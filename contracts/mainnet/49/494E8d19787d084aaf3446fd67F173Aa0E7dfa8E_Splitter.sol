// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ISplitter {
    function split() external;
}

contract Splitter is ISplitter, Ownable {
    address public ownerAddress;
    address public devAddress;
    address public charityAddress;

    uint256 public ownerPercentage;
    uint256 public devPercentage;
    uint256 public charityPercentage;

    constructor() {
        ownerAddress = msg.sender;
        devAddress = msg.sender;
        charityAddress = msg.sender;

        ownerPercentage = 60;
        devPercentage = 20;
        charityPercentage = 20;
    }

    function setOwnerAddress(address _addr) public onlyOwner {
        ownerAddress = _addr;
    }

    function setDevAddress(address _addr) public onlyOwner {
        devAddress = _addr;
    }

    function setCharityAddress(address _addr) public onlyOwner {
        charityAddress = _addr;
    }

    function setOwnerPercentage(uint256 _perc) public onlyOwner {
        ownerPercentage = _perc;
    }

    function setDevPercentage(uint256 _perc) public onlyOwner {
        devPercentage = _perc;
    }

    function setCharityPercentage(uint256 _perc) public onlyOwner {
        charityPercentage = _perc;
    }

    fallback() external payable {}

    receive() external payable {}

    function split() external onlyOwner {
        uint256 totBalance = address(this).balance;

        (bool hs1, ) = payable(ownerAddress).call{
            value: (totBalance * ownerPercentage) / 100
        }("");
        require(hs1);

        (bool hs2, ) = payable(devAddress).call{
            value: (totBalance * devPercentage) / 100
        }("");
        require(hs2);

        (bool hs3, ) = payable(charityAddress).call{
            value: (totBalance * charityPercentage) / 100
        }("");
        require(hs3);
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