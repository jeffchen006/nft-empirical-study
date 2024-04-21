// Be name khoda
// Bime abolfazl
//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
interface IERC20 {
	function mint(address to, uint256 amount) external;
	function burn(address from, uint256 amount) external;
	function transfer(address recipient, uint256 amount) external returns (bool);
	function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


contract Migrator is Ownable {
	/* ----- state variables --------*/
	address public fromCoin;
	uint256 public ratio;
	uint256 public scale = 1e18;
	uint256 public endBlock;

	/* ----- consturctor -------*/
	constructor (address _fromCoin, uint256 _ratio, uint256 _endBlock) {
		fromCoin = _fromCoin;
		ratio = _ratio;
		endBlock = _endBlock;
	}

	/* ----- modifiers -------*/
	modifier openMigrate {
		require(block.number <= endBlock, "Migration is closed");
		_;
	}

	/* ----- restricted functions -------*/
	function setFromCoin(address _fromCoin) external onlyOwner {
		fromCoin = _fromCoin;
	}

	function setEndBlock(uint256 _endBlock) external onlyOwner {
		endBlock = _endBlock;
	}

	function setRatio(uint256 _ratio) external onlyOwner {
		ratio = _ratio;
	}

	function withdraw(address to, uint256 amount, address token) external onlyOwner {
		IERC20(token).transfer(to, amount);
	}

	/* ----- public functions -------*/
	function migrateFor(address user, uint256 amount, address toCoin) public openMigrate {
		IERC20(fromCoin).transferFrom(msg.sender, address(this), amount);
		IERC20(toCoin).mint(user, amount * ratio / scale);
		emit Migrate(user, amount * ratio / scale);
	}

	function migrate(uint256 amount, address toCoin) external {
		migrateFor(msg.sender, amount, toCoin);
	}

	/* ----- events -------*/
	event Migrate(address user, uint256 amount);
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