// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./Staking20Into20.sol";
import "./Staking20Plus20Into20.sol";

contract FactoryStakingInto20 {
    using SafeERC20 for IERC20;

    IAccessControl public immutable FACTORY;

    modifier onlyAdmin() {
        require(FACTORY.hasRole(0x0, msg.sender));
        _;
    }

    event NewContract(address indexed instance, uint8 instanceType);

    constructor(IAccessControl _factory) {
        FACTORY = _factory;
    }

    function createStaking20Into20(IERC20 _stakeToken, IERC20Metadata _rewardToken, uint256 _startTime, uint256 _endTime, uint256 _rewardPerSecond, uint256 _penaltyPeriod, uint16 _feePercentage) external onlyAdmin {
        Staking20Into20 instance = new Staking20Into20(_stakeToken, _rewardToken, _startTime, _endTime, _rewardPerSecond, _penaltyPeriod, _feePercentage);
        instance.setFeeReceiver(msg.sender);
        IERC20(_rewardToken).safeTransferFrom(msg.sender, address(instance), (_endTime - _startTime) * _rewardPerSecond);
        emit NewContract(address(instance), 0);
    }

    function createStaking20Plus20Into20(IERC20Metadata[2] memory _stakeToken, IERC20Metadata _rewardToken, uint256[2] memory _proportion, uint256 _startTime, uint256 _endTime, uint256 _rewardPerSecond, uint256 _penaltyPeriod, uint16 _feePercentage) external onlyAdmin {
        Staking20Plus20Into20 instance = new Staking20Plus20Into20(_stakeToken, _rewardToken, _proportion, _startTime, _endTime, _rewardPerSecond, _penaltyPeriod, _feePercentage);
        instance.setFeeReceiver(msg.sender);
        IERC20(_rewardToken).safeTransferFrom(msg.sender, address(instance), (_endTime - _startTime) * _rewardPerSecond);
        emit NewContract(address(instance), 1);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking20Plus20Into20 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant FEE_DENOMINATOR = 10000;

    uint256 public PRECISION_FACTOR;
    uint256 public REWARD_PER_SECOND;
    IERC20[2] public STAKE_TOKEN;
    IERC20 public REWARD_TOKEN;

    uint256[2] public PROPORTION;

    uint256 public PENALTY_PERIOD;
    uint16 public FEE_PERCENTAGE;

    uint256 public START_TIME;
    uint256 public END_TIME;
    uint256 public totalStaked;
    uint256 public accTokenPerShare;

    address public feeReceiver;

    bool public excessRewardWithdrawn;

    uint256 private lastActionTime;
    uint256 private _excessReward;

    mapping (address => UserInfo) public stakeInfo;

    struct UserInfo {
        uint256[2] amount;
        uint256 rewardTaken;
        uint256 enteredAt;
    }

    constructor(IERC20Metadata[2] memory _stakeToken, IERC20Metadata _rewardToken, uint256[2] memory _proportion, uint256 _startTime, uint256 _endTime, uint256 _rewardPerSecond, uint256 _penaltyPeriod, uint16 _feePercentage) {
        require(_startTime < _endTime && _startTime >= block.timestamp, "Cannot set these start and end times");
        require(_feePercentage <= FEE_DENOMINATOR, "Cannot set fee higher than 100%");
        require(_proportion[0] > 0 && _proportion[1] > 0, "Cannot set these values for proportion");
        STAKE_TOKEN = _stakeToken;
        REWARD_TOKEN = _rewardToken;
        if (_stakeToken[0].decimals() > _stakeToken[1].decimals()) {
            _proportion[0] *= 10 ** (_stakeToken[0].decimals() - _stakeToken[1].decimals());
        }
        else {
            _proportion[1] *= 10 ** (_stakeToken[1].decimals() - _stakeToken[0].decimals());
        }
        PROPORTION = _proportion;
        START_TIME = _startTime;
        lastActionTime = _startTime;
        END_TIME = _endTime;
        REWARD_PER_SECOND = _rewardPerSecond;
        PENALTY_PERIOD = _penaltyPeriod;
        FEE_PERCENTAGE = _feePercentage;
        PRECISION_FACTOR = 10 ** (uint256(30) - uint256(_rewardToken.decimals()));
        feeReceiver = msg.sender;
    }

    function generalInfo() external view returns(IERC20[2] memory, IERC20, uint256, uint256, uint256, uint256, uint16) {
        return (STAKE_TOKEN, REWARD_TOKEN, START_TIME, END_TIME, REWARD_PER_SECOND, PENALTY_PERIOD, FEE_PERCENTAGE);
    }

    function getUserAmounts(address account) external view returns(uint256[2] memory) {
        return stakeInfo[account].amount;
    }

    function pendingReward(address account) external view returns(uint256) {
        if (totalStaked > 0) {
            UserInfo storage stake = stakeInfo[account];
            uint256 adjustedTokenPerShare =
                accTokenPerShare + (((_getMultiplier(lastActionTime, block.timestamp) * REWARD_PER_SECOND) * PRECISION_FACTOR)) / totalStaked;
            return ((stake.amount[0] * adjustedTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        }
        else {
            return 0;
        }
    }

    function setFeeReceiver(address _feeReceiver) external {
        require(msg.sender == feeReceiver, "Not a fee receiver");
        require(_feeReceiver != address(0), "Cannot set zero address");
        feeReceiver = _feeReceiver;
    }

    function withdrawExcessReward() external {
        require(msg.sender == feeReceiver, "Not a fee receiver");
        require(block.timestamp >= END_TIME, "Pool not yet ended");
        require(!excessRewardWithdrawn, "Excess reward already withdrawn");
        excessRewardWithdrawn = true;
        REWARD_TOKEN.safeTransfer(feeReceiver, excessReward());
    }

    function deposit(uint256 amount) external nonReentrant {
        require(block.timestamp >= START_TIME && block.timestamp < END_TIME, "Pool not yet started or already ended");
        require(block.timestamp < END_TIME - PENALTY_PERIOD, "Too late to stake");
        require(amount > 0, "Cannot stake zero");
        UserInfo storage stake = stakeInfo[msg.sender];
        _updatePool();
        STAKE_TOKEN[0].safeTransferFrom(msg.sender, address(this), amount);
        uint256 amountSecond = calculateSecondTokenAmount(stake.amount[0] + amount) - stake.amount[1];
        STAKE_TOKEN[1].safeTransferFrom(msg.sender, address(this), amountSecond);
        uint256 reward = ((stake.amount[0] * accTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        if (reward > 0) {
            REWARD_TOKEN.safeTransfer(msg.sender, reward);
        }
        totalStaked += amount;
        stake.amount[0] += amount;
        stake.amount[1] += amountSecond;
        stake.rewardTaken = ((stake.amount[0] * accTokenPerShare) / PRECISION_FACTOR);
        stake.enteredAt = block.timestamp;
    }

    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage stake = stakeInfo[msg.sender];
        require(stake.amount[0] >= amount, "Cannot withdraw this much");
        _updatePool();
        uint256 toTransfer = ((stake.amount[0] * accTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        if (amount > 0) {
            stake.amount[0] -= amount;
            uint256 amountSecond = stake.amount[1] - calculateSecondTokenAmount(stake.amount[0]);
            stake.amount[1] -= amountSecond;
            totalStaked -= amount;
            if (stake.enteredAt + PENALTY_PERIOD >= block.timestamp) {
                uint256 fee = (amount * FEE_PERCENTAGE) / FEE_DENOMINATOR;
                uint256 feeSecond = (amountSecond * FEE_PERCENTAGE) / FEE_DENOMINATOR;
                STAKE_TOKEN[0].safeTransfer(feeReceiver, fee);
                STAKE_TOKEN[1].safeTransfer(feeReceiver, feeSecond);
                amount -= fee;
                amountSecond -= feeSecond;
            }
            STAKE_TOKEN[0].safeTransfer(msg.sender, amount);
            STAKE_TOKEN[1].safeTransfer(msg.sender, amountSecond);
        }
        if (toTransfer > 0) {
            REWARD_TOKEN.safeTransfer(msg.sender, toTransfer);
        }
        stake.rewardTaken = (stake.amount[0] * accTokenPerShare) / PRECISION_FACTOR;
    }

    function calculateSecondTokenAmount(uint256 amount) public view returns(uint256) {
        return ((amount * PROPORTION[1]) / PROPORTION[0]);
    }

    function excessReward() public view returns(uint256) {
        if (totalStaked == 0) {
            return REWARD_TOKEN.balanceOf(address(this));
        }
        return _excessReward;
    }

    function _updatePool() private {
        if (block.timestamp <= lastActionTime) {
            return;
        }

        if (totalStaked == 0) {
            _excessReward += ((block.timestamp - lastActionTime) * REWARD_PER_SECOND);
            lastActionTime = block.timestamp;
            return;
        }

        uint256 reward = (_getMultiplier(lastActionTime, block.timestamp) * REWARD_PER_SECOND);
        accTokenPerShare += (reward * PRECISION_FACTOR) / totalStaked;
        lastActionTime = block.timestamp;
    }

    function _getMultiplier(uint256 _from, uint256 _to) private view returns(uint256) {
        if (_to <= END_TIME) {
            return _to - _from;
        } else if (_from >= END_TIME) {
            return 0;
        } else {
            return END_TIME - _from;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking20Into20 is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint16 public constant FEE_DENOMINATOR = 10000;

    uint256 public PRECISION_FACTOR;
    uint256 public REWARD_PER_SECOND;
    IERC20 public STAKE_TOKEN;
    IERC20 public REWARD_TOKEN;

    uint256 public PENALTY_PERIOD;
    uint16 public FEE_PERCENTAGE;

    uint256 public START_TIME;
    uint256 public END_TIME;
    uint256 public totalStaked;
    uint256 public accTokenPerShare;

    address public feeReceiver;

    bool public excessRewardWithdrawn;

    uint256 private lastActionTime;
    uint256 private _excessReward;

    mapping (address => UserInfo) public stakeInfo;

    struct UserInfo {
        uint256 amount;
        uint256 rewardTaken;
        uint256 enteredAt;
    }

    constructor(IERC20 _stakeToken, IERC20Metadata _rewardToken, uint256 _startTime, uint256 _endTime, uint256 _rewardPerSecond, uint256 _penaltyPeriod, uint16 _feePercentage) {
        require(_startTime < _endTime && _startTime >= block.timestamp, "Cannot set these start and end times");
        require(_feePercentage <= FEE_DENOMINATOR, "Cannot set fee higher than 100%");
        STAKE_TOKEN = _stakeToken;
        REWARD_TOKEN = _rewardToken;
        START_TIME = _startTime;
        lastActionTime = _startTime;
        END_TIME = _endTime;
        REWARD_PER_SECOND = _rewardPerSecond;
        PENALTY_PERIOD = _penaltyPeriod;
        FEE_PERCENTAGE = _feePercentage;
        PRECISION_FACTOR = 10 ** (uint256(30) - uint256(_rewardToken.decimals()));
        feeReceiver = msg.sender;
    }

    function generalInfo() external view returns(IERC20, IERC20, uint256, uint256, uint256, uint256, uint16) {
        return (STAKE_TOKEN, REWARD_TOKEN, START_TIME, END_TIME, REWARD_PER_SECOND, PENALTY_PERIOD, FEE_PERCENTAGE);
    }

    function pendingReward(address account) external view returns(uint256) {
        if (totalStaked > 0) {
            UserInfo storage stake = stakeInfo[account];
            uint256 adjustedTokenPerShare =
                accTokenPerShare + (((_getMultiplier(lastActionTime, block.timestamp) * REWARD_PER_SECOND) * PRECISION_FACTOR)) / totalStaked;
            return ((stake.amount * adjustedTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        }
        else {
            return 0;
        }
    }

    function setFeeReceiver(address _feeReceiver) external {
        require(msg.sender == feeReceiver, "Not a fee receiver");
        require(_feeReceiver != address(0), "Cannot set zero address");
        feeReceiver = _feeReceiver;
    }

    function withdrawExcessReward() external {
        require(msg.sender == feeReceiver, "Not a fee receiver");
        require(block.timestamp >= END_TIME, "Pool not yet ended");
        require(!excessRewardWithdrawn, "Excess reward already withdrawn");
        excessRewardWithdrawn = true;
        REWARD_TOKEN.safeTransfer(feeReceiver, excessReward());
    }

    function deposit(uint256 amount) external nonReentrant {
        require(block.timestamp >= START_TIME && block.timestamp < END_TIME, "Pool not yet started or already ended");
        require(block.timestamp < END_TIME - PENALTY_PERIOD, "Too late to stake");
        require(amount > 0, "Cannot stake zero");
        UserInfo storage stake = stakeInfo[msg.sender];
        _updatePool();
        STAKE_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        uint256 reward = ((stake.amount * accTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        if (reward > 0) {
            REWARD_TOKEN.safeTransfer(msg.sender, reward);
        }
        totalStaked += amount;
        stake.amount += amount;
        stake.rewardTaken = ((stake.amount * accTokenPerShare) / PRECISION_FACTOR);
        stake.enteredAt = block.timestamp;
    }

    function withdraw(uint256 amount) external nonReentrant {
        UserInfo storage stake = stakeInfo[msg.sender];
        require(stake.amount >= amount, "Cannot withdraw this much");
        _updatePool();
        uint256 toTransfer = ((stake.amount * accTokenPerShare) / PRECISION_FACTOR) - stake.rewardTaken;
        if (amount > 0) {
            stake.amount -= amount;
            totalStaked -= amount;
            if (stake.enteredAt + PENALTY_PERIOD >= block.timestamp) {
                uint256 fee = (amount * FEE_PERCENTAGE) / FEE_DENOMINATOR;
                STAKE_TOKEN.safeTransfer(feeReceiver, fee);
                amount -= fee;
            }
            STAKE_TOKEN.safeTransfer(msg.sender, amount);
        }
        if (toTransfer > 0) {
            REWARD_TOKEN.safeTransfer(msg.sender, toTransfer);
        }
        stake.rewardTaken = (stake.amount * accTokenPerShare) / PRECISION_FACTOR;
    }

    function excessReward() public view returns(uint256) {
        if (totalStaked == 0) {
            return REWARD_TOKEN.balanceOf(address(this));
        }
        return _excessReward;
    }

    function _updatePool() private {
        if (block.timestamp <= lastActionTime) {
            return;
        }

        if (totalStaked == 0) {
            _excessReward += ((block.timestamp - lastActionTime) * REWARD_PER_SECOND);
            lastActionTime = block.timestamp;
            return;
        }

        uint256 reward = (_getMultiplier(lastActionTime, block.timestamp) * REWARD_PER_SECOND);
        accTokenPerShare += (reward * PRECISION_FACTOR) / totalStaked;
        lastActionTime = block.timestamp;
    }

    function _getMultiplier(uint256 _from, uint256 _to) private view returns(uint256) {
        if (_to <= END_TIME) {
            return _to - _from;
        } else if (_from >= END_TIME) {
            return 0;
        } else {
            return END_TIME - _from;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}