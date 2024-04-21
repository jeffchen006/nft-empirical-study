// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface GardenCenterOwnershipToken{

    function mint(address to, address collection, address center) external;
}

interface GardenCenter{

    function construct(address _collection, address _sender) external;
}

interface Ownable{

    function owner() external view returns(address);
}

contract GardenCenterFactory {
    
    uint256 public cooldownPeriod;
    address public blueprint;
    address public owner;
    address public ownershipToken;
    address[] public centers;
    mapping(address => address) public centersMap;
    mapping(address => uint256) public centersIndex;
    mapping(address => address) public altOwner;
    mapping(address => uint256) public accountLastTimestamp;
    mapping(uint256 => uint256) public tokenIdLastTimestamp;
    mapping(address => bool) public admins;

    event GardenCenterCreated(address indexed user, address indexed collection, address indexed center);
    event AdminSet(address indexed admin, bool state);

    constructor(address _blueprint)  {

        blueprint = _blueprint;
        owner = msg.sender;
        centers.push(address(0));
        ownershipToken = 0x4538e6225bD4cdAA9da327a16b9FC2f35c7e4cA7;
        cooldownPeriod = 86400;
    }

    function newCenter(address collection, uint256 unicornTokenId) external {
	    
        uint256 _cooldownPeriod = cooldownPeriod;
        address _sender = msg.sender;

        require(collection != address(0), "newCenter: null address not allowed.");
        require(IERC721(0x13fD344E39C30187D627e68075d6E9201163DF33).ownerOf(unicornTokenId) == _sender, "newCenter: not owning the given tokenId.");
        require(block.timestamp - accountLastTimestamp[_sender] >= _cooldownPeriod, "newCenter: cooldown period for account not yet expired");
        require(block.timestamp - tokenIdLastTimestamp[unicornTokenId] >= _cooldownPeriod, "newCenter: cooldown period for tokendID not yet expired");
        require(centersMap[collection] == address(0), "newCenter: center exists already.");

	    address center = createClone(blueprint);
        uint256 ts = block.timestamp;

	    centers.push(center);
        centersIndex[collection] = centers.length - 1;
        centersMap[collection] = center;
        accountLastTimestamp[_sender] = ts;
        tokenIdLastTimestamp[unicornTokenId] = ts;

        GardenCenter(center).construct(collection, _sender);
        GardenCenterOwnershipToken(ownershipToken).mint(_sender, collection, center);
	    
	    emit GardenCenterCreated(_sender, collection, center);
	}

    function collectionOwner(address _owner, address collection) external view returns(bool){

        return Ownable(collection).owner() == _owner;
    }

    function getCentersLength() external view returns(uint256){

        return centers.length;
    }

    function setCooldownPeriod(uint256 _cooldownPeriod) external{

        require(owner == msg.sender || admins[msg.sender], "setCooldownPeriod: not an admin.");

        cooldownPeriod = _cooldownPeriod;
    }

    function setAltOwner(address _collection, address _altOwner) external{

        require(owner == msg.sender || admins[msg.sender], "setAltOwner: not an admin.");

        altOwner[_collection] = _altOwner;
    }

    function setAdmin(address _admin, bool _is) external{

        require(owner == msg.sender, "setAdmin: not the owner.");

        admins[_admin] = _is;

        emit AdminSet(_admin, _is);
    }

    function setBlueprint(address _blueprint) external{

        require(owner == msg.sender, "setBlueprint: not the owner.");

        blueprint = _blueprint;
    }

    function transferOwnership(address _newOwner) external{

        require(owner == msg.sender, "transferOwnership: not the owner.");

        owner = _newOwner;
    }

    function createClone(address target) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
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