// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./thirdparty/erc1167/CloneFactory.sol";

import "./L2MintableERC1155.sol";

contract L2MintableERC1155Factory is CloneFactory {
    event InstanceCreatedEvent(L2MintableERC1155 instance);

    address immutable implementation;
    L2MintableERC1155[] public instances;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function create(
        address owner,
        address authorization,
        string memory name
    ) external {
        L2MintableERC1155 instance = L2MintableERC1155(
            createClone(implementation)
        );
        instance.init(owner, authorization, name);
        instances.push(instance);
        InstanceCreatedEvent(instance);
    }

    function getInstances() external view returns (L2MintableERC1155[] memory) {
        return instances;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/*
The MIT License (MIT)
Copyright (c) 2018 Murray Software, LLC.
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:
The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

// See: https://eips.ethereum.org/EIPS/eip-1167
// See: https://github.com/optionality/clone-factory/blob/master/contracts/CloneFactory.sol

contract CloneFactory {
    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(
                add(clone, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            result := create(0, clone, 0x37)
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./lib/AddressSet.sol";
import "./lib/Claimable.sol";
import "./lib/Ownable.sol";

import "./thirdparty/erc165/ERC165.sol";
import "./thirdparty/erc165/IERC165.sol";

import "./thirdparty/erc1155/Context.sol";
import "./thirdparty/erc1155/ERC1155.sol";
import "./thirdparty/erc1155/IERC1155.sol";
import "./thirdparty/erc1155/IERC1155MetadataURI.sol";
import "./thirdparty/erc1155/IERC1155Receiver.sol";
import "./thirdparty/erc1155/SafeMath.sol";

import "./MintAuthorization.sol";

contract L2MintableERC1155 is ERC1155, Claimable {
    event MintFromL2(address owner, uint256 id, uint256 amount, address minter);

    string public name;

    // Authorization for which addresses can mint tokens and add collections is
    // delegated to another contract.
    // TODO: (Loopring feedback) Make this field immutable when contract is upgradable
    MintAuthorization private authorization;

    // The IPFS hash for each collection (these hashes represent a directory within
    // IPFS that contain one JSON file per edition in the collection).
    mapping(uint64 => string) private _ipfsHashes;

    modifier onlyFromLayer2() {
        require(_msgSender() == authorization.layer2(), "UNAUTHORIZED");
        _;
    }

    modifier onlyMinter(address addr) {
        require(
            authorization.isActiveMinter(addr) ||
                authorization.isRetiredMinter(addr),
            "NOT_MINTER"
        );
        _;
    }

    modifier onlyFromUpdater() {
        require(authorization.isUpdater(msg.sender), "NOT_FROM_UPDATER");
        _;
    }

    // Prevent initialization of the implementation deployment.
    // (L2MintableERC1155Factory should be used to create usable instances.)
    constructor() {
        owner = 0x000000000000000000000000000000000000dEaD;
    }

    // An init method is used instead of a constructor to allow use of the proxy
    // factory pattern. The init method can only be called once and should be
    // called within the factory.
    function init(
        address _owner,
        address _authorization,
        string memory _name
    ) public {
        require(owner == address(0), "ALREADY_INITIALIZED");
        require(_owner != address(0), "OWNER_REQUIRED");

        _registerInterface(_INTERFACE_ID_ERC1155);
        _registerInterface(_INTERFACE_ID_ERC1155_METADATA_URI);
        _registerInterface(_INTERFACE_ID_ERC165);

        owner = _owner;
        name = _name;
        authorization = MintAuthorization(_authorization);
    }

    // This function is called when an NFT minted on L2 is withdrawn from Loopring.
    // That means the NFTs were burned on L2 and now need to be minted on L1.
    // This function can only be called by the Loopring exchange.
    function mintFromL2(
        address to,
        uint256 tokenId,
        uint256 amount,
        address minter,
        bytes calldata data
    ) external onlyFromLayer2 onlyMinter(minter) {
        _mint(to, tokenId, amount, data);
        emit MintFromL2(to, tokenId, amount, minter);
    }

    // Allow only the owner to mint directly on L1
    // TODO: (Loopring feedback) Can be removed once contract is upgrabable
    function mint(
        address tokenId,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner {
        _mint(tokenId, id, amount, data);
    }

    // All address that are currently authorized to mint NFTs on L2.
    function minters() public view returns (address[] memory) {
        return authorization.activeMinters();
    }

    // Delegate authorization to a different contract (can be called by an owner to
    // "eject" from the GameStop ecosystem).
    // TODO: (Loopring feedback) Should be removed once contract is upgrabable
    function setAuthorization(address _authorization) external onlyOwner {
        authorization = MintAuthorization(_authorization);
    }

    function uri(uint256 id) external view override returns (string memory) {
        // The layout of an ID is: 64 bit creator ID, 64 bits of flags, 64 bit
        // collection ID then 64 bit edition ID:
        uint64 collectionId = uint64(
            (id &
                0x00000000000000000000000000000000FFFFFFFFFFFFFFFF0000000000000000) >>
                64
        );
        uint64 editionId = uint64(
            id &
                0x000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFF
        );

        string memory ipfsHash = _ipfsHashes[collectionId];
        require(bytes(ipfsHash).length != 0, "NO_IPFS_BASE");

        return
            _appendStrings(
                "ipfs://",
                ipfsHash,
                "/",
                _uintToString(editionId),
                ".json"
            );
    }

    function setIpfsHash(uint64 collectionId, string memory ipfsHash)
        external
        onlyFromUpdater
    {
        string memory existingIpfsHash = _ipfsHashes[collectionId];
        require(bytes(existingIpfsHash).length == 0, "IPFS_ALREADY_SET");
        _ipfsHashes[collectionId] = ipfsHash;
    }

    function getIpfsHash(uint64 collectionId)
        external
        view
        returns (string memory)
    {
        return _ipfsHashes[collectionId];
    }

    function _appendStrings(
        string memory a,
        string memory b,
        string memory c,
        string memory d,
        string memory e
    ) private pure returns (string memory) {
        return string(abi.encodePacked(a, b, c, d, e));
    }

    // TODO: (Loopring feedback) Is there a library that implements this?
    function _uintToString(uint256 input)
        private
        pure
        returns (string memory _uintAsString)
    {
        if (input == 0) {
            return "0";
        }

        uint256 i = input;
        uint256 length = 0;
        while (i != 0) {
            length++;
            i /= 10;
        }

        bytes memory result = new bytes(length);
        i = length;
        while (input != 0) {
            i--;
            uint8 character = (48 + uint8(input - (input / 10) * 10));
            result[i] = bytes1(character);
            input /= 10;
        }
        return string(result);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

contract AddressSet {
    struct Set {
        address[] addresses;
        mapping(address => uint256) positions;
        uint256 count;
    }
    mapping(bytes32 => Set) private sets;

    function addAddressToSet(
        bytes32 key,
        address addr,
        bool maintainList
    ) internal {
        Set storage set = sets[key];
        require(set.positions[addr] == 0, "ALREADY_IN_SET");

        if (maintainList) {
            require(
                set.addresses.length == set.count,
                "PREVIOUSLY_NOT_MAINTAILED"
            );
            set.addresses.push(addr);
        } else {
            require(set.addresses.length == 0, "MUST_MAINTAIN");
        }

        set.count += 1;
        set.positions[addr] = set.count;
    }

    function removeAddressFromSet(bytes32 key, address addr) internal {
        Set storage set = sets[key];
        uint256 pos = set.positions[addr];
        require(pos != 0, "NOT_IN_SET");

        delete set.positions[addr];
        set.count -= 1;

        if (set.addresses.length > 0) {
            address lastAddr = set.addresses[set.count];
            if (lastAddr != addr) {
                set.addresses[pos - 1] = lastAddr;
                set.positions[lastAddr] = pos;
            }
            set.addresses.pop();
        }
    }

    function isAddressInSet(bytes32 key, address addr)
        internal
        view
        returns (bool)
    {
        return sets[key].positions[addr] != 0;
    }

    function numAddressesInSet(bytes32 key) internal view returns (uint256) {
        Set storage set = sets[key];
        return set.count;
    }

    function addressesInSet(bytes32 key)
        internal
        view
        returns (address[] memory)
    {
        Set storage set = sets[key];
        require(set.count == set.addresses.length, "NOT_MAINTAINED");
        return sets[key].addresses;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./Ownable.sol";

// Extension for the Ownable contract, where the ownership needs
// to be claimed. This allows the new owner to accept the transfer.
contract Claimable is Ownable {
    address public pendingOwner;

    modifier onlyPendingOwner() {
        require(msg.sender == pendingOwner, "UNAUTHORIZED");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0) && newOwner != owner, "INVALID_ADDRESS");
        pendingOwner = newOwner;
    }

    function claimOwnership() public onlyPendingOwner {
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

// The Ownable contract has an owner address, and provides basic
// authorization control functions, this simplifies the implementation of
// "user permissions". Subclasses are responsible for initializing the
// `owner` property (it is not done in a constructor to faciliate use of
// a factory proxy pattern).
contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "UNAUTHORIZED");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./IERC165.sol";

// Implementation of the {IERC165} interface.
// Contracts may inherit from this and call {_registerInterface} to declare
// their support of an interface.  Derived contracts must call
// _registerInterface(_INTERFACE_ID_ERC165).
abstract contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 internal constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    mapping(bytes4 => bool) private _supportedInterfaces;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return _supportedInterfaces[interfaceId];
    }

    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "../erc165/ERC165.sol";
import "./Address.sol";
import "./Context.sol";
import "./IERC1155.sol";
import "./IERC1155MetadataURI.sol";
import "./IERC1155Receiver.sol";
import "./SafeMath.sol";

// Implementation of the basic standard multi-token.
// See https://eips.ethereum.org/EIPS/eip-1155
// Originally based on code by Enjin: https://github.com/enjin/erc-1155
abstract contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using SafeMath for uint256;
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /*
     *     bytes4(keccak256('balanceOf(address,uint256)')) == 0x00fdd58e
     *     bytes4(keccak256('balanceOfBatch(address[],uint256[])')) == 0x4e1273f4
     *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
     *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
     *     bytes4(keccak256('safeTransferFrom(address,address,uint256,uint256,bytes)')) == 0xf242432a
     *     bytes4(keccak256('safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)')) == 0x2eb2c2d6
     *
     *     => 0x00fdd58e ^ 0x4e1273f4 ^ 0xa22cb465 ^
     *        0xe985e9c5 ^ 0xf242432a ^ 0x2eb2c2d6 == 0xd9b67a26
     */
    bytes4 internal constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;

    /*
     *     bytes4(keccak256('uri(uint256)')) == 0x0e89341c
     */
    bytes4 internal constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;

    function balanceOf(address account, uint256 id)
        public
        view
        override
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            require(
                accounts[i] != address(0),
                "ERC1155: batch balance query for the zero address"
            );
            batchBalances[i] = _balances[ids[i]][accounts[i]];
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        require(
            _msgSender() != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address account, address operator)
        public
        view
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        address operator = _msgSender();

        _balances[id][from] = _balances[id][from].sub(
            amount,
            "ERC1155: insufficient balance for transfer"
        );
        _balances[id][to] = _balances[id][to].add(amount);

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );

        address operator = _msgSender();

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            _balances[id][from] = _balances[id][from].sub(
                amount,
                "ERC1155: insufficient balance for transfer"
            );
            _balances[id][to] = _balances[id][to].add(amount);
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _balances[id][account] = _balances[id][account].add(amount);
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            account,
            id,
            amount,
            data
        );
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver(to).onERC1155Received.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response !=
                    IERC1155Receiver(to).onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "../erc165/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "../erc165/ERC165.sol";

/**
 * _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./lib/OwnerManagable.sol";

contract MintAuthorization is OwnerManagable {
    address public immutable layer2;

    constructor(
        address _owner,
        address _layer2,
        address[] memory _initialMinters,
        address[] memory _initialUpdaters
    ) {
        // Initially allow the deploying account to add minters/updaters
        owner = msg.sender;

        layer2 = _layer2;

        for (uint256 i = 0; i < _initialMinters.length; i++) {
            addActiveMinter(_initialMinters[i]);
        }

        for (uint256 i = 0; i < _initialUpdaters.length; i++) {
            addUpdater(_initialUpdaters[i]);
        }

        // From now on, only the specified owner can add/remove minters/updaters
        owner = _owner;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.0;

import "./AddressSet.sol";
import "./Claimable.sol";

contract OwnerManagable is Claimable, AddressSet {
    bytes32 internal constant MINTER = keccak256("__MINTERS__");
    bytes32 internal constant RETIREDMINTER = keccak256("__RETIREDMINTERS__");
    bytes32 internal constant UPDATER = keccak256("__UPDATER__");

    event MinterAdded(address indexed minter);
    event MinterRetired(address indexed minter);
    event UpdaterAdded(address indexed updater);
    event UpdaterRemoved(address indexed updater);

    // All address that are currently authorized to mint NFTs on L2.
    function activeMinters() public view returns (address[] memory) {
        return addressesInSet(MINTER);
    }

    // All address that were previously authorized to mint NFTs on L2.
    function retiredMinters() public view returns (address[] memory) {
        return addressesInSet(RETIREDMINTER);
    }

    // All address that are authorized to add new collections.
    function updaters() public view returns (address[] memory) {
        return addressesInSet(UPDATER);
    }

    function numActiveMinters() public view returns (uint256) {
        return numAddressesInSet(MINTER);
    }

    function numRetiredMinters() public view returns (uint256) {
        return numAddressesInSet(RETIREDMINTER);
    }

    function numUpdaters() public view returns (uint256) {
        return numAddressesInSet(UPDATER);
    }

    function isActiveMinter(address addr) public view returns (bool) {
        return isAddressInSet(MINTER, addr);
    }

    function isRetiredMinter(address addr) public view returns (bool) {
        return isAddressInSet(RETIREDMINTER, addr);
    }

    function isUpdater(address addr) public view returns (bool) {
        return isAddressInSet(UPDATER, addr);
    }

    function addActiveMinter(address minter) public virtual onlyOwner {
        addAddressToSet(MINTER, minter, true);
        if (isRetiredMinter(minter)) {
            removeAddressFromSet(RETIREDMINTER, minter);
        }
        emit MinterAdded(minter);
    }

    function addUpdater(address updater) public virtual onlyOwner {
        addAddressToSet(UPDATER, updater, true);
        emit UpdaterAdded(updater);
    }

    function removeUpdater(address updater) public virtual onlyOwner {
        removeAddressFromSet(UPDATER, updater);
        emit UpdaterRemoved(updater);
    }

    function retireMinter(address minter) public virtual onlyOwner {
        removeAddressFromSet(MINTER, minter);
        addAddressToSet(RETIREDMINTER, minter, true);
        emit MinterRetired(minter);
    }
}