// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FayreTokenLocker is Ownable {
    struct LockData {
        uint256 lockId;
        address owner;
        uint256 amount;
        uint256 start;
        uint256 expiration;
    }

    struct BonusData {
        uint256 requiredAmount;
        uint256 bonus;
    }

    event Lock(address indexed owner, uint256 indexed lockId, uint256 indexed amount, LockData lockData);
    event Withdraw(address indexed owner, uint256 indexed lockId, uint256 indexed amount, LockData lockData);
    event Bonus(address indexed owner, uint256 indexed lockId, uint256 indexed bonusAmount, LockData lockData);

    address public tokenAddress;
    mapping(uint256 => LockData) public locksData;
    mapping(address => LockData) public usersLockData;
    uint256 public minLockDuration;
    uint256 public tokensForBonusesAmount;
    BonusData[] public bonusesData;
    uint256 public currentLockId;

    function setTokenAddress(address newTokenAddress) external onlyOwner {
        tokenAddress = newTokenAddress;
    }

    function setMinLockDuration(uint256 newMinLockDuration) external onlyOwner {
        minLockDuration = newMinLockDuration;
    }

    function addTokensBonus(uint256 requiredAmount, uint256 bonus) external onlyOwner {
        for (uint256 i = 0; i < bonusesData.length; i++)
            if (bonusesData[i].requiredAmount == requiredAmount)
                revert("Bonus already present");

        bonusesData.push(BonusData(requiredAmount, bonus));
    }

    function removeTokensBonus(uint256 requiredAmount) external onlyOwner {
        uint256 indexToDelete = type(uint256).max;

        for (uint256 i = 0; i < bonusesData.length; i++)
            if (bonusesData[i].requiredAmount == requiredAmount)
                indexToDelete = i;

        require(indexToDelete != type(uint256).max, "E#16");

        bonusesData[indexToDelete] = bonusesData[bonusesData.length - 1];

        bonusesData.pop();
    }

    function depositTokensForBonuses(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");

        _transferAsset(msg.sender, address(this), amount);

        tokensForBonusesAmount += amount;
    }

    function withdrawTokensForBonuses(uint256 amount) external onlyOwner {
        require(amount > 0, "Invalid amount");

        require(amount <= tokensForBonusesAmount, "Not enough tokens");

        _transferAsset(address(this), msg.sender, amount);

        tokensForBonusesAmount -= amount;
    }

    function lock(uint256 amount) external {
        require(amount > 0, "Invalid amount");

        LockData storage lockData = usersLockData[msg.sender];

        if (lockData.lockId == 0) {
            lockData.lockId = currentLockId++;
            lockData.owner = msg.sender;
        }

        lockData.amount += amount;
        lockData.start = block.timestamp;
        lockData.expiration = lockData.start + minLockDuration;

        locksData[lockData.lockId] = lockData;

        _transferAsset(msg.sender, address(this), amount);

        emit Lock(msg.sender, lockData.lockId, amount, lockData);
    }

    function withdraw() external {
        LockData storage lockData = usersLockData[msg.sender];

        require(lockData.amount > 0, "Already withdrawed");
        require(lockData.expiration < block.timestamp, "Lock not expired");

        uint256 bonusAmount = 0;

        for (uint256 i = 0; i < bonusesData.length; i++)
            if (lockData.amount >= bonusesData[i].requiredAmount)
                if (bonusAmount < bonusesData[i].bonus)
                    bonusAmount = bonusesData[i].bonus;

        uint256 amountToTransfer = lockData.amount;

        lockData.amount = 0;

        locksData[lockData.lockId] = lockData;

        _transferAsset(address(this), msg.sender, amountToTransfer);

        if (bonusAmount > 0) {
            _transferAsset(address(this), msg.sender, bonusAmount);

            tokensForBonusesAmount -= bonusAmount;

            emit Bonus(msg.sender, lockData.lockId, bonusAmount, lockData);
        }

        emit Withdraw(msg.sender, lockData.lockId, amountToTransfer, lockData);
    }

    function _transferAsset(address from, address to, uint256 amount) private {
        if (from == address(this))
            require(IERC20(tokenAddress).transfer(to, amount), "Error during transfer");
        else
            require(IERC20(tokenAddress).transferFrom(from, to, amount), "Error during transfer");
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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