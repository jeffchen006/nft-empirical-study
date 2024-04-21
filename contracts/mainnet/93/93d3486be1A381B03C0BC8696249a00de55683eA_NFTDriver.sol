// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (metatx/ERC2771Context.sol)

pragma solidity ^0.8.9;

import "../utils/Context.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771Context is Context {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address private immutable _trustedForwarder;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address trustedForwarder) {
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == _trustedForwarder;
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.0;

import "../Proxy.sol";
import "./ERC1967Upgrade.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeacon.sol";
import "../../interfaces/draft-IERC1822.sol";
import "../../utils/Address.sol";
import "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822.sol";
import "../ERC1967/ERC1967Upgrade.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is IERC1822Proxiable, ERC1967Upgrade {
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate the implementation's compatibility when performing an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

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
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.2) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _ownerOf(tokenId);
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner or approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId, 1);

        // Check that tokenId was not minted by `_beforeTokenTransfer` hook
        require(!_exists(tokenId), "ERC721: token already minted");

        unchecked {
            // Will not overflow unless all 2**256 token ids are minted to the same owner.
            // Given that tokens are minted one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch minting.
            // The ERC fails to describe this case.
            _balances[to] += 1;
        }

        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId, 1);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId, 1);

        // Update ownership in case tokenId was transferred by `_beforeTokenTransfer` hook
        owner = ERC721.ownerOf(tokenId);

        // Clear approvals
        delete _tokenApprovals[tokenId];

        unchecked {
            // Cannot overflow, as that would require more tokens to be burned/transferred
            // out than the owner initially received through minting and transferring in.
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId, 1);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId, 1);

        // Check that tokenId was not transferred by `_beforeTokenTransfer` hook
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");

        // Clear approvals from the previous owner
        delete _tokenApprovals[tokenId];

        unchecked {
            // `_balances[from]` cannot overflow for the same reason as described in `_burn`:
            // `from`'s balance is the number of token held, which is at least one before the current
            // transfer.
            // `_balances[to]` could overflow in the conditions described in `_mint`. That would require
            // all 2**256 token ids to be minted, which in practice is impossible.
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId, 1);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting and burning. If {ERC721Consecutive} is
     * used, the hook may be called as part of a consecutive (batch) mint, as indicated by `batchSize` greater than 1.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens were transferred to `to`.
     * - When `from` is zero, the tokens were minted for `to`.
     * - When `to` is zero, ``from``'s tokens were burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual {}

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * WARNING: Anyone calling this MUST ensure that the balances remain consistent with the ownership. The invariant
     * being that for any address `a` the value returned by `balanceOf(a)` must be equal to the number of tokens such
     * that `ownerOf(tokenId)` is `a`.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __unsafe_increaseBalance(address account, uint256 amount) internal {
        _balances[account] += amount;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC721/extensions/ERC721Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "../../../utils/Context.sol";

/**
 * @title ERC721 Burnable Token
 * @dev ERC721 Token that can be burned (destroyed).
 */
abstract contract ERC721Burnable is Context, ERC721 {
    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator.
     */
    function burn(uint256 tokenId) public virtual {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _burn(tokenId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
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
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

/// @notice A drips receiver
struct DripsReceiver {
    /// @notice The user ID.
    uint256 userId;
    /// @notice The drips configuration.
    DripsConfig config;
}

/// @notice The sender drips history entry, used when squeezing drips.
struct DripsHistory {
    /// @notice Drips receivers list hash, see `_hashDrips`.
    /// If it's non-zero, `receivers` must be empty.
    bytes32 dripsHash;
    /// @notice The drips receivers. If it's non-empty, `dripsHash` must be `0`.
    /// If it's empty, this history entry will be skipped when squeezing drips
    /// and `dripsHash` will be used when verifying the drips history validity.
    /// Skipping a history entry allows cutting gas usage on analysis
    /// of parts of the drips history which are not worth squeezing.
    /// The hash of an empty receivers list is `0`, so when the sender updates
    /// their receivers list to be empty, the new `DripsHistory` entry will have
    /// both the `dripsHash` equal to `0` and the `receivers` empty making it always skipped.
    /// This is fine, because there can't be any funds to squeeze from that entry anyway.
    DripsReceiver[] receivers;
    /// @notice The time when drips have been configured
    uint32 updateTime;
    /// @notice The maximum end time of drips
    uint32 maxEnd;
}

/// @notice Describes a drips configuration.
/// It's a 256-bit integer constructed by concatenating the configuration parameters:
/// `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`.
/// `dripId` is an arbitrary number used to identify a drip.
/// It's a part of the configuration but the protocol doesn't use it.
/// `amtPerSec` is the amount per second being dripped. Must never be zero.
/// It must have additional `Drips._AMT_PER_SEC_EXTRA_DECIMALS` decimals and can have fractions.
/// To achieve that its value must be multiplied by `Drips._AMT_PER_SEC_MULTIPLIER`.
/// `start` is the timestamp when dripping should start.
/// If zero, use the timestamp when drips are configured.
/// `duration` is the duration of dripping.
/// If zero, drip until balance runs out.
type DripsConfig is uint256;

using DripsConfigImpl for DripsConfig global;

library DripsConfigImpl {
    /// @notice Create a new DripsConfig.
    /// @param dripId_ An arbitrary number used to identify a drip.
    /// It's a part of the configuration but the protocol doesn't use it.
    /// @param amtPerSec_ The amount per second being dripped. Must never be zero.
    /// It must have additional `Drips._AMT_PER_SEC_EXTRA_DECIMALS` decimals and can have fractions.
    /// To achieve that the passed value must be multiplied by `Drips._AMT_PER_SEC_MULTIPLIER`.
    /// @param start_ The timestamp when dripping should start.
    /// If zero, use the timestamp when drips are configured.
    /// @param duration_ The duration of dripping.
    /// If zero, drip until balance runs out.
    function create(uint32 dripId_, uint160 amtPerSec_, uint32 start_, uint32 duration_)
        internal
        pure
        returns (DripsConfig)
    {
        // By assignment we get `config` value:
        // `zeros (224 bits) | dripId (32 bits)`
        uint256 config = dripId_;
        // By bit shifting we get `config` value:
        // `zeros (64 bits) | dripId (32 bits) | zeros (160 bits)`
        // By bit masking we get `config` value:
        // `zeros (64 bits) | dripId (32 bits) | amtPerSec (160 bits)`
        config = (config << 160) | amtPerSec_;
        // By bit shifting we get `config` value:
        // `zeros (32 bits) | dripId (32 bits) | amtPerSec (160 bits) | zeros (32 bits)`
        // By bit masking we get `config` value:
        // `zeros (32 bits) | dripId (32 bits) | amtPerSec (160 bits) | start (32 bits)`
        config = (config << 32) | start_;
        // By bit shifting we get `config` value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | zeros (32 bits)`
        // By bit masking we get `config` value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        config = (config << 32) | duration_;
        return DripsConfig.wrap(config);
    }

    /// @notice Extracts dripId from a `DripsConfig`
    function dripId(DripsConfig config) internal pure returns (uint32) {
        // `config` has value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        // By bit shifting we get value:
        // `zeros (224 bits) | dripId (32 bits)`
        // By casting down we get value:
        // `dripId (32 bits)`
        return uint32(DripsConfig.unwrap(config) >> 224);
    }

    /// @notice Extracts amtPerSec from a `DripsConfig`
    function amtPerSec(DripsConfig config) internal pure returns (uint160) {
        // `config` has value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        // By bit shifting we get value:
        // `zeros (64 bits) | dripId (32 bits) | amtPerSec (160 bits)`
        // By casting down we get value:
        // `amtPerSec (160 bits)`
        return uint160(DripsConfig.unwrap(config) >> 64);
    }

    /// @notice Extracts start from a `DripsConfig`
    function start(DripsConfig config) internal pure returns (uint32) {
        // `config` has value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        // By bit shifting we get value:
        // `zeros (32 bits) | dripId (32 bits) | amtPerSec (160 bits) | start (32 bits)`
        // By casting down we get value:
        // `start (32 bits)`
        return uint32(DripsConfig.unwrap(config) >> 32);
    }

    /// @notice Extracts duration from a `DripsConfig`
    function duration(DripsConfig config) internal pure returns (uint32) {
        // `config` has value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        // By casting down we get value:
        // `duration (32 bits)`
        return uint32(DripsConfig.unwrap(config));
    }

    /// @notice Compares two `DripsConfig`s.
    /// First compares `dripId`s, then `amtPerSec`s, then `start`s and finally `duration`s.
    /// @return isLower True if `config` is strictly lower than `otherConfig`.
    function lt(DripsConfig config, DripsConfig otherConfig) internal pure returns (bool isLower) {
        // Both configs have value:
        // `dripId (32 bits) | amtPerSec (160 bits) | start (32 bits) | duration (32 bits)`
        // Comparing them as integers is equivalent to comparing their fields from left to right.
        return DripsConfig.unwrap(config) < DripsConfig.unwrap(otherConfig);
    }
}

/// @notice Drips can keep track of at most `type(int128).max`
/// which is `2 ^ 127 - 1` units of each asset.
/// It's up to the caller to guarantee that this limit is never exceeded,
/// failing to do so may result in a total protocol collapse.
abstract contract Drips {
    /// @notice Maximum number of drips receivers of a single user.
    /// Limits cost of changes in drips configuration.
    uint256 internal constant _MAX_DRIPS_RECEIVERS = 100;
    /// @notice The additional decimals for all amtPerSec values.
    uint8 internal constant _AMT_PER_SEC_EXTRA_DECIMALS = 9;
    /// @notice The multiplier for all amtPerSec values. It's `10 ** _AMT_PER_SEC_EXTRA_DECIMALS`.
    uint160 internal constant _AMT_PER_SEC_MULTIPLIER = 1_000_000_000;
    /// @notice The total amount the contract can keep track of each asset.
    uint256 internal constant _MAX_TOTAL_DRIPS_BALANCE = uint128(type(int128).max);
    /// @notice On every timestamp `T`, which is a multiple of `cycleSecs`, the receivers
    /// gain access to drips received during `T - cycleSecs` to `T - 1`.
    /// Always higher than 1.
    // slither-disable-next-line naming-convention
    uint32 internal immutable _cycleSecs;
    /// @notice The minimum amtPerSec of a drip. It's 1 token per cycle.
    // slither-disable-next-line naming-convention
    uint160 internal immutable _minAmtPerSec;
    /// @notice The storage slot holding a single `DripsStorage` structure.
    bytes32 private immutable _dripsStorageSlot;

    /// @notice Emitted when the drips configuration of a user is updated.
    /// @param userId The user ID.
    /// @param assetId The used asset ID
    /// @param receiversHash The drips receivers list hash
    /// @param dripsHistoryHash The drips history hash which was valid right before the update.
    /// @param balance The new drips balance. These funds will be dripped to the receivers.
    /// @param maxEnd The maximum end time of drips, when funds run out.
    /// If funds run out after the timestamp `type(uint32).max`, it's set to `type(uint32).max`.
    /// If the balance is 0 or there are no receivers, it's set to the current timestamp.
    event DripsSet(
        uint256 indexed userId,
        uint256 indexed assetId,
        bytes32 indexed receiversHash,
        bytes32 dripsHistoryHash,
        uint128 balance,
        uint32 maxEnd
    );

    /// @notice Emitted when a user is seen in a drips receivers list.
    /// @param receiversHash The drips receivers list hash
    /// @param userId The user ID.
    /// @param config The drips configuration.
    event DripsReceiverSeen(
        bytes32 indexed receiversHash, uint256 indexed userId, DripsConfig config
    );

    /// @notice Emitted when drips are received.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param amt The received amount.
    /// @param receivableCycles The number of cycles which still can be received.
    event ReceivedDrips(
        uint256 indexed userId, uint256 indexed assetId, uint128 amt, uint32 receivableCycles
    );

    /// @notice Emitted when drips are squeezed.
    /// @param userId The squeezing user ID.
    /// @param assetId The used asset ID.
    /// @param senderId The ID of the user sending drips which are squeezed.
    /// @param amt The squeezed amount.
    /// @param dripsHistoryHashes The history hashes of all squeezed drips history entries.
    /// Each history hash matches `dripsHistoryHash` emitted in its `DripsSet`
    /// when the squeezed drips configuration was set.
    /// Sorted in the oldest drips configuration to the newest.
    event SqueezedDrips(
        uint256 indexed userId,
        uint256 indexed assetId,
        uint256 indexed senderId,
        uint128 amt,
        bytes32[] dripsHistoryHashes
    );

    struct DripsStorage {
        /// @notice User drips states.
        mapping(uint256 assetId => mapping(uint256 userId => DripsState)) states;
    }

    struct DripsState {
        /// @notice The drips history hash, see `_hashDripsHistory`.
        bytes32 dripsHistoryHash;
        /// @notice The next squeezable timestamps.
        /// Each `N`th element of the array is the next squeezable timestamp
        /// of the `N`th sender's drips configuration in effect in the current cycle.
        mapping(uint256 userId => uint32[2 ** 32]) nextSqueezed;
        /// @notice The drips receivers list hash, see `_hashDrips`.
        bytes32 dripsHash;
        /// @notice The next cycle to be received
        uint32 nextReceivableCycle;
        /// @notice The time when drips have been configured for the last time
        uint32 updateTime;
        /// @notice The maximum end time of drips
        uint32 maxEnd;
        /// @notice The balance when drips have been configured for the last time
        uint128 balance;
        /// @notice The number of drips configurations seen in the current cycle
        uint32 currCycleConfigs;
        /// @notice The changes of received amounts on specific cycle.
        /// The keys are cycles, each cycle `C` becomes receivable on timestamp `C * cycleSecs`.
        /// Values for cycles before `nextReceivableCycle` are guaranteed to be zeroed.
        /// This means that the value of `amtDeltas[nextReceivableCycle].thisCycle` is always
        /// relative to 0 or in other words it's an absolute value independent from other cycles.
        mapping(uint32 cycle => AmtDelta) amtDeltas;
    }

    struct AmtDelta {
        /// @notice Amount delta applied on this cycle
        int128 thisCycle;
        /// @notice Amount delta applied on the next cycle
        int128 nextCycle;
    }

    /// @param cycleSecs The length of cycleSecs to be used in the contract instance.
    /// Low value makes funds more available by shortening the average time of funds being frozen
    /// between being taken from the users' drips balances and being receivable by their receivers.
    /// High value makes receiving cheaper by making it process less cycles for a given time range.
    /// Must be higher than 1.
    /// @param dripsStorageSlot The storage slot to holding a single `DripsStorage` structure.
    constructor(uint32 cycleSecs, bytes32 dripsStorageSlot) {
        require(cycleSecs > 1, "Cycle length too low");
        _cycleSecs = cycleSecs;
        _minAmtPerSec = (_AMT_PER_SEC_MULTIPLIER + cycleSecs - 1) / cycleSecs;
        _dripsStorageSlot = dripsStorageSlot;
    }

    /// @notice Receive drips from unreceived cycles of the user.
    /// Received drips cycles won't need to be analyzed ever again.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param maxCycles The maximum number of received drips cycles.
    /// If too low, receiving will be cheap, but may not cover many cycles.
    /// If too high, receiving may become too expensive to fit in a single transaction.
    /// @return receivedAmt The received amount
    function _receiveDrips(uint256 userId, uint256 assetId, uint32 maxCycles)
        internal
        returns (uint128 receivedAmt)
    {
        uint32 receivableCycles;
        uint32 fromCycle;
        uint32 toCycle;
        int128 finalAmtPerCycle;
        (receivedAmt, receivableCycles, fromCycle, toCycle, finalAmtPerCycle) =
            _receiveDripsResult(userId, assetId, maxCycles);
        if (fromCycle != toCycle) {
            DripsState storage state = _dripsStorage().states[assetId][userId];
            state.nextReceivableCycle = toCycle;
            mapping(uint32 cycle => AmtDelta) storage amtDeltas = state.amtDeltas;
            unchecked {
                for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                    delete amtDeltas[cycle];
                }
                // The next cycle delta must be relative to the last received cycle, which deltas
                // got zeroed. In other words the next cycle delta must be an absolute value.
                if (finalAmtPerCycle != 0) {
                    amtDeltas[toCycle].thisCycle += finalAmtPerCycle;
                }
            }
        }
        emit ReceivedDrips(userId, assetId, receivedAmt, receivableCycles);
    }

    /// @notice Calculate effects of calling `_receiveDrips` with the given parameters.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param maxCycles The maximum number of received drips cycles.
    /// If too low, receiving will be cheap, but may not cover many cycles.
    /// If too high, receiving may become too expensive to fit in a single transaction.
    /// @return receivedAmt The amount which would be received
    /// @return receivableCycles The number of cycles which would still be receivable after the call
    /// @return fromCycle The cycle from which funds would be received
    /// @return toCycle The cycle to which funds would be received
    /// @return amtPerCycle The amount per cycle when `toCycle` starts.
    function _receiveDripsResult(uint256 userId, uint256 assetId, uint32 maxCycles)
        internal
        view
        returns (
            uint128 receivedAmt,
            uint32 receivableCycles,
            uint32 fromCycle,
            uint32 toCycle,
            int128 amtPerCycle
        )
    {
        unchecked {
            (fromCycle, toCycle) = _receivableDripsCyclesRange(userId, assetId);
            if (toCycle - fromCycle > maxCycles) {
                receivableCycles = toCycle - fromCycle - maxCycles;
                toCycle -= receivableCycles;
            }
            mapping(uint32 cycle => AmtDelta) storage amtDeltas =
                _dripsStorage().states[assetId][userId].amtDeltas;
            for (uint32 cycle = fromCycle; cycle < toCycle; cycle++) {
                AmtDelta memory amtDelta = amtDeltas[cycle];
                amtPerCycle += amtDelta.thisCycle;
                receivedAmt += uint128(amtPerCycle);
                amtPerCycle += amtDelta.nextCycle;
            }
        }
    }

    /// @notice Counts cycles from which drips can be received.
    /// This function can be used to detect that there are
    /// too many cycles to analyze in a single transaction.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @return cycles The number of cycles which can be flushed
    function _receivableDripsCycles(uint256 userId, uint256 assetId)
        internal
        view
        returns (uint32 cycles)
    {
        unchecked {
            (uint32 fromCycle, uint32 toCycle) = _receivableDripsCyclesRange(userId, assetId);
            return toCycle - fromCycle;
        }
    }

    /// @notice Calculates the cycles range from which drips can be received.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @return fromCycle The cycle from which funds can be received
    /// @return toCycle The cycle to which funds can be received
    function _receivableDripsCyclesRange(uint256 userId, uint256 assetId)
        private
        view
        returns (uint32 fromCycle, uint32 toCycle)
    {
        fromCycle = _dripsStorage().states[assetId][userId].nextReceivableCycle;
        toCycle = _cycleOf(_currTimestamp());
        // slither-disable-next-line timestamp
        if (fromCycle == 0 || toCycle < fromCycle) {
            toCycle = fromCycle;
        }
    }

    /// @notice Receive drips from the currently running cycle from a single sender.
    /// It doesn't receive drips from the previous, finished cycles, to do that use `_receiveDrips`.
    /// Squeezed funds won't be received in the next calls to `_squeezeDrips` or `_receiveDrips`.
    /// Only funds dripped before `block.timestamp` can be squeezed.
    /// @param userId The ID of the user receiving drips to squeeze funds for.
    /// @param assetId The used asset ID.
    /// @param senderId The ID of the user sending drips to squeeze funds from.
    /// @param historyHash The sender's history hash which was valid right before
    /// they set up the sequence of configurations described by `dripsHistory`.
    /// @param dripsHistory The sequence of the sender's drips configurations.
    /// It can start at an arbitrary past configuration, but must describe all the configurations
    /// which have been used since then including the current one, in the chronological order.
    /// Only drips described by `dripsHistory` will be squeezed.
    /// If `dripsHistory` entries have no receivers, they won't be squeezed.
    /// @return amt The squeezed amount.
    function _squeezeDrips(
        uint256 userId,
        uint256 assetId,
        uint256 senderId,
        bytes32 historyHash,
        DripsHistory[] memory dripsHistory
    ) internal returns (uint128 amt) {
        unchecked {
            uint256 squeezedNum;
            uint256[] memory squeezedRevIdxs;
            bytes32[] memory historyHashes;
            uint256 currCycleConfigs;
            (amt, squeezedNum, squeezedRevIdxs, historyHashes, currCycleConfigs) =
                _squeezeDripsResult(userId, assetId, senderId, historyHash, dripsHistory);
            bytes32[] memory squeezedHistoryHashes = new bytes32[](squeezedNum);
            DripsState storage state = _dripsStorage().states[assetId][userId];
            uint32[2 ** 32] storage nextSqueezed = state.nextSqueezed[senderId];
            for (uint256 i = 0; i < squeezedNum; i++) {
                // `squeezedRevIdxs` are sorted from the newest configuration to the oldest,
                // but we need to consume them from the oldest to the newest.
                uint256 revIdx = squeezedRevIdxs[squeezedNum - i - 1];
                squeezedHistoryHashes[i] = historyHashes[historyHashes.length - revIdx];
                nextSqueezed[currCycleConfigs - revIdx] = _currTimestamp();
            }
            uint32 cycleStart = _currCycleStart();
            _addDeltaRange(
                state, cycleStart, cycleStart + 1, -int160(amt * _AMT_PER_SEC_MULTIPLIER)
            );
            emit SqueezedDrips(userId, assetId, senderId, amt, squeezedHistoryHashes);
        }
    }

    /// @notice Calculate effects of calling `_squeezeDrips` with the given parameters.
    /// See its documentation for more details.
    /// @param userId The ID of the user receiving drips to squeeze funds for.
    /// @param assetId The used asset ID.
    /// @param senderId The ID of the user sending drips to squeeze funds from.
    /// @param historyHash The sender's history hash which was valid right before `dripsHistory`.
    /// @param dripsHistory The sequence of the sender's drips configurations.
    /// @return amt The squeezed amount.
    /// @return squeezedNum The number of squeezed history entries.
    /// @return squeezedRevIdxs The indexes of the squeezed history entries.
    /// The indexes are reversed, meaning that to get the actual index in an array,
    /// they must counted from the end of arrays, as in `arrayLength - squeezedRevIdxs[i]`.
    /// These indexes can be safely used to access `dripsHistory`, `historyHashes`
    /// and `nextSqueezed` regardless of their lengths.
    /// `squeezeRevIdxs` is sorted ascending, from pointing at the most recent entry to the oldest.
    /// @return historyHashes The history hashes valid for squeezing each of `dripsHistory` entries.
    /// In other words history hashes which had been valid right before each drips
    /// configuration was set, matching `dripsHistoryHash` emitted in its `DripsSet`.
    /// The first item is always equal to `historyHash`.
    /// @return currCycleConfigs The number of the sender's
    /// drips configurations which have been seen in the current cycle.
    /// This is also the number of used entries in each of the sender's `nextSqueezed` arrays.
    function _squeezeDripsResult(
        uint256 userId,
        uint256 assetId,
        uint256 senderId,
        bytes32 historyHash,
        DripsHistory[] memory dripsHistory
    )
        internal
        view
        returns (
            uint128 amt,
            uint256 squeezedNum,
            uint256[] memory squeezedRevIdxs,
            bytes32[] memory historyHashes,
            uint256 currCycleConfigs
        )
    {
        {
            DripsState storage sender = _dripsStorage().states[assetId][senderId];
            historyHashes = _verifyDripsHistory(historyHash, dripsHistory, sender.dripsHistoryHash);
            // If the last update was not in the current cycle,
            // there's only the single latest history entry to squeeze in the current cycle.
            currCycleConfigs = 1;
            // slither-disable-next-line timestamp
            if (sender.updateTime >= _currCycleStart()) currCycleConfigs = sender.currCycleConfigs;
        }
        squeezedRevIdxs = new uint256[](dripsHistory.length);
        uint32[2 ** 32] storage nextSqueezed =
            _dripsStorage().states[assetId][userId].nextSqueezed[senderId];
        uint32 squeezeEndCap = _currTimestamp();
        unchecked {
            for (uint256 i = 1; i <= dripsHistory.length && i <= currCycleConfigs; i++) {
                DripsHistory memory drips = dripsHistory[dripsHistory.length - i];
                if (drips.receivers.length != 0) {
                    uint32 squeezeStartCap = nextSqueezed[currCycleConfigs - i];
                    if (squeezeStartCap < _currCycleStart()) squeezeStartCap = _currCycleStart();
                    if (squeezeStartCap < drips.updateTime) squeezeStartCap = drips.updateTime;
                    if (squeezeStartCap < squeezeEndCap) {
                        squeezedRevIdxs[squeezedNum++] = i;
                        amt += _squeezedAmt(userId, drips, squeezeStartCap, squeezeEndCap);
                    }
                }
                squeezeEndCap = drips.updateTime;
            }
        }
    }

    /// @notice Verify a drips history and revert if it's invalid.
    /// @param historyHash The user's history hash which was valid right before `dripsHistory`.
    /// @param dripsHistory The sequence of the user's drips configurations.
    /// @param finalHistoryHash The history hash at the end of `dripsHistory`.
    /// @return historyHashes The history hashes valid for squeezing each of `dripsHistory` entries.
    /// In other words history hashes which had been valid right before each drips
    /// configuration was set, matching `dripsHistoryHash`es emitted in `DripsSet`.
    /// The first item is always equal to `historyHash` and `finalHistoryHash` is never included.
    function _verifyDripsHistory(
        bytes32 historyHash,
        DripsHistory[] memory dripsHistory,
        bytes32 finalHistoryHash
    ) private pure returns (bytes32[] memory historyHashes) {
        historyHashes = new bytes32[](dripsHistory.length);
        for (uint256 i = 0; i < dripsHistory.length; i++) {
            DripsHistory memory drips = dripsHistory[i];
            bytes32 dripsHash = drips.dripsHash;
            if (drips.receivers.length != 0) {
                require(dripsHash == 0, "Entry with hash and receivers");
                dripsHash = _hashDrips(drips.receivers);
            }
            historyHashes[i] = historyHash;
            historyHash = _hashDripsHistory(historyHash, dripsHash, drips.updateTime, drips.maxEnd);
        }
        // slither-disable-next-line incorrect-equality,timestamp
        require(historyHash == finalHistoryHash, "Invalid drips history");
    }

    /// @notice Calculate the amount squeezable by a user from a single drips history entry.
    /// @param userId The ID of the user to squeeze drips for.
    /// @param dripsHistory The squeezed history entry.
    /// @param squeezeStartCap The squeezed time range start.
    /// @param squeezeEndCap The squeezed time range end.
    /// @return squeezedAmt The squeezed amount.
    function _squeezedAmt(
        uint256 userId,
        DripsHistory memory dripsHistory,
        uint32 squeezeStartCap,
        uint32 squeezeEndCap
    ) private view returns (uint128 squeezedAmt) {
        unchecked {
            DripsReceiver[] memory receivers = dripsHistory.receivers;
            // Binary search for the `idx` of the first occurrence of `userId`
            uint256 idx = 0;
            for (uint256 idxCap = receivers.length; idx < idxCap;) {
                uint256 idxMid = (idx + idxCap) / 2;
                if (receivers[idxMid].userId < userId) {
                    idx = idxMid + 1;
                } else {
                    idxCap = idxMid;
                }
            }
            uint32 updateTime = dripsHistory.updateTime;
            uint32 maxEnd = dripsHistory.maxEnd;
            uint256 amt = 0;
            for (; idx < receivers.length; idx++) {
                DripsReceiver memory receiver = receivers[idx];
                if (receiver.userId != userId) break;
                (uint32 start, uint32 end) =
                    _dripsRange(receiver, updateTime, maxEnd, squeezeStartCap, squeezeEndCap);
                amt += _drippedAmt(receiver.config.amtPerSec(), start, end);
            }
            return uint128(amt);
        }
    }

    /// @notice Current user drips state.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @return dripsHash The current drips receivers list hash, see `_hashDrips`
    /// @return dripsHistoryHash The current drips history hash, see `_hashDripsHistory`.
    /// @return updateTime The time when drips have been configured for the last time
    /// @return balance The balance when drips have been configured for the last time
    /// @return maxEnd The current maximum end time of drips
    function _dripsState(uint256 userId, uint256 assetId)
        internal
        view
        returns (
            bytes32 dripsHash,
            bytes32 dripsHistoryHash,
            uint32 updateTime,
            uint128 balance,
            uint32 maxEnd
        )
    {
        DripsState storage state = _dripsStorage().states[assetId][userId];
        return
            (state.dripsHash, state.dripsHistoryHash, state.updateTime, state.balance, state.maxEnd);
    }

    /// @notice User's drips balance at a given timestamp
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param currReceivers The current drips receivers list.
    /// It must be exactly the same as the last list set for the user with `_setDrips`.
    /// @param timestamp The timestamps for which balance should be calculated.
    /// It can't be lower than the timestamp of the last call to `setDrips`.
    /// If it's bigger than `block.timestamp`, then it's a prediction assuming
    /// that `setDrips` won't be called before `timestamp`.
    /// @return balance The user balance on `timestamp`
    function _balanceAt(
        uint256 userId,
        uint256 assetId,
        DripsReceiver[] memory currReceivers,
        uint32 timestamp
    ) internal view returns (uint128 balance) {
        DripsState storage state = _dripsStorage().states[assetId][userId];
        require(timestamp >= state.updateTime, "Timestamp before the last update");
        _verifyDripsReceivers(currReceivers, state);
        return _calcBalance(state.balance, state.updateTime, state.maxEnd, currReceivers, timestamp);
    }

    /// @notice Calculates the drips balance at a given timestamp.
    /// @param lastBalance The balance when drips have started
    /// @param lastUpdate The timestamp when drips have started.
    /// @param maxEnd The maximum end time of drips
    /// @param receivers The list of drips receivers.
    /// @param timestamp The timestamps for which balance should be calculated.
    /// It can't be lower than `lastUpdate`.
    /// If it's bigger than `block.timestamp`, then it's a prediction assuming
    /// that `setDrips` won't be called before `timestamp`.
    /// @return balance The user balance on `timestamp`
    function _calcBalance(
        uint128 lastBalance,
        uint32 lastUpdate,
        uint32 maxEnd,
        DripsReceiver[] memory receivers,
        uint32 timestamp
    ) private view returns (uint128 balance) {
        unchecked {
            balance = lastBalance;
            for (uint256 i = 0; i < receivers.length; i++) {
                DripsReceiver memory receiver = receivers[i];
                (uint32 start, uint32 end) = _dripsRange({
                    receiver: receiver,
                    updateTime: lastUpdate,
                    maxEnd: maxEnd,
                    startCap: lastUpdate,
                    endCap: timestamp
                });
                balance -= uint128(_drippedAmt(receiver.config.amtPerSec(), start, end));
            }
        }
    }

    /// @notice Sets the user's drips configuration.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param currReceivers The current drips receivers list.
    /// It must be exactly the same as the last list set for the user with `_setDrips`.
    /// If this is the first update, pass an empty array.
    /// @param balanceDelta The drips balance change being applied.
    /// Positive when adding funds to the drips balance, negative to removing them.
    /// @param newReceivers The list of the drips receivers of the user to be set.
    /// Must be sorted, deduplicated and without 0 amtPerSecs.
    /// @param maxEndHint1 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The first hint for finding the maximum end time when all drips stop due to funds
    /// running out after the balance is updated and the new receivers list is applied.
    /// Hints have no effect on the results of calling this function, except potentially saving gas.
    /// Hints are Unix timestamps used as the starting points for binary search for the time
    /// when funds run out in the range of timestamps from the current block's to `2^32`.
    /// Hints lower than the current timestamp are ignored.
    /// You can provide zero, one or two hints. The order of hints doesn't matter.
    /// Hints are the most effective when one of them is lower than or equal to
    /// the last timestamp when funds are still dripping, and the other one is strictly larger
    /// than that timestamp,the smaller the difference between such hints, the higher gas savings.
    /// The savings are the highest possible when one of the hints is equal to
    /// the last timestamp when funds are still dripping, and the other one is larger by 1.
    /// It's worth noting that the exact timestamp of the block in which this function is executed
    /// may affect correctness of the hints, especially if they're precise.
    /// Hints don't provide any benefits when balance is not enough to cover
    /// a single second of dripping or is enough to cover all drips until timestamp `2^32`.
    /// Even inaccurate hints can be useful, and providing a single hint
    /// or two hints that don't enclose the time when funds run out can still save some gas.
    /// Providing poor hints that don't reduce the number of binary search steps
    /// may cause slightly higher gas usage than not providing any hints.
    /// @param maxEndHint2 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The second hint for finding the maximum end time, see `maxEndHint1` docs for more details.
    /// @return realBalanceDelta The actually applied drips balance change.
    function _setDrips(
        uint256 userId,
        uint256 assetId,
        DripsReceiver[] memory currReceivers,
        int128 balanceDelta,
        DripsReceiver[] memory newReceivers,
        // slither-disable-next-line similar-names
        uint32 maxEndHint1,
        uint32 maxEndHint2
    ) internal returns (int128 realBalanceDelta) {
        unchecked {
            DripsState storage state = _dripsStorage().states[assetId][userId];
            _verifyDripsReceivers(currReceivers, state);
            uint32 lastUpdate = state.updateTime;
            uint128 newBalance;
            uint32 newMaxEnd;
            {
                uint32 currMaxEnd = state.maxEnd;
                int128 currBalance = int128(
                    _calcBalance(
                        state.balance, lastUpdate, currMaxEnd, currReceivers, _currTimestamp()
                    )
                );
                realBalanceDelta = balanceDelta;
                // Cap `realBalanceDelta` at withdrawal of the entire `currBalance`
                if (realBalanceDelta < -currBalance) {
                    realBalanceDelta = -currBalance;
                }
                newBalance = uint128(currBalance + realBalanceDelta);
                newMaxEnd = _calcMaxEnd(newBalance, newReceivers, maxEndHint1, maxEndHint2);
                _updateReceiverStates(
                    _dripsStorage().states[assetId],
                    currReceivers,
                    lastUpdate,
                    currMaxEnd,
                    newReceivers,
                    newMaxEnd
                );
            }
            state.updateTime = _currTimestamp();
            state.maxEnd = newMaxEnd;
            state.balance = newBalance;
            bytes32 dripsHistory = state.dripsHistoryHash;
            // slither-disable-next-line timestamp
            if (dripsHistory != 0 && _cycleOf(lastUpdate) != _cycleOf(_currTimestamp())) {
                state.currCycleConfigs = 2;
            } else {
                state.currCycleConfigs++;
            }
            bytes32 newDripsHash = _hashDrips(newReceivers);
            state.dripsHistoryHash =
                _hashDripsHistory(dripsHistory, newDripsHash, _currTimestamp(), newMaxEnd);
            emit DripsSet(userId, assetId, newDripsHash, dripsHistory, newBalance, newMaxEnd);
            // slither-disable-next-line timestamp
            if (newDripsHash != state.dripsHash) {
                state.dripsHash = newDripsHash;
                for (uint256 i = 0; i < newReceivers.length; i++) {
                    DripsReceiver memory receiver = newReceivers[i];
                    emit DripsReceiverSeen(newDripsHash, receiver.userId, receiver.config);
                }
            }
        }
    }

    /// @notice Verifies that the provided list of receivers is currently active for the user.
    /// @param currReceivers The verified list of receivers.
    /// @param state The user's state.
    function _verifyDripsReceivers(DripsReceiver[] memory currReceivers, DripsState storage state)
        private
        view
    {
        require(_hashDrips(currReceivers) == state.dripsHash, "Invalid current drips list");
    }

    /// @notice Calculates the maximum end time of drips.
    /// @param balance The balance when drips have started
    /// @param receivers The list of drips receivers.
    /// Must be sorted, deduplicated and without 0 amtPerSecs.
    /// @param hint1 The first hint for finding the maximum end time.
    /// See `_setDrips` docs for `maxEndHint1` for more details.
    /// @param hint2 The second hint for finding the maximum end time.
    /// See `_setDrips` docs for `maxEndHint2` for more details.
    /// @return maxEnd The maximum end time of drips
    function _calcMaxEnd(
        uint128 balance,
        DripsReceiver[] memory receivers,
        uint32 hint1,
        uint32 hint2
    ) private view returns (uint32 maxEnd) {
        (uint256[] memory configs, uint256 configsLen) = _buildConfigs(receivers);

        uint256 enoughEnd = _currTimestamp();
        // slither-disable-start incorrect-equality,timestamp
        if (configsLen == 0 || balance == 0) {
            return uint32(enoughEnd);
        }

        uint256 notEnoughEnd = type(uint32).max;
        if (_isBalanceEnough(balance, configs, configsLen, notEnoughEnd)) {
            return uint32(notEnoughEnd);
        }

        if (hint1 > enoughEnd && hint1 < notEnoughEnd) {
            if (_isBalanceEnough(balance, configs, configsLen, hint1)) {
                enoughEnd = hint1;
            } else {
                notEnoughEnd = hint1;
            }
        }

        if (hint2 > enoughEnd && hint2 < notEnoughEnd) {
            if (_isBalanceEnough(balance, configs, configsLen, hint2)) {
                enoughEnd = hint2;
            } else {
                notEnoughEnd = hint2;
            }
        }

        while (true) {
            uint256 end;
            unchecked {
                end = (enoughEnd + notEnoughEnd) / 2;
            }
            if (end == enoughEnd) {
                return uint32(end);
            }
            if (_isBalanceEnough(balance, configs, configsLen, end)) {
                enoughEnd = end;
            } else {
                notEnoughEnd = end;
            }
        }
        // slither-disable-end incorrect-equality,timestamp
    }

    /// @notice Check if a given balance is enough to cover drips with the given `maxEnd`.
    /// @param balance The balance when drips have started
    /// @param configs The list of drips configurations
    /// @param configsLen The length of `configs`
    /// @param maxEnd The maximum end time of drips
    /// @return isEnough `true` if the balance is enough, `false` otherwise
    function _isBalanceEnough(
        uint256 balance,
        uint256[] memory configs,
        uint256 configsLen,
        uint256 maxEnd
    ) private view returns (bool isEnough) {
        unchecked {
            uint256 spent = 0;
            for (uint256 i = 0; i < configsLen; i++) {
                (uint256 amtPerSec, uint256 start, uint256 end) = _getConfig(configs, i);
                // slither-disable-next-line timestamp
                if (maxEnd <= start) {
                    continue;
                }
                // slither-disable-next-line timestamp
                if (end > maxEnd) {
                    end = maxEnd;
                }
                spent += _drippedAmt(amtPerSec, start, end);
                if (spent > balance) {
                    return false;
                }
            }
            return true;
        }
    }

    /// @notice Build a preprocessed list of drips configurations from receivers.
    /// @param receivers The list of drips receivers.
    /// Must be sorted, deduplicated and without 0 amtPerSecs.
    /// @return configs The list of drips configurations
    /// @return configsLen The length of `configs`
    function _buildConfigs(DripsReceiver[] memory receivers)
        private
        view
        returns (uint256[] memory configs, uint256 configsLen)
    {
        unchecked {
            require(receivers.length <= _MAX_DRIPS_RECEIVERS, "Too many drips receivers");
            configs = new uint256[](receivers.length);
            for (uint256 i = 0; i < receivers.length; i++) {
                DripsReceiver memory receiver = receivers[i];
                if (i > 0) {
                    require(_isOrdered(receivers[i - 1], receiver), "Drips receivers not sorted");
                }
                configsLen = _addConfig(configs, configsLen, receiver);
            }
        }
    }

    /// @notice Preprocess and add a drips receiver to the list of configurations.
    /// @param configs The list of drips configurations
    /// @param configsLen The length of `configs`
    /// @param receiver The added drips receiver.
    /// @return newConfigsLen The new length of `configs`
    function _addConfig(uint256[] memory configs, uint256 configsLen, DripsReceiver memory receiver)
        private
        view
        returns (uint256 newConfigsLen)
    {
        uint160 amtPerSec = receiver.config.amtPerSec();
        require(amtPerSec >= _minAmtPerSec, "Drips receiver amtPerSec too low");
        (uint32 start, uint32 end) =
            _dripsRangeInFuture(receiver, _currTimestamp(), type(uint32).max);
        // slither-disable-next-line incorrect-equality,timestamp
        if (start == end) {
            return configsLen;
        }
        // By assignment we get `config` value:
        // `zeros (96 bits) | amtPerSec (160 bits)`
        uint256 config = amtPerSec;
        // By bit shifting we get `config` value:
        // `zeros (64 bits) | amtPerSec (160 bits) | zeros (32 bits)`
        // By bit masking we get `config` value:
        // `zeros (64 bits) | amtPerSec (160 bits) | start (32 bits)`
        config = (config << 32) | start;
        // By bit shifting we get `config` value:
        // `zeros (32 bits) | amtPerSec (160 bits) | start (32 bits) | zeros (32 bits)`
        // By bit masking we get `config` value:
        // `zeros (32 bits) | amtPerSec (160 bits) | start (32 bits) | end (32 bits)`
        config = (config << 32) | end;
        configs[configsLen] = config;
        unchecked {
            return configsLen + 1;
        }
    }

    /// @notice Load a drips configuration from the list.
    /// @param configs The list of drips configurations
    /// @param idx The loaded configuration index. It must be smaller than the `configs` length.
    /// @return amtPerSec The amount per second being dripped.
    /// @return start The timestamp when dripping starts.
    /// @return end The maximum timestamp when dripping ends.
    function _getConfig(uint256[] memory configs, uint256 idx)
        private
        pure
        returns (uint256 amtPerSec, uint256 start, uint256 end)
    {
        uint256 config;
        // `config` has value:
        // `zeros (32 bits) | amtPerSec (160 bits) | start (32 bits) | end (32 bits)`
        // slither-disable-next-line assembly
        assembly ("memory-safe") {
            config := mload(add(32, add(configs, shl(5, idx))))
        }
        // By bit shifting we get value:
        // `zeros (96 bits) | amtPerSec (160 bits)`
        amtPerSec = config >> 64;
        // By bit shifting we get value:
        // `zeros (64 bits) | amtPerSec (160 bits) | start (32 bits)`
        // By casting down we get value:
        // `start (32 bits)`
        start = uint32(config >> 32);
        // By casting down we get value:
        // `end (32 bits)`
        end = uint32(config);
    }

    /// @notice Calculates the hash of the drips configuration.
    /// It's used to verify if drips configuration is the previously set one.
    /// @param receivers The list of the drips receivers.
    /// Must be sorted, deduplicated and without 0 amtPerSecs.
    /// If the drips have never been updated, pass an empty array.
    /// @return dripsHash The hash of the drips configuration
    function _hashDrips(DripsReceiver[] memory receivers)
        internal
        pure
        returns (bytes32 dripsHash)
    {
        if (receivers.length == 0) {
            return bytes32(0);
        }
        return keccak256(abi.encode(receivers));
    }

    /// @notice Calculates the hash of the drips history after the drips configuration is updated.
    /// @param oldDripsHistoryHash The history hash which was valid before the drips were updated.
    /// The `dripsHistoryHash` of a user before they set drips for the first time is `0`.
    /// @param dripsHash The hash of the drips receivers being set.
    /// @param updateTime The timestamp when the drips are updated.
    /// @param maxEnd The maximum end of the drips being set.
    /// @return dripsHistoryHash The hash of the updated drips history.
    function _hashDripsHistory(
        bytes32 oldDripsHistoryHash,
        bytes32 dripsHash,
        uint32 updateTime,
        uint32 maxEnd
    ) internal pure returns (bytes32 dripsHistoryHash) {
        return keccak256(abi.encode(oldDripsHistoryHash, dripsHash, updateTime, maxEnd));
    }

    /// @notice Applies the effects of the change of the drips on the receivers' drips states.
    /// @param states The drips states for the used asset.
    /// @param currReceivers The list of the drips receivers set in the last drips update
    /// of the user.
    /// If this is the first update, pass an empty array.
    /// @param lastUpdate the last time the sender updated the drips.
    /// If this is the first update, pass zero.
    /// @param currMaxEnd The maximum end time of drips according to the last drips update.
    /// @param newReceivers  The list of the drips receivers of the user to be set.
    /// Must be sorted, deduplicated and without 0 amtPerSecs.
    /// @param newMaxEnd The maximum end time of drips according to the new drips configuration.
    function _updateReceiverStates(
        mapping(uint256 userId => DripsState) storage states,
        DripsReceiver[] memory currReceivers,
        uint32 lastUpdate,
        uint32 currMaxEnd,
        DripsReceiver[] memory newReceivers,
        uint32 newMaxEnd
    ) private {
        uint256 currIdx = 0;
        uint256 newIdx = 0;
        while (true) {
            bool pickCurr = currIdx < currReceivers.length;
            // slither-disable-next-line uninitialized-local
            DripsReceiver memory currRecv;
            if (pickCurr) {
                currRecv = currReceivers[currIdx];
            }

            bool pickNew = newIdx < newReceivers.length;
            // slither-disable-next-line uninitialized-local
            DripsReceiver memory newRecv;
            if (pickNew) {
                newRecv = newReceivers[newIdx];
            }

            // Limit picking both curr and new to situations when they differ only by time
            if (pickCurr && pickNew) {
                if (
                    currRecv.userId != newRecv.userId
                        || currRecv.config.amtPerSec() != newRecv.config.amtPerSec()
                ) {
                    pickCurr = _isOrdered(currRecv, newRecv);
                    pickNew = !pickCurr;
                }
            }

            if (pickCurr && pickNew) {
                // Shift the existing drip to fulfil the new configuration
                DripsState storage state = states[currRecv.userId];
                (uint32 currStart, uint32 currEnd) =
                    _dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
                (uint32 newStart, uint32 newEnd) =
                    _dripsRangeInFuture(newRecv, _currTimestamp(), newMaxEnd);
                int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
                // Move the start and end times if updated. This has the same effects as calling
                // _addDeltaRange(state, currStart, currEnd, -amtPerSec);
                // _addDeltaRange(state, newStart, newEnd, amtPerSec);
                // but it allows skipping storage access if there's no change to the starts or ends.
                _addDeltaRange(state, currStart, newStart, -amtPerSec);
                _addDeltaRange(state, currEnd, newEnd, amtPerSec);
                // Ensure that the user receives the updated cycles
                uint32 currStartCycle = _cycleOf(currStart);
                uint32 newStartCycle = _cycleOf(newStart);
                // The `currStartCycle > newStartCycle` check is just an optimization.
                // If it's false, then `state.nextReceivableCycle > newStartCycle` must be
                // false too, there's no need to pay for the storage access to check it.
                // slither-disable-next-line timestamp
                if (currStartCycle > newStartCycle && state.nextReceivableCycle > newStartCycle) {
                    state.nextReceivableCycle = newStartCycle;
                }
            } else if (pickCurr) {
                // Remove an existing drip
                // slither-disable-next-line similar-names
                DripsState storage state = states[currRecv.userId];
                (uint32 start, uint32 end) = _dripsRangeInFuture(currRecv, lastUpdate, currMaxEnd);
                // slither-disable-next-line similar-names
                int256 amtPerSec = int256(uint256(currRecv.config.amtPerSec()));
                _addDeltaRange(state, start, end, -amtPerSec);
            } else if (pickNew) {
                // Create a new drip
                DripsState storage state = states[newRecv.userId];
                // slither-disable-next-line uninitialized-local
                (uint32 start, uint32 end) =
                    _dripsRangeInFuture(newRecv, _currTimestamp(), newMaxEnd);
                int256 amtPerSec = int256(uint256(newRecv.config.amtPerSec()));
                _addDeltaRange(state, start, end, amtPerSec);
                // Ensure that the user receives the updated cycles
                uint32 startCycle = _cycleOf(start);
                // slither-disable-next-line timestamp
                uint32 nextReceivableCycle = state.nextReceivableCycle;
                if (nextReceivableCycle == 0 || nextReceivableCycle > startCycle) {
                    state.nextReceivableCycle = startCycle;
                }
            } else {
                break;
            }

            unchecked {
                if (pickCurr) {
                    currIdx++;
                }
                if (pickNew) {
                    newIdx++;
                }
            }
        }
    }

    /// @notice Calculates the time range in the future in which a receiver will be dripped to.
    /// @param receiver The drips receiver
    /// @param maxEnd The maximum end time of drips
    function _dripsRangeInFuture(DripsReceiver memory receiver, uint32 updateTime, uint32 maxEnd)
        private
        view
        returns (uint32 start, uint32 end)
    {
        return _dripsRange(receiver, updateTime, maxEnd, _currTimestamp(), type(uint32).max);
    }

    /// @notice Calculates the time range in which a receiver is to be dripped to.
    /// This range is capped to provide a view on drips through a specific time window.
    /// @param receiver The drips receiver
    /// @param updateTime The time when drips are configured
    /// @param maxEnd The maximum end time of drips
    /// @param startCap The timestamp the drips range start should be capped to
    /// @param endCap The timestamp the drips range end should be capped to
    function _dripsRange(
        DripsReceiver memory receiver,
        uint32 updateTime,
        uint32 maxEnd,
        uint32 startCap,
        uint32 endCap
    ) private pure returns (uint32 start, uint32 end_) {
        start = receiver.config.start();
        // slither-disable-start timestamp
        if (start == 0) {
            start = updateTime;
        }
        uint40 end;
        unchecked {
            end = uint40(start) + receiver.config.duration();
        }
        // slither-disable-next-line incorrect-equality
        if (end == start || end > maxEnd) {
            end = maxEnd;
        }
        if (start < startCap) {
            start = startCap;
        }
        if (end > endCap) {
            end = endCap;
        }
        if (end < start) {
            end = start;
        }
        // slither-disable-end timestamp
        return (start, uint32(end));
    }

    /// @notice Adds funds received by a user in a given time range
    /// @param state The user state
    /// @param start The timestamp from which the delta takes effect
    /// @param end The timestamp until which the delta takes effect
    /// @param amtPerSec The dripping rate
    function _addDeltaRange(DripsState storage state, uint32 start, uint32 end, int256 amtPerSec)
        private
    {
        // slither-disable-next-line incorrect-equality,timestamp
        if (start == end) {
            return;
        }
        mapping(uint32 cycle => AmtDelta) storage amtDeltas = state.amtDeltas;
        _addDelta(amtDeltas, start, amtPerSec);
        _addDelta(amtDeltas, end, -amtPerSec);
    }

    /// @notice Adds delta of funds received by a user at a given time
    /// @param amtDeltas The user amount deltas
    /// @param timestamp The timestamp when the deltas need to be added
    /// @param amtPerSec The dripping rate
    function _addDelta(
        mapping(uint32 cycle => AmtDelta) storage amtDeltas,
        uint256 timestamp,
        int256 amtPerSec
    ) private {
        unchecked {
            // In order to set a delta on a specific timestamp it must be introduced in two cycles.
            // These formulas follow the logic from `_drippedAmt`, see it for more details.
            int256 amtPerSecMultiplier = int160(_AMT_PER_SEC_MULTIPLIER);
            int256 fullCycle = (int256(uint256(_cycleSecs)) * amtPerSec) / amtPerSecMultiplier;
            // slither-disable-next-line weak-prng
            int256 nextCycle = (int256(timestamp % _cycleSecs) * amtPerSec) / amtPerSecMultiplier;
            AmtDelta storage amtDelta = amtDeltas[_cycleOf(uint32(timestamp))];
            // Any over- or under-flows are fine, they're guaranteed to be fixed by a matching
            // under- or over-flow from the other call to `_addDelta` made by `_addDeltaRange`.
            // This is because the total balance of `Drips` can never exceed `type(int128).max`,
            // so in the end no amtDelta can have delta higher than `type(int128).max`.
            amtDelta.thisCycle += int128(fullCycle - nextCycle);
            amtDelta.nextCycle += int128(nextCycle);
        }
    }

    /// @notice Checks if two receivers fulfil the sortedness requirement of the receivers list.
    /// @param prev The previous receiver
    /// @param next The next receiver
    function _isOrdered(DripsReceiver memory prev, DripsReceiver memory next)
        private
        pure
        returns (bool)
    {
        if (prev.userId != next.userId) {
            return prev.userId < next.userId;
        }
        return prev.config.lt(next.config);
    }

    /// @notice Calculates the amount dripped over a time range.
    /// The amount dripped in the `N`th second of each cycle is:
    /// `(N + 1) * amtPerSec / AMT_PER_SEC_MULTIPLIER - N * amtPerSec / AMT_PER_SEC_MULTIPLIER`.
    /// For a range of `N`s from `0` to `M` the sum of the dripped amounts is calculated as:
    /// `M * amtPerSec / AMT_PER_SEC_MULTIPLIER` assuming that `M <= cycleSecs`.
    /// For an arbitrary time range across multiple cycles the amount is calculated as the sum of
    /// the amount dripped in the start cycle, each of the full cycles in between and the end cycle.
    /// This algorithm has the following properties:
    /// - During every second full units are dripped, there are no partially dripped units.
    /// - Undripped fractions are dripped when they add up into full units.
    /// - Undripped fractions don't add up across cycle end boundaries.
    /// - Some seconds drip more units and some less.
    /// - Every `N`th second of each cycle drips the same amount.
    /// - Every full cycle drips the same amount.
    /// - The amount dripped in a given second is independent from the dripping start and end.
    /// - Dripping over time ranges `A:B` and then `B:C` is equivalent to dripping over `A:C`.
    /// - Different drips existing in the system don't interfere with each other.
    /// @param amtPerSec The dripping rate
    /// @param start The dripping start time
    /// @param end The dripping end time
    /// @return amt The dripped amount
    function _drippedAmt(uint256 amtPerSec, uint256 start, uint256 end)
        private
        view
        returns (uint256 amt)
    {
        // This function is written in Yul because it can be called thousands of times
        // per transaction and it needs to be optimized as much as possible.
        // As of Solidity 0.8.13, rewriting it in unchecked Solidity triples its gas cost.
        uint256 cycleSecs = _cycleSecs;
        // slither-disable-next-line assembly
        assembly {
            let endedCycles := sub(div(end, cycleSecs), div(start, cycleSecs))
            // slither-disable-next-line divide-before-multiply
            let amtPerCycle := div(mul(cycleSecs, amtPerSec), _AMT_PER_SEC_MULTIPLIER)
            amt := mul(endedCycles, amtPerCycle)
            // slither-disable-next-line weak-prng
            let amtEnd := div(mul(mod(end, cycleSecs), amtPerSec), _AMT_PER_SEC_MULTIPLIER)
            amt := add(amt, amtEnd)
            // slither-disable-next-line weak-prng
            let amtStart := div(mul(mod(start, cycleSecs), amtPerSec), _AMT_PER_SEC_MULTIPLIER)
            amt := sub(amt, amtStart)
        }
    }

    /// @notice Calculates the cycle containing the given timestamp.
    /// @param timestamp The timestamp.
    /// @return cycle The cycle containing the timestamp.
    function _cycleOf(uint32 timestamp) private view returns (uint32 cycle) {
        unchecked {
            return timestamp / _cycleSecs + 1;
        }
    }

    /// @notice The current timestamp, casted to the contract's internal representation.
    /// @return timestamp The current timestamp
    function _currTimestamp() private view returns (uint32 timestamp) {
        return uint32(block.timestamp);
    }

    /// @notice The current cycle start timestamp, casted to the contract's internal representation.
    /// @return timestamp The current cycle start timestamp
    function _currCycleStart() private view returns (uint32 timestamp) {
        unchecked {
            uint32 currTimestamp = _currTimestamp();
            // slither-disable-next-line weak-prng
            return currTimestamp - (currTimestamp % _cycleSecs);
        }
    }

    /// @notice Returns the Drips storage.
    /// @return dripsStorage The storage.
    function _dripsStorage() private view returns (DripsStorage storage dripsStorage) {
        bytes32 slot = _dripsStorageSlot;
        // slither-disable-next-line assembly
        assembly {
            dripsStorage.slot := slot
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {Drips, DripsConfig, DripsHistory, DripsConfigImpl, DripsReceiver} from "./Drips.sol";
import {Managed} from "./Managed.sol";
import {Splits, SplitsReceiver} from "./Splits.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

/// @notice The user metadata.
/// The key and the value are not standardized by the protocol, it's up to the user
/// to establish and follow conventions to ensure compatibility with the consumers.
struct UserMetadata {
    /// @param key The metadata key
    bytes32 key;
    /// @param value The metadata value
    bytes value;
}

/// @notice Drips hub contract. Automatically drips and splits funds between users.
///
/// The user can transfer some funds to their drips balance in the contract
/// and configure a list of receivers, to whom they want to drip these funds.
/// As soon as the drips balance is enough to cover at least 1 second of dripping
/// to the configured receivers, the funds start dripping automatically.
/// Every second funds are deducted from the drips balance and moved to their receivers.
/// The process stops automatically when the drips balance is not enough to cover another second.
///
/// Every user has a receiver balance, in which they have funds received from other users.
/// The dripped funds are added to the receiver balances in global cycles.
/// Every `cycleSecs` seconds the drips hub adds dripped funds to the receivers' balances,
/// so recently dripped funds may not be receivable immediately.
/// `cycleSecs` is a constant configured when the drips hub is deployed.
/// The receiver balance is independent from the drips balance,
/// to drip received funds they need to be first collected and then added to the drips balance.
///
/// The user can share collected funds with other users by using splits.
/// When collecting, the user gives each of their splits receivers a fraction of the received funds.
/// Funds received from splits are available for collection immediately regardless of the cycle.
/// They aren't exempt from being split, so they too can be split when collected.
/// Users can build chains and networks of splits between each other.
/// Anybody can request collection of funds for any user,
/// which can be used to enforce the flow of funds in the network of splits.
///
/// The concept of something happening periodically, e.g. every second or every `cycleSecs` are
/// only high-level abstractions for the user, Ethereum isn't really capable of scheduling work.
/// The actual implementation emulates that behavior by calculating the results of the scheduled
/// events based on how many seconds have passed and only when the user needs their outcomes.
///
/// The contract can store at most `type(int128).max` which is `2 ^ 127 - 1` units of each token.
contract DripsHub is Managed, Drips, Splits {
    /// @notice Maximum number of drips receivers of a single user.
    /// Limits cost of changes in drips configuration.
    uint256 public constant MAX_DRIPS_RECEIVERS = _MAX_DRIPS_RECEIVERS;
    /// @notice The additional decimals for all amtPerSec values.
    uint8 public constant AMT_PER_SEC_EXTRA_DECIMALS = _AMT_PER_SEC_EXTRA_DECIMALS;
    /// @notice The multiplier for all amtPerSec values.
    uint160 public constant AMT_PER_SEC_MULTIPLIER = _AMT_PER_SEC_MULTIPLIER;
    /// @notice Maximum number of splits receivers of a single user. Limits the cost of splitting.
    uint256 public constant MAX_SPLITS_RECEIVERS = _MAX_SPLITS_RECEIVERS;
    /// @notice The total splits weight of a user
    uint32 public constant TOTAL_SPLITS_WEIGHT = _TOTAL_SPLITS_WEIGHT;
    /// @notice The offset of the controlling driver ID in the user ID.
    /// In other words the controlling driver ID is the highest 32 bits of the user ID.
    /// Every user ID is a 256-bit integer constructed by concatenating:
    /// `driverId (32 bits) | driverCustomData (224 bits)`.
    uint256 public constant DRIVER_ID_OFFSET = 224;
    /// @notice The total amount the contract can store of each token.
    /// It's the minimum of _MAX_TOTAL_DRIPS_BALANCE and _MAX_TOTAL_SPLITS_BALANCE.
    uint256 public constant MAX_TOTAL_BALANCE = _MAX_TOTAL_DRIPS_BALANCE;
    /// @notice On every timestamp `T`, which is a multiple of `cycleSecs`, the receivers
    /// gain access to drips received during `T - cycleSecs` to `T - 1`.
    /// Always higher than 1.
    uint32 public immutable cycleSecs;
    /// @notice The minimum amtPerSec of a drip. It's 1 token per cycle.
    uint160 public immutable minAmtPerSec;
    /// @notice The ERC-1967 storage slot holding a single `DripsHubStorage` structure.
    bytes32 private immutable _dripsHubStorageSlot = _erc1967Slot("eip1967.dripsHub.storage");

    /// @notice Emitted when a driver is registered
    /// @param driverId The driver ID
    /// @param driverAddr The driver address
    event DriverRegistered(uint32 indexed driverId, address indexed driverAddr);

    /// @notice Emitted when a driver address is updated
    /// @param driverId The driver ID
    /// @param oldDriverAddr The old driver address
    /// @param newDriverAddr The new driver address
    event DriverAddressUpdated(
        uint32 indexed driverId, address indexed oldDriverAddr, address indexed newDriverAddr
    );

    /// @notice Emitted when funds are withdrawn.
    /// @param erc20 The used ERC-20 token.
    /// @param receiver The address that the funds are sent to.
    /// @param amt The withdrawn amount.
    event Withdrawn(IERC20 indexed erc20, address indexed receiver, uint256 amt);

    /// @notice Emitted by the user to broadcast metadata.
    /// The key and the value are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @param userId The ID of the user emitting metadata
    /// @param key The metadata key
    /// @param value The metadata value
    event UserMetadataEmitted(uint256 indexed userId, bytes32 indexed key, bytes value);

    struct DripsHubStorage {
        /// @notice The next driver ID that will be used when registering.
        uint32 nextDriverId;
        /// @notice Driver addresses.
        mapping(uint32 driverId => address) driverAddresses;
        /// @notice The total amount currently stored in DripsHub of each token.
        mapping(IERC20 erc20 => uint256) totalBalances;
    }

    /// @param cycleSecs_ The length of cycleSecs to be used in the contract instance.
    /// Low value makes funds more available by shortening the average time of funds being frozen
    /// between being taken from the users' drips balances and being receivable by their receivers.
    /// High value makes receiving cheaper by making it process less cycles for a given time range.
    /// Must be higher than 1.
    constructor(uint32 cycleSecs_)
        Drips(cycleSecs_, _erc1967Slot("eip1967.drips.storage"))
        Splits(_erc1967Slot("eip1967.splits.storage"))
    {
        cycleSecs = Drips._cycleSecs;
        minAmtPerSec = Drips._minAmtPerSec;
    }

    /// @notice A modifier making functions callable only by the driver controlling the user ID.
    /// @param userId The user ID.
    modifier onlyDriver(uint256 userId) {
        // `userId` has value:
        // `driverId (32 bits) | driverCustomData (224 bits)`
        // By bit shifting we get value:
        // `zeros (224 bits) | driverId (32 bits)`
        // By casting down we get value:
        // `driverId (32 bits)`
        uint32 driverId = uint32(userId >> DRIVER_ID_OFFSET);
        _assertCallerIsDriver(driverId);
        _;
    }

    /// @notice Verifies that the caller controls the given driver ID and reverts otherwise.
    /// @param driverId The driver ID.
    function _assertCallerIsDriver(uint32 driverId) internal view {
        require(driverAddress(driverId) == msg.sender, "Callable only by the driver");
    }

    /// @notice Registers a driver.
    /// The driver is assigned a unique ID and a range of user IDs it can control.
    /// That range consists of all 2^224 user IDs with highest 32 bits equal to the driver ID.
    /// Every user ID is a 256-bit integer constructed by concatenating:
    /// `driverId (32 bits) | driverCustomData (224 bits)`.
    /// Every driver ID is assigned only to a single address,
    /// but a single address can have multiple driver IDs assigned to it.
    /// @param driverAddr The address of the driver. Must not be zero address.
    /// It should be a smart contract capable of dealing with the DripsHub API.
    /// It shouldn't be an EOA because the API requires making multiple calls per transaction.
    /// @return driverId The registered driver ID.
    function registerDriver(address driverAddr) public whenNotPaused returns (uint32 driverId) {
        require(driverAddr != address(0), "Driver registered for 0 address");
        DripsHubStorage storage dripsHubStorage = _dripsHubStorage();
        driverId = dripsHubStorage.nextDriverId++;
        dripsHubStorage.driverAddresses[driverId] = driverAddr;
        emit DriverRegistered(driverId, driverAddr);
    }

    /// @notice Returns the driver address.
    /// @param driverId The driver ID to look up.
    /// @return driverAddr The address of the driver.
    /// If the driver hasn't been registered yet, returns address 0.
    function driverAddress(uint32 driverId) public view returns (address driverAddr) {
        return _dripsHubStorage().driverAddresses[driverId];
    }

    /// @notice Updates the driver address. Must be called from the current driver address.
    /// @param driverId The driver ID.
    /// @param newDriverAddr The new address of the driver.
    /// It should be a smart contract capable of dealing with the DripsHub API.
    /// It shouldn't be an EOA because the API requires making multiple calls per transaction.
    function updateDriverAddress(uint32 driverId, address newDriverAddr) public whenNotPaused {
        _assertCallerIsDriver(driverId);
        _dripsHubStorage().driverAddresses[driverId] = newDriverAddr;
        emit DriverAddressUpdated(driverId, msg.sender, newDriverAddr);
    }

    /// @notice Returns the driver ID which will be assigned for the next registered driver.
    /// @return driverId The next driver ID.
    function nextDriverId() public view returns (uint32 driverId) {
        return _dripsHubStorage().nextDriverId;
    }

    /// @notice Returns the total amount currently stored in DripsHub of the given token.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return balance The balance of the token.
    function totalBalance(IERC20 erc20) public view returns (uint256 balance) {
        return _dripsHubStorage().totalBalances[erc20];
    }

    /// @notice Transfers withdrawable funds to an address.
    /// The withdrawable funds are held by the DripsHub contract,
    /// but not used in the protocol, so they are free to be transferred out.
    /// Anybody can call `withdraw`, so all withdrawable funds should be withdrawn
    /// or used in the protocol before any 3rd parties have a chance to do that.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param receiver The address to send withdrawn funds to.
    /// @param amt The withdrawn amount.
    /// It must be at most the difference between the balance of the token
    /// held by the DripsHub contract address and the total balance managed by the protocol,
    /// or in other words `erc20.balanceOf(address(dripsHub)) - dripsHub.totalBalance(erc20)`.
    function withdraw(IERC20 erc20, address receiver, uint256 amt) public {
        uint256 withdrawable = erc20.balanceOf(address(this)) - totalBalance(erc20);
        require(amt <= withdrawable, "Withdrawal amount too high");
        emit Withdrawn(erc20, receiver, amt);
        erc20.safeTransfer(receiver, amt);
    }

    /// @notice Increases the total amount currently stored in DripsHub of the given token.
    /// No funds are transferred, all the tokens are expected to be already held by DripsHub.
    /// The new total balance is verified to have coverage in the held tokens
    /// and to be within the limit of `MAX_TOTAL_BALANCE`.
    /// @param erc20 The used ERC-20 token.
    /// @param amt The amount to increase the total balance by.
    function _increaseTotalBalance(IERC20 erc20, uint128 amt) internal {
        if (amt == 0) return;
        uint256 newBalance = _dripsHubStorage().totalBalances[erc20] += amt;
        require(newBalance <= MAX_TOTAL_BALANCE, "Total balance too high");
        require(newBalance <= erc20.balanceOf(address(this)), "ERC-20 balance too low");
    }

    /// @notice Decreases the total amount currently stored in DripsHub of the given token.
    /// No funds are transferred, but the tokens held by DripsHub
    /// above the total balance become withdrawable.
    /// @param erc20 The used ERC-20 token.
    /// @param amt The amount to decrease the total balance by.
    function _decreaseTotalBalance(IERC20 erc20, uint128 amt) internal {
        if (amt == 0) return;
        _dripsHubStorage().totalBalances[erc20] -= amt;
    }

    /// @notice Counts cycles from which drips can be collected.
    /// This function can be used to detect that there are
    /// too many cycles to analyze in a single transaction.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return cycles The number of cycles which can be flushed
    function receivableDripsCycles(uint256 userId, IERC20 erc20)
        public
        view
        returns (uint32 cycles)
    {
        return Drips._receivableDripsCycles(userId, _assetId(erc20));
    }

    /// @notice Calculate effects of calling `receiveDrips` with the given parameters.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param maxCycles The maximum number of received drips cycles.
    /// If too low, receiving will be cheap, but may not cover many cycles.
    /// If too high, receiving may become too expensive to fit in a single transaction.
    /// @return receivableAmt The amount which would be received
    function receiveDripsResult(uint256 userId, IERC20 erc20, uint32 maxCycles)
        public
        view
        returns (uint128 receivableAmt)
    {
        (receivableAmt,,,,) = Drips._receiveDripsResult(userId, _assetId(erc20), maxCycles);
    }

    /// @notice Receive drips for the user.
    /// Received drips cycles won't need to be analyzed ever again.
    /// Calling this function does not collect but makes the funds ready to be split and collected.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param maxCycles The maximum number of received drips cycles.
    /// If too low, receiving will be cheap, but may not cover many cycles.
    /// If too high, receiving may become too expensive to fit in a single transaction.
    /// @return receivedAmt The received amount
    function receiveDrips(uint256 userId, IERC20 erc20, uint32 maxCycles)
        public
        whenNotPaused
        returns (uint128 receivedAmt)
    {
        uint256 assetId = _assetId(erc20);
        receivedAmt = Drips._receiveDrips(userId, assetId, maxCycles);
        if (receivedAmt > 0) Splits._addSplittable(userId, assetId, receivedAmt);
    }

    /// @notice Receive drips from the currently running cycle from a single sender.
    /// It doesn't receive drips from the previous, finished cycles, to do that use `receiveDrips`.
    /// Squeezed funds won't be received in the next calls to `squeezeDrips` or `receiveDrips`.
    /// Only funds dripped before `block.timestamp` can be squeezed.
    /// @param userId The ID of the user receiving drips to squeeze funds for.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param senderId The ID of the user sending drips to squeeze funds from.
    /// @param historyHash The sender's history hash which was valid right before
    /// they set up the sequence of configurations described by `dripsHistory`.
    /// @param dripsHistory The sequence of the sender's drips configurations.
    /// It can start at an arbitrary past configuration, but must describe all the configurations
    /// which have been used since then including the current one, in the chronological order.
    /// Only drips described by `dripsHistory` will be squeezed.
    /// If `dripsHistory` entries have no receivers, they won't be squeezed.
    /// @return amt The squeezed amount.
    function squeezeDrips(
        uint256 userId,
        IERC20 erc20,
        uint256 senderId,
        bytes32 historyHash,
        DripsHistory[] memory dripsHistory
    ) public whenNotPaused returns (uint128 amt) {
        uint256 assetId = _assetId(erc20);
        amt = Drips._squeezeDrips(userId, assetId, senderId, historyHash, dripsHistory);
        if (amt > 0) Splits._addSplittable(userId, assetId, amt);
    }

    /// @notice Calculate effects of calling `squeezeDrips` with the given parameters.
    /// See its documentation for more details.
    /// @param userId The ID of the user receiving drips to squeeze funds for.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param senderId The ID of the user sending drips to squeeze funds from.
    /// @param historyHash The sender's history hash which was valid right before `dripsHistory`.
    /// @param dripsHistory The sequence of the sender's drips configurations.
    /// @return amt The squeezed amount.
    function squeezeDripsResult(
        uint256 userId,
        IERC20 erc20,
        uint256 senderId,
        bytes32 historyHash,
        DripsHistory[] memory dripsHistory
    ) public view returns (uint128 amt) {
        (amt,,,,) =
            Drips._squeezeDripsResult(userId, _assetId(erc20), senderId, historyHash, dripsHistory);
    }

    /// @notice Returns user's received but not split yet funds.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return amt The amount received but not split yet.
    function splittable(uint256 userId, IERC20 erc20) public view returns (uint128 amt) {
        return Splits._splittable(userId, _assetId(erc20));
    }

    /// @notice Calculate the result of splitting an amount using the current splits configuration.
    /// @param userId The user ID
    /// @param currReceivers The list of the user's current splits receivers.
    /// It must be exactly the same as the last list set for the user with `setSplits`.
    /// @param amount The amount being split.
    /// @return collectableAmt The amount made collectable for the user
    /// on top of what was collectable before.
    /// @return splitAmt The amount split to the user's splits receivers
    function splitResult(uint256 userId, SplitsReceiver[] memory currReceivers, uint128 amount)
        public
        view
        returns (uint128 collectableAmt, uint128 splitAmt)
    {
        return Splits._splitResult(userId, currReceivers, amount);
    }

    /// @notice Splits the user's splittable funds among receivers.
    /// The entire splittable balance of the given asset is split.
    /// All split funds are split using the current splits configuration.
    /// Because the user can update their splits configuration at any time,
    /// it is possible that calling this function will be frontrun,
    /// and all the splittable funds will become splittable only using the new configuration.
    /// The user must be trusted with how funds sent to them will be splits,
    /// in the end they can do with their funds whatever they want by changing the configuration.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param currReceivers The list of the user's current splits receivers.
    /// It must be exactly the same as the last list set for the user with `setSplits`.
    /// @return collectableAmt The amount made collectable for the user
    /// on top of what was collectable before.
    /// @return splitAmt The amount split to the user's splits receivers
    function split(uint256 userId, IERC20 erc20, SplitsReceiver[] memory currReceivers)
        public
        whenNotPaused
        returns (uint128 collectableAmt, uint128 splitAmt)
    {
        return Splits._split(userId, _assetId(erc20), currReceivers);
    }

    /// @notice Returns user's received funds already split and ready to be collected.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return amt The collectable amount.
    function collectable(uint256 userId, IERC20 erc20) public view returns (uint128 amt) {
        return Splits._collectable(userId, _assetId(erc20));
    }

    /// @notice Collects user's received already split funds and makes them withdrawable.
    /// Anybody can call `withdraw`, so all withdrawable funds should be withdrawn
    /// or used in the protocol before any 3rd parties have a chance to do that.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return amt The collected amount
    function collect(uint256 userId, IERC20 erc20)
        public
        whenNotPaused
        onlyDriver(userId)
        returns (uint128 amt)
    {
        amt = Splits._collect(userId, _assetId(erc20));
        _decreaseTotalBalance(erc20, amt);
    }

    /// @notice Gives funds from the user to the receiver.
    /// The receiver can split and collect them immediately.
    /// Requires that the tokens used to give are already sent to DripsHub and are withdrawable.
    /// Anybody can call `withdraw`, so all withdrawable funds should be withdrawn
    /// or used in the protocol before any 3rd parties have a chance to do that.
    /// @param userId The user ID
    /// @param receiver The receiver
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param amt The given amount
    function give(uint256 userId, uint256 receiver, IERC20 erc20, uint128 amt)
        public
        whenNotPaused
        onlyDriver(userId)
    {
        _increaseTotalBalance(erc20, amt);
        Splits._give(userId, receiver, _assetId(erc20), amt);
    }

    /// @notice Current user drips state.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @return dripsHash The current drips receivers list hash, see `hashDrips`
    /// @return dripsHistoryHash The current drips history hash, see `hashDripsHistory`.
    /// @return updateTime The time when drips have been configured for the last time
    /// @return balance The balance when drips have been configured for the last time
    /// @return maxEnd The current maximum end time of drips
    function dripsState(uint256 userId, IERC20 erc20)
        public
        view
        returns (
            bytes32 dripsHash,
            bytes32 dripsHistoryHash,
            uint32 updateTime,
            uint128 balance,
            uint32 maxEnd
        )
    {
        return Drips._dripsState(userId, _assetId(erc20));
    }

    /// @notice User's drips balance at a given timestamp
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param currReceivers The current drips receivers list.
    /// It must be exactly the same as the last list set for the user with `setDrips`.
    /// @param timestamp The timestamps for which balance should be calculated.
    /// It can't be lower than the timestamp of the last call to `setDrips`.
    /// If it's bigger than `block.timestamp`, then it's a prediction assuming
    /// that `setDrips` won't be called before `timestamp`.
    /// @return balance The user balance on `timestamp`
    function balanceAt(
        uint256 userId,
        IERC20 erc20,
        DripsReceiver[] memory currReceivers,
        uint32 timestamp
    ) public view returns (uint128 balance) {
        return Drips._balanceAt(userId, _assetId(erc20), currReceivers, timestamp);
    }

    /// @notice Sets the user's drips configuration.
    /// Requires that the tokens used to increase the drips balance
    /// are already sent to DripsHub and are withdrawable.
    /// If the drips balance is decreased, the released tokens become withdrawable.
    /// Anybody can call `withdraw`, so all withdrawable funds should be withdrawn
    /// or used in the protocol before any 3rd parties have a chance to do that.
    /// @param userId The user ID
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param currReceivers The current drips receivers list.
    /// It must be exactly the same as the last list set for the user with `setDrips`.
    /// If this is the first update, pass an empty array.
    /// @param balanceDelta The drips balance change to be applied.
    /// Positive to add funds to the drips balance, negative to remove them.
    /// @param newReceivers The list of the drips receivers of the user to be set.
    /// Must be sorted by the receivers' addresses, deduplicated and without 0 amtPerSecs.
    /// @param maxEndHint1 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The first hint for finding the maximum end time when all drips stop due to funds
    /// running out after the balance is updated and the new receivers list is applied.
    /// Hints have no effect on the results of calling this function, except potentially saving gas.
    /// Hints are Unix timestamps used as the starting points for binary search for the time
    /// when funds run out in the range of timestamps from the current block's to `2^32`.
    /// Hints lower than the current timestamp are ignored.
    /// You can provide zero, one or two hints. The order of hints doesn't matter.
    /// Hints are the most effective when one of them is lower than or equal to
    /// the last timestamp when funds are still dripping, and the other one is strictly larger
    /// than that timestamp,the smaller the difference between such hints, the higher gas savings.
    /// The savings are the highest possible when one of the hints is equal to
    /// the last timestamp when funds are still dripping, and the other one is larger by 1.
    /// It's worth noting that the exact timestamp of the block in which this function is executed
    /// may affect correctness of the hints, especially if they're precise.
    /// Hints don't provide any benefits when balance is not enough to cover
    /// a single second of dripping or is enough to cover all drips until timestamp `2^32`.
    /// Even inaccurate hints can be useful, and providing a single hint
    /// or two hints that don't enclose the time when funds run out can still save some gas.
    /// Providing poor hints that don't reduce the number of binary search steps
    /// may cause slightly higher gas usage than not providing any hints.
    /// @param maxEndHint2 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The second hint for finding the maximum end time, see `maxEndHint1` docs for more details.
    /// @return realBalanceDelta The actually applied drips balance change.
    /// If it's lower than zero, it's the negative of the amount that became withdrawable.
    function setDrips(
        uint256 userId,
        IERC20 erc20,
        DripsReceiver[] memory currReceivers,
        int128 balanceDelta,
        DripsReceiver[] memory newReceivers,
        // slither-disable-next-line similar-names
        uint32 maxEndHint1,
        uint32 maxEndHint2
    ) public whenNotPaused onlyDriver(userId) returns (int128 realBalanceDelta) {
        if (balanceDelta > 0) _increaseTotalBalance(erc20, uint128(balanceDelta));
        realBalanceDelta = Drips._setDrips(
            userId,
            _assetId(erc20),
            currReceivers,
            balanceDelta,
            newReceivers,
            maxEndHint1,
            maxEndHint2
        );
        if (realBalanceDelta < 0) _decreaseTotalBalance(erc20, uint128(-realBalanceDelta));
    }

    /// @notice Calculates the hash of the drips configuration.
    /// It's used to verify if drips configuration is the previously set one.
    /// @param receivers The list of the drips receivers.
    /// Must be sorted by the receivers' addresses, deduplicated and without 0 amtPerSecs.
    /// If the drips have never been updated, pass an empty array.
    /// @return dripsHash The hash of the drips configuration
    function hashDrips(DripsReceiver[] memory receivers) public pure returns (bytes32 dripsHash) {
        return Drips._hashDrips(receivers);
    }

    /// @notice Calculates the hash of the drips history after the drips configuration is updated.
    /// @param oldDripsHistoryHash The history hash which was valid before the drips were updated.
    /// The `dripsHistoryHash` of a user before they set drips for the first time is `0`.
    /// @param dripsHash The hash of the drips receivers being set.
    /// @param updateTime The timestamp when the drips are updated.
    /// @param maxEnd The maximum end of the drips being set.
    /// @return dripsHistoryHash The hash of the updated drips history.
    function hashDripsHistory(
        bytes32 oldDripsHistoryHash,
        bytes32 dripsHash,
        uint32 updateTime,
        uint32 maxEnd
    ) public pure returns (bytes32 dripsHistoryHash) {
        return Drips._hashDripsHistory(oldDripsHistoryHash, dripsHash, updateTime, maxEnd);
    }

    /// @notice Sets user splits configuration. The configuration is common for all assets.
    /// Nothing happens to the currently splittable funds, but when they are split
    /// after this function finishes, the new splits configuration will be used.
    /// Because anybody can call `split`, calling this function may be frontrun
    /// and all the currently splittable funds will be split using the old splits configuration.
    /// @param userId The user ID
    /// @param receivers The list of the user's splits receivers to be set.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// Each splits receiver will be getting `weight / TOTAL_SPLITS_WEIGHT`
    /// share of the funds collected by the user.
    /// If the sum of weights of all receivers is less than `_TOTAL_SPLITS_WEIGHT`,
    /// some funds won't be split, but they will be left for the user to collect.
    /// It's valid to include the user's own `userId` in the list of receivers,
    /// but funds split to themselves return to their splittable balance and are not collectable.
    /// This is usually unwanted, because if splitting is repeated,
    /// funds split to themselves will be again split using the current configuration.
    /// Splitting 100% to self effectively blocks splitting unless the configuration is updated.
    function setSplits(uint256 userId, SplitsReceiver[] memory receivers)
        public
        whenNotPaused
        onlyDriver(userId)
    {
        Splits._setSplits(userId, receivers);
    }

    /// @notice Current user's splits hash, see `hashSplits`.
    /// @param userId The user ID
    /// @return currSplitsHash The current user's splits hash
    function splitsHash(uint256 userId) public view returns (bytes32 currSplitsHash) {
        return Splits._splitsHash(userId);
    }

    /// @notice Calculates the hash of the list of splits receivers.
    /// @param receivers The list of the splits receivers.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// @return receiversHash The hash of the list of splits receivers.
    function hashSplits(SplitsReceiver[] memory receivers)
        public
        pure
        returns (bytes32 receiversHash)
    {
        return Splits._hashSplits(receivers);
    }

    /// @notice Emits user metadata.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @param userId The user ID.
    /// @param userMetadata The list of user metadata.
    function emitUserMetadata(uint256 userId, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        onlyDriver(userId)
    {
        unchecked {
            for (uint256 i = 0; i < userMetadata.length; i++) {
                UserMetadata calldata metadata = userMetadata[i];
                emit UserMetadataEmitted(userId, metadata.key, metadata.value);
            }
        }
    }

    /// @notice Returns the DripsHub storage.
    /// @return storageRef The storage.
    function _dripsHubStorage() internal view returns (DripsHubStorage storage storageRef) {
        bytes32 slot = _dripsHubStorageSlot;
        // slither-disable-next-line assembly
        assembly {
            storageRef.slot := slot
        }
    }

    /// @notice Generates an asset ID for the ERC-20 token
    /// @param erc20 The ERC-20 token
    /// @return assetId The asset ID
    function _assetId(IERC20 erc20) internal pure returns (uint256 assetId) {
        return uint160(address(erc20));
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";

using EnumerableSet for EnumerableSet.AddressSet;

/// @notice A mix-in for contract pausing, upgrading and admin management.
/// It can't be used directly, only via a proxy. It uses the upgrade-safe ERC-1967 storage scheme.
///
/// Managed uses the ERC-1967 admin slot to store the admin address.
/// All instances of the contracts have admin address `0x00` and are forever paused.
/// When a proxy uses such contract via delegation, the proxy should define
/// the initial admin address and the contract is initially unpaused.
abstract contract Managed is UUPSUpgradeable {
    /// @notice The pointer to the storage slot holding a single `ManagedStorage` structure.
    bytes32 private immutable _managedStorageSlot = _erc1967Slot("eip1967.managed.storage");

    /// @notice Emitted when a new admin of the contract is proposed.
    /// The proposed admin must call `acceptAdmin` to finalize the change.
    /// @param currentAdmin The current admin address.
    /// @param newAdmin The proposed admin address.
    event NewAdminProposed(address indexed currentAdmin, address indexed newAdmin);

    /// @notice Emitted when the pauses role is granted.
    /// @param pauser The address that the pauser role was granted to.
    /// @param admin The address of the admin that triggered the change.
    event PauserGranted(address indexed pauser, address indexed admin);

    /// @notice Emitted when the pauses role is revoked.
    /// @param pauser The address that the pauser role was revoked from.
    /// @param admin The address of the admin that triggered the change.
    event PauserRevoked(address indexed pauser, address indexed admin);

    /// @notice Emitted when the pause is triggered.
    /// @param pauser The address that triggered the change.
    event Paused(address indexed pauser);

    /// @notice Emitted when the pause is lifted.
    /// @param pauser The address that triggered the change.
    event Unpaused(address indexed pauser);

    struct ManagedStorage {
        bool isPaused;
        EnumerableSet.AddressSet pausers;
        address proposedAdmin;
    }

    /// @notice Throws if called by any caller other than the admin.
    modifier onlyAdmin() {
        require(admin() == msg.sender, "Caller not the admin");
        _;
    }

    /// @notice Throws if called by any caller other than the admin or a pauser.
    modifier onlyAdminOrPauser() {
        require(admin() == msg.sender || isPauser(msg.sender), "Caller not the admin or a pauser");
        _;
    }

    /// @notice Modifier to make a function callable only when the contract is not paused.
    modifier whenNotPaused() {
        require(!isPaused(), "Contract paused");
        _;
    }

    /// @notice Modifier to make a function callable only when the contract is paused.
    modifier whenPaused() {
        require(isPaused(), "Contract not paused");
        _;
    }

    /// @notice Initializes the contract in paused state and with no admin.
    /// The contract instance can be used only as a call delegation target for a proxy.
    constructor() {
        _managedStorage().isPaused = true;
    }

    /// @notice Returns the current implementation address.
    function implementation() public view returns (address) {
        return _getImplementation();
    }

    /// @notice Returns the address of the current admin.
    function admin() public view returns (address) {
        return _getAdmin();
    }

    /// @notice Returns the proposed address to change the admin to.
    function proposedAdmin() public view returns (address) {
        return _managedStorage().proposedAdmin;
    }

    /// @notice Proposes a change of the admin of the contract.
    /// The proposed new admin must call `acceptAdmin` to finalize the change.
    /// To cancel a proposal propose a different address, e.g. the zero address.
    /// Can only be called by the current admin.
    /// @param newAdmin The proposed admin address.
    function proposeNewAdmin(address newAdmin) public onlyAdmin {
        emit NewAdminProposed(msg.sender, newAdmin);
        _managedStorage().proposedAdmin = newAdmin;
    }

    /// @notice Applies a proposed change of the admin of the contract.
    /// Sets the proposed admin to the zero address.
    /// Can only be called by the proposed admin.
    function acceptAdmin() public {
        require(proposedAdmin() == msg.sender, "Caller not the proposed admin");
        _updateAdmin(msg.sender);
    }

    /// @notice Changes the admin of the contract to address zero.
    /// It's no longer possible to change the admin or upgrade the contract afterwards.
    /// Can only be called by the current admin.
    function renounceAdmin() public onlyAdmin {
        _updateAdmin(address(0));
    }

    /// @notice Sets the current admin of the contract and clears the proposed admin.
    /// @param newAdmin The admin address being set. Can be the zero address.
    function _updateAdmin(address newAdmin) internal {
        emit AdminChanged(admin(), newAdmin);
        _managedStorage().proposedAdmin = address(0);
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /// @notice Grants the pauser role to an address. Callable only by the admin.
    /// @param pauser The granted address.
    function grantPauser(address pauser) public onlyAdmin {
        require(_managedStorage().pausers.add(pauser), "Address already is a pauser");
        emit PauserGranted(pauser, msg.sender);
    }

    /// @notice Revokes the pauser role from an address. Callable only by the admin.
    /// @param pauser The revoked address.
    function revokePauser(address pauser) public onlyAdmin {
        require(_managedStorage().pausers.remove(pauser), "Address is not a pauser");
        emit PauserRevoked(pauser, msg.sender);
    }

    /// @notice Checks if an address is a pauser.
    /// @param pauser The checked address.
    /// @return isAddrPauser True if the address is a pauser.
    function isPauser(address pauser) public view returns (bool isAddrPauser) {
        return _managedStorage().pausers.contains(pauser);
    }

    /// @notice Returns all the addresses with the pauser role.
    /// @return pausersList The list of all the pausers, ordered arbitrarily.
    /// The list's order may change after granting or revoking the pauser role.
    function allPausers() public view returns (address[] memory pausersList) {
        return _managedStorage().pausers.values();
    }

    /// @notice Returns true if the contract is paused, and false otherwise.
    function isPaused() public view returns (bool) {
        return _managedStorage().isPaused;
    }

    /// @notice Triggers stopped state. Callable only by the admin or a pauser.
    function pause() public onlyAdminOrPauser whenNotPaused {
        _managedStorage().isPaused = true;
        emit Paused(msg.sender);
    }

    /// @notice Returns to normal state. Callable only by the admin or a pauser.
    function unpause() public onlyAdminOrPauser whenPaused {
        _managedStorage().isPaused = false;
        emit Unpaused(msg.sender);
    }

    /// @notice Calculates the quasi ERC-1967 slot pointer.
    /// @param name The name of the slot, should be globally unique
    /// @return slot The slot pointer
    function _erc1967Slot(string memory name) internal pure returns (bytes32 slot) {
        // The original ERC-1967 subtracts 1 from the hash to get 1 storage slot
        // under an index without a known hash preimage which is enough to store a single address.
        // This implementation subtracts 1024 to get 1024 slots without a known preimage
        // allowing securely storing much larger structures.
        return bytes32(uint256(keccak256(bytes(name))) - 1024);
    }

    /// @notice Returns the Managed storage.
    /// @return storageRef The storage.
    function _managedStorage() internal view returns (ManagedStorage storage storageRef) {
        bytes32 slot = _managedStorageSlot;
        // slither-disable-next-line assembly
        assembly {
            storageRef.slot := slot
        }
    }

    /// @notice Authorizes the contract upgrade. See `UUPSUpgradeable` docs for more details.
    function _authorizeUpgrade(address /* newImplementation */ ) internal view override onlyAdmin {
        return;
    }
}

/// @notice A generic proxy for contracts implementing `Managed`.
contract ManagedProxy is ERC1967Proxy {
    constructor(Managed logic, address admin) ERC1967Proxy(address(logic), new bytes(0)) {
        _changeAdmin(admin);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {
    DripsHub,
    DripsReceiver,
    IERC20,
    SafeERC20,
    SplitsReceiver,
    UserMetadata
} from "./DripsHub.sol";
import {Managed} from "./Managed.sol";
import {Context, ERC2771Context} from "openzeppelin-contracts/metatx/ERC2771Context.sol";
import {StorageSlot} from "openzeppelin-contracts/utils/StorageSlot.sol";
import {
    ERC721,
    ERC721Burnable,
    IERC721,
    IERC721Metadata
} from "openzeppelin-contracts/token/ERC721/extensions/ERC721Burnable.sol";

/// @notice A DripsHub driver implementing token-based user identification.
/// Anybody can mint a new token and create a new identity.
/// Only the current holder of the token can control its user ID.
/// The token ID and the user ID controlled by it are always equal.
contract NFTDriver is ERC721Burnable, ERC2771Context, Managed {
    using SafeERC20 for IERC20;

    /// @notice The DripsHub address used by this driver.
    DripsHub public immutable dripsHub;
    /// @notice The driver ID which this driver uses when calling DripsHub.
    uint32 public immutable driverId;
    /// @notice The ERC-1967 storage slot holding a single `NFTDriverStorage` structure.
    bytes32 private immutable _nftDriverStorageSlot = _erc1967Slot("eip1967.nftDriver.storage");

    struct NFTDriverStorage {
        /// @notice The number of tokens minted without salt.
        uint64 mintedTokens;
        /// @notice The salts already used for minting tokens.
        mapping(address minter => mapping(uint64 salt => bool)) isSaltUsed;
    }

    /// @param _dripsHub The drips hub to use.
    /// @param forwarder The ERC-2771 forwarder to trust. May be the zero address.
    /// @param _driverId The driver ID to use when calling DripsHub.
    constructor(DripsHub _dripsHub, address forwarder, uint32 _driverId)
        ERC2771Context(forwarder)
        ERC721("", "")
    {
        dripsHub = _dripsHub;
        driverId = _driverId;
    }

    modifier onlyHolder(uint256 tokenId) {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: caller is not token owner or approved"
        );
        _;
    }

    /// @notice Get the ID of the next minted token.
    /// Every token ID is a 256-bit integer constructed by concatenating:
    /// `driverId (32 bits) | zeros (160 bits) | mintedTokensCounter (64 bits)`.
    /// @return tokenId The token ID. It's equal to the user ID controlled by it.
    function nextTokenId() public view returns (uint256 tokenId) {
        return calcTokenIdWithSalt(address(0), _nftDriverStorage().mintedTokens);
    }

    /// @notice Calculate the ID of the token minted with salt.
    /// Every token ID is a 256-bit integer constructed by concatenating:
    /// `driverId (32 bits) | minter (160 bits) | salt (64 bits)`.
    /// @param minter The minter of the token.
    /// @param salt The salt used for minting the token.
    /// @return tokenId The token ID. It's equal to the user ID controlled by it.
    function calcTokenIdWithSalt(address minter, uint64 salt)
        public
        view
        returns (uint256 tokenId)
    {
        // By assignment we get `tokenId` value:
        // `zeros (224 bits) | driverId (32 bits)`
        tokenId = driverId;
        // By bit shifting we get `tokenId` value:
        // `zeros (64 bits) | driverId (32 bits) | zeros (160 bits)`
        // By bit masking we get `tokenId` value:
        // `zeros (64 bits) | driverId (32 bits) | minter (160 bits)`
        tokenId = (tokenId << 160) | uint160(minter);
        // By bit shifting we get `tokenId` value:
        // `driverId (32 bits) | minter (160 bits) | zeros (64 bits)`
        // By bit masking we get `tokenId` value:
        // `driverId (32 bits) | minter (160 bits) | salt (64 bits)`
        tokenId = (tokenId << 64) | salt;
    }

    /// @notice Checks if the salt has already been used for minting a token.
    /// Each minter can use each salt only once, to mint a single token.
    /// @param minter The minter of the token.
    /// @param salt The salt used for minting the token.
    /// @return isUsed True if the salt has been used, false otherwise.
    function isSaltUsed(address minter, uint64 salt) public view returns (bool isUsed) {
        return _nftDriverStorage().isSaltUsed[minter][salt];
    }

    /// @notice Mints a new token controlling a new user ID and transfers it to an address.
    /// Emits user metadata for the new token.
    /// Usage of this method is discouraged, use `safeMint` whenever possible.
    /// @param to The address to transfer the minted token to.
    /// @param userMetadata The list of user metadata to emit for the minted token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @return tokenId The minted token ID. It's equal to the user ID controlled by it.
    function mint(address to, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        returns (uint256 tokenId)
    {
        tokenId = _registerTokenId();
        _mint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    /// @notice Mints a new token controlling a new user ID and safely transfers it to an address.
    /// Emits user metadata for the new token.
    /// @param to The address to transfer the minted token to.
    /// @param userMetadata The list of user metadata to emit for the minted token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @return tokenId The minted token ID. It's equal to the user ID controlled by it.
    function safeMint(address to, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        returns (uint256 tokenId)
    {
        tokenId = _registerTokenId();
        _safeMint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    /// @notice Registers the next token ID when minting.
    /// @return tokenId The registered token ID.
    function _registerTokenId() internal returns (uint256 tokenId) {
        tokenId = nextTokenId();
        _nftDriverStorage().mintedTokens++;
    }

    /// @notice Mints a new token controlling a new user ID and transfers it to an address.
    /// The token ID is deterministically derived from the caller's address and the salt.
    /// Each caller can use each salt only once, to mint a single token.
    /// Emits user metadata for the new token.
    /// Usage of this method is discouraged, use `safeMint` whenever possible.
    /// @param to The address to transfer the minted token to.
    /// @param userMetadata The list of user metadata to emit for the minted token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @return tokenId The minted token ID. It's equal to the user ID controlled by it.
    /// The ID is calculated using `calcTokenIdWithSalt` for the caller's address and the used salt.
    function mintWithSalt(uint64 salt, address to, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        returns (uint256 tokenId)
    {
        tokenId = _registerTokenIdWithSalt(salt);
        _mint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    /// @notice Mints a new token controlling a new user ID and safely transfers it to an address.
    /// The token ID is deterministically derived from the caller's address and the salt.
    /// Each caller can use each salt only once, to mint a single token.
    /// Emits user metadata for the new token.
    /// @param to The address to transfer the minted token to.
    /// @param userMetadata The list of user metadata to emit for the minted token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @return tokenId The minted token ID. It's equal to the user ID controlled by it.
    /// The ID is calculated using `calcTokenIdWithSalt` for the caller's address and the used salt.
    function safeMintWithSalt(uint64 salt, address to, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        returns (uint256 tokenId)
    {
        tokenId = _registerTokenIdWithSalt(salt);
        _safeMint(to, tokenId);
        _emitUserMetadata(tokenId, userMetadata);
    }

    /// @notice Registers the token ID minted with salt by the caller.
    /// Reverts if the caller has already used the salt.
    /// @return tokenId The registered token ID.
    function _registerTokenIdWithSalt(uint64 salt) internal returns (uint256 tokenId) {
        address minter = _msgSender();
        require(!isSaltUsed(minter, salt), "ERC721: token already minted");
        _nftDriverStorage().isSaltUsed[minter][salt] = true;
        return calcTokenIdWithSalt(minter, salt);
    }

    /// @notice Collects the user's received already split funds
    /// and transfers them out of the drips hub contract.
    /// @param tokenId The ID of the token representing the collecting user ID.
    /// The caller must be the owner of the token or be approved to use it.
    /// The token ID is equal to the user ID controlled by it.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param transferTo The address to send collected funds to
    /// @return amt The collected amount
    function collect(uint256 tokenId, IERC20 erc20, address transferTo)
        public
        whenNotPaused
        onlyHolder(tokenId)
        returns (uint128 amt)
    {
        amt = dripsHub.collect(tokenId, erc20);
        if (amt > 0) dripsHub.withdraw(erc20, transferTo, amt);
    }

    /// @notice Gives funds from the user to the receiver.
    /// The receiver can split and collect them immediately.
    /// Transfers the funds to be given from the message sender's wallet to the drips hub contract.
    /// @param tokenId The ID of the token representing the giving user ID.
    /// The caller must be the owner of the token or be approved to use it.
    /// The token ID is equal to the user ID controlled by it.
    /// @param receiver The receiver
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param amt The given amount
    function give(uint256 tokenId, uint256 receiver, IERC20 erc20, uint128 amt)
        public
        whenNotPaused
        onlyHolder(tokenId)
    {
        if (amt > 0) _transferFromCaller(erc20, amt);
        dripsHub.give(tokenId, receiver, erc20, amt);
    }

    /// @notice Sets the user's drips configuration.
    /// Transfers funds between the message sender's wallet and the drips hub contract
    /// to fulfil the change of the drips balance.
    /// @param tokenId The ID of the token representing the configured user ID.
    /// The caller must be the owner of the token or be approved to use it.
    /// The token ID is equal to the user ID controlled by it.
    /// @param erc20 The used ERC-20 token.
    /// It must preserve amounts, so if some amount of tokens is transferred to
    /// an address, then later the same amount must be transferable from that address.
    /// Tokens which rebase the holders' balances, collect taxes on transfers,
    /// or impose any restrictions on holding or transferring tokens are not supported.
    /// If you use such tokens in the protocol, they can get stuck or lost.
    /// @param currReceivers The current drips receivers list.
    /// It must be exactly the same as the last list set for the user with `setDrips`.
    /// If this is the first update, pass an empty array.
    /// @param balanceDelta The drips balance change to be applied.
    /// Positive to add funds to the drips balance, negative to remove them.
    /// @param newReceivers The list of the drips receivers of the sender to be set.
    /// Must be sorted by the receivers' addresses, deduplicated and without 0 amtPerSecs.
    /// @param maxEndHint1 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The first hint for finding the maximum end time when all drips stop due to funds
    /// running out after the balance is updated and the new receivers list is applied.
    /// Hints have no effect on the results of calling this function, except potentially saving gas.
    /// Hints are Unix timestamps used as the starting points for binary search for the time
    /// when funds run out in the range of timestamps from the current block's to `2^32`.
    /// Hints lower than the current timestamp are ignored.
    /// You can provide zero, one or two hints. The order of hints doesn't matter.
    /// Hints are the most effective when one of them is lower than or equal to
    /// the last timestamp when funds are still dripping, and the other one is strictly larger
    /// than that timestamp,the smaller the difference between such hints, the higher gas savings.
    /// The savings are the highest possible when one of the hints is equal to
    /// the last timestamp when funds are still dripping, and the other one is larger by 1.
    /// It's worth noting that the exact timestamp of the block in which this function is executed
    /// may affect correctness of the hints, especially if they're precise.
    /// Hints don't provide any benefits when balance is not enough to cover
    /// a single second of dripping or is enough to cover all drips until timestamp `2^32`.
    /// Even inaccurate hints can be useful, and providing a single hint
    /// or two hints that don't enclose the time when funds run out can still save some gas.
    /// Providing poor hints that don't reduce the number of binary search steps
    /// may cause slightly higher gas usage than not providing any hints.
    /// @param maxEndHint2 An optional parameter allowing gas optimization, pass `0` to ignore it.
    /// The second hint for finding the maximum end time, see `maxEndHint1` docs for more details.
    /// @param transferTo The address to send funds to in case of decreasing balance
    /// @return realBalanceDelta The actually applied drips balance change.
    function setDrips(
        uint256 tokenId,
        IERC20 erc20,
        DripsReceiver[] calldata currReceivers,
        int128 balanceDelta,
        DripsReceiver[] calldata newReceivers,
        // slither-disable-next-line similar-names
        uint32 maxEndHint1,
        uint32 maxEndHint2,
        address transferTo
    ) public whenNotPaused onlyHolder(tokenId) returns (int128 realBalanceDelta) {
        if (balanceDelta > 0) _transferFromCaller(erc20, uint128(balanceDelta));
        realBalanceDelta = dripsHub.setDrips(
            tokenId, erc20, currReceivers, balanceDelta, newReceivers, maxEndHint1, maxEndHint2
        );
        if (realBalanceDelta < 0) dripsHub.withdraw(erc20, transferTo, uint128(-realBalanceDelta));
    }

    /// @notice Sets user splits configuration. The configuration is common for all assets.
    /// Nothing happens to the currently splittable funds, but when they are split
    /// after this function finishes, the new splits configuration will be used.
    /// Because anybody can call `split` on `DripsHub`, calling this function may be frontrun
    /// and all the currently splittable funds will be split using the old splits configuration.
    /// @param tokenId The ID of the token representing the configured user ID.
    /// The caller must be the owner of the token or be approved to use it.
    /// The token ID is equal to the user ID controlled by it.
    /// @param receivers The list of the user's splits receivers to be set.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// Each splits receiver will be getting `weight / TOTAL_SPLITS_WEIGHT`
    /// share of the funds collected by the user.
    /// If the sum of weights of all receivers is less than `_TOTAL_SPLITS_WEIGHT`,
    /// some funds won't be split, but they will be left for the user to collect.
    /// It's valid to include the user's own `userId` in the list of receivers,
    /// but funds split to themselves return to their splittable balance and are not collectable.
    /// This is usually unwanted, because if splitting is repeated,
    /// funds split to themselves will be again split using the current configuration.
    /// Splitting 100% to self effectively blocks splitting unless the configuration is updated.
    function setSplits(uint256 tokenId, SplitsReceiver[] calldata receivers)
        public
        whenNotPaused
        onlyHolder(tokenId)
    {
        dripsHub.setSplits(tokenId, receivers);
    }

    /// @notice Emits the user metadata for the given token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @param tokenId The ID of the token representing the emitting user ID.
    /// The caller must be the owner of the token or be approved to use it.
    /// The token ID is equal to the user ID controlled by it.
    /// @param userMetadata The list of user metadata.
    function emitUserMetadata(uint256 tokenId, UserMetadata[] calldata userMetadata)
        public
        whenNotPaused
        onlyHolder(tokenId)
    {
        _emitUserMetadata(tokenId, userMetadata);
    }

    /// @notice Emits the user metadata for the given token.
    /// The keys and the values are not standardized by the protocol, it's up to the user
    /// to establish and follow conventions to ensure compatibility with the consumers.
    /// @param tokenId The ID of the token representing the emitting user ID.
    /// The token ID is equal to the user ID controlled by it.
    /// @param userMetadata The list of user metadata.
    function _emitUserMetadata(uint256 tokenId, UserMetadata[] calldata userMetadata) internal {
        if (userMetadata.length == 0) return;
        dripsHub.emitUserMetadata(tokenId, userMetadata);
    }

    /// @inheritdoc IERC721Metadata
    function name() public pure override returns (string memory) {
        return "DripsHub identity";
    }

    /// @inheritdoc IERC721Metadata
    function symbol() public pure override returns (string memory) {
        return "DHI";
    }

    /// @inheritdoc ERC721Burnable
    function burn(uint256 tokenId) public override whenNotPaused {
        super.burn(tokenId);
    }

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public override whenNotPaused {
        super.approve(to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        override
        whenNotPaused
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        whenNotPaused
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public override whenNotPaused {
        super.setApprovalForAll(operator, approved);
    }

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId)
        public
        override
        whenNotPaused
    {
        super.transferFrom(from, to, tokenId);
    }

    function _transferFromCaller(IERC20 erc20, uint128 amt) internal {
        erc20.safeTransferFrom(_msgSender(), address(dripsHub), amt);
    }

    // Workaround for https://github.com/ethereum/solidity/issues/12554
    function _msgSender() internal view override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    // Workaround for https://github.com/ethereum/solidity/issues/12554
    // slither-disable-next-line dead-code
    function _msgData() internal view override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @notice Returns the NFTDriver storage.
    /// @return storageRef The storage.
    function _nftDriverStorage() internal view returns (NFTDriverStorage storage storageRef) {
        bytes32 slot = _nftDriverStorageSlot;
        // slither-disable-next-line assembly
        assembly {
            storageRef.slot := slot
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

/// @notice A splits receiver
struct SplitsReceiver {
    /// @notice The user ID.
    uint256 userId;
    /// @notice The splits weight. Must never be zero.
    /// The user will be getting `weight / _TOTAL_SPLITS_WEIGHT`
    /// share of the funds collected by the splitting user.
    uint32 weight;
}

/// @notice Splits can keep track of at most `type(uint128).max`
/// which is `2 ^ 128 - 1` units of each asset.
/// It's up to the caller to guarantee that this limit is never exceeded,
/// failing to do so may result in a total protocol collapse.
abstract contract Splits {
    /// @notice Maximum number of splits receivers of a single user. Limits the cost of splitting.
    uint256 internal constant _MAX_SPLITS_RECEIVERS = 200;
    /// @notice The total splits weight of a user
    uint32 internal constant _TOTAL_SPLITS_WEIGHT = 1_000_000;
    /// @notice The total amount the contract can keep track of each asset.
    // slither-disable-next-line unused-state
    uint256 internal constant _MAX_TOTAL_SPLITS_BALANCE = type(uint128).max;
    /// @notice The storage slot holding a single `SplitsStorage` structure.
    bytes32 private immutable _splitsStorageSlot;

    /// @notice Emitted when a user collects funds
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param collected The collected amount
    event Collected(uint256 indexed userId, uint256 indexed assetId, uint128 collected);

    /// @notice Emitted when funds are split from a user to a receiver.
    /// This is caused by the user collecting received funds.
    /// @param userId The user ID
    /// @param receiver The splits receiver user ID
    /// @param assetId The used asset ID
    /// @param amt The amount split to the receiver
    event Split(
        uint256 indexed userId, uint256 indexed receiver, uint256 indexed assetId, uint128 amt
    );

    /// @notice Emitted when funds are made collectable after splitting.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param amt The amount made collectable for the user on top of what was collectable before.
    event Collectable(uint256 indexed userId, uint256 indexed assetId, uint128 amt);

    /// @notice Emitted when funds are given from the user to the receiver.
    /// @param userId The user ID
    /// @param receiver The receiver user ID
    /// @param assetId The used asset ID
    /// @param amt The given amount
    event Given(
        uint256 indexed userId, uint256 indexed receiver, uint256 indexed assetId, uint128 amt
    );

    /// @notice Emitted when the user's splits are updated.
    /// @param userId The user ID
    /// @param receiversHash The splits receivers list hash
    event SplitsSet(uint256 indexed userId, bytes32 indexed receiversHash);

    /// @notice Emitted when a user is seen in a splits receivers list.
    /// @param receiversHash The splits receivers list hash
    /// @param userId The user ID.
    /// @param weight The splits weight. Must never be zero.
    /// The user will be getting `weight / _TOTAL_SPLITS_WEIGHT`
    /// share of the funds collected by the splitting user.
    event SplitsReceiverSeen(bytes32 indexed receiversHash, uint256 indexed userId, uint32 weight);

    struct SplitsStorage {
        /// @notice User splits states.
        mapping(uint256 userId => SplitsState) splitsStates;
    }

    struct SplitsState {
        /// @notice The user's splits configuration hash, see `hashSplits`.
        bytes32 splitsHash;
        /// @notice The user's splits balances.
        mapping(uint256 assetId => SplitsBalance) balances;
    }

    struct SplitsBalance {
        /// @notice The not yet split balance, must be split before collecting by the user.
        uint128 splittable;
        /// @notice The already split balance, ready to be collected by the user.
        uint128 collectable;
    }

    /// @param splitsStorageSlot The storage slot to holding a single `SplitsStorage` structure.
    constructor(bytes32 splitsStorageSlot) {
        _splitsStorageSlot = splitsStorageSlot;
    }

    function _addSplittable(uint256 userId, uint256 assetId, uint128 amt) internal {
        _splitsStorage().splitsStates[userId].balances[assetId].splittable += amt;
    }

    /// @notice Returns user's received but not split yet funds.
    /// @param userId The user ID
    /// @param assetId The used asset ID.
    /// @return amt The amount received but not split yet.
    function _splittable(uint256 userId, uint256 assetId) internal view returns (uint128 amt) {
        return _splitsStorage().splitsStates[userId].balances[assetId].splittable;
    }

    /// @notice Calculate the result of splitting an amount using the current splits configuration.
    /// @param userId The user ID
    /// @param currReceivers The list of the user's current splits receivers.
    /// It must be exactly the same as the last list set for the user with `_setSplits`.
    /// @param amount The amount being split.
    /// @return collectableAmt The amount made collectable for the user
    /// on top of what was collectable before.
    /// @return splitAmt The amount split to the user's splits receivers
    function _splitResult(uint256 userId, SplitsReceiver[] memory currReceivers, uint128 amount)
        internal
        view
        returns (uint128 collectableAmt, uint128 splitAmt)
    {
        _assertCurrSplits(userId, currReceivers);
        if (amount == 0) {
            return (0, 0);
        }
        unchecked {
            uint160 splitsWeight = 0;
            for (uint256 i = 0; i < currReceivers.length; i++) {
                splitsWeight += currReceivers[i].weight;
            }
            splitAmt = uint128(amount * splitsWeight / _TOTAL_SPLITS_WEIGHT);
            collectableAmt = amount - splitAmt;
        }
    }

    /// @notice Splits the user's splittable funds among receivers.
    /// The entire splittable balance of the given asset is split.
    /// All split funds are split using the current splits configuration.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @param currReceivers The list of the user's current splits receivers.
    /// It must be exactly the same as the last list set for the user with `_setSplits`.
    /// @return collectableAmt The amount made collectable for the user
    /// on top of what was collectable before.
    /// @return splitAmt The amount split to the user's splits receivers
    function _split(uint256 userId, uint256 assetId, SplitsReceiver[] memory currReceivers)
        internal
        returns (uint128 collectableAmt, uint128 splitAmt)
    {
        _assertCurrSplits(userId, currReceivers);
        SplitsBalance storage balance = _splitsStorage().splitsStates[userId].balances[assetId];

        collectableAmt = balance.splittable;
        if (collectableAmt == 0) {
            return (0, 0);
        }
        balance.splittable = 0;

        unchecked {
            uint160 splitsWeight = 0;
            for (uint256 i = 0; i < currReceivers.length; i++) {
                splitsWeight += currReceivers[i].weight;
                uint128 currSplitAmt =
                    uint128(collectableAmt * splitsWeight / _TOTAL_SPLITS_WEIGHT) - splitAmt;
                splitAmt += currSplitAmt;
                uint256 receiver = currReceivers[i].userId;
                _addSplittable(receiver, assetId, currSplitAmt);
                emit Split(userId, receiver, assetId, currSplitAmt);
            }
            collectableAmt -= splitAmt;
            balance.collectable += collectableAmt;
        }
        emit Collectable(userId, assetId, collectableAmt);
    }

    /// @notice Returns user's received funds already split and ready to be collected.
    /// @param userId The user ID
    /// @param assetId The used asset ID.
    /// @return amt The collectable amount.
    function _collectable(uint256 userId, uint256 assetId) internal view returns (uint128 amt) {
        return _splitsStorage().splitsStates[userId].balances[assetId].collectable;
    }

    /// @notice Collects user's received already split funds
    /// and transfers them out of the drips hub contract to msg.sender.
    /// @param userId The user ID
    /// @param assetId The used asset ID
    /// @return amt The collected amount
    function _collect(uint256 userId, uint256 assetId) internal returns (uint128 amt) {
        SplitsBalance storage balance = _splitsStorage().splitsStates[userId].balances[assetId];
        amt = balance.collectable;
        balance.collectable = 0;
        emit Collected(userId, assetId, amt);
    }

    /// @notice Gives funds from the user to the receiver.
    /// The receiver can split and collect them immediately.
    /// Transfers the funds to be given from the user's wallet to the drips hub contract.
    /// @param userId The user ID
    /// @param receiver The receiver
    /// @param assetId The used asset ID
    /// @param amt The given amount
    function _give(uint256 userId, uint256 receiver, uint256 assetId, uint128 amt) internal {
        _addSplittable(receiver, assetId, amt);
        emit Given(userId, receiver, assetId, amt);
    }

    /// @notice Sets user splits configuration. The configuration is common for all assets.
    /// Nothing happens to the currently splittable funds, but when they are split
    /// after this function finishes, the new splits configuration will be used.
    /// @param userId The user ID
    /// @param receivers The list of the user's splits receivers to be set.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// Each splits receiver will be getting `weight / _TOTAL_SPLITS_WEIGHT`
    /// share of the funds collected by the user.
    /// If the sum of weights of all receivers is less than `_TOTAL_SPLITS_WEIGHT`,
    /// some funds won't be split, but they will be left for the user to collect.
    /// It's valid to include the user's own `userId` in the list of receivers,
    /// but funds split to themselves return to their splittable balance and are not collectable.
    /// This is usually unwanted, because if splitting is repeated,
    /// funds split to themselves will be again split using the current configuration.
    /// Splitting 100% to self effectively blocks splitting unless the configuration is updated.
    function _setSplits(uint256 userId, SplitsReceiver[] memory receivers) internal {
        SplitsState storage state = _splitsStorage().splitsStates[userId];
        bytes32 newSplitsHash = _hashSplits(receivers);
        emit SplitsSet(userId, newSplitsHash);
        if (newSplitsHash != state.splitsHash) {
            _assertSplitsValid(receivers, newSplitsHash);
            state.splitsHash = newSplitsHash;
        }
    }

    /// @notice Validates a list of splits receivers and emits events for them
    /// @param receivers The list of splits receivers
    /// @param receiversHash The hash of the list of splits receivers.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    function _assertSplitsValid(SplitsReceiver[] memory receivers, bytes32 receiversHash) private {
        unchecked {
            require(receivers.length <= _MAX_SPLITS_RECEIVERS, "Too many splits receivers");
            uint64 totalWeight = 0;
            // slither-disable-next-line uninitialized-local
            uint256 prevUserId;
            for (uint256 i = 0; i < receivers.length; i++) {
                SplitsReceiver memory receiver = receivers[i];
                uint32 weight = receiver.weight;
                require(weight != 0, "Splits receiver weight is zero");
                totalWeight += weight;
                uint256 userId = receiver.userId;
                if (i > 0) require(prevUserId < userId, "Splits receivers not sorted");
                prevUserId = userId;
                emit SplitsReceiverSeen(receiversHash, userId, weight);
            }
            require(totalWeight <= _TOTAL_SPLITS_WEIGHT, "Splits weights sum too high");
        }
    }

    /// @notice Asserts that the list of splits receivers is the user's currently used one.
    /// @param userId The user ID
    /// @param currReceivers The list of the user's current splits receivers.
    function _assertCurrSplits(uint256 userId, SplitsReceiver[] memory currReceivers)
        internal
        view
    {
        require(
            _hashSplits(currReceivers) == _splitsHash(userId), "Invalid current splits receivers"
        );
    }

    /// @notice Current user's splits hash, see `hashSplits`.
    /// @param userId The user ID
    /// @return currSplitsHash The current user's splits hash
    function _splitsHash(uint256 userId) internal view returns (bytes32 currSplitsHash) {
        return _splitsStorage().splitsStates[userId].splitsHash;
    }

    /// @notice Calculates the hash of the list of splits receivers.
    /// @param receivers The list of the splits receivers.
    /// Must be sorted by the splits receivers' addresses, deduplicated and without 0 weights.
    /// @return receiversHash The hash of the list of splits receivers.
    function _hashSplits(SplitsReceiver[] memory receivers)
        internal
        pure
        returns (bytes32 receiversHash)
    {
        if (receivers.length == 0) {
            return bytes32(0);
        }
        return keccak256(abi.encode(receivers));
    }

    /// @notice Returns the Splits storage.
    /// @return splitsStorage The storage.
    function _splitsStorage() private view returns (SplitsStorage storage splitsStorage) {
        bytes32 slot = _splitsStorageSlot;
        // slither-disable-next-line assembly
        assembly {
            splitsStorage.slot := slot
        }
    }
}