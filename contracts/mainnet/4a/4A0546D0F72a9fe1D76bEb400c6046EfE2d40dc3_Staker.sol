pragma solidity 0.5.16;

// import "openzeppelin-solidity2/contracts/GSN/Context.sol";
// import "openzeppelin-solidity2/contracts/token/ERC20/IERC20.sol";
// import "openzeppelin-solidity2/contracts/math/SafeMath.sol";
// import "openzeppelin-solidity2/contracts/utils/Address.sol";
// import "openzeppelin-solidity2/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity2/GSN/Context.sol";
import "openzeppelin-solidity2/token/ERC20/IERC20.sol";
import "openzeppelin-solidity2/math/SafeMath.sol";
import "openzeppelin-solidity2/utils/Address.sol";
import "openzeppelin-solidity2/ownership/Ownable.sol";

contract Staker is Ownable {
  using SafeMath for uint256;
  using Address for address;

  IERC20 public f9token;
  IERC20 public dao9token;
  mapping(address => mapping(address => uint256)) _tokenBalances;
  mapping(address => uint256) _unlockTime;
  mapping(address => bool) _isIDO;
  mapping(address => bool) _isF9Staked;
  mapping(address => bool) _isDAO9Staked;
  mapping(address => uint256) _dao9Tier;
  bool public f9Halted;
  bool public dao9Halted;
  uint256[3] public dao9Tiers = [999 * 10**18, 4999 * 10**18, 9999 * 10**18];
  uint256[3] public dao9TiersStaked = [0, 0, 0];
  uint256[3] public dao9TiersMax = [100, 100, 100];

  event updateDAO9StakeCapacity(
    uint256 lowTierMax,
    uint256 middleTierMax,
    uint256 highTierMax,
    uint256 timestamp
  );
  event haltF9Staking(bool f9Halted, uint256 timestamp);
  event haltDAO9Staking(bool dao9Halted, uint256 timestamp);
  event addIDOManager(address indexed account, uint256 timestamp);
  event Stake(address indexed account, uint256 timestamp, uint256 value);
  event Unstake(address indexed account, uint256 timestamp, uint256 value);
  event Lock(address indexed account, uint256 timestamp, uint256 unlockTime, address locker);

  constructor(address _f9, address _dao9token) public {
    f9token = IERC20(_f9);
    dao9token = IERC20(_dao9token);
    dao9Halted = true;
  }

  function stakedBalance(IERC20 token, address account) external view returns (uint256) {
    return _tokenBalances[address(token)][account];
  }

  function unlockTime(address account) external view returns (uint256) {
    return _unlockTime[account];
  }

  function isIDO(address account) external view returns (bool) {
    return _isIDO[account];
  }

  /**
   * @dev Returns a boolean for whether a user has staked F9
   *
   * @param account address for which to check status
   * @return bool - true if user has staked F9
   */
  function isF9Staked(address account) external view returns (bool) {
    return _isF9Staked[account];
  }

  function isDAO9Staked(address account) external view returns (bool) {
    return _isDAO9Staked[account];
  }

  function updateDAO9Tiers(
    uint256 lowTier,
    uint256 middleTier,
    uint256 highTier
  ) external onlyIDO {
    dao9Tiers = [lowTier, middleTier, highTier];
  }

  function updateDAO9TiersMax(
    uint256 lowTierMax,
    uint256 middleTierMax,
    uint256 highTierMax
  ) external onlyOwner {
    dao9TiersMax = [lowTierMax, middleTierMax, highTierMax];
    emit updateDAO9StakeCapacity(lowTierMax, middleTierMax, highTierMax, now);
  }

  function _stake(IERC20 token, uint256 value) internal {
    token.transferFrom(_msgSender(), address(this), value);
    _tokenBalances[address(token)][_msgSender()] = _tokenBalances[address(token)][_msgSender()].add(
      value
    );
    emit Stake(_msgSender(), now, value);
  }

  function _unstake(IERC20 token, uint256 value) internal {
    _tokenBalances[address(token)][_msgSender()] = _tokenBalances[address(token)][_msgSender()].sub(
      value,
      "Staker: insufficient staked balance"
    );
    token.transfer(_msgSender(), value);
    emit Unstake(_msgSender(), now, value);
  }

  /**
   * @dev User calls this function to stake DAO9
   */
  function dao9Stake(uint256 tier) external notDAO9Halted {
    require(
      dao9token.balanceOf(_msgSender()) >= dao9Tiers[tier],
      "Staker: Stake amount exceeds wallet DAO9 balance"
    );
    require(dao9TiersStaked[tier] < dao9TiersMax[tier], "Staker: Pool is full");
    require(_isDAO9Staked[_msgSender()] == false, "Staker: User already staked DAO9");
    require(_isF9Staked[_msgSender()] == false, "Staker: User staked in F9 pool");
    _isDAO9Staked[_msgSender()] = true;
    _dao9Tier[_msgSender()] = tier;
    dao9TiersStaked[tier] += 1;
    _stake(dao9token, dao9Tiers[tier]);
  }

  /**
   * @dev User calls this function to stake F9
   */
  function f9Stake(uint256 value) external notF9Halted {
    require(value > 0, "Staker: unstake value should be greater than 0");
    require(
      f9token.balanceOf(_msgSender()) >= value,
      "Staker: Stake amount exceeds wallet F9 balance"
    );
    require(_isDAO9Staked[_msgSender()] == false, "Staker: User staked in DAO9 pool");
    _isF9Staked[_msgSender()] = true;
    _stake(f9token, value);
  }

  function dao9Unstake() external lockable {
    uint256 _tier = _dao9Tier[_msgSender()];
    require(
      _tokenBalances[address(dao9token)][_msgSender()] > 0,
      "Staker: insufficient staked DAO9"
    );
    dao9TiersStaked[_tier] -= 1;
    _isDAO9Staked[_msgSender()] = false;
    _unstake(dao9token, _tokenBalances[address(dao9token)][_msgSender()]);
  }

  function f9Unstake(uint256 value) external lockable {
    require(value > 0, "Staker: unstake value should be greater than 0");
    require(
      _tokenBalances[address(f9token)][_msgSender()] >= value,
      "Staker: insufficient staked F9 balance"
    );
    _unstake(f9token, value);
    if (_tokenBalances[address(f9token)][_msgSender()] == 0) {
      _isF9Staked[_msgSender()] = false;
    }
  }

  function lock(address user, uint256 unlockAt) external onlyIDO {
    require(unlockAt > now, "Staker: unlock is in the past");
    if (_unlockTime[user] < unlockAt) {
      _unlockTime[user] = unlockAt;
      emit Lock(user, now, unlockAt, _msgSender());
    }
  }

  function f9Halt(bool status) external onlyOwner {
    f9Halted = status;
    emit haltF9Staking(status, now);
  }

  function dao9Halt(bool status) external onlyOwner {
    dao9Halted = status;
    emit haltDAO9Staking(status, now);
  }

  function addIDO(address account) external onlyOwner {
    require(account != address(0), "Staker: cannot be zero address");
    _isIDO[account] = true;
    emit addIDOManager(account, now);
  }

  modifier onlyIDO() {
    require(_isIDO[_msgSender()], "Staker: only IDOs can lock");
    _;
  }

  modifier lockable() {
    require(_unlockTime[_msgSender()] <= now, "Staker: account is locked");
    _;
  }

  modifier notF9Halted() {
    require(!f9Halted, "Staker: F9 deposits are paused");
    _;
  }

  modifier notDAO9Halted() {
    require(!dao9Halted, "Staker: DAO9 deposits are paused");
    _;
  }
}

pragma solidity ^0.5.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

pragma solidity ^0.5.0;

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
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
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
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

pragma solidity ^0.5.0;

import "../GSN/Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity ^0.5.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
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

pragma solidity ^0.5.5;

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
     * @dev Converts an `address` into `address payable`. Note that this is
     * simply a type cast: the actual underlying value is not changed.
     *
     * _Available since v2.4.0._
     */
    function toPayable(address account) internal pure returns (address payable) {
        return address(uint160(account));
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
     *
     * _Available since v2.4.0._
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        // solhint-disable-next-line avoid-call-value
        (bool success, ) = recipient.call.value(amount)("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}