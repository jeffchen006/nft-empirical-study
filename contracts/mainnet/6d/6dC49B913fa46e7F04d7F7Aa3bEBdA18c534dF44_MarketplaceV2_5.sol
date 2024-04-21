// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./HasSecondarySaleFees.sol";

contract MarketplaceV2_5 is Ownable {
    using SafeERC20 for IERC20;

    enum TokenType {ERC1155, ERC721, ERC721Deprecated}

    struct nftToken {
        address collection;
        uint256 id;
        TokenType tokenType;
    }

    struct Position {
        nftToken nft;
        uint256 amount;
        uint256 price;
        address owner;
        address currency;
    }

    struct MarketplaceFee {
        bool customFee;
        uint16 buyerFee;
        uint16 sellerFee;
    }

    struct CollectionRoyalties {
        address recipient;
        uint256 fee;
    }

    mapping(uint256 => Position) public positions;
    uint256 public positionsCount = 0;

    address public marketplaceBeneficiaryAddress;
    mapping(address => MarketplaceFee) private marketplaceCollectionFee;
    mapping(address => CollectionRoyalties) private customCollectionRoyalties;

    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

    /**
     * @dev Emitted when changing `MarketplaceFee` for an `colection`.
     */
    event MarketplaceFeeChanged(
        address indexed colection,
        uint16 buyerFee,
        uint16 sellerFee
    );

    /**
     * @dev Emitted when changing custom `CollectionRoyalties` for an `colection`.
     */
    event CollectionRoyaltiesChanged(
        address indexed colection,
        address recipient,
        uint256 indexed amount
    );

    /**
     * @dev Emitted when `owner` puts `token` from `collection` on sale for `price` `currency` per one.
     */
    event NewPosition(
        address indexed owner,
        uint256 indexed id,
        address collection,
        uint256 token,
        uint256 amount,
        uint256 price,
        address currency
    );

    /**
     * @dev Emitted when `buyer` buys `token` from `owner`.
     */
    event Buy(
        address owner,
        address buyer,
        uint256 indexed position,
        address indexed collection,
        uint256 indexed token,
        uint256 amount,
        uint256 price,
        address currency
    );

    /**
     * @dev Emitted when `owner` cancells his `position`.
     */
    event Cancel(address owner, uint256 position);

    constructor() {
        marketplaceBeneficiaryAddress = payable(msg.sender);
        marketplaceCollectionFee[address(0)] = MarketplaceFee(true, 250, 250);
    }

    /**
     * @dev Change marketplace beneficiary address.
     *
     * @param _marketplaceBeneficiaryAddress address of the beneficiary
     */
    function changeMarketplaceBeneficiary(
        address _marketplaceBeneficiaryAddress
    ) external onlyOwner {
        marketplaceBeneficiaryAddress = _marketplaceBeneficiaryAddress;
    }

    /**
     * @dev Returns `MarketplaceFee` for given `_collection`.
     *
     * @param _collection address of collection
     */
    function getMarketplaceFee(address _collection) public view returns(MarketplaceFee memory) {
        if (marketplaceCollectionFee[_collection].customFee) {
            return marketplaceCollectionFee[_collection];
        }
        return marketplaceCollectionFee[address(0)];
    }

    /**
     * @dev Change `MarketplaceFee` for given `_collection`.
     *
     * @param _collection address of collection
     * @param _buyerFee needed buyer fee
     * @param _sellerFee needed seller fee
     *
     * Emits a {MarketplaceFeeChanged} event.
     */
    function changeMarketplaceCollectionFee(
        address _collection,
        uint16 _buyerFee,
        uint16 _sellerFee
    ) external onlyOwner {
        marketplaceCollectionFee[_collection] = MarketplaceFee(
            true,
            _buyerFee,
            _sellerFee
        );
        emit MarketplaceFeeChanged(_collection, _buyerFee, _sellerFee);
    }

    /**
     * @dev Remove `MarketplaceFee` for given `_collection`.
     *
     * @param _collection address of collection
     *
     * Emits a {MarketplaceFeeChanged} event.
     */
    function removeMarketplaceCollectionFee(address _collection) external onlyOwner {
        require(_collection != address(0), "Wrong collection");
        delete marketplaceCollectionFee[_collection];
        emit MarketplaceFeeChanged(
            _collection,
            marketplaceCollectionFee[address(0)].buyerFee,
            marketplaceCollectionFee[address(0)].sellerFee
        );
    }

    /**
     * @dev Returns `CollectionRoyalties` for given `_collection`.
     *
     * @param _collection address of collection
     */
    function getCustomCollectionRoyalties(address _collection) public view returns(CollectionRoyalties memory) {
        return customCollectionRoyalties[_collection];
    }

    /**
     * @dev Change `CollectionRoyalties` for given `_collection`.
     *
     * @param _collection address of collection
     * @param _recipient royalties recipient
     * @param _amount royalties amount
     *
     * Emits a {CollectionRoyaltiesChanged} event.
     */
    function changeCollectionRoyalties(
        address _collection,
        address _recipient,
        uint256 _amount
    ) external onlyOwner {
        require(_collection != address(0), "Wrong collection");
        require(_amount > 0 && _amount < 10000, "Wrong amount");
        require(!IERC165(_collection).supportsInterface(_INTERFACE_ID_FEES), "Collection haw own royalties");
        customCollectionRoyalties[_collection] = CollectionRoyalties(_recipient, _amount);
        emit CollectionRoyaltiesChanged(_collection, _recipient, _amount);
    }

    /**
     * @dev Remove `CollectionRoyalties` for given `_collection`.
     *
     * @param _collection address of collection
     *
     * Emits a {CollectionRoyaltiesChanged} event.
     */
    function removeCollectionRoyalties(address _collection) external onlyOwner {
        delete customCollectionRoyalties[_collection];
        emit CollectionRoyaltiesChanged(_collection, address(0), 0);
    }

    /**
     * @dev Create new sale position for token with `_id` from `_collection`.
     *
     * @param _collection address of collection
     * @param _tokenType TokenType of collection contract
     * @param _id address token id in collection
     * @param _amount amount of tokens to sale
     * @param _price proce for one token
     * @param _currency sale currency token address, use `address(0)` for BNB
     *
     * Emits a {NewPosition} event.
     */
    function putOnSale(
        address _collection,
        TokenType _tokenType,
        uint256 _id,
        uint256 _amount,
        uint256 _price,
        address _currency
    ) external returns (uint256) {
        if (_tokenType == TokenType.ERC1155) {
            require(
                IERC1155(_collection).balanceOf(msg.sender, _id) >= _amount,
                "Wrong amount"
            );
        } else {
            require(
                (IERC721(_collection).ownerOf(_id) == msg.sender) &&
                    (_amount == 1),
                "Wrong amount"
            );
        }
        positions[++positionsCount] = Position(
            nftToken(_collection, _id, _tokenType),
            _amount,
            _price,
            msg.sender,
            _currency
        );

        emit NewPosition(
            msg.sender,
            positionsCount,
            _collection,
            _id,
            _amount,
            _price,
            _currency
        );
        return positionsCount;
    }

    /**
     * @dev Remove position `_id` from sale.
     *
     * @param _id position id
     *
     * Emits a {Cancel} event.
     */
    function cancel(uint256 _id) external {
        require(msg.sender == positions[_id].owner || msg.sender == owner(), "Access denied");
        positions[_id].amount = 0;

        emit Cancel(msg.sender, _id);
    }

    /**
     * @dev Purchase `amount` of tokens by specific `position`.
     *
     * @param _position position id
     * @param _amount amount of tokens needed
     * @param _buyer address of the token destination
     * @param _data additional data for erc1155
     *
     * Emits a {Buy} event.
     */
    function buy(
        uint256 _position,
        uint256 _amount,
        address _buyer,
        bytes calldata _data
    ) external payable {
        Position memory position = positions[_position];
        require(position.amount >= _amount, "Wrong amount");

        transferWithFees(_position, _amount);

        if (_buyer == address(0)) {
            _buyer = msg.sender;
        }
        if (position.nft.tokenType == TokenType.ERC1155) {
            IERC1155(position.nft.collection).safeTransferFrom(
                position.owner,
                _buyer,
                position.nft.id,
                _amount,
                _data
            );
        } else if (position.nft.tokenType == TokenType.ERC721) {
            require(_amount == 1, "Wrong amount");
            IERC721(position.nft.collection).safeTransferFrom(
                position.owner,
                _buyer,
                position.nft.id
            );
        } else if (position.nft.tokenType == TokenType.ERC721Deprecated) {
            require(_amount == 1, "Wrong amount");
            IERC721(position.nft.collection).transferFrom(
                position.owner,
                _buyer,
                position.nft.id
            );
        }
        emit Buy(
            position.owner,
            _buyer,
            _position,
            position.nft.collection,
            position.nft.id,
            _amount,
            position.price,
            position.currency
        );
    }

    /**
     * @dev Calculate all needed fees and transfers them to recipients.
     */
    function transferWithFees(uint256 _position, uint256 _amount) internal {
        Position storage position = positions[_position];
        uint256 price = position.price * _amount;
        MarketplaceFee memory marketplaceFee = getMarketplaceFee(position.nft.collection);
        uint256 buyerFee = getFee(price, marketplaceFee.buyerFee);
        uint256 sellerFee = getFee(price, marketplaceFee.sellerFee);
        uint256 total = price + buyerFee;

        if (position.currency == address(0)) {
            require(msg.value >= total, "Insufficient balance");
            uint256 returnBack = msg.value - total;
            if (returnBack > 0) {
                payable(msg.sender).transfer(returnBack);
            }
        }

        if (buyerFee + sellerFee > 0) {
            transfer(
                marketplaceBeneficiaryAddress,
                position.currency,
                buyerFee + sellerFee
            );
        }
        uint256 fees = transferFees(price, position) + sellerFee;
        transfer(position.owner, position.currency, price - fees);

        position.amount = position.amount - _amount;
    }

    function transfer(
        address _to,
        address _currency,
        uint256 _amount
    ) internal {
        if (_currency == address(0)) {
            payable(_to).transfer(_amount);
        } else {
            IERC20(_currency).transferFrom(msg.sender, _to, _amount);
        }
    }

    /**
     * @dev Calculate royalties fee.
     */
    function transferFees(uint256 _price, Position memory position)
        internal
        returns (uint256)
    {
        HasSecondarySaleFees collection =
            HasSecondarySaleFees(position.nft.collection);
        uint256 result = 0;
        if (
            (position.nft.tokenType == TokenType.ERC1155 &&
                IERC1155(position.nft.collection).supportsInterface(
                    _INTERFACE_ID_FEES
                )) ||
            ((position.nft.tokenType == TokenType.ERC721 ||
                position.nft.tokenType == TokenType.ERC721Deprecated) &&
                IERC721(position.nft.collection).supportsInterface(
                    _INTERFACE_ID_FEES
                ))
        ) {
            uint256[] memory fees = collection.getFeeBps(position.nft.id);
            address payable[] memory recipients =
                collection.getFeeRecipients(position.nft.id);
            for (uint256 i = 0; i < fees.length; i++) {
                uint256 fee = getFee(_price, fees[i]);
                if (fee > 0) {
                    transfer(recipients[i], position.currency, fee);
                    result = result + fee;
                }
            }
        } else if (customCollectionRoyalties[position.nft.collection].fee > 0) {
            uint256 fee = getFee(_price, customCollectionRoyalties[position.nft.collection].fee);
            transfer(customCollectionRoyalties[position.nft.collection].recipient, position.currency, fee);
            result = result + fee;
        }
        return result;
    }

    /**
     * @dev Calculate the fee for an `_amount`.
     */
    function getFee(uint256 _amount, uint256 _fee)
        internal
        pure
        returns (uint256)
    {
        return _amount * _fee / 10000;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
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
pragma solidity ^0.8.0;

interface HasSecondarySaleFees {
    function getFeeRecipients(uint256 id)
        external
        view
        returns (address payable[] memory);

    function getFeeBps(uint256 id)
        external
        view
        returns (uint256[] memory);
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