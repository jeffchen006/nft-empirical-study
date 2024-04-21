// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @author: x0r - Michael Blau

import '@openzeppelin/contracts/utils/Strings.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Base64.sol';
import '@openzeppelin/contracts/interfaces/IERC721.sol';

contract ASCIIGenerator is Ownable {
    using Base64 for string;
    using Strings for uint256;

    uint256[] public partOne;
    uint256[] public partTwo;

    string internal description = 'description';
    string internal SVGHeader =
        "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 900 1090'><defs><style>.cls-1{font-size: 10px; fill: white; font-family:monospace;}</style></defs><g><rect width='900' height='1090' fill='black' />";
    string internal firstTextTagPart =
        "<text lengthAdjust='spacing' textLength='900' class='cls-1' x='0' y='";
    string internal SVGFooter = '</g></svg>';
    uint256 internal tspanLineHeight = 12;

    // =================== ASCII GENERATOR FUNCTIONS =================== //

    /**
     * @notice Generates full metadata
     */
    function generateMetadata(address _nftContract, uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        string[55] memory owners = getOwners(_nftContract);

        string memory SVG = generateSVG(owners);

        string memory metadata = Base64.encode(
            bytes(
                string.concat(
                    '{"name": "Ledger #',
                    _tokenId.toString(),
                    '/55",',
                    '"description":"',
                    description,
                    '","image":"',
                    SVG,
                    '"}'
                )
            )
        );

        return string.concat('data:application/json;base64,', metadata);
    }

    /**
     * @notice Get all ERC721 owner addresses and convert them to strings
     * @param _nftContract to query NFT owners from
     */
    function getOwners(address _nftContract) internal view returns (string[55] memory) {
        IERC721 nftContract = IERC721(_nftContract);

        string[55] memory owners;

        for (uint256 i; i < owners.length; i++) {
            try nftContract.ownerOf(i + 1) returns (address nftOwner) {
                owners[i] = Strings.toHexString(uint256(uint160(nftOwner)), 20);
            } catch {
                owners[i] = Strings.toHexString(uint256(uint160(address(0))), 20);
            }
        }

        return owners;
    }

    /**
     * @notice Generates the SVG image
     */
    function generateSVG(string[55] memory _owners) public view returns (string memory) {
        string[89] memory rows = genCoreAscii(_owners);

        string memory _firstTextTagPart = firstTextTagPart;
        string memory span;
        string memory center;
        uint256 y = tspanLineHeight;

        for (uint256 i; i < rows.length; i++) {
            span = string.concat(_firstTextTagPart, y.toString(), "'>", rows[i], '</text>');
            center = string.concat(center, span);
            y += tspanLineHeight;
        }

        // add last row of ASCII that contains the last updated block number
        center = string.concat(
            center,
            _firstTextTagPart,
            y.toString(),
            "'>",
            getLastUpdatedBlockString(block.number),
            '</text>'
        );

        // base64 encode the SVG text
        string memory SVGImage = Base64.encode(bytes(string.concat(SVGHeader, center, SVGFooter)));

        return string.concat('data:image/svg+xml;base64,', SVGImage);
    }

    /**
     * @notice Generates all ASCII rows of the image
     */
    function genCoreAscii(string[55] memory _owners) public view returns (string[89] memory) {
        string[89] memory asciiRows;

        uint256 partOneEndIndex = partOne.length;
        uint256 partTwoEndIndex = partOneEndIndex + partTwo.length;

        for (uint256 i; i < asciiRows.length; i++) {
            if (i < partOneEndIndex) {
                asciiRows[i] = rowToString(partOne[i], 150);
            } else if (i >= partOneEndIndex && i < partTwoEndIndex) {
                uint256 centerIndex = i - partOneEndIndex;
                string memory rowHalf = rowToString(partTwo[centerIndex], 54);
                asciiRows[i] = string.concat(rowHalf, _owners[centerIndex], reverseValue(rowHalf));
            } else if (i >= partTwoEndIndex) {
                asciiRows[i] = asciiRows[asciiRows.length - i - 1];
            }
        }

        return asciiRows;
    }

    /**
     * @notice Generates one ASCII row as a string
     */
    function rowToString(uint256 _row, uint256 _bitsToUnpack)
        internal
        pure
        returns (string memory)
    {
        string memory rowString;
        for (uint256 i; i < _bitsToUnpack; i++) {
            if (((_row >> (1 * i)) & 1) == 0) {
                rowString = string.concat(rowString, '.');
            } else {
                rowString = string.concat(rowString, '-');
            }
        }

        return rowString;
    }

    /**
     * @notice Generates one row of ASCII that shows the last block number when the ledger was updated (i.e., the NFT was transferred)
     * @param _blockNumber when the NFT was last transferred
     */
    function getLastUpdatedBlockString(uint256 _blockNumber) public pure returns (string memory) {
        string memory blockNumberString = _blockNumber.toString();
        uint256 asciiOffset = 150 - bytes(blockNumberString).length;

        string memory asciiRow;
        for (uint256 i; i < asciiOffset; i++) {
            asciiRow = string.concat(asciiRow, '.');
        }

        return string.concat(asciiRow, blockNumberString);
    }

    /**
     * @notice reverse a string
     */
    function reverseValue(string memory _base) internal pure returns (string memory) {
        bytes memory _baseBytes = bytes(_base);
        assert(_baseBytes.length > 0);

        string memory _tempValue = new string(_baseBytes.length);
        bytes memory _newValue = bytes(_tempValue);

        for (uint256 i; i < _baseBytes.length; i++) {
            _newValue[_baseBytes.length - i - 1] = _baseBytes[i];
        }

        return string(_newValue);
    }

    // =================== STORE IMAGE DATA =================== //

    function storeImageParts(uint256[] memory _partOne, uint256[] memory _partTwo)
        external
        onlyOwner
    {
        partOne = _partOne;
        partTwo = _partTwo;
    }

    function setSVGParts(
        string calldata _SVGHeader,
        string calldata _SVGFooter,
        string calldata _firstTextTagPart,
        uint256 _tspanLineHeight
    ) external onlyOwner {
        SVGHeader = _SVGHeader;
        SVGFooter = _SVGFooter;
        firstTextTagPart = _firstTextTagPart;
        tspanLineHeight = _tspanLineHeight;
    }

    function getSVGParts()
        external
        view
        returns (
            string memory,
            string memory,
            string memory,
            uint256
        )
    {
        return (SVGHeader, SVGFooter, firstTextTagPart, tspanLineHeight);
    }

    function setDescription(string calldata _description) external onlyOwner {
        description = _description;
    }
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Base64.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides a set of functions to operate with Base64 strings.
 *
 * _Available since v4.5._
 */
library Base64 {
    /**
     * @dev Base64 Encoding/Decoding Table
     */
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Converts a `bytes` to its Bytes64 `string` representation.
     */
    function encode(bytes memory data) internal pure returns (string memory) {
        /**
         * Inspired by Brecht Devos (Brechtpd) implementation - MIT licence
         * https://github.com/Brechtpd/base64/blob/e78d9fd951e7b0977ddca77d92dc85183770daf4/base64.sol
         */
        if (data.length == 0) return "";

        // Loads the table into memory
        string memory table = _TABLE;

        // Encoding takes 3 bytes chunks of binary data from `bytes` data parameter
        // and split into 4 numbers of 6 bits.
        // The final Base64 length should be `bytes` data length multiplied by 4/3 rounded up
        // - `data.length + 2`  -> Round up
        // - `/ 3`              -> Number of 3-bytes chunks
        // - `4 *`              -> 4 characters for each chunk
        string memory result = new string(4 * ((data.length + 2) / 3));

        assembly {
            // Prepare the lookup table (skip the first "length" byte)
            let tablePtr := add(table, 1)

            // Prepare result pointer, jump over length
            let resultPtr := add(result, 32)

            // Run over the input, 3 bytes at a time
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {

            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // To write each character, shift the 3 bytes (18 bits) chunk
                // 4 times in blocks of 6 bits for each character (18, 12, 6, 0)
                // and apply logical AND with 0x3F which is the number of
                // the previous character in the ASCII table prior to the Base64 Table
                // The result is then added to the table to get the character to write,
                // and finally write it in the result pointer but with a left shift
                // of 256 (1 byte) - 8 (1 ASCII char) = 248 bits

                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance

                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }

            // When data `bytes` is not exactly 3 bytes long
            // it is padded with `=` characters at the end
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC721.sol)

pragma solidity ^0.8.0;

import "../token/ERC721/IERC721.sol";

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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721.sol)

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
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
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