// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTAuctionSale is Ownable, Pausable {
    uint256 public constant AUCTION_LENGTH = 14 days;
    uint256 public constant TIME_BUFFER = 4 hours;

    event PutOnAuction(
        uint256 nftTokenId,
        uint256 reservePrice,
        address seller
    );

    event BidPlaced(
        uint256 nftTokenId,
        address bidder,
        uint256 bidPrice,
        uint256 timestamp,
        uint256 transaction
    );

    event NFTClaimed(uint256 nftTokenId, address winner, uint256 price);

    event ReservePriceUpdated(
        uint256 nftTokenId,
        uint256 reservePrice,
        address seller
    );

    struct AuctionBid {
        address bidder;
        uint256 price;
    }

    struct Auction {
        address seller;
        uint256 reservePrice;
        uint256 endTime;
        AuctionBid bid;
    }

    mapping(uint256 => Auction) private auctions;

    address private escrowAccount;
    IERC721 private auctionToken;

    constructor(address _nftTokenAddress) {
        auctionToken = IERC721(_nftTokenAddress);
        require(
            auctionToken.supportsInterface(0x80ac58cd),
            "Auction token is not ERC721"
        );

        escrowAccount = _msgSender();
    }

    function updateEscrowAccount(address _escrowAccount) external onlyOwner {
        require(_escrowAccount != address(0x0), "Invalid account");
        require(
            auctionToken.isApprovedForAll(_escrowAccount, escrowAccount),
            "New EscrowAccount is not approved to transfer tokens"
        );
        escrowAccount = _escrowAccount;
    }

    function getRequiredBid(uint256 price) internal pure returns (uint256) {
        uint256 a = price + 10000000000000000; // 0.01 ether
        uint256 b = price + (price / 20); // 5%

        return a < b ? a : b;
    }

    function putOnAuction(uint256 nftTokenId) public whenNotPaused onlyOwner {
        require(
            auctions[nftTokenId].seller == address(0x0),
            "NFT already on Auction"
        );

        auctions[nftTokenId] = Auction(
            _msgSender(),
            10000000000000000,
            block.timestamp + AUCTION_LENGTH,
            AuctionBid(address(0x0), 0)
        );

        emit PutOnAuction(nftTokenId, 10000000000000000, _msgSender());
    }

    function putOnAuctionBulk(uint256 i, uint256 j)
        public
        whenNotPaused
        onlyOwner
    {
        while (i < j) {
            putOnAuction(i++);
        }
    }

    function distributeReward(uint256 nftTokenId) external {
        Auction storage _auction = auctions[nftTokenId];
        AuctionBid storage _bid = _auction.bid;

        require(
            _auction.endTime < block.timestamp,
            "Auction still in progress"
        );

        require(_bid.bidder != address(0x0), "No bids placed");
        require(_auction.reservePrice != 0, "Auction completed");

        _auction.reservePrice = 0;

        // Token transfer
        auctionToken.safeTransferFrom(escrowAccount, _bid.bidder, nftTokenId);

        // Seller fee
        payable(_auction.seller).transfer(_bid.price);

        emit NFTClaimed(nftTokenId, _bid.bidder, _bid.price);

        delete auctions[nftTokenId];
    }

    function bid(uint256 nftTokenId) external payable whenNotPaused {
        uint256 bidPrice = msg.value;

        Auction storage _auction = auctions[nftTokenId];
        AuctionBid storage _auctionBid = _auction.bid;

        require(_auction.seller != address(0x0), "Auction not found");
        require(_auction.seller != _msgSender(), "Seller cannot place bids");

        // Validate can place bids
        require(_auction.endTime >= block.timestamp, "Cannot place new bids");

        // first bid
        if (_auctionBid.price == 0) {
            // Validate bid price
            require(
                bidPrice >= getRequiredBid(_auction.reservePrice),
                "New bids needs to higher by 5% or 0.01 ether"
            );
            _auction.bid = AuctionBid(_msgSender(), bidPrice);
            // update auction if bid placed in last 15 minutes
            if (_auction.endTime - block.timestamp < 15 minutes) {
                _auction.endTime = _auction.endTime + TIME_BUFFER;
            }
            emit BidPlaced(
                nftTokenId,
                _msgSender(),
                bidPrice,
                block.timestamp,
                block.number
            );
            return;
        }

        // Validate bid price
        uint256 requiredBid = getRequiredBid(_auctionBid.price);
        require(
            bidPrice >= requiredBid,
            "New bids needs to higher by 5% or 0.01 ether"
        );

        // Previous bid
        AuctionBid memory prevBid = _auctionBid;

        // update storage bid
        _auction.bid.price = bidPrice;
        _auction.bid.bidder = _msgSender();

        // update auction if bid placed in last 15 minutes
        if (_auction.endTime - block.timestamp < 15 minutes) {
            _auction.endTime = _auction.endTime + TIME_BUFFER;
        }

        payable(prevBid.bidder).transfer(prevBid.price);
        emit BidPlaced(
            nftTokenId,
            _msgSender(),
            bidPrice,
            block.timestamp,
            block.number
        );
    }

    function getAuction(uint256 nftId) public view returns (Auction memory) {
        return auctions[nftId];
    }

    function getAuctionsBulk(uint256 i, uint256 j)
        public
        view
        returns (Auction[] memory)
    {
        Auction[] memory _auctions = new Auction[](j - i);
        for (; i < j; ++i) {
            _auctions[i] = auctions[i];
        }
        return _auctions;
    }

    /*
        Rescue any ERC-20 tokens (doesnt include ETH) that are sent to this contract mistakenly
    */
    function withdrawToken(address _token, uint256 _amount) public onlyOwner {
        IERC20(_token).transferFrom(address(this), owner(), _amount);
    }

    function selfDestruct(address adr) public onlyOwner whenPaused {
        selfdestruct(payable(adr));
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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