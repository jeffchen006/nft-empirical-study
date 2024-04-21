//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract MetaFactory is Ownable, Pausable {
    using Address for address payable;

    event TokenInfoSet(address indexed tokenAddress, uint256 indexed tokenId, uint256 price, uint256 euroPrice);
    event TokenSaleToggled(address indexed tokenAddress, uint256 indexed tokenId, bool active);
    event TokenSold(address indexed tokenAddress, uint256 indexed tokenId, address indexed recipient, uint256 amount);
    event TokenInfoRemoved(address indexed tokenAddress, uint256 indexed tokenId);

    struct TokenInfo {
        // Price in Wei (ETH)
        // The price is either fixed in Dollar or ETH
        // If the price is fixed in ETH then price > 0
        uint256 price;
        // Price in Euro (with 2 decimals)
        // The price is either fixed in Euro or ETH
        // If the price is fixed in Euro then euroPrice > 0
        uint256 euroPrice;
        // Whether people can buy the token
        bool saleActive;
        // The beneficiary of the sale of the token
        address beneficiary;
        // Commission received on the sales of the token
        // from 0 to 10000 (e.g. 300 => 3%)
        uint256 commission;
        // The original owner of the token
        address originalOwner;
    }

    address public fundsRecipient = 0x2F043D494E1EbBD551F63ceC0381cb9C31A67e71;

    // Address of an ERC-721 or ERC-1155 external smart contract
    // => whether this contract accepts to sell the token emitted
    // by the external smart contract
    mapping(address => bool) public tokensAccepted;
    // Address of an ERC-721 or ERC-1155 external smart contract
    // => id of the token => details of the token
    mapping(address => mapping(uint256 => TokenInfo)) public tokenDetails;

    // Price feed of ETH/USD (8 decimals)
    AggregatorV3Interface private immutable ethToUsdFeed;
    // Price feed of EUR/USD
    AggregatorV3Interface private immutable eurToUsdFeed;

    constructor(address _ethToUsdFeed, address _eurToUsdFeed) {
        require(_ethToUsdFeed != address(0) 
            && _eurToUsdFeed != address(0), "Invalid address");
        ethToUsdFeed = AggregatorV3Interface(_ethToUsdFeed);
        eurToUsdFeed = AggregatorV3Interface(_eurToUsdFeed);
    }

    /**
    * @dev Let purchase tokens available for sale on this contract 
    * @param tokenAddress Address of the token
    * @param tokenId Id of the token
    * @param amount Amount of the token to purchase (ignored for ERC721)
    * @param to Address where the purchased tokens will be sent to
     */
    function buyTokensFor(
        address tokenAddress,
        uint256 tokenId,
        uint256 amount,
        address to
    ) external payable whenNotPaused {
        TokenInfo storage tokenInfo = tokenDetails[tokenAddress][tokenId];
        require(tokenInfo.saleActive, "Not available for sale");
        // Check the value is correct
        if(tokenInfo.euroPrice > 0) {
            uint256 price = getPriceInETH(tokenAddress, tokenId);
            // Take a 0.5% slippage into account
            uint256 minPrice = (price * 995) / 1000;
            uint256 maxPrice = (price * 1005) / 1000;
            require(msg.value >= minPrice * amount, "Not enough ETH"); 
            require(msg.value <= maxPrice * amount, "Too much ETH"); 
        } else {
            require(msg.value == tokenInfo.price * amount, "Wrong value"); 
        }
        address beneficiary = tokenInfo.beneficiary;
        address originalOwner = tokenInfo.originalOwner;
        uint256 commission = tokenInfo.commission;
        // Check which type of token it is
        if (
            IERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)
        ) {
            IERC1155 token = IERC1155(tokenAddress);
            // Make sure the contract can transfer this token
            require(
                token.isApprovedForAll(originalOwner, address(this)),
                "Not available"
            );
            uint256 amountLeft = token.balanceOf(originalOwner, tokenId);
            require(amountLeft >= amount, "Not enough supply left");
            if (amountLeft == amount) {
                // The tokens will change hands and no longer be controlled by this
                // smart contract so we can remove these details safely
                delete tokenDetails[tokenAddress][tokenId];
            }
            // Transfer the tokens to the recipient set by the buyer
            token.safeTransferFrom(originalOwner, to, tokenId, amount, "");
        } else {
            IERC721 token = IERC721(tokenAddress);
            // Make sure the contract can transfer this token
            require(
                token.isApprovedForAll(token.ownerOf(tokenId), address(this)),
                "Not available"
            );
            // The token will change hands and no longer be controlled by this
            // smart contract so we can remove these details safely
            delete tokenDetails[tokenAddress][tokenId];
            // Transfer the tokens to the recipient set by the buyer
            IERC721(tokenAddress).transferFrom(
                token.ownerOf(tokenId),
                to,
                tokenId
            );
        }
        uint256 totalCommission = (msg.value * commission) /
            10000;
        // Take the commission
        payable(fundsRecipient).sendValue(totalCommission);
        // And send the rest to the beneficiary of this sale
        payable(beneficiary).sendValue(msg.value - totalCommission);
        emit TokenSold(tokenAddress, tokenId, to, amount);
    }
    
    /**
     * @dev Set the info of a token to be sold through this contract
     * This contract needs to be approved by the owner of the token
     * in order for the sale to be active.
     * For ERC-1155, the owner of the token cannot change during the sale
     * or any purchase transaction will fail.
     */
    function setTokenInfo(
        address tokenAddress,
        uint256 tokenId,
        uint256 price,
        uint256 euroPrice,
        uint256 commission,
        address originalOwner
    ) public onlyOwner {
        checkInfo(tokenAddress, price, euroPrice, commission, originalOwner);
        // Check that the owner is the right one
        if(IERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)) {
            require(IERC1155(tokenAddress).balanceOf(originalOwner, tokenId) > 0, "Wrong owner");
        } else {
            require(IERC721(tokenAddress).ownerOf(tokenId) == originalOwner, "Wrong owner");
        }
        tokenDetails[tokenAddress][tokenId] = TokenInfo({
            price: price,
            euroPrice: euroPrice,
            // Any update to the token info will disable the sale
            // so that the owner of the NFT has to enable it again
            saleActive: false,
            // Keep the value of the beneficiary
            beneficiary: tokenDetails[tokenAddress][tokenId].beneficiary,
            commission: commission,
            // Useful for ERC-1155 contracts
            originalOwner: originalOwner
        });
        emit TokenInfoSet(tokenAddress, tokenId, price, euroPrice);
    }

    function setTokensInfo(
        address tokenAddress,
        uint256[] memory tokenIds,
        uint256 price,
        uint256 euroPrice,
        uint256 commission,
        address originalOwner
    ) external {
        // Will fail if not owner of the contract as this resctriction is
        // checked in the function called below
        for(uint256 i = 0; i < tokenIds.length; i++) {
            setTokenInfo(tokenAddress, tokenIds[i], price, euroPrice, commission, originalOwner);
        }
     }

    function checkInfo(        
        address tokenAddress,
        uint256 price,
        uint256 euroPrice,
        uint256 commission,
        address originalOwner
    ) private view {
        // The token must be accepted first
        require(tokensAccepted[tokenAddress], "Token not accepted");
        // One of the price must be greater than 0
        require(price > 0 || euroPrice > 0, "Price must be greater than 0");
        require(originalOwner != address(0), "Invalid original owner address");
        // price and euroPrice are mutually exclusive, one of them must be 0
        require(price == 0 || euroPrice == 0, "You cannot fix the price both in EUR and ETH");
        require(commission <= 10000, "Commission cannot above 100%");
    }

    /**
    * @dev Remove all info stored about a token
    * @param tokenAddress Address of the token
    * @param tokenId Id of the token
     */
    function removeTokenInfo(address tokenAddress, uint256 tokenId) public onlyOwner {
        require(tokenDetails[tokenAddress][tokenId].originalOwner != address(0), "No info defined");
        delete tokenDetails[tokenAddress][tokenId];
        emit TokenInfoRemoved(tokenAddress, tokenId);
    }

    /**
    * @dev Remove all info stored about the tokens
    * @param tokenAddress Address of the tokens
    * @param tokenIds Ids of the tokens
     */
    function removeTokensInfo(address tokenAddress, uint256[] memory tokenIds) external onlyOwner {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            removeTokenInfo(tokenAddress, tokenIds[i]);
        }
    }


    /**
    * @dev Change the status of the sale of a given token
    * @param tokenAddress The address of the token
    * @param tokenId The id of the token
    * @param active Whether to enable or disable the sale
    * @param beneficiary Address that will receive proceeds of the sale for the artist
    * Can be set to zero address (if so the argument will be ignored)
     */
    function toggleTokenSale(address tokenAddress, uint256 tokenId, bool active, address beneficiary) public {
        TokenInfo storage details = tokenDetails[tokenAddress][tokenId];
        // Check if the token info have been defined
        // No need to check whether it was accepted or not
        // cause if the info have been defined it's necessarily accepted
        require(details.originalOwner != address(0), "Token not defined");            
        // Only the owner of the token can call this function
        if(IERC165(tokenAddress).supportsInterface(type(IERC1155).interfaceId)) {
            // If the owner changed in between the time the token info were defined
            // and now, this transaction will fail (so the owner should be updated) 
            require(msg.sender == details.originalOwner 
                && IERC1155(tokenAddress).balanceOf(details.originalOwner, tokenId) > 0, "Not allowed"); 
        } else {
            // Checking for the ownership is more straightforward for the ERC-721
            require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Not allowed"); 
        }
        tokenDetails[tokenAddress][tokenId].saleActive = active;
        // Set the beneficiary to the new address if defined
        if(beneficiary != address(0)) {
            tokenDetails[tokenAddress][tokenId].beneficiary = beneficiary;
        }
        emit TokenSaleToggled(tokenAddress, tokenId, active);
    }

    /**
    * @dev Change the status of the sale of the tokens
    * @param tokenAddress The address of the token
    * @param tokenIds The ids of the tokens
    * @param active Whether to enable or disable the sale
    * @param beneficiary Address that will receive proceeds of the sale for the artist
    * Can be set to zero address (if so the argument will be ignored)
     */
    function toggleTokensSale(address tokenAddress, uint256[] memory tokenIds, bool active, address beneficiary) external {
        for(uint256 i = 0; i < tokenIds.length; i++) {
            toggleTokenSale(tokenAddress, tokenIds[i], active, beneficiary);
        }
    }

    /**
    * @dev To add or remove tokens that are accepted by this contract for the sales
    * @param addrs Addresses of the tokens to manage
    * @param accepted Whether to consider them as accepted or not
     */
    function manageAcceptedTokens(address[] memory addrs, bool accepted)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addrs.length; i++) {
            require(addrs[i] != address(0), "Invalid address");
            // Check that the token address is a valid ERC-721 or ERC-1155 contract
            require(
                ERC165Checker.supportsERC165(addrs[i]) &&
                (IERC165(addrs[i]).supportsInterface(
                    type(IERC1155).interfaceId
                ) ||
                    IERC165(addrs[i]).supportsInterface(
                        type(IERC721).interfaceId
                    )),
                "Token not a valid interface"
            );
            tokensAccepted[addrs[i]] = accepted;
        }
    }

    /**
    @dev Set the address that will receive the commission on the sales
    @param addr Address that will receive the commissions
     */
    function setFundsRecipient(address addr) external onlyOwner {
        require(addr != address(0), "Invalid address");
        fundsRecipient = addr;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Get current rate of ETH to US Dollar
     */
    function getETHtoUSDPrice() private view returns (uint256) {
        (, int256 price, , , ) = ethToUsdFeed.latestRoundData();
        return uint256(price);
    }

    /**
    * @dev Get current rate of Euro to US Dollar
    */
    function getEURToUSDPrice() private view returns (uint256) {
        (, int256 price, , , ) = eurToUsdFeed.latestRoundData();
        return uint256(price);
    }


    function getPriceInETH(address tokenAddress, uint256 tokenId) public view returns (uint256) {
        // Get the price fixed in EUR for the token if any
        uint256 priceInEuro = tokenDetails[tokenAddress][tokenId].euroPrice;
        require(priceInEuro > 0, "Price not fixed in EUR");
        // Get rate for EUR/USD
        uint256 eurToUsd = getEURToUSDPrice();
        // Get rate for ETH/USD
        uint256 ethToUsd = getETHtoUSDPrice();
        // Convert price in US Dollar
        // We divide by 10 to power of the number of decimals of EUR/USD feed
        // to cancel out all decimals in priceInUsd
        uint256 priceInUsd = (priceInEuro * eurToUsd) / 10**eurToUsdFeed.decimals();
        // Convert price in ETH for US Dollar price
        // We multiply by the 10^(decimals of ETH/USD feed) to make the priceInUsd
        // which has 2 decimals equal to the number of decimals of the denominator
        // We then multiply by 10^16 to increase the accuracy of the conversion
        // and also make the result 18 decimals (priceInUsd is 2 decimals) since the rest
        // of the decimals cancel out between numerator and denominator
        uint256 priceInETH = (priceInUsd *
            10**(ethToUsdFeed.decimals()) *
            10**16) / ethToUsd;
        return priceInETH;
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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165Checker.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library ERC165Checker {
    // As per the EIP-165 spec, no interface should ever match 0xffffffff
    bytes4 private constant _INTERFACE_ID_INVALID = 0xffffffff;

    /**
     * @dev Returns true if `account` supports the {IERC165} interface,
     */
    function supportsERC165(address account) internal view returns (bool) {
        // Any contract that implements ERC165 must explicitly indicate support of
        // InterfaceId_ERC165 and explicitly indicate non-support of InterfaceId_Invalid
        return
            _supportsERC165Interface(account, type(IERC165).interfaceId) &&
            !_supportsERC165Interface(account, _INTERFACE_ID_INVALID);
    }

    /**
     * @dev Returns true if `account` supports the interface defined by
     * `interfaceId`. Support for {IERC165} itself is queried automatically.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(address account, bytes4 interfaceId) internal view returns (bool) {
        // query support of both ERC165 as per the spec and support of _interfaceId
        return supportsERC165(account) && _supportsERC165Interface(account, interfaceId);
    }

    /**
     * @dev Returns a boolean array where each value corresponds to the
     * interfaces passed in and whether they're supported or not. This allows
     * you to batch check interfaces for a contract where your expectation
     * is that some interfaces may not be supported.
     *
     * See {IERC165-supportsInterface}.
     *
     * _Available since v3.4._
     */
    function getSupportedInterfaces(address account, bytes4[] memory interfaceIds)
        internal
        view
        returns (bool[] memory)
    {
        // an array of booleans corresponding to interfaceIds and whether they're supported or not
        bool[] memory interfaceIdsSupported = new bool[](interfaceIds.length);

        // query support of ERC165 itself
        if (supportsERC165(account)) {
            // query support of each interface in interfaceIds
            for (uint256 i = 0; i < interfaceIds.length; i++) {
                interfaceIdsSupported[i] = _supportsERC165Interface(account, interfaceIds[i]);
            }
        }

        return interfaceIdsSupported;
    }

    /**
     * @dev Returns true if `account` supports all the interfaces defined in
     * `interfaceIds`. Support for {IERC165} itself is queried automatically.
     *
     * Batch-querying can lead to gas savings by skipping repeated checks for
     * {IERC165} support.
     *
     * See {IERC165-supportsInterface}.
     */
    function supportsAllInterfaces(address account, bytes4[] memory interfaceIds) internal view returns (bool) {
        // query support of ERC165 itself
        if (!supportsERC165(account)) {
            return false;
        }

        // query support of each interface in _interfaceIds
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            if (!_supportsERC165Interface(account, interfaceIds[i])) {
                return false;
            }
        }

        // all interfaces supported
        return true;
    }

    /**
     * @notice Query if a contract implements an interface, does not check ERC165 support
     * @param account The address of the contract to query for support of an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return true if the contract at account indicates support of the interface with
     * identifier interfaceId, false otherwise
     * @dev Assumes that account contains a contract that supports ERC165, otherwise
     * the behavior of this method is undefined. This precondition can be checked
     * with {supportsERC165}.
     * Interface identification is specified in ERC-165.
     */
    function _supportsERC165Interface(address account, bytes4 interfaceId) private view returns (bool) {
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory result) = account.staticcall{gas: 30000}(encodedParams);
        if (result.length < 32) return false;
        return success && abi.decode(result, (bool));
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