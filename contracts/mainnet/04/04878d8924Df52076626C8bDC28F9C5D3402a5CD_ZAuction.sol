// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./oz/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IRegistrar.sol";
import "./IZNSHub.sol";

contract ZAuction is Initializable, OwnableUpgradeable {
  using ECDSA for bytes32;
  using SafeERC20 for IERC20;

  // Default ERC20 Token
  IERC20 public defaultPaymentToken;

  // To avoid overriding this variable in memory on upgrades we have to keep it
  IRegistrar public registrar;

  struct Listing {
    uint256 price;
    address holder;
    IERC20 paymentToken;
  }

  mapping(uint256 => Listing) public priceInfo;
  mapping(address => mapping(uint256 => bool)) public consumed;
  mapping(uint256 => uint256) public topLevelDomainIdCache;
  mapping(uint256 => uint256) public topLevelDomainFee;

  event BidAccepted(
    uint256 bidNonce,
    address indexed bidder,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 tokenId,
    uint256 expireBlock
  );

  event BidAcceptedV2(
    uint256 bidNonce,
    address indexed bidder,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 tokenId,
    uint256 expireBlock,
    address paymentToken,
    uint256 topLevelDomainId
  );

  event DomainSold(
    address indexed buyer,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 indexed tokenId
  );

  event DomainSoldV2(
    address indexed buyer,
    address indexed seller,
    uint256 amount,
    address nftAddress,
    uint256 indexed tokenId,
    address paymentToken,
    uint256 topLevelDomainId
  );

  event BuyNowPriceSet(uint256 indexed tokenId, uint256 amount);

  event BuyNowPriceSetV2(
    uint256 indexed tokenId,
    uint256 amount,
    address paymentToken
  );

  event BidCancelled(uint256 bidNonce, address indexed bidder);

  // On upgrade new variables must be inserted after all existing variables
  IZNSHub public hub;

  // Map top level domain ID to the ERC20 token used for that network.
  mapping(uint256 => IERC20) public networkPaymentToken;

  // Hardcoded address of the wild token for legacy bids only
  IERC20 public wildToken;

  // Storage slot with the proxy admin of the contract
  bytes32 internal constant _ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  function initialize(
    IERC20 defaultPaymentToken_,
    IERC20 wildToken_,
    IZNSHub znsHub_
  ) public initializer {
    __Ownable_init();
    defaultPaymentToken = defaultPaymentToken_;
    wildToken = wildToken_;
    hub = znsHub_;
  }

  function getProxyAdmin() public view returns (address) {
    return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
  }

  // For backwards compatability we want to make sure there is still a "token" that can be called.
  // This will be deprecated in the future, don't call this function.
  function token() external view returns (IERC20) {
    return wildToken;
  }

  /// recovers bidder's signature based on seller's proposed data and, if bid data hash matches the message hash, transfers nft and payment
  /// @param signature type encoded message signed by the bidder
  /// @param bidNonce unique per address auction identifier chosen by seller
  /// @param bidder address of who the seller says the bidder is, for confirmation of the recovered bidder
  /// @param bid token amount bid
  /// @param domainTokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  function acceptBid(
    bytes memory signature,
    uint256 bidNonce,
    address bidder,
    uint256 bid,
    uint256 domainTokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock
  ) external {
    require(startBlock <= block.number, "zAuction: auction hasn't started");
    require(expireBlock > block.number, "zAuction: auction expired");
    require(minbid <= bid, "zAuction: cannot accept bid below min");
    require(bidder != msg.sender, "zAuction: cannot sell to self");
    require(msg.sender == hub.ownerOf(domainTokenId), "Only Owner");

    IRegistrar domainRegistrar = hub.getRegistrarForDomain(domainTokenId);

    bytes32 data = createBid(
      bidNonce,
      bid,
      address(domainRegistrar),
      domainTokenId,
      minbid,
      startBlock,
      expireBlock
    );

    require(
      bidder == recover(toEthSignedMessageHash(data), signature),
      "zAuction: recovered incorrect bidder"
    );
    require(!consumed[bidder][bidNonce], "zAuction: data already consumed");

    consumed[bidder][bidNonce] = true;

    uint256 topLevelDomainId = getTopLevelIdWithUpdate(domainTokenId);
    // Transfer payment, royalty to minter, and fee to topLevel domain
    paymentTransfers(
      bidder,
      bid,
      msg.sender,
      topLevelDomainId,
      domainTokenId,
      wildToken
    );

    // Owner -> Bidder, send NFT
    domainRegistrar.safeTransferFrom(msg.sender, bidder, domainTokenId);

    emit BidAccepted(
      bidNonce,
      bidder,
      msg.sender,
      bid,
      address(domainRegistrar),
      domainTokenId,
      expireBlock
    );
  }

  // Accept a bid but with the addition of a bidToken parameter to support v2.1 changes
  /// @param signature type encoded message signed by the bidder
  /// @param bidNonce unique per address auction identifier chosen by seller
  /// @param bidder address of who the seller says the bidder is, for confirmation of the recovered bidder
  /// @param bid token amount bid
  /// @param domainTokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  /// @param bidToken the token used in payment for the bid
  function acceptBidV2(
    bytes memory signature,
    uint256 bidNonce,
    address bidder,
    uint256 bid,
    uint256 domainTokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock,
    IERC20 bidToken
  ) external {
    require(startBlock <= block.number, "zAuction: auction hasn't started");
    require(expireBlock > block.number, "zAuction: auction expired");
    require(minbid <= bid, "zAuction: cannot accept bid below min");
    require(bidder != msg.sender, "zAuction: cannot sell to self");
    require(msg.sender == hub.ownerOf(domainTokenId), "Only Owner");

    // Disallow accepting bid if made in the wrong ERC20 token
    IERC20 paymentToken = getPaymentTokenForDomain(domainTokenId);
    require(
      paymentToken == bidToken,
      "zAuction: Only bids made with the network's token can be accepted"
    );

    IRegistrar domainRegistrar = hub.getRegistrarForDomain(domainTokenId);

    bytes32 data = createBidV2(
      bidNonce,
      bid,
      domainTokenId,
      minbid,
      startBlock,
      expireBlock,
      address(bidToken)
    );

    require(
      bidder == recover(toEthSignedMessageHash(data), signature),
      "zAuction: recovered incorrect bidder"
    );
    require(!consumed[bidder][bidNonce], "zAuction: data already consumed");

    consumed[bidder][bidNonce] = true;

    uint256 topLevelDomainId = getTopLevelIdWithUpdate(domainTokenId);
    // Transfer payment, royalty to minter, and fee to topLevel domain owner
    paymentTransfers(
      bidder,
      bid,
      msg.sender,
      topLevelDomainId,
      domainTokenId,
      bidToken
    );

    // Owner -> Bidder, send NFT
    domainRegistrar.safeTransferFrom(msg.sender, bidder, domainTokenId);

    emit BidAcceptedV2(
      bidNonce,
      bidder,
      msg.sender,
      bid,
      address(domainRegistrar),
      domainTokenId,
      expireBlock,
      address(bidToken),
      topLevelDomainId
    );
  }

  /// Allows setting of a network token. Network is the same conceptually as a top level domain,
  /// so a network might be 0://wilder and network token would mean that every subdomain in that network
  /// e.g. 0://wilder.kitty will use that ERC20 token for bidding and sales.
  /// @param domainNetworkId The top level domainId of a network
  /// @param domainNetworkToken The token to set for purchases of subdomains in that network
  function setNetworkToken(uint256 domainNetworkId, IERC20 domainNetworkToken)
    external
    onlyOwner
  {
    // Setting to 0 will cause the system to fall back onto the default token
    require(
      networkPaymentToken[domainNetworkId] != domainNetworkToken,
      "zAuction: No state change"
    );
    networkPaymentToken[domainNetworkId] = domainNetworkToken;
  }

  /// Set the value of the hardcoded IERC20 wildToken to be used in legacy bids
  /// @param token The WILD token address
  function setWildToken(IERC20 token) external onlyOwner {
    require(token != wildToken, "zAuction: No state change");
    wildToken = token;
  }

  /// Admin modify default token
  /// @param newDefaultToken The new default ERC20 token to use
  function setDefaultPaymentToken(IERC20 newDefaultToken) external onlyOwner {
    require(
      newDefaultToken != IERC20(address(0)),
      "zAuction: Cannot give a zero address for the default payment token"
    );
    require(
      newDefaultToken != defaultPaymentToken,
      "zAuction: No state change"
    );
    defaultPaymentToken = newDefaultToken;
  }

  /// Allows for setting the buyNow price of a domain in either the network token or default token
  /// @param amount The price to be set
  /// @param domainTokenId The domain token to be put up for sale
  function setBuyPrice(uint256 amount, uint256 domainTokenId) external {
    IRegistrar domainRegistrar = hub.getRegistrarForDomain(domainTokenId);
    address owner = domainRegistrar.ownerOf(domainTokenId);

    require(msg.sender == owner, "zAuction: only owner can set price");

    require(
      priceInfo[domainTokenId].price != amount,
      "zAuction: listing already exists"
    );

    // Always set in whatever the current token for that domain is
    IERC20 paymentToken = getPaymentTokenForDomain(domainTokenId);

    priceInfo[domainTokenId] = Listing(amount, owner, paymentToken);
    emit BuyNowPriceSetV2(domainTokenId, amount, address(paymentToken));
  }

  /// recovers buyer's signature based on seller's proposed data and, if bid data hash matches the message hash, transfers nft and payment
  /// @param amount token amount of sale
  /// @param domainTokenId token id we are transferring
  function buyNow(uint256 amount, uint256 domainTokenId) external {
    require(priceInfo[domainTokenId].price != 0, "zAuction: item not for sale");
    require(
      amount == priceInfo[domainTokenId].price,
      "zAuction: wrong sale price"
    );

    IRegistrar domainRegistrar = hub.getRegistrarForDomain(domainTokenId);
    address seller = domainRegistrar.ownerOf(domainTokenId);

    require(msg.sender != seller, "zAuction: cannot sell to self");
    require(
      priceInfo[domainTokenId].holder == seller,
      "zAuction: not listed for sale"
    );

    // Transfer payment, royalty to minter, and fee to topLevel domain
    paymentTransfers(
      msg.sender,
      amount,
      seller,
      getTopLevelIdWithUpdate(domainTokenId),
      domainTokenId,
      wildToken
    );

    // To disallow being shown as a sale after being already purchased, we set price to 0
    priceInfo[domainTokenId].price = 0;

    // Owner -> message sender, send NFT
    domainRegistrar.safeTransferFrom(seller, msg.sender, domainTokenId);

    emit DomainSold(
      msg.sender,
      seller,
      amount,
      address(domainRegistrar),
      domainTokenId
    );
  }

  /// Allows immediate purchase like in `buyNow`
  /// @param amount token amount of sale
  /// @param domainTokenId token id we are transferring
  function buyNowV2(uint256 amount, uint256 domainTokenId) external {
    require(priceInfo[domainTokenId].price != 0, "zAuction: item not for sale");
    require(
      amount == priceInfo[domainTokenId].price,
      "zAuction: wrong sale price"
    );

    // It is possible the payment token is modified between the time
    // a buy price is set and the time it is accepted. If this is so,
    // we can't perform a buyNow sale as it is not set in the updated
    // token.
    IERC20 listingPaymentToken = priceInfo[domainTokenId].paymentToken;
    IERC20 domainPaymentToken = getPaymentTokenForDomain(domainTokenId);
    require(
      domainPaymentToken == listingPaymentToken,
      "zAuction: Listing not set in correct domain token"
    );

    IRegistrar domainRegistrar = hub.getRegistrarForDomain(domainTokenId);
    address seller = domainRegistrar.ownerOf(domainTokenId);

    require(msg.sender != seller, "zAuction: cannot sell to self");
    require(
      priceInfo[domainTokenId].holder == seller,
      "zAuction: not listed for sale"
    );

    // Transfer payment, royalty to minter, and fee to topLevel domain
    paymentTransfers(
      msg.sender,
      amount,
      seller,
      getTopLevelIdWithUpdate(domainTokenId),
      domainTokenId,
      listingPaymentToken
    );

    uint256 topLevelId = getTopLevelIdWithUpdate(domainTokenId);

    // To disallow being shown as a sale after being already purchased, we set price to 0
    priceInfo[domainTokenId].price = 0;

    // Owner -> message sender, send NFT
    domainRegistrar.safeTransferFrom(seller, msg.sender, domainTokenId);

    emit DomainSoldV2(
      msg.sender,
      seller,
      amount,
      address(domainRegistrar),
      domainTokenId,
      address(listingPaymentToken),
      topLevelId
    );
  }

  /// Cancels an existing bid for an NFT by marking it as already consumed
  /// so that it can never be fulfilled.
  /// @param account The account that made the specific bid
  /// @param bidNonce A nonce for the bid (account based nonce)
  function cancelBid(address account, uint256 bidNonce) external {
    require(
      msg.sender == account,
      "zAuction: Cannot cancel someone else's bid"
    );
    require(
      !consumed[account][bidNonce],
      "zAuction: Cannot cancel an already consumed bid"
    );

    consumed[account][bidNonce] = true;

    emit BidCancelled(bidNonce, account);
  }

  /// Allows setting of a zNS Hub that provides access to multiple
  /// registrars for different domains, instead of a single one.
  /// Because this contract has already been deployed this value
  /// cannot be set in the initializer. On new upgrades, this must
  /// be run immediately afterwards.
  /// @param hubAddress The address of the zNS Hub deployment
  function setZNSHub(IZNSHub hubAddress) public onlyOwner {
    require(
      address(hubAddress) != address(0),
      "zAuction: Cannot set the zNSHub to an empty address"
    );
    require(hubAddress != hub, "zAuction: Cannot set to the same hub");
    hub = hubAddress;
  }

  /// Allows the owner of the given token to set the fee owed upon sale
  /// Amount given should be as a percent with 5 decimals of precision
  /// e.g. 10% (max) is 1000000, 0.0001% (min) is 1
  /// @param id The id of the domain to update
  /// @param amount The amount to set
  function setTopLevelDomainFee(uint256 id, uint256 amount) external {
    require(
      msg.sender == hub.ownerOf(id),
      "zAuction: Cannot set fee on unowned domain"
    );
    require(amount <= 1000000, "zAuction: Cannot set a fee higher than 10%");
    require(amount != topLevelDomainFee[id], "zAuction: Amount is already set");
    topLevelDomainFee[id] = amount;
  }

  /// Get the defined ERC20 token used for payment of a domain in either bidding
  /// or immediate buying.
  /// @param domainTokenId The id of the domain to get an ERC20 token for
  function getPaymentTokenForDomain(uint256 domainTokenId)
    public
    view
    returns (IERC20)
  {
    require(domainTokenId != 0, "zAuction: Must provide a valid domainId");

    uint256 topLevelDomainId = getTopLevelId(domainTokenId);
    IERC20 paymentToken = networkPaymentToken[topLevelDomainId];

    // If value is unset, or set to 0 intentionally, we return the default
    if (paymentToken == IERC20(address(0))) {
      return defaultPaymentToken;
    } else {
      return paymentToken;
    }
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

    // Find what percent is specified as a top level fee
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
  /// @param bidNonce unique per address bid identifier chosen by seller
  /// @param bid token amount bid
  /// @param nftAddress the contract address of the domain
  /// @param tokenId token id we are transferring
  /// @param minbid minimum bid allowed
  /// @param startBlock block number at which acceptBid starts working
  /// @param expireBlock block number at which acceptBid stops working
  function createBid(
    uint256 bidNonce,
    uint256 bid,
    address nftAddress,
    uint256 tokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock
  ) public view returns (bytes32 data) {
    IRegistrar domainRegistrar = hub.getRegistrarForDomain(tokenId);
    return
      keccak256(
        abi.encode(
          bidNonce,
          address(this),
          block.chainid,
          bid,
          address(domainRegistrar),
          tokenId,
          minbid,
          startBlock,
          expireBlock
        )
      );
  }

  function createBidV2(
    uint256 bidNonce,
    uint256 bid,
    uint256 tokenId,
    uint256 minbid,
    uint256 startBlock,
    uint256 expireBlock,
    address bidToken
  ) public view returns (bytes32 data) {
    IRegistrar domainRegistrar = hub.getRegistrarForDomain(tokenId);
    return
      keccak256(
        abi.encode(
          bidNonce,
          address(this),
          block.chainid,
          bid,
          address(domainRegistrar),
          tokenId,
          minbid,
          startBlock,
          expireBlock,
          bidToken
        )
      );
  }

  /// Get the top level domain ID of a given domain. Will return self if already the top level.
  /// Note will not update the cache once found, this is to keep it a view function. To force
  /// updating the cache, instead use getTopLevelIdWithUpdate(uint256) below
  /// @param domainTokenId The domain ID to get the top level domain for.
  function getTopLevelId(uint256 domainTokenId) public view returns (uint256) {
    uint256 topLevelDomainId = topLevelDomainIdCache[domainTokenId];
    if (topLevelDomainId != 0) {
      return topLevelDomainId;
    }

    uint256 parentId = hub.parentOf(domainTokenId);
    uint256 holder = domainTokenId;
    while (parentId != 0) {
      holder = parentId;
      parentId = hub.parentOf(parentId);
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
  /// @param paymentToken The token of the network for that domain, used for payment in bids
  function paymentTransfers(
    address bidder,
    uint256 bid,
    address owner,
    uint256 topLevelId,
    uint256 tokenId,
    IERC20 paymentToken
  ) internal {
    address topLevelOwner = hub.ownerOf(topLevelId);
    uint256 topLevelFee = calculateTopLevelDomainFee(topLevelId, bid);
    uint256 minterRoyalty = calculateMinterRoyalty(tokenId, bid);

    uint256 bidActual = bid - minterRoyalty - topLevelFee;

    // Bidder -> Owner, pay transaction
    SafeERC20.safeTransferFrom(paymentToken, bidder, owner, bidActual);

    IRegistrar domainRegistrar = hub.getRegistrarForDomain(tokenId);

    // Bidder -> Minter, pay minter royalty
    SafeERC20.safeTransferFrom(
      paymentToken,
      bidder,
      domainRegistrar.minterOf(tokenId),
      minterRoyalty
    );

    // Bidder -> topLevel Owner, pay top level owner fee
    SafeERC20.safeTransferFrom(
      paymentToken,
      bidder,
      topLevelOwner,
      topLevelFee
    );
  }

  /// Get top level domain id for a domain. Update the cache once this is found.
  /// @param tokenId The id to get the top level owner of
  function getTopLevelIdWithUpdate(uint256 tokenId) private returns (uint256) {
    uint256 topLevelId = topLevelDomainIdCache[tokenId];
    if (topLevelId == 0) {
      topLevelId = getTopLevelId(tokenId);
      topLevelDomainIdCache[tokenId] = topLevelId;
    }
    return topLevelId;
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

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        assembly {
            r.slot := slot
        }
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

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 value
  ) internal {
    _callOptionalReturn(
      token,
      abi.encodeWithSelector(token.transfer.selector, to, value)
    );
  }

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 value
  ) internal {
    _callOptionalReturn(
      token,
      abi.encodeWithSelector(token.transferFrom.selector, from, to, value)
    );
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
    // solhint-disable-next-line max-line-length
    require(
      (value == 0) || (token.allowance(address(this), spender) == 0),
      "SafeERC20: approve from non-zero to non-zero allowance"
    );
    _callOptionalReturn(
      token,
      abi.encodeWithSelector(token.approve.selector, spender, value)
    );
  }

  function safeIncreaseAllowance(
    IERC20 token,
    address spender,
    uint256 value
  ) internal {
    uint256 newAllowance = token.allowance(address(this), spender) + value;
    _callOptionalReturn(
      token,
      abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
    );
  }

  function safeDecreaseAllowance(
    IERC20 token,
    address spender,
    uint256 value
  ) internal {
    unchecked {
      uint256 oldAllowance = token.allowance(address(this), spender);
      require(
        oldAllowance >= value,
        "SafeERC20: decreased allowance below zero"
      );
      uint256 newAllowance = oldAllowance - value;
      _callOptionalReturn(
        token,
        abi.encodeWithSelector(token.approve.selector, spender, newAllowance)
      );
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

    bytes memory returndata = address(token).functionCall(
      data,
      "SafeERC20: low-level call failed"
    );
    if (returndata.length > 0) {
      // Return data is optional
      // solhint-disable-next-line max-line-length
      require(
        abi.decode(returndata, (bool)),
        "SafeERC20: ERC20 operation did not succeed"
      );
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
pragma solidity ^0.8.4;

import {IRegistrar} from "./IRegistrar.sol";

interface IZNSHub {
  function addRegistrar(uint256 rootDomainId, address registrar) external;

  function isController(address controller) external returns (bool);

  function getRegistrarForDomain(uint256 domainId)
    external
    view
    returns (IRegistrar);

  function ownerOf(uint256 domainId) external view returns (address);

  function domainExists(uint256 domainId) external view returns (bool);

  function owner() external view returns (address);

  function registrarBeacon() external view returns (address);

  function domainTransferred(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function domainCreated(
    uint256 id,
    string calldata name,
    uint256 nameHash,
    uint256 parent,
    address minter,
    address controller,
    string calldata metadataUri,
    uint256 royaltyAmount
  ) external;

  function metadataLockChanged(
    uint256 id,
    address locker,
    bool isLocked
  ) external;

  function metadataChanged(uint256 id, string calldata uri) external;

  function royaltiesAmountChanged(uint256 id, uint256 amount) external;

  // Returns the parent domain of a child domain
  function parentOf(uint256 id) external view returns (uint256);
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
  function allowance(address owner, address spender)
    external
    view
    returns (uint256);

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
    assembly {
      size := extcodesize(account)
    }
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
    (bool success, ) = recipient.call{value: amount}("");
    require(
      success,
      "Address: unable to send value, recipient may have reverted"
    );
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
  function functionCall(address target, bytes memory data)
    internal
    returns (bytes memory)
  {
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
    return
      functionCallWithValue(
        target,
        data,
        value,
        "Address: low-level call with value failed"
      );
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
    require(
      address(this).balance >= value,
      "Address: insufficient balance for call"
    );
    require(isContract(target), "Address: call to non-contract");

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.call{value: value}(data);
    return _verifyCallResult(success, returndata, errorMessage);
  }

  /**
   * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
   * but performing a static call.
   *
   * _Available since v3.3._
   */
  function functionStaticCall(address target, bytes memory data)
    internal
    view
    returns (bytes memory)
  {
    return
      functionStaticCall(target, data, "Address: low-level static call failed");
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

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.staticcall(data);
    return _verifyCallResult(success, returndata, errorMessage);
  }

  function _verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) private pure returns (bytes memory) {
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