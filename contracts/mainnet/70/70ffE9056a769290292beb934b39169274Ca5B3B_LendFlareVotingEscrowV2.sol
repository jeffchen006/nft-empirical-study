// SPDX-License-Identifier: UNLICENSED
/* 

  _                          _   _____   _                       
 | |       ___   _ __     __| | |  ___| | |   __ _   _ __    ___ 
 | |      / _ \ | '_ \   / _` | | |_    | |  / _` | | '__|  / _ \
 | |___  |  __/ | | | | | (_| | |  _|   | | | (_| | | |    |  __/
 |_____|  \___| |_| |_|  \__,_| |_|     |_|  \__,_| |_|     \___|
                                                                 
LendFlare.finance
*/

pragma solidity =0.6.12;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/Initializable.sol";
import "./common/IBaseReward.sol";

// Reference @openzeppelin/contracts/token/ERC20/IERC20.sol
interface ILendFlareVotingEscrow {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

contract LendFlareVotingEscrowV2 is Initializable, ReentrancyGuard, ILendFlareVotingEscrow {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 constant WEEK = 1 weeks; // all future times are rounded by week
    uint256 constant MAXTIME = 4 * 365 * 86400; // 4 years
    string constant NAME = "Vote-escrowed LFT";
    string constant SYMBOL = "VeLFT";
    uint8 constant DECIMALS = 18;

    address public token;
    address public rewardManager;

    uint256 public lockedSupply;

    enum DepositTypes {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME
    }

    struct Point {
        int256 bias;
        int256 slope; // dweight / dt
        uint256 timestamp; // timestamp
    }

    struct LockedBalance {
        uint256 amount;
        uint256 end;
    }

    IBaseReward[] public rewardPools;

    mapping(address => LockedBalance) public lockedBalances;
    mapping(address => mapping(uint256 => Point)) public userPointHistory; // user => ( user epoch => point )
    mapping(address => uint256) public userPointEpoch; // user => user epoch

    bool public expired;
    uint256 public epoch;

    mapping(uint256 => Point) public pointHistory; // epoch -> unsigned point.
    mapping(uint256 => int256) public slopeChanges; // time -> signed slope change

    event Deposit(address indexed provider, uint256 value, uint256 indexed locktime, DepositTypes depositTypes, uint256 ts);
    event Withdraw(address indexed provider, uint256 value, uint256 timestamp);
    event TotalSupply(uint256 prevSupply, uint256 supply);

    // @custom:oz-upgrades-unsafe-allow constructor
    constructor() public initializer {}

    function initialize(address _token, address _rewardManager) public initializer {
        token = _token;
        rewardManager = _rewardManager;
    }

    modifier onlyRewardManager() {
        require(rewardManager == msg.sender, "LendFlareVotingEscrow: caller is not the rewardManager");
        _;
    }

    function rewardPoolsLength() external view returns (uint256) {
        return rewardPools.length;
    }

    function addRewardPool(address _v) external onlyRewardManager returns (bool) {
        require(_v != address(0), "!_v");

        rewardPools.push(IBaseReward(_v));

        return true;
    }

    function clearRewardPools() external onlyRewardManager {
        delete rewardPools;
    }

    function updateTotalSupply(bytes memory data) public {
        bytes memory callData;

        callData = abi.encodePacked(bytes4(keccak256(bytes("_updateTotalSupply(address[],bool)"))), data);

        (bool success, bytes memory returnData) = address(this).call(callData);
        require(success, string(returnData));
    }

    function _updateTotalSupply(address[] calldata _senders, bool _expired) public {
        require(epoch == 0, "!epoch");

        for (uint256 i = 0; i < _senders.length; i++) {
            LockedBalance storage newLocked = lockedBalances[_senders[i]];

            _updateTotalSupply(_senders[i], newLocked);
        }

        if (_expired) {
            require(!expired, "!expired");

            expired = true;
        }
    }

    function _updateTotalSupply(address _sender, LockedBalance storage _newLocked) internal {
        Point memory userOldPoint;
        Point memory userNewPoint;

        int256 newSlope = 0;

        if (_sender != address(0)) {
            if (_newLocked.end > block.timestamp && _newLocked.amount > 0) {
                userNewPoint.slope = int256(_newLocked.amount / MAXTIME);
                userNewPoint.bias = userNewPoint.slope * int256(_newLocked.end - block.timestamp);
            }
            newSlope = slopeChanges[_newLocked.end];
        }

        Point memory lastPoint = Point({ bias: 0, slope: 0, timestamp: block.timestamp });

        if (epoch > 0) {
            lastPoint = pointHistory[epoch];
        }

        uint256 lastCheckpoint = lastPoint.timestamp;
        uint256 iterativeTime = _floorToWeek(lastCheckpoint);

        for (uint256 i; i < 255; i++) {
            int256 slope = 0;
            iterativeTime += WEEK;

            if (iterativeTime > block.timestamp) {
                iterativeTime = block.timestamp;
            } else {
                slope = slopeChanges[iterativeTime];
            }

            lastPoint.bias -= lastPoint.slope * int256(iterativeTime - lastCheckpoint);
            lastPoint.slope += slope;

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0; // This can happen
            }

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0; // This cannot happen - just in case
            }

            lastCheckpoint = iterativeTime;
            lastPoint.timestamp = iterativeTime;

            epoch++;

            if (iterativeTime == block.timestamp) {
                break;
            } else {
                pointHistory[epoch] = lastPoint;
            }
        }

        if (_sender != address(0)) {
            lastPoint.slope += userNewPoint.slope - userOldPoint.slope;
            lastPoint.bias += userNewPoint.bias - userOldPoint.bias;

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        pointHistory[epoch] = lastPoint;

        if (_sender != address(0)) {
            newSlope -= userNewPoint.slope; // old slope disappeared at this point
            slopeChanges[_newLocked.end] = newSlope;
        }
    }

    function _checkpointV1(address _sender, LockedBalance storage _newLocked) internal {
        Point storage point = userPointHistory[_sender][++userPointEpoch[_sender]];

        point.timestamp = block.timestamp;

        if (_newLocked.end > block.timestamp) {
            point.slope = int256(_newLocked.amount / MAXTIME);
            point.bias = point.slope * int256(_newLocked.end - block.timestamp);
        }
    }

    function _checkpoint(
        address _sender,
        LockedBalance memory _oldLocked,
        LockedBalance memory _newLocked
    ) internal {
        Point memory userOldPoint;
        Point memory userNewPoint;

        int256 oldSlope = 0;
        int256 newSlope = 0;

        if (_sender != address(0)) {
            if (_oldLocked.end > block.timestamp && _oldLocked.amount > 0) {
                userOldPoint.slope = int256(_oldLocked.amount / MAXTIME);
                userOldPoint.bias = userOldPoint.slope * int256(_oldLocked.end - block.timestamp);
            }

            if (_newLocked.end > block.timestamp && _newLocked.amount > 0) {
                userNewPoint.slope = int256(_newLocked.amount / MAXTIME);
                userNewPoint.bias = userNewPoint.slope * int256(_newLocked.end - block.timestamp);
            }

            oldSlope = slopeChanges[_oldLocked.end];

            if (_newLocked.end != 0) {
                if (_newLocked.end == _oldLocked.end) {
                    newSlope = oldSlope;
                } else {
                    newSlope = slopeChanges[_newLocked.end];
                }
            }
        }

        Point memory lastPoint = Point({ bias: 0, slope: 0, timestamp: block.timestamp });

        if (epoch > 0) {
            lastPoint = pointHistory[epoch];
        }

        uint256 lastCheckpoint = lastPoint.timestamp;
        uint256 iterativeTime = _floorToWeek(lastCheckpoint);

        for (uint256 i; i < 255; i++) {
            int256 slope = 0;

            iterativeTime += WEEK;

            if (iterativeTime > block.timestamp) {
                iterativeTime = block.timestamp;
            } else {
                slope = slopeChanges[iterativeTime];
            }

            lastPoint.bias -= lastPoint.slope * int256(iterativeTime - lastCheckpoint);
            lastPoint.slope += slope;

            if (lastPoint.bias < 0) {
                lastPoint.bias = 0; // This can happen
            }

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0; // This cannot happen - just in case
            }

            lastCheckpoint = iterativeTime;
            lastPoint.timestamp = iterativeTime;

            epoch++;

            if (iterativeTime == block.timestamp) {
                break;
            } else {
                pointHistory[epoch] = lastPoint;
            }
        }

        if (_sender != address(0)) {
            // If last point was in this block, the slope change has been applied already
            // But in such case we have 0 slope(s)
            lastPoint.slope += userNewPoint.slope - userOldPoint.slope;
            lastPoint.bias += userNewPoint.bias - userOldPoint.bias;

            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        pointHistory[epoch] = lastPoint;

        if (_sender != address(0)) {
            if (_oldLocked.end > block.timestamp) {
                oldSlope += userOldPoint.slope;

                if (_newLocked.end == _oldLocked.end) {
                    oldSlope -= userNewPoint.slope; // It was a new deposit, not extension
                }

                slopeChanges[_oldLocked.end] = oldSlope;
            }

            if (_newLocked.end > block.timestamp) {
                if (_newLocked.end > _oldLocked.end) {
                    newSlope -= userNewPoint.slope; // old slope disappeared at this point
                    slopeChanges[_newLocked.end] = newSlope;
                }
            }

            uint256 userEpoch = userPointEpoch[_sender] + 1;

            userPointEpoch[_sender] = userEpoch;
            userNewPoint.timestamp = block.timestamp;
            userPointHistory[_sender][userEpoch] = userNewPoint;
        }
    }

    function _depositFor(
        address _sender,
        uint256 _amount,
        uint256 _unlockTime,
        LockedBalance storage _locked,
        DepositTypes _depositTypes
    ) internal {
        uint256 oldLockedSupply = lockedSupply;

        if (_amount > 0) {
            IERC20(token).safeTransferFrom(_sender, address(this), _amount);
        }

        LockedBalance memory oldLocked;

        (oldLocked.amount, oldLocked.end) = (_locked.amount, _locked.end);

        _locked.amount = _locked.amount + _amount;
        lockedSupply = lockedSupply + _amount;

        if (_unlockTime > 0) {
            _locked.end = _unlockTime;
        }

        for (uint256 i = 0; i < rewardPools.length; i++) {
            rewardPools[i].stake(_sender);
        }

        if (expired) {
            _checkpoint(_sender, oldLocked, _locked);
        } else {
            _checkpointV1(_sender, _locked);
        }

        emit Deposit(_sender, _amount, _locked.end, _depositTypes, block.timestamp);
        emit TotalSupply(oldLockedSupply, lockedSupply);
    }

    function deposit(uint256 _amount) external nonReentrant {
        LockedBalance storage locked = lockedBalances[msg.sender];

        require(_amount > 0, "need non-zero value");
        require(locked.amount > 0, "no existing lock found");
        require(locked.end > block.timestamp, "cannot add to expired lock. Withdraw");

        _depositFor(msg.sender, _amount, 0, locked, DepositTypes.DEPOSIT_FOR_TYPE);
    }

    function createLock(uint256 _amount, uint256 _unlockTime) public nonReentrant {
        _unlockTime = _floorToWeek(_unlockTime);

        require(_amount != 0, "Must stake non zero amount");
        require(_unlockTime > block.timestamp, "Can only lock until time in the future");

        LockedBalance storage locked = lockedBalances[msg.sender];

        require(locked.amount == 0, "Withdraw old tokens first");

        uint256 roundedMin = _floorToWeek(block.timestamp) + WEEK;
        uint256 roundedMax = _floorToWeek(block.timestamp) + MAXTIME;

        if (_unlockTime < roundedMin) {
            _unlockTime = roundedMin;
        } else if (_unlockTime > roundedMax) {
            _unlockTime = roundedMax;
        }

        _depositFor(msg.sender, _amount, _unlockTime, locked, DepositTypes.CREATE_LOCK_TYPE);
    }

    function increaseAmount(uint256 _amount) external nonReentrant {
        LockedBalance storage locked = lockedBalances[msg.sender];

        require(_amount != 0, "Must stake non zero amount");
        require(locked.amount != 0, "No existing lock found");
        require(locked.end >= block.timestamp, "Can't add to expired lock. Withdraw old tokens first");

        _depositFor(msg.sender, _amount, 0, locked, DepositTypes.INCREASE_LOCK_AMOUNT);
    }

    function increaseUnlockTime(uint256 _unlockTime) external nonReentrant {
        LockedBalance storage locked = lockedBalances[msg.sender];

        require(locked.amount != 0, "No existing lock found");
        require(locked.end >= block.timestamp, "Lock expired. Withdraw old tokens first");

        uint256 maxUnlockTime = _floorToWeek(block.timestamp) + MAXTIME;
        require(locked.end != maxUnlockTime, "Already locked for maximum time");

        _unlockTime = _floorToWeek(_unlockTime);

        require(_unlockTime <= maxUnlockTime, "Can't lock for more than max time");

        _depositFor(msg.sender, 0, _unlockTime, locked, DepositTypes.INCREASE_UNLOCK_TIME);
    }

    function withdraw() public nonReentrant {
        LockedBalance storage locked = lockedBalances[msg.sender];
        LockedBalance memory oldLocked = locked;

        require(block.timestamp >= locked.end, "The lock didn't expire");

        uint256 oldLockedSupply = lockedSupply;
        uint256 lockedAmount = locked.amount;

        lockedSupply = lockedSupply - lockedAmount;

        locked.amount = 0;
        locked.end = 0;

        if (expired) {
            _checkpoint(msg.sender, oldLocked, locked);
        } else {
            _checkpointV1(msg.sender, locked);
        }

        IERC20(token).safeTransfer(msg.sender, lockedAmount);

        for (uint256 i = 0; i < rewardPools.length; i++) {
            rewardPools[i].withdraw(msg.sender);
        }

        emit Withdraw(msg.sender, lockedAmount, block.timestamp);
        emit TotalSupply(oldLockedSupply, lockedSupply);
    }

    function _floorToWeek(uint256 _t) internal pure returns (uint256) {
        return (_t / WEEK) * WEEK;
    }

    function balanceOf(address _sender) external view override returns (uint256) {
        uint256 t = block.timestamp;
        uint256 userEpoch = userPointEpoch[_sender];

        if (userEpoch == 0) return 0;

        Point storage point = userPointHistory[_sender][userEpoch];

        int256 bias = point.slope * int256(t - point.timestamp);

        if (bias > point.bias) return 0;

        return uint256(point.bias - bias);
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function supplyAt(Point memory _point, uint256 _t) internal view returns (uint256) {
        uint256 iterativeTime = _floorToWeek(_point.timestamp);

        for (uint256 i; i < 255; i++) {
            int256 slope = 0;

            iterativeTime += WEEK;

            if (iterativeTime > _t) {
                iterativeTime = _t;
            } else {
                slope = slopeChanges[iterativeTime];
            }
            _point.bias -= _point.slope * int256(iterativeTime - _point.timestamp);

            if (iterativeTime == _t) {
                break;
            }
            _point.slope += slope;
            _point.timestamp = iterativeTime;
        }

        if (_point.bias < 0) {
            _point.bias = 0;
        }

        return uint256(_point.bias);
    }

    function totalSupply() public view override returns (uint256) {
        if (expired) {
            return supplyAt(pointHistory[epoch], block.timestamp);
        } else {
            return lockedSupply;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC20.sol";
import "../../math/SafeMath.sol";
import "../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;
    using Address for address;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value, "SafeERC20: decreased allowance below zero");
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity >=0.4.24 <0.8.0;

import "../utils/Address.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {UpgradeableProxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || _isConstructor() || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        return !Address.isContract(address(this));
    }
}

// SPDX-License-Identifier: UNLICENSED
/* 

  _                          _   _____   _                       
 | |       ___   _ __     __| | |  ___| | |   __ _   _ __    ___ 
 | |      / _ \ | '_ \   / _` | | |_    | |  / _` | | '__|  / _ \
 | |___  |  __/ | | | | | (_| | |  _|   | | | (_| | | |    |  __/
 |_____|  \___| |_| |_|  \__,_| |_|     |_|  \__,_| |_|     \___|
                                                                 
LendFlare.finance
*/

pragma solidity =0.6.12;

interface IBaseReward {
    function earned(address account) external view returns (uint256);
    function stake(address _for) external;
    function withdraw(address _for) external;
    function getReward(address _for) external;
    function notifyRewardAmount(uint256 reward) external;
    function addOwner(address _newOwner) external;
    function addOwners(address[] calldata _newOwners) external;
    function removeOwner(address _owner) external;
    function isOwner(address _owner) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
      return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}