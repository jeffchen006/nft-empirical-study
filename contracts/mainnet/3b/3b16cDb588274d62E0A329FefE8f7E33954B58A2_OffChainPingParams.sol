// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./IPingParams.sol";
import "./PingAtts.sol";

contract OffChainPingParams is IPingParams, Ownable {

    using Strings for uint8;
    using Strings for uint256;

    function getParmsSequence(uint256 tokenId, PingAtts calldata atts, bool isSample)
        public
        pure
        virtual
        override
        returns(string memory)
    {
        return string.concat(
            getParmsSequence_1(tokenId, atts),
            getParmsSequence_2(atts),
            getParmsSequence_3(atts, isSample)
        );

    }
    function getParmsSequence_1(uint256 tokenId, PingAtts calldata atts)
        internal
        pure
        returns(string memory)
    {
        return string.concat(
            "[",
            tokenId.toString(), ",",
            atts.numX.toString(), ",",
            atts.numY.toString(), ",",
            atts.paletteIndex.toString(), ",",
            (atts.hasTexture ? "1" : "0"), ",",
            (atts.openShape ? "1" : "0"), ",",
            atts.lineColorIdx.toString(), ",",
            atts.paintIdx.toString(), ","
        );
    }

    function getParmsSequence_2(PingAtts calldata atts)
        internal
        pure
        returns(string memory)
    {
        return string.concat(
            atts.shapeColorIdx.toString(), ",",
            atts.emitColorIdx.toString(), ",",
            atts.shadowColorIdx.toString(), ",",
            atts.nShadColIdx.toString(), ",",
            atts.shapeSizesDensity.toString(), ",",
            atts.lineThickness.toString(), ",",
            atts.emitRate.toString(), ",",
            atts.wiggleSpeedIdx.toString(), ","
        );
    }

    function getParmsSequence_3(PingAtts calldata atts, bool isSample)
        internal
        pure
        returns(string memory)
    {
        return string.concat(
            atts.wiggleStrengthIdx.toString(), ",",
            atts.paint2Idx.toString(), ",",

            (isSample ? "1" : "0"),
            "]"

        );
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


struct PingAtts {
    uint8 numX;
    uint8 numY;
    uint8 paletteIndex;
    bool hasTexture;
    bool openShape;
    uint8 lineColorIdx;
    uint8 paintIdx;
    uint8 shapeColorIdx;
    uint8 emitColorIdx;
    uint8 shadowColorIdx;
    uint8 nShadColIdx;
    uint8 shapeSizesDensity;
    uint8 lineThickness;
    uint8 emitRate;
    uint8 wiggleSpeedIdx;
    uint8 wiggleStrengthIdx;
    uint8 paint2Idx;

    uint8[] extraParams;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./PingAtts.sol";

interface IPingParams {

    function getParmsSequence(uint256 tokenId, PingAtts calldata atts, bool isSample) external pure returns(string memory);

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
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