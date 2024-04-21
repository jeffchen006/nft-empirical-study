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

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./interfaces/IAllowList.sol";

/// @author Matter Labs
abstract contract AllowListed {
    modifier senderCanCallFunction(IAllowList _allowList) {
        // Preventing the stack too deep error
        {
            require(_allowList.canCall(msg.sender, address(this), msg.sig), "nr");
        }
        _;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



interface IAllowList {
    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Access mode of target contract is changed
    event UpdateAccessMode(address indexed target, AccessMode previousMode, AccessMode newMode);

    /// @notice Permission to call is changed
    event UpdateCallPermission(address indexed caller, address indexed target, bytes4 indexed functionSig, bool status);

    /// @notice Type of access to a specific contract includes three different modes
    /// @param Closed No one has access to the contract
    /// @param SpecialAccessOnly Any address with granted special access can interact with a contract (see `hasSpecialAccessToCall`)
    /// @param Public Everyone can interact with a contract
    enum AccessMode {
        Closed,
        SpecialAccessOnly,
        Public
    }

    /// @dev A struct that contains withdrawal limit data of a token
    /// @param withdrawalLimitation Whether any withdrawal limitation is placed or not
    /// @param withdrawalFactor Percentage of allowed withdrawal. A withdrawalFactor of 10 means maximum %10 of bridge balance can be withdrawn
    struct Withdrawal {
        bool withdrawalLimitation;
        uint256 withdrawalFactor;
    }

    /// @dev A struct that contains deposit limit data of a token
    /// @param depositLimitation Whether any deposit limitation is placed or not
    /// @param depositCap The maximum amount that can be deposited.
    struct Deposit {
        bool depositLimitation;
        uint256 depositCap;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    function getAccessMode(address _target) external view returns (AccessMode);

    function hasSpecialAccessToCall(
        address _caller,
        address _target,
        bytes4 _functionSig
    ) external view returns (bool);

    function canCall(
        address _caller,
        address _target,
        bytes4 _functionSig
    ) external view returns (bool);

    function getTokenWithdrawalLimitData(address _l1Token) external view returns (Withdrawal memory);

    function getTokenDepositLimitData(address _l1Token) external view returns (Deposit memory);

    /*//////////////////////////////////////////////////////////////
                           ALLOW LIST LOGIC
    //////////////////////////////////////////////////////////////*/

    function setBatchAccessMode(address[] calldata _targets, AccessMode[] calldata _accessMode) external;

    function setAccessMode(address _target, AccessMode _accessMode) external;

    function setBatchPermissionToCall(
        address[] calldata _callers,
        address[] calldata _targets,
        bytes4[] calldata _functionSigs,
        bool[] calldata _enables
    ) external;

    function setPermissionToCall(
        address _caller,
        address _target,
        bytes4 _functionSig,
        bool _enable
    ) external;

    /*//////////////////////////////////////////////////////////////
                           WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function setWithdrawalLimit(
        address _l1Token,
        bool _withdrawalLimitation,
        uint256 _withdrawalFactor
    ) external;

    /*//////////////////////////////////////////////////////////////
                           DEPOSIT LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function setDepositLimit(
        address _l1Token,
        bool _depositLimitation,
        uint256 _depositCap
    ) external;
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



interface IL2Messenger {
    function sendToL1(bytes memory _message) external returns (bytes32);
}

interface IContractDeployer {
    struct ForceDeployment {
        bytes32 bytecodeHash;
        address newAddress;
        bool callConstructor;
        uint256 value;
        bytes input;
    }

    function forceDeployOnAddresses(ForceDeployment[] calldata _deployParams) external;

    function create2(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        bytes calldata _input
    ) external;
}

uint160 constant SYSTEM_CONTRACTS_OFFSET = 0x8000; // 2^15

address constant BOOTLOADER_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x01);

address constant DEPLOYER_SYSTEM_CONTRACT_ADDRESS = address(SYSTEM_CONTRACTS_OFFSET + 0x06);

// A contract that is allowed to deploy any codehash
// on any address. To be used only during an upgrade.
address constant FORCE_DEPLOYER = address(SYSTEM_CONTRACTS_OFFSET + 0x07);

IL2Messenger constant L2_MESSENGER = IL2Messenger(address(SYSTEM_CONTRACTS_OFFSET + 0x08));

library L2ContractHelper {
    bytes32 constant CREATE2_PREFIX = keccak256("zksyncCreate2");

    function sendMessageToL1(bytes memory _message) internal returns (bytes32) {
        return L2_MESSENGER.sendToL1(_message);
    }

    function hashL2Bytecode(bytes memory _bytecode) internal pure returns (bytes32 hashedBytecode) {
        // Note that the length of the bytecode
        // must be provided in 32-byte words.
        require(_bytecode.length % 32 == 0, "po");

        uint256 bytecodeLenInWords = _bytecode.length / 32;
        require(bytecodeLenInWords < 2**16, "pp"); // bytecode length must be less than 2^16 words
        require(bytecodeLenInWords % 2 == 1, "pr"); // bytecode length in words must be odd
        hashedBytecode = sha256(_bytecode) & 0x00000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        // Setting the version of the hash
        hashedBytecode = (hashedBytecode | bytes32(uint256(1 << 248)));
        // Setting the length
        hashedBytecode = hashedBytecode | bytes32(bytecodeLenInWords << 224);
    }

    /// @notice Validates the bytecodehash
    function validateBytecodeHash(bytes32 _bytecodeHash) internal pure {
        uint8 version = uint8(_bytecodeHash[0]);
        require(version == 1 && _bytecodeHash[1] == bytes1(0), "zf"); // Incorrectly formatted bytecodeHash

        require(bytecodeLen(_bytecodeHash) % 2 == 1, "uy"); // Code length in words must be odd
    }

    /// @notice returns the length of the bytecode
    function bytecodeLen(bytes32 _bytecodeHash) internal pure returns (uint256 codeLengthInWords) {
        codeLengthInWords = uint256(uint8(_bytecodeHash[2])) * 256 + uint256(uint8(_bytecodeHash[3]));
    }

    function computeCreate2Address(
        address _sender,
        bytes32 _salt,
        bytes32 _bytecodeHash,
        bytes32 _constructorInputHash
    ) internal pure returns (address) {
        bytes32 senderBytes = bytes32(uint256(uint160(_sender)));
        bytes32 data = keccak256(
            bytes.concat(CREATE2_PREFIX, senderBytes, _salt, _bytecodeHash, _constructorInputHash)
        );

        return address(uint160(uint256(data)));
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



library UncheckedMath {
    function uncheckedInc(uint256 _number) internal pure returns (uint256) {
        unchecked {
            return _number + 1;
        }
    }

    function uncheckedAdd(uint256 _lhs, uint256 _rhs) internal pure returns (uint256) {
        unchecked {
            return _lhs + _rhs;
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/**
 * @author Matter Labs
 * @dev The library provides a set of functions that help read data from an "abi.encodePacked" byte array.
 * @dev Each of the functions accepts the `bytes memory` and the offset where data should be read and returns a value of a certain type.
 *
 * @dev WARNING!
 * 1) Functions don't check the length of the bytes array, so it can go out of bounds.
 * The user of the library must check for bytes length before using any functions from the library!
 *
 * 2) Read variables are not cleaned up - https://docs.soliditylang.org/en/v0.8.16/internals/variable_cleanup.html.
 * Using data in inline assembly can lead to unexpected behavior!
 */
library UnsafeBytes {
    function readUint32(bytes memory _bytes, uint256 _start) internal pure returns (uint32 result, uint256 offset) {
        assembly {
            offset := add(_start, 4)
            result := mload(add(_bytes, offset))
        }
    }

    function readAddress(bytes memory _bytes, uint256 _start) internal pure returns (address result, uint256 offset) {
        assembly {
            offset := add(_start, 20)
            result := mload(add(_bytes, offset))
        }
    }

    function readUint256(bytes memory _bytes, uint256 _start) internal pure returns (uint256 result, uint256 offset) {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }

    function readBytes32(bytes memory _bytes, uint256 _start) internal pure returns (bytes32 result, uint256 offset) {
        assembly {
            offset := add(_start, 32)
            result := mload(add(_bytes, offset))
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



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
 *
 * _Since v2.5.0:_ this module is now much more gas efficient, given net gas
 * metering changes introduced in the Istanbul hardfork.
 */
abstract contract ReentrancyGuard {
    /// @dev Address of lock flag variable.
    /// @dev Flag is placed at random memory location to not interfere with Storage contract.
    uint256 private constant LOCK_FLAG_ADDRESS = 0x8e94fed44239eb2314ab7a406345e6c5a8f0ccedf3b600de3d004e672c33abf4; // keccak256("ReentrancyGuard") - 1;

    // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/566a774222707e424896c0c390a84dc3c13bdcb2/contracts/security/ReentrancyGuard.sol
    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier reentrancyGuardInitializer() {
        _initializeReentrancyGuard();
        _;
    }

    function _initializeReentrancyGuard() private {
        uint256 lockSlotOldValue;

        // Storing an initial non-zero value makes deployment a bit more
        // expensive but in exchange every call to nonReentrant
        // will be cheaper.
        assembly {
            lockSlotOldValue := sload(LOCK_FLAG_ADDRESS)
            sstore(LOCK_FLAG_ADDRESS, _NOT_ENTERED)
        }

        // Check that storage slot for reentrancy guard is empty to rule out possibility of slot conflict
        require(lockSlotOldValue == 0, "1B");
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        uint256 _status;
        assembly {
            _status := sload(LOCK_FLAG_ADDRESS)
        }

        // On the first call to nonReentrant, _notEntered will be true
        require(_status == _NOT_ENTERED, "r1");

        // Any calls to nonReentrant after this point will fail
        assembly {
            sstore(LOCK_FLAG_ADDRESS, _ENTERED)
        }

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        assembly {
            sstore(LOCK_FLAG_ADDRESS, _NOT_ENTERED)
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: Apache-2.0

/*
 * Copyright 2019-2021, Offchain Labs, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */



library AddressAliasHelper {
    uint160 constant offset = uint160(0x1111000000000000000000000000000000001111);

    /// @notice Utility function that converts the address in the L1 that submitted a tx to
    /// the inbox to the msg.sender viewed in the L2
    /// @param l1Address the address in the L1 that triggered the tx to L2
    /// @return l2Address L2 address as viewed in msg.sender
    function applyL1ToL2Alias(address l1Address) internal pure returns (address l2Address) {
        unchecked {
            l2Address = address(uint160(l1Address) + offset);
        }
    }

    /// @notice Utility function that converts the msg.sender viewed in the L2 to the
    /// address in the L1 that submitted a tx to the inbox
    /// @param l2Address L2 address as viewed in msg.sender
    /// @return l1Address the address in the L1 that triggered the tx to L2
    function undoL1ToL2Alias(address l2Address) internal pure returns (address l1Address) {
        unchecked {
            l1Address = address(uint160(l2Address) - offset);
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/// @dev `keccak256("")`
bytes32 constant EMPTY_STRING_KECCAK = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

/// @dev Bytes in raw L2 log
/// @dev Equal to the bytes size of the tuple - (uint8 ShardId, bool isService, uint16 txNumberInBlock, address sender, bytes32 key, bytes32 value)
uint256 constant L2_TO_L1_LOG_SERIALIZE_SIZE = 88;

/// @dev The maximum length of the bytes array with L2 -> L1 logs
uint256 constant MAX_L2_TO_L1_LOGS_COMMITMENT_BYTES = 4 + L2_TO_L1_LOG_SERIALIZE_SIZE * 512;

/// @dev L2 -> L1 logs Merkle tree height
uint256 constant L2_TO_L1_LOG_MERKLE_TREE_HEIGHT = 9;

/// @dev The value of default leaf hash for L2 -> L1 logs Merkle tree
/// @dev An incomplete fixed-size tree is filled with this value to be a full binary tree
/// @dev Actually equal to the `keccak256(new bytes(L2_TO_L1_LOG_SERIALIZE_SIZE))`
bytes32 constant L2_L1_LOGS_TREE_DEFAULT_LEAF_HASH = 0x72abee45b59e344af8a6e520241c4744aff26ed411f4c4b00f8af09adada43ba;

/// @dev Number of bytes in a one initial storage change
/// @dev Equal to the bytes size of the tuple - (bytes32 key, bytes32 value)
uint256 constant INITIAL_STORAGE_CHANGE_SERIALIZE_SIZE = 64;

/// @dev The maximum length of the bytes array with initial storage changes
uint256 constant MAX_INITIAL_STORAGE_CHANGES_COMMITMENT_BYTES = 4 + INITIAL_STORAGE_CHANGE_SERIALIZE_SIZE * 4765;

/// @dev Number of bytes in a one repeated storage change
/// @dev Equal to the bytes size of the tuple - (bytes8 key, bytes32 value)
uint256 constant REPEATED_STORAGE_CHANGE_SERIALIZE_SIZE = 40;

/// @dev The maximum length of the bytes array with repeated storage changes
uint256 constant MAX_REPEATED_STORAGE_CHANGES_COMMITMENT_BYTES = 4 + REPEATED_STORAGE_CHANGE_SERIALIZE_SIZE * 7564;

// TODO: change constant to the real root hash of empty Merkle tree (SMA-184)
bytes32 constant DEFAULT_L2_LOGS_TREE_ROOT_HASH = bytes32(0);

/// @dev The address of the special smart contract that can send arbitrary length message as an L2 log
address constant L2_TO_L1_MESSENGER = address(0x8008);

/// @dev The address of the bootloader start program
address constant L2_BOOTLOADER_ADDRESS = address(0x8001);

/// @dev The address of the eth token system contract
address constant L2_ETH_TOKEN_ADDRESS = address(0x800a);

/// @dev The address of the known code storage system contract
address constant L2_KNOWN_CODE_STORAGE_ADDRESS = address(0x8004);

/// @dev The address of the context system contract
address constant L2_SYSTEM_CONTEXT_ADDRESS = address(0x800b);

/// @dev Denotes the first byte of the zkSync transaction that came from L1.
uint256 constant PRIORITY_OPERATION_L2_TX_TYPE = 255;

/// @dev The amount of time in seconds the validator has to process the priority transaction
/// NOTE: The constant is set to zero for the Alpha release period
uint256 constant PRIORITY_EXPIRATION = 0 days;

/// @dev Notice period before activation preparation status of upgrade mode (in seconds)
/// @dev NOTE: we must reserve for users enough time to send full exit operation, wait maximum time for processing this operation and withdraw funds from it.
uint256 constant UPGRADE_NOTICE_PERIOD = 0;

/// @dev Timestamp - seconds since unix epoch
uint256 constant COMMIT_TIMESTAMP_NOT_OLDER = 365 days;

/// @dev Maximum available error between real commit block timestamp and analog used in the verifier (in seconds)
/// @dev Must be used cause miner's `block.timestamp` value can differ on some small value (as we know - 15 seconds)
uint256 constant COMMIT_TIMESTAMP_APPROXIMATION_DELTA = 365 days;

/// @dev Bit mask to apply for verifier public input before verifying.
uint256 constant INPUT_MASK = 452312848583266388373324160190187140051835877600158453279131187530910662655;

/// @dev The maximum number of L2 gas that a user can request for an L2 transaction
uint256 constant L2_TX_MAX_GAS_LIMIT = 80000000;

/// @dev The maximum number of the pubdata an L2 operation should be allowed to use.
uint256 constant MAX_PUBDATA_PER_BLOCK = 110000;

/// @dev The maximum number of the pubdata an priority operation should be allowed to use.
/// For now, it is somewhat lower than the maximum number of pubdata allowed for an L2 transaction,
/// to ensure that the transaction is definitely processable on L2 despite any potential overhead.
uint256 constant PRIORITY_TX_MAX_PUBDATA = 99000;

/// @dev The default price per L2 gas to be used for L1->L2 transactions
uint256 constant FAIR_L2_GAS_PRICE = 500000000;

/// @dev Even though the price for 1 byte of pubdata is 16 L1 gas, we have a slightly increased
/// value.
uint256 constant L1_GAS_PER_PUBDATA_BYTE = 17;

/// @dev The computational overhead of processing an L2 block.
uint256 constant BLOCK_OVERHEAD_L2_GAS = 1200000;

/// @dev The overhead in L1 gas of interacting with the L1
uint256 constant BLOCK_OVERHEAD_L1_GAS = 1000000;

/// @dev The equivalent in L1 pubdata of L1 gas used for working with L1
uint256 constant BLOCK_OVERHEAD_PUBDATA = BLOCK_OVERHEAD_L1_GAS / L1_GAS_PER_PUBDATA_BYTE;

/// @dev The maximum number of transactions in L2 block:
uint256 constant MAX_TRANSACTIONS_IN_BLOCK = 1024;

/// @dev The size of the bootloader memory dedicated to the encodings of transactions
uint256 constant BOOTLOADER_TX_ENCODING_SPACE = 519017;

/// @dev The intrinsic cost of the L1->l2 transaction in computational L2 gas
uint256 constant L1_TX_INTRINSIC_L2_GAS = 167157;

/// @dev The intrinsic cost of the L1->l2 transaction in pubdata
uint256 constant L1_TX_INTRINSIC_PUBDATA = 88;

/// @dev The minimal base price for L1 transaction
uint256 constant L1_TX_MIN_L2_GAS_BASE = 173484;

/// @dev The number of L2 gas the transaction starts costing more with each 544 bytes of encoding
uint256 constant L1_TX_DELTA_544_ENCODING_BYTES = 1656;

/// @dev The number of L2 gas an L1->L2 transaction gains with each new factory dependency
uint256 constant L1_TX_DELTA_FACTORY_DEPS_L2_GAS = 2473;

/// @dev The number of L2 gas an L1->L2 transaction gains with each new factory dependency
uint256 constant L1_TX_DELTA_FACTORY_DEPS_PUBDATA = 64;

/// @dev The number of pubdata an L1->L2 transaction requires with each new factory dependency
uint256 constant MAX_NEW_FACTORY_DEPS = 32;

/// @dev The default L2 gasPricePerPubdata to be used in bridges.
uint256 constant DEFAULT_L2_GAS_PRICE_PER_PUBDATA = 800;

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../Storage.sol";
import "../../common/ReentrancyGuard.sol";
import "../../common/AllowListed.sol";

/// @title Base contract containing functions accessible to the other facets.
/// @author Matter Labs
contract Base is ReentrancyGuard, AllowListed {
    AppStorage internal s;

    /// @notice Checks that the message sender is an active governor
    modifier onlyGovernor() {
        require(msg.sender == s.governor, "1g"); // only by governor
        _;
    }

    /// @notice Checks if validator is active
    modifier onlyValidator() {
        require(s.validators[msg.sender], "1h"); // validator is not active
        _;
    }

    modifier onlySecurityCouncil() {
        require(msg.sender == s.upgrades.securityCouncil, "a9"); // not a security council
        _;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/IMailbox.sol";
import "../libraries/Merkle.sol";
import "../libraries/PriorityQueue.sol";
import "../Storage.sol";
import "../Config.sol";
import "../../common/libraries/UncheckedMath.sol";
import "../../common/libraries/UnsafeBytes.sol";
import "../../common/L2ContractHelper.sol";
import "../../vendor/AddressAliasHelper.sol";
import "./Base.sol";

/// @title zkSync Mailbox contract providing interfaces for L1 <-> L2 interaction.
/// @author Matter Labs
contract MailboxFacet is Base, IMailbox {
    using UncheckedMath for uint256;
    using PriorityQueue for PriorityQueue.Queue;

    /// @notice Prove that a specific arbitrary-length message was sent in a specific L2 block number
    /// @param _blockNumber The executed L2 block number in which the message appeared
    /// @param _index The position in the L2 logs Merkle tree of the l2Log that was sent with the message
    /// @param _message Information about the sent message: sender address, the message itself, tx index in the L2 block where the message was sent
    /// @param _proof Merkle proof for inclusion of L2 log that was sent with the message
    /// @return Whether the proof is valid
    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message memory _message,
        bytes32[] calldata _proof
    ) public view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _L2MessageToLog(_message), _proof);
    }

    /// @notice Prove that a specific L2 log was sent in a specific L2 block
    /// @param _blockNumber The executed L2 block number in which the log appeared
    /// @param _index The position of the l2log in the L2 logs Merkle tree
    /// @param _log Information about the sent log
    /// @param _proof Merkle proof for inclusion of the L2 log
    /// @return Whether the proof is correct and L2 log is included in block
    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool) {
        return _proveL2LogInclusion(_blockNumber, _index, _log, _proof);
    }

    /// @notice Prove that the L1 -> L2 transaction was processed with the specified status.
    /// @param _l2TxHash The L2 canonical transaction hash
    /// @param _l2BlockNumber The L2 block number where the transaction was processed
    /// @param _l2MessageIndex The position in the L2 logs Merkle tree of the l2Log that was sent with the message
    /// @param _l2TxNumberInBlock The L2 transaction number in a block, in which the log was sent
    /// @param _merkleProof The Merkle proof of the processing L1 -> L2 transaction
    /// @param _status The execution status of the L1 -> L2 transaction (true - success & 0 - fail)
    /// @return Whether the proof is correct and the transaction was actually executed with provided status
    /// NOTE: It may return `false` for incorrect proof, but it doesn't mean that the L1 -> L2 transaction has an opposite status!
    function proveL1ToL2TransactionStatus(
        bytes32 _l2TxHash,
        uint256 _l2BlockNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBlock,
        bytes32[] calldata _merkleProof,
        TxStatus _status
    ) public view override returns (bool) {
        // Bootloader sends an L2 -> L1 log only after processing the L1 -> L2 transaction.
        // Thus, we can verify that the L1 -> L2 transaction was included in the L2 block with specified status.
        //
        // The semantics of such L2 -> L1 log is always:
        // - sender = BOOTLOADER_ADDRESS
        // - key = hash(L1ToL2Transaction)
        // - value = status of the processing transaction (1 - success & 0 - fail)
        // - isService = true (just a conventional value)
        // - l2ShardId = 0 (means that L1 -> L2 transaction was processed in a rollup shard, other shards are not available yet anyway)
        // - txNumberInBlock = number of transaction in the block
        L2Log memory l2Log = L2Log({
            l2ShardId: 0,
            isService: true,
            txNumberInBlock: _l2TxNumberInBlock,
            sender: BOOTLOADER_ADDRESS,
            key: _l2TxHash,
            value: bytes32(uint256(_status))
        });
        return _proveL2LogInclusion(_l2BlockNumber, _l2MessageIndex, l2Log, _merkleProof);
    }

    /// @notice Transfer ether from the contract to the receiver
    /// @dev Reverts only if the transfer call failed
    function _withdrawFunds(address _to, uint256 _amount) internal {
        bool callSuccess;
        // Low-level assembly call, to avoid any memory copying (save gas)
        assembly {
            callSuccess := call(gas(), _to, _amount, 0, 0, 0, 0)
        }
        require(callSuccess, "pz");
    }

    /// @dev Prove that a specific L2 log was sent in a specific L2 block number
    function _proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) internal view returns (bool) {
        require(_blockNumber <= s.totalBlocksExecuted, "xx");

        bytes32 hashedLog = keccak256(
            abi.encodePacked(_log.l2ShardId, _log.isService, _log.txNumberInBlock, _log.sender, _log.key, _log.value)
        );
        // Check that hashed log is not the default one,
        // otherwise it means that the value is out of range of sent L2 -> L1 logs
        require(hashedLog != L2_L1_LOGS_TREE_DEFAULT_LEAF_HASH, "tw");
        // Check that the proof length is exactly the same as tree height, to prevent
        // any shorter/longer paths attack on the Merkle path validation
        require(_proof.length == L2_TO_L1_LOG_MERKLE_TREE_HEIGHT, "rz");

        bytes32 calculatedRootHash = Merkle.calculateRoot(_proof, _index, hashedLog);
        bytes32 actualRootHash = s.l2LogsRootHashes[_blockNumber];

        return actualRootHash == calculatedRootHash;
    }

    /// @dev Convert arbitrary-length message to the raw l2 log
    function _L2MessageToLog(L2Message memory _message) internal pure returns (L2Log memory) {
        return
            L2Log({
                l2ShardId: 0,
                isService: true,
                txNumberInBlock: _message.txNumberInBlock,
                sender: L2_TO_L1_MESSENGER,
                key: bytes32(uint256(uint160(_message.sender))),
                value: keccak256(_message.data)
            });
    }

    /// @notice Estimates the cost in Ether of requesting execution of an L2 transaction from L1
    /// @return The estimated L2 gas for the transaction to be paid
    function l2TransactionBaseCost(
        uint256, // _gasPrice
        uint256, // _l2GasLimit
        uint256 // _l2GasPerPubdataByteLimit
    ) public pure returns (uint256) {
        // TODO: for now, all the L1->L2 transaction are free.
        // Below the return is the correct code for estimation of the base cost for
        // the transaction.
        return 0;

        // uint256 l2GasPrice = _deriveL2GasPrice(
        //     _gasPrice,
        //      _l2GasPerPubdataByteLimit
        // );
        // return l2GasPrice * _l2GasLimit;
    }

    /// @notice Derives the price for L2 gas in ETH to be paid.
    /// @param _l1GasPrice The gas price on L1.
    /// @param _gasPricePerPubdata The price for each pubdata byte in L2 gas
    function _deriveL2GasPrice(uint256 _l1GasPrice, uint256 _gasPricePerPubdata) internal pure returns (uint256) {
        uint256 pubdataPriceETH = L1_GAS_PER_PUBDATA_BYTE * _l1GasPrice;
        uint256 minL2GasPriceETH = (pubdataPriceETH + _gasPricePerPubdata - 1) / _gasPricePerPubdata;

        return Math.max(FAIR_L2_GAS_PRICE, minL2GasPriceETH);
    }

    /// @notice Finalize the withdrawal and release funds
    /// @param _l2BlockNumber The L2 block number where the withdrawal was processed
    /// @param _l2MessageIndex The position in the L2 logs Merkle tree of the l2Log that was sent with the message
    /// @param _l2TxNumberInBlock The L2 transaction number in a block, in which the log was sent
    /// @param _message The L2 withdraw data, stored in an L2 -> L1 message
    /// @param _merkleProof The Merkle proof of the inclusion L2 -> L1 message about withdrawal initialization
    function finalizeEthWithdrawal(
        uint256 _l2BlockNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBlock,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external override nonReentrant {
        require(!s.isEthWithdrawalFinalized[_l2BlockNumber][_l2MessageIndex], "jj");

        L2Message memory l2ToL1Message = L2Message({
            txNumberInBlock: _l2TxNumberInBlock,
            sender: L2_ETH_TOKEN_ADDRESS,
            data: _message
        });

        (address _l1WithdrawReceiver, uint256 _amount) = _parseL2WithdrawalMessage(_message);

        _verifyWithdrawalLimit(_amount);

        bool proofValid = proveL2MessageInclusion(_l2BlockNumber, _l2MessageIndex, l2ToL1Message, _merkleProof);
        require(proofValid, "pi"); // Failed to verify that withdrawal was actually initialized on L2

        s.isEthWithdrawalFinalized[_l2BlockNumber][_l2MessageIndex] = true;
        _withdrawFunds(_l1WithdrawReceiver, _amount);

        emit EthWithdrawalFinalized(_l1WithdrawReceiver, _amount);
    }

    function _verifyWithdrawalLimit(uint256 _amount) internal {
        IAllowList.Withdrawal memory limitData = IAllowList(s.allowList).getTokenWithdrawalLimitData(address(0)); // address(0) denotes the ETH
        if (!limitData.withdrawalLimitation) return; // no withdrwawal limitation is placed for ETH
        if (block.timestamp > s.lastWithdrawalLimitReset + 1 days) {
            // The _amount should be <= %10 of balance
            require(_amount <= (limitData.withdrawalFactor * address(this).balance) / 100, "w3");
            s.withdrawnAmountInWindow = _amount; // reseting the withdrawn amount
            s.lastWithdrawalLimitReset = block.timestamp;
        } else {
            // The _amount + withdrawn amount should be <= %10 of balance
            require(
                _amount + s.withdrawnAmountInWindow <= (limitData.withdrawalFactor * address(this).balance) / 100,
                "w4"
            );
            s.withdrawnAmountInWindow += _amount; // accumulate the withdrawn amount for ETH
        }
    }

    /// @notice Request execution of L2 transaction from L1.
    /// @param _contractL2 The L2 receiver address
    /// @param _l2Value `msg.value` of L2 transaction
    /// @param _calldata The input of the L2 transaction
    /// @param _l2GasLimit Maximum amount of L2 gas that transaction can consume during execution on L2
    /// @param _l2GasPerPubdataByteLimit The maximum amount L2 gas that the operator may charge the user for.
    /// @param _factoryDeps An array of L2 bytecodes that will be marked as known on L2
    /// @param _refundRecipient The address on L2 that will receive the refund for the transaction. If the transaction fails,
    /// it will also be the address to receive `_l2Value`.
    /// @return canonicalTxHash The hash of the requested L2 transaction. This hash can be used to follow the transaction status
    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        address _refundRecipient
    ) external payable nonReentrant senderCanCallFunction(s.allowList) returns (bytes32 canonicalTxHash) {
        // Change the sender address if it is a smart contract to prevent address collision between L1 and L2.
        // Please note, currently zkSync address derivation is different from Ethereum one, but it may be changed in the future.
        address sender = msg.sender;
        if (sender != tx.origin) {
            sender = AddressAliasHelper.applyL1ToL2Alias(msg.sender);
        }

        // The L1 -> L2 transaction may be failed and funds will be sent to the `_refundRecipient`,
        // so we use `msg.value` instead of `_l2Value` as the bridged amount.
        _verifyDepositLimit(msg.sender, msg.value);
        canonicalTxHash = _requestL2Transaction(
            sender,
            _contractL2,
            _l2Value,
            _calldata,
            _l2GasLimit,
            _l2GasPerPubdataByteLimit,
            _factoryDeps,
            false,
            _refundRecipient
        );
    }

    function _verifyDepositLimit(address _depositor, uint256 _amount) internal {
        IAllowList.Deposit memory limitData = IAllowList(s.allowList).getTokenDepositLimitData(address(0)); // address(0) denotes the ETH
        if (!limitData.depositLimitation) return; // no deposit limitation is placed for ETH

        require(s.totalDepositedAmountPerUser[_depositor] + _amount <= limitData.depositCap, "d2");
        s.totalDepositedAmountPerUser[_depositor] += _amount;
    }

    function _requestL2Transaction(
        address _sender,
        address _contractAddressL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        bool _isFree,
        address _refundRecipient
    ) internal returns (bytes32 canonicalTxHash) {
        require(_factoryDeps.length <= MAX_NEW_FACTORY_DEPS, "uj");
        uint64 expirationTimestamp = uint64(block.timestamp + PRIORITY_EXPIRATION); // Safe to cast
        uint256 txId = s.priorityQueue.getTotalPriorityTxs();

        // Checking that the user provided enough ether to pay for the transaction.
        // Using a new scope to prevent "stack too deep" error
        {
            uint256 baseCost = _isFree ? 0 : l2TransactionBaseCost(tx.gasprice, _l2GasLimit, _l2GasPerPubdataByteLimit);
            require(msg.value >= baseCost + _l2Value);
        }

        // Here we manually assign fields for the struct to prevent "stack too deep" error
        WritePriorityOpParams memory params;
        params.sender = _sender;
        params.txId = txId;
        params.l2Value = _l2Value;
        params.contractAddressL2 = _contractAddressL2;
        params.expirationTimestamp = expirationTimestamp;
        params.l2GasLimit = _l2GasLimit;
        params.l2GasPricePerPubdata = _l2GasPerPubdataByteLimit;
        params.valueToMint = msg.value;
        params.refundRecipient = _refundRecipient == address(0) ? _sender : _refundRecipient;

        canonicalTxHash = _writePriorityOp(params, _calldata, _factoryDeps);
    }

    function _serializeL2Transaction(
        WritePriorityOpParams memory _priorityOpParams,
        bytes calldata _calldata,
        bytes[] calldata _factoryDeps
    ) internal pure returns (L2CanonicalTransaction memory transaction) {
        // Saving these two parameters in the local variables prevents
        // "stack too deep error"
        uint256 toMint = _priorityOpParams.valueToMint;
        address refundRecipient = _priorityOpParams.refundRecipient;
        transaction = serializeL2Transaction(
            _priorityOpParams.txId,
            _priorityOpParams.l2Value,
            _priorityOpParams.sender,
            _priorityOpParams.contractAddressL2,
            _calldata,
            _priorityOpParams.l2GasLimit,
            _priorityOpParams.l2GasPricePerPubdata,
            _factoryDeps,
            toMint,
            refundRecipient
        );
    }

    /// @notice Stores a transaction record in storage & send event about that
    function _writePriorityOp(
        WritePriorityOpParams memory _priorityOpParams,
        bytes calldata _calldata,
        bytes[] calldata _factoryDeps
    ) internal returns (bytes32 canonicalTxHash) {
        L2CanonicalTransaction memory transaction = _serializeL2Transaction(_priorityOpParams, _calldata, _factoryDeps);

        bytes memory transactionEncoding = abi.encode(transaction);

        uint256 l2GasForTxBody = _getTransactionBodyGasLimit(
            _priorityOpParams.l2GasLimit,
            _priorityOpParams.l2GasPricePerPubdata,
            transactionEncoding.length
        );

        // Ensuring that the transaction is provable
        require(l2GasForTxBody <= s.priorityTxMaxGasLimit, "ui");
        // Ensuring that the transaction can not output more pubdata than is processable
        require(l2GasForTxBody / _priorityOpParams.l2GasPricePerPubdata <= PRIORITY_TX_MAX_PUBDATA, "uk");

        // Ensuring that the transaction covers the minimal costs for its processing:
        // hashing its content, publishing the factory dependencies, etc.
        require(
            _getMinimalPriorityTransactionGasLimit(
                transactionEncoding.length,
                _factoryDeps.length,
                _priorityOpParams.l2GasPricePerPubdata
            ) <= _priorityOpParams.l2GasLimit,
            "um"
        );

        canonicalTxHash = keccak256(transactionEncoding);

        s.priorityQueue.pushBack(
            PriorityOperation({
                canonicalTxHash: canonicalTxHash,
                expirationTimestamp: _priorityOpParams.expirationTimestamp,
                layer2Tip: uint192(0) // TODO: Restore after fee modeling will be stable. (SMA-1230)
            })
        );

        // Data that is needed for the operator to simulate priority queue offchain
        emit NewPriorityRequest(
            _priorityOpParams.txId,
            canonicalTxHash,
            _priorityOpParams.expirationTimestamp,
            transaction,
            _factoryDeps
        );
    }

    function _getMinimalPriorityTransactionGasLimit(
        uint256 _encodingLength,
        uint256 _numberOfFactoryDependencies,
        uint256 _l2GasPricePerPubdata
    ) internal pure returns (uint256) {
        uint256 costForComputation;
        {
            // Adding the intrinsic cost for the transaction, i.e. auxilary prices which can not be easily accounted for
            costForComputation = L1_TX_INTRINSIC_L2_GAS;

            // Taking into account the hashing costs that depend on the length of the transaction
            // Note that, L1_TX_DELTA_544_ENCODING_BYTES is the delta in price for each 544 bytes of
            // the transaction's encoding. It is taken as LCM between 136 and 32 (the length for each keccak round
            // and the size of each new encoding word).
            costForComputation += Math.ceilDiv(_encodingLength * L1_TX_DELTA_544_ENCODING_BYTES, 544);

            // Taking into the account the additional costs of providing new factory dependenies
            costForComputation += _numberOfFactoryDependencies * L1_TX_DELTA_FACTORY_DEPS_L2_GAS;

            // There is a minimal amount of computational L2 gas that the transaction should cover
            costForComputation = Math.max(costForComputation, L1_TX_MIN_L2_GAS_BASE);
        }

        uint256 costForPubdata = 0;
        {
            // Adding the intrinsic cost for the transaction, i.e. auxilary prices which can not be easily accounted for
            costForPubdata = L1_TX_INTRINSIC_PUBDATA * _l2GasPricePerPubdata;

            // Taking into the account the additional costs of providing new factory dependenies
            costForPubdata += _numberOfFactoryDependencies * L1_TX_DELTA_FACTORY_DEPS_PUBDATA * _l2GasPricePerPubdata;
        }

        return costForComputation + costForPubdata;
    }

    /// @dev Accepts the parameters of the l2 transaction and converts it to the canonical form.
    /// @param _txId Priority operation ID, used as a unique identifier so that transactions always have a different hash
    /// @param _l2Value `msg.value` of L2 transaction. Please note, this ether is not transferred with requesting priority op,
    /// but will be taken from the balance in L2 during the execution
    /// @param _sender The L2 address of the account that initiates the transaction
    /// @param _contractAddressL2 The L2 receiver address
    /// @param _calldata The input of the L2 transaction
    /// @param _l2GasLimit Maximum amount of L2 gas that transaction can consume during execution on L2
    /// @param _l2GasPerPubdataByteLimit The maximum price in L2 gas per pubdata byte that the user can be charged by the operator in this transaction
    /// @param _factoryDeps An array of L2 bytecodes that will be marked as known on L2
    /// @param _toMint The amount of ether to be minted with this transaction
    /// @param _refundRecipient The address on L2 that will receive the refund for the transaction. If the transaction fails,
    /// it will also be the address to receive `_l2Value`.
    /// @return The canonical form of the l2 transaction parameters
    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        uint256 _toMint,
        address _refundRecipient
    ) public pure returns (L2CanonicalTransaction memory) {
        return
            L2CanonicalTransaction({
                txType: PRIORITY_OPERATION_L2_TX_TYPE,
                from: uint256(uint160(_sender)),
                to: uint256(uint160(_contractAddressL2)),
                gasLimit: _l2GasLimit,
                gasPerPubdataByteLimit: _l2GasPerPubdataByteLimit,
                maxFeePerGas: uint256(0),
                maxPriorityFeePerGas: uint256(0),
                paymaster: uint256(0),
                // Note, that the priority operation id is used as "nonce" for L1->L2 transactions
                nonce: uint256(_txId),
                value: _l2Value,
                reserved: [_toMint, uint256(uint160(_refundRecipient)), 0, 0],
                data: _calldata,
                signature: new bytes(0),
                factoryDeps: _hashFactoryDeps(_factoryDeps),
                paymasterInput: new bytes(0),
                reservedDynamic: new bytes(0)
            });
    }

    /// @notice Hashes the L2 bytecodes and returns them in the format in which they are processed by the bootloader
    function _hashFactoryDeps(bytes[] calldata _factoryDeps)
        internal
        pure
        returns (uint256[] memory hashedFactoryDeps)
    {
        uint256 factoryDepsLen = _factoryDeps.length;
        hashedFactoryDeps = new uint256[](factoryDepsLen);
        for (uint256 i = 0; i < factoryDepsLen; i = i.uncheckedInc()) {
            bytes32 hashedBytecode = L2ContractHelper.hashL2Bytecode(_factoryDeps[i]);

            // Store the resulting hash sequentially in bytes.
            assembly {
                mstore(add(hashedFactoryDeps, mul(add(i, 1), 32)), hashedBytecode)
            }
        }
    }

    /// @notice Based on the total L2 gas limit and several other parameters of the transaction
    /// returns the part of the L2 gas that will be spent on the block's overhead.
    /// @dev The details of how this function works can be checked in the documentation
    /// of the fee model of zkSync. The appropriate comments are also present
    /// in the Rust implementation description of function `get_maximal_allowed_overhead`.
    /// @param _totalGasLimit The L2 gas limit that includes both the overhead for processing the block
    /// and the L2 gas needed to process the transaction itself (i.e. the actual gasLimit that will be used for the transaction).
    function _getOverheadForTransaction(
        uint256 _totalGasLimit,
        uint256, // _gasPricePerPubdata
        uint256 // _encodingLength
    ) internal pure returns (uint256 blockOverheadForTransaction) {
        // TODO: (SMA-1715) make users pay for overhead
        return 0;
    }

    /// @notice Based on the full L2 gas limit (that includes the block overhead) and other
    /// properties of the transaction, returns the l2GasLimit for the body of the transaction (the actual execution).
    /// @param _totalGasLimit The L2 gas limit that includes both the overhead for processing the block
    /// and the L2 gas needed to process the transaction itself (i.e. the actual l2GasLimit that will be used for the transaction).
    /// @param _gasPricePerPubdata The L2 gas price for each byte of pubdata.
    /// @param _encodingLength The length of the ABI-encoding of the transaction.
    function _getTransactionBodyGasLimit(
        uint256 _totalGasLimit,
        uint256 _gasPricePerPubdata,
        uint256 _encodingLength
    ) internal pure returns (uint256 txBodyGasLimit) {
        uint256 overhead = _getOverheadForTransaction(_totalGasLimit, _gasPricePerPubdata, _encodingLength);

        unchecked {
            // The implementation of the `getOverheadForTransaction` function
            // enforces the fact that _totalGasLimit >= overhead.
            txBodyGasLimit = _totalGasLimit - overhead;
        }
    }

    /// @dev Decode the withdraw message that came from L2
    function _parseL2WithdrawalMessage(bytes memory _message)
        internal
        pure
        returns (address l1Receiver, uint256 amount)
    {
        // Check that the message length is correct.
        // It should be equal to the length of the function signature + address + uint256 = 4 + 20 + 32 = 56 (bytes).
        require(_message.length == 56);

        (uint32 functionSignature, uint256 offset) = UnsafeBytes.readUint32(_message, 0);
        require(bytes4(functionSignature) == this.finalizeEthWithdrawal.selector);

        (l1Receiver, offset) = UnsafeBytes.readAddress(_message, offset);
        (amount, offset) = UnsafeBytes.readUint256(_message, offset);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import {L2Log, L2Message} from "../Storage.sol";

/// @dev The enum that represents the transaction execution status
/// @param Failure The transaction execution failed
/// @param Success The transaction execution succeeded
enum TxStatus {
    Failure,
    Success
}

interface IMailbox {
    /// @dev Structure that includes all fields of the L2 transaction
    /// @dev The hash of this structure is the "canonical L2 transaction hash" and can be used as a unique identifier of a tx
    /// @param txType The tx type number, depending on which the L2 transaction can be interpreted differently
    /// @param from The sender's address. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param to The recipient's address. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param gasLimit The L2 gas limit for L2 transaction. Analog to the `gasLimit` on an L1 transactions
    /// @param gasPerPubdataByteLimit Maximum number of L2 gas that will cost one byte of pubdata (every piece of data that will be stored on L1 as calldata)
    /// @param maxFeePerGas The absolute maximum sender willing to pay per unit of L2 gas to get the transaction included in a block. Analog to the EIP-1559 `maxFeePerGas` on an L1 transactions
    /// @param maxPriorityFeePerGas The additional fee that is paid directly to the validator to incentivize them to include the transaction in a block. Analog to the EIP-1559 `maxPriorityFeePerGas` on an L1 transactions
    /// @param paymaster The address of the EIP-4337 paymaster, that will pay fees for the transaction. `uint256` type for possible address format changes and maintaining backward compatibility
    /// @param nonce The nonce of the transaction. For L1->L2 transactions it is the priority operation Id.
    /// @param value The value to pass with the transaction
    /// @param reserved The fixed-length fields for usage in a future extension of transaction formats
    /// @param data The calldata that is transmitted for the transaction call
    /// @param signature An abstract set of bytes that are used for transaction authorization
    /// @param factoryDeps The set of L2 bytecode hashes whose preimages were shown on L1
    /// @param paymasterInput The arbitrary-length data that is used as a calldata to the paymaster pre-call
    /// @param reservedDynamic The arbitrary-length field for usage in a future extension of transaction formats
    struct L2CanonicalTransaction {
        uint256 txType;
        uint256 from;
        uint256 to;
        uint256 gasLimit;
        uint256 gasPerPubdataByteLimit;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        uint256 paymaster;
        uint256 nonce;
        uint256 value;
        // In the future, we might want to add some
        // new fields to the struct. The `txData` struct
        // is to be passed to account and any changes to its structure
        // would mean a breaking change to these accounts. To prevent this,
        // we should keep some fields as "reserved".
        // It is also recommended that their length is fixed, since
        // it would allow easier proof integration (in case we will need
        // some special circuit for preprocessing transactions).
        uint256[4] reserved;
        bytes data;
        bytes signature;
        uint256[] factoryDeps;
        bytes paymasterInput;
        // Reserved dynamic type for the future use-case. Using it should be avoided,
        // But it is still here, just in case we want to enable some additional functionality.
        bytes reservedDynamic;
    }

    /// @dev Internal structure that contains the parameters for the writePriorityOp
    /// internal function.
    /// @param sender The sender's address.
    /// @param txId The id of the priority transaction.
    /// @param l2Value The msg.value of the L2 transaction.
    /// @param contractAddressL2 The address of the contract on L2 to call.
    /// @param expirationTimestamp The timestamp by which the priority operation must be processed by the operator.
    /// @param l2GasLimit The limit of the L2 gas for the L2 transaction
    /// @param l2GasPricePerPubdata The price for a single pubdata byte in L2 gas.
    /// @param valueToMint The amount of ether that should be minted on L2 as the result of this transaction.
    /// @param refundRecipient The recipient of the refund for the transaction on L2. If the transaction fails, then
    /// this address will receive the `l2Value`.
    struct WritePriorityOpParams {
        address sender;
        uint256 txId;
        uint256 l2Value;
        address contractAddressL2;
        uint64 expirationTimestamp;
        uint256 l2GasLimit;
        uint256 l2GasPricePerPubdata;
        uint256 valueToMint;
        address refundRecipient;
    }

    function proveL2MessageInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Message calldata _message,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function proveL2LogInclusion(
        uint256 _blockNumber,
        uint256 _index,
        L2Log memory _log,
        bytes32[] calldata _proof
    ) external view returns (bool);

    function proveL1ToL2TransactionStatus(
        bytes32 _l2TxHash,
        uint256 _l2BlockNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBlock,
        bytes32[] calldata _merkleProof,
        TxStatus _status
    ) external view returns (bool);

    function serializeL2Transaction(
        uint256 _txId,
        uint256 _l2Value,
        address _sender,
        address _contractAddressL2,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        uint256 _toMint,
        address _refundRecipient
    ) external pure returns (L2CanonicalTransaction memory);

    function finalizeEthWithdrawal(
        uint256 _l2BlockNumber,
        uint256 _l2MessageIndex,
        uint16 _l2TxNumberInBlock,
        bytes calldata _message,
        bytes32[] calldata _merkleProof
    ) external;

    function requestL2Transaction(
        address _contractL2,
        uint256 _l2Value,
        bytes calldata _calldata,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit,
        bytes[] calldata _factoryDeps,
        address _refundRecipient
    ) external payable returns (bytes32 canonicalTxHash);

    function l2TransactionBaseCost(
        uint256 _gasPrice,
        uint256 _l2GasLimit,
        uint256 _l2GasPerPubdataByteLimit
    ) external view returns (uint256);

    /// @notice New priority request event. Emitted when a request is placed into the priority queue
    /// @param txId Serial number of the priority operation
    /// @param txHash keccak256 hash of encoded transaction representation
    /// @param expirationTimestamp Timestamp up to which priority request should be processed
    /// @param transaction The whole transaction structure that is requested to be executed on L2
    /// @param factoryDeps An array of bytecodes that were shown in the L1 public data. Will be marked as known bytecodes in L2
    event NewPriorityRequest(
        uint256 txId,
        bytes32 txHash,
        uint64 expirationTimestamp,
        L2CanonicalTransaction transaction,
        bytes[] factoryDeps
    );

    /// @notice Emitted when the withdrawal is finalized on L1 and funds are released.
    /// @param to The address to which the funds were sent
    /// @param amount The amount of funds that were sent
    event EthWithdrawalFinalized(address indexed to, uint256 amount);
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "../../common/libraries/UncheckedMath.sol";

/// @author Matter Labs
library Merkle {
    using UncheckedMath for uint256;

    /// @dev Calculate Merkle root by the provided Merkle proof.
    /// NOTE: When using this function, check that the _path length is equal to the tree height to prevent shorter/longer paths attack
    /// @param _path Merkle path from the leaf to the root
    /// @param _index Leaf index in the tree
    /// @param _itemHash Hash of leaf content
    /// @return The Merkle root
    function calculateRoot(
        bytes32[] calldata _path,
        uint256 _index,
        bytes32 _itemHash
    ) internal pure returns (bytes32) {
        uint256 pathLength = _path.length;
        require(pathLength > 0, "xc");
        require(pathLength < 256, "bt");
        require(_index < (1 << pathLength), "pz");

        bytes32 currentHash = _itemHash;
        for (uint256 i; i < pathLength; i = i.uncheckedInc()) {
            currentHash = (_index % 2 == 0)
                ? _efficientHash(currentHash, _path[i])
                : _efficientHash(_path[i], currentHash);
            _index /= 2;
        }

        return currentHash;
    }

    /// @dev Keccak hash of the concatenation of two 32-byte words
    function _efficientHash(bytes32 _lhs, bytes32 _rhs) private pure returns (bytes32 result) {
        assembly {
            mstore(0x00, _lhs)
            mstore(0x20, _rhs)
            result := keccak256(0x00, 0x40)
        }
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



library PairingsBn254 {
    uint256 constant q_mod = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
    uint256 constant r_mod = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant bn254_b_coeff = 3;

    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    struct Fr {
        uint256 value;
    }

    function new_fr(uint256 fr) internal pure returns (Fr memory) {
        require(fr < r_mod);
        return Fr({value: fr});
    }

    function copy(Fr memory self) internal pure returns (Fr memory n) {
        n.value = self.value;
    }

    function assign(Fr memory self, Fr memory other) internal pure {
        self.value = other.value;
    }

    function inverse(Fr memory fr) internal view returns (Fr memory) {
        require(fr.value != 0);
        return pow(fr, r_mod - 2);
    }

    function add_assign(Fr memory self, Fr memory other) internal pure {
        self.value = addmod(self.value, other.value, r_mod);
    }

    function sub_assign(Fr memory self, Fr memory other) internal pure {
        self.value = addmod(self.value, r_mod - other.value, r_mod);
    }

    function mul_assign(Fr memory self, Fr memory other) internal pure {
        self.value = mulmod(self.value, other.value, r_mod);
    }

    function pow(Fr memory self, uint256 power) internal view returns (Fr memory) {
        uint256[6] memory input = [32, 32, 32, self.value, power, r_mod];
        uint256[1] memory result;
        bool success;
        assembly {
            success := staticcall(gas(), 0x05, input, 0xc0, result, 0x20)
        }
        require(success);
        return Fr({value: result[0]});
    }

    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    function new_g1(uint256 x, uint256 y) internal pure returns (G1Point memory) {
        return G1Point(x, y);
    }

    // function new_g1_checked(uint256 x, uint256 y) internal pure returns (G1Point memory) {
    function new_g1_checked(uint256 x, uint256 y) internal pure returns (G1Point memory) {
        if (x == 0 && y == 0) {
            // point of infinity is (0,0)
            return G1Point(x, y);
        }

        // check encoding
        require(x < q_mod, "x axis isn't valid");
        require(y < q_mod, "y axis isn't valid");
        // check on curve
        uint256 lhs = mulmod(y, y, q_mod); // y^2

        uint256 rhs = mulmod(x, x, q_mod); // x^2
        rhs = mulmod(rhs, x, q_mod); // x^3
        rhs = addmod(rhs, bn254_b_coeff, q_mod); // x^3 + b
        require(lhs == rhs, "is not on curve");

        return G1Point(x, y);
    }

    function new_g2(uint256[2] memory x, uint256[2] memory y) internal pure returns (G2Point memory) {
        return G2Point(x, y);
    }

    function copy_g1(G1Point memory self) internal pure returns (G1Point memory result) {
        result.X = self.X;
        result.Y = self.Y;
    }

    function P2() internal pure returns (G2Point memory) {
        // for some reason ethereum expects to have c1*v + c0 form

        return
            G2Point(
                [
                    0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
                    0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed
                ],
                [
                    0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
                    0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa
                ]
            );
    }

    function negate(G1Point memory self) internal pure {
        // The prime q in the base field F_q for G1
        if (self.Y == 0) {
            require(self.X == 0);
            return;
        }

        self.Y = q_mod - self.Y;
    }

    function point_add(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        point_add_into_dest(p1, p2, r);
        return r;
    }

    function point_add_assign(G1Point memory p1, G1Point memory p2) internal view {
        point_add_into_dest(p1, p2, p1);
    }

    function point_add_into_dest(
        G1Point memory p1,
        G1Point memory p2,
        G1Point memory dest
    ) internal view {
        if (p2.X == 0 && p2.Y == 0) {
            // we add zero, nothing happens
            dest.X = p1.X;
            dest.Y = p1.Y;
            return;
        } else if (p1.X == 0 && p1.Y == 0) {
            // we add into zero, and we add non-zero point
            dest.X = p2.X;
            dest.Y = p2.Y;
            return;
        } else {
            uint256[4] memory input;

            input[0] = p1.X;
            input[1] = p1.Y;
            input[2] = p2.X;
            input[3] = p2.Y;

            bool success;
            assembly {
                success := staticcall(gas(), 6, input, 0x80, dest, 0x40)
            }
            require(success);
        }
    }

    function point_sub_assign(G1Point memory p1, G1Point memory p2) internal view {
        point_sub_into_dest(p1, p2, p1);
    }

    function point_sub_into_dest(
        G1Point memory p1,
        G1Point memory p2,
        G1Point memory dest
    ) internal view {
        if (p2.X == 0 && p2.Y == 0) {
            // we subtracted zero, nothing happens
            dest.X = p1.X;
            dest.Y = p1.Y;
            return;
        } else if (p1.X == 0 && p1.Y == 0) {
            // we subtract from zero, and we subtract non-zero point
            dest.X = p2.X;
            dest.Y = q_mod - p2.Y;
            return;
        } else {
            uint256[4] memory input;

            input[0] = p1.X;
            input[1] = p1.Y;
            input[2] = p2.X;
            input[3] = q_mod - p2.Y;

            bool success = false;
            assembly {
                success := staticcall(gas(), 6, input, 0x80, dest, 0x40)
            }
            require(success);
        }
    }

    function point_mul(G1Point memory p, Fr memory s) internal view returns (G1Point memory r) {
        // https://eips.ethereum.org/EIPS/eip-197
        // Elliptic curve points are encoded as a Jacobian pair (X, Y) where the point at infinity is encoded as (0, 0)
        // TODO
        if (p.X == 0 && p.Y == 1) {
            p.Y = 0;
        }
        point_mul_into_dest(p, s, r);
        return r;
    }

    function point_mul_assign(G1Point memory p, Fr memory s) internal view {
        point_mul_into_dest(p, s, p);
    }

    function point_mul_into_dest(
        G1Point memory p,
        Fr memory s,
        G1Point memory dest
    ) internal view {
        uint256[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s.value;
        bool success;
        assembly {
            success := staticcall(gas(), 7, input, 0x60, dest, 0x40)
        }
        require(success);
    }

    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint256 elements = p1.length;
        uint256 inputSize = elements * 6;
        uint256[] memory input = new uint256[](inputSize);
        for (uint256 i = 0; i < elements; ) {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
            unchecked {
                ++i;
            }
        }
        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(gas(), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
        }
        require(success);
        return out[0] != 0;
    }

    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(
        G1Point memory a1,
        G2Point memory a2,
        G1Point memory b1,
        G2Point memory b2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



/// @notice The structure that contains meta information of the L2 transaction that was requested from L1
/// @dev The weird size of fields was selected specifically to minimize the structure storage size
/// @param canonicalTxHash Hashed L2 transaction data that is needed to process it
/// @param expirationTimestamp Expiration timestamp for this request (must be satisfied before)
/// @param layer2Tip Additional payment to the validator as an incentive to perform the operation
struct PriorityOperation {
    bytes32 canonicalTxHash;
    uint64 expirationTimestamp;
    uint192 layer2Tip;
}

/// @author Matter Labs
/// @dev The library provides the API to interact with the priority queue container
/// @dev Order of processing operations from queue - FIFO (Fist in - first out)
library PriorityQueue {
    using PriorityQueue for Queue;

    /// @notice Container that stores priority operations
    /// @param data The inner mapping that saves priority operation by its index
    /// @param head The pointer to the first unprocessed priority operation, equal to the tail if the queue is empty
    /// @param tail The pointer to the free slot
    struct Queue {
        mapping(uint256 => PriorityOperation) data;
        uint256 tail;
        uint256 head;
    }

    /// @notice Returns zero if and only if no operations were processed from the queue
    /// @return Index of the oldest priority operation that wasn't processed yet
    function getFirstUnprocessedPriorityTx(Queue storage _queue) internal view returns (uint256) {
        return _queue.head;
    }

    /// @return The total number of priority operations that were added to the priority queue, including all processed ones
    function getTotalPriorityTxs(Queue storage _queue) internal view returns (uint256) {
        return _queue.tail;
    }

    /// @return The total number of unprocessed priority operations in a priority queue
    function getSize(Queue storage _queue) internal view returns (uint256) {
        return uint256(_queue.tail - _queue.head);
    }

    /// @return Whether the priority queue contains no operations
    function isEmpty(Queue storage _queue) internal view returns (bool) {
        return _queue.tail == _queue.head;
    }

    /// @notice Add the priority operation to the end of the priority queue
    function pushBack(Queue storage _queue, PriorityOperation memory _operation) internal {
        // Save value into the stack to avoid double reading from the storage
        uint256 tail = _queue.tail;

        _queue.data[tail] = _operation;
        _queue.tail = tail + 1;
    }

    /// @return The first unprocessed priority operation from the queue
    function front(Queue storage _queue) internal view returns (PriorityOperation memory) {
        require(!_queue.isEmpty(), "D"); // priority queue is empty

        return _queue.data[_queue.head];
    }

    /// @notice Remove the first unprocessed priority operation from the queue
    /// @return priorityOperation that was popped from the priority queue
    function popFront(Queue storage _queue) internal returns (PriorityOperation memory priorityOperation) {
        require(!_queue.isEmpty(), "s"); // priority queue is empty

        // Save value into the stack to avoid double reading from the storage
        uint256 head = _queue.head;

        priorityOperation = _queue.data[head];
        delete _queue.data[head];
        _queue.head = head + 1;
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./PairingsBn254.sol";

library TranscriptLib {
    // flip                    0xe000000000000000000000000000000000000000000000000000000000000000;
    uint256 constant FR_MASK = 0x1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    uint32 constant DST_0 = 0;
    uint32 constant DST_1 = 1;
    uint32 constant DST_CHALLENGE = 2;

    struct Transcript {
        bytes32 state_0;
        bytes32 state_1;
        uint32 challenge_counter;
    }

    function new_transcript() internal pure returns (Transcript memory t) {
        t.state_0 = bytes32(0);
        t.state_1 = bytes32(0);
        t.challenge_counter = 0;
    }

    function update_with_u256(Transcript memory self, uint256 value) internal pure {
        bytes32 old_state_0 = self.state_0;
        self.state_0 = keccak256(abi.encodePacked(DST_0, old_state_0, self.state_1, value));
        self.state_1 = keccak256(abi.encodePacked(DST_1, old_state_0, self.state_1, value));
    }

    function update_with_fr(Transcript memory self, PairingsBn254.Fr memory value) internal pure {
        update_with_u256(self, value.value);
    }

    function update_with_g1(Transcript memory self, PairingsBn254.G1Point memory p) internal pure {
        update_with_u256(self, p.X);
        update_with_u256(self, p.Y);
    }

    function get_challenge(Transcript memory self) internal pure returns (PairingsBn254.Fr memory challenge) {
        bytes32 query = keccak256(abi.encodePacked(DST_CHALLENGE, self.state_0, self.state_1, self.challenge_counter));
        self.challenge_counter += 1;
        challenge = PairingsBn254.Fr({value: uint256(query) & FR_MASK});
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./libraries/PairingsBn254.sol";
import "./libraries/TranscriptLib.sol";
import "../common/libraries/UncheckedMath.sol";

uint256 constant STATE_WIDTH = 4;
uint256 constant NUM_G2_ELS = 2;

struct VerificationKey {
    uint256 domain_size;
    uint256 num_inputs;
    PairingsBn254.Fr omega;
    PairingsBn254.G1Point[2] gate_selectors_commitments;
    PairingsBn254.G1Point[8] gate_setup_commitments;
    PairingsBn254.G1Point[STATE_WIDTH] permutation_commitments;
    PairingsBn254.G1Point lookup_selector_commitment;
    PairingsBn254.G1Point[4] lookup_tables_commitments;
    PairingsBn254.G1Point lookup_table_type_commitment;
    PairingsBn254.Fr[STATE_WIDTH - 1] non_residues;
    PairingsBn254.G2Point[NUM_G2_ELS] g2_elements;
}

contract Plonk4VerifierWithAccessToDNext {
    using PairingsBn254 for PairingsBn254.G1Point;
    using PairingsBn254 for PairingsBn254.G2Point;
    using PairingsBn254 for PairingsBn254.Fr;

    using TranscriptLib for TranscriptLib.Transcript;

    using UncheckedMath for uint256;

    struct Proof {
        uint256[] input_values;
        // commitments
        PairingsBn254.G1Point[STATE_WIDTH] state_polys_commitments;
        PairingsBn254.G1Point copy_permutation_grand_product_commitment;
        PairingsBn254.G1Point[STATE_WIDTH] quotient_poly_parts_commitments;
        // openings
        PairingsBn254.Fr[STATE_WIDTH] state_polys_openings_at_z;
        PairingsBn254.Fr[1] state_polys_openings_at_z_omega; // TODO: not use array while there is only D_next
        PairingsBn254.Fr[1] gate_selectors_openings_at_z;
        PairingsBn254.Fr[STATE_WIDTH - 1] copy_permutation_polys_openings_at_z;
        PairingsBn254.Fr copy_permutation_grand_product_opening_at_z_omega;
        PairingsBn254.Fr quotient_poly_opening_at_z;
        PairingsBn254.Fr linearization_poly_opening_at_z;
        // lookup commitments
        PairingsBn254.G1Point lookup_s_poly_commitment;
        PairingsBn254.G1Point lookup_grand_product_commitment;
        // lookup openings
        PairingsBn254.Fr lookup_s_poly_opening_at_z_omega;
        PairingsBn254.Fr lookup_grand_product_opening_at_z_omega;
        PairingsBn254.Fr lookup_t_poly_opening_at_z;
        PairingsBn254.Fr lookup_t_poly_opening_at_z_omega;
        PairingsBn254.Fr lookup_selector_poly_opening_at_z;
        PairingsBn254.Fr lookup_table_type_poly_opening_at_z;
        PairingsBn254.G1Point opening_proof_at_z;
        PairingsBn254.G1Point opening_proof_at_z_omega;
    }

    struct PartialVerifierState {
        PairingsBn254.Fr zero;
        PairingsBn254.Fr alpha;
        PairingsBn254.Fr beta;
        PairingsBn254.Fr gamma;
        PairingsBn254.Fr[9] alpha_values;
        PairingsBn254.Fr eta;
        PairingsBn254.Fr beta_lookup;
        PairingsBn254.Fr gamma_lookup;
        PairingsBn254.Fr beta_plus_one;
        PairingsBn254.Fr beta_gamma;
        PairingsBn254.Fr v;
        PairingsBn254.Fr u;
        PairingsBn254.Fr z;
        PairingsBn254.Fr z_omega;
        PairingsBn254.Fr z_minus_last_omega;
        PairingsBn254.Fr l_0_at_z;
        PairingsBn254.Fr l_n_minus_one_at_z;
        PairingsBn254.Fr t;
        PairingsBn254.G1Point tp;
    }

    function evaluate_l0_at_point(uint256 domain_size, PairingsBn254.Fr memory at)
        internal
        view
        returns (PairingsBn254.Fr memory num)
    {
        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);

        PairingsBn254.Fr memory size_fe = PairingsBn254.new_fr(domain_size);
        PairingsBn254.Fr memory den = at.copy();
        den.sub_assign(one);
        den.mul_assign(size_fe);

        den = den.inverse();

        num = at.pow(domain_size);
        num.sub_assign(one);
        num.mul_assign(den);
    }

    function evaluate_lagrange_poly_out_of_domain(
        uint256 poly_num,
        uint256 domain_size,
        PairingsBn254.Fr memory omega,
        PairingsBn254.Fr memory at
    ) internal view returns (PairingsBn254.Fr memory res) {
        // (omega^i / N) / (X - omega^i) * (X^N - 1)
        require(poly_num < domain_size);
        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory omega_power = omega.pow(poly_num);
        res = at.pow(domain_size);
        res.sub_assign(one);
        require(res.value != 0); // Vanishing polynomial can not be zero at point `at`
        res.mul_assign(omega_power);

        PairingsBn254.Fr memory den = PairingsBn254.copy(at);
        den.sub_assign(omega_power);
        den.mul_assign(PairingsBn254.new_fr(domain_size));

        den = den.inverse();

        res.mul_assign(den);
    }

    function evaluate_vanishing(uint256 domain_size, PairingsBn254.Fr memory at)
        internal
        view
        returns (PairingsBn254.Fr memory res)
    {
        res = at.pow(domain_size);
        res.sub_assign(PairingsBn254.new_fr(1));
    }

    function initialize_transcript(Proof memory proof, VerificationKey memory vk)
        internal
        pure
        returns (PartialVerifierState memory state)
    {
        TranscriptLib.Transcript memory transcript = TranscriptLib.new_transcript();

        for (uint256 i = 0; i < vk.num_inputs; i = i.uncheckedInc()) {
            transcript.update_with_u256(proof.input_values[i]);
        }

        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            transcript.update_with_g1(proof.state_polys_commitments[i]);
        }

        state.eta = transcript.get_challenge();
        transcript.update_with_g1(proof.lookup_s_poly_commitment);

        state.beta = transcript.get_challenge();
        state.gamma = transcript.get_challenge();

        transcript.update_with_g1(proof.copy_permutation_grand_product_commitment);
        state.beta_lookup = transcript.get_challenge();
        state.gamma_lookup = transcript.get_challenge();
        transcript.update_with_g1(proof.lookup_grand_product_commitment);
        state.alpha = transcript.get_challenge();

        for (uint256 i = 0; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
            transcript.update_with_g1(proof.quotient_poly_parts_commitments[i]);
        }
        state.z = transcript.get_challenge();

        transcript.update_with_fr(proof.quotient_poly_opening_at_z);

        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.state_polys_openings_at_z[i]);
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z_omega.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.state_polys_openings_at_z_omega[i]);
        }
        for (uint256 i = 0; i < proof.gate_selectors_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.gate_selectors_openings_at_z[i]);
        }
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            transcript.update_with_fr(proof.copy_permutation_polys_openings_at_z[i]);
        }

        state.z_omega = state.z.copy();
        state.z_omega.mul_assign(vk.omega);

        transcript.update_with_fr(proof.copy_permutation_grand_product_opening_at_z_omega);

        transcript.update_with_fr(proof.lookup_t_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_selector_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_table_type_poly_opening_at_z);
        transcript.update_with_fr(proof.lookup_s_poly_opening_at_z_omega);
        transcript.update_with_fr(proof.lookup_grand_product_opening_at_z_omega);
        transcript.update_with_fr(proof.lookup_t_poly_opening_at_z_omega);
        transcript.update_with_fr(proof.linearization_poly_opening_at_z);

        state.v = transcript.get_challenge();

        transcript.update_with_g1(proof.opening_proof_at_z);
        transcript.update_with_g1(proof.opening_proof_at_z_omega);

        state.u = transcript.get_challenge();
    }

    // compute some powers of challenge alpha([alpha^1, .. alpha^8])
    function compute_powers_of_alpha(PartialVerifierState memory state) public pure {
        require(state.alpha.value != 0);
        state.alpha_values[0] = PairingsBn254.new_fr(1);
        state.alpha_values[1] = state.alpha.copy();
        PairingsBn254.Fr memory current_alpha = state.alpha.copy();
        for (uint256 i = 2; i < state.alpha_values.length; i = i.uncheckedInc()) {
            current_alpha.mul_assign(state.alpha);
            state.alpha_values[i] = current_alpha.copy();
        }
    }

    function verify(Proof memory proof, VerificationKey memory vk) internal view returns (bool) {
        // we initialize all challenges beforehand, we can draw each challenge in its own place
        PartialVerifierState memory state = initialize_transcript(proof, vk);
        if (verify_quotient_evaluation(vk, proof, state) == false) {
            return false;
        }
        require(proof.state_polys_openings_at_z_omega.length == 1); // TODO

        PairingsBn254.G1Point memory quotient_result = proof.quotient_poly_parts_commitments[0].copy_g1();
        {
            // block scope
            PairingsBn254.Fr memory z_in_domain_size = state.z.pow(vk.domain_size);
            PairingsBn254.Fr memory current_z = z_in_domain_size.copy();
            PairingsBn254.G1Point memory tp;
            // start from i =1
            for (uint256 i = 1; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
                tp = proof.quotient_poly_parts_commitments[i].copy_g1();
                tp.point_mul_assign(current_z);
                quotient_result.point_add_assign(tp);

                current_z.mul_assign(z_in_domain_size);
            }
        }

        Queries memory queries = prepare_queries(vk, proof, state);
        queries.commitments_at_z[0] = quotient_result;
        queries.values_at_z[0] = proof.quotient_poly_opening_at_z;
        queries.commitments_at_z[1] = aggregated_linearization_commitment(vk, proof, state);
        queries.values_at_z[1] = proof.linearization_poly_opening_at_z;

        require(queries.commitments_at_z.length == queries.values_at_z.length);

        PairingsBn254.G1Point memory aggregated_commitment_at_z = queries.commitments_at_z[0];

        PairingsBn254.Fr memory aggregated_opening_at_z = queries.values_at_z[0];
        PairingsBn254.Fr memory aggregation_challenge = PairingsBn254.new_fr(1);
        PairingsBn254.G1Point memory scaled;
        for (uint256 i = 1; i < queries.commitments_at_z.length; i = i.uncheckedInc()) {
            aggregation_challenge.mul_assign(state.v);
            scaled = queries.commitments_at_z[i].point_mul(aggregation_challenge);
            aggregated_commitment_at_z.point_add_assign(scaled);

            state.t = queries.values_at_z[i];
            state.t.mul_assign(aggregation_challenge);
            aggregated_opening_at_z.add_assign(state.t);
        }

        aggregation_challenge.mul_assign(state.v);

        PairingsBn254.G1Point memory aggregated_commitment_at_z_omega = queries.commitments_at_z_omega[0].point_mul(
            aggregation_challenge
        );
        PairingsBn254.Fr memory aggregated_opening_at_z_omega = queries.values_at_z_omega[0];
        aggregated_opening_at_z_omega.mul_assign(aggregation_challenge);
        for (uint256 i = 1; i < queries.commitments_at_z_omega.length; i = i.uncheckedInc()) {
            aggregation_challenge.mul_assign(state.v);

            scaled = queries.commitments_at_z_omega[i].point_mul(aggregation_challenge);
            aggregated_commitment_at_z_omega.point_add_assign(scaled);

            state.t = queries.values_at_z_omega[i];
            state.t.mul_assign(aggregation_challenge);
            aggregated_opening_at_z_omega.add_assign(state.t);
        }

        return
            final_pairing(
                vk.g2_elements,
                proof,
                state,
                aggregated_commitment_at_z,
                aggregated_commitment_at_z_omega,
                aggregated_opening_at_z,
                aggregated_opening_at_z_omega
            );
    }

    function verify_quotient_evaluation(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (bool) {
        uint256[] memory lagrange_poly_numbers = new uint256[](vk.num_inputs);
        for (uint256 i = 0; i < lagrange_poly_numbers.length; i = i.uncheckedInc()) {
            lagrange_poly_numbers[i] = i;
        }
        // require(vk.num_inputs > 0); // TODO

        PairingsBn254.Fr memory inputs_term = PairingsBn254.new_fr(0);
        for (uint256 i = 0; i < vk.num_inputs; i = i.uncheckedInc()) {
            // TODO we may use batched lagrange compputation
            state.t = evaluate_lagrange_poly_out_of_domain(i, vk.domain_size, vk.omega, state.z);
            state.t.mul_assign(PairingsBn254.new_fr(proof.input_values[i]));
            inputs_term.add_assign(state.t);
        }
        inputs_term.mul_assign(proof.gate_selectors_openings_at_z[0]);
        PairingsBn254.Fr memory result = proof.linearization_poly_opening_at_z.copy();
        result.add_assign(inputs_term);

        // compute powers of alpha
        compute_powers_of_alpha(state);
        PairingsBn254.Fr memory factor = state.alpha_values[4].copy();
        factor.mul_assign(proof.copy_permutation_grand_product_opening_at_z_omega);

        // - alpha_0 * (a + perm(z) * beta + gamma)*()*(d + gamma) * z(z*omega)
        require(proof.copy_permutation_polys_openings_at_z.length == STATE_WIDTH - 1);
        PairingsBn254.Fr memory t; // TMP;
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            t = proof.copy_permutation_polys_openings_at_z[i].copy();
            t.mul_assign(state.beta);
            t.add_assign(proof.state_polys_openings_at_z[i]);
            t.add_assign(state.gamma);

            factor.mul_assign(t);
        }

        t = proof.state_polys_openings_at_z[3].copy();
        t.add_assign(state.gamma);
        factor.mul_assign(t);
        result.sub_assign(factor);

        // - L_0(z) * alpha_1
        PairingsBn254.Fr memory l_0_at_z = evaluate_l0_at_point(vk.domain_size, state.z);
        l_0_at_z.mul_assign(state.alpha_values[4 + 1]);
        result.sub_assign(l_0_at_z);

        PairingsBn254.Fr memory lookup_quotient_contrib = lookup_quotient_contribution(vk, proof, state);
        result.add_assign(lookup_quotient_contrib);

        PairingsBn254.Fr memory lhs = proof.quotient_poly_opening_at_z.copy();
        lhs.mul_assign(evaluate_vanishing(vk.domain_size, state.z));
        return lhs.value == result.value;
    }

    function lookup_quotient_contribution(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (PairingsBn254.Fr memory result) {
        PairingsBn254.Fr memory t;

        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        state.beta_plus_one = state.beta_lookup.copy();
        state.beta_plus_one.add_assign(one);
        state.beta_gamma = state.beta_plus_one.copy();
        state.beta_gamma.mul_assign(state.gamma_lookup);

        // (s'*beta + gamma)*(zw')*alpha
        t = proof.lookup_s_poly_opening_at_z_omega.copy();
        t.mul_assign(state.beta_lookup);
        t.add_assign(state.beta_gamma);
        t.mul_assign(proof.lookup_grand_product_opening_at_z_omega);
        t.mul_assign(state.alpha_values[6]);

        // (z - omega^{n-1}) for this part
        PairingsBn254.Fr memory last_omega = vk.omega.pow(vk.domain_size - 1);
        state.z_minus_last_omega = state.z.copy();
        state.z_minus_last_omega.sub_assign(last_omega);
        t.mul_assign(state.z_minus_last_omega);
        result.add_assign(t);

        // - alpha_1 * L_{0}(z)
        state.l_0_at_z = evaluate_lagrange_poly_out_of_domain(0, vk.domain_size, vk.omega, state.z);
        t = state.l_0_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 1]);
        result.sub_assign(t);

        // - alpha_2 * beta_gamma_powered L_{n-1}(z)
        PairingsBn254.Fr memory beta_gamma_powered = state.beta_gamma.pow(vk.domain_size - 1);
        state.l_n_minus_one_at_z = evaluate_lagrange_poly_out_of_domain(
            vk.domain_size - 1,
            vk.domain_size,
            vk.omega,
            state.z
        );
        t = state.l_n_minus_one_at_z.copy();
        t.mul_assign(beta_gamma_powered);
        t.mul_assign(state.alpha_values[6 + 2]);

        result.sub_assign(t);
    }

    function aggregated_linearization_commitment(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) internal view returns (PairingsBn254.G1Point memory result) {
        // qMain*(Q_a * A + Q_b * B + Q_c * C + Q_d * D + Q_m * A*B + Q_const + Q_dNext * D_next)
        result = PairingsBn254.new_g1(0, 0);
        // Q_a * A
        PairingsBn254.G1Point memory scaled = vk.gate_setup_commitments[0].point_mul(
            proof.state_polys_openings_at_z[0]
        );
        result.point_add_assign(scaled);
        // Q_b * B
        scaled = vk.gate_setup_commitments[1].point_mul(proof.state_polys_openings_at_z[1]);
        result.point_add_assign(scaled);
        // Q_c * C
        scaled = vk.gate_setup_commitments[2].point_mul(proof.state_polys_openings_at_z[2]);
        result.point_add_assign(scaled);
        // Q_d * D
        scaled = vk.gate_setup_commitments[3].point_mul(proof.state_polys_openings_at_z[3]);
        result.point_add_assign(scaled);
        // Q_m* A*B or Q_ab*A*B
        PairingsBn254.Fr memory t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(proof.state_polys_openings_at_z[1]);
        scaled = vk.gate_setup_commitments[4].point_mul(t);
        result.point_add_assign(scaled);
        // Q_AC* A*C
        t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(proof.state_polys_openings_at_z[2]);
        scaled = vk.gate_setup_commitments[5].point_mul(t);
        result.point_add_assign(scaled);
        // Q_const
        result.point_add_assign(vk.gate_setup_commitments[6]);
        // Q_dNext * D_next
        scaled = vk.gate_setup_commitments[7].point_mul(proof.state_polys_openings_at_z_omega[0]);
        result.point_add_assign(scaled);
        result.point_mul_assign(proof.gate_selectors_openings_at_z[0]);

        PairingsBn254.G1Point
            memory rescue_custom_gate_linearization_contrib = rescue_custom_gate_linearization_contribution(
                vk,
                proof,
                state
            );
        result.point_add_assign(rescue_custom_gate_linearization_contrib);
        require(vk.non_residues.length == STATE_WIDTH - 1);

        PairingsBn254.Fr memory one = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory factor = state.alpha_values[4].copy();
        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; ) {
            t = state.z.copy();
            if (i == 0) {
                t.mul_assign(one);
            } else {
                t.mul_assign(vk.non_residues[i - 1]); // TODO add one into non-residues during codegen?
            }
            t.mul_assign(state.beta);
            t.add_assign(state.gamma);
            t.add_assign(proof.state_polys_openings_at_z[i]);

            factor.mul_assign(t);
            unchecked {
                ++i;
            }
        }

        scaled = proof.copy_permutation_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        // - (a(z) + beta*perm_a + gamma)*()*()*z(z*omega) * beta * perm_d(X)
        factor = state.alpha_values[4].copy();
        factor.mul_assign(state.beta);
        factor.mul_assign(proof.copy_permutation_grand_product_opening_at_z_omega);
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            t = proof.copy_permutation_polys_openings_at_z[i].copy();
            t.mul_assign(state.beta);
            t.add_assign(state.gamma);
            t.add_assign(proof.state_polys_openings_at_z[i]);

            factor.mul_assign(t);
        }
        scaled = vk.permutation_commitments[3].point_mul(factor);
        result.point_sub_assign(scaled);

        // + L_0(z) * Z(x)
        // TODO
        state.l_0_at_z = evaluate_lagrange_poly_out_of_domain(0, vk.domain_size, vk.omega, state.z);
        require(state.l_0_at_z.value != 0);
        factor = state.l_0_at_z.copy();
        factor.mul_assign(state.alpha_values[4 + 1]);
        scaled = proof.copy_permutation_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        PairingsBn254.G1Point memory lookup_linearization_contrib = lookup_linearization_contribution(proof, state);
        result.point_add_assign(lookup_linearization_contrib);
    }

    function rescue_custom_gate_linearization_contribution(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) public view returns (PairingsBn254.G1Point memory result) {
        PairingsBn254.Fr memory t;
        PairingsBn254.Fr memory intermediate_result;

        // a^2 - b = 0
        t = proof.state_polys_openings_at_z[0].copy();
        t.mul_assign(t);
        t.sub_assign(proof.state_polys_openings_at_z[1]);
        // t.mul_assign(challenge1);
        t.mul_assign(state.alpha_values[1]);
        intermediate_result.add_assign(t);

        // b^2 - c = 0
        t = proof.state_polys_openings_at_z[1].copy();
        t.mul_assign(t);
        t.sub_assign(proof.state_polys_openings_at_z[2]);
        t.mul_assign(state.alpha_values[1 + 1]);
        intermediate_result.add_assign(t);

        // c*a - d = 0;
        t = proof.state_polys_openings_at_z[2].copy();
        t.mul_assign(proof.state_polys_openings_at_z[0]);
        t.sub_assign(proof.state_polys_openings_at_z[3]);
        t.mul_assign(state.alpha_values[1 + 2]);
        intermediate_result.add_assign(t);

        result = vk.gate_selectors_commitments[1].point_mul(intermediate_result);
    }

    function lookup_linearization_contribution(Proof memory proof, PartialVerifierState memory state)
        internal
        view
        returns (PairingsBn254.G1Point memory result)
    {
        PairingsBn254.Fr memory zero = PairingsBn254.new_fr(0);

        PairingsBn254.Fr memory t;
        PairingsBn254.Fr memory factor;
        // s(x) from the Z(x*omega)*(\gamma*(1 + \beta) + s(x) + \beta * s(x*omega)))
        factor = proof.lookup_grand_product_opening_at_z_omega.copy();
        factor.mul_assign(state.alpha_values[6]);
        factor.mul_assign(state.z_minus_last_omega);

        PairingsBn254.G1Point memory scaled = proof.lookup_s_poly_commitment.point_mul(factor);
        result.point_add_assign(scaled);

        // Z(x) from - alpha_0 * Z(x) * (\beta + 1) * (\gamma + f(x)) * (\gamma(1 + \beta) + t(x) + \beta * t(x*omega))
        // + alpha_1 * Z(x) * L_{0}(z) + alpha_2 * Z(x) * L_{n-1}(z)

        // accumulate coefficient
        factor = proof.lookup_t_poly_opening_at_z_omega.copy();
        factor.mul_assign(state.beta_lookup);
        factor.add_assign(proof.lookup_t_poly_opening_at_z);
        factor.add_assign(state.beta_gamma);

        // (\gamma + f(x))
        PairingsBn254.Fr memory f_reconstructed;
        PairingsBn254.Fr memory current = PairingsBn254.new_fr(1);
        PairingsBn254.Fr memory tmp0;
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            tmp0 = proof.state_polys_openings_at_z[i].copy();
            tmp0.mul_assign(current);
            f_reconstructed.add_assign(tmp0);

            current.mul_assign(state.eta);
        }

        // add type of table
        t = proof.lookup_table_type_poly_opening_at_z.copy();
        t.mul_assign(current);
        f_reconstructed.add_assign(t);

        f_reconstructed.mul_assign(proof.lookup_selector_poly_opening_at_z);
        f_reconstructed.add_assign(state.gamma_lookup);

        // end of (\gamma + f(x)) part
        factor.mul_assign(f_reconstructed);
        factor.mul_assign(state.beta_plus_one);
        t = zero.copy();
        t.sub_assign(factor);
        factor = t;
        factor.mul_assign(state.alpha_values[6]);

        // Multiply by (z - omega^{n-1})
        factor.mul_assign(state.z_minus_last_omega);

        // L_{0}(z) in front of Z(x)
        t = state.l_0_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 1]);
        factor.add_assign(t);

        // L_{n-1}(z) in front of Z(x)
        t = state.l_n_minus_one_at_z.copy();
        t.mul_assign(state.alpha_values[6 + 2]);
        factor.add_assign(t);

        scaled = proof.lookup_grand_product_commitment.point_mul(factor);
        result.point_add_assign(scaled);
    }

    struct Queries {
        PairingsBn254.G1Point[13] commitments_at_z;
        PairingsBn254.Fr[13] values_at_z;
        PairingsBn254.G1Point[6] commitments_at_z_omega;
        PairingsBn254.Fr[6] values_at_z_omega;
    }

    function prepare_queries(
        VerificationKey memory vk,
        Proof memory proof,
        PartialVerifierState memory state
    ) public view returns (Queries memory queries) {
        // we set first two items in calee side so start idx from 2
        uint256 idx = 2;
        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            queries.commitments_at_z[idx] = proof.state_polys_commitments[i];
            queries.values_at_z[idx] = proof.state_polys_openings_at_z[i];
            idx = idx.uncheckedInc();
        }
        require(proof.gate_selectors_openings_at_z.length == 1);
        queries.commitments_at_z[idx] = vk.gate_selectors_commitments[0];
        queries.values_at_z[idx] = proof.gate_selectors_openings_at_z[0];
        idx = idx.uncheckedInc();
        for (uint256 i = 0; i < STATE_WIDTH - 1; i = i.uncheckedInc()) {
            queries.commitments_at_z[idx] = vk.permutation_commitments[i];
            queries.values_at_z[idx] = proof.copy_permutation_polys_openings_at_z[i];
            idx = idx.uncheckedInc();
        }

        queries.commitments_at_z_omega[0] = proof.copy_permutation_grand_product_commitment;
        queries.commitments_at_z_omega[1] = proof.state_polys_commitments[STATE_WIDTH - 1];

        queries.values_at_z_omega[0] = proof.copy_permutation_grand_product_opening_at_z_omega;
        queries.values_at_z_omega[1] = proof.state_polys_openings_at_z_omega[0];

        PairingsBn254.G1Point memory lookup_t_poly_commitment_aggregated = vk.lookup_tables_commitments[0];
        PairingsBn254.Fr memory current_eta = state.eta.copy();
        for (uint256 i = 1; i < vk.lookup_tables_commitments.length; i = i.uncheckedInc()) {
            state.tp = vk.lookup_tables_commitments[i].point_mul(current_eta);
            lookup_t_poly_commitment_aggregated.point_add_assign(state.tp);

            current_eta.mul_assign(state.eta);
        }
        queries.commitments_at_z[idx] = lookup_t_poly_commitment_aggregated;
        queries.values_at_z[idx] = proof.lookup_t_poly_opening_at_z;
        idx = idx.uncheckedInc();
        queries.commitments_at_z[idx] = vk.lookup_selector_commitment;
        queries.values_at_z[idx] = proof.lookup_selector_poly_opening_at_z;
        idx = idx.uncheckedInc();
        queries.commitments_at_z[idx] = vk.lookup_table_type_commitment;
        queries.values_at_z[idx] = proof.lookup_table_type_poly_opening_at_z;
        queries.commitments_at_z_omega[2] = proof.lookup_s_poly_commitment;
        queries.values_at_z_omega[2] = proof.lookup_s_poly_opening_at_z_omega;
        queries.commitments_at_z_omega[3] = proof.lookup_grand_product_commitment;
        queries.values_at_z_omega[3] = proof.lookup_grand_product_opening_at_z_omega;
        queries.commitments_at_z_omega[4] = lookup_t_poly_commitment_aggregated;
        queries.values_at_z_omega[4] = proof.lookup_t_poly_opening_at_z_omega;
    }

    function final_pairing(
        // VerificationKey memory vk,
        PairingsBn254.G2Point[NUM_G2_ELS] memory g2_elements,
        Proof memory proof,
        PartialVerifierState memory state,
        PairingsBn254.G1Point memory aggregated_commitment_at_z,
        PairingsBn254.G1Point memory aggregated_commitment_at_z_omega,
        PairingsBn254.Fr memory aggregated_opening_at_z,
        PairingsBn254.Fr memory aggregated_opening_at_z_omega
    ) internal view returns (bool) {
        // q(x) = f(x) - f(z) / (x - z)
        // q(x) * (x-z)  = f(x) - f(z)

        // f(x)
        PairingsBn254.G1Point memory pair_with_generator = aggregated_commitment_at_z.copy_g1();
        aggregated_commitment_at_z_omega.point_mul_assign(state.u);
        pair_with_generator.point_add_assign(aggregated_commitment_at_z_omega);

        // - f(z)*g
        PairingsBn254.Fr memory aggregated_value = aggregated_opening_at_z_omega.copy();
        aggregated_value.mul_assign(state.u);
        aggregated_value.add_assign(aggregated_opening_at_z);
        PairingsBn254.G1Point memory tp = PairingsBn254.P1().point_mul(aggregated_value);
        pair_with_generator.point_sub_assign(tp);

        // +z * q(x)
        tp = proof.opening_proof_at_z.point_mul(state.z);
        PairingsBn254.Fr memory t = state.z_omega.copy();
        t.mul_assign(state.u);
        PairingsBn254.G1Point memory t1 = proof.opening_proof_at_z_omega.point_mul(t);
        tp.point_add_assign(t1);
        pair_with_generator.point_add_assign(tp);

        // rhs
        PairingsBn254.G1Point memory pair_with_x = proof.opening_proof_at_z_omega.point_mul(state.u);
        pair_with_x.point_add_assign(proof.opening_proof_at_z);
        pair_with_x.negate();
        // Pairing precompile expects points to be in a `i*x[1] + x[0]` form instead of `x[0] + i*x[1]`
        // so we handle it in code generation step
        PairingsBn254.G2Point memory first_g2 = g2_elements[0];
        PairingsBn254.G2Point memory second_g2 = g2_elements[1];
        PairingsBn254.G2Point memory gen2 = PairingsBn254.P2();

        return PairingsBn254.pairingProd2(pair_with_generator, first_g2, pair_with_x, second_g2);
    }
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./Verifier.sol";
import "../common/interfaces/IAllowList.sol";
import "./libraries/PriorityQueue.sol";

/// @notice Indicates whether an upgrade is initiated and if yes what type
/// @param None Upgrade is NOT initiated
/// @param Transparent Fully transparent upgrade is initiated, upgrade data is publicly known
/// @param Shadow Shadow upgrade is initiated, upgrade data is hidden
enum UpgradeState {
    None,
    Transparent,
    Shadow
}

/// @dev Logically separated part of the storage structure, which is responsible for everything related to proxy upgrades and diamond cuts
/// @param proposedUpgradeHash The hash of the current upgrade proposal, zero if there is no active proposal
/// @param state Indicates whether an upgrade is initiated and if yes what type
/// @param securityCouncil Address which has the permission to approve instant upgrades (expected to be a Gnosis multisig)
/// @param approvedBySecurityCouncil Indicates whether the security council has approved the upgrade
/// @param proposedUpgradeTimestamp The timestamp when the upgrade was proposed, zero if there are no active proposals
/// @param currentProposalId The serial number of proposed upgrades, increments when proposing a new one
struct UpgradeStorage {
    bytes32 proposedUpgradeHash;
    UpgradeState state;
    address securityCouncil;
    bool approvedBySecurityCouncil;
    uint40 proposedUpgradeTimestamp;
    uint40 currentProposalId;
}

/// @dev The log passed from L2
/// @param l2ShardId The shard identifier, 0 - rollup, 1 - porter. All other values are not used but are reserved for the future
/// @param isService A boolean flag that is part of the log along with `key`, `value`, and `sender` address.
/// This field is required formally but does not have any special meaning.
/// @param txNumberInBlock The L2 transaction number in a block, in which the log was sent
/// @param sender The L2 address which sent the log
/// @param key The 32 bytes of information that was sent in the log
/// @param value The 32 bytes of information that was sent in the log
// Both `key` and `value` are arbitrary 32-bytes selected by the log sender
struct L2Log {
    uint8 l2ShardId;
    bool isService;
    uint16 txNumberInBlock;
    address sender;
    bytes32 key;
    bytes32 value;
}

/// @dev An arbitrary length message passed from L2
/// @notice Under the hood it is `L2Log` sent from the special system L2 contract
/// @param txNumberInBlock The L2 transaction number in a block, in which the message was sent
/// @param sender The address of the L2 account from which the message was passed
/// @param data An arbitrary length message
struct L2Message {
    uint16 txNumberInBlock;
    address sender;
    bytes data;
}

/// @notice Part of the configuration parameters of ZKP circuits
struct VerifierParams {
    bytes32 recursionNodeLevelVkHash;
    bytes32 recursionLeafLevelVkHash;
    bytes32 recursionCircuitsSetVksHash;
}

/// @dev storing all storage variables for zkSync facets
/// NOTE: It is used in a proxy, so it is possible to add new variables to the end
/// NOTE: but NOT to modify already existing variables or change their order
/// NOTE: DiamondCutStorage is unused, but it must remain a member of AppStorage to not have storage collision
/// NOTE: instead UpgradeStorage is used that is appended to the end of the AppStorage struct
struct AppStorage {
    /// @dev Storage of variables needed for deprecated diamond cut facet
    uint256[7] __DEPRECATED_diamondCutStorage;
    /// @notice Address which will exercise governance over the network i.e. change validator set, conduct upgrades
    address governor;
    /// @notice Address that the governor proposed as one that will replace it
    address pendingGovernor;
    /// @notice List of permitted validators
    mapping(address => bool) validators;
    /// @dev Verifier contract. Used to verify aggregated proof for blocks
    Verifier verifier;
    /// @notice Total number of executed blocks i.e. blocks[totalBlocksExecuted] points at the latest executed block (block 0 is genesis)
    uint256 totalBlocksExecuted;
    /// @notice Total number of proved blocks i.e. blocks[totalBlocksProved] points at the latest proved block
    uint256 totalBlocksVerified;
    /// @notice Total number of committed blocks i.e. blocks[totalBlocksCommitted] points at the latest committed block
    uint256 totalBlocksCommitted;
    /// @dev Stored hashed StoredBlock for block number
    mapping(uint256 => bytes32) storedBlockHashes;
    /// @dev Stored root hashes of L2 -> L1 logs
    mapping(uint256 => bytes32) l2LogsRootHashes;
    /// @dev Container that stores transactions requested from L1
    PriorityQueue.Queue priorityQueue;
    /// @dev The smart contract that manages the list with permission to call contract functions
    IAllowList allowList;
    /// @notice Part of the configuration parameters of ZKP circuits. Used as an input for the verifier smart contract
    VerifierParams verifierParams;
    /// @notice Bytecode hash of bootloader program.
    /// @dev Used as an input to zkp-circuit.
    bytes32 l2BootloaderBytecodeHash;
    /// @notice Bytecode hash of default account (bytecode for EOA).
    /// @dev Used as an input to zkp-circuit.
    bytes32 l2DefaultAccountBytecodeHash;
    /// @dev Indicates that the porter may be touched on L2 transactions.
    /// @dev Used as an input to zkp-circuit.
    bool zkPorterIsAvailable;
    /// @dev The maximum number of the L2 gas that a user can request for L1 -> L2 transactions
    /// @dev This is the maximum number of L2 gas that is available for the "body" of the transaction, i.e.
    /// without overhead for proving the block.
    uint256 priorityTxMaxGasLimit;
    /// @dev Storage of variables needed for upgrade facet
    UpgradeStorage upgrades;
    /// @dev A mapping L2 block number => message number => flag.
    /// @dev The L2 -> L1 log is sent for every withdrawal, so this mapping is serving as
    /// a flag to indicate that the message was already processed.
    /// @dev Used to indicate that eth withdrawal was already processed
    mapping(uint256 => mapping(uint256 => bool)) isEthWithdrawalFinalized;
    /// @dev The most recent withdrawal time and amount reset
    uint256 lastWithdrawalLimitReset;
    /// @dev The accumulated withdrawn amount during the withdrawal limit window
    uint256 withdrawnAmountInWindow;
    /// @dev A mapping user address => the total deposited amount by the user
    mapping(address => uint256) totalDepositedAmountPerUser;
}

pragma solidity ^0.8.0;

// SPDX-License-Identifier: MIT



import "./Plonk4VerifierWithAccessToDNext.sol";
import "../common/libraries/UncheckedMath.sol";

contract Verifier is Plonk4VerifierWithAccessToDNext {
    using UncheckedMath for uint256;

    function get_verification_key() public pure returns (VerificationKey memory vk) {
        vk.num_inputs = 1;
        vk.domain_size = 67108864;
        vk.omega = PairingsBn254.new_fr(0x1dba8b5bdd64ef6ce29a9039aca3c0e524395c43b9227b96c75090cc6cc7ec97);
        // coefficients
        vk.gate_setup_commitments[0] = PairingsBn254.new_g1(
            0x08fa9d6f0dd6ac1cbeb94ae20fe7a23df05cb1095df66fb561190e615a4037ef,
            0x196dcc8692fe322d21375920559944c12ba7b1ba8b732344cf4ba2e3aa0fc8b4
        );
        vk.gate_setup_commitments[1] = PairingsBn254.new_g1(
            0x0074aaf5d97bd57551311a8b3e4aa7840bc55896502020b2f43ad6a98d81a443,
            0x2d275a3ad153dc9d89ebb9c9b6a0afd2dde82470554e9738d905c328fbb4c8bc
        );
        vk.gate_setup_commitments[2] = PairingsBn254.new_g1(
            0x287f1975a9aeaef5d2bb0767b5ef538f76e82f7da01c0cb6db8c6f920818ec4f,
            0x2fff6f53594129f794a7731d963d27e72f385c5c6d8e08829e6f66a9d29a12ea
        );
        vk.gate_setup_commitments[3] = PairingsBn254.new_g1(
            0x038809fa3d4b7320d43e023454194f0a7878baa7e73a295d2d105260f1c34cbc,
            0x25418b1105cf45b2a3da6c349bab1d9caaf145eaf24d1e8fb92c11654c000781
        );
        vk.gate_setup_commitments[4] = PairingsBn254.new_g1(
            0x0561cafd527ac3f0bc550db77d87cd1c63938f7ec051e62ebf84a5bbe07f9840,
            0x28f87201b4cbe19f1517a1c29ca6d6cb074502ccfed4c31c8931c6992c3eea43
        );
        vk.gate_setup_commitments[5] = PairingsBn254.new_g1(
            0x27e0af572bac6e36d31c33808cb44c0ef8ceee5e2850e916fb01f3747db72491,
            0x1da20087ba61c59366b21e31e4ac6889d357cf11bf16b94d875f94f41525c427
        );
        vk.gate_setup_commitments[6] = PairingsBn254.new_g1(
            0x2c2bcafea8f93d07f96874f470985a8d272c09c8ed49373f36497ee80bd8da17,
            0x299276cf6dca1a7e3780f6276c5d067403f6e024e83e0cc1ab4c5f7252b7f653
        );
        vk.gate_setup_commitments[7] = PairingsBn254.new_g1(
            0x0ba9d4a53e050da25b8410045b634f1ca065ff74acd35bab1a72bf1f20047ef3,
            0x1f1eefc8b0507a08f852f554bd7abcbd506e52de390ca127477a678d212abfe5
        );
        // gate selectors
        vk.gate_selectors_commitments[0] = PairingsBn254.new_g1(
            0x1c6b68d9920620012d85a4850dad9bd6d03ae8bbc7a08b827199e85dba1ef2b1,
            0x0f6380560d1b585628ed259289cec19d3a7c70c60e66bbfebfcb70c8c312d91e
        );
        vk.gate_selectors_commitments[1] = PairingsBn254.new_g1(
            0x0dfead780e5067181aae631ff734a33fca302773472997daca58ba49dbd20dcc,
            0x00f13fa6e356f525d2fd1c533acf2858c0d2b9f0a9b3180f94e1543929c75073
        );
        // permutation
        vk.permutation_commitments[0] = PairingsBn254.new_g1(
            0x1df0747c787934650d99c5696f9273088ad07ec3e0825c9d39685a9b9978ebed,
            0x2ace2a277becbc69af4e89518eb50960a733d9d71354845ea43d2e65c8e0e4cb
        );
        vk.permutation_commitments[1] = PairingsBn254.new_g1(
            0x06598c8236a5f5045cd7444dc87f3e1f66f99bf01251e13be4dc0ab1f7f1af4b,
            0x14ca234fe9b3bb1e5517fc60d6b90f8ad44b0899a2d4f71a64c9640b3142ce8b
        );
        vk.permutation_commitments[2] = PairingsBn254.new_g1(
            0x1889e2c684caefde60471748f4259196ecf4209a735ccdf7b1816f05bafa50a,
            0x92d287a080bfe2fd40ad392ff290e462cd0e347b8fd9d05b90af234ce77a11b
        );
        vk.permutation_commitments[3] = PairingsBn254.new_g1(
            0x0dd98eeb5bc12c221da969398b67750a8774dbdd37a78da52367f9fc0e566d5c,
            0x06750ceb40c9fb87fc424df9599340938b7552b759914a90cb0e41d3915c945b
        );
        // lookup table commitments
        vk.lookup_selector_commitment = PairingsBn254.new_g1(
            0x2f491c662ae53ceb358f57a868dc00b89befa853bd9a449127ea2d46820995bd,
            0x231fe6538634ff8b6fa21ca248fb15e7f43d82eb0bfa705490d24ddb3e3cad77
        );
        vk.lookup_tables_commitments[0] = PairingsBn254.new_g1(
            0x0ebe0de4a2f39df3b903da484c1641ffdffb77ff87ce4f9508c548659eb22d3c,
            0x12a3209440242d5662729558f1017ed9dcc08fe49a99554dd45f5f15da5e4e0b
        );
        vk.lookup_tables_commitments[1] = PairingsBn254.new_g1(
            0x1b7d54f8065ca63bed0bfbb9280a1011b886d07e0c0a26a66ecc96af68c53bf9,
            0x2c51121fff5b8f58c302f03c74e0cb176ae5a1d1730dec4696eb9cce3fe284ca
        );
        vk.lookup_tables_commitments[2] = PairingsBn254.new_g1(
            0x0138733c5faa9db6d4b8df9748081e38405999e511fb22d40f77cf3aef293c44,
            0x269bee1c1ac28053238f7fe789f1ea2e481742d6d16ae78ed81e87c254af0765
        );
        vk.lookup_tables_commitments[3] = PairingsBn254.new_g1(
            0x1b1be7279d59445065a95f01f16686adfa798ec4f1e6845ffcec9b837e88372e,
            0x057c90cb96d8259238ed86b05f629efd55f472a721efeeb56926e979433e6c0e
        );
        vk.lookup_table_type_commitment = PairingsBn254.new_g1(
            0x12cd873a6f18a4a590a846d9ebf61565197edf457efd26bc408eb61b72f37b59,
            0x19890cbdac892682e7a5910ca6c238c082130e1c71f33d0c9c901153377770d1
        );
        // non residues
        vk.non_residues[0] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000005);
        vk.non_residues[1] = PairingsBn254.new_fr(0x0000000000000000000000000000000000000000000000000000000000000007);
        vk.non_residues[2] = PairingsBn254.new_fr(0x000000000000000000000000000000000000000000000000000000000000000a);

        // g2 elements
        vk.g2_elements[0] = PairingsBn254.new_g2(
            [
                0x198e9393920d483a7260bfb731fb5d25f1aa493335a9e71297e485b7aef312c2,
                0x1800deef121f1e76426a00665e5c4479674322d4f75edadd46debd5cd992f6ed
            ],
            [
                0x090689d0585ff075ec9e99ad690c3395bc4b313370b38ef355acdadcd122975b,
                0x12c85ea5db8c6deb4aab71808dcb408fe3d1e7690c43d37b4ce6cc0166fa7daa
            ]
        );
        vk.g2_elements[1] = PairingsBn254.new_g2(
            [
                0x260e01b251f6f1c7e7ff4e580791dee8ea51d87a358e038b4efe30fac09383c1,
                0x0118c4d5b837bcc2bc89b5b398b5974e9f5944073b32078b7e231fec938883b0
            ],
            [
                0x04fc6369f7110fe3d25156c1bb9a72859cf2a04641f99ba4ee413c80da6a5fe4,
                0x22febda3c0c0632a56475b4214e5615e11e6dd3f96e6cea2854a87d4dacc5e55
            ]
        );
    }

    function deserialize_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        internal
        pure
        returns (Proof memory proof)
    {
        // require(serialized_proof.length == 44); TODO
        proof.input_values = new uint256[](public_inputs.length);
        for (uint256 i = 0; i < public_inputs.length; i = i.uncheckedInc()) {
            proof.input_values[i] = public_inputs[i];
        }

        uint256 j;
        for (uint256 i = 0; i < STATE_WIDTH; i = i.uncheckedInc()) {
            proof.state_polys_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );

            j = j.uncheckedAdd(2);
        }
        proof.copy_permutation_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_s_poly_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);

        proof.lookup_grand_product_commitment = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        for (uint256 i = 0; i < proof.quotient_poly_parts_commitments.length; i = i.uncheckedInc()) {
            proof.quotient_poly_parts_commitments[i] = PairingsBn254.new_g1_checked(
                serialized_proof[j],
                serialized_proof[j.uncheckedInc()]
            );
            j = j.uncheckedAdd(2);
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }

        for (uint256 i = 0; i < proof.state_polys_openings_at_z_omega.length; i = i.uncheckedInc()) {
            proof.state_polys_openings_at_z_omega[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.gate_selectors_openings_at_z.length; i = i.uncheckedInc()) {
            proof.gate_selectors_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        for (uint256 i = 0; i < proof.copy_permutation_polys_openings_at_z.length; i = i.uncheckedInc()) {
            proof.copy_permutation_polys_openings_at_z[i] = PairingsBn254.new_fr(serialized_proof[j]);

            j = j.uncheckedInc();
        }
        proof.copy_permutation_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_s_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_grand_product_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);

        j = j.uncheckedInc();
        proof.lookup_t_poly_opening_at_z_omega = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_selector_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.lookup_table_type_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.quotient_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.linearization_poly_opening_at_z = PairingsBn254.new_fr(serialized_proof[j]);
        j = j.uncheckedInc();
        proof.opening_proof_at_z = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
        j = j.uncheckedAdd(2);
        proof.opening_proof_at_z_omega = PairingsBn254.new_g1_checked(
            serialized_proof[j],
            serialized_proof[j.uncheckedInc()]
        );
    }

    function verify_serialized_proof(uint256[] calldata public_inputs, uint256[] calldata serialized_proof)
        public
        view
        returns (bool)
    {
        VerificationKey memory vk = get_verification_key();
        require(vk.num_inputs == public_inputs.length);

        Proof memory proof = deserialize_proof(public_inputs, serialized_proof);

        return verify(proof, vk);
    }
}