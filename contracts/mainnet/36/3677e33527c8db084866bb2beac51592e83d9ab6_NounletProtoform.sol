// SPDX-License-Identifier: GPL-3.0

/// @title Interface for SVGRenderer

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.6;

interface ISVGRenderer {
    struct Part {
        bytes image;
        bytes palette;
    }

    struct SVGParams {
        Part[] parts;
        string background;
    }

    function generateSVG(SVGParams memory params) external view returns (string memory svg);

    function generateSVGPart(Part memory part) external view returns (string memory partialSVG);

    function generateSVGParts(Part[] memory parts) external view returns (string memory partialSVG);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnerUpdated(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnerUpdated(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function setOwner(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {MerkleBase} from "./utils/MerkleBase.sol";
import {INounletAuction as IAuction, IModule} from "./interfaces/INounletAuction.sol";
import {INounletProtoform as IProtoform} from "./interfaces/INounletProtoform.sol";
import {INounletRegistry as IRegistry} from "./interfaces/INounletRegistry.sol";
import {INounsToken as INouns} from "./interfaces/INounsToken.sol";
import {Owned} from "@rari-capital/solmate/src/auth/Owned.sol";

/// @title NounletProtoform
/// @author Tessera
/// @notice Protoform contract for deploying new vaults with a fixed supply, nouns style auction, and buyout mechanism
contract NounletProtoform is IProtoform, MerkleBase, Owned {
    /// @notice Address of NounletAuction module contract
    address public immutable auction;
    /// @notice Address of NounletRegistry contract
    address public immutable registry;

    /// @dev Initializes NounletRegistry and NounletAuction contracts
    constructor(address _registry, address _auction) Owned(msg.sender) {
        registry = _registry;
        auction = _auction;
    }

    /// @notice Deploys a new vault with given permissions and plugins
    /// @param _modules Address of the module contracts
    /// @param _plugins Addresses of plugin contracts
    /// @param _selectors List of function selectors
    /// @param _mintProof Merkle proof for minting fractions
    /// @param _descriptor Address of the NounsDescriptor contract
    /// @param _nounId ID of the NounsToken
    /// @param _owner Address of the Nouns owner
    function deployVault(
        address[] calldata _modules,
        address[] calldata _plugins,
        bytes4[] calldata _selectors,
        bytes32[] calldata _mintProof,
        address _descriptor,
        uint256 _nounId,
        address _owner
    ) external onlyOwner returns (address vault) {
        // Generates merkle tree with the list of module contracts
        bytes32[] memory leafNodes = generateMerkleTree(_modules);
        // Gets the merkle root of the leaf nodes
        bytes32 merkleRoot = getRoot(leafNodes);
        // Deploys a new vault for the NounsToken ID
        vault = IRegistry(registry).create(merkleRoot, _plugins, _selectors, _descriptor, _nounId);
        {
            // Transfers NounsToken from caller to vault
            address nounsToken = IRegistry(registry).nounsToken();
            INouns(nounsToken).safeTransferFrom(_owner, vault, _nounId);
            // Creates a new auction for the NounsToken and mints the first Nounlet
            IAuction(auction).createAuction(vault, _owner, _mintProof);
        }
        // Emits event with list of modules installed on the vault
        emit ActiveModules(vault, _modules);
    }

    /// @notice Generates a merkle tree from the hashed permission lists of the given modules
    /// @param _modules List of module contracts
    /// @return hashes A combined list of leaf nodes
    function generateMerkleTree(address[] calldata _modules)
        public
        view
        returns (bytes32[] memory hashes)
    {
        uint256 counter;
        uint256 hashesLength;
        for (uint256 i = 0; i < _modules.length; ++i) {
            hashesLength += IModule(_modules[i]).getLeafNodes().length;
        }
        hashes = new bytes32[](hashesLength);
        unchecked {
            for (uint256 i = 0; i < _modules.length; ++i) {
                bytes32[] memory leaves = IModule(_modules[i]).getLeafNodes();
                for (uint256 j; j < leaves.length; ++j) {
                    hashes[counter++] = leaves[j];
                }
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Permission} from "./IVaultRegistry.sol";

/// @dev Interface for generic Module contract
interface IModule {
    function getLeafNodes() external view returns (bytes32[] memory nodes);

    function getPermissions() external view returns (Permission[] memory permissions);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IModule, Permission} from "./IModule.sol";

/// @dev Auction information
struct Auction {
    // Address of the highest bidder
    address bidder;
    // Amount of the highest bid
    uint64 amount;
    // End time of the auction
    uint32 endTime;
}

/// @dev Vault information
struct Vault {
    // Address of the vault curator
    address curator;
    // Current ID of the token
    uint96 currentId;
}

/// @dev Interface for NounletAuction contract
interface INounletAuction is IModule {
    /// @dev Emitted when the auction has already been created for the first Nounlet of a Noun
    error AuctionAlreadyCreated();
    /// @dev Emitted when the auction has not completed
    error AuctionNotCompleted();
    /// @dev Emitted when the auction has already ended
    error AuctionExpired();
    /// @dev Emitted when the minimum bid increase has not been met
    error InvalidBidIncrease();
    /// @dev Emitted when the caller is the not the auction winner
    error NotWinner();

    /// @dev Event log for creating a new auction
    /// @param _vault Address of the vault
    /// @param _token Address of the token contract
    /// @param _id ID of the token
    /// @param _endTime End time of the auction
    event Created(
        address indexed _vault,
        address indexed _token,
        uint256 indexed _id,
        uint256 _endTime
    );

    /// @dev Event log for bidding on an auction
    /// @param _vault Address of the vault
    /// @param _token Address of the token contract
    /// @param _id ID of the token
    /// @param _bidder Address of the bidder
    /// @param _value Ether value of the current bid
    /// @param _endTime New end time if bid is placed in final 10 minutes
    event Bid(
        address indexed _vault,
        address indexed _token,
        uint256 indexed _id,
        address _bidder,
        uint256 _value,
        uint256 _endTime
    );

    /// @dev Event log for settling a finished auction
    /// @param _vault Address of the vault
    /// @param _token Address of the token contract
    /// @param _id ID of the token
    /// @param _winner Address of the highest bidder at auction end
    /// @param _amount Ether value of the highest bid at auction end
    event Settled(
        address indexed _vault,
        address indexed _token,
        uint256 indexed _id,
        address _winner,
        uint256 _amount
    );

    function duration() external view returns (uint48);

    function MIN_INCREASE() external view returns (uint48);

    function TIME_BUFFER() external view returns (uint48);

    function TOTAL_SUPPLY() external view returns (uint48);

    function auctionInfo(address, uint256)
        external
        view
        returns (
            address bidder,
            uint64 bid,
            uint32 endTime
        );

    function bid(address _vault) external payable;

    function registry() external view returns (address);

    function createAuction(
        address _vault,
        address _curator,
        bytes32[] calldata _mintProof
    ) external;

    function settleAuction(address _vault, bytes32[] calldata _mintProof) external;

    function vaultInfo(address) external view returns (address curator, uint96 currentId);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface for NounletProtoform contract
interface INounletProtoform {
    /// @dev Event log for modules that are enabled on a vault
    /// @param _vault Address of the vault deployed
    /// @param _modules List of modules contract addresses being activated on the vault
    event ActiveModules(address indexed _vault, address[] _modules);

    function auction() external view returns (address);

    function deployVault(
        address[] calldata _modules,
        address[] calldata _plugins,
        bytes4[] calldata _selectors,
        bytes32[] calldata _mintProof,
        address _descriptor,
        uint256 _nounId,
        address _owner
    ) external returns (address vault);

    function generateMerkleTree(address[] calldata _modules)
        external
        view
        returns (bytes32[] memory hashes);

    function registry() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Interface for NounletRegistry contract
interface INounletRegistry {
    /// @dev Emitted when the caller is not a registered vault
    error UnregisteredVault(address _sender);

    /// @dev Event log for deploying vault
    /// @param _vault Address of the vault
    /// @param _token Address of the token
    event VaultDeployed(address indexed _vault, address indexed _token);

    function batchBurn(address _from, uint256[] memory _ids) external;

    function create(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors,
        address _descriptor,
        uint256 _nounId
    ) external returns (address vault);

    function factory() external view returns (address);

    function implementation() external view returns (address);

    function mint(address _to, uint256 _id) external;

    function nounsToken() external view returns (address);

    function royaltyBeneficiary() external view returns (address);

    function uri(address _vault, uint256 _id) external view returns (string memory);

    function vaultToToken(address) external view returns (address token);
}

// SPDX-License-Identifier: GPL-3.0

/// @title Common interface for NounsDescriptor versions, as used by NounsToken and NounsSeeder.

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.13;

import {INounsSeeder} from "./INounsSeeder.sol";
import {ISVGRenderer} from "nouns-contracts/contracts/interfaces/ISVGRenderer.sol";

interface INounsDescriptor {
    function tokenURI(uint256 tokenId, INounsSeeder.Seed memory seed)
        external
        view
        returns (string memory);

    function dataURI(uint256 tokenId, INounsSeeder.Seed memory seed)
        external
        view
        returns (string memory);

    function backgroundCount() external view returns (uint256);

    function bodyCount() external view returns (uint256);

    function accessoryCount() external view returns (uint256);

    function headCount() external view returns (uint256);

    function glassesCount() external view returns (uint256);

    function genericDataURI(
        string calldata name,
        string calldata description,
        INounsSeeder.Seed memory seed
    ) external view returns (string memory);

    function renderer() external view returns (address);

    function art() external view returns (address);

    function getPartsForSeed(INounsSeeder.Seed memory seed)
        external
        view
        returns (ISVGRenderer.Part[] memory);
}

// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsSeeder

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.13;

import {INounsDescriptor} from "./INounsDescriptor.sol";

interface INounsSeeder {
    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
        uint48 glasses;
    }

    function generateSeed(uint256 nounId, INounsDescriptor descriptor)
        external
        view
        returns (Seed memory);
}

// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsToken

/*********************************
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░██░░░████░░██░░░████░░░ *
 * ░░██████░░░████████░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░██░░██░░░████░░██░░░████░░░ *
 * ░░░░░░█████████░░█████████░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ *
 *********************************/

pragma solidity ^0.8.13;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {INounsDescriptor} from "./INounsDescriptor.sol";
import {INounsSeeder} from "./INounsSeeder.sol";

interface INounsToken is IERC721 {
    event DescriptorLocked();

    event DescriptorUpdated(INounsDescriptor descriptor);

    event NounBurned(uint256 indexed tokenId);

    event NounCreated(uint256 indexed tokenId, INounsSeeder.Seed seed);

    event NoundersDAOUpdated(address noundersDAO);

    event MinterLocked();

    event MinterUpdated(address minter);

    event SeederLocked();

    event SeederUpdated(INounsSeeder seeder);

    function burn(uint256 tokenId) external;

    function dataURI(uint256 tokenId) external returns (string memory);

    function delegate(address delegatee) external;

    function descriptor() external returns (INounsDescriptor);

    function lockDescriptor() external;

    function lockMinter() external;

    function lockSeeder() external;

    function mint() external returns (uint256);

    function minter() external returns (address);

    function seeds(uint256) external view returns (INounsSeeder.Seed memory);

    function setDescriptor(INounsDescriptor descriptor) external;

    function setMinter(address minter) external;

    function setNoundersDAO(address noundersDAO) external;

    function setSeeder(INounsSeeder seeder) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @dev Vault permissions
struct Permission {
    // Address of module contract
    address module;
    // Address of target contract
    address target;
    // Function selector from target contract
    bytes4 selector;
}

/// @dev Vault information
struct VaultInfo {
    // Address of FERC1155 token contract
    address token;
    // ID of the token type
    uint256 id;
}

/// @dev Interface for VaultRegistry contract
interface IVaultRegistry {
    /// @dev Emitted when the caller is not the controller
    error InvalidController(address _controller, address _sender);
    /// @dev Emitted when the caller is not a registered vault
    error UnregisteredVault(address _sender);

    /// @dev Event log for deploying vault
    /// @param _vault Address of the vault
    /// @param _token Address of the token
    /// @param _id Id of the token
    event VaultDeployed(address indexed _vault, address indexed _token, uint256 _id);

    function burn(address _from, uint256 _value) external;

    function create(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function createCollection(
        bytes32 _merkleRoot,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault, address token);

    function createCollectionFor(
        bytes32 _merkleRoot,
        address _controller,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault, address token);

    function createFor(
        bytes32 _merkleRoot,
        address _owner,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function createInCollection(
        bytes32 _merkleRoot,
        address _token,
        address[] memory _plugins,
        bytes4[] memory _selectors
    ) external returns (address vault);

    function factory() external view returns (address);

    function fNFT() external view returns (address);

    function fNFTImplementation() external view returns (address);

    function mint(address _to, uint256 _value) external;

    function nextId(address) external view returns (uint256);

    function totalSupply(address _vault) external view returns (uint256);

    function uri(address _vault) external view returns (string memory);

    function vaultToToken(address) external view returns (address token, uint256 id);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/// @title Merkle Base
/// @author Modified from Murky (https://github.com/dmfxyz/murky/blob/main/src/common/MurkyBase.sol)
/// @notice Utility contract for generating merkle roots and verifying proofs
abstract contract MerkleBase {
    constructor() {}

    /// @notice Hashes two leaf pairs
    /// @param _left Node on left side of tree level
    /// @param _right Node on right side of tree level
    /// @return data Result hash of node params
    function hashLeafPairs(bytes32 _left, bytes32 _right) public pure returns (bytes32 data) {
        // Return opposite node if checked node is of bytes zero value
        if (_left == bytes32(0)) return _right;
        if (_right == bytes32(0)) return _left;

        assembly {
            // TODO: This can be aesthetically simplified with a switch. Not sure it will
            // save much gas but there are other optimizations to be had in here.
            if or(lt(_left, _right), eq(_left, _right)) {
                mstore(0x0, _left)
                mstore(0x20, _right)
            }
            if gt(_left, _right) {
                mstore(0x0, _right)
                mstore(0x20, _left)
            }
            data := keccak256(0x0, 0x40)
        }
    }

    /// @notice Verifies the merkle proof of a given value
    /// @param _root Hash of merkle root
    /// @param _proof Merkle proof
    /// @param _valueToProve Leaf node being proven
    /// @return Status of proof verification
    function verifyProof(
        bytes32 _root,
        bytes32[] memory _proof,
        bytes32 _valueToProve
    ) public pure returns (bool) {
        // proof length must be less than max array size
        bytes32 rollingHash = _valueToProve;
        unchecked {
            for (uint256 i = 0; i < _proof.length; ++i) {
                rollingHash = hashLeafPairs(rollingHash, _proof[i]);
            }
        }
        return _root == rollingHash;
    }

    /// @notice Generates the merkle root of a tree
    /// @param _data Leaf nodes of the merkle tree
    /// @return Hash of merkle root
    function getRoot(bytes32[] memory _data) public pure returns (bytes32) {
        require(_data.length > 1, "wont generate root for single leaf");
        while (_data.length > 1) {
            _data = hashLevel(_data);
        }
        return _data[0];
    }

    /// @notice Generates the merkle proof for a leaf node in a given tree
    /// @param _data Leaf nodes of the merkle tree
    /// @param _node Index of the node in the tree
    /// @return Merkle proof
    function getProof(bytes32[] memory _data, uint256 _node)
        public
        pure
        returns (bytes32[] memory)
    {
        require(_data.length > 1, "wont generate proof for single leaf");
        // The size of the proof is equal to the ceiling of log2(numLeaves)
        uint256 size = log2ceil_naive(_data.length);
        bytes32[] memory result = new bytes32[](size);
        uint256 pos;
        uint256 counter;

        // Two overflow risks: node, pos
        // node: max array size is 2**256-1. Largest index in the array will be 1 less than that. Also,
        // for dynamic arrays, size is limited to 2**64-1
        // pos: pos is bounded by log2(data.length), which should be less than type(uint256).max
        while (_data.length > 1) {
            unchecked {
                if (_node % 2 == 1) {
                    result[pos] = _data[_node - 1];
                } else if (_node + 1 == _data.length) {
                    result[pos] = bytes32(0);
                    ++counter;
                } else {
                    result[pos] = _data[_node + 1];
                }
                ++pos;
                _node = _node / 2;
            }
            _data = hashLevel(_data);
        }

        // Dynamic array to filter out address(0) since proof size is rounded up
        // This is done to return the actual proof size of the indexed node
        bytes32[] memory arr = new bytes32[](size - counter);
        unchecked {
            uint256 offset;
            for (uint256 i; i < result.length; ++i) {
                if (result[i] != bytes32(0)) {
                    arr[i - offset] = result[i];
                } else {
                    ++offset;
                }
            }
        }

        return arr;
    }

    /// @dev Hashes nodes at the given tree level
    /// @param _data Nodes at the current level
    /// @return result Hashes of nodes at the next level
    function hashLevel(bytes32[] memory _data) private pure returns (bytes32[] memory result) {
        // Function is private, and all internal callers check that data.length >=2.
        // Underflow is not possible as lowest possible value for data/result index is 1
        // overflow should be safe as length is / 2 always.
        unchecked {
            uint256 length = _data.length;
            if (length & 0x1 == 1) {
                result = new bytes32[](length / 2 + 1);
                result[result.length - 1] = hashLeafPairs(_data[length - 1], bytes32(0));
            } else {
                result = new bytes32[](length / 2);
            }

            // pos is upper bounded by data.length / 2, so safe even if array is at max size
            uint256 pos;
            for (uint256 i; i < length - 1; i += 2) {
                result[pos] = hashLeafPairs(_data[i], _data[i + 1]);
                ++pos;
            }
        }
    }

    /// @notice Calculates proof size based on size of tree
    /// @dev Note that x is assumed > 0 and proof size is not precise
    /// @param x Size of the merkle tree
    /// @return ceil Rounded value of proof size
    function log2ceil_naive(uint256 x) public pure returns (uint256 ceil) {
        uint256 pOf2;
        // If x is a power of 2, then this function will return a ceiling
        // that is 1 greater than the actual ceiling. So we need to check if
        // x is a power of 2, and subtract one from ceil if so.
        assembly {
            // we check by seeing if x == (~x + 1) & x. This applies a mask
            // to find the lowest set bit of x and then checks it for equality
            // with x. If they are equal, then x is a power of 2.

            /* Example
                x has single bit set
                x := 0000_1000
                (~x + 1) = (1111_0111) + 1 = 1111_1000
                (1111_1000 & 0000_1000) = 0000_1000 == x
                x has multiple bits set
                x := 1001_0010
                (~x + 1) = (0110_1101 + 1) = 0110_1110
                (0110_1110 & x) = 0000_0010 != x
            */

            // we do some assembly magic to treat the bool as an integer later on
            pOf2 := eq(and(add(not(x), 1), x), x)
        }

        // if x == type(uint256).max, than ceil is capped at 256
        // if x == 0, then pO2 == 0, so ceil won't underflow
        unchecked {
            while (x > 0) {
                x >>= 1;
                ceil++;
            }
            ceil -= pOf2; // see above
        }
    }
}