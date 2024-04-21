// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

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
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

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
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

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
    function balanceOf(address account, uint256 id) external view returns (uint256);

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
    function isApprovedForAll(address account, address operator) external view returns (bool);

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155Receiver.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
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

//*~~~> SPDX-License-Identifier: MIT make it better, stronger, faster

/*~~~>
    Thank you Phunks for your inspiration and phriendship.
      Never stop phighting, never surrender, always stand up for what is right and make the best of all situations towards all people.
      Phunks are phreedom phighters!
      
      "When the power of love overcomes the love of power the world will know peace." - Jimi Hendrix <3

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################%%%%%@@@@@((((((((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################%%%%%@@@@@((((((((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@########################################%%%%%@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@########################################%%%%%@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@###############@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@###############@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@PhunkyJON was here programming trustless, unstoppable [email protected](((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@#PHUNKYJON///////////////#PHUNKYJON//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@#PHUNKYJON///////////////#PHUNKYJON//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////@EYES////////////////////@EYES///////////////@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////@EYES////////////////////@EYES///////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////////////////////////////////////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////////////////////////////////////////////[email protected]@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@/////////////////////////////////////////////@@@@@@@@@@((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////[email protected]@////////////////////#####@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((SMOKE((((((((((@@@@@//////////[email protected]@////////////////////#####@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@#####//////////////////////////////##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((@@@@@#####//////////////////////////////##########@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@###################################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@###################################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((EMBER(((((,,,,,,,,,,,,,,,,,,,,,,,,,@@@@@MOUTH&&&&&####################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((EMBER(((((,,,,,,,,,,,,,,,,,,,,,,,,,@@@@@MOUTH&&&&&####################@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@##############################/////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((@[email protected]@[email protected]@@##############################/////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%(((((((((((((((((((((((((((((((((((@@@@@##############################//////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((@@@@@@@@@@@@@@@@@@@@@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%((((((((((((((((((((((((((((((((((((((((((((((((((((((((((((@@@@@///////////////@@@@@(((((((((((((((((((((((((%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@///////////////@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%@@@@@///////////////@@@@@%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

 <~~~*/

pragma solidity  0.8.7;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "./interfaces/IEscrow.sol";
import "./interfaces/INFTMarket.sol";
import "./interfaces/IRoleProvider.sol";

contract MarketTrades is ReentrancyGuard {
  
  //*~~~> counter increments NFTs Trade Offer ids
  uint private tradeCount;
  uint private blindTradeCount;

  //*~~~> Roles for designated accessibility
  bytes32 public constant PROXY_ROLE = keccak256("PROXY_ROLE");
  bytes32 public constant DEV = keccak256("DEV");
  modifier hasAdmin(){
    require(IRoleProvider(roleAdd).hasTheRole(PROXY_ROLE, msg.sender), "DOES NOT HAVE ADMIN ROLE");
    _;
  }
  modifier hasContractAdmin(){
    require(IRoleProvider(roleAdd).hasContractRole(msg.sender), "DOES NOT HAVE CONTRACT ROLE");
    _;
  }
  modifier hasDevAdmin(){
    require(IRoleProvider(roleAdd).hasTheRole(DEV, msg.sender), "DOES NOT HAVE DEV ROLE");
    _;
  }

  //*~~~> Upgradable addresses
  address public roleAdd;

  //*~~~> global address variable from Role Provider contract
  bytes32 public constant MARKET = keccak256("MARKET");

  bytes32 public constant BIDS = keccak256("BIDS");

  bytes32 public constant OFFERS = keccak256("OFFERS");

  uint[] private openStorage;
  uint[] private blindOpenStorage;

  //*~~~> Fee constructor initially set to .005%
  constructor(address role){
    roleAdd = role;
  }

  //*~~~> Declaring object struct for trades entered
  struct Trade {
    bool is1155; 
    uint itemId;
    uint tradeId;
    uint tokenId;
    uint amount1155;
    address nftCont;
    address trader;
    address seller;
  }
  struct BlindTrade {
    bool is1155;
    bool isWant1155;
    bool isActive;
    bool isSpecific;
    uint wantedId;
    uint tradeId;
    uint tokenId;
    uint amount1155;
    uint wAmount1155;
    address nftCont;
    address wantCont;
    address trader;
  }

  //*~~~> Memory array of all Trades
  mapping (uint256 => Trade) private idToNftTrade;
  mapping (uint256 => BlindTrade) private idToBlindTrade;
  mapping (uint => uint) private marketIdToTradeId;

  //*~~~> Declaring event object structure for trade entered
  event TradeEntered(
      bool is1155,
      uint itemId,
      uint tradeId,
      uint tokenId,
      uint amount1155,
      address indexed nftCont,
      address indexed trader,
      address indexed seller
  );
  event BlindTradeEntered(
      bool isWanted1155,
      bool isGiven1155,
      bool isSpecific,
      uint wantedId,
      uint tokenId,
      uint tradeId,
      uint amount1155,
      uint wAmount1155,
      address indexed nftCont,
      address indexed wantCont,
      address indexed trader
  );

  //*~~~> Declaring event object structure for trade withdrawn
  event TradeWithdrawn(
      bool is1155,
      uint itemId,
      uint tradeId,
      uint indexed tokenId,
      address indexed nftCont,
      address indexed trader
  );

  //*~~~> Declaring event object structure for trade accepted
  event TradeAccepted(
      bool is1155,
      bool isActive,
      uint indexed itemId,
      uint indexed tradeId,
      uint tokenId,
      address nftCont,
      address indexed trader,
      address seller
  ); 
  
  //*~~~> Declaring event object structure for blindTrade accepted
  event BlindTradeAccepted(
      bool is1155,
      bool isActive,
      uint indexed itemId,
      uint indexed tradeId,
      uint tokenId,
      address nftCont,
      address indexed trader,
      address seller
  );  

  //*~~~> Declaring event object structure for trade updated
  event TradeUpdated(
      bool is1155,
      bool isActive,
      uint indexed itemId,
      uint indexed tradeId,
      uint tokenId,
      address nftCont,
      address indexed trader,
      address seller
  );

  ///@notice
  /*~~~>
    Public function to enter a trade of an ERC721 or ERC1155 NFT for any item listed on market
  <~~~*/
  ///@dev
  /*~~~>
    amount1155: how many ERC1155 to be offered for trade;
    itemId: Market contract internal state itemId;
    tokenId: specific token Id to trade listed item for;
    nftContract: contract address of the NFT to trade;
    seller: ownerOf NFT desired;
  <~~~*/
  function enterTrade(
      uint[] memory amount1155,
      uint[] memory itemId,
      uint[] memory tokenId,
      address[] memory nftContract,
      address[] memory seller
  ) external nonReentrant returns(bool){
    for (uint i=0;i<itemId.length;i++) {
      uint tradeId;
      if (openStorage.length>=1) {
        tradeId = openStorage[openStorage.length-1];
        _remove(0);
      } else {
        tradeId = tradeCount+=1;
      }
      if (amount1155[i]>0){
        IERC1155(nftContract[i]).safeTransferFrom(msg.sender, address(this), tokenId[i], amount1155[i], "");
        IERC1155(nftContract[i]).setApprovalForAll(address(this), true);
        marketIdToTradeId[itemId[i]] = tradeId;
        idToNftTrade[tradeId] = Trade(true, itemId[i], tradeId, tokenId[i], amount1155[i], nftContract[i], msg.sender, seller[i]);
        emit TradeEntered(
          true,
          itemId[i], 
          tradeId, 
          tokenId[i],
          amount1155[i],
          nftContract[i], 
          msg.sender, 
          seller[i]);
      } else {
        require(transferFromERC721(nftContract[i], tokenId[i], address(this)));
        require(approveERC721(nftContract[i], address(this), tokenId[i]));
        marketIdToTradeId[itemId[i]] = tradeId;
        idToNftTrade[tradeId] = Trade(false, itemId[i], tradeId, tokenId[i], amount1155[i], nftContract[i], msg.sender, seller[i]);
        emit TradeEntered(
          false,
          itemId[i], 
          tradeId, 
          tokenId[i],
          amount1155[i],
          nftContract[i], 
          msg.sender, 
          seller[i]);
        }
      }
    return true;
  }

  ///@notice
  //*~~~> Public function to enter blind trades
  ///@dev
  /*~~~> 

      let Given = nft given to trade
      let Wanted = nft wanted from trade
    
    isWanted1155: (true) if Wanted is ERC1155;
    isGiven1155: (true) if Given is ERC1155;
    isSpecific: (true) if Wanted is specific;
    wantedId: token Id of the Wanted;
    tokenId: token Id of the Given;
    amount1155: how many Given 1155;
    wAmount1155: how many Wanted 1155;
    nftContract: Given contract address;
    wantContract: Wanted contract address;
  <~~~*/
  function enterBlindTrade(
      bool[] memory isWanted1155,
      bool[] memory isGiven1155,
      bool[] memory isSpecific,
      uint[] memory wantedId,
      uint[] memory tokenId,
      uint[] memory amount1155,
      uint[] memory wAmount1155,
      address[] memory nftContract,
      address[] memory wantContract
  ) external nonReentrant{

    for (uint i=0;i<tokenId.length;i++) {
      uint tradeId;
      if (blindOpenStorage.length>=1) {
        tradeId = blindOpenStorage[blindOpenStorage.length-1];
        _remove(1);
      } else {
        tradeId = blindTradeCount+=1;
      }
      if (isGiven1155[i]){
        IERC1155(nftContract[i]).safeTransferFrom(msg.sender, address(this), tokenId[i], amount1155[i], "");
        IERC1155(nftContract[i]).setApprovalForAll(address(this), true);
      } else {
        require(transferFromERC721(nftContract[i], tokenId[i], address(this)));
        require(approveERC721(nftContract[i], address(this), tokenId[i]));
      }
      idToBlindTrade[tradeId] = BlindTrade(isWanted1155[i], isGiven1155[i], true, isSpecific[i], wantedId[i], tradeId, tokenId[i], amount1155[i], wAmount1155[i], nftContract[i], wantContract[i], msg.sender);
      emit BlindTradeEntered(
          isWanted1155[i],
          isGiven1155[i],
          isSpecific[i],
          wantedId[i],
          tokenId[i],
          tradeId, 
          amount1155[i],
          wAmount1155[i],
          nftContract[i], 
          wantContract[i],
          msg.sender);
      }
  }

  ///@notice
  //*~~~>Public function to withdraw trade
  ///@dev
  /*~~~>
    isBlind: (true) if trade is blind;
    itemId: Market internal storage id;
    tradeId: internal this storade id;
  <~~~*/
  ///@return Bool
  function withdrawTrade(
      bool[] memory isBlind,
      uint[] memory itemId,
      uint[] memory tradeId
  ) external nonReentrant returns(bool){
    for (uint i=0; i<itemId.length; i++) {
      if(isBlind[i]){
      BlindTrade memory trade = idToBlindTrade[tradeId[i]];
      require(trade.isActive == true, "Item is not listed for trade...");
      if (trade.trader != msg.sender) revert();
      if ( trade.is1155 ){
        IERC1155(trade.nftCont).safeTransferFrom(address(this), trade.trader, trade.tokenId, trade.amount1155, "");
      } else {
        require(transferERC721(trade.nftCont, trade.trader, trade.tokenId));
      }
      blindOpenStorage.push(tradeId[i]);
      idToBlindTrade[tradeId[i]] = BlindTrade(false, false, false, false, 0, 0, 0, 0, 0, address(0x0), address(0x0), address(0x0));
      emit TradeWithdrawn(
          false,
          itemId[i], 
          tradeId[i],  
          trade.tokenId,
          trade.nftCont, 
          trade.trader
          );
      } else {
      Trade memory trade = idToNftTrade[tradeId[i]];
      require(trade.tradeId > 0, "Item is not listed for trade...");
      if (trade.trader != msg.sender) revert();
      if ( trade.is1155 ){
        IERC1155(trade.nftCont).safeTransferFrom(address(this), msg.sender, trade.tokenId, trade.amount1155, "");
      } else {
        require(transferERC721(trade.nftCont, trade.trader, trade.tokenId));
      }
      openStorage.push(tradeId[i]);
      marketIdToTradeId[itemId[i]] = 0;
      idToNftTrade[tradeId[i]] = Trade(false, 0, 0, 0, 0, address(0x0), address(0x0), address(0x0));
      
      emit TradeWithdrawn(
          false,
          itemId[i], 
          tradeId[i],  
          trade.tokenId,
          trade.nftCont, 
          trade.trader
          );
        }
      }
      return true;
  }

  ///@notice
  //*~~~>Function to refund trade if the item sells
  ///@dev
  /*~~~>
    itemId: Market item id internal storage;
    tradeId: trade item id for this internal storage;
  <~~~*/
  ///@return Bool
  function refundTrade(uint itemId, uint tradeId) public nonReentrant hasContractAdmin returns(bool){
    Trade memory trade = idToNftTrade[tradeId];
    if ( trade.is1155 ){
      IERC1155(trade.nftCont).safeTransferFrom(address(this), trade.trader, trade.tokenId, trade.amount1155, "");
    } else {
      require(transferERC721(trade.nftCont, trade.trader, trade.tokenId));
    }
    idToNftTrade[tradeId] = Trade(false, 0, 0, 0, 0, address(0x0), address(0x0), address(0x0));
    openStorage.push(tradeId);
    emit TradeUpdated(
       trade.is1155,
       false,
       itemId, 
       tradeId, 
       trade.tokenId,
       trade.nftCont, 
       trade.trader,
       trade.seller
      );
    return true;
  }

  ///@notice
  //*~~~>Internal function to refund trade if the item sells
  ///@dev
  /*~~~> The contract will throw an access control error if not done internally
    itemId: Market item id internal storage;
    tradeId: trade item id for this internal storage;
  <~~~*/
  function _refundTradeFromSale(uint itemId, uint tradeId) internal returns(bool){
    Trade memory trade = idToNftTrade[tradeId];
    if ( trade.is1155 ){
      IERC1155(trade.nftCont).safeTransferFrom(address(this), trade.trader, trade.tokenId, trade.amount1155, "");
    } else {
      require(transferERC721(trade.nftCont, trade.trader, trade.tokenId));
    }
    idToNftTrade[tradeId] = Trade(false, 0, 0, 0, 0, address(0x0), address(0x0), address(0x0));
    openStorage.push(tradeId);
    emit TradeUpdated(
       trade.is1155,
       false,
       itemId, 
       tradeId, 
       trade.tokenId,
       trade.nftCont, 
       trade.trader,
       trade.seller
      );
    return true;
  }

  ///@notice
  /*~~~>
    Public function to accept trade
  <~~~*/
  ///@notice
  /*~~~>
    itemId: Market item Id internal storage;
    tradeId: Id of trade for internal storage;
  <~~~*/
  ///@return Bool
  function acceptTrade(
      uint[] calldata itemId,
      uint[] calldata tradeId
  ) public nonReentrant returns(bool){
    
    address marketAdd = IRoleProvider(roleAdd).fetchAddress(MARKET);
    address bidsAdd = IRoleProvider(roleAdd).fetchAddress(BIDS);
    address offersAdd = IRoleProvider(roleAdd).fetchAddress(OFFERS);
    for(uint i=0; i<itemId.length;i++) {
      Trade memory trade = idToNftTrade[tradeId[i]];
      require(msg.sender == trade.seller,"Not Owner");
      if ( trade.is1155 ){
        IERC1155(trade.nftCont).safeTransferFrom(address(this), trade.seller, trade.tokenId, trade.amount1155, "");
      } else {
        require(transferERC721(trade.nftCont, trade.seller, trade.tokenId));
      }
      /*~~~> Check for the case where there is a trade and refund it. <~~~*/
      uint offerId = IOffers(offersAdd).fetchOfferId(itemId[i]);
      if (offerId > 0) {
      /*~~~> Kill offer and refund amount <~~~*/
        //*~~~> Call the contract to refund the NFT offered for trade
        require(IOffers(offersAdd).refundOffer(itemId[i], offerId));
      }
      uint bidId = IBids(bidsAdd).fetchBidId(itemId[i]);
      if (bidId>0) {
      /*~~~> Kill bid and refund bidValue <~~~*/
        //~~~> Call the contract to refund the ETH offered for a bid
        require(IBids(bidsAdd).refundBid(bidId));
      }
       openStorage.push(tradeId[i]);
       marketIdToTradeId[itemId[i]] = 0;
       idToNftTrade[tradeId[i]] = Trade(
           false,
           0,
           0,
           0,
           0,
           address(0x0),
           address(0x0),
           address(0x0)
       );
      Trade[] memory trades = fetchTradesById(itemId[i]);
      for(uint j; j<trades.length;j++){
        require(_refundTradeFromSale(trades[i].itemId, trades[i].tradeId));
      }
       require(INFTMarket(marketAdd).transferNftForSale(trade.trader, itemId[i]));
       emit TradeAccepted(
           trade.is1155,
           false,
           itemId[i], 
           tradeId[i], 
           trade.tokenId,
           trade.nftCont,
           trade.trader, 
           trade.seller
           );
      }
    return true;
    }

  ///@notice
  /*~~~>
    Public function to accept trade
  <~~~*/
  ///@notice
  /*~~~>
    tradeId: Id of trade for internal storage;
    tokenId: (if specific) token id of the wanted NFT;
    listedId: (0) if the item is not listed for sale on the marketplace contract;
  <~~~*/
  ///@return Bool
    function acceptBlindTrade(
      uint[] memory tradeId,
      uint[] memory tokenId,
      uint[] memory listedId
  ) public  nonReentrant returns(bool){
    address marketAdd = IRoleProvider(roleAdd).fetchAddress(MARKET);
    for(uint i=0; i<tradeId.length;i++) {
      uint j = tradeId[i];
      BlindTrade memory trade = idToBlindTrade[j];
            //*~~~> Disallow random acceptances if specific
      if(trade.isSpecific){
          require(tokenId[i]==trade.wantedId,"Wrong item!");
        }
      
      /// Send the given NFT
      if (trade.is1155){
        if(listedId[i]==0){
          IERC1155(trade.nftCont).safeTransferFrom(address(this), msg.sender, trade.tokenId, trade.amount1155, "");
        } else {
          require(INFTMarket(marketAdd).transferNftForSale(msg.sender, listedId[i]));
        }
      } else {
        if(listedId[i]==0){
          require(transferERC721(trade.nftCont, msg.sender, trade.tokenId));
        } else {
          require(INFTMarket(marketAdd).transferNftForSale(msg.sender, listedId[i]));
        }
      }
      /// Send the wanted NFT
      if (trade.isWant1155){
        IERC1155(trade.wantCont).safeTransferFrom(msg.sender, trade.trader, tokenId[i], trade.wAmount1155, "");
      } else {
        require(IERC721(trade.wantCont).ownerOf(trade.wantedId) == msg.sender, "Not the token owner!");
        require(transferERC721(trade.wantCont, trade.trader, tokenId[i]));
      }
       blindOpenStorage.push(tradeId[i]);
       idToBlindTrade[tradeId[i]] = BlindTrade(
           false,
           false,
           false,
           false,
           0,
           0,
           0,
           0,
           0,
           address(0x0),
           address(0x0),
           address(0x0)
       );
       emit BlindTradeAccepted(
           trade.is1155,
           false,
           listedId[i], 
           tradeId[i], 
           tokenId[i],
           trade.nftCont, 
           trade.trader,
           msg.sender
           );
           
    }
    return true;
    }

  /// @notice 
    /*~~~> 
      Internal function to transferFrom ERC721 NFTs, including crypto kitties/punks
    <~~~*/
  /// @dev
    /*~~~>
      assetAddr: address of the token to be transfered;
      tokenId: Id of the token to be transfered;
      to: address of recipient;
    <~~~*/
  function transferFromERC721(address assetAddr, uint256 tokenId, address to) internal virtual returns(bool) {
    address kitties = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == kitties) {
        // Cryptokitties.
        data = abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, to, tokenId);
    } else if (assetAddr == punks) {
        // CryptoPunks.
        // Fix here for frontrun attack. Added in v1.0.2.
        bytes memory punkIndexToAddress = abi.encodeWithSignature("punkIndexToAddress(uint256)", tokenId);
        (bool checkSuccess, bytes memory result) = address(assetAddr).staticcall(punkIndexToAddress);
        (address nftOwner) = abi.decode(result, (address));
        require(checkSuccess && nftOwner == msg.sender, "Not the NFT owner");
        data = abi.encodeWithSignature("transferPunk(address,uint256)", msg.sender, tokenId);
    } else {
        // Default.
        // We push to the vault to avoid an unneeded transfer.
        data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", msg.sender, to, tokenId);
    }
    (bool success, bytes memory resultData) = address(assetAddr).call(data);
    require(success, string(resultData));
    return true;
  }

  /// @notice 
    /*~~~> 
      Internal function to approve ERC721 NFTs for transfer, including crypto kitties/punks
    <~~~*/
  /// @dev
    /*~~~>
      assetAddr: address of the token to be transfered;
      to: address of recipient;
      tokenId: Id of the token to be transfered;
    <~~~*/
  function approveERC721(address assetAddr, address to, uint256 tokenId) internal virtual returns(bool) {
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == punks) {
        // CryptoPunks.
        data = abi.encodeWithSignature("offerPunkForSaleToAddress(uint256,uint256,address)", tokenId, 0, to);
        (bool success, bytes memory resultData) = address(assetAddr).call(data);
        require(success, string(resultData));
    } else {
      data = abi.encodeWithSignature("approve(address,uint256)", to, tokenId);
    }
    return true;
  }
  
  /// @notice 
    /*~~~> 
      Internal function to transfer ERC721 NFTs, including crypto kitties/punks
    <~~~*/
  /// @dev
    /*~~~>
      assetAddr: address of the token to be transfered;
      to: address of the recipient;
      tokenId: Id of the token to be transfered;
    <~~~*/
  function transferERC721(address assetAddr, address to, uint256 tokenId) internal virtual returns(bool) {
    address kitties = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
    address punks = 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB;
    bytes memory data;
    if (assetAddr == kitties) {
        // Changed in v1.0.4.
        data = abi.encodeWithSignature("transfer(address,uint256)", to, tokenId);
    } else if (assetAddr == punks) {
        // CryptoPunks.
        data = abi.encodeWithSignature("transferPunk(address,uint256)", to, tokenId);
    } else {
        // Default.
        data = abi.encodeWithSignature("safeTransferFrom(address,address,uint256)", address(this), to, tokenId);
    }
    (bool success, bytes memory returnData) = address(assetAddr).call(data);
    require(success, string(returnData));
    return true;
  }

  ///@notice
  /* Public read functions for internal state */
  function fetchTrades() public view returns (Trade[] memory) {
    uint itemCount = tradeCount;
    uint currentIndex;
    Trade[] memory trades = new Trade[](itemCount);
    for (uint i=0; i < itemCount; i++) {
      if (idToNftTrade[i + 1].tradeId > 0) {
        Trade storage currentItem = idToNftTrade[i + 1];
         trades[currentIndex] = currentItem;
         currentIndex++;
      }
    }
    return trades;
  }
  function fetchUserTrades(address user) public view returns (Trade[] memory) {
    uint itemCount = tradeCount;
    uint currentIndex;
    Trade[] memory trades = new Trade[](itemCount);
    for (uint i=0; i < itemCount; i++) {
      if (idToNftTrade[i + 1].trader == user) {
        Trade storage currentItem = idToNftTrade[i + 1];
         trades[currentIndex] = currentItem;
         currentIndex++;
      }
    }
    return trades;
  }
  function fetchBlindTrades() public view returns (BlindTrade[] memory) {
    uint itemCount = blindTradeCount;
    uint currentIndex;
    BlindTrade[] memory trades = new BlindTrade[](itemCount);
    for (uint i=0; i < itemCount; i++) {
      if (idToBlindTrade[i + 1].isActive) {
        BlindTrade storage currentItem = idToBlindTrade[i + 1];
         trades[currentIndex] = currentItem;
         currentIndex++;
      }
    }
    return trades;
  }
  function fetchUserBlindTrades(address user) public view returns (BlindTrade[] memory) {
    uint itemCount = blindTradeCount;
    uint currentIndex;
    BlindTrade[] memory trades = new BlindTrade[](itemCount);
    for (uint i=0; i < itemCount; i++) {
      if (idToBlindTrade[i + 1].trader == user) {
        BlindTrade storage currentItem = idToBlindTrade[i + 1];
         trades[currentIndex] = currentItem;
         currentIndex++;
      }
    }
    return trades;
  }

  function fetchTradesById(uint itemId) public view returns (Trade[] memory) {
    uint itemCount = tradeCount;
    uint currentIndex;
    Trade[] memory trades = new Trade[](itemCount);
    for (uint i=0; i < itemCount; i++) {
      if (idToNftTrade[i + 1].tradeId > 0) {
          if (idToNftTrade[i + 1].itemId == itemId) {
            Trade storage currentItem = idToNftTrade[i + 1];
            trades[currentIndex] = currentItem;
            currentIndex++;
        }
      }
    }
    return trades;
  }

  function fetchTrade(uint itemId) public view returns (Trade memory item) {
    uint id = marketIdToTradeId[itemId];
    return idToNftTrade[id];
  }

  function fetchTradeId(uint itemId) public view returns(uint tradeId){
    uint id = marketIdToTradeId[itemId];
    return id;
  }

  /// @notice 
  /*~~~> 
    Internal function for removing elements from an array
    Only used for internal storage array index recycling

      In order to reduce storage array size of listed items 
        while maintaining specific enumerable bidId's, 
        any sold or removed item spots are re-used by referring to their index,
        else a new storage spot is created;

        We use the last item in the storage (length of array - 1),
        in order to pop off the item and avoid rewriting 
  <~~~*/
  function _remove(uint store) internal {
      if (store==0){
      openStorage.pop();
      } else if (store==1){
      blindOpenStorage.pop();
      }
    }

  /// @notice
  /*~~~> 
    Internal function for sending ether
  <~~~*/
  /// @return Bool
  function sendEther(address recipient, uint ethvalue) internal returns (bool){
    (bool success, bytes memory data) = address(recipient).call{value: ethvalue}("");
    return(success);
  }

  ///@notice
  /*~~~> External ETH transfer forwarded to role provider contract <~~~*/
  event FundsForwarded(uint value, address from, address to);
  receive() external payable {
    require(sendEther(roleAdd, msg.value));
      emit FundsForwarded(msg.value, msg.sender, roleAdd);
  }
  
  function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
    return this.onERC1155Received.selector;
  }
  
  function onERC721Received(
      address, 
      address, 
      uint256, 
      bytes memory
    )external pure returns(bytes4) {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
  }
}

//*~~~> SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IOffers {
  function fetchOfferId(uint marketId) external returns(uint);
  function refundOffer(uint itemID, uint offerId) external returns (bool);
}
interface ITrades {
  function fetchTradeId(uint marketId) external returns(uint);
  function refundTrade(uint itemId, uint tradeId) external returns (bool);
}
interface IBids {
  function fetchBidId(uint marketId) external returns(uint);
  function refundBid(uint bidId) external returns (bool);
}

//*~~~> SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface INFTMarket { 
    function transferNftForSale(address receiver, uint itemId) external returns(bool);
}

//*~~~> SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IRoleProvider {
  function hasTheRole(bytes32 role, address theaddress) external returns(bool);
  function fetchAddress(bytes32 thevar) external returns(address);
  function hasContractRole(address theaddress) external view returns(bool);
}