// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "IERC20.sol";
import "SafeMath.sol";
import "Address.sol";
import "SafeERC20.sol";

import "IProxy.sol";
import "Mintr.sol";
import "FeeDistribution.sol";
import "Gauge.sol";

library SafeProxy {
    function safeExecute(
        IProxy proxy,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        (bool success, ) = proxy.execute(to, value, data);
        require(success);
    }
}

interface VeCRV {
    function increase_unlock_time(uint256 _time) external;
}

contract StrategyProxy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;
    using SafeProxy for IProxy;

    uint256 private constant week = 604800; // Number of seconds in a week
    IProxy public constant proxy = IProxy(0xF147b8125d2ef93FB6965Db97D6746952a133934); // Refer to this as "voter" contract
    address public constant mintr = address(0xd061D61a4d941c39E5453435B6345Dc261C2fcE0);
    address public constant crv = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant gauge = address(0x2F50D538606Fa9EDD2B11E2446BEb18C9D5846bB);
    address public constant yveCRV = address(0xc5bDdf9843308380375a611c18B50Fb9341f502A);
    address public constant CRV3 = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public feeRecipient = address(0xc5bDdf9843308380375a611c18B50Fb9341f502A); // Default value is yveCRV
    FeeDistribution public constant feeDistribution = FeeDistribution(0xA464e6DCda8AC41e03616F95f4BC98a13b8922Dc);
    VeCRV public constant veCRV  = VeCRV(0x5f3b5DfEb7B28CDbD7FAba78963EE202a494e2A2);
    // gauge => strategies
    mapping(address => address) public strategies;
    mapping(address => bool) public voters;
    mapping(address => bool) public lockers;
    address public governance;

    uint256 public lastTimeCursor;

    // Events so that indexers can keep track of key actions
    event GovernanceSet(address governance);
    event FeeRecipientSet(address feeRecipient);
    event StrategyApproved(address gauge, address strategy);
    event StrategyRevoked(address gauge);
    event VoterApproved(address voter);
    event VoterRevoked(address voter);
    event LockerApproved(address locker);
    event LockerRevoked(address locker);
    event AdminFeesClaimed(address _recipient, uint256 amount);

    constructor() public {
        governance = msg.sender;
    }

    /// @notice Set governance address
    /// @param _governance Address to set as governance
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "!governance");
        require(_governance != governance, "already set");
        governance = _governance;
        emit GovernanceSet(_governance);
    }

    /// @notice Set recipient of weekly 3CRV admin fees
    /// @dev Only a single address can be approved at any time
    /// @param _feeRecipient Address to approve for fees
    function setFeeRecipient(address _feeRecipient) external {
        require(msg.sender == governance, "!governance");
        require(_feeRecipient != address(0), "!zeroaddress");
        require(_feeRecipient != feeRecipient, "already set");
        feeRecipient = _feeRecipient;
        emit FeeRecipientSet(_feeRecipient);
    }

    /// @notice Add strategy to a gauge
    /// @param _gauge Gauge to permit strategy on
    /// @param _strategy Strategy to approve on gauge
    function approveStrategy(address _gauge, address _strategy) external {
        require(msg.sender == governance, "!governance");
        require(_strategy != address(0), "disallow zero");
        require(strategies[_gauge] != _strategy, "already approved");
        strategies[_gauge] = _strategy;
        emit StrategyApproved(_gauge, _strategy);
    }

    /// @notice Clear any previously approved strategy to a gauge
    /// @param _gauge Gauge from which to remove strategy
    function revokeStrategy(address _gauge) external {
        require(msg.sender == governance, "!governance");
        require(strategies[_gauge] != address(0), "already revoked");
        strategies[_gauge] = address(0);
        emit StrategyRevoked(_gauge);
    }

    /// @notice Approve an address for voting on gauge weights
    /// @param _voter Voter to add
    function approveVoter(address _voter) external {
        require(msg.sender == governance, "!governance");
        require(!voters[_voter], "already approved");
        voters[_voter] = true;
        emit VoterApproved(_voter);
    }

    /// @notice Remove ability to vote on gauge weights
    /// @param _voter Voter to remove
    function revokeVoter(address _voter) external {
        require(msg.sender == governance, "!governance");
        require(voters[_voter], "already revoked");
        voters[_voter] = false;
        emit VoterRevoked(_voter);
    }

    /// @notice Approve an address for voting on gauge weights
    /// @param _locker Voter to add
    function approveLocker(address _locker) external {
        require(msg.sender == governance, "!governance");
        require(!lockers[_locker], "already approved");
        lockers[_locker] = true;
        emit LockerApproved(_locker);
    }

    /// @notice Remove ability to max lock CRV
    /// @param _locker Locker to remove
    function revokeLocker(address _locker) external {
        require(msg.sender == governance, "!governance");
        require(lockers[_locker], "already revoked");
        lockers[_locker] = false;
        emit LockerRevoked(_locker);
    }

    /// @notice Lock CRV into veCRV contract
    /// @dev Permissionless, anyone is encouraged to call it when CRV is available to lock
    function lock() external {
        uint256 amount = IERC20(crv).balanceOf(address(proxy));
        if (amount > 0) proxy.increaseAmount(amount);
    }

    /// @notice Extend veCRV lock time to maximum amount of 4 years.
    function maxLock() external {
        require(msg.sender == governance || lockers[msg.sender], "!locker");
        proxy.safeExecute(
            address(veCRV), 
            0, 
            abi.encodeWithSignature("increase_unlock_time(uint256)", now + (365 days * 4))
        );
    }

    /// @notice Vote on a gauge
    /// @param _gauge The gauge to vote on
    /// @param _weight Weight to vote with
    function vote(address _gauge, uint256 _weight) external {
        require(msg.sender == governance || voters[msg.sender], "!voter");
        _vote(_gauge, _weight);
    }

    /// @notice Vote on a multiple gauges
    /// @param _gauges List of gauges to vote on
    /// @param _weights List of weight to vote with
    function vote_many(address[] calldata _gauges, uint256[] calldata _weights) external {
        require(msg.sender == governance || voters[msg.sender], "!voter");
        require(_gauges.length == _weights.length, "!mismatch");
        for(uint256 i = 0; i < _gauges.length; i++) {
            _vote(_gauges[i], _weights[i]);
        }
    }

    function _vote(address _gauge, uint256 _weight) internal {
        proxy.safeExecute(gauge, 0, abi.encodeWithSignature("vote_for_gauge_weights(address,uint256)", _gauge, _weight));
    }

    /// @notice Withdraw exact amount of LPs from gauge
    /// @param _gauge The gauge from which to withdraw
    /// @param _token The LP token to withdraw from gauge
    /// @param _amount The exact amount of LPs with withdraw
    function withdraw(
        address _gauge,
        address _token,
        uint256 _amount
    ) public returns (uint256) {
        require(strategies[_gauge] == msg.sender, "!strategy");
        uint256 _balance = IERC20(_token).balanceOf(address(proxy));
        proxy.safeExecute(_gauge, 0, abi.encodeWithSignature("withdraw(uint256)", _amount));
        _balance = IERC20(_token).balanceOf(address(proxy)).sub(_balance);
        proxy.safeExecute(_token, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _balance));
        return _balance;
    }

    /// @notice Find Yearn voter's full balance within a given gauge
    /// @param _gauge The gauge from which to check balance
    function balanceOf(address _gauge) public view returns (uint256) {
        return IERC20(_gauge).balanceOf(address(proxy));
    }

    /// @notice Withdraw full balance of voter's LPs from gauge
    /// @param _gauge The gauge from which to withdraw
    /// @param _token The LP token to withdraw from gauge
    function withdrawAll(address _gauge, address _token) external returns (uint256) {
        return withdraw(_gauge, _token, balanceOf(_gauge));
    }

    /// @notice Takes care of depositing Curve LPs into gauge
    /// @dev Strategy must first transfer LPs to this contract prior to calling
    /// @param _gauge The gauge to deposit LP token into
    /// @param _token The LP token to deposit into gauge
    function deposit(address _gauge, address _token) external {
        require(strategies[_gauge] == msg.sender, "!strategy");
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(address(proxy), _balance);
        _balance = IERC20(_token).balanceOf(address(proxy));

        proxy.safeExecute(_token, 0, abi.encodeWithSignature("approve(address,uint256)", _gauge, 0));
        proxy.safeExecute(_token, 0, abi.encodeWithSignature("approve(address,uint256)", _gauge, _balance));
        proxy.safeExecute(_gauge, 0, abi.encodeWithSignature("deposit(uint256)", _balance));
    }

    /// @notice Abstracts the CRV minting and transfers to an approved strategy with CRV earnings
    /// @dev Designed to be called within the harvest function of a strategy
    /// @param _gauge The gauge which this strategy is claiming CRV from
    function harvest(address _gauge) external {
        require(strategies[_gauge] == msg.sender, "!strategy");
        uint256 _balance = IERC20(crv).balanceOf(address(proxy));
        proxy.safeExecute(mintr, 0, abi.encodeWithSignature("mint(address)", _gauge));
        _balance = (IERC20(crv).balanceOf(address(proxy))).sub(_balance);
        proxy.safeExecute(crv, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, _balance));
    }

    /// @notice Claim share of weekly admin fees from Curve fee distributor
    /// @dev Admin fees become available every Thursday, so we run this expensive logic only once per week.
    /// @param _recipient The address to which we transfer 3CRV
    function claim(address _recipient) external {
        require(msg.sender == feeRecipient, "!approved");
        if (!claimable()) return;

        address p = address(proxy);
        feeDistribution.claim_many([p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p, p]);
        lastTimeCursor = feeDistribution.time_cursor_of(address(proxy));

        uint256 amount = IERC20(CRV3).balanceOf(address(proxy));
        if (amount > 0) {
            proxy.safeExecute(CRV3, 0, abi.encodeWithSignature("transfer(address,uint256)", _recipient, amount));
            emit AdminFeesClaimed(_recipient, amount);
        }
    }

    /// @notice Check if it has been one week since last admin fee claim
    function claimable() public view returns (bool) {
        if (now < lastTimeCursor.add(week)) return false;
        return true;
    }

    /// @notice Claim non-CRV token incentives from the gauge and transfer to strategy
    /// @param _gauge The gauge which this strategy is claiming rewards
    /// @param _token The token to be claimed to the approved strategy
    function claimRewards(address _gauge, address _token) external {
        require(strategies[_gauge] == msg.sender, "!strategy");
        Gauge(_gauge).claim_rewards(address(proxy));
        proxy.safeExecute(_token, 0, abi.encodeWithSignature("transfer(address,uint256)", msg.sender, IERC20(_token).balanceOf(address(proxy))));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

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

pragma solidity ^0.6.0;

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
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
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
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
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
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
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
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
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
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.2;

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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
        return _functionCallWithValue(target, data, 0, errorMessage);
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
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errorMessage) private returns (bytes memory) {
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: weiValue }(data);
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "IERC20.sol";
import "SafeMath.sol";
import "Address.sol";

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

pragma solidity ^0.6.12;

interface IProxy {
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bool, bytes memory);

    function increaseAmount(uint256) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface Mintr {
    function mint(address) external;
}

pragma solidity ^0.6.12;

interface FeeDistribution {
    function claim_many(address[20] calldata) external returns (bool);

    function last_token_time() external view returns (uint256);

    function time_cursor() external view returns (uint256);

    function time_cursor_of(address) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface Gauge {
    function deposit(uint256) external;

    function balanceOf(address) external view returns (uint256);

    function withdraw(uint256) external;

    function claim_rewards(address) external;

    function rewarded_token() external returns (address);

    function reward_tokens(uint256) external returns (address);
}