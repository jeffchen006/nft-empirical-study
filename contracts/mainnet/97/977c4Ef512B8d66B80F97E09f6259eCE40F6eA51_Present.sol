// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./WriteSVG.sol";

//__/\\\________/\\\__/\\\\\\\\\\\\\____/\\\\\\\\\\\\___________________/\\\\\\\\\\\________/\\\\\\\\\__/\\\________/\\\_
//__\/\\\_______\/\\\_\/\\\/////////\\\_\/\\\////////\\\________________\/////\\\///______/\\\////////__\/\\\_____/\\\//__
//___\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\______\//\\\___________________\/\\\_______/\\\/___________\/\\\__/\\\//_____
//____\/\\\\\\\\\\\\\\\_\/\\\\\\\\\\\\\\__\/\\\_______\/\\\___________________\/\\\______/\\\_____________\/\\\\\\//\\\_____
//_____\/\\\/////////\\\_\/\\\/////////\\\_\/\\\_______\/\\\___________________\/\\\_____\/\\\_____________\/\\\//_\//\\\____
//______\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\_______\/\\\___________________\/\\\_____\//\\\____________\/\\\____\//\\\___
//_______\/\\\_______\/\\\_\/\\\_______\/\\\_\/\\\_______/\\\_____________/\\\___\/\\\______\///\\\__________\/\\\_____\//\\\__
//________\/\\\_______\/\\\_\/\\\\\\\\\\\\\/__\/\\\\\\\\\\\\/_____________\//\\\\\\\\\_________\////\\\\\\\\\_\/\\\______\//\\\_
//_________\///________\///__\/////////////____\////////////________________\/////////_____________\/////////__\///________\///__

contract Present is ERC721, WriteSVG {
    string signatures = "";
    uint256 SIGN_OFFSET_Y = 70;
    uint256 CARD_HEIGHT = 102;
    mapping(address => bool) signed;

    constructor() ERC721("HBD JCK", "HBD") {
        // HBD JCK
        _safeMint(0xD1295FcBAf56BF1a6DFF3e1DF7e437f987f6feCa, 34);
    }

    /// @notice Say happy birthday to Jack!
    function signCard(string memory name) public returns (bool) {
        bytes memory byteName = bytes(name);
        require(!signed[msg.sender], "You can only sign once");
        require(!(byteName.length <= 0), "No signature");
        require(!(byteName.length >= 10), "Signature must be 10 or less characters");
        require(block.timestamp <= 1660453200, "Jacks birthday is over");
        require(!hasSpace(name), "Signatures must be without spaces");

        signatures = string(abi.encodePacked(signatures,signSVG(name)));
        signed[msg.sender] = true;
        return true;
    }

    /// @dev There can ever only be one token. HBD JCK.
    function totalSupply() public pure returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(tokenId == 34, "This isn't Jacks birthday");

        string memory present = string(abi.encodePacked("<svg viewBox='0 0 100 ",Strings.toString(CARD_HEIGHT),"' width='500' xmlns='http://www.w3.org/2000/svg'><rect x='0' y='0' width='100%' height='100%' fill='#000'/><g transform='scale(1) translate(44.5, 40)' fill='#fff' fill-rule='evenodd' clip-rule='evenodd' aria-label='HBD'><g transform='translate(0)'><path d='M0 0H1L1 2H2V0H3V2V3V5H2V3H1V5H0V0Z'/></g><g transform='translate(4)'><path d='M1 0H0V5H1H2H3V3H2V2H3V0H2H1ZM2 2H1V1H2V2ZM2 4V3H1V4H2Z'/></g><g transform='translate(8)'><path d='M0 1V4V5H1H2H3V1H2V0H1H0V1ZM2 4V1L1 1V4H2Z'/></g></g><g transform='scale(1) translate(42, 50)' fill='#fff' fill-rule='evenodd' clip-rule='evenodd' aria-label='JACK'><g transform='translate(0)'><g transform='translate(0)'><path d='M0 0H2H3V1V4V5H2H1H0V4V3H1V4H2V1L0 1V0Z'/></g><g transform='translate(4)'><path d='M0 3V5H1V3L2 3V5H3V3V2V1V0H2H1H0V1V2V3ZM1 2H2V1H1V2Z'/></g><g transform='translate(8)'><path d='M0 0H1H3V1L1 1V4H3V5H1H0V4V1V0Z'/></g><g transform='translate(12)'><path d='M1 0H0V2V3V5H1V3H2V5H3L3 3H2V2H3L3 0H2L2 2H1V0Z'/></g><g transform='translate(16)'><path d='M0 3H1L1 0H0V3ZM0 5H1L1 4H0V5Z'/></g></g></g><rect x='41' y='64' width='19' height='1' fill='#F9F9F9'/>"));
        present = string(abi.encodePacked(present,signatures,"</svg>"));
        present = string(abi.encodePacked("data:image/svg+xml;base64,",Base64.encode(bytes(present))));

        bytes memory dataURI = abi.encodePacked(
            '{',
                '"name": "HBD JCK",',
                '"description": "Happy Birthday Jack - VV",',
                '"image": "', present, '"'
            '}'
        );

        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(dataURI)
            )
        );
    }

    function signSVG(string memory name) private returns (string memory) {
        SIGN_OFFSET_Y += 5;
        CARD_HEIGHT += 5;
        return write(name,"#999",1,SIGN_OFFSET_Y*2);
    }

    function hasSpace(string memory name) pure internal returns (bool) {
        for(uint256 i = 0; i < bytes(name).length; i++) {
            bytes memory firstCharByte = new bytes(1);
			firstCharByte[0] = bytes(name)[i];
			uint8 decimal = uint8(firstCharByte[0]);
			if(decimal == 32) {
                return true;
            }
        }

        return false;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/ERC721.sol)

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
     * by default, can be overriden in child contracts.
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
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
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
        address owner = ERC721.ownerOf(tokenId);

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
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
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
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
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
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Strings.sol";

contract WriteSVG {
    mapping(string => string) private LETTERS;
    mapping(string => uint256) private LETTER_WIDTHS;

    constructor() {
		LETTERS["0"] = "<path d='M1 1H2L2 4H1L1 1ZM1 1H0V4H1L1 5H2L2 4H3L3 1H2L2 0H1L1 1Z'/>";
		LETTERS["1"] = "<path d='M0 0V1H1V5H2V1V0H1H0Z'/>";
		LETTERS["2"] = "<path d='M2 1H0V0H3L3 1L3 3L2 3L1 3L1 4H3L3 5H0V4V3V2L2 2L2 1Z'/>";
		LETTERS["3"] = "<path d='M3 1L3 0H2H0V1L2 1V2L0 2V3L2 3V4H0V5H2H3L3 4L3 3L3 2V1Z'/>";
		LETTERS["4"] = "<path d='M3 5H2L2 3H1L0 3V2V0H1L1 2L2 2L2 0H3L3 2L3 3V5Z'/>";
		LETTERS["5"] = "<path d='M0 0H1H3V1H1V2H2V3H1H0V0ZM2 3H3V4V5H0V4H2V3Z'/>";
		LETTERS["6"] = "<path d='M0 4V3V2V0H0.999999L1 2H2L3 2L3 3L3 4L3 5H2H1H0V4ZM2 4V3L1 3L1 4H2Z'/>";
		LETTERS["7"] = "<path d='M3 1L3 0H2H0V1L2 1L2 5H3V1Z'/>";
		LETTERS["8"] = "<path d='M2 1L1 1L1 2L2 2V1ZM2 0H3L3 1L3 2L3 3L3 4L3 5H2H1H0V4V3V2V1V0H1H2ZM2 4V3L1 3L1 4H2Z'/>";
		LETTERS["9"] = "<path d='M1 1L2 1V2L1 2L1 1ZM1 0H2H3L3 1L3 2L3 3V5H2L2 3H1L0 3V2V1V0H1Z'/>";

		LETTERS["A"] = "<path d='M0 3V5H1V3L2 3V5H3V3V2V1V0H2H1H0V1V2V3ZM1 2H2V1H1V2Z'/>";
		LETTERS["B"] = "<path d='M1 0H0V5H1H2H3V3H2V2H3V0H2H1ZM2 2H1V1H2V2ZM2 4V3H1V4H2Z'/>";
		LETTERS["C"] = "<path d='M0 0H1H3V1L1 1V4H3V5H1H0V4V1V0Z'/>";
		LETTERS["D"] = "<path d='M0 1V4V5H1H2H3V1H2V0H1H0V1ZM2 4V1L1 1V4H2Z'/>";
		LETTERS["E"] = "<path d='M1 0H0V1V4V5H1H3V4H1V3H2V2H1L1 1L3 1V0H1Z'/>";
		LETTERS["F"] = "<path d='M0 0H1H3V1L1 1V2H2V3H1V5H0V3V2V1V0Z'/>";
		LETTERS["G"] = "<path d='M0 1V4V5H1H2H3V4V2H2V4H1V1L3 1V0H1H0V1Z'/>";
		LETTERS["H"] = "<path d='M0 0H1L1 2H2V0H3V2V3V5H2V3H1V5H0V0Z'/>";
		LETTERS["I"] = "<path d='M0 1V0H1H2H3V1L2 1V4H3V5H2H1H0V4H1V1L0 1Z'/>";
		LETTERS["J"] = "<path d='M0 0H2H3V1V4V5H2H1H0V4V3H1V4H2V1L0 1V0Z'/>";
		LETTERS["K"] = "<path d='M1 0H0V2V3V5H1V3H2V5H3L3 3H2V2H3L3 0H2L2 2H1V0Z'/>";
		LETTERS["L"] = "<path d='M1 0H0V4V5H1H3V4H1V0Z'/>";
		LETTERS["M"] = "<path d='M1 5H0V0H1L1 1L2 1V2L1 2L1 5ZM3 2V3H2L2 2L3 2ZM3 2L3 1L4 1L4 0H5L5 5H4V2H3Z'/>";
		LETTERS["N"] = "<path d='M0 0H1V5H0V0Z M1 1H2V3H1V1Z M2 2H3V4H2V2Z M3 0H4V5H3V0Z'/>";
		LETTERS["O"] = "<path d='M0 5H1H2H3L3 0H2H1H0V5ZM2 4L2 1L1 1L1 4H2Z'/>";
		LETTERS["P"] = "<path d='M0 5H1L1 3L3 3L3 2L3 1L3 0H1H0V5ZM2 1L1 1L1 2L2 2L2 1Z'/>";
		LETTERS["Q"] = "<path d='M0 5H1H2L2 4H3L3 0H2H1H0V5ZM1 4L1 1L2 1L2 4H1Z'/>";
		LETTERS["R"] = "<path d='M1 5H0V0H1H3L3 1V2L2 2L2 1L1 1V2L2 2L2 3H1V5ZM2 3H3L3 5H2L2 3Z'/>";
		LETTERS["S"] = "<path d='M1 3H0V0H1H3L3 1L1 1L1 2L2 2H3L3 3L3 4V5H2H0V4L2 4L2 3L1 3Z'/>";
		LETTERS["T"] = "<path d='M3 1L3 0H2H1H0V1L1 1L1 5H2L2 1L3 1Z'/>";
		LETTERS["U"] = "<path d='M1 5H0V4V0H1L1 4L2 4L2 0H3L3 4V5H2H1Z'/>";
		LETTERS["V"] = "<path d='M1 4H0V0H1L1 4ZM2 4H1V5H2L2 4ZM2 4L2 0H3L3 4H2Z'/>";
		LETTERS["W"] = "<path d='M4 0L5 0L5 5H4L4 4H3V3H4V0Z M2 3L2 2H3L3 3L2 3Z M2 3L2 4L1 4L1 5H0L0 0L1 0L1 3H2Z'/>";
		LETTERS["X"] = "<path d='M1 2H0V0H1L1 2ZM2 2H1L1 3H0V5H1L1 3H2L2 5H3L3 3H2L2 2ZM2 2L2 0H3L3 2H2Z'/>";
		LETTERS["Y"] = "<path d='M1 3H0V0H1L1 3ZM2 3H1V5H2L2 3ZM2 3L2 0H3L3 3H2Z'/>";
		LETTERS["Z"] = "<path d='M2 1H0V0H3L3 1L3 2L2 2L2 1ZM1 3L1 2L2 2L2 3H1ZM1 3L1 4H3L3 5H0V4V3L1 3Z'/>";
		LETTERS["a"] = LETTERS["A"];
		LETTERS["b"] = LETTERS["B"];
		LETTERS["c"] = LETTERS["C"];
		LETTERS["d"] = LETTERS["D"];
		LETTERS["e"] = LETTERS["E"];
		LETTERS["f"] = LETTERS["F"];
		LETTERS["g"] = LETTERS["G"];
		LETTERS["h"] = LETTERS["H"];
		LETTERS["i"] = LETTERS["I"];
		LETTERS["j"] = LETTERS["J"];
		LETTERS["k"] = LETTERS["K"];
		LETTERS["l"] = LETTERS["L"];
		LETTERS["m"] = LETTERS["M"];
		LETTERS["n"] = LETTERS["N"];
		LETTERS["o"] = LETTERS["O"];
		LETTERS["p"] = LETTERS["P"];
		LETTERS["q"] = LETTERS["Q"];
		LETTERS["r"] = LETTERS["R"];
		LETTERS["s"] = LETTERS["S"];
		LETTERS["t"] = LETTERS["T"];
		LETTERS["u"] = LETTERS["U"];
		LETTERS["v"] = LETTERS["V"];
		LETTERS["w"] = LETTERS["W"];
		LETTERS["x"] = LETTERS["X"];
		LETTERS["y"] = LETTERS["Y"];
		LETTERS["z"] = LETTERS["Z"];

		LETTERS["*"] = "<path d='M0 2V1H1L1 2L0 2ZM2 2L1 2V3H0V4L1 4V3L2 3V4L3 4V3L2 3V2ZM2 2L3 2V1H2V2Z'/>";
		LETTERS["="] = "<path d='M0 1V2L3 2V1H0ZM0 3V4L3 4V3L0 3Z'/>";
		LETTERS["<"] = "<path d='M1 4L0 4L0 5L1 5L1 4ZM2 3L2 4L1 4L1 3L2 3ZM2 2L2 3L3 3L3 2L2 2ZM1 1L1 2L2 2L2 1L1 1ZM1 1L1 0L0 0L0 1L1 1Z'/>";
		LETTERS[">"] = "<path d='M2 1H3L3 0H2V1ZM1 2L1 1H2V2H1ZM1 3L1 2H0V3H1ZM2 4L2 3H1L1 4H2ZM2 4V5H3L3 4H2Z'/>";
		LETTERS[","] = "<path transform='translate(0, 1)' d='M1 4H2L2 3H1L1 4ZM1 4H0V5H1L1 4Z'/>";
		LETTERS["."] = "<rect x='1' y='5' width='1' height='1' transform='rotate(180 1 5)'/>";
		LETTERS[":"] = "<path d='M0 1V2L1 2L1 1H0ZM0 3V4L1 4L1 3H0Z'/>";
		LETTERS[";"] = "<path d='M1 2L1 1H2V2L1 2ZM1 5L1 3H2V5L1 5ZM1 5V6H0V5H1Z'/>";
		LETTERS["!"] = "<path d='M0 3H1L1 0H0V3ZM0 5H1L1 4H0V5Z'/>";
		LETTERS["?"] = "<path d='M2 0H0V1H2V2H1V3H2V2H3V0H2ZM2 4H1V5H2V4Z'/>";
		LETTERS["+"] = "<path d='M2 1H1L1 2L0 2V3L1 3L1 4L2 4L2 3L3 3V2L2 2L2 1Z'/>";
		LETTERS["-"] = "<path d='M0 3L0 2L3 2V3L0 3Z'/>";
		LETTERS["$"] = "<path transform='translate(0, -1)' d='M1 1L1 0H2L2 1H3L3 2L1 2L1 3L2 3H3L3 4L3 5V6H2L2 7H1L1 6H0V5L2 5L2 4L1 4H0V1L1 1Z'/>";
		LETTERS["#"] = "<path d='M1 5H2L2 4H3V5H4V4H5V3H4V2H5V1H4V0H3V1H2L2 0H1L1 1H0V2H1L1 3H0V4H1L1 5ZM3 2H2L2 3H3V2Z'/>";
		LETTERS[" "] = "";

		LETTER_WIDTHS["DEFAULT"] = 3;
		LETTER_WIDTHS[" "] = 1;
		LETTER_WIDTHS["."] = 1;
		LETTER_WIDTHS[":"] = 1;
		LETTER_WIDTHS["!"] = 1;
		LETTER_WIDTHS[","] = 2;
		LETTER_WIDTHS[";"] = 2;
		LETTER_WIDTHS["N"] = 4;
		LETTER_WIDTHS["n"] = 4;
		LETTER_WIDTHS["#"] = 5;
		LETTER_WIDTHS["M"] = 5;
		LETTER_WIDTHS["m"] = 5;
		LETTER_WIDTHS["W"] = 5;
		LETTER_WIDTHS["w"] = 5;
    }

	function upperCase(string memory text, uint256 i) internal pure returns (string memory) {
		bytes memory firstCharByte = new bytes(1);
		firstCharByte[0] = bytes(text)[i];
		return 	string(firstCharByte);
	}

    function write(string memory text, string memory color, uint256 spacing, uint256 y) view public returns (string memory) {
		uint256 letterPos = 0;
		string memory letters = "";

		for (uint256 i = 0; i < bytes(text).length; i++) {
			string memory normalized = upperCase(text, i);
			string memory path = LETTERS[normalized];
			uint256 width = LETTER_WIDTHS[normalized] != 0
				? LETTER_WIDTHS[normalized]
				: LETTER_WIDTHS["DEFAULT"];

			if (bytes(path).length <= 0) continue;
			
			letters = string(abi.encodePacked(letters,"<g transform='translate(",Strings.toString(letterPos),")'>",path,"</g>"));
			letterPos = letterPos + width + spacing;
		}
		
		uint256 cx = (100 - (letterPos/2));
		string memory svg = string(abi.encodePacked("<g  transform='scale(0.5) translate(",Strings.toString(cx),",", Strings.toString(y),")' fill='",color,"' fill-rule='evenodd' clip-rule='evenodd' aria-label='",text,"'>",letters,"</g>"));
		return svg;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
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