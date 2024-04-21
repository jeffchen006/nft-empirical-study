// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Context.sol";
import "Ownable.sol";
import "ReentrancyGuard.sol";
import "IERC20.sol";

contract MoonBagVault is Context, Ownable, ReentrancyGuard {

	address public moonAddress;

	struct Bag {
		uint256 date; // when the bag was created
		uint256 amount; // the amount locked in the bag
	}
	mapping(address => uint256) private _balance;
	mapping(address => uint256) private _availableBalance;
	mapping(address => Bag[]) private _bags;
	mapping(address => uint256) private _bagsLastUpdated;

	uint256 private _totalLocked;

	constructor(address _moonAddress) {
		moonAddress = _moonAddress;
	}
	
	function lock(address account, uint256 amount) public nonReentrant {
		require(
			_msgSender() == account || _msgSender() == moonAddress,
			"Cannot lock on behalf of another account."
		);

		IERC20(moonAddress).transferFrom(account, address(this), amount);
		_balance[account] += amount;
		_totalLocked += amount;
		_bags[account].push(Bag(block.timestamp, amount));
	}

	function balanceOf(address account) public view returns (uint256) {
		return _balance[account];
	}

	function availableBalance(address account) public view returns (uint256) {
		uint newlyAvailable = 0;
		Bag[] storage arr = _bags[account];
		for (uint i = 0; i < arr.length; i++) {
			uint256 currentWeek = (block.timestamp - arr[i].date) / 604800;
			uint256 lastUpdateWeek = (_bagsLastUpdated[account] > arr[i].date)
				? (_bagsLastUpdated[account] - arr[i].date) / 604800
				: 0;
			if (currentWeek > 3) currentWeek = 4;
			uint256 releases = currentWeek - lastUpdateWeek;
			if (releases == 0) continue;
			newlyAvailable += releases * (arr[i].amount / 4);
			if (currentWeek == 4) {
				newlyAvailable += arr[i].amount - 4 * (arr[i].amount / 4);
			}
		}
		return _availableBalance[account] + newlyAvailable;
	}

	function lockedBalance(address account) public view returns (uint256) {
		return balanceOf(account) - availableBalance(account);
	}

	function withdraw(uint256 amount) public nonReentrant {
		_processReleases(_msgSender());
		require(_availableBalance[_msgSender()] >= amount, "Not enough MOON available to withdraw.");
		IERC20(moonAddress).transfer(_msgSender(), amount);
		_availableBalance[_msgSender()] -= amount;
		_balance[_msgSender()] -= amount;
		_totalLocked -= amount;
	}

	function showBags(address account) public view returns (Bag[] memory) {
		return _bags[account];
	}

	function _processReleases(address account) private {
		uint removed = 0;
		Bag[] storage arr = _bags[account];
		for (uint i = 0; i < arr.length; i++) {
			if (removed > 0)
				arr[i - removed] = arr[i];
			uint256 currentWeek = (block.timestamp - arr[i].date) / 604800;
			uint256 lastUpdateWeek = (_bagsLastUpdated[account] > arr[i].date)
				? (_bagsLastUpdated[account] - arr[i].date) / 604800
				: 0;
			if (currentWeek > 3) currentWeek = 4;
			uint256 releases = currentWeek - lastUpdateWeek;
			if (releases == 0)
				continue;
			_availableBalance[account] += releases * (arr[i].amount / 4);
			if (currentWeek == 4) {
				_availableBalance[account] += arr[i].amount - 4 * (arr[i].amount / 4);
				removed++;
			}
		}
		for (uint i = 0; i < removed; i++)
			arr.pop();
		_bagsLastUpdated[account] = block.timestamp;
		_bags[account] = arr;
	}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "Context.sol";
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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

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