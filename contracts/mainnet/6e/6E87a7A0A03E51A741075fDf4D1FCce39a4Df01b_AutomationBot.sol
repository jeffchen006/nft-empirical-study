//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/ManagerLike.sol";
import "./interfaces/ICommand.sol";
import "./interfaces/BotLike.sol";
import "./ServiceRegistry.sol";
import "./McdUtils.sol";

contract AutomationBot {
    struct TriggerRecord {
        bytes32 triggerHash;
        uint256 cdpId;
    }

    string private constant CDP_MANAGER_KEY = "CDP_MANAGER";
    string private constant AUTOMATION_BOT_KEY = "AUTOMATION_BOT";
    string private constant AUTOMATION_EXECUTOR_KEY = "AUTOMATION_EXECUTOR";
    string private constant MCD_UTILS_KEY = "MCD_UTILS";

    mapping(uint256 => TriggerRecord) public activeTriggers;

    uint256 public triggersCounter = 0;

    ServiceRegistry public immutable serviceRegistry;
    address public immutable self;

    constructor(ServiceRegistry _serviceRegistry) {
        serviceRegistry = _serviceRegistry;
        self = address(this);
    }

    modifier auth(address caller) {
        require(
            serviceRegistry.getRegisteredService(AUTOMATION_EXECUTOR_KEY) == caller,
            "bot/not-executor"
        );
        _;
    }

    modifier onlyDelegate() {
        require(address(this) != self, "bot/only-delegate");
        _;
    }

    // works correctly in any context
    function validatePermissions(
        uint256 cdpId,
        address operator,
        ManagerLike manager
    ) private view {
        require(isCdpOwner(cdpId, operator, manager), "bot/no-permissions");
    }

    // works correctly in any context
    function isCdpAllowed(
        uint256 cdpId,
        address operator,
        ManagerLike manager
    ) public view returns (bool) {
        address cdpOwner = manager.owns(cdpId);
        return (manager.cdpCan(cdpOwner, cdpId, operator) == 1) || (operator == cdpOwner);
    }

    // works correctly in any context
    function isCdpOwner(
        uint256 cdpId,
        address operator,
        ManagerLike manager
    ) private view returns (bool) {
        return (operator == manager.owns(cdpId));
    }

    // works correctly in any context
    function getCommandAddress(uint256 triggerType) public view returns (address) {
        bytes32 commandHash = keccak256(abi.encode("Command", triggerType));

        address commandAddress = serviceRegistry.getServiceAddress(commandHash);

        return commandAddress;
    }

    // works correctly in any context
    function getTriggersHash(
        uint256 cdpId,
        bytes memory triggerData,
        address commandAddress
    ) private view returns (bytes32) {
        bytes32 triggersHash = keccak256(
            abi.encodePacked(cdpId, triggerData, serviceRegistry, commandAddress)
        );

        return triggersHash;
    }

    // works correctly in context of Automation Bot
    function checkTriggersExistenceAndCorrectness(
        uint256 cdpId,
        uint256 triggerId,
        address commandAddress,
        bytes memory triggerData
    ) private view {
        bytes32 triggersHash = activeTriggers[triggerId].triggerHash;

        require(
            triggersHash != bytes32(0) &&
                triggersHash == getTriggersHash(cdpId, triggerData, commandAddress),
            "bot/invalid-trigger"
        );
    }

    function checkTriggersExistenceAndCorrectness(uint256 cdpId, uint256 triggerId) private view {
        require(activeTriggers[triggerId].cdpId == cdpId, "bot/invalid-trigger");
    }

    // works correctly in context of automationBot
    function addRecord(
        // This function should be executed allways in a context of AutomationBot address not DsProxy,
        // msg.sender should be dsProxy
        uint256 cdpId,
        uint256 triggerType,
        uint256 replacedTriggerId,
        bytes memory triggerData
    ) external {
        ManagerLike manager = ManagerLike(serviceRegistry.getRegisteredService(CDP_MANAGER_KEY));
        address commandAddress = getCommandAddress(triggerType);

        require(
            ICommand(commandAddress).isTriggerDataValid(cdpId, triggerData),
            "bot/invalid-trigger-data"
        );

        require(isCdpAllowed(cdpId, msg.sender, manager), "bot/no-permissions");

        triggersCounter = triggersCounter + 1;
        activeTriggers[triggersCounter] = TriggerRecord(
            getTriggersHash(cdpId, triggerData, commandAddress),
            cdpId
        );

        if (replacedTriggerId != 0) {
            require(
                activeTriggers[replacedTriggerId].cdpId == cdpId,
                "bot/trigger-removal-illegal"
            );
            activeTriggers[replacedTriggerId] = TriggerRecord(0, 0);
            emit TriggerRemoved(cdpId, replacedTriggerId);
        }
        emit TriggerAdded(triggersCounter, commandAddress, cdpId, triggerData);
    }

    // works correctly in context of automationBot
    function removeRecord(
        // This function should be executed allways in a context of AutomationBot address not DsProxy,
        // msg.sender should be dsProxy
        uint256 cdpId,
        uint256 triggerId
    ) external {
        address managerAddress = serviceRegistry.getRegisteredService(CDP_MANAGER_KEY);

        require(isCdpAllowed(cdpId, msg.sender, ManagerLike(managerAddress)), "bot/no-permissions");
        // validatePermissions(cdpId, msg.sender, ManagerLike(managerAddress));

        checkTriggersExistenceAndCorrectness(cdpId, triggerId);

        activeTriggers[triggerId] = TriggerRecord(0, 0);
        emit TriggerRemoved(cdpId, triggerId);
    }

    //works correctly in context of dsProxy
    function addTrigger(
        uint256 cdpId,
        uint256 triggerType,
        uint256 replacedTriggerId,
        bytes memory triggerData
    ) external onlyDelegate {
        // TODO: consider adding isCdpAllow add flag in tx payload, make sense from extensibility perspective
        ManagerLike manager = ManagerLike(serviceRegistry.getRegisteredService(CDP_MANAGER_KEY));

        address automationBot = serviceRegistry.getRegisteredService(AUTOMATION_BOT_KEY);
        BotLike(automationBot).addRecord(cdpId, triggerType, replacedTriggerId, triggerData);
        if (!isCdpAllowed(cdpId, automationBot, manager)) {
            manager.cdpAllow(cdpId, automationBot, 1);
            emit ApprovalGranted(cdpId, automationBot);
        }
    }

    //works correctly in context of dsProxy

    // TODO: removeAllowance parameter of this method moves responsibility to decide on this to frontend.
    // In case of a bug on frontend allowance might be revoked by setting this parameter to `true`
    // despite there still be some active triggers which will be disables by this call.
    // One of the solutions is to add counter of active triggers and revoke allowance only if last trigger is being deleted
    function removeTrigger(
        uint256 cdpId,
        uint256 triggerId,
        bool removeAllowance
    ) external onlyDelegate {
        address managerAddress = serviceRegistry.getRegisteredService(CDP_MANAGER_KEY);
        ManagerLike manager = ManagerLike(managerAddress);

        address automationBot = serviceRegistry.getRegisteredService(AUTOMATION_BOT_KEY);

        BotLike(automationBot).removeRecord(cdpId, triggerId);

        if (removeAllowance) {
            manager.cdpAllow(cdpId, automationBot, 0);
            emit ApprovalRemoved(cdpId, automationBot);
        }

        emit TriggerRemoved(cdpId, triggerId);
    }

    //works correctly in context of dsProxy
    function removeApproval(ServiceRegistry _serviceRegistry, uint256 cdpId) external onlyDelegate {
        address approvedEntity = changeApprovalStatus(_serviceRegistry, cdpId, 0);
        emit ApprovalRemoved(cdpId, approvedEntity);
    }

    //works correctly in context of dsProxy
    function grantApproval(ServiceRegistry _serviceRegistry, uint256 cdpId) external onlyDelegate {
        address approvedEntity = changeApprovalStatus(_serviceRegistry, cdpId, 1);
        emit ApprovalGranted(cdpId, approvedEntity);
    }

    //works correctly in context of dsProxy
    function changeApprovalStatus(
        ServiceRegistry _serviceRegistry,
        uint256 cdpId,
        uint256 status
    ) private returns (address) {
        address managerAddress = _serviceRegistry.getRegisteredService(CDP_MANAGER_KEY);
        ManagerLike manager = ManagerLike(managerAddress);
        address automationBot = _serviceRegistry.getRegisteredService(AUTOMATION_BOT_KEY);
        require(
            isCdpAllowed(cdpId, automationBot, manager) != (status == 1),
            "bot/approval-unchanged"
        );
        validatePermissions(cdpId, address(this), manager);
        manager.cdpAllow(cdpId, automationBot, status);
        return automationBot;
    }

    function drawDaiFromVault(
        uint256 cdpId,
        ManagerLike manager,
        uint256 daiCoverage
    ) internal {
        address utilsAddress = serviceRegistry.getRegisteredService(MCD_UTILS_KEY);

        McdUtils utils = McdUtils(utilsAddress);
        manager.cdpAllow(cdpId, utilsAddress, 1);
        utils.drawDebt(daiCoverage, cdpId, manager, msg.sender);
        manager.cdpAllow(cdpId, utilsAddress, 0);
    }

    //works correctly in context of automationBot
    function execute(
        bytes calldata executionData,
        uint256 cdpId,
        bytes calldata triggerData,
        address commandAddress,
        uint256 triggerId,
        uint256 daiCoverage
    ) external auth(msg.sender) {
        checkTriggersExistenceAndCorrectness(cdpId, triggerId, commandAddress, triggerData);
        ManagerLike manager = ManagerLike(serviceRegistry.getRegisteredService(CDP_MANAGER_KEY));
        drawDaiFromVault(cdpId, manager, daiCoverage);

        ICommand command = ICommand(commandAddress);
        require(command.isExecutionLegal(cdpId, triggerData), "bot/trigger-execution-illegal");

        manager.cdpAllow(cdpId, commandAddress, 1);
        command.execute(executionData, cdpId, triggerData);
        activeTriggers[triggerId] = TriggerRecord(0, 0);
        manager.cdpAllow(cdpId, commandAddress, 0);

        require(command.isExecutionCorrect(cdpId, triggerData), "bot/trigger-execution-wrong");

        emit TriggerExecuted(triggerId, cdpId, executionData);
    }

    event ApprovalRemoved(uint256 indexed cdpId, address approvedEntity);

    event ApprovalGranted(uint256 indexed cdpId, address approvedEntity);

    event TriggerRemoved(uint256 indexed cdpId, uint256 indexed triggerId);

    event TriggerAdded(
        uint256 indexed triggerId,
        address indexed commandAddress,
        uint256 indexed cdpId,
        bytes triggerData
    );

    event TriggerExecuted(uint256 indexed triggerId, uint256 indexed cdpId, bytes executionData);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ManagerLike {
    function cdpCan(
        address owner,
        uint256 cdpId,
        address allowedAddr
    ) external view returns (uint256);

    function vat() external view returns (address);

    function ilks(uint256) external view returns (bytes32);

    function owns(uint256) external view returns (address);

    function urns(uint256) external view returns (address);

    function cdpAllow(
        uint256 cdp,
        address usr,
        uint256 ok
    ) external;

    function frob(
        uint256,
        int256,
        int256
    ) external;

    function flux(
        uint256,
        address,
        uint256
    ) external;

    function move(
        uint256,
        address,
        uint256
    ) external;

    function exit(
        address,
        uint256,
        address,
        uint256
    ) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface ICommand {
    function isTriggerDataValid(uint256 _cdpId, bytes memory triggerData)
        external
        view
        returns (bool);

    function isExecutionCorrect(uint256 cdpId, bytes memory triggerData)
        external
        view
        returns (bool);

    function isExecutionLegal(uint256 cdpId, bytes memory triggerData) external view returns (bool);

    function execute(
        bytes calldata executionData,
        uint256 cdpId,
        bytes memory triggerData
    ) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface BotLike {
    function addRecord(
        uint256 cdpId,
        uint256 triggerType,
        uint256 replacedTriggerId,
        bytes memory triggerData
    ) external;

    function removeRecord(
        // This function should be executed allways in a context of AutomationBot address not DsProxy,
        //msg.sender should be dsProxy
        uint256 cdpId,
        uint256 triggerId
    ) external;

    function execute(
        bytes calldata executionData,
        uint256 cdpId,
        bytes calldata triggerData,
        address commandAddress,
        uint256 triggerId,
        uint256 daiCoverage
    ) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract ServiceRegistry {
    uint256 public constant MAX_DELAY = 30 days;

    mapping(bytes32 => uint256) public lastExecuted;
    mapping(bytes32 => address) private namedService;
    address public owner;
    uint256 public requiredDelay;

    modifier validateInput(uint256 len) {
        require(msg.data.length == len, "registry/illegal-padding");
        _;
    }

    modifier delayedExecution() {
        bytes32 operationHash = keccak256(msg.data);
        uint256 reqDelay = requiredDelay;

        /* solhint-disable not-rely-on-time */
        if (lastExecuted[operationHash] == 0 && reqDelay > 0) {
            // not called before, scheduled for execution
            lastExecuted[operationHash] = block.timestamp;
            emit ChangeScheduled(operationHash, block.timestamp + reqDelay, msg.data);
        } else {
            require(
                block.timestamp - reqDelay > lastExecuted[operationHash],
                "registry/delay-too-small"
            );
            emit ChangeApplied(operationHash, block.timestamp, msg.data);
            _;
            lastExecuted[operationHash] = 0;
        }
        /* solhint-enable not-rely-on-time */
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "registry/only-owner");
        _;
    }

    constructor(uint256 initialDelay) {
        require(initialDelay <= MAX_DELAY, "registry/invalid-delay");
        requiredDelay = initialDelay;
        owner = msg.sender;
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
        validateInput(36)
        delayedExecution
    {
        owner = newOwner;
    }

    function changeRequiredDelay(uint256 newDelay)
        external
        onlyOwner
        validateInput(36)
        delayedExecution
    {
        require(newDelay <= MAX_DELAY, "registry/invalid-delay");
        requiredDelay = newDelay;
    }

    function getServiceNameHash(string memory name) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(name));
    }

    function addNamedService(bytes32 serviceNameHash, address serviceAddress)
        external
        onlyOwner
        validateInput(68)
        delayedExecution
    {
        require(namedService[serviceNameHash] == address(0), "registry/service-override");
        namedService[serviceNameHash] = serviceAddress;
    }

    function updateNamedService(bytes32 serviceNameHash, address serviceAddress)
        external
        onlyOwner
        validateInput(68)
        delayedExecution
    {
        require(namedService[serviceNameHash] != address(0), "registry/service-does-not-exist");
        namedService[serviceNameHash] = serviceAddress;
    }

    function removeNamedService(bytes32 serviceNameHash) external onlyOwner validateInput(36) {
        require(namedService[serviceNameHash] != address(0), "registry/service-does-not-exist");
        namedService[serviceNameHash] = address(0);
        emit NamedServiceRemoved(serviceNameHash);
    }

    function getRegisteredService(string memory serviceName) external view returns (address) {
        return namedService[keccak256(abi.encodePacked(serviceName))];
    }

    function getServiceAddress(bytes32 serviceNameHash) external view returns (address) {
        return namedService[serviceNameHash];
    }

    function clearScheduledExecution(bytes32 scheduledExecution)
        external
        onlyOwner
        validateInput(36)
    {
        require(lastExecuted[scheduledExecution] > 0, "registry/execution-not-scheduled");
        lastExecuted[scheduledExecution] = 0;
        emit ChangeCancelled(scheduledExecution);
    }

    event ChangeScheduled(bytes32 dataHash, uint256 scheduledFor, bytes data);
    event ChangeApplied(bytes32 dataHash, uint256 appliedAt, bytes data);
    event ChangeCancelled(bytes32 dataHash);
    event NamedServiceRemoved(bytes32 nameHash);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./external/DSMath.sol";
import "./interfaces/ManagerLike.sol";
import "./interfaces/ICommand.sol";
import "./interfaces/Mcd.sol";
import "./interfaces/BotLike.sol";

import "./ServiceRegistry.sol";

/// @title Getter contract for Vault info from Maker protocol
contract McdUtils is DSMath {
    address public immutable serviceRegistry;
    IERC20 private immutable DAI;
    address private immutable daiJoin;
    address public immutable jug;

    constructor(
        address _serviceRegistry,
        IERC20 _dai,
        address _daiJoin,
        address _jug
    ) {
        serviceRegistry = _serviceRegistry;
        DAI = _dai;
        daiJoin = _daiJoin;
        jug = _jug;
    }

    function toInt256(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int256-overflow");
    }

    function _getDrawDart(
        address vat,
        address urn,
        bytes32 ilk,
        uint256 wad
    ) internal returns (int256 dart) {
        // Updates stability fee rate
        uint256 rate = IJug(jug).drip(ilk);

        // Gets DAI balance of the urn in the vat
        uint256 dai = IVat(vat).dai(urn);

        // If there was already enough DAI in the vat balance, just exits it without adding more debt
        if (dai < mul(wad, RAY)) {
            // Calculates the needed dart so together with the existing dai in the vat is enough to exit wad amount of DAI tokens
            dart = toInt256(sub(mul(wad, RAY), dai) / rate);
            // This is neeeded due lack of precision. It might need to sum an extra dart wei (for the given DAI wad amount)
            dart = mul(uint256(dart), rate) < mul(wad, RAY) ? dart + 1 : dart;
        }
    }

    function drawDebt(
        uint256 borrowedDai,
        uint256 cdpId,
        ManagerLike manager,
        address sendTo
    ) external {
        address urn = manager.urns(cdpId);
        address vat = manager.vat();

        manager.frob(cdpId, 0, _getDrawDart(vat, urn, manager.ilks(cdpId), borrowedDai));
        manager.move(cdpId, address(this), mul(borrowedDai, RAY));

        if (IVat(vat).can(address(this), daiJoin) == 0) {
            IVat(vat).hope(daiJoin);
        }

        IJoin(daiJoin).exit(sendTo, borrowedDai);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x, "");
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "");
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x / y;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x <= y ? x : y;
    }

    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        return x >= y ? x : y;
    }

    function imin(int256 x, int256 y) internal pure returns (int256 z) {
        return x <= y ? x : y;
    }

    function imax(int256 x, int256 y) internal pure returns (int256 z) {
        return x >= y ? x : y;
    }

    uint256 internal constant WAD = 10**18;
    uint256 internal constant RAY = 10**27;

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint256 x, uint256 n) internal pure returns (uint256 z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

abstract contract IVat {
    struct Urn {
        uint256 ink; // Locked Collateral  [wad]
        uint256 art; // Normalised Debt    [wad]
    }

    struct Ilk {
        uint256 Art; // Total Normalised Debt     [wad]
        uint256 rate; // Accumulated Rates         [ray]
        uint256 spot; // Price with Safety Margin  [ray]
        uint256 line; // Debt Ceiling              [rad]
        uint256 dust; // Urn Debt Floor            [rad]
    }

    mapping(bytes32 => mapping(address => Urn)) public urns;
    mapping(bytes32 => Ilk) public ilks;
    mapping(bytes32 => mapping(address => uint256)) public gem; // [wad]

    function can(address, address) public view virtual returns (uint256);

    function dai(address) public view virtual returns (uint256);

    function frob(
        bytes32,
        address,
        address,
        address,
        int256,
        int256
    ) public virtual;

    function hope(address) public virtual;

    function move(
        address,
        address,
        uint256
    ) public virtual;

    function fork(
        bytes32,
        address,
        address,
        int256,
        int256
    ) public virtual;
}

abstract contract IGem {
    function dec() public virtual returns (uint256);

    function gem() public virtual returns (IGem);

    function join(address, uint256) public payable virtual;

    function exit(address, uint256) public virtual;

    function approve(address, uint256) public virtual;

    function transfer(address, uint256) public virtual returns (bool);

    function transferFrom(
        address,
        address,
        uint256
    ) public virtual returns (bool);

    function deposit() public payable virtual;

    function withdraw(uint256) public virtual;

    function allowance(address, address) public virtual returns (uint256);
}

abstract contract IJoin {
    bytes32 public ilk;

    function dec() public view virtual returns (uint256);

    function gem() public view virtual returns (IGem);

    function join(address, uint256) public payable virtual;

    function exit(address, uint256) public virtual;
}

abstract contract IDaiJoin {
    function vat() public virtual returns (IVat);

    function dai() public virtual returns (IGem);

    function join(address, uint256) public payable virtual;

    function exit(address, uint256) public virtual;
}

abstract contract IJug {
    struct Ilk {
        uint256 duty;
        uint256 rho;
    }

    mapping(bytes32 => Ilk) public ilks;

    function drip(bytes32) public virtual returns (uint256);
}