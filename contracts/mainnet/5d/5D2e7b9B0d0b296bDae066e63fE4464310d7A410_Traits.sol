// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./lib/Ownable.sol";
import "./lib/Strings.sol";
import "./ITraits.sol";
import "./IDegens.sol";

contract Traits is Ownable, ITraits {

    using Strings for uint256;

    bool phase1 = true;

    // struct to store each trait's data for metadata and rendering
    struct Trait {
        string name;
        string png;
    }

    // mapping from trait type (index) to its name
    string[8] _traitTypes = [
    "Accessories",
    "Clothes",
    "Eyes",
    "Background",
    "Mouth",
    "Body",
    "Hairdo",
    "Alpha"
    ];

    // storage of each traits name and base64 PNG data
    mapping(uint8 => mapping(uint8 => mapping(uint8 => Trait))) public traitData;

    // mapping from alphaIndex to its score
    string[4] _alphas = ["8", "7", "6", "5"];

    IDegens public degens;

    constructor() {}

    function setPhase1Enabled(bool _enabled) external onlyOwner {
        phase1 = _enabled;
    }

    /** ADMIN */
    function setDegensContractAddress(address _degensContractAddress) external onlyOwner {
        degens = IDegens(_degensContractAddress);
    }

    /**
     * administrative to upload the names and images associated with each trait
     * @param traitType the trait type to upload the traits for (see traitTypes for a mapping)
   * @param traits the names and base64 encoded PNGs for each trait
   */
    function uploadTraits(uint8 degenType, uint8 traitType, uint8[] calldata traitIds, Trait[] calldata traits) external onlyOwner {
        require(traitIds.length == traits.length, "Mismatched inputs");
        for (uint i = 0; i < traits.length; i++) {
            traitData[degenType][traitType][traitIds[i]] = Trait(
                traits[i].name,
                traits[i].png
            );
        }
    }

    /** RENDER */

    /**
     * generates an <image> element using base64 encoded PNGs
     * @param trait the trait storing the PNG data
   * @return the <image> element
   */
    function drawTrait(Trait memory trait) internal pure returns (string memory) {
        return string(abi.encodePacked(
                '<image x="0" y="0" width="64" height="64" image-rendering="pixelated" preserveAspectRatio="xMidYMid" xlink:href="data:image/png;base64,',
                trait.png,
                '"/>'
            ));
    }

    /**
     * generates an entire SVG by composing multiple <image> elements of PNGs
     * @param tokenId the ID of the token to generate an SVG for
   * @return a valid SVG of the bba / zombie
   */
    function drawSVG(uint256 tokenId) public view returns (string memory) {
        IDegens.Degen memory s = degens.getTokenTraits(tokenId);
        bool isNotZombie = !degens.isZombies(s);
        bool isApe = degens.isApes(s);
        bool isBear = degens.isBears(s);
        bool isBull = degens.isBull(s);

        if (phase1) {
            string memory imagelink;
            if (!isNotZombie) {
                imagelink = "https://gameofdegens.com/zombie_placeholder.gif";
            } else if (isApe) {
                imagelink = "https://gameofdegens.com/ape_placeholder.gif";
            } else if (isBear) {
                imagelink = "https://gameofdegens.com/bear_placeholder.gif";
            } else if (isBull) {
                imagelink = "https://gameofdegens.com/bull_placeholder.gif";
            }

            return imagelink;
        }

        string memory svgString = string(abi.encodePacked(
                drawTrait(traitData[0][3][s.background]),
                drawTrait(traitData[s.degenType][5][s.body]),
                isApe ? drawTrait(traitData[s.degenType][2][s.eyes]) : drawTrait(traitData[s.degenType][1][s.clothes]),
                isApe ? drawTrait(traitData[s.degenType][1][s.clothes]) : drawTrait(traitData[s.degenType][2][s.eyes]),
                isNotZombie ? isBear ? drawTrait(traitData[s.degenType][0][s.accessories]) : drawTrait(traitData[s.degenType][4][s.mouth]) : drawTrait(traitData[s.degenType][6][s.hairdo]),
                isBear ? drawTrait(traitData[s.degenType][4][s.mouth]) : drawTrait(traitData[s.degenType][0][s.accessories])

            ));

        return string(abi.encodePacked(
                '<svg id="character" width="100%" height="100%" version="1.1" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">',
                svgString,
                "</svg>"
            ));
    }

    /**
     * generates an attribute for the attributes array in the ERC721 metadata standard
     * @param traitType the trait type to reference as the metadata key
   * @param value the token's trait associated with the key
   * @return a JSON dictionary for the single attribute
   */
    function attributeForTypeAndValue(string memory traitType, string memory value) internal pure returns (string memory) {
        return string(abi.encodePacked(
                '{"trait_type":"',
                traitType,
                '","value":"',
                value,
                '"}'
            ));
    }

    /**
     * generates an array composed of all the individual traits and values
     * @param tokenId the ID of the token to compose the metadata for
   * @return a JSON array of all of the attributes for given token ID
   */
    function compileAttributes(uint256 tokenId) public view returns (string memory) {
        IDegens.Degen memory s = degens.getTokenTraits(tokenId);
        string memory traits;

        if (phase1) {
            return string(abi.encodePacked(
                    '[{"trait_type":"Generation","value": "',
                    degens.getNFTGeneration(tokenId),
                    '"},{"trait_type":"Type","value": "', degens.getDegenTypeName(s), '"}]'
                ));
        }

        if (degens.isBull(s)) {
            traits = string(abi.encodePacked(
                    attributeForTypeAndValue(_traitTypes[0], traitData[0][0][s.accessories].name), ',',
                    attributeForTypeAndValue(_traitTypes[1], traitData[0][1][s.clothes].name), ',',
                    attributeForTypeAndValue(_traitTypes[2], traitData[0][2][s.eyes].name), ',',
                    attributeForTypeAndValue(_traitTypes[3], traitData[0][3][s.background].name), ',',
                    attributeForTypeAndValue(_traitTypes[4], traitData[0][4][s.mouth].name), ',',
                    attributeForTypeAndValue(_traitTypes[5], traitData[0][5][s.body].name), ','
                ));
        }
        else if (degens.isBears(s)) {
            traits = string(abi.encodePacked(
                    attributeForTypeAndValue(_traitTypes[0], traitData[1][0][s.accessories].name), ',',
                    attributeForTypeAndValue(_traitTypes[1], traitData[1][1][s.clothes].name), ',',
                    attributeForTypeAndValue(_traitTypes[2], traitData[1][2][s.eyes].name), ',',
                    attributeForTypeAndValue(_traitTypes[3], traitData[0][3][s.background].name), ',',
                    attributeForTypeAndValue(_traitTypes[4], traitData[1][4][s.mouth].name), ',',
                    attributeForTypeAndValue(_traitTypes[5], traitData[1][5][s.body].name), ','
                ));
        } else if (degens.isApes(s)) {
            traits = string(abi.encodePacked(
                    attributeForTypeAndValue(_traitTypes[0], traitData[2][0][s.accessories].name), ',',
                    attributeForTypeAndValue(_traitTypes[1], traitData[2][1][s.clothes].name), ',',
                    attributeForTypeAndValue(_traitTypes[2], traitData[2][2][s.eyes].name), ',',
                    attributeForTypeAndValue(_traitTypes[3], traitData[0][3][s.background].name), ',',
                    attributeForTypeAndValue(_traitTypes[4], traitData[2][4][s.mouth].name), ',',
                    attributeForTypeAndValue(_traitTypes[5], traitData[2][5][s.body].name), ','
                ));
        } else if (degens.isZombies(s)) {
            traits = string(abi.encodePacked(
                    attributeForTypeAndValue(_traitTypes[0], traitData[3][0][s.accessories].name), ',',
                    attributeForTypeAndValue(_traitTypes[1], traitData[3][1][s.clothes].name), ',',
                    attributeForTypeAndValue(_traitTypes[2], traitData[3][2][s.eyes].name), ',',
                    attributeForTypeAndValue(_traitTypes[3], traitData[0][3][s.background].name), ',',
                    attributeForTypeAndValue(_traitTypes[5], traitData[3][5][s.body].name), ',',
                    attributeForTypeAndValue(_traitTypes[6], traitData[3][6][s.hairdo].name), ',',
                    attributeForTypeAndValue("Alpha Score", _alphas[s.alphaIndex]), ','
                ));
        }
        return string(abi.encodePacked(
                '[',
                traits,
                '{"trait_type":"Generation","value":"',
                degens.getNFTGeneration(tokenId),
                '"},{"trait_type":"Type","value":"',
                degens.getDegenTypeName(s),
                '"}]'
            ));
    }

    /**
     * generates a base64 encoded metadata response without referencing off-chain content
     * @param tokenId the ID of the token to generate the metadata for
   * @return a base64 encoded JSON dictionary of the token's metadata and SVG
   */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        IDegens.Degen memory s = degens.getTokenTraits(tokenId);

        string memory metadata = string(abi.encodePacked(
                '{"name": "',
                degens.getNFTName(s), ' #',
                tokenId.toString(),
                '", "description": "A group of elite degens unite in a fortress in a metaverse to protect themselves from the zombies. A tempting prize of $GAINS awaits, with deadly high stakes. All the metadata and images are generated and stored 100% on-chain. No IPFS. NO API. Just the Ethereum blockchain.",',
                ' "image":', phase1 ? '"' : '"data:image/svg+xml;base64,',
                phase1 ? drawSVG(tokenId) : '',
                phase1 ? '' : base64(bytes(drawSVG(tokenId))),
                '", "attributes":',
                compileAttributes(tokenId),
                "}"
            ));

        return string(abi.encodePacked(
                "data:application/json;base64,",
                base64(bytes(metadata))
            ));
    }

    /** BASE 64 - Written by Brech Devos */
    string internal constant TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
        // set the actual output length
            mstore(result, encodedLen)

        // prepare the lookup table
            let tablePtr := add(table, 1)

        // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

        // result ptr, jump over length
            let resultPtr := add(result, 32)

        // run over the input, 3 bytes at a time
            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)

            // read 3 bytes
                let input := mload(dataPtr)

            // write 4 characters
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(input, 0x3F)))))
                resultPtr := add(resultPtr, 1)
            }

        // padding with '='
            switch mod(mload(data), 3)
            case 1 {mstore(sub(resultPtr, 2), shl(240, 0x3d3d))}
            case 2 {mstore(sub(resultPtr, 1), shl(248, 0x3d))}
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

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

pragma solidity ^0.8.0;

import "./Context.sol";

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

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
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

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
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ITraits {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ierc/IERC721.sol";

interface IDegens is IERC721 {

    // struct to store each token's traits
    struct Degen {
        uint8 degenType;
        uint8 accessories;
        uint8 clothes;
        uint8 eyes;
        uint8 background;
        uint8 mouth;
        uint8 body;
        uint8 hairdo;
        uint8 alphaIndex;
    }

    function getDegenTypeName(Degen memory _degen) external view returns (string memory);

    function getNFTName(Degen memory _degen) external view returns (string memory);

    function getNFTGeneration(uint256 tokenId) external pure returns (string memory);

    function getPaidTokens() external view returns (uint256);

    function getTokenTraits(uint256 tokenId) external view returns (Degen memory);

    function isBull(Degen memory _character) external pure returns (bool);

    function isBears(Degen memory _character) external pure returns (bool);

    function isZombies(Degen memory _character) external pure returns (bool);

    function isApes(Degen memory _character) external pure returns (bool);
}