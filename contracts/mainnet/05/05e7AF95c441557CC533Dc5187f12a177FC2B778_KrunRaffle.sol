// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KrunRaffle is Ownable {
  bool public paused;
  address private krunAddress;
  uint256 public raffleIndex;
  uint256 public KrunTicketMax;
  uint256 public EthTicketMax;

  constructor() {
    krunAddress = 0x14a47885db4AEE4b83d13e281b2013A18AA75ff4;
    paused = false;
    raffleIndex = 1;
    KrunTicketMax = 1000000000000000000000;
    EthTicketMax = 100;
  }

  // userAddress => raffleIndex => token amount //
  mapping(address => mapping(uint256 => uint256)) userKrunBalance;
  mapping(address => mapping(uint256 => uint256)) userEthBalance;

  // Events //
  event etherDepositComplete(address sender, uint256 value);
  event KrunDepositComplete(address sender, uint256 amount);
  event etherwithdrawComplete(address sender, uint256 amount);
  event KrunWithdrawalComplete(address sender, uint256 amount);

  // Views //
  function getEthBalance() public view returns (uint) {
    return address(this).balance;
  }

  function getKrunBalance() public view returns (uint) {
    return IERC20(krunAddress).balanceOf(address(this));
  }

  function getUserKrunBalance(address user) public view returns (uint) {
    return userKrunBalance[user][raffleIndex];
  }

  function getUserEthBalance(address user) public view returns (uint) {
    return userEthBalance[user][raffleIndex];
  }

  // Functions //
  function setPaused(bool _paused) external onlyOwner {
    paused = _paused;
  }

  function setRaffleIndex(uint256 _raffleIndex) external onlyOwner {
    raffleIndex = _raffleIndex;
  }

  function setKrunTicketMax(uint256 _TicketMax) external onlyOwner {
    KrunTicketMax = _TicketMax;
  }

  function setEthTicketMax(uint256 _TicketMax) external onlyOwner {
    EthTicketMax = _TicketMax;
  }

  function depositEther() public payable {
    require(paused == false, "Contract Paused");
    require(
      msg.sender.balance > msg.value,
      "Your Eth balance is less than deposit amount"
    );
    require(
      userEthBalance[msg.sender][raffleIndex] + msg.value <= EthTicketMax,
      "You have already hit ticket limit"
    );
    userEthBalance[msg.sender][raffleIndex] += msg.value;
    emit etherDepositComplete(msg.sender, msg.value);
  }

  function depositKrun(uint256 amount) public {
    require(paused == false, "Contract Paused");
    require(
      IERC20(krunAddress).balanceOf(msg.sender) >= amount,
      "Your token balance is less than deposit amount"
    );
    require(
      userKrunBalance[msg.sender][raffleIndex] + amount <= KrunTicketMax,
      "You have already hit ticket limit"
    );
    require(
      IERC20(krunAddress).transferFrom(msg.sender, address(this), amount)
    );
    userKrunBalance[msg.sender][raffleIndex] += amount;
    emit KrunDepositComplete(msg.sender, amount);
  }

  function withdrawEther() external onlyOwner {
    require(address(this).balance > 0, "Contract value is zero");
    address payable to = payable(msg.sender);
    uint256 amount = getEthBalance();
    to.transfer(getEthBalance());
    emit etherwithdrawComplete(msg.sender, amount);
  }

  function withdrawKrun() external onlyOwner {
    require(
      IERC20(krunAddress).balanceOf(address(this)) > 0,
      "Contract value is zero"
    );
    uint256 amount = getKrunBalance();
    require(
      IERC20(krunAddress).transfer(msg.sender, amount),
      "Withdraw all has failed"
    );
    emit KrunWithdrawalComplete(msg.sender, amount);
  }

  function tokenRescue(
    IERC20 token,
    address recipient,
    uint256 amount
  ) external onlyOwner {
    token.transfer(recipient, amount);
  }
}