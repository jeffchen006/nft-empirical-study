// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "../../../interfaces/IEscrowTicketer.sol";
import "../../../interfaces/ISaleBuilder.sol";
import "../../../interfaces/ISaleHandler.sol";
import "../../../interfaces/ISaleRunner.sol";
import "../../../interfaces/ISeenHausNFT.sol";
import "../MarketHandlerBase.sol";

/**
 * @title SaleBuilderFacet
 *
 * @notice Handles the operation of Seen.Haus sales.
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract SaleBuilderFacet is ISaleBuilder, MarketHandlerBase {

    /**
     * @dev Modifier to protect initializer function from being invoked twice.
     */
    modifier onlyUnInitialized()
    {
        MarketHandlerLib.MarketHandlerInitializers storage mhi = MarketHandlerLib.marketHandlerInitializers();
        require(!mhi.saleBuilderFacet, "Initializer: contract is already initialized");
        mhi.saleBuilderFacet = true;
        _;
    }

    /**
     * @notice Facet Initializer
     *
     * Register supported interfaces
     */
    function initialize()
    public
    onlyUnInitialized
    {
        DiamondLib.addSupportedInterface(type(ISaleBuilder).interfaceId);  // when combined with ISaleRunner ...
        DiamondLib.addSupportedInterface(type(ISaleBuilder).interfaceId ^ type(ISaleRunner).interfaceId); // ... supports ISaleHandler
    }

    /**
     * @notice The sale getter
     */
    function getSale(uint256 _consignmentId)
    external
    override
    view
    returns (Sale memory)
    {
        // Get Market Handler Storage struct
        MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();

        // Return sale
        return mhs.sales[_consignmentId];
    }

    /**
     * @notice Create a new sale.
     *
     * For some lot size of one ERC-1155 token.
     *
     * Ownership of the consigned inventory is transferred to this contract
     * for the duration of the sale.
     *
     * Reverts if:
     *  - Sale start is zero
     *  - Sale exists for consignment
     *  - Consignment has already been marketed
     *
     * Emits a SalePending event.
     *
     * @param _consignmentId - id of the consignment being sold
     * @param _start - the scheduled start time of the sale
     * @param _price - the price of each item in the lot
     * @param _perTxCap - the maximum amount that can be bought in a single transaction
     * @param _audience - the initial audience that can participate. See {SeenTypes.Audience}
     */
    function createPrimarySale (
        uint256 _consignmentId,
        uint256 _start,
        uint256 _price,
        uint256 _perTxCap,
        Audience _audience
    )
    external
    override
    onlyRole(SELLER)
    onlyConsignor(_consignmentId)
    {
        require(_start > 0, "_start may not be zero");

        // Get Market Handler Storage slot
        MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();

        // Fetch the consignment
        Consignment memory consignment = getMarketController().getConsignment(_consignmentId);

        // Make sure the consignment hasn't been marketed
        require(consignment.marketHandler == MarketHandler.Unhandled, "Consignment has already been marketed");

        // Get the storage location for the sale
        Sale storage sale = mhs.sales[consignment.id];

        // Make sure sale doesn't exist (start would always be non-zero on an actual sale)
        require(sale.start == 0, "Sale exists");

        // Set up the sale
        setAudience(_consignmentId, _audience);
        sale.consignmentId = _consignmentId;
        sale.start = _start;
        sale.price = _price;
        sale.perTxCap = _perTxCap;
        sale.state = State.Pending;
        sale.outcome = Outcome.Pending;

        // Notify MarketController the consignment has been marketed
        getMarketController().marketConsignment(consignment.id, MarketHandler.Sale);

        // Notify listeners of state change
        emit SalePending(msg.sender, consignment.seller, sale);
    }

    /**
     * @notice Create a new sale.
     *
     * For some lot size of one ERC-1155 token.
     *
     * Ownership of the consigned inventory is transferred to this contract
     * for the duration of the sale.
     *
     * Reverts if:
     *  - Sale start is zero
     *  - Supply is zero
     *  - Sale exists for consignment
     *  - This contract isn't approved to transfer seller's tokens
     *  - Token contract does not implement either IERC1155 or IERC721
     *
     * Emits a SalePending event.
     *
     * @param _seller - the address that procedes of the sale should go to
     * @param _tokenAddress - the contract address issuing the NFT behind the consignment
     * @param _tokenId - the id of the token being consigned
     * @param _start - the scheduled start time of the sale
     * @param _supply - the supply of the given consigned token being sold
     * @param _price - the price of each item in the lot
     * @param _perTxCap - the maximum amount that can be bought in a single transaction
     * @param _audience - the initial audience that can participate. See {SeenTypes.Audience}
     */
    function createSecondarySale (
        address payable _seller,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _start,
        uint256 _supply,
        uint256 _price,
        uint256 _perTxCap,
        Audience _audience
    )
    external
    override
    {
        // Make sure sale start is not set to zero
        require(_start > 0, "_start may not be zero");

        // Get Market Handler Storage slot
        MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();

        // Get the MarketController
        IMarketController marketController = getMarketController();

        // Determine if consignment is physical
        address nft = marketController.getNft();
        if (nft == _tokenAddress && ISeenHausNFT(nft).isPhysical(_tokenId)) {
            // Is physical NFT, require that msg.sender has ESCROW_AGENT role
            require(checkHasRole(msg.sender, ESCROW_AGENT), "Physical NFT secondary listings require ESCROW_AGENT role");
        } else if (nft != _tokenAddress) {
            // Is external NFT, require that listing external NFTs is enabled
            bool isEnabled = marketController.getAllowExternalTokensOnSecondary();
            require(isEnabled, "Listing external tokens is not currently enabled");
        }

        // Make sure supply is non-zero
        require (_supply > 0, "Supply must be non-zero");

        // Make sure this contract is approved to transfer the token
        // N.B. The following will work because isApprovedForAll has the same signature on both IERC721 and IERC1155
        require(IERC1155Upgradeable(_tokenAddress).isApprovedForAll(msg.sender, address(this)), "Not approved to transfer seller's tokens");

        // To register the consignment, tokens must first be in MarketController's possession
        if (IERC165Upgradeable(_tokenAddress).supportsInterface(type(IERC1155Upgradeable).interfaceId)) {

            // Ensure seller owns sufficient supply of token
            require(IERC1155Upgradeable(_tokenAddress).balanceOf(msg.sender, _tokenId) >= _supply, "Seller has insufficient balance of token");

            // Transfer supply to MarketController
            IERC1155Upgradeable(_tokenAddress).safeTransferFrom(
                msg.sender,
                address(getMarketController()),
                _tokenId,
                _supply,
                new bytes(0x0)
            );

        } else {

            require(_supply == 1, "ERC721 listings must use a supply of 1");

            // Token must be a single token NFT
            require(IERC165Upgradeable(_tokenAddress).supportsInterface(type(IERC721Upgradeable).interfaceId), "Invalid token type");

            // Transfer tokenId to MarketController
            IERC721Upgradeable(_tokenAddress).safeTransferFrom(
                msg.sender,
                address(getMarketController()),
                _tokenId
            );

        }

        // Register consignment
        Consignment memory consignment = getMarketController().registerConsignment(Market.Secondary, msg.sender, _seller, _tokenAddress, _tokenId, _supply);
        // Secondaries are marketed directly after registration
        getMarketController().marketConsignment(consignment.id, MarketHandler.Sale);

        // Set up the sale
        setAudience(consignment.id, _audience);
        Sale storage sale = mhs.sales[consignment.id];
        sale.consignmentId = consignment.id;
        sale.start = _start;
        sale.price = _price;
        sale.perTxCap = _perTxCap;
        sale.state = State.Pending;
        sale.outcome = Outcome.Pending;

        // Notify listeners of state change
        emit SalePending(msg.sender, consignment.seller, sale);
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
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

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721Upgradeable is IERC165Upgradeable {
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";

/**
 * @title IEscrowTicketer
 *
 * @notice Manages the issue and claim of escrow tickets.
 *
 * The ERC-165 identifier for this interface is: 0x73811679
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IEscrowTicketer {

    event TicketIssued(uint256 ticketId, uint256 indexed consignmentId, address indexed buyer, uint256 amount);
    event TicketClaimed(uint256 ticketId, address indexed claimant, uint256 amount);

    /**
     * @notice The nextTicket getter
     */
    function getNextTicket() external view returns (uint256);

    /**
     * @notice Get info about the ticket
     */
    function getTicket(uint256 _ticketId) external view returns (SeenTypes.EscrowTicket memory);

    /**
     * @notice Get how many claims can be made using tickets (does not change after ticket burns)
     */
    function getTicketClaimableCount(uint256 _consignmentId) external view returns (uint256);

    /**
     * @notice Gets the URI for the ticket metadata
     *
     * This method normalizes how you get the URI,
     * since ERC721 and ERC1155 differ in approach
     *
     * @param _ticketId - the token id of the ticket
     */
    function getTicketURI(uint256 _ticketId) external view returns (string memory);

    /**
     * Issue an escrow ticket to the buyer
     *
     * For physical consignments, Seen.Haus must hold the items in escrow
     * until the buyer(s) claim them.
     *
     * When a buyer wins an auction or makes a purchase in a sale, the market
     * handler contract they interacted with will call this method to issue an
     * escrow ticket, which is an NFT that can be sold, transferred, or claimed.
     *
     * @param _consignmentId - the id of the consignment being sold
     * @param _amount - the amount of the given token to escrow
     * @param _buyer - the buyer of the escrowed item(s) to whom the ticket is issued
     */
    function issueTicket(uint256 _consignmentId, uint256 _amount, address payable _buyer) external;

    /**
     * Claim the holder's escrowed items associated with the ticket.
     *
     * @param _ticketId - the ticket representing the escrowed items
     */
    function claim(uint256 _ticketId) external;

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";
import "./IMarketHandler.sol";

/**
 * @title ISaleBuilder
 *
 * @notice Handles the creation of Seen.Haus sales.
 *
 * The ERC-165 identifier for this interface is: 0x4811411a
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface ISaleBuilder is IMarketHandler {

    // Events
    event SalePending(address indexed consignor, address indexed seller, SeenTypes.Sale sale);

    /**
     * @notice The sale getter
     */
    function getSale(uint256 _consignmentId) external view returns (SeenTypes.Sale memory);

    /**
     * @notice Create a new sale.
     *
     * For some lot size of one ERC-1155 token.
     *
     * Ownership of the consigned inventory is transferred to this contract
     * for the duration of the sale.
     *
     * Reverts if:
     *  - Sale exists for consignment
     *  - Consignment has already been marketed
     *  - Sale start is zero
     *
     * Emits a SalePending event.
     *
     * @param _consignmentId - id of the consignment being sold
     * @param _start - the scheduled start time of the sale
     * @param _price - the price of each item in the lot
     * @param _perTxCap - the maximum amount that can be bought in a single transaction
     * @param _audience - the initial audience that can participate. See {SeenTypes.Audience}
     */
    function createPrimarySale (
        uint256 _consignmentId,
        uint256 _start,
        uint256 _price,
        uint256 _perTxCap,
        SeenTypes.Audience _audience
    ) external;

    /**
     * @notice Create a new sale.
     *
     * For some lot size of one ERC-1155 token.
     *
     * Ownership of the consigned inventory is transferred to this contract
     * for the duration of the sale.
     *
     * Reverts if:
     *  - Sale exists for consignment
     *  - Sale start is zero
     *  - This contract isn't approved to transfer seller's tokens
     *
     * Emits a SalePending event.
     *
     * @param _seller - the current owner of the consignment
     * @param _tokenAddress - the contract address issuing the NFT behind the consignment
     * @param _tokenId - the id of the token being consigned
     * @param _start - the scheduled start time of the sale
     * @param _supply - the supply of the given consigned token being sold
     * @param _price - the price of each item in the lot
     * @param _perTxCap - the maximum amount that can be bought in a single transaction
     * @param _audience - the initial audience that can participate. See {SeenTypes.Audience}
     */
    function createSecondarySale (
        address payable _seller,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _start,
        uint256 _supply,
        uint256 _price,
        uint256 _perTxCap,
        SeenTypes.Audience _audience
    ) external;

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/ISaleBuilder.sol";
import "../interfaces/ISaleRunner.sol";
import "../interfaces/ISaleEnder.sol";

/**
 * @title ISaleHandler
 *
 * @notice Handles the creation, running, and disposition of Seen.Haus sales.
 *
 * The ERC-165 identifier for this interface is: 0xa9ae54df
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface ISaleHandler is ISaleBuilder, ISaleRunner, ISaleEnder {}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";
import "./IMarketHandler.sol";

/**
 * @title ISaleRunner
 *
 * @notice Handles the operation of Seen.Haus sales.
 *
 * The ERC-165 identifier for this interface is: 0xe1bf15c5
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface ISaleRunner is IMarketHandler {

    // Events
    event SaleStarted(uint256 indexed consignmentId);
    event Purchase(uint256 indexed consignmentId, address indexed buyer, uint256 amount, uint256 value);
    event TokenHistoryTracker(address indexed tokenAddress, uint256 indexed tokenId, address indexed buyer, uint256 value, uint256 amount, uint256 consignmentId);

    /**
     * @notice Change the audience for a sale.
     *
     * Reverts if:
     *  - Caller does not have ADMIN role
     *  - Auction doesn't exist or has already been settled
     *
     * @param _consignmentId - the id of the consignment being sold
     * @param _audience - the new audience for the sale
     */
    function changeSaleAudience(uint256 _consignmentId, SeenTypes.Audience _audience) external;

    /**
     * @notice Buy some amount of the remaining supply of the lot for sale.
     *
     * Ownership of the purchased inventory is transferred to the buyer.
     * The buyer's payment will be held for disbursement when sale is settled.
     *
     * Reverts if:
     *  - Caller is not in audience
     *  - Sale doesn't exist or hasn't started
     *  - Caller is a contract
     *  - The per-transaction buy limit is exceeded
     *  - Payment doesn't cover the order price
     *
     * Emits a Purchase event.
     * May emit a SaleStarted event, on the first purchase.
     *
     * @param _consignmentId - id of the consignment being sold
     * @param _amount - the amount of the remaining supply to buy
     */
    function buy(uint256 _consignmentId, uint256 _amount) external payable;

    /**
     * @notice Claim a pending payout on an ongoing sale without closing/cancelling
     *
     * Funds are disbursed as normal. See: {MarketHandlerBase.disburseFunds}
     *
     * Reverts if:
     * - Sale doesn't exist or hasn't started
     * - There is no pending payout
     * - Called by any address other than seller
     * - The sale is sold out (in which case closeSale should be called)
     *
     * Does not emit its own event, but disburseFunds emits an event
     *
     * @param _consignmentId - id of the consignment being sold
     */
    function claimPendingPayout(uint256 _consignmentId) external;

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "../domain/SeenTypes.sol";
import "./IERC2981.sol";

/**
 * @title ISeenHausNFT
 *
 * @notice This is the interface for the Seen.Haus ERC-1155 NFT contract.
 *
 * The ERC-165 identifier for this interface is: 0x34d6028b
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
*/
interface ISeenHausNFT is IERC2981, IERC1155Upgradeable {

    /**
     * @notice The nextToken getter
     * @dev does not increment counter
     */
    function getNextToken() external view returns (uint256 nextToken);

    /**
     * @notice Get the info about a given token.
     *
     * @param _tokenId - the id of the token to check
     * @return tokenInfo - the info about the token. See: {SeenTypes.Token}
     */
    function getTokenInfo(uint256 _tokenId) external view returns (SeenTypes.Token memory tokenInfo);

    /**
     * @notice Check if a given token id corresponds to a physical lot.
     *
     * @param _tokenId - the id of the token to check
     * @return physical - true if the item corresponds to a physical lot
     */
    function isPhysical(uint256 _tokenId) external returns (bool);

    /**
     * @notice Mint a given supply of a token, marking it as physical.
     *
     * Entire supply must be minted at once.
     * More cannot be minted later for the same token id.
     * Can only be called by an address with the ESCROW_AGENT role.
     * Token supply is sent to the caller.
     *
     * @param _supply - the supply of the token
     * @param _creator - the creator of the NFT (where the royalties will go)
     * @param _tokenURI - the URI of the token metadata
     *
     * @return consignment - the registered primary market consignment of the newly minted token
     */
    function mintPhysical(
        uint256 _supply,
        address payable _creator,
        string memory _tokenURI,
        uint16 _royaltyPercentage
    )
    external
    returns(SeenTypes.Consignment memory consignment);

    /**
     * @notice Mint a given supply of a token.
     *
     * Entire supply must be minted at once.
     * More cannot be minted later for the same token id.
     * Can only be called by an address with the MINTER role.
     * Token supply is sent to the caller's address.
     *
     * @param _supply - the supply of the token
     * @param _creator - the creator of the NFT (where the royalties will go)
     * @param _tokenURI - the URI of the token metadata
     *
     * @return consignment - the registered primary market consignment of the newly minted token
     */
    function mintDigital(
        uint256 _supply,
        address payable _creator,
        string memory _tokenURI,
        uint16 _royaltyPercentage
    )
    external
    returns(SeenTypes.Consignment memory consignment);

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() external view returns (address);

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() external;

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) external;

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../interfaces/IMarketController.sol";
import "../../interfaces/IMarketHandler.sol";
import "../../interfaces/ISeenHausNFT.sol";
import "../../domain/SeenConstants.sol";
import "../../interfaces/IERC2981.sol";
import "../../domain/SeenTypes.sol";
import "./MarketHandlerLib.sol";

/**
 * @title MarketHandlerBase
 *
 * @notice Provides base functionality for common actions taken by market handlers.
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
abstract contract MarketHandlerBase is IMarketHandler, SeenTypes, SeenConstants {

    /**
     * @dev Modifier that checks that the caller has a specific role.
     *
     * Reverts if caller doesn't have role.
     *
     * See: {AccessController.hasRole}
     */
    modifier onlyRole(bytes32 _role) {
        DiamondLib.DiamondStorage storage ds = DiamondLib.diamondStorage();
        require(ds.accessController.hasRole(_role, msg.sender), "Caller doesn't have role");
        _;
    }

    /**
     * @dev Modifier that checks that the caller has a specific role or is a consignor.
     *
     * Reverts if caller doesn't have role or is not consignor.
     *
     * See: {AccessController.hasRole}
     */
    modifier onlyRoleOrConsignor(bytes32 _role, uint256 _consignmentId) {
        DiamondLib.DiamondStorage storage ds = DiamondLib.diamondStorage();
        require(ds.accessController.hasRole(_role, msg.sender) || getMarketController().getConsignor(_consignmentId) == msg.sender, "Caller doesn't have role or is not consignor");
        _;
    }

    /**
     * @dev Function that checks that the caller has a specific role.
     *
     * Reverts if caller doesn't have role.
     *
     * See: {AccessController.hasRole}
     */
    function checkHasRole(address _address, bytes32 _role) internal view returns (bool) {
        DiamondLib.DiamondStorage storage ds = DiamondLib.diamondStorage();
        return ds.accessController.hasRole(_role, _address);
    }

    /**
     * @notice Gets the address of the Seen.Haus MarketController contract.
     *
     * @return marketController - the address of the MarketController contract
     */
    function getMarketController()
    internal
    view
    returns(IMarketController marketController)
    {
        return IMarketController(address(this));
    }

    /**
     * @notice Sets the audience for a consignment at sale or auction.
     *
     * Emits an AudienceChanged event.
     *
     * @param _consignmentId - the id of the consignment
     * @param _audience - the new audience for the consignment
     */
    function setAudience(uint256 _consignmentId, Audience _audience)
    internal
    {
        MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();

        // Set the new audience
        mhs.audiences[_consignmentId] = _audience;

        // Notify listeners of state change
        emit AudienceChanged(_consignmentId, _audience);

    }

    /**
     * @notice Check if the caller is a Staker.
     *
     * @return status - true if caller's xSEEN ERC-20 balance is non-zero.
     */
    function isStaker()
    internal
    view
    returns (bool status)
    {
        IMarketController marketController = getMarketController();
        status = IERC20Upgradeable(marketController.getStaking()).balanceOf(msg.sender) > 0;
    }

    /**
     * @notice Check if the caller is a VIP Staker.
     *
     * See {MarketController:vipStakerAmount}
     *
     * @return status - true if caller's xSEEN ERC-20 balance is at least equal to the VIP Staker Amount.
     */
    function isVipStaker()
    internal
    view
    returns (bool status)
    {
        IMarketController marketController = getMarketController();
        status = IERC20Upgradeable(marketController.getStaking()).balanceOf(msg.sender) >= marketController.getVipStakerAmount();
    }

    /**
     * @notice Modifier that checks that caller is in consignment's audience
     *
     * Reverts if user is not in consignment's audience
     */
    modifier onlyAudienceMember(uint256 _consignmentId) {
        MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();
        Audience audience = mhs.audiences[_consignmentId];
        if (audience != Audience.Open) {
            if (audience == Audience.Staker) {
                require(isStaker());
            } else if (audience == Audience.VipStaker) {
                require(isVipStaker());
            }
        }
        _;
    }

    /**
     * @dev Modifier that checks that the caller is the consignor
     *
     * Reverts if caller isn't the consignor
     *
     * See: {MarketController.getConsignor}
     */
    modifier onlyConsignor(uint256 _consignmentId) {

        // Make sure the caller is the consignor
        require(getMarketController().getConsignor(_consignmentId) == msg.sender, "Caller is not consignor");
        _;
    }

    /**
     * @notice Get a percentage of a given amount.
     *
     * N.B. Represent ercentage values are stored
     * as unsigned integers, the result of multiplying the given percentage by 100:
     * e.g, 1.75% = 175, 100% = 10000
     *
     * @param _amount - the amount to return a percentage of
     * @param _percentage - the percentage value represented as above
     */
    function getPercentageOf(uint256 _amount, uint16 _percentage)
    internal
    pure
    returns (uint256 share)
    {
        share = _amount * _percentage / 10000;
    }

    /**
     * @notice Deduct and pay royalties on sold secondary market consignments.
     *
     * Does nothing is this is a primary market sale.
     *
     * If the consigned item's contract supports NFT Royalty Standard EIP-2981,
     * it is queried for the expected royalty amount and recipient.
     *
     * Deducts royalty and pays to recipient:
     * - entire expected amount, if below or equal to the marketplace's maximum royalty percentage
     * - the marketplace's maximum royalty percentage See: {MarketController.maxRoyaltyPercentage}
     *
     * Emits a RoyaltyDisbursed event with the amount actually paid.
     *
     * @param _consignment - the consigned item
     * @param _grossSale - the gross sale amount
     *
     * @return net - the net amount of the sale after the royalty has been paid
     */
    function deductRoyalties(Consignment memory _consignment, uint256 _grossSale)
    internal
    returns (uint256 net)
    {
        // Only pay royalties on secondary market sales
        uint256 royaltyAmount = 0;
        if (_consignment.market == Market.Secondary) {
            // Determine if NFT contract supports NFT Royalty Standard EIP-2981
            try IERC165Upgradeable(_consignment.tokenAddress).supportsInterface(type(IERC2981).interfaceId) returns (bool supported) {

                // If so, find out the who to pay and how much
                if (supported) {

                    // Get the MarketController
                    IMarketController marketController = getMarketController();

                    // Get the royalty recipient and expected payment
                    (address recipient, uint256 expected) = IERC2981(_consignment.tokenAddress).royaltyInfo(_consignment.tokenId, _grossSale);

                    // Determine the max royalty we will pay
                    uint256 maxRoyalty = getPercentageOf(_grossSale, marketController.getMaxRoyaltyPercentage());

                    // If a royalty is expected...
                    if (expected > 0) {

                        // Lets pay, but only up to our platform policy maximum
                        royaltyAmount = (expected <= maxRoyalty) ? expected : maxRoyalty;
                        sendValueOrCreditAccount(payable(recipient), royaltyAmount);

                        // Notify listeners of payment
                        emit RoyaltyDisbursed(_consignment.id, recipient, royaltyAmount);
                    }

                }

            // Any case where the check for interface support fails can be ignored
            } catch Error(string memory) {
            } catch (bytes memory) {
            }

        }

        // Return the net amount after royalty deduction
        net = _grossSale - royaltyAmount;
    }

    /**
     * @notice Deduct and pay escrow agent fees on sold physical secondary market consignments.
     *
     * Does nothing if this is a primary market sale.
     *
     * Deducts escrow agent fee and pays to consignor
     * - entire expected amount
     *
     * Emits a EscrowAgentFeeDisbursed event with the amount actually paid.
     *
     * @param _consignment - the consigned item
     * @param _grossSale - the gross sale amount
     * @param _netAfterRoyalties - the funds left to be distributed
     *
     * @return net - the net amount of the sale after the royalty has been paid
     */
    function deductEscrowAgentFee(Consignment memory _consignment, uint256 _grossSale, uint256 _netAfterRoyalties)
    internal
    returns (uint256 net)
    {
        // Only pay royalties on secondary market sales
        uint256 escrowAgentFeeAmount = 0;
        if (_consignment.market == Market.Secondary) {
            // Get the MarketController
            IMarketController marketController = getMarketController();
            address consignor = marketController.getConsignor(_consignment.id);
            if(consignor != _consignment.seller) {
                uint16 escrowAgentBasisPoints = marketController.getEscrowAgentFeeBasisPoints(consignor);
                if(escrowAgentBasisPoints > 0) {
                    // Determine if consignment is physical
                    address nft = marketController.getNft();
                    if (nft == _consignment.tokenAddress && ISeenHausNFT(nft).isPhysical(_consignment.tokenId)) {
                        // Consignor is not seller, consigner has a positive escrowAgentBasisPoints value, consignment is of a physical item
                        // Therefore, pay consignor the escrow agent fees
                        escrowAgentFeeAmount = getPercentageOf(_grossSale, escrowAgentBasisPoints);

                        // If escrow agent fee is expected...
                        if (escrowAgentFeeAmount > 0) {
                            require(escrowAgentFeeAmount <= _netAfterRoyalties, "escrowAgentFeeAmount exceeds remaining funds");
                            sendValueOrCreditAccount(payable(consignor), escrowAgentFeeAmount);
                            // Notify listeners of payment
                            emit EscrowAgentFeeDisbursed(_consignment.id, consignor, escrowAgentFeeAmount);
                        }
                    }
                }
            }
        }

        // Return the net amount after royalty deduction
        net = _netAfterRoyalties - escrowAgentFeeAmount;
    }

    /**
     * @notice Deduct and pay fee on a sold consignment.
     *
     * Deducts marketplace fee and pays:
     * - Half to the staking contract
     * - Half to the multisig contract
     *
     * Emits a FeeDisbursed event for staking payment.
     * Emits a FeeDisbursed event for multisig payment.
     *
     * @param _consignment - the consigned item
     * @param _grossSale - the gross sale amount
     * @param _netAmount - the net amount after royalties (total remaining to be distributed as part of payout process)
     *
     * @return payout - the payout amount for the seller
     */
    function deductFee(Consignment memory _consignment, uint256 _grossSale, uint256 _netAmount)
    internal
    returns (uint256 payout)
    {
        // Get the MarketController
        IMarketController marketController = getMarketController();

        // With the net after royalties, calculate and split
        // the auction fee between SEEN staking and multisig,
        uint256 feeAmount;
        if(_consignment.customFeePercentageBasisPoints > 0) {
            feeAmount = getPercentageOf(_grossSale, _consignment.customFeePercentageBasisPoints);
        } else {
            feeAmount = getPercentageOf(_grossSale, marketController.getFeePercentage(_consignment.market));
        }
        require(feeAmount <= _netAmount, "feeAmount exceeds remaining funds");
        uint256 splitStaking = feeAmount / 2;
        uint256 splitMultisig = feeAmount - splitStaking;
        address payable staking = marketController.getStaking();
        address payable multisig = marketController.getMultisig();
        sendValueOrCreditAccount(staking, splitStaking);
        sendValueOrCreditAccount(multisig, splitMultisig);

        // Return the seller payout amount after fee deduction
        payout = _netAmount - feeAmount;

        // Notify listeners of payment
        emit FeeDisbursed(_consignment.id, staking, splitStaking);
        emit FeeDisbursed(_consignment.id, multisig, splitMultisig);
    }

    /**
     * @notice Disburse funds for a sale or auction, primary or secondary.
     *
     * Disburses funds in this order
     * - Pays any necessary royalties first. See {deductRoyalties}
     * - Deducts and distributes marketplace fee. See {deductFee}
     * - Pays the remaining amount to the seller.
     *
     * Emits a PayoutDisbursed event on success.
     *
     * @param _consignmentId - the id of the consignment being sold
     * @param _saleAmount - the gross sale amount
     */
    function disburseFunds(uint256 _consignmentId, uint256 _saleAmount)
    internal
    {
        // Get the MarketController
        IMarketController marketController = getMarketController();

        // Get consignment
        SeenTypes.Consignment memory consignment = marketController.getConsignment(_consignmentId);

        // Pay royalties if needed
        uint256 netAfterRoyalties = deductRoyalties(consignment, _saleAmount);

        // Pay escrow agent fees if needed
        uint256 netAfterEscrowAgentFees = deductEscrowAgentFee(consignment, _saleAmount, netAfterRoyalties);

        // Pay marketplace fee
        uint256 payout = deductFee(consignment, _saleAmount, netAfterEscrowAgentFees);

        // Pay seller
        sendValueOrCreditAccount(consignment.seller, payout);

        // Notify listeners of payment
        emit PayoutDisbursed(_consignmentId, consignment.seller, payout);
    }

    /**
     * @notice Attempts an ETH transfer, else adds a pull-able credit
     *
     * In cases where ETH is unable to be transferred to a particular address
     * either due to malicious agents or bugs in receiver addresses
     * the payout process should not fail for all parties involved 
     * (or funds can become stuck for benevolent parties)
     *
     * @param _recipient - the recipient of the transfer
     * @param _value - the transfer value
     */
    function sendValueOrCreditAccount(address payable _recipient, uint256 _value)
    internal
    {
        // Attempt to send funds to recipient
        require(address(this).balance >= _value);
        (bool success, ) = _recipient.call{value: _value}("");
        if(!success) {
            // Credit the account
            MarketHandlerLib.MarketHandlerStorage storage mhs = MarketHandlerLib.marketHandlerStorage();
            mhs.addressToEthCredit[_recipient] += _value;
            emit EthCredited(_recipient, _value);
        }
    }

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
interface IERC165Upgradeable {
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title SeenTypes
 *
 * @notice Enums and structs used by the Seen.Haus contract ecosystem.
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract SeenTypes {

    enum Market {
        Primary,
        Secondary
    }

    enum MarketHandler {
        Unhandled,
        Auction,
        Sale
    }

    enum Clock {
        Live,
        Trigger
    }

    enum Audience {
        Open,
        Staker,
        VipStaker
    }

    enum Outcome {
        Pending,
        Closed,
        Canceled
    }

    enum State {
        Pending,
        Running,
        Ended
    }

    enum Ticketer {
        Default,
        Lots,
        Items
    }

    struct Token {
        address payable creator;
        uint16 royaltyPercentage;
        bool isPhysical;
        uint256 id;
        uint256 supply;
        string uri;
    }

    struct Consignment {
        Market market;
        MarketHandler marketHandler;
        address payable seller;
        address tokenAddress;
        uint256 tokenId;
        uint256 supply;
        uint256 id;
        bool multiToken;
        bool released;
        uint256 releasedSupply;
        uint16 customFeePercentageBasisPoints;
        uint256 pendingPayout;
    }

    struct Auction {
        address payable buyer;
        uint256 consignmentId;
        uint256 start;
        uint256 duration;
        uint256 reserve;
        uint256 bid;
        Clock clock;
        State state;
        Outcome outcome;
    }

    struct Sale {
        uint256 consignmentId;
        uint256 start;
        uint256 price;
        uint256 perTxCap;
        State state;
        Outcome outcome;
    }

    struct EscrowTicket {
        uint256 amount;
        uint256 consignmentId;
        uint256 id;
        string itemURI;
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";

/**
 * @title IMarketHandler
 *
 * @notice Provides no functions, only common events to market handler facets.
 *
 * No ERC-165 identifier for this interface, not checked or supported.
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IMarketHandler {

    // Events
    event RoyaltyDisbursed(uint256 indexed consignmentId, address indexed recipient, uint256 amount);
    event EscrowAgentFeeDisbursed(uint256 indexed consignmentId, address indexed recipient, uint256 amount);
    event FeeDisbursed(uint256 indexed consignmentId, address indexed recipient, uint256 amount);
    event PayoutDisbursed(uint256 indexed consignmentId, address indexed recipient, uint256 amount);
    event AudienceChanged(uint256 indexed consignmentId, SeenTypes.Audience indexed audience);
    event EthCredited(address indexed recipient, uint256 amount);

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";
import "./IMarketHandler.sol";

/**
 * @title ISaleEnder
 *
 * @notice Handles the finalization of Seen.Haus sales.
 *
 * The ERC-165 identifier for this interface is: 0x19b68d56
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface ISaleEnder is IMarketHandler {

    // Events
    event SaleEnded(uint256 indexed consignmentId, SeenTypes.Outcome indexed outcome);

    /**
     * @notice Close out a successfully completed sale.
     *
     * Funds are disbursed as normal. See: {MarketHandlerBase.disburseFunds}
     *
     * Reverts if:
     * - Sale doesn't exist or hasn't started
     * - There is remaining inventory
     *
     * Emits a SaleEnded event.
     *
     * @param _consignmentId - id of the consignment being sold
     */
    function closeSale(uint256 _consignmentId) external;

    /**
     * @notice Cancel a sale that has remaining inventory.
     *
     * Remaining tokens are returned to seller. If there have been any purchases,
     * the funds are distributed normally.
     *
     * Reverts if:
     * - Caller doesn't have ADMIN role
     * - Sale doesn't exist or has already been settled
     *
     * Emits a SaleEnded event
     *
     * @param _consignmentId - id of the consignment being sold
     */
    function cancelSale(uint256 _consignmentId) external;

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

/**
 * @title IERC2981 interface
 *
 * @notice NFT Royalty Standard.
 *
 * See https://eips.ethereum.org/EIPS/eip-2981
 */
interface IERC2981 is IERC165Upgradeable {

    /**
     * @notice Determine how much royalty is owed (if any) and to whom.
     * @param _tokenId - the NFT asset queried for royalty information
     * @param _salePrice - the sale price of the NFT asset specified by _tokenId
     * @return receiver - address of who should be sent the royalty payment
     * @return royaltyAmount - the royalty payment amount for _salePrice
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
    external
    view
    returns (
        address receiver,
        uint256 royaltyAmount
    );

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./IMarketConfig.sol";
import "./IMarketConfigAdditional.sol";
import "./IMarketClerk.sol";

/**
 * @title IMarketController
 *
 * @notice Manages configuration and consignments used by the Seen.Haus contract suite.
 *
 * The ERC-165 identifier for this interface is: 0xbb8dba77
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IMarketController is IMarketClerk, IMarketConfig, IMarketConfigAdditional {}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title SeenConstants
 *
 * @notice Constants used by the Seen.Haus contract ecosystem.
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
contract SeenConstants {

    // Endpoint will serve dynamic metadata composed of ticket and ticketed item's info
    string internal constant ESCROW_TICKET_URI = "https://api.seen.haus/ticket/metadata/";

    // Access Control Roles
    bytes32 internal constant ADMIN = keccak256("ADMIN");                   // Deployer and any other admins as needed
    bytes32 internal constant SELLER = keccak256("SELLER");                 // Approved sellers amd Seen.Haus reps
    bytes32 internal constant MINTER = keccak256("MINTER");                 // Approved artists and Seen.Haus reps
    bytes32 internal constant ESCROW_AGENT = keccak256("ESCROW_AGENT");     // Seen.Haus Physical Item Escrow Agent
    bytes32 internal constant MARKET_HANDLER = keccak256("MARKET_HANDLER"); // Market Handler contracts
    bytes32 internal constant UPGRADER = keccak256("UPGRADER");             // Performs contract upgrades
    bytes32 internal constant MULTISIG = keccak256("MULTISIG");             // Admin role of MARKET_HANDLER & UPGRADER

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../interfaces/IMarketController.sol";
import "../../domain/SeenTypes.sol";
import "../diamond/DiamondLib.sol";

/**
 * @title MarketHandlerLib
 *
 * @dev Provides access to the the MarketHandler Storage and Intitializer slots for MarketHandler facets
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
library MarketHandlerLib {

    bytes32 constant MARKET_HANDLER_STORAGE_POSITION = keccak256("seen.haus.market.handler.storage");
    bytes32 constant MARKET_HANDLER_INITIALIZERS_POSITION = keccak256("seen.haus.market.handler.initializers");

    struct MarketHandlerStorage {

        // map a consignment id to an audience
        mapping(uint256 => SeenTypes.Audience) audiences;

        //s map a consignment id to a sale
        mapping(uint256 => SeenTypes.Sale) sales;

        // @dev map a consignment id to an auction
        mapping(uint256 => SeenTypes.Auction) auctions;

        // map an address to ETH credit available to withdraw
        mapping(address => uint256) addressToEthCredit;

    }

    struct MarketHandlerInitializers {

        // AuctionBuilderFacet initialization state
        bool auctionBuilderFacet;

        // AuctionRunnerFacet initialization state
        bool auctionRunnerFacet;

        // AuctionEnderFacet initialization state
        bool auctionEnderFacet;

        // SaleBuilderFacet initialization state
        bool saleBuilderFacet;

        // SaleRunnerFacet initialization state
        bool saleRunnerFacet;

        // SaleRunnerFacet initialization state
        bool saleEnderFacet;

        // EthCreditFacet initialization state
        bool ethCreditRecoveryFacet;

    }

    function marketHandlerStorage() internal pure returns (MarketHandlerStorage storage mhs) {
        bytes32 position = MARKET_HANDLER_STORAGE_POSITION;
        assembly {
            mhs.slot := position
        }
    }

    function marketHandlerInitializers() internal pure returns (MarketHandlerInitializers storage mhi) {
        bytes32 position = MARKET_HANDLER_INITIALIZERS_POSITION;
        assembly {
            mhi.slot := position
        }
    }

}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";

/**
 * @title IMarketController
 *
 * @notice Manages configuration and consignments used by the Seen.Haus contract suite.
 * @dev Contributes its events and functions to the IMarketController interface
 *
 * The ERC-165 identifier for this interface is: 0x57f9f26d
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IMarketConfig {

    /// Events
    event NFTAddressChanged(address indexed nft);
    event EscrowTicketerAddressChanged(address indexed escrowTicketer, SeenTypes.Ticketer indexed ticketerType);
    event StakingAddressChanged(address indexed staking);
    event MultisigAddressChanged(address indexed multisig);
    event VipStakerAmountChanged(uint256 indexed vipStakerAmount);
    event PrimaryFeePercentageChanged(uint16 indexed feePercentage);
    event SecondaryFeePercentageChanged(uint16 indexed feePercentage);
    event MaxRoyaltyPercentageChanged(uint16 indexed maxRoyaltyPercentage);
    event OutBidPercentageChanged(uint16 indexed outBidPercentage);
    event DefaultTicketerTypeChanged(SeenTypes.Ticketer indexed ticketerType);

    /**
     * @notice Sets the address of the xSEEN ERC-20 staking contract.
     *
     * Emits a NFTAddressChanged event.
     *
     * @param _nft - the address of the nft contract
     */
    function setNft(address _nft) external;

    /**
     * @notice The nft getter
     */
    function getNft() external view returns (address);

    /**
     * @notice Sets the address of the Seen.Haus lots-based escrow ticketer contract.
     *
     * Emits a EscrowTicketerAddressChanged event.
     *
     * @param _lotsTicketer - the address of the items-based escrow ticketer contract
     */
    function setLotsTicketer(address _lotsTicketer) external;

    /**
     * @notice The lots-based escrow ticketer getter
     */
    function getLotsTicketer() external view returns (address);

    /**
     * @notice Sets the address of the Seen.Haus items-based escrow ticketer contract.
     *
     * Emits a EscrowTicketerAddressChanged event.
     *
     * @param _itemsTicketer - the address of the items-based escrow ticketer contract
     */
    function setItemsTicketer(address _itemsTicketer) external;

    /**
     * @notice The items-based escrow ticketer getter
     */
    function getItemsTicketer() external view returns (address);

    /**
     * @notice Sets the address of the xSEEN ERC-20 staking contract.
     *
     * Emits a StakingAddressChanged event.
     *
     * @param _staking - the address of the staking contract
     */
    function setStaking(address payable _staking) external;

    /**
     * @notice The staking getter
     */
    function getStaking() external view returns (address payable);

    /**
     * @notice Sets the address of the Seen.Haus multi-sig wallet.
     *
     * Emits a MultisigAddressChanged event.
     *
     * @param _multisig - the address of the multi-sig wallet
     */
    function setMultisig(address payable _multisig) external;

    /**
     * @notice The multisig getter
     */
    function getMultisig() external view returns (address payable);

    /**
     * @notice Sets the VIP staker amount.
     *
     * Emits a VipStakerAmountChanged event.
     *
     * @param _vipStakerAmount - the minimum amount of xSEEN ERC-20 a caller must hold to participate in VIP events
     */
    function setVipStakerAmount(uint256 _vipStakerAmount) external;

    /**
     * @notice The vipStakerAmount getter
     */
    function getVipStakerAmount() external view returns (uint256);

    /**
     * @notice Sets the marketplace fee percentage.
     * Emits a PrimaryFeePercentageChanged event.
     *
     * @param _primaryFeePercentage - the percentage that will be taken as a fee from the net of a Seen.Haus primary sale or auction
     *
     * N.B. Represent percentage value as an unsigned int by multiplying the percentage by 100:
     * e.g, 1.75% = 175, 100% = 10000
     */
    function setPrimaryFeePercentage(uint16 _primaryFeePercentage) external;

    /**
     * @notice Sets the marketplace fee percentage.
     * Emits a SecondaryFeePercentageChanged event.
     *
     * @param _secondaryFeePercentage - the percentage that will be taken as a fee from the net of a Seen.Haus secondary sale or auction (after royalties)
     *
     * N.B. Represent percentage value as an unsigned int by multiplying the percentage by 100:
     * e.g, 1.75% = 175, 100% = 10000
     */
    function setSecondaryFeePercentage(uint16 _secondaryFeePercentage) external;

    /**
     * @notice The primaryFeePercentage and secondaryFeePercentage getter
     */
    function getFeePercentage(SeenTypes.Market _market) external view returns (uint16);

    /**
     * @notice Sets the external marketplace maximum royalty percentage.
     *
     * Emits a MaxRoyaltyPercentageChanged event.
     *
     * @param _maxRoyaltyPercentage - the maximum percentage of a Seen.Haus sale or auction that will be paid as a royalty
     */
    function setMaxRoyaltyPercentage(uint16 _maxRoyaltyPercentage) external;

    /**
     * @notice The maxRoyaltyPercentage getter
     */
    function getMaxRoyaltyPercentage() external view returns (uint16);

    /**
     * @notice Sets the marketplace auction outbid percentage.
     *
     * Emits a OutBidPercentageChanged event.
     *
     * @param _outBidPercentage - the minimum percentage a Seen.Haus auction bid must be above the previous bid to prevail
     */
    function setOutBidPercentage(uint16 _outBidPercentage) external;

    /**
     * @notice The outBidPercentage getter
     */
    function getOutBidPercentage() external view returns (uint16);

    /**
     * @notice Sets the default escrow ticketer type.
     *
     * Emits a DefaultTicketerTypeChanged event.
     *
     * Reverts if _ticketerType is Ticketer.Default
     * Reverts if _ticketerType is already the defaultTicketerType
     *
     * @param _ticketerType - the new default escrow ticketer type.
     */
    function setDefaultTicketerType(SeenTypes.Ticketer _ticketerType) external;

    /**
     * @notice The defaultTicketerType getter
     */
    function getDefaultTicketerType() external view returns (SeenTypes.Ticketer);

    /**
     * @notice Get the Escrow Ticketer to be used for a given consignment
     *
     * If a specific ticketer has not been set for the consignment,
     * the default escrow ticketer will be returned.
     *
     * @param _consignmentId - the id of the consignment
     * @return ticketer = the address of the escrow ticketer to use
     */
    function getEscrowTicketer(uint256 _consignmentId) external view returns (address ticketer);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "../domain/SeenTypes.sol";

/**
 * @title IMarketController
 *
 * @notice Manages configuration and consignments used by the Seen.Haus contract suite.
 * @dev Contributes its events and functions to the IMarketController interface
 *
 * The ERC-165 identifier for this interface is: 0x57f9f26d
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IMarketConfigAdditional {

    /// Events
    event AllowExternalTokensOnSecondaryChanged(bool indexed status);
    event EscrowAgentFeeChanged(address indexed escrowAgent, uint16 fee);
    
    /**
     * @notice Sets whether or not external tokens can be listed on secondary market
     *
     * Emits an AllowExternalTokensOnSecondaryChanged event.
     *
     * @param _status - boolean of whether or not external tokens are allowed
     */
    function setAllowExternalTokensOnSecondary(bool _status) external;

    /**
     * @notice The allowExternalTokensOnSecondary getter
     */
    function getAllowExternalTokensOnSecondary() external view returns (bool status);

        /**
     * @notice The escrow agent fee getter
     */
    function getEscrowAgentFeeBasisPoints(address _escrowAgentAddress) external view returns (uint16);

    /**
     * @notice The escrow agent fee setter
     */
    function setEscrowAgentFeeBasisPoints(address _escrowAgentAddress, uint16 _basisPoints) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../domain/SeenTypes.sol";

/**
 * @title IMarketClerk
 *
 * @notice Manages consignments for the Seen.Haus contract suite.
 *
 * The ERC-165 identifier for this interface is: 0xec74481a
 *
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
interface IMarketClerk is IERC1155ReceiverUpgradeable, IERC721ReceiverUpgradeable {

    /// Events
    event ConsignmentTicketerChanged(uint256 indexed consignmentId, SeenTypes.Ticketer indexed ticketerType);
    event ConsignmentFeeChanged(uint256 indexed consignmentId, uint16 customConsignmentFee);
    event ConsignmentPendingPayoutSet(uint256 indexed consignmentId, uint256 amount);
    event ConsignmentRegistered(address indexed consignor, address indexed seller, SeenTypes.Consignment consignment);
    event ConsignmentMarketed(address indexed consignor, address indexed seller, uint256 indexed consignmentId);
    event ConsignmentReleased(uint256 indexed consignmentId, uint256 amount, address releasedTo);

    /**
     * @notice The nextConsignment getter
     */
    function getNextConsignment() external view returns (uint256);

    /**
     * @notice The consignment getter
     */
    function getConsignment(uint256 _consignmentId) external view returns (SeenTypes.Consignment memory);

    /**
     * @notice Get the remaining supply of the given consignment.
     *
     * @param _consignmentId - the id of the consignment
     * @return uint256 - the remaining supply held by the MarketController
     */
    function getUnreleasedSupply(uint256 _consignmentId) external view returns(uint256);

    /**
     * @notice Get the consignor of the given consignment
     *
     * @param _consignmentId - the id of the consignment
     * @return  address - consigner's address
     */
    function getConsignor(uint256 _consignmentId) external view returns(address);

    /**
     * @notice Registers a new consignment for sale or auction.
     *
     * Emits a ConsignmentRegistered event.
     *
     * @param _market - the market for the consignment. See {SeenTypes.Market}
     * @param _consignor - the address executing the consignment transaction
     * @param _seller - the seller of the consignment
     * @param _tokenAddress - the contract address issuing the NFT behind the consignment
     * @param _tokenId - the id of the token being consigned
     * @param _supply - the amount of the token being consigned
     *
     * @return Consignment - the registered consignment
     */
    function registerConsignment(
        SeenTypes.Market _market,
        address _consignor,
        address payable _seller,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _supply
    )
    external
    returns(SeenTypes.Consignment memory);

    /**
      * @notice Update consignment to indicate it has been marketed
      *
      * Emits a ConsignmentMarketed event.
      *
      * Reverts if consignment has already been marketed.
      * A consignment is considered as marketed if it has a marketHandler other than Unhandled. See: {SeenTypes.MarketHandler}
      *
      * @param _consignmentId - the id of the consignment
      */
    function marketConsignment(uint256 _consignmentId, SeenTypes.MarketHandler _marketHandler) external;

    /**
     * @notice Release the consigned item to a given address
     *
     * Emits a ConsignmentReleased event.
     *
     * Reverts if caller is does not have MARKET_HANDLER role.
     *
     * @param _consignmentId - the id of the consignment
     * @param _amount - the amount of the consigned supply to release
     * @param _releaseTo - the address to transfer the consigned token balance to
     */
    function releaseConsignment(uint256 _consignmentId, uint256 _amount, address _releaseTo) external;

    /**
     * @notice Clears the pending payout value of a consignment
     *
     * Emits a ConsignmentPayoutSet event.
     *
     * Reverts if:
     *  - caller is does not have MARKET_HANDLER role.
     *  - consignment doesn't exist
     *
     * @param _consignmentId - the id of the consignment
     * @param _amount - the amount of that the consignment's pendingPayout must be set to
     */
    function setConsignmentPendingPayout(uint256 _consignmentId, uint256 _amount) external;

    /**
     * @notice Set the type of Escrow Ticketer to be used for a consignment
     *
     * Default escrow ticketer is Ticketer.Lots. This only needs to be called
     * if overriding to Ticketer.Items for a given consignment.
     *
     * Emits a ConsignmentTicketerSet event.
     * Reverts if consignment is not registered.
     *
     * @param _consignmentId - the id of the consignment
     * @param _ticketerType - the type of ticketer to use. See: {SeenTypes.Ticketer}
     */
    function setConsignmentTicketer(uint256 _consignmentId, SeenTypes.Ticketer _ticketerType) external;

    /**
     * @notice Set a custom fee percentage on a consignment (e.g. for "official" SEEN x Artist drops)
     *
     * Default escrow ticketer is Ticketer.Lots. This only needs to be called
     * if overriding to Ticketer.Items for a given consignment.
     *
     * Emits a ConsignmentFeeChanged event.
     *
     * Reverts if consignment doesn't exist     *
     *
     * @param _consignmentId - the id of the consignment
     * @param _customFeePercentageBasisPoints - the custom fee percentage basis points to use
     *
     * N.B. _customFeePercentageBasisPoints percentage value as an unsigned int by multiplying the percentage by 100:
     * e.g, 1.75% = 175, 100% = 10000
     */
    function setConsignmentCustomFee(uint256 _consignmentId, uint16 _customFeePercentageBasisPoints) external;

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
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
pragma solidity ^0.8.0;

import { IAccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import { IDiamondCut } from "../../interfaces/IDiamondCut.sol";

/**
 * @title DiamondLib
 *
 * @notice Diamond storage slot and supported interfaces
 *
 * @notice Based on Nick Mudge's gas-optimized diamond-2 reference,
 * with modifications to support role-based access and management of
 * supported interfaces.
 *
 * Reference Implementation  : https://github.com/mudgen/diamond-2-hardhat
 * EIP-2535 Diamond Standard : https://eips.ethereum.org/EIPS/eip-2535
 *
 * N.B. Facet management functions from original `DiamondLib` were refactor/extracted
 * to JewelerLib, since business facets also use this library for access control and
 * managing supported interfaces.
 *
 * @author Nick Mudge <[email protected]> (https://twitter.com/mudgen)
 * @author Cliff Hall <[email protected]> (https://twitter.com/seaofarrows)
 */
library DiamondLib {

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

    struct DiamondStorage {

        // maps function selectors to the facets that execute the functions.
        // and maps the selectors to their position in the selectorSlots array.
        // func selector => address facet, selector position
        mapping(bytes4 => bytes32) facets;

        // array of slots of function selectors.
        // each slot holds 8 function selectors.
        mapping(uint256 => bytes32) selectorSlots;

        // The number of function selectors in selectorSlots
        uint16 selectorCount;

        // Used to query if a contract implements an interface.
        // Used to implement ERC-165.
        mapping(bytes4 => bool) supportedInterfaces;

        // The Seen.Haus AccessController
        IAccessControlUpgradeable accessController;

    }

    /**
     * @notice Get the Diamond storage slot
     *
     * @return ds - Diamond storage slot cast to DiamondStorage
     */
    function diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Add a supported interface to the Diamond
     *
     * @param _interfaceId - the interface to add
     */
    function addSupportedInterface(bytes4 _interfaceId) internal {

        // Get the DiamondStorage struct
        DiamondStorage storage ds = diamondStorage();

        // Flag the interfaces as supported
        ds.supportedInterfaces[_interfaceId] = true;
    }

    /**
     * @notice Implementation of ERC-165 interface detection standard.
     *
     * @param _interfaceId - the sighash of the given interface
     */
    function supportsInterface(bytes4 _interfaceId) internal view returns (bool) {

        // Get the DiamondStorage struct
        DiamondStorage storage ds = diamondStorage();

        // Return the value
        return ds.supportedInterfaces[_interfaceId] || false;
    }

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IDiamondCut
 *
 * @notice Diamond Facet management
 *
 * Reference Implementation  : https://github.com/mudgen/diamond-2-hardhat
 * EIP-2535 Diamond Standard : https://eips.ethereum.org/EIPS/eip-2535
 *
 * The ERC-165 identifier for this interface is: 0x1f931c1c
 *
 * @author Nick Mudge <[email protected]> (https://twitter.com/mudgen)
 */
interface IDiamondCut {

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    enum FacetCutAction {Add, Replace, Remove}

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Add/replace/remove any number of functions and
     * optionally execute a function with delegatecall
     *
     * _calldata is executed with delegatecall on _init
     *
     * @param _diamondCut Contains the facet addresses and function selectors
     * @param _init The address of the contract or facet to execute _calldata
     * @param _calldata A function call, including function selector and arguments
     */
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external;
}