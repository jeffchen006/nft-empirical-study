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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title ITransferWhitelist
 * @author Limit Break, Inc.
 * @notice Interface for transfer whitelist registries.
 */
interface ITransferWhitelist is IERC165 {

    /// @dev Returns the number of exchanges that are currently in the whitelist
    function getWhitelistedExchangeCount() external view returns (uint256);

    /// @dev Returns true if the specified account is in the whitelist, false otherwise
    function isWhitelistedExchange(address account) external view returns (bool);

    /// @dev Returns true if the caller is permitted to execute a transfer, false otherwise
    function isTransferWhitelisted(address caller) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./ITransferWhitelist.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

error ExchangeIsWhitelisted();
error ExchangeIsNotWhitelisted();

/**
 * @title TransferWhitelistRegistry
 * @author Limit Break, Inc.
 * @notice A simple implementation of a transfer whitelist registry contract.
 * It is highly recommended that the initial contract owner transfers ownership 
 * of this contract to a multi-sig wallet.  The multi-sig may be controlled by
 * the project's preferred governance structure.
 */
contract TransferWhitelistRegistry is ERC165, Ownable, ITransferWhitelist {

    /// @dev Tracks the number of whitelisted exchanges
    uint256 private whitelistedExchangeCount;

    /// @dev Mapping of whitelisted exchange addresses
    mapping (address => bool) private exchangeWhitelist;

    /// @dev Emitted when an address is added to the whitelist
    event ExchangeAddedToWhitelist(address indexed exchange);

    /// @dev Emitted when an address is removed from the whitelist
    event ExchangeRemovedFromWhitelist(address indexed exchange);

    /// @dev ERC-165 interface support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(ITransferWhitelist).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @notice Allows contract owner to whitelist an address.
    /// 
    /// Throws when the specified address is already whitelisted.
    /// Throws when caller is not the contract owner.
    /// 
    /// Postconditions:
    /// ---------------
    /// Whitelisted exchange count is incremented by 1.
    /// Specified address is now whitelisted.
    /// An `ExchangeAddedToWhitelist` event has been emitted.
    function whitelistExchange(address account) external onlyOwner {
        if(exchangeWhitelist[account]) {
            revert ExchangeIsWhitelisted();
        }

        ++whitelistedExchangeCount;
        exchangeWhitelist[account] = true;
        emit ExchangeAddedToWhitelist(account);
    }

    /// @notice Allows contract owner to remove an address from the whitelist.
    /// 
    /// Throws when the specified address is not whitelisted.
    /// Throws when caller is not the contract owner.
    /// 
    /// Postconditions:
    /// ---------------
    /// Whitelisted exchange count is decremented by 1.
    /// Specified address is no longer whitelisted.
    /// An `ExchangeRemovedFromWhitelist` event has been emitted.
    function unwhitelistExchange(address account) external onlyOwner {
        if(!exchangeWhitelist[account]) {
            revert ExchangeIsNotWhitelisted();
        }

        unchecked {
            --whitelistedExchangeCount;
        }

        delete exchangeWhitelist[account];
        emit ExchangeRemovedFromWhitelist(account);
    }

    /// @notice Returns the number of exchanges that are currently in the whitelist
    function getWhitelistedExchangeCount() external view override returns (uint256) {
        return whitelistedExchangeCount;
    }

    /// @notice Returns true if the specified account is in the whitelist, false otherwise
    function isWhitelistedExchange(address account) external view override returns (bool) {
        return exchangeWhitelist[account];
    }

    /// @notice Returns true if the caller is permitted to execute a transfer, false otherwise.
    /// @dev Transfers are unrestricted if the whitelist is empty.
    function isTransferWhitelisted(address caller) external view override returns (bool) {
        return 
        (whitelistedExchangeCount == 0) ||
        (exchangeWhitelist[caller]);
    }

    
}