// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IRegistrar.sol";

contract ZAuction is Initializable, OwnableUpgradeable {
  using ECDSA for bytes32;

  IERC20 public token;
  IRegistrar public registrar;

  // Original zAuction contract address for backward compatibility
  address legacyZAuction;

  struct Listing {
    uint256 price;
    address holder;
  }

  mapping(uint256 => Listing) public priceInfo;
  mapping(address => mapping(uint256 => bool)) public consumed;
  mapping(uint256 => uint256) public topLevelDomainIdCache;
  mapping(uint256 => uint256) public topLevelDomainFee;

  event BidAccepted(
    uint256 auctionId,
    address indexed bidder,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 tokenId,
    uint256 expireBlock
  );

  event DomainSold(
    address indexed buyer,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 indexed tokenId
  );

  event BidCancelled(uint256 auctionId, address indexed bidder);

  function getTopLevelId(uint256 tokenId) private returns (uint256) {
    uint256 topLevelId = topLevelDomainIdCache[tokenId];
    if (topLevelId == 0) {
      topLevelId = topLevelDomainIdOf(tokenId);
      topLevelDomainIdCache[tokenId] = topLevelId;
    }
    return topLevelId;
  }

  function initialize(
    IERC20 tokenAddress,
    IRegistrar registrarAddress,
    address legacyZAuctionAddress
  ) public initializer {
    __Ownable_init();
    token = tokenAddress;
    registrar = registrarAddress;
    legacyZAuction = legacyZAuctionAddress;
  }

  /// recovers bidder's signature based on seller's proposed data and, if bid data hash matches the message hash, transfers nft and payment
  /// @param signature type encoded message signed by the bidder
  /// @param auctionId unique per address auction identifier chosen by seller
  /// @param bidder address of who the seller says the bidder is, for confirmation of the recovered bidder
  /// @param bid token amount bid
  /// @param tokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  function acceptBid(
    bytes memory signature,
    uint256 auctionId,
    address bidder,
    uint256 bid,
    uint256 tokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock
  ) external {
    require(startBlock <= block.number, "zAuction: auction hasn't started");
    require(expireBlock > block.number, "zAuction: auction expired");
    require(minbid <= bid, "zAuction: cannot accept bid below min");
    require(bidder != msg.sender, "zAuction: cannot sell to self");

    bytes32 data = createBid(
      auctionId,
      bid,
      address(registrar),
      tokenId,
      minbid,
      startBlock,
      expireBlock
    );

    if (bidder != recover(toEthSignedMessageHash(data), signature)) {
      // Encode data with legacy zAuction address for backwards compatibility
      bytes32 legacyData = createLegacyBid(
        auctionId,
        bid,
        address(registrar),
        tokenId,
        minbid,
        startBlock,
        expireBlock
      );
      require(
        bidder == recover(toEthSignedMessageHash(legacyData), signature),
        "zAuction: recovered incorrect bidder"
      );
    }
    require(!consumed[bidder][auctionId], "zAuction: data already consumed");

    consumed[bidder][auctionId] = true;

    // Transfer payment, royalty to minter, and fee to topLevel domain
    paymentTransfers(bidder, bid, msg.sender, getTopLevelId(tokenId), tokenId);

    // Owner -> Bidder, send NFT
    registrar.safeTransferFrom(msg.sender, bidder, tokenId);

    emit BidAccepted(
      auctionId,
      bidder,
      msg.sender,
      bid,
      address(registrar),
      tokenId,
      expireBlock
    );
  }

  function setBuyPrice(uint256 amount, uint256 tokenId) external {
    address owner = registrar.ownerOf(tokenId);
    require(msg.sender == owner, "zAuction: only owner can set price");
    require(
      priceInfo[tokenId].price != amount,
      "zAuction: listing already exists"
    );
    priceInfo[tokenId] = Listing(amount, owner);
  }

  /// recovers buyer's signature based on seller's proposed data and, if bid data hash matches the message hash, transfers nft and payment
  /// @param amount token amount of sale
  /// @param tokenId token id we are transferring
  function buyNow(uint256 amount, uint256 tokenId) external {
    require(amount == priceInfo[tokenId].price, "zAuction: wrong sale price");
    address seller = registrar.ownerOf(tokenId);
    require(msg.sender != seller, "zAuction: cannot sell to self");
    require(
      priceInfo[tokenId].holder == seller,
      "zAuction: not listed for sale"
    );
    require(priceInfo[tokenId].price != 0, "zAuction: item not for sale");

    // Transfer payment, royalty to minter, and fee to topLevel domain
    paymentTransfers(
      msg.sender,
      amount,
      seller,
      getTopLevelId(tokenId),
      tokenId
    );

    priceInfo[tokenId].price = 0;

    // Owner -> message sender, send NFT
    registrar.safeTransferFrom(seller, msg.sender, tokenId);

    emit DomainSold(msg.sender, seller, amount, address(registrar), tokenId);
  }

  /// Cancels an existing bid for an NFT by marking it as already consumed
  /// so that it can never be fulfilled.
  /// @param account The account that made the specific bid
  /// @param auctionId The ID of the auction associated with that bid
  function cancelBid(address account, uint256 auctionId) external {
    require(
      msg.sender == account,
      "zAuction: Cannot cancel someone else's bid"
    );
    require(
      !consumed[account][auctionId],
      "zAuction: Cannot cancel an already consumed bid"
    );

    consumed[account][auctionId] = true;

    emit BidCancelled(auctionId, account);
  }

  /// Allows the owner of the given token to set the fee owed upon sale
  /// Amount given should be as a percent with 5 decimals of precision
  /// e.g. 10% (max) is 1000000, 0.0001% (min) is 1
  /// @param id The id of the domain to update
  /// @param amount The
  function setTopLevelDomainFee(uint256 id, uint256 amount) public {
    require(
      msg.sender == registrar.ownerOf(id),
      "zAuction: Cannot set fee on unowned domain"
    );
    require(amount <= 1000000, "zAuction: Cannot set a fee higher than 10%");
    require(amount != topLevelDomainFee[id], "zAuction: Amount is already set");
    topLevelDomainFee[id] = amount;
  }

  /// Fetch the top level domain fee if it exists and calculate the token amount
  /// @param topLevelId The id of the top level domain for a subdomain
  /// @param bid The bid for the fee to apply to
  function calculateTopLevelDomainFee(uint256 topLevelId, uint256 bid)
    public
    view
    returns (uint256)
  {
    require(topLevelId > 0, "zAuction: must provide a valid id");
    require(bid > 0, "zAuction: Cannot calculate domain fee on an empty bid");

    // Find what percent they've specified as a royalty
    uint256 fee = topLevelDomainFee[topLevelId];
    if (fee == 0) return 0;

    uint256 calculatedFee = (bid * fee * 10**13) / (100 * 10**18);

    return calculatedFee;
  }

  /// Fetch the minter royalty if it exists and calculate the token amount
  /// @param bid The bid for the royalty to be calculated
  /// @param id The id of the minted domain
  function calculateMinterRoyalty(uint256 id, uint256 bid)
    public
    pure
    returns (uint256)
  {
    require(id > 0, "zAuction: must provide a valid id");
    uint256 domainRoyalty = 1000000;
    uint256 royalty = (bid * domainRoyalty * 10**13) / (100 * 10**18);

    return royalty;
  }

  /// Create a bid object hashed with the current contract address
  /// @param auctionId unique per address auction identifier chosen by seller
  /// @param bid token amount bid
  /// @param nftAddress address of the nft contract
  /// @param tokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  function createBid(
    uint256 auctionId,
    uint256 bid,
    address nftAddress,
    uint256 tokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock
  ) public view returns (bytes32 data) {
    data = keccak256(
      abi.encode(
        auctionId,
        address(this),
        block.chainid,
        bid,
        nftAddress,
        tokenId,
        minbid,
        startBlock,
        expireBlock
      )
    );
    return data;
  }

  /// Create a bid object hashed with the legacy contract address
  /// for backwards compatability.
  /// @param auctionId unique per address auction identifier chosen by seller
  /// @param bid token amount bid
  /// @param nftAddress address of the nft contract
  /// @param tokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  function createLegacyBid(
    uint256 auctionId,
    uint256 bid,
    address nftAddress,
    uint256 tokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock
  ) public view returns (bytes32 data) {
    data = keccak256(
      abi.encode(
        auctionId,
        legacyZAuction,
        block.chainid,
        bid,
        nftAddress,
        tokenId,
        minbid,
        startBlock,
        expireBlock
      )
    );
    return data;
  }

  // Will return self if already at the top level
  function topLevelDomainIdOf(uint256 id) public view returns (uint256) {
    uint256 parentId = registrar.parentOf(id);
    uint256 holder = id;
    while (parentId != 0) {
      holder = parentId; // Hold on to previous parent
      parentId = registrar.parentOf(parentId);
    }
    return holder;
  }

  /// Recover an account from a signature hash
  /// @param hash the bytes object
  /// @param signature the signature to recover from
  function recover(bytes32 hash, bytes memory signature)
    public
    pure
    returns (address)
  {
    return hash.recover(signature);
  }

  function toEthSignedMessageHash(bytes32 hash) public pure returns (bytes32) {
    return hash.toEthSignedMessageHash();
  }

  /// Send all required payment transfers when an NFT is sold
  /// This requires paying the owner, minter, and top level domain owner
  /// @param bidder address of who the seller says the bidder is, for confirmation of the recovered bidder
  /// @param bid token amount bid
  /// @param owner address of the owner of that domain pre-transfer
  /// @param topLevelId the ID of the top level domain for a given domain or subdomain
  /// @param tokenId the ID of the domain
  function paymentTransfers(
    address bidder,
    uint256 bid,
    address owner,
    uint256 topLevelId,
    uint256 tokenId
  ) internal {
    address topLevelOwner = registrar.ownerOf(topLevelId);
    uint256 topLevelFee = calculateTopLevelDomainFee(topLevelId, bid);
    uint256 minterRoyalty = calculateMinterRoyalty(tokenId, bid);

    uint256 bidActual = bid - minterRoyalty - topLevelFee;

    // Bidder -> Owner, pay transaction
    SafeERC20.safeTransferFrom(token, bidder, owner, bidActual);

    // Bidder -> Minter, pay minter royalty
    SafeERC20.safeTransferFrom(
      token,
      bidder,
      registrar.minterOf(tokenId),
      minterRoyalty
    );

    // Bidder -> topLevel Owner, pay top level owner fee
    SafeERC20.safeTransferFrom(token, bidder, topLevelOwner, topLevelFee);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        // Divide the signature in r, s and v variables
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
        } else if (signature.length == 64) {
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let vs := mload(add(signature, 0x40))
                r := mload(add(signature, 0x20))
                s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                v := add(shr(255, vs), 27)
            }
        } else {
            revert("ECDSA: invalid signature length");
        }

        return recover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        require(uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0, "ECDSA: invalid signature 's' value");
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        require(signer != address(0), "ECDSA: invalid signature");

        return signer;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";
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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {

    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IRegistrar is IERC721 {
  // Checks if a domains metadata is locked
  function isDomainMetadataLocked(uint256 id) external view returns (bool);

  // Gets a domains current royalty amount
  function domainRoyaltyAmount(uint256 id) external view returns (uint256);

  // Sets the asked royalty amount on a domain (amount is a percentage with 5 decimal places)
  function setDomainRoyaltyAmount(uint256 id, uint256 amount) external;

  // Returns the parent domain of a child domain
  function parentOf(uint256 id) external view returns (uint256);

  //Gets a domain's minter
  function minterOf(uint256 id) external view returns (address);
}

// SPDX-License-Identifier: MIT

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.8.0;

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
        assembly { size := extcodesize(account) }
        return size > 0;
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
    uint256[50] private __gap;
}