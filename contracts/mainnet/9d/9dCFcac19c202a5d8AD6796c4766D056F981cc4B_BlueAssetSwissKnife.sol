/**
 *Submitted for verification at Etherscan.io on 2023-03-16
*/

pragma solidity ^0.8.17;


// 
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)
/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// 
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)
/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// 
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)
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
                /// @solidity memory-safe-assembly
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

// 
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
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

//
uint16 constant DENOMINATOR = 10000;

uint256 constant SHARE_DENOMINATOR = 1e36;

// week in seconds
uint256 constant WEEK = 604800;

// 
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
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

// 
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)
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
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// 
interface IAccessControl {
    function addAdmin(address account) external;

    function removeAdmin(address account) external;

    function renounceAdmin() external;

    function isAdmin(address account) external view returns (bool);
}

//
/**
 * @dev Contract module which provides a basic access control mechanism, there
 *  are two levels of access , owner and admin, only owner can add or remove admin.
 */
contract AccessControl is Ownable, IAccessControl {
    mapping(address => bool) private admins;

    event AdminAdded(address indexed account, address indexed sender);
    event AdminRemoved(address indexed account, address indexed sender);

    constructor() {
        admins[_msgSender()] = true;
        emit AdminAdded(_msgSender(), _msgSender());
    }

    modifier onlyAdmin() {
        require(admins[_msgSender()], "!a");
        _;
    }

    function addAdmin(address account) external onlyOwner {
        require(account != address(0), "!0");

        admins[account] = true;
        emit AdminAdded(account, _msgSender());
    }

    function removeAdmin(address account) external onlyOwner {
        require(account != address(0), "!0");
        require(admins[account], "!a");

        admins[account] = false;
        emit AdminRemoved(account, _msgSender());
    }

    function renounceAdmin() external onlyAdmin {
        admins[_msgSender()] = false;
        emit AdminRemoved(_msgSender(), _msgSender());
    }

    function isAdmin(address account) external view returns (bool) {
        return admins[account];
    }
}

//
contract ReferralManagementAccessControl is Context, AccessControl {
    uint16 constant DENOMINATOR = 10000;
    uint16 constant MAX_REFERRAL_PERCENTAGE = 1000; // 10%
    uint16 private referralCommissionRate = 100; // 1%

    mapping(address => address) private _referrers;

    event UserReferrerSet(address indexed user, address indexed referrer);
    event ReceivedComission(
        address indexed user,
        address indexed asset,
        uint256 amount
    );

    constructor() {}

    function setReferralCommissionRate(uint16 _referralCommissionRate)
        external
        onlyAdmin
    {
        require(_referralCommissionRate <= MAX_REFERRAL_PERCENTAGE, "> 10%");
        referralCommissionRate = _referralCommissionRate;
    }

    function setReferrer(address _referrer) external {
        _setReferer(_msgSender(), _referrer);
    }

    function setReferrerFor(address _user, address _referrer)
        external
        onlyAdmin
    {
        _setReferer(_user, _referrer);
    }

    function _setReferer(address _user, address _referrer) internal {
        require(_referrer != address(0), "!0");
        require(_referrer != _user, "!usr");
        require(_referrers[_user] == address(0), "ref_set");
        _referrers[_user] = _referrer;

        emit UserReferrerSet(_user, _referrer);
    }

    function referrerOf(address account) public view returns (address) {
        return _referrers[account];
    }

    function getReferralCommissionRate() public view returns (uint16) {
        return referralCommissionRate;
    }
}

//
//import "hardhat/console.sol";
contract RewardsManager is AccessControl {
    using SafeERC20 for IERC20;

    IERC20 public immutable rewardToken;

    uint256 private _totalRewards = 0;

    uint128 public immutable startTime;
    uint128 private _endTime;

    uint128 private _rewardsPerSec;
    uint128 private _lastEmissionChange;
    uint256 private _totalRewardsBeforeLastChange;
    uint256 private _totalPaidOutRewards;

    event rewardPerSecondChanged(uint256 newRewardPerSec);
    event rewardAdded(uint256 amount);
    event rewardClaimed(address indexed user, uint256 amount);

    constructor(IERC20 _rewardToken, uint128 _startTime) {
        rewardToken = _rewardToken;
        startTime = _startTime;
        _lastEmissionChange = _startTime;
    }

    modifier onlyAfterInit() {
        require(_endTime != 0, "!init");
        _;
    }

    modifier onlyAfterStart() {
        require(block.timestamp > startTime, "!start");
        _;
    }

    /**
     * @dev Funds the contract the contract.
     * @param _amount amount of tokens to fund the contract with
     */
    function fund(uint256 _amount) external onlyAdmin {
        require(_endTime >= block.timestamp || _endTime == 0, "ended");

        rewardToken.safeTransferFrom(_msgSender(), address(this), _amount);

        _totalRewards += _amount;

        uint256 extendedTime = _rewardsPerSec > 0
            ? _amount / _rewardsPerSec
            : type(uint256).max;
        _endTime = uint128(_endTime + extendedTime);

        emit rewardAdded(_amount);
    }

    function _updateRewardsPerSecond(uint256 _newRewardPerSec) internal {
        require(_endTime >= block.timestamp || _endTime == 0, "ended");

        uint256 timePassed = block.timestamp > startTime
            ? block.timestamp - _lastEmissionChange
            : startTime - _lastEmissionChange;
        uint256 rewardsEarned = timePassed * _rewardsPerSec;

        uint256 totalPastRewards = rewardsEarned +
            _totalRewardsBeforeLastChange;

        uint256 newTimeLeft = _newRewardPerSec > 0
            ? (_totalRewards - totalPastRewards) / _newRewardPerSec
            : type(uint128).max;

        _endTime = uint128(
            newTimeLeft < type(uint128).max
                ? (block.timestamp > startTime)
                    ? block.timestamp + newTimeLeft
                    : startTime + newTimeLeft
                : type(uint128).max
        );

        _rewardsPerSec = uint128(_newRewardPerSec);
        _totalRewardsBeforeLastChange += rewardsEarned;
        _lastEmissionChange += uint128(timePassed);

        emit rewardPerSecondChanged(_newRewardPerSec);
    }

    function setEndTime(uint256 endTime) external onlyAdmin {
        require(endTime >= block.timestamp, "passed");

        require(endTime > startTime && endTime < _endTime, "invalid");

        uint256 delta = _endTime - endTime;
        uint256 leftRewards = delta * _rewardsPerSec;

        rewardToken.safeTransfer(owner(), leftRewards);
        _endTime = uint128(endTime);
        _totalRewards -= leftRewards;
    }

    function _sendReward(address _user, uint256 _amount) internal {
        rewardToken.safeTransfer(_user, _amount);
        _totalPaidOutRewards += _amount;
        emit rewardClaimed(_user, _amount);
    }

    function getEndTime() public view returns (uint256) {
        return _endTime;
    }

    function rewardsPerSec() public view returns (uint256) {
        return _rewardsPerSec;
    }

    function totalRewards() public view returns (uint256) {
        return _totalRewards;
    }

    function totalPaidout() public view returns (uint256) {
        return _totalPaidOutRewards;
    }
}

// 
struct PoolInfo {
    IERC20 token; // 20 bytes so we left with 12 bytes
    uint128 multiplier;
    uint128 lastRewardsTime;
    uint128 totalStaked;
    uint128 weightedStake;
    uint256 accERC20PerShare;
}

contract PoolsManager is RewardsManager {
    using SafeERC20 for IERC20;

    PoolInfo[] private _pools;

    uint128 private _totalMultipliers;

    constructor(IERC20 _rewardToken, uint128 _startTime)
        RewardsManager(_rewardToken, _startTime)
    {}

    function addPool(IERC20 __token, uint128 _multiplier) external onlyAdmin {
        massUpdatePools();

        uint256 currentTime = block.timestamp > startTime
            ? block.timestamp
            : startTime;

        _pools.push(
            PoolInfo(__token, _multiplier, uint128(currentTime), 0, 0, 0)
        );

        _totalMultipliers += _multiplier;
    }

    function updatePool(uint256 _pid) public {
        // we calculate the total rewards generated for this pool since the last time we updated it
        PoolInfo storage pool = _pools[_pid];
        uint256 currentTime = block.timestamp < getEndTime()
            ? block.timestamp
            : getEndTime();

        if (currentTime <= pool.lastRewardsTime) {
            return;
        }

        if (pool.weightedStake == 0) {
            pool.lastRewardsTime = uint128(currentTime);
            return;
        }

        uint256 totalRewardsGenerated = (currentTime - pool.lastRewardsTime) *
            rewardsPerSec();
        uint256 rewardsForThisPool = _totalMultipliers > 0
            ? (totalRewardsGenerated * pool.multiplier) / _totalMultipliers
            : 0;

        pool.accERC20PerShare +=
            (rewardsForThisPool * SHARE_DENOMINATOR) /
            pool.weightedStake;
        pool.lastRewardsTime = uint128(currentTime);
    }

    function massUpdatePools() public {
        uint256 length = _pools.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updateMultiplier(uint256 _pid, uint128 _multiplier)
        external
        onlyAdmin
    {
        massUpdatePools();
        _totalMultipliers += _multiplier;
        _totalMultipliers -= _pools[_pid].multiplier;
        _pools[_pid].multiplier = _multiplier;
    }

    function _addStake(
        uint256 _pid,
        uint256 _amount,
        uint256 weightedAmount
    ) internal {
        _pools[_pid].totalStaked += uint128(_amount);
        _pools[_pid].weightedStake += uint128(weightedAmount);
    }

    function _removeStake(
        uint256 _pid,
        uint256 _amount,
        uint256 weightedAmount
    ) internal {
        _pools[_pid].totalStaked -= uint128(_amount);
        _pools[_pid].weightedStake -= uint128(weightedAmount);
    }

    function poolsLength() external view returns (uint256) {
        return _pools.length;
    }

    function poolInfo(uint256 _pid) public view returns (PoolInfo memory) {
        return _pools[_pid];
    }

    function _accPerShare(uint256 pid) internal view returns (uint256) {
        return _pools[pid].accERC20PerShare;
    }

    function _token(uint256 pid) internal view returns (IERC20) {
        return _pools[pid].token;
    }

    function totalMultipliers() public view returns (uint128) {
        return _totalMultipliers;
    }
}

//
contract FeeCollectorAccessControl is AccessControl {
    uint16 private _fee = 100; // 1%
    address private _feeCollector;

    event feeCollected(
        address indexed user,
        address indexed asset,
        uint256 amount
    );

    constructor() {
        _feeCollector = _msgSender();
    }

    function setFee(uint16 fee) external onlyAdmin {
        _fee = fee;
    }

    function getFee() public view returns (uint16) {
        return _fee;
    }

    function getFeeCollector() public view returns (address) {
        return _feeCollector;
    }

    function setFeeCollector(address feeCollector) external onlyAdmin {
        require(feeCollector != address(0), "!0");
        _feeCollector = feeCollector;
    }
}

// 
//import "hardhat/console.sol";
struct UserInfo {
    uint128 weightedAmount; // How many tokens the user has provided.
    uint128 unlockedAmount; // How many tokens the user has unlocked.
    uint128 rewardsReserves; // Rewards that were not claimed yet
    uint128 rewardDebt; // Reward debt. See explanation below.
}

struct UserDeposit {
    uint128 amount; // the amount deposited
    uint64 lockTime; // this the time this deposit will be unlocked and available for withdrawal
    uint64 lockWeeks; // boost will boost = 1 + (weeks * (week +1) / 2 + 24)
}

contract UserDepositManager is
    PoolsManager,
    ReferralManagementAccessControl,
    FeeCollectorAccessControl
{
    using SafeERC20 for IERC20;

    // Info of each user that stakes LP tokens.
    // pid => user => UserInfo
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    mapping(uint256 => mapping(address => UserDeposit[])) public userDeposits;

    // user => harvester => bool
    mapping(address => mapping(address => bool)) public approveHarvester;

    event Deposit(address indexed user, uint256 amount);
    event Locked(
        address indexed user,
        uint256 amount,
        uint256 lockTime,
        uint256 lockWeeks
    );
    event Withdraw(address indexed user, uint256 amount);
    event Unlocked(
        address indexed user,
        uint256 amount,
        uint256 lockTime,
        uint256 lockWeeks
    );
    event Harvest(address indexed user, uint256 amount);

    constructor(IERC20 _token, uint128 _startTime)
        PoolsManager(_token, _startTime)
    {}

    function depositFor(
        address _user,
        uint128 _pid,
        uint128 _amount,
        uint16 _weeks,
        bool _harvest,
        address _referrer
    ) external {
        _deposit(
            _user,
            _msgSender(),
            _pid,
            _amount,
            _weeks,
            _harvest,
            _referrer
        );
    }

    function deposit(
        uint128 _pid,
        uint128 _amount,
        uint16 _weeks,
        bool _harvest,
        address _referrer
    ) external {
        _deposit(
            _msgSender(),
            _msgSender(),
            _pid,
            _amount,
            _weeks,
            _harvest,
            _referrer
        );
    }

    function _deposit(
        address _user,
        address _caller,
        uint128 _pid,
        uint128 _amount,
        uint16 _weeks,
        bool _harvest,
        address _referrer
    ) internal onlyAfterInit onlyAfterStart {
        require(_weeks < 54);
        require(_amount > 0);
        //PoolInfo memory pool = poolInfo(_pid);
        IERC20 token = _token(_pid);

        // we transfer the staked amount to the contract
        token.safeTransferFrom(_caller, address(this), _amount);

        // setReferrer if not already set
        address referrer = referrerOf(_user);

        // if referrer is not set, set it
        if (referrer == address(0) && _referrer != address(0)) {
            _setReferer(_user, _referrer);
            referrer = _referrer;
        }

        // if no referrer set feeCollector as referrer
        if (referrer == address(0)) {
            referrer = getFeeCollector();
        }

        // calculate fees
        uint256 adminFee = getFee();
        uint256 referralFee = getReferralCommissionRate();

        uint256 adminFeeAmount = (_amount * adminFee) / DENOMINATOR;
        uint256 referralFeeAmount = (_amount * referralFee) / DENOMINATOR;
        uint256 amount = _amount - adminFeeAmount - referralFeeAmount;

        if (adminFeeAmount > 0) {
            _deposit(
                _pid,
                getFeeCollector(),
                uint128(adminFeeAmount),
                0,
                false
            );
            emit feeCollected(_user, address(token), adminFeeAmount);
        }
        if (referralFeeAmount > 0) {
            _deposit(_pid, referrer, uint128(referralFeeAmount), 0, false);
            emit ReceivedComission(referrer, address(token), referralFeeAmount);
        }

        _deposit(_pid, _user, uint128(amount), _weeks, _harvest);
    }

    function unstakeUnlockedAmount(uint256 _pid, uint256 _amount)
        external
        onlyAfterInit
    {
        require(_amount > 0);

        UserInfo storage user = userInfo[_pid][_msgSender()];
        //require(user.unlockedAmount >= _amount, "unlockedAmount < _amount");

        updatePool(_pid);

        _harvestRewards(_pid, _msgSender(), _accPerShare(_pid), true);

        user.unlockedAmount -= uint128(_amount);
        user.weightedAmount -= uint128(_amount);

        _removeStake(_pid, uint128(_amount), uint128(_amount));
        user.rewardDebt = uint128(
            (user.weightedAmount * _accPerShare(_pid)) / SHARE_DENOMINATOR
        );
        // we make the transfer last here to make sure if re-entered the state would already have been changed
        _token(_pid).safeTransfer(_msgSender(), _amount);
        emit Withdraw(_msgSender(), _amount);
    }

    function unstakeUnlockedDeposit(uint256 _pid, uint256 index) external {
        UserDeposit[] storage deposits = userDeposits[_pid][_msgSender()];

        UserDeposit storage userDeposit = deposits[index];

        uint64 lockWeeks = userDeposit.lockWeeks;
        require(
            userDeposit.lockTime + WEEK * lockWeeks <= block.timestamp ||
                getEndTime() <= block.timestamp,
            "!lcked"
        );

        UserInfo storage user = userInfo[_pid][_msgSender()];

        updatePool(_pid);

        _harvestRewards(_pid, _msgSender(), _accPerShare(_pid), true);

        uint256 amount = userDeposit.amount;
        /*
        uint256 boost = DENOMINATOR *
            1 +
            ((DENOMINATOR * lockWeeks * (lockWeeks + 1)) /
                2 +
                24);*/
        uint256 boost = 1 + lockWeeks;
        uint256 weightedAmount = amount * boost;

        user.weightedAmount -= uint128(weightedAmount);
        user.rewardDebt = uint128(
            (user.weightedAmount * _accPerShare(_pid)) / SHARE_DENOMINATOR
        );

        // emit event before we delite the deposit
        emit Unlocked(_msgSender(), amount, userDeposit.lockTime, lockWeeks);

        // remove deposit
        deposits[index] = deposits[deposits.length - 1];
        deposits.pop();

        _removeStake(_pid, uint128(amount), uint128(weightedAmount));
        _token(_pid).safeTransfer(_msgSender(), amount);
    }

    function _deposit(
        uint256 _pid,
        address _user,
        uint128 _amount,
        uint256 _weeks,
        bool _harvest
    ) internal {
        UserInfo storage user = userInfo[_pid][_user];
        updatePool(_pid);
        uint256 accPerShare = _accPerShare(_pid);

        if (user.weightedAmount > 0) {
            _harvestRewards(_pid, _user, accPerShare, _harvest); // harvest rewards
        }
        /*
        uint256 boost = DENOMINATOR +
            ((DENOMINATOR * _weeks * (_weeks + 1)) / 2 + 24);
            */
        uint256 boost = 1 + _weeks;
        uint256 weightedAmount = (_amount * boost);
        if (_weeks > 0) {
            userDeposits[_pid][_user].push(
                UserDeposit(_amount, uint64(block.timestamp), uint64(_weeks))
            );
            emit Locked(_user, _amount, block.timestamp, _weeks);
        } else {
            user.unlockedAmount += uint128(_amount);
            emit Deposit(_user, _amount);
        }
        user.weightedAmount += uint128(weightedAmount);
        user.rewardDebt = uint128(
            (user.weightedAmount * accPerShare) / SHARE_DENOMINATOR
        );
        _addStake(_pid, _amount, weightedAmount);
    }

    function harvest(uint256 pid) external onlyAfterInit {
        updatePool(pid);
        address _user = _msgSender();
        _harvestRewards(pid, _user, _accPerShare(pid), true);

        UserInfo storage user = userInfo[pid][_user];
        user.rewardDebt = uint128(
            (user.weightedAmount * _accPerShare(pid)) / SHARE_DENOMINATOR
        );
    }

    function pendingFor(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_pid][_user];
        PoolInfo memory pool = poolInfo(_pid);

        uint256 currentTime = block.timestamp < getEndTime()
            ? block.timestamp
            : getEndTime();

        uint256 generatedRewards = ((currentTime - pool.lastRewardsTime) *
            rewardsPerSec() *
            pool.multiplier) / totalMultipliers();

        uint256 accPerShare = pool.accERC20PerShare +
            (generatedRewards * SHARE_DENOMINATOR) /
            pool.weightedStake;

        return
            (user.weightedAmount * accPerShare) /
            SHARE_DENOMINATOR -
            user.rewardDebt +
            user.rewardsReserves;
    }

    function _harvestRewards(
        uint256 _pid,
        address _user,
        uint256 _accPerShare,
        bool _harvest
    ) internal {
        UserInfo storage user = userInfo[_pid][_user];
        //uint256 accPerShare = _accPerShare(_pid);
        uint256 pending = (user.weightedAmount * _accPerShare) /
            SHARE_DENOMINATOR -
            user.rewardDebt;

        if ((pending > 0 || user.rewardsReserves > 0) && _harvest) {
            _sendReward(_user, pending + user.rewardsReserves); // send rewards to user
            user.rewardsReserves = 0;
            emit Harvest(_user, pending);
        } else {
            user.rewardsReserves += uint128(pending); // add rewards to reserves
        }
    }

    function userDepositsLength(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        return userDeposits[_pid][_user].length;
    }
}

//
//import "hardhat/console.sol";
contract BlueAssetSwissKnife is UserDepositManager {
    constructor(IERC20 _rewardToken, uint128 _startTime)
        UserDepositManager(_rewardToken, _startTime)
    {}

    function updateRewardsPerSec(uint256 rewards) external onlyAdmin {
        massUpdatePools();
        _updateRewardsPerSecond(rewards);
    }
}