// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintable {
    function mint(address _receiver, uint256 _amount) external;
}

interface IMigrator {
    function migrate(
        address account,
        uint256 total,
        uint256 startTime
    ) external;
}

interface IHodler {
    function add(uint256 amount) external;
}

contract GROVesting is Ownable {
    using SafeERC20 for IERC20;


    uint256 internal constant ONE_YEAR_SECONDS = 31556952; // average year (including leap years) in seconds
    uint256 private constant DEFAULT_MAX_LOCK_PERIOD = ONE_YEAR_SECONDS * 1; // 1 years period
    uint256 public constant PERCENTAGE_DECIMAL_FACTOR = 10000; // BP
    uint256 internal constant TWO_WEEKS = 604800; // two weeks in seconds
    uint256 private lockPeriodFactor = PERCENTAGE_DECIMAL_FACTOR;

    IMintable public distributer;
    // percentage of tokens that are available immediatly when a vesting postiion is created
    uint256 public immutable initUnlockedPercent;
    // Active airdrops and liquidity pools
    mapping(address => bool) public vesters;

    uint256 public totalLockedAmount;
    // vesting actions
    uint256 constant CREATE = 0;
    uint256 constant ADD = 1;
    uint256 constant EXIT = 2;
    uint256 constant EXTEND = 3;

    address public hodlerClaims;

    IMigrator public migrator;

    struct AccountInfo {
        uint256 total;
        uint256 startTime;
    }

    mapping(address => AccountInfo) public accountInfos;
    mapping(address => uint256) public withdrawals;
    // Start time for the global vesting curve
    uint256 public globalStartTime;

    event LogVester(address vester, bool status);
    event LogMaxLockPeriod(uint256 newMaxPeriod);
    event LogNewMigrator(address newMigrator);
    event LogNewDistributer(address newDistributer);
    event LogNewBonusContract(address bonusContract);

    event LogVest(address indexed user, uint256 totalLockedAmount, uint256 amount, AccountInfo vesting);
    event LogExit(address indexed user, uint256 totalLockedAmount, uint256 vesting, uint256 unlocked, uint256 penalty);
    event LogExtend(address indexed user, uint256 newPeriod, AccountInfo newVesting);
    event LogMigrate(address indexed user, AccountInfo vesting);

    constructor(uint256 _initUnlockedPercent) {
        initUnlockedPercent = _initUnlockedPercent;
        globalStartTime = block.timestamp;
    }

    function setDistributer(address _distributer) external onlyOwner {
        distributer = IMintable(_distributer);
        emit LogNewDistributer(_distributer);
    }

    // @notice Estimation for how much groove is in the vesting contract
    // @dev Total groove is estimated by multiplying the total gro amount with the % amount has vested
    //  according to the global vesting curve. As time passes, there will be less global groove, as
    //  each individual users position will vest. The vesting can be estimated by continiously shifting,
    //  The global vesting curves start date (and end date by extension), which gets updated whenever user
    //  interacts with the vesting contract ( see updateGlobalTime )
    function totalGroove() external view returns (uint256) {
        uint256 _maxLock = maxLockPeriod();
        uint256 _globalEndTime = (globalStartTime + _maxLock);
        uint256 _now = block.timestamp;
        if (_now >= _globalEndTime) {
            return 0;
        }

        uint256 total = totalLockedAmount;

        return
            ((total * ((PERCENTAGE_DECIMAL_FACTOR - initUnlockedPercent) * (_globalEndTime - _now))) / _maxLock) /
                PERCENTAGE_DECIMAL_FACTOR;
    }

    // @notice Calculate the start point of the global vesting curve
    // @param amount gro token amount
    // @param startTime users position startTime
    // @param newStartTime users new startime if applicable, 0 otherwise.
    // @param action user interaction with the vesting contract : 0) create/add position 1) exit position 2) extend position
    // @dev The global vesting curve is an estimation to the amount of groove in the contract. The curve dictates a linear decline
    //  of the amount of groove in the contract. As users interact with the contract the start date of the curve gets adjusted to
    //  capture changes in individual users vesting position at that specific point in time. depending on the type of interaction
    //  the user takes, the new curve will be defined as:
    //      Create position:
    //          g_st = g_st * (g_amt - u_amt) / (g_amt) + (u_st * u_amt) / (g_amt)
    //
    //      Add to position:
    //          (g_st * g_amt - u_old_st * u_tot + u_new_st * (u_tot + u_amt)) / (g_amt + u_amt)          
    //          
    //      Exit position:
    //          g_st = g_st + (g_st - u_st) * u_amt / (g_amt)
    //
    //      Extend position:
    //          g_st = g_st + (u_tot * u_st) / (g_amt)
    //
    //      Where:
    //          g_st : global vesting curve start time
    //          u_st : user start time
    //          g_amt : global gro amount
    //          u_amt : user gro amount added
    //          u_tot : user current gro amount
    //
    //  Special care needs to be taken as positions that dont exit will cause this to drift, when a user with an position that
    //  has 'overvested' takes an action, this needs to be accounted for. Unaccounted for drift (users that dont interact with the contract
    //  after their vesting period has expired) will have to be dealt with offchain.
    function updateGlobalTime(
        uint256 amount,
        uint256 startTime,
        uint256 userTotal,
        uint256 newStartTime,
        uint256 action
    ) internal {
        uint256 _totalLockedAmount = totalLockedAmount;
        if (action == CREATE) {
            // When creating a position we need to add the new amount to the global total
            _totalLockedAmount = _totalLockedAmount + amount;
        } else if (action == EXIT) {
            // When exiting we remove from the global total
            _totalLockedAmount = _totalLockedAmount - amount;
        } else if (_totalLockedAmount == userTotal) {
            globalStartTime = startTime;
            return;
        }
        uint256 _globalStartTime = globalStartTime;

        if (_totalLockedAmount == 0) {
            return;
        }

        if (action == ADD) {
            // adding to an existing position
            // formula for calculating add to position, including dealing with any drift caused by over vesting:
            //      (g_st * g_amt - u_old_st * u_tot + u_new_st * (u_tot + u_amt)) / (g_amt + u_amt)
            // this removes the impact of the users old position, and adds in the
            //  new position (user old amount + user added amount) based on the new start date. 
uint256 newWeightedTimeSum = (_globalStartTime * _totalLockedAmount + newStartTime * (userTotal + amount)) - startTime * userTotal;
            globalStartTime = newWeightedTimeSum / (_totalLockedAmount + amount);

        } else if (action == EXIT) {
            // exiting an existing position
            // note that g_amt = prev_g_amt - u_amt
            // g_st = g_st + (g_st - u_st) * u_amt / (g_amt)
            globalStartTime = uint256(
                int256(_globalStartTime) +
                    ((int256(_globalStartTime) - int256(startTime)) * int256(amount)) /
                    int256(_totalLockedAmount)
            );
        } else if (action == EXTEND) {
            // extending an existing position
            // g_st = g_st + (u_tot * (u_new_st - u_st)) / (g_amt)
            globalStartTime = _globalStartTime +
                    (userTotal * (newStartTime - startTime)) /
                    _totalLockedAmount;
        } else {
            // Createing new vesting positions
            // note that g_amt = prev_g_amt + u_amt
            // g_st = g_st + (g_amt - u_amt) / (g_amt) + (u_st * u_amt) / (g_amt)
            globalStartTime =
                (_globalStartTime * (_totalLockedAmount - amount)) /
                _totalLockedAmount +
                (startTime * amount) /
                _totalLockedAmount;
        }
    }

    /// @notice Set the vesting bonus contract
    /// @param _hodlerClaims Address of vesting bonus contract
    function setHodlerClaims(address _hodlerClaims) external onlyOwner {
        hodlerClaims = _hodlerClaims;
        emit LogNewBonusContract(_hodlerClaims);
    }

    /// @notice Get the current max lock period - dictates the end date of users vests
    function maxLockPeriod() public view returns (uint256) {
        return (DEFAULT_MAX_LOCK_PERIOD * lockPeriodFactor) / PERCENTAGE_DECIMAL_FACTOR;
    }

    // Adds a new contract that can create vesting positions
    function setVester(address vester, bool status) public onlyOwner {
        vesters[vester] = status;
        emit LogVester(vester, status);
    }

    /// @notice Sets amount of time the vesting lasts
    /// @param maxPeriodFactor Factor to apply to the vesting period
    function setMaxLockPeriod(uint256 maxPeriodFactor) external onlyOwner {
        // cant extend the vesting period more than 200%
        require(maxPeriodFactor <= 20000, "adjustLockPeriod: newFactor > 20000");
        // max Lock period needs to be longer than a month
        require(maxPeriodFactor * DEFAULT_MAX_LOCK_PERIOD / PERCENTAGE_DECIMAL_FACTOR > TWO_WEEKS * 2, "adjustLockPeriod: newFactor to small");
        lockPeriodFactor = maxPeriodFactor;
        emit LogMaxLockPeriod(maxLockPeriod());
    }

    /// @notice Set the new vesting contract that users can migrate to
    /// @param _migrator Address of new vesting contract
    function setMigrator(address _migrator) external onlyOwner {
        migrator = IMigrator(_migrator);
        emit LogNewMigrator(_migrator);
    }

    /// @notice Create or modify a vesting position
    /// @param account Account which to add vesting position for
    /// @param amount Amount to add to vesting position
    function vest(address account, uint256 amount) external {
        require(vesters[msg.sender], "vest: !vester");
        require(account != address(0), "vest: !account");
        require(amount > 0, "vest: !amount");

        AccountInfo memory ai = accountInfos[account];
        uint256 _maxLock = maxLockPeriod();

        if (ai.startTime == 0) {
            // If no position exists, create a new one
            ai.startTime = block.timestamp;
            updateGlobalTime(amount, ai.startTime, 0, 0, CREATE);
        } else {
            // If a position exists, update user's startdate by weighting current time based on GRO being added
            uint256 newStartTime = (ai.startTime * ai.total + block.timestamp * amount) / (ai.total + amount);
            if (newStartTime + _maxLock <= block.timestamp) {
                newStartTime = block.timestamp - (_maxLock) + TWO_WEEKS;
            }
            updateGlobalTime(amount, ai.startTime, ai.total, newStartTime, ADD);
            ai.startTime = newStartTime;
        }

        // update user position
        ai.total += amount;
        accountInfos[account] = ai;
        totalLockedAmount += amount;

        emit LogVest(account, totalLockedAmount, amount, ai);
    }

    /// @notice Extend vesting period
    /// @param extension extension to current vesting period
    function extend(uint256 extension) external {
        require(extension <= PERCENTAGE_DECIMAL_FACTOR, "extend: extension > 100%");
        AccountInfo storage ai = accountInfos[msg.sender];

        // check if user has a position before extending
        uint256 total = ai.total;
        require(total > 0, "extend: no vesting");

        uint256 _maxLock = maxLockPeriod();
        uint256 startTime = ai.startTime;
        uint256 newPeriod;
        uint256 newStartTime;

        // if the position is over vested, set the extension by moving the start time back from the current
        //  block by (max lock time) - (desired extension).
        if (startTime + _maxLock < block.timestamp) {
            newPeriod = _maxLock - ((_maxLock * extension) / PERCENTAGE_DECIMAL_FACTOR);
            newStartTime = block.timestamp - newPeriod;
        } else {
            newPeriod = (_maxLock * extension) / PERCENTAGE_DECIMAL_FACTOR;
            // Cannot extend pass max lock period, just set startTime to current block
            if (startTime + newPeriod >= block.timestamp) {
                newStartTime = block.timestamp;
            } else {
                newStartTime = startTime + newPeriod;
            }
        }

        ai.startTime = newStartTime;
        accountInfos[msg.sender] = ai;
        // Calculate the difference between the original start time and the new
        updateGlobalTime(0, startTime, total, newStartTime, EXTEND);

        emit LogExtend(msg.sender, newStartTime, ai);
    }

    /// @notice Claim all vested tokens, transfering any unclaimed to the hodler pool
    function exit() external {
        (uint256 total, uint256 unlocked, uint256 startTime, ) = unlockedBalance(msg.sender);
        require(total > 0, "exit: no vesting");
        uint256 penalty = total - unlocked;

        delete accountInfos[msg.sender];
        // record account total withdrawal
        withdrawals[msg.sender] += unlocked;

        updateGlobalTime(total, startTime, 0, 0, EXIT);
        totalLockedAmount -= total;

        if (penalty > 0) {
            IHodler(hodlerClaims).add(penalty);
        }
        distributer.mint(msg.sender, unlocked);

        emit LogExit(msg.sender, totalLockedAmount, total, unlocked, penalty);
    }

    /// @notice Migrate sender's vesting data into a new contract
    function migrate() external {
        require(address(migrator) != address(0), "migrate: !migrator");
        AccountInfo memory ai = accountInfos[msg.sender];
        require(ai.total > 0, "migrate: no vesting");
        migrator.migrate(msg.sender, ai.total, ai.startTime);
        emit LogMigrate(msg.sender, ai);
    }

    /// @notice See the amount of vested assets the account has accumulated
    /// @param account Account to get vested amount for
    function unlockedBalance(address account)
        private
        view
        returns (
            uint256 total,
            uint256 unlocked,
            uint256 startTime,
            uint256 _endTime
        )
    {
        AccountInfo memory ai = accountInfos[account];
        startTime = ai.startTime;
        total = ai.total;
        if (startTime > 0) {
            _endTime = startTime + maxLockPeriod();
            if (_endTime > block.timestamp) {
                unlocked = (total * initUnlockedPercent) / PERCENTAGE_DECIMAL_FACTOR;
                unlocked = unlocked + ((total - unlocked) * 
                                       (block.timestamp - startTime)) / (_endTime - startTime);
            } else {
                unlocked = ai.total;
            }
        }
    }

    /// @notice Get total size of position, vested + vesting
    /// @param account Target account
    function totalBalance(address account) public view returns (uint256 unvested) {
        AccountInfo memory ai = accountInfos[account];
        unvested = ai.total;
    }

    /// @notice Get current unlocked (vested) amount
    /// @param account Target account
    function vestedBalance(address account) external view returns (uint256 unvested) {
        ( , uint256 unlocked, , ) = unlockedBalance(account);
        return unlocked;
    }

    /// @notice Get the current locked (vesting amount
    /// @param account Target account
    function vestingBalance(address account) external view returns (uint256) {
        (uint256 total, uint256 unlocked, , ) = unlockedBalance(account);
        return total - unlocked;
    }

    /// @notice Get total amount of gro minted to user
    /// @param account Target account
    /// @dev As users can exit and create new vesting positions, this will
    ///     tell the user how much gro they've accrued over all.
    function totalWithdrawn(address account) external view returns (uint256) {
        return withdrawals[account];
    }

    /// @notice Get the start and end date for a vesting position
    /// @param account Target account
    /// @dev userfull for showing the amount of time you've got left
    function getVestingDates(address account) external view returns (uint256, uint256) {
        AccountInfo storage ai = accountInfos[account];
        uint256 _startDate = ai.startTime;
        require(_startDate > 0, 'getVestingDates: No active position');
        uint256 _endDate = _startDate + maxLockPeriod();

        return (_startDate, _endDate);
    }
}

// SPDX-License-Identifier: MIT

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
    function transferFrom(
        address sender,
        address recipient,
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

pragma solidity ^0.8.0;

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
        assembly {
            size := extcodesize(account)
        }
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

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}