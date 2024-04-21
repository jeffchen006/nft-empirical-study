// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "base64-sol/base64.sol";
import "./lib/ERC721Initializable.sol";
import "./lib/ERC721Queryable.sol";
import "./lib/ColorUtils.sol";
import "./lib/StringUtils.sol";
import "./IDixelClubV2Factory.sol";
import "./Shared.sol";
import "./Constants.sol";
import "./SVGGenerator.sol"; // inheriting Constants

/* Change Logs

<Version 2>
1. Add default dimemsions on SVG for better compatibility (Opensea)
2. Fix white gapp issues on Safari & iPhone browsers (hack: 25f5e59)
3. Allow new-line characters on descriptions

<Version 3>
1. Remove JSON string validator (should be done on front-end)

<Version 4>
1. Add `mintByOwner` function that can by-pass whitelist, mintingCost, mintingBeginsFrom checks
*/

contract DixelClubV2NFT is ERC721Queryable, Ownable, Constants, SVGGenerator {
    error DixelClubV2__NotExist();
    error DixelClubV2__Initalized();
    error DixelClubV2__InvalidCost(uint256 expected, uint256 actual);
    error DixelClubV2__MaximumMinted();
    error DixelClubV2__NotStarted(uint40 beginAt, uint40 nowAt);
    error DixelClubV2__NotWhitelisted();
    error DixelClubV2__NotApproved();
    error DixelClubV2__PublicCollection();
    error DixelClubV2__PrivateCollection();
    error DixelClubV2__InvalidRoyalty(uint256 invalid);
    error DixelClubV2__AlreadyStarted();
    error DixelClubV2__DescriptionTooLong();
    error DixelClubV2__WhiteListValueDoNotMatch(address expected, address actual);

    struct EditionData {
        uint24[PALETTE_SIZE] palette; // 24bit color (16,777,216) - up to 16 colors
    }

    IDixelClubV2Factory private _factory;
    uint40 private _initializedAt;
    Shared.MetaData private _metaData; // Collection meta data

    EditionData[] private _editionData; // Color (palette) data for each edition
    uint8[PIXEL_ARRAY_SIZE] private _pixels; // 8 * 288 = 2304bit = 9 of 256bit storage block. Each uint8 saves 2 pixels.

    // NOTE: Implemented whitelist managing function with the simplest structure for gas saving
    // - EnumerableMap adds 3-5x more gas
    // - MerkleTree doesn't fit for managing the actual list on-chain
    address[] private _whitelist;
    string private _description;

    event Mint(address indexed to, uint256 indexed tokenId);
    event Burn(uint256 indexed tokenId);

    modifier checkTokenExists(uint256 tokenId) {
        if (!_exists(tokenId)) revert DixelClubV2__NotExist();
        _;
    }

    function init(
        address owner_,
        string calldata name_,
        string calldata symbol_,
        string calldata description_,
        Shared.MetaData calldata metaData_,
        uint24[PALETTE_SIZE] calldata palette_,
        uint8[PIXEL_ARRAY_SIZE] calldata pixels_
    ) external {
        if(_initializedAt != 0) revert DixelClubV2__Initalized();
        _initializedAt = uint40(block.timestamp);

        _factory = IDixelClubV2Factory(msg.sender);

        // ERC721 attributes
        _name = name_;
        _symbol = symbol_;
        _description = description_;

        // Custom attributes
        _metaData = metaData_;
        _pixels = pixels_;

        // Transfer ownership to the collection creator, so he/she can edit info on marketplaces like Opeansea
        _transferOwnership(owner_);

        // Mint edition #0 to the creator with the default palette set automatically
        _mintNewEdition(owner_, palette_);
    }

    function mintPublic(address to, uint24[PALETTE_SIZE] calldata palette) external payable {
        if(_metaData.whitelistOnly) revert DixelClubV2__PrivateCollection();

        _mintWithFees(to, palette);
    }

    function mintPrivate(uint256 whitelistIndex, address to, uint24[PALETTE_SIZE] calldata palette) external payable {
        if(!_metaData.whitelistOnly) revert DixelClubV2__PublicCollection();

        _removeWhitelist(whitelistIndex, msg.sender);

        _mintWithFees(to, palette);
    }

    // Give free minting permission to the collection owner because owners can update settings anyway
    function mintByOwner(address to, uint24[PALETTE_SIZE] calldata palette) external onlyOwner {
        // By-passing whitelist, mintingCost, mintingBeginsFrom checks
        // maxSupply is not changeable even by the owner, so it should be checked
        if(nextTokenId() >= _metaData.maxSupply) revert DixelClubV2__MaximumMinted();

        _mintNewEdition(to, palette);
    }

    function _mintWithFees(address to, uint24[PALETTE_SIZE] calldata palette) private {
        uint256 mintingCost = uint256(_metaData.mintingCost);

        if(msg.value != mintingCost) revert DixelClubV2__InvalidCost(mintingCost, msg.value);
        if(nextTokenId() >= _metaData.maxSupply) revert DixelClubV2__MaximumMinted();
        if(uint40(block.timestamp) < _metaData.mintingBeginsFrom) revert DixelClubV2__NotStarted(_metaData.mintingBeginsFrom, uint40(block.timestamp));

        if (mintingCost > 0) {
            // Send fee to the beneficiary
            uint256 fee = (mintingCost * _factory.mintingFee()) / FRICTION_BASE;
            (bool sent, ) = (_factory.beneficiary()).call{ value: fee }("");
            require(sent, "FEE_TRANSFER_FAILED");

            // Send the rest of minting cost to the collection creator
            (bool sent2, ) = (owner()).call{ value: mintingCost - fee }("");
            require(sent2, "MINTING_COST_TRANSFER_FAILED");
        }

        _mintNewEdition(to, palette);
    }

    function _mintNewEdition(address to, uint24[PALETTE_SIZE] calldata palette) private {
        uint256 nextId = nextTokenId();

        _editionData.push(EditionData(palette));
        unchecked {
            assert(nextId == _editionData.length - 1);
        }

        _safeMint(to, nextId);

        emit Mint(to, nextId);
    }

    function burn(uint256 tokenId) external {
        if(!_isApprovedOrOwner(msg.sender, tokenId)) revert DixelClubV2__NotApproved(); // This will check existence of token

        delete _editionData[tokenId];
        _burn(tokenId);

        emit Burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override checkTokenExists(tokenId) returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(tokenJSON(tokenId)))));
    }

    // Contract-level metadata for Opeansea
    // REF: https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(contractJSON()))));
    }

    // MARK: - Whitelist related functions

    // @dev Maximum length of list parameter can be limited by block gas limit of blockchain
    // @notice Duplicated address input means multiple allowance
    function addWhitelist(address[] calldata list) external onlyOwner {
        if(!_metaData.whitelistOnly) revert DixelClubV2__PublicCollection();

        uint256 length = list.length; // gas saving
        for (uint256 i; i != length;) {
            _whitelist.push(list[i]); // O(1) for adding 1 address
            unchecked {
                ++i;
            }
        }
    }

    function _removeWhitelist(uint256 index, address value) private {
        if(!_metaData.whitelistOnly) revert DixelClubV2__PublicCollection();
        if (_whitelist[index] != value) revert DixelClubV2__WhiteListValueDoNotMatch(value, _whitelist[index]);

        _whitelist[index] = _whitelist[_whitelist.length - 1]; // put the last element into the delete index
        _whitelist.pop(); // delete the last element to decrease array length;
    }

    // @dev O(1) for removing by index
    function removeWhitelist(uint256 index, address value) external onlyOwner {
        _removeWhitelist(index, value);
    }

    function resetWhitelist() external onlyOwner {
        delete _whitelist;
    }

    // @dev offset & limit for pagination
    function getAllWhitelist(uint256 offset, uint256 limit) external view returns (address[] memory list) {
        unchecked {
            address[] memory clone = _whitelist; // gas saving
            uint256 length = clone.length; // gas saving
            uint256 count = limit;

            if (offset >= length) {
                return list; // empty list
            } else if (offset + limit > length) {
                count = length - offset;
            }

            list = new address[](count);
            for (uint256 i = 0; i != count; ++i) {
                list[i] = clone[offset + i];
            }
        }
    }

    function getWhitelistCount() external view returns (uint256) {
        return _whitelist.length;
    }

    // @dev utility function for front-end, that can be reverted if the list is too big
    function getWhitelistAllowanceLeft(address wallet) external view returns (uint256 allowance) {
        unchecked {
            address[] memory clone = _whitelist; // gas saving
            uint256 length = clone.length; // gas saving
            for (uint256 i; i != length; ++i) {
                if (clone[i] == wallet) {
                    allowance++;
                }
            }

            return allowance;
        }
    }

    // @dev utility function for front-end, that can be reverted if the list is too big
    function getWhitelistIndex(address wallet) external view returns (uint256) {
        unchecked {
            address[] memory clone = _whitelist; // gas saving
            uint256 length = clone.length; // gas saving
            for (uint256 i; i != length; ++i) {
                if (clone[i] == wallet) {
                    return i;
                }
            }

            revert DixelClubV2__NotWhitelisted();
        }
    }


    // MARK: - Update metadata

    function updateMetadata(bool whitelistOnly, bool hidden, uint24 royaltyFriction, uint40 mintingBeginsFrom, uint152 mintingCost) external onlyOwner {
        if(royaltyFriction > MAX_ROYALTY_FRACTION) revert DixelClubV2__InvalidRoyalty(royaltyFriction);
        if(_metaData.mintingBeginsFrom != mintingBeginsFrom && uint40(block.timestamp) >= _metaData.mintingBeginsFrom) revert DixelClubV2__AlreadyStarted();

        _metaData.whitelistOnly = whitelistOnly;
        if (!_metaData.whitelistOnly) {
            delete _whitelist; // empty whitelist array data if it becomes public
        }

        _metaData.hidden = hidden;
        _metaData.royaltyFriction = royaltyFriction;
        _metaData.mintingBeginsFrom = mintingBeginsFrom < block.timestamp ? uint40(block.timestamp) : mintingBeginsFrom;
        _metaData.mintingCost = mintingCost;
    }

    function updateDescription(string calldata description) external onlyOwner {
        if (bytes(description).length > 1000) revert DixelClubV2__DescriptionTooLong(); // ~900 gas per character

        _description = description;
    }

    // MARK: - External utility functions

    function generateSVG(uint256 tokenId) external view checkTokenExists(tokenId) returns (string memory) {
        return _generateSVG(_editionData[tokenId].palette, _pixels);
    }

    function generateBase64SVG(uint256 tokenId) public view checkTokenExists(tokenId) returns (string memory) {
        return _generateBase64SVG(_editionData[tokenId].palette, _pixels);
    }

    function tokenJSON(uint256 tokenId) public view checkTokenExists(tokenId) returns (string memory) {
        return string(abi.encodePacked(
            '{"name":"',
            _symbol, ' #', ColorUtils.uint2str(tokenId),
            '","description":"',
            _description,
            '","external_url":"https://dixel.club/collection/',
            ColorUtils.uint2str(block.chainid), '/', StringUtils.address2str(address(this)), '/', ColorUtils.uint2str(tokenId),
            '","image":"',
            generateBase64SVG(tokenId),
            '"}'
        ));
    }

    function contractJSON() public view returns (string memory) {
        return string(abi.encodePacked(
            '{"name":"',
            _name,
            '","description":"',
            _description,
            '","image":"',
            generateBase64SVG(0),
            '","external_link":"https://dixel.club/collection/',
            ColorUtils.uint2str(block.chainid), '/', StringUtils.address2str(address(this)),
            '","seller_fee_basis_points":"',
            ColorUtils.uint2str(_metaData.royaltyFriction),
            '","fee_recipient":"',
            StringUtils.address2str(owner()),
            '"}'
        ));
    }

    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    function listData() external view returns (uint40 initializedAt_, bool hidden_) {
        initializedAt_ = _initializedAt;
        hidden_ = _metaData.hidden;
    }

    function metaData() external view returns (
        string memory name_,
        bool whitelistOnly_,
        uint24 maxSupply_,
        uint24 royaltyFriction_,
        uint40 mintingBeginsFrom_,
        uint168 mintingCost_,
        string memory description_,
        uint256 nextTokenId_,
        uint256 totalSupply_,
        address owner_,
        uint8[PIXEL_ARRAY_SIZE] memory pixels_,
        uint24[PALETTE_SIZE] memory defaultPalette_
    ) {
        name_ = name();
        whitelistOnly_ = _metaData.whitelistOnly;
        maxSupply_ = _metaData.maxSupply;
        royaltyFriction_ = _metaData.royaltyFriction;
        mintingBeginsFrom_ = _metaData.mintingBeginsFrom;
        mintingCost_ = _metaData.mintingCost;
        description_ = _description;
        nextTokenId_ = nextTokenId();
        totalSupply_ = totalSupply();
        owner_ = owner();
        pixels_ = _pixels;
        defaultPalette_ = _editionData[0].palette;
    }

    function paletteOf(uint256 tokenId) external view checkTokenExists(tokenId) returns (uint24[PALETTE_SIZE] memory) {
        return _editionData[tokenId].palette;
    }

    function getAllPixels() external view returns (uint8[PIXEL_ARRAY_SIZE] memory) {
        return _pixels;
    }

    // MARK: - Override extensions

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Initializable) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev IERC2981 implementation
     * - NOTE: ERC2981 royalty info may not be applied on some marketplaces
     * - NOTE: Opensea uses contract-level metadata: https://docs.opensea.io/docs/contract-level-metadata
     */
    function royaltyInfo(uint256 /*_tokenId*/, uint256 _salePrice) public view returns (address, uint256) {
        // NOTE:
        // 1. The same royalty friction for all tokens in the same collection
        // 2. Receiver is collection owner

        return (owner(), (_salePrice * _metaData.royaltyFriction) / FRICTION_BASE);
    }

    // NFT implementation version
    function version() external pure virtual returns (uint16) {
        return 4;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (interfaces/IERC2981.sol)

pragma solidity ^0.8.0;

import "../utils/introspection/IERC165.sol";

/**
 * @dev Interface for the NFT Royalty Standard.
 *
 * A standardized way to retrieve royalty payment information for non-fungible tokens (NFTs) to enable universal
 * support for royalty payments across all NFT marketplaces and ecosystem participants.
 *
 * _Available since v4.5._
 */
interface IERC2981 is IERC165 {
    /**
     * @dev Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
     * exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
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

pragma solidity >=0.6.0;

/// @title Base64
/// @author Brecht Devos - <[email protected]>
/// @notice Provides functions for encoding/decoding base64
library Base64 {
    string internal constant TABLE_ENCODE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    bytes  internal constant TABLE_DECODE = hex"0000000000000000000000000000000000000000000000000000000000000000"
                                            hex"00000000000000000000003e0000003f3435363738393a3b3c3d000000000000"
                                            hex"00000102030405060708090a0b0c0d0e0f101112131415161718190000000000"
                                            hex"001a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132330000000000";

    function encode(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return '';

        // load the table into memory
        string memory table = TABLE_ENCODE;

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
                // read 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)

                // write 4 characters
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(shr( 6, input), 0x3F))))
                resultPtr := add(resultPtr, 1)
                mstore8(resultPtr, mload(add(tablePtr, and(        input,  0x3F))))
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function decode(string memory _data) internal pure returns (bytes memory) {
        bytes memory data = bytes(_data);

        if (data.length == 0) return new bytes(0);
        require(data.length % 4 == 0, "invalid base64 decoder input");

        // load the table into memory
        bytes memory table = TABLE_DECODE;

        // every 4 characters represent 3 bytes
        uint256 decodedLen = (data.length / 4) * 3;

        // add some extra buffer at the end required for the writing
        bytes memory result = new bytes(decodedLen + 32);

        assembly {
            // padding with '='
            let lastBytes := mload(add(data, mload(data)))
            if eq(and(lastBytes, 0xFF), 0x3d) {
                decodedLen := sub(decodedLen, 1)
                if eq(and(lastBytes, 0xFFFF), 0x3d3d) {
                    decodedLen := sub(decodedLen, 1)
                }
            }

            // set the actual output length
            mstore(result, decodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 4 characters at a time
            for {} lt(dataPtr, endPtr) {}
            {
               // read 4 characters
               dataPtr := add(dataPtr, 4)
               let input := mload(dataPtr)

               // write 3 bytes
               let output := add(
                   add(
                       shl(18, and(mload(add(tablePtr, and(shr(24, input), 0xFF))), 0xFF)),
                       shl(12, and(mload(add(tablePtr, and(shr(16, input), 0xFF))), 0xFF))),
                   add(
                       shl( 6, and(mload(add(tablePtr, and(shr( 8, input), 0xFF))), 0xFF)),
                               and(mload(add(tablePtr, and(        input , 0xFF))), 0xFF)
                    )
                )
                mstore(resultPtr, shl(232, output))
                resultPtr := add(resultPtr, 3)
            }
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT

// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

/**
 * @dev A slightly modified version of ERC721.sol (from Openzeppelin 4.6.0) for initialization pattern
 *   - remove constructor
 *   - make `_name`, `_symbol` and `_owners` internal instead of private
 *   - rename ERC721 -> ERC721Initializable
 */
abstract contract ERC721Initializable is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string internal _name;

    // Token symbol
    string internal _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) internal _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

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
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
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
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

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
        address owner = ERC721Initializable.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

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
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

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
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
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
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
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
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721Initializable.ownerOf(tokenId);
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
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
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

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721Initializable.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
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
        require(ERC721Initializable.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        unchecked {
            _balances[to] += 1;
        }
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721Initializable.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
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
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
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
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import './ERC721Initializable.sol';

/**
 * @title ERC721A Queryable + ERC721Enumerable#totalSupply only to save gas
 * @dev ERC721A subclass with convenience query functions.
 */
abstract contract ERC721Queryable is ERC721Initializable {
    error ERC721Queryable__InvalidQueryRange();

    // @dev Store total number of Tokens.
    uint256 private _totalSupply;

    // @dev The tokenId of the next token to be minted.
    uint256 private _currentIndex;

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        unchecked {
            if (from == address(0)) {
                ++_totalSupply;
                ++_currentIndex;
            } else if (to == address(0)) {
                --_totalSupply;
            }
        }
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function nextTokenId() public view returns (uint256) {
        return _currentIndex;
    }

    /**
     * @dev Returns an array of token IDs owned by `owner`,
     * in the range [`start`, `stop`)
     * (i.e. `start <= tokenId < stop`).
     *
     * This function allows for tokens to be queried if the collection
     * grows too big for a single call of {ERC721Queryable-tokensOfOwner}.
     *
     * Requirements:
     *
     * - `start` < `stop`
     */
    function tokensOfOwnerIn(
        address owner,
        uint256 start,
        uint256 stop
    ) external view returns (uint256[] memory) {
        unchecked {
            if (start >= stop) revert ERC721Queryable__InvalidQueryRange();

            if (stop > _currentIndex) {
                stop = _currentIndex;
            }

            uint256 tokenIdsMaxLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsMaxLength);
            if (tokenIdsMaxLength == 0) {
                return tokenIds;
            }

            // Set `tokenIdsMaxLength = min(balanceOf(owner), stop - start)`,
            // to cater for cases where `balanceOf(owner)` is too big.
            if (stop - start < tokenIdsMaxLength) {
                tokenIdsMaxLength = stop - start;
            }

            uint256 tokenIdsIdx;
            for (uint256 i = start; i != stop && tokenIdsIdx != tokenIdsMaxLength; ++i) {
                if(_owners[i] == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }
            // Downsize the array to fit.
            assembly {
                mstore(tokenIds, tokenIdsIdx)
            }
            return tokenIds;
        }
    }

    /**
     * @dev Returns an array of token IDs owned by `owner`.
     *
     * This function scans the ownership mapping and is O(totalSupply) in complexity.
     * It is meant to be called off-chain.
     *
     * See {ERC721Queryable-tokensOfOwnerIn} for splitting the scan into
     * multiple smaller scans if the collection is large enough to cause
     * an out-of-gas error (10K pfp collections should be fine).
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        unchecked {
            uint256 tokenIdsIdx;
            uint256 tokenIdsLength = balanceOf(owner);
            uint256[] memory tokenIds = new uint256[](tokenIdsLength);

            for (uint256 i = 0; tokenIdsIdx != tokenIdsLength; ++i) {
                if(_owners[i] == owner) {
                    tokenIds[tokenIdsIdx++] = i;
                }
            }

            return tokenIds;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

library ColorUtils {
    function uint2str(uint256 i) internal pure returns (string memory) {
        if (i == 0) {
            return "0";
        }
        uint256 j = i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(i - i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            i /= 10;
        }
        return string(bstr);
    }

    function uint2hex(uint24 i) internal pure returns (string memory) {
        bytes memory o = new bytes(6);
        uint24 mask = 0x00000f; // hex 15
        uint256 k = 6;
        do {
            k--;
            uint8 masked = uint8(i & mask);
            o[k] = bytes1((masked > 9) ? (masked + 87) : (masked + 48)); // ASCII a-f => +87 | 0-9 => +48
            i >>= 4;
        } while (k > 0);

        return string(o);
    }
}

// SPDX-License-Identifier: BSD-3-Clause

import "@openzeppelin/contracts/utils/Strings.sol";

pragma solidity ^0.8.13;

library StringUtils {
    function address2str(address addr) internal pure returns (string memory) {
        return Strings.toHexString(uint160(addr), 20);
    }
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.13;

import "./Shared.sol";

interface IDixelClubV2Factory {
  function beneficiary() external view returns (address);
  function mintingFee() external view returns (uint256);
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.13;

library Shared {
    struct MetaData {
        bool whitelistOnly;
        bool hidden;
        uint24 maxSupply; // can be minted up to MAX_SUPPLY
        uint24 royaltyFriction; // used for `royaltyInfo` (ERC2981) and `seller_fee_basis_points` (Opeansea's Contract-level metadata)
        uint40 mintingBeginsFrom; // Timestamp that minting event begins
        uint152 mintingCost; // Native token (ETH, BNB, KLAY, etc)
    }
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.13;

abstract contract Constants {
    uint256 public constant MAX_SUPPLY = 1000000; // 1M hardcap max
    uint256 public constant MAX_ROYALTY_FRACTION = 1000; // 10%
    uint256 public constant FRICTION_BASE = 10000;

    uint256 internal constant PALETTE_SIZE = 16; // 16 colors max - equal to the data type max value of CANVAS_SIZE (2^8 = 16)
    uint256 internal constant CANVAS_SIZE = 24; // 24x24 pixels
    uint256 internal constant TOTAL_PIXEL_COUNT = CANVAS_SIZE * CANVAS_SIZE; // 24x24
    uint256 internal constant PIXEL_ARRAY_SIZE = TOTAL_PIXEL_COUNT / 2; // packing 2 pixels in each uint8
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.13;

import "base64-sol/base64.sol";
import "./lib/ColorUtils.sol";
import "./Constants.sol";

/**
* @title Dixel SVG image generator
*/
abstract contract SVGGenerator is Constants {

    // Using paths for each palette color (speed: 700-2300 / size: 1-5KB)
    // - pros: faster average speed, smaller svg size (over 50%)
    // - cons: slower worst-case speed


    // NOTE: viewBox -0.5 on top to prevent top side crop issue
    // ref: https://codepen.io/shshaw/post/vector-pixels-svg-optimization-animation-and-understanding-path-data#crazy-pants-optimization-4

    // NOTE: viewbox height 23.999 & preserveAspectRatio="none" to prevent gpas between shapes when it's resized to an indivisible dimensions (e.g. 480x480 -> fine, but 500x500 shows gaps)
    // ref: https://codepen.io/sydneyitguy/pen/MWVgOjG
    string private constant HEADER = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -0.5 24 23.999" width="960" height="960" preserveAspectRatio="none" shape-rendering="crispEdges">';
    string private constant FOOTER = '</svg>';

    function _generateSVG(uint24[PALETTE_SIZE] memory palette, uint8[PIXEL_ARRAY_SIZE] memory pixels) internal pure returns (string memory) {
        string[PALETTE_SIZE] memory paths;

        for (uint256 y; y < CANVAS_SIZE;) {
            uint256 prev = pixels[y * CANVAS_SIZE / 2] & 15; // prev pixel color. see comment below. x=0 so no shifting needed.
            paths[prev] = string(abi.encodePacked(paths[prev], "M0 ", ColorUtils.uint2str(y)));
            uint256 width = 1;

            for (uint256 x = 1; x < CANVAS_SIZE;) {
                /*
                    Pixels array: we're packing 2 pixels into each uint8.
                    So pixels[y * CANVAS_SIZE/2 + x/2] contains pixels (x,y) and (x+1,y).
                    The 4 rightmost bits are (x,y), so to extract that value we mask pixels[y * CANVAS_SIZE/2 + x/2] with 15 ("00001111").
                    The 4 leftmost bits are (x+1,y), so to extract that value we shift pixels[y * CANVAS_SIZE/2 + x/2]
                        4 places to the right, and then mask it with 15 ("00001111").
                 */
                uint256 current = (pixels[y * CANVAS_SIZE/2 + x/2] >> (4*(x%2))) & 15; // current pixel color.

                if (prev == current) {
                    width++;
                } else {
                    paths[prev] = string(abi.encodePacked(paths[prev], "h", ColorUtils.uint2str(width)));
                    width = 1;

                    paths[current] = string(abi.encodePacked(paths[current], "M", ColorUtils.uint2str(x), " ", ColorUtils.uint2str(y)));
                }

                if (x == CANVAS_SIZE - 1) {
                    paths[current] = string(abi.encodePacked(paths[current], "h", ColorUtils.uint2str(width)));
                }

                prev = current;

                unchecked {
                    ++x;
                }
            }
            unchecked {
                ++y;
            }
        }

        string memory joined;
        for (uint256 i; i < PALETTE_SIZE;) {
            if (bytes(paths[i]).length > 0) {
                joined = string(abi.encodePacked(joined, '<path stroke="#', ColorUtils.uint2hex(palette[i]), '" d="', paths[i], '"/>'));
            }
            unchecked {
                ++i;
            }
        }

        return string(abi.encodePacked(HEADER, joined, FOOTER));
    }

    // Using block-stacking approach with color variables (speed: ~1500 / size: ~8.5KB)
    // - pros: constant speed & svg size, faster worst-case speed
    // - cons: slower average speed, bigger svg size

    /* DEPRECATED in favor of the solution above
    string private constant HEADER = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMidYMid meet" viewBox="0 0 24 24" shape-rendering="crispEdges"><style>';
    string private constant FOOTER = '</style><defs><rect id="p" width="40" height="40"/><svg id="r"><use href="#p" fill="var(--a)"/><use href="#p" x="1" fill="var(--b)"/><use href="#p" x="2" fill="var(--c)"/><use href="#p" x="3" fill="var(--d)"/><use href="#p" x="4" fill="var(--e)"/><use href="#p" x="5" fill="var(--f)"/><use href="#p" x="6" fill="var(--g)"/><use href="#p" x="7" fill="var(--h)"/><use href="#p" x="8" fill="var(--i)"/><use href="#p" x="9" fill="var(--j)"/><use href="#p" x="10" fill="var(--k)"/><use href="#p" x="11" fill="var(--l)"/><use href="#p" x="12" fill="var(--m)"/><use href="#p" x="13" fill="var(--n)"/><use href="#p" x="14" fill="var(--o)"/><use href="#p" x="15" fill="var(--p)"/><use href="#p" x="16" fill="var(--q)"/><use href="#p" x="17" fill="var(--r)"/><use href="#p" x="18" fill="var(--s)"/><use href="#p" x="19" fill="var(--t)"/><use href="#p" x="20" fill="var(--u)"/><use href="#p" x="21" fill="var(--v)"/><use href="#p" x="22" fill="var(--w)"/><use href="#p" x="23" fill="var(--x)"/></svg></defs><use href="#r" class="a"/><use href="#r" y="1" class="b"/><use href="#r" y="2" class="c"/><use href="#r" y="3" class="d"/><use href="#r" y="4" class="e"/><use href="#r" y="5" class="f"/><use href="#r" y="6" class="g"/><use href="#r" y="7" class="h"/><use href="#r" y="8" class="i"/><use href="#r" y="9" class="j"/><use href="#r" y="10" class="k"/><use href="#r" y="11" class="l"/><use href="#r" y="12" class="m"/><use href="#r" y="13" class="n"/><use href="#r" y="14" class="o"/><use href="#r" y="15" class="p"/><use href="#r" y="16" class="q"/><use href="#r" y="17" class="r"/><use href="#r" y="18" class="s"/><use href="#r" y="19" class="t"/><use href="#r" y="20" class="u"/><use href="#r" y="21" class="v"/><use href="#r" y="22" class="w"/><use href="#r" y="23" class="x"/></svg>';
    bytes32 private constant CLASS = 'abcdefghijklmnopqrstuvwx'; // class names for each row, pixel (length must be equal to CANVAS_SIZE)

    function _generateSVG(uint24[PALETTE_SIZE] memory palette, uint8[TOTAL_PIXEL_COUNT] memory pixels) internal pure returns (string memory) {
        string memory joined;
        string[CANVAS_SIZE] memory styles;

        for (uint256 x = 0; x < CANVAS_SIZE; x++) {
            styles[x] = string(abi.encodePacked(styles[x], '.', CLASS[x], '{'));

            for (uint256 y = 0; y < CANVAS_SIZE; y++) {
                styles[x] = string(abi.encodePacked(styles[x], '--', CLASS[y], ':#', ColorUtils.uint2hex(palette[pixels[x * CANVAS_SIZE + y]]), ';'));
            }

            styles[x] = string(abi.encodePacked(styles[x], '}'));
            joined = string(abi.encodePacked(joined, styles[x]));
        }

        return string(abi.encodePacked(HEADER, joined, FOOTER));
    }
    */

    function _generateBase64SVG(uint24[PALETTE_SIZE] memory palette, uint8[PIXEL_ARRAY_SIZE] memory pixels) internal pure returns (string memory) {
        return string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(_generateSVG(palette, pixels)))));
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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
        return functionCall(target, data, "Address: low-level call failed");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
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