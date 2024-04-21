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

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface iCable {
  function mint(address recipient) external;
}

/// @title CABLE Controller
/// @notice https://cable.folia.app
/// @author @okwme / okw.me, artwork by @joanheemskerk / https://w3b4.net/cable-/
/// @dev managing the mint and payments

contract Controller is Ownable {
  bool public paused;
  address public cable;
  address public splitter;
  uint256 public price = 0.111111111111111111 ether;

  event EthMoved(address indexed to, bool indexed success, bytes returnData);

  constructor(address payable splitter_) {
    splitter = splitter_;
  }

  // @dev Throws if called before the cable address is set.
  modifier initialized() {
    require(cable != address(0), "NO CABLE");
    require(splitter != address(0), "NO SPLIT");
    _;
  }

  /// @dev mints cables
  function mint() public payable initialized {
    require(!paused, "PAUSED");
    require(msg.value == price, "WRONG PRICE");
    (bool sent, bytes memory data) = splitter.call{value: msg.value}("");
    emit EthMoved(msg.sender, sent, data);
    iCable(cable).mint(msg.sender);
  }

  /// @dev only the owner can set the splitter address
  function setSplitter(address splitter_) public onlyOwner {
    splitter = splitter_;
  }

  /// @dev only the owner can set the cable address
  function setCable(address cable_) public onlyOwner {
    cable = cable_;
  }

  /// @dev only the owner can set the contract paused
  function setPause(bool paused_) public onlyOwner {
    paused = paused_;
  }

  function setPrice(uint256 price_) public onlyOwner {
    price = price_;
  }

  /// @dev only the owner can mint without paying
  function adminMint(address recipient) public initialized onlyOwner {
    iCable(cable).mint(recipient);
  }

  /// @dev if mint fails to send eth to splitter, admin can recover
  // This should not be necessary but Berlin hardfork broke split before so this
  // is extra precaution. Also allows recovery if users accidentally send eth
  // straight to the contract.
  function recoverUnsuccessfulMintPayment(address payable _to) public onlyOwner {
    (bool sent, bytes memory data) = _to.call{value: address(this).balance}("");
    emit EthMoved(_to, sent, data);
  }
}