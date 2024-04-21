// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Incubator
/// @author: manifold.xyz

import "./manifold/ERC721Creator.sol";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                              //
//                                                                                                              //
//                              ___ _  _  ___ _   _ ___   _ _____ ___  ___                                      //
//                             |_ _| \| |/ __| | | | _ ) /_\_   _/ _ \| _ \                                     //
//                              | || .` | (__| |_| | _ \/ _ \| || (_) |   /                                     //
//                             |___|_|\_|\___|\___/|___/_/ \_\_| \___/|_|_\                                     //
//                              ............by gabriella morton............                                     //
//                                                                                                              //
//                                           ...:::^^^^^^^::::....                                              //
//                                    ..:^^~~^^^^~~^^^!7!^^:^^^^^^^^:::..                                       //
//                                .:^^^^~~7~^~!!!7!!!!!!7!~~~^^^^^^:^^^:::::..                                  //
//                            .:^^^^^^!7??YPPP555GPPGBBBBBBGGPPYYYJJ7^:::::::^::..                              //
//                         .:^^^^~~!!!777!7YY7~!!7J5YJ?77?JY555PPPPBBGYJ!^^:^^^^^:::.                           //
//                      .::^^~~~~~~~~~^~?7~!?7~~~^~!~~!!~~~~^^^~!!?Y5GGG555J7!^::^^^::..                        //
//                    .::^~!!~~^~~~!777!77!!~~~~~!!!!!7?!~~^~!?7!!!~^!?5GGPYJYYJ~:::^:^^:.                      //
//                  ::::~~^^~!77????777Y5P5Y??JY5PGBBBGGGGP5YPB&BGPJ!~^^!YGBJ^!JP57^:::::::.                    //
//                ::^::^^^!7!!!~~!5PPB#&##&#BBGGGGGBGP5PPPGB####BBB#&BP?~~~JPPJ7!75Y7^:::::::.                  //
//              .::~~^^^^~~~^~~!?GPJ?5GG5P5YJ?77!!~~~~~!~~!!!7?YY5P5G&&&G7~~~777JJ7!JP!::::::::.                //
//             ::^~!~^^^^^~!?~!!??JY55J?7!!!!!!!!~~~~~!!!!~~~~~77!!77JYB&&P?!~^^^!Y?^!Y7~:::::::.               //
//           .:^!!~^^^^^^~?5?7JPP5Y7!!!!~~!!?YPPPP555YYJ?7!~~!77~~~~!?J?Y#&#GY7~~^^7~^~7?7::::^:::              //
//          .:~55~^^^^^~?5P5GBG5?7!~!!7775B#&&@@@@@@&&&&&&#BPY?!~~~~~~!JYYB&&&&Y!~~^^^^!YY7::::::::             //
//         .:~P&P~^~^^?P5JJJ?7!7!~!?YPG&&@@&&&#BGGPPPPPGGB#&&&#G?~~~~~~~!JGB#&&&P~~~^^^^Y5Y!::::::::.           //
//        .:^7GPJ^~^^5G777!!7?777?P#&&&#GP5YYJ?????77!!7!~!JPB#&&[email protected]&#J~^^^^^^7P5^::::::::           //
//       .:^7?7^^~~~GB?77!7J?!?PB&#GGJ!!!!!~!!!!!!!!!!!!~~~~~!?5#&&5~~~~~~~!GB&&&#7^~^^^^!JPJ^^:::::::          //
//       :^7^!^^~~^5B!7?!!?!75B##5?!!~~~~!!!!!~~!7?JYP7~J?~!^^^!JG&&Y~!~~~~~!G&&&@5^^^^^^!PGB?:^::::::.         //
//      :^?J?~^^~^Y&JJJ~~7!?PGBY!!7!!~~!!!!!?Y5G#&@@@@&B#&&&G5?^[email protected]#Y!!~~~~~7#&#&#~^^^^^^G&GY7::::::::.        //
//     .:!BB?^^^^?BY??~!?!?PGP7~!!~!~~~!?YPG&@@@@@&&@&&@@@@@@@@J^!?&&G7!~!~~~~G#BP&?^^~~^^B577P^:^::::^:        //
//     :^^!7^^^^?&5?7~!?!7P&BJ!!!!!!!~~~P&@@@@&##BPJYG5J5GP5#@@&!!Y&&B5~!!~~~!Y##Y&5~~^^^~B!J?J:^^::::::        //
//     :^^^^^^^^JPJ7~?Y!!?BGJY?!!!!!!!!Y&@@@&BG5?7!!!!7!~^^^[email protected]&B!~J#&GP~!~~~~!!5B#&J~~^^^^JJ#Y5^^^^^^^^:.       //
//    .:^::^^^^^^Y5!?GJ!7PBPJY7!!!!!!?G&&&@@&[email protected]&Y~^Y#PP5~~~~~~^^!5&&J~~~^^^~J&7~^^^^^^~^::       //
//    .^^::^^^~~J#575G?!J#B?YJ!!!!!!!YB&@@@&&57!!!!!!7??!~~775J^^!GB7G!~~~^^^^~~P&BJ^~!~^^~G&?^^^^^^^^:::       //
//    .^::^^^^^[email protected]#GJB5!!J&#YP?!!!!!!7Y#&@@&&&?!!!YPJ77!??~~~!~~~!PB?Y7~~~~^^^~^?#BBJ!~~~^^Y&P?^^^^^~~^:^:       //
//    .:::^^^^^[email protected]&GPBY!~?&&P5?77!!!!!Y&#&@@&[email protected]@@&#PYY?7~!!!?PGJJ7~~!!~~~~^7BBBP?!~~~^^Y#J~^^^!Y#?^:::       //
//     ::^^^^^^[email protected]&GGBJ~~?&&G5Y7777!!77B&@@@&P7?!?#@&#&&BGPY!!?YPPYJ7!~~!~~!7^!BBG5!!~!~~~?BB7~~^^[email protected]#G!::.       //
//     ::^^^^^^[email protected]@5BBJ~!5&#[email protected]@@@&#?!7?7J5PGBGPGP5PG5J?!!!~~~!~~~~7GBG?~~~~!~^JGGP7!~^~B&BP~^:        //
//     .^:^^^^^[email protected]@?P#5!!7Y&B5P57777!!5&@&@@&&#?!7~~!!!!!7JJ?!~~~~!7!^^~7?7JG##P7~~~!!~7PPJYJ~~^^P&&#J^^:        //
//      ::::^^^~#@G5#G777!5&GBGJ7777777P&@&&&&&57!~~~~~~~!!?7~~^~!7~~~!7JP#G5J!!!~!!7Y&G7J77~^^P&@GY~^^:        //
//      .::^^~^^[email protected]&BBB?!77!5#B#GY?7?77~~G&&&&&&&BY!^^^~~~~!!~^^^^!!!7?JJ5P5J!~~~~~!Y5#B5?!!!~~P&#G?!^^^         //
//       ::^^^^^^#@&BP5!!!!!Y###BGY7~~~!!?G#&@&&&&#GY?77!!7!~~!!!?5BGBBBGY?7?!~~75GG##5J!~!~!G&BGJ!^^~.         //
//        ::::^^^!&@&GPYJ!~!7?P#&#BGJ~~~!!~7YB&&&&&&&&&##&&&######&#BPY?!~~~!!^~YPY#BY7!!!~!BB&#5~~~^.          //
//        .::::^^^?#@&B5YY!!7?7?P#&BBP5J7!~~~^7Y5PB&&###&&&&#BGPP5J?!~~~~^^^~7YGBPPY7~!7!!JBPG&5~^~^:           //
//         .:::^^^^[email protected]@&555!!!7!~~5GBGGB#GYJ7!!~~~~~7?J??YPY?!~^^~~~~~!~~^?PB###BJ!~~~~~7G#YG&P~^~^:            //
//           :^^^^^^^?&@&GPY!7!^~!!7J5PPB#&&&BP?!~^~~77!!~!!~~^^~~~!!7?JY5555P5Y7^~~~^^J&&GBGJ~~^^.             //
//            :^^^^^^^!5&@#BPJ?~!77777?JJYY5PG#&#BP5JJJYJ77?!!!7JPGGGG5J7!7?7!^^^^~^^?B&&#G5!^^^^.              //
//             .:^^^~~^^[email protected]@@G5J777777~~~!??JYY55G#&&&&&&&&#BBGPP5YJ?77!~~^^^~^^^^^7G&&#BY~^^^^^                //
//               .^^^^^^^^7G&@&B5Y??7~~~~^^~~!77!!7?J5PPP555YJ?77!7!!!!~~^^^^^^^~JB&&&#G7^:^::.                 //
//                 :^^^~~^^~!?G&@&BGYJ!~~^^^~~^^^^~~!!7!!!!~^~~~~!!!~~~^^^^^~!?5B&@&BP?^^^^:.                   //
//                  .:^~~^^~~^^!5&@@@&&GYYJ7~~^^^^^~~!!!!~!~~~~~~~~~~~!!7J5GB&&@&BP7^::^^^.                     //
//                     :^~~^^^^~^~?YG#&@@&&##BGP5J??7!!~~^~~!!!!!7???JPB#&&&&&B57^:::^^:.                       //
//                       .:^^^^~^^:^^~~JG#&@@@@@@&&&&##BGP5PGGGB##&&&@@&&&B5!^:::^^^:.                          //
//                          .:^^^^:^^^^^^~~!?YP#&&@@@&&&&&&&&&&&#BGPY?!~^^::::::::.                             //
//                              .::^^^^^^^:::::^^~7J5YJJJ?7!~~^^^^^^::::::::::..                                //
//                                  ..:::::^:^^^:::^:::^^::::::^:::::::::..                                     //
//                                        ....::::^^::^::::::::::....                                           //
//                                                                                                              //
//                                                                                                              //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract INC is ERC721Creator {
    constructor() ERC721Creator("Incubator", "INC") {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract ERC721Creator is Proxy {
    
    constructor(string memory name, string memory symbol) {
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = 0x2d3fC875de7Fe7Da43AD0afa0E7023c9B91D06b1;
        Address.functionDelegateCall(
            0x2d3fC875de7Fe7Da43AD0afa0E7023c9B91D06b1,
            abi.encodeWithSignature("initialize(string,string)", name, symbol)
        );
    }
        
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Returns the current implementation address.
     */
     function implementation() public view returns (address) {
        return _implementation();
    }

    function _implementation() internal override view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
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