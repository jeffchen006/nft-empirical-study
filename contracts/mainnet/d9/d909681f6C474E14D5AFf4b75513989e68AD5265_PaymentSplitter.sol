//SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

//import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "hardhat/console.sol";

contract PaymentSplitter is Ownable {
    //  using SafeMath for uint256;

    address payable public EC_wallet;
    address payable public AOKI_wallet;
    address payable public METAZOO_wallet;
    uint256 public creator_fee_percentage;

    uint256[] public shares = [70, 180, 750];

    address payable[] wallets = [
        payable(0xA3cB071C94b825471E230ff42ca10094dEd8f7bB), // EC
        payable(0xA807a452e20a766Ea36019bF5bE5c5f4cbDE7563), // AOKI
        payable(0x77b94A55684C95D59A8F56a234B6e555fC79997c) // MetaZoo
    ];

    function setWallets(
        address payable[] memory _wallets,
        uint256[] memory _shares
    ) public onlyOwner {
        require(_wallets.length == _shares.length, "not same lenght");
        wallets = _wallets;
        shares = _shares;
    }

    function _split(uint256 amount) internal {
        // duplicated to save an extra call
        bool sent;
        uint256 _total;
        for (uint256 j = 0; j < wallets.length; j++) {
            uint256 _amount = (amount * shares[j]) / 1000;
            if (j == wallets.length - 1) {
                _amount = amount - _total;
            } else {
                _total += _amount;
            }
            //  console.log(_amount);

            (sent, ) = wallets[j].call{value: _amount}(""); // don't use send or xfer (gas)
            //  console.log(sent);
            require(sent, "Failed to send Ether");
        }
    }

    receive() external payable {
        _split(msg.value);
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