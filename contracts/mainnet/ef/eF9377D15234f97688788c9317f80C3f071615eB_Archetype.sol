// SPDX-License-Identifier: MIT
// Archetype v0.3.4
//
//        d8888                 888               888
//       d88888                 888               888
//      d88P888                 888               888
//     d88P 888 888d888 .d8888b 88888b.   .d88b.  888888 888  888 88888b.   .d88b.
//    d88P  888 888P"  d88P"    888 "88b d8P  Y8b 888    888  888 888 "88b d8P  Y8b
//   d88P   888 888    888      888  888 88888888 888    888  888 888  888 88888888
//  d8888888888 888    Y88b.    888  888 Y8b.     Y88b.  Y88b 888 888 d88P Y8b.
// d88P     888 888     "Y8888P 888  888  "Y8888   "Y888  "Y88888 88888P"   "Y8888
//                                                            888 888
//                                                       Y8b d88P 888
//                                                        "Y88P"  888

pragma solidity ^0.8.4;

import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import "erc721a-upgradeable/contracts/ERC721A__Initializable.sol";
import "./ERC721A__OwnableUpgradeable.sol";
import "solady/src/utils/MerkleProofLib.sol";
import "solady/src/utils/LibString.sol";
import "solady/src/utils/ECDSA.sol";
import "closedsea/src/OperatorFilterer.sol";

error InvalidConfig();
error MintNotYetStarted();
error WalletUnauthorizedToMint();
error InsufficientEthSent();
error ExcessiveEthSent();
error MaxSupplyExceeded();
error NumberOfMintsExceeded();
error MintingPaused();
error InvalidReferral();
error InvalidSignature();
error BalanceEmpty();
error TransferFailed();
error MaxBatchSizeExceeded();
error BurnToMintDisabled();
error NotTokenOwner();
error NotApprovedToTransfer();
error InvalidAmountOfTokens();
error WrongPassword();
error LockedForever();

contract Archetype is ERC721A__Initializable, ERC721AUpgradeable, OperatorFilterer, ERC721A__OwnableUpgradeable {
  //
  // EVENTS
  //
  event Invited(bytes32 indexed key, bytes32 indexed cid);
  event Referral(address indexed affiliate, uint128 wad, uint256 numMints);
  event Withdrawal(address indexed src, uint128 wad);

  //
  // STRUCTS
  //
  struct Auth {
    bytes32 key;
    bytes32[] proof;
  }

  struct MintTier {
    uint16 numMints;
    uint16 mintDiscount; //BPS
  }

  struct Discount {
    uint16 affiliateDiscount; //BPS
    MintTier[] mintTiers;
  }

  struct Config {
    string unrevealedUri;
    string baseUri;
    address affiliateSigner;
    address ownerAltPayout; // optional alternative address for owner withdrawals.
    address superAffiliatePayout; // optional super affiliate address, will receive half of platform fee if set.
    uint32 maxSupply;
    uint32 maxBatchSize;
    uint16 affiliateFee; //BPS
    uint16 platformFee; //BPS
    Discount discounts;
  }

  struct Invite {
    uint128 price;
    uint64 start;
    uint64 limit;
  }

  struct Invitelist {
    bytes32 key;
    bytes32 cid;
    Invite invite;
  }

  struct OwnerBalance {
    uint128 owner;
    uint128 platform;
  }

  struct BurnConfig {
    Archetype archetype;
    bool enabled;
    uint16 ratio;
    uint64 start;
    uint64 limit;
  }

  //
  // VARIABLES
  //
  mapping(bytes32 => Invite) public invites;
  mapping(address => mapping(bytes32 => uint256)) private minted;
  mapping(address => uint128) public affiliateBalance;
  mapping(uint256 => bytes) private tokenMsg;

  OwnerBalance public ownerBalance;
  Config public config;
  BurnConfig public burnConfig;

  bool public uriLocked;
  bool public maxSupplyLocked;
  bool public affiliateFeeLocked;
  bool public discountsLocked;
  bool public ownerAltPayoutLocked;
  bool public royaltyEnforcementEnabled;
  bool public royaltyEnforcementLocked;
  bool public provenanceHashLocked;
  string public provenance;

  // address private constant PLATFORM = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // TEST (account[2])
  address private constant PLATFORM = 0x86B82972282Dd22348374bC63fd21620F7ED847B;
  uint16 private constant MAXBPS = 5000; // max fee or discount is 50%

  //
  // METHODS
  //
  function initialize(
    string memory name,
    string memory symbol,
    Config calldata config_
  ) external initializerERC721A {
    __ERC721A_init(name, symbol);
    // check max bps not reached and min platform fee.
    if (
      config_.affiliateFee > MAXBPS ||
      config_.platformFee > MAXBPS ||
      config_.platformFee < 500 ||
      config_.discounts.affiliateDiscount > MAXBPS ||
      config_.affiliateSigner == address(0) ||
      config_.maxBatchSize == 0
    ) {
      revert InvalidConfig();
    }
    // ensure mint tiers are correctly ordered from highest to lowest.
    for (uint256 i = 1; i < config_.discounts.mintTiers.length; i++) {
      if (
        config_.discounts.mintTiers[i].mintDiscount > MAXBPS ||
        config_.discounts.mintTiers[i].numMints > config_.discounts.mintTiers[i - 1].numMints
      ) {
        revert InvalidConfig();
      }
    }
    config = config_;
    __Ownable_init();
    uriLocked = false;
    maxSupplyLocked = false;
    affiliateFeeLocked = false;
    discountsLocked = false;
    ownerAltPayoutLocked = false;
    provenanceHashLocked = false;
    royaltyEnforcementEnabled = false;
    royaltyEnforcementLocked = false;
  }

  //
  // PUBLIC
  //
  function mint(
    Auth calldata auth,
    uint256 quantity,
    address affiliate,
    bytes calldata signature
  ) external payable {
    mintTo(auth, quantity, msg.sender, affiliate, signature);
  }

  function batchMintTo(
    Auth calldata auth,
    address[] calldata toList,
    uint256[] calldata quantityList,
    address affiliate,
    bytes calldata signature
  ) public payable {
    if(quantityList.length != toList.length) {
      revert InvalidConfig();
    }
    uint256 quantity = 0;
    for (uint256 i=0; i< quantityList.length; i++){
      quantity += quantityList[i];
    }
    validateMint(auth, quantity, affiliate, signature);
    
    for (uint256 i=0; i< toList.length; i++){
      _mint(toList[i], quantityList[i]);
    }

    Invite memory invite = invites[auth.key];
    if (invite.limit < config.maxSupply) {
      minted[msg.sender][auth.key] += quantity;
    }
    payoutEth(affiliate, quantity);
  }

  function mintTo(
    Auth calldata auth,
    uint256 quantity,
    address to,
    address affiliate,
    bytes calldata signature
  ) public payable {

    validateMint(auth, quantity, affiliate, signature);
    _mint(to, quantity);

    Invite memory i = invites[auth.key];
    if (i.limit < config.maxSupply) {
      minted[msg.sender][auth.key] += quantity;
    }
    payoutEth(affiliate, quantity);
  }

  function burnToMint(uint256[] calldata tokenIds) external {
    if (!burnConfig.enabled) {
      revert BurnToMintDisabled();
    }

    if (block.timestamp < burnConfig.start) {
      revert MintNotYetStarted();
    }

    // check if msg.sender owns tokens and has correct approvals
    for (uint256 i = 0; i < tokenIds.length; i++) {
      if (burnConfig.archetype.ownerOf(tokenIds[i]) != msg.sender) {
        revert NotTokenOwner();
      }
    }

    if (!burnConfig.archetype.isApprovedForAll(msg.sender, address(this))) {
      revert NotApprovedToTransfer();
    }

    if (tokenIds.length % burnConfig.ratio != 0) {
      revert InvalidAmountOfTokens();
    }

    uint256 quantity = tokenIds.length / burnConfig.ratio;

    if (quantity > config.maxBatchSize) {
      revert MaxBatchSizeExceeded();
    }

    if (burnConfig.limit < config.maxSupply) {
      uint256 totalAfterMint = minted[msg.sender][bytes32("burn")] + quantity;

      if (totalAfterMint > burnConfig.limit) {
        revert NumberOfMintsExceeded();
      }
    }

    if ((_totalMinted() + quantity) > config.maxSupply) {
      revert MaxSupplyExceeded();
    }

    for (uint256 i = 0; i < tokenIds.length; i++) {
      burnConfig.archetype.transferFrom(
        msg.sender,
        address(0x000000000000000000000000000000000000dEaD),
        tokenIds[i]
      );
    }
    _mint(msg.sender, quantity);

    if (burnConfig.limit < config.maxSupply) {
      minted[msg.sender][bytes32("burn")] += quantity;
    }
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

    return
      bytes(config.baseUri).length != 0
        ? string(abi.encodePacked(config.baseUri, LibString.toString(tokenId)))
        : "";
  }

  function withdraw() external {
    uint128 wad = 0;

    if (msg.sender == owner() || msg.sender == config.ownerAltPayout || msg.sender == PLATFORM) {
      OwnerBalance memory balance = ownerBalance;
      if (msg.sender == owner() || msg.sender == config.ownerAltPayout) {
        wad = balance.owner;
        ownerBalance = OwnerBalance({ owner: 0, platform: balance.platform });
      } else {
        wad = balance.platform;
        ownerBalance = OwnerBalance({ owner: balance.owner, platform: 0 });
      }
    } else {
      wad = affiliateBalance[msg.sender];
      affiliateBalance[msg.sender] = 0;
    }

    if (wad == 0) {
      revert BalanceEmpty();
    }
    bool success = false;
    // send to ownerAltPayout if set and owner is withdrawing
    if (msg.sender == owner() && config.ownerAltPayout != address(0)) {
      (success, ) = payable(config.ownerAltPayout).call{ value: wad }("");
    } else {
      (success, ) = msg.sender.call{ value: wad }("");
    }
    if (!success) {
      revert TransferFailed();
    }
    emit Withdrawal(msg.sender, wad);
  }

  function setTokenMsg(uint256 tokenId, string calldata message) external {
    if (msg.sender != ownerOf(tokenId)) {
      revert NotTokenOwner();
    }

    tokenMsg[tokenId] = bytes(message);
  }

  function getTokenMsg(uint256 tokenId) external view returns (string memory) {
    if (!_exists(tokenId)) revert URIQueryForNonexistentToken();
    return string(tokenMsg[tokenId]);
  }

  // calculate price based on affiliate usage and mint discounts
  function computePrice(
    uint128 price,
    uint256 numTokens,
    bool affiliateUsed
  ) public view returns (uint256) {
    uint256 cost = price * numTokens;

    if (affiliateUsed) {
      cost = cost - ((cost * config.discounts.affiliateDiscount) / 10000);
    }

    for (uint256 i = 0; i < config.discounts.mintTiers.length; i++) {
      if (numTokens >= config.discounts.mintTiers[i].numMints) {
        return cost = cost - ((cost * config.discounts.mintTiers[i].mintDiscount) / 10000);
      }
    }
    return cost;
  }

  //
  // OWNER ONLY
  //

  function setBaseURI(string memory baseUri) external onlyOwner {
    if (uriLocked) {
      revert LockedForever();
    }

    config.baseUri = baseUri;
  }

  /// @notice the password is "forever"
  function lockURI(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    uriLocked = true;
  }

  /// @notice the password is "forever"
  // max supply cannot subceed total supply. Be careful changing.
  function setMaxSupply(uint32 maxSupply, string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }
    
    if (maxSupplyLocked) {
      revert LockedForever();
    }

    if (maxSupply < _totalMinted()) {
      revert MaxSupplyExceeded();
    }

    config.maxSupply = maxSupply;
  }

  /// @notice the password is "forever"
  function lockMaxSupply(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    maxSupplyLocked = true;
  }

  function setAffiliateFee(uint16 affiliateFee) external onlyOwner {
    if (affiliateFeeLocked) {
      revert LockedForever();
    }
    if (affiliateFee > MAXBPS) {
      revert InvalidConfig();
    }

    config.affiliateFee = affiliateFee;
  }

  /// @notice the password is "forever"
  function lockAffiliateFee(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    affiliateFeeLocked = true;
  }

  function setDiscounts(Discount calldata discounts) external onlyOwner {
    if (discountsLocked) {
      revert LockedForever();
    }

    if (discounts.affiliateDiscount > MAXBPS) {
      revert InvalidConfig();
    }

    // ensure mint tiers are correctly ordered from highest to lowest.
    for (uint256 i = 1; i < discounts.mintTiers.length; i++) {
      if (
        discounts.mintTiers[i].mintDiscount > MAXBPS ||
        discounts.mintTiers[i].numMints > discounts.mintTiers[i - 1].numMints
      ) {
        revert InvalidConfig();
      }
    }

    config.discounts = discounts;
  }

  /// @notice the password is "forever"
  function lockDiscounts(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    discountsLocked = true;
  }

  /// @notice Set BAYC-style provenance once it's calculated
  function setProvenanceHash(string memory provenanceHash) external onlyOwner {
    if (provenanceHashLocked) {
      revert LockedForever();
    }

    provenance = provenanceHash;
  }

  /// @notice the password is "forever"
  function lockProvenanceHash(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    provenanceHashLocked = true;
  }

  function setOwnerAltPayout(address ownerAltPayout) external onlyOwner {
    if (ownerAltPayoutLocked) {
      revert LockedForever();
    }

    config.ownerAltPayout = ownerAltPayout;
  }

  /// @notice the password is "forever"
  function lockOwnerAltPayout(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    ownerAltPayoutLocked = true;
  }

  function setInvites(Invitelist[] calldata invitelist) external onlyOwner {
    for (uint256 i = 0; i < invitelist.length; i++) {
      Invitelist calldata list = invitelist[i];
      invites[list.key] = list.invite;
      emit Invited(list.key, list.cid);
    }
  }

  function setInvite(
    bytes32 _key,
    bytes32 _cid,
    Invite calldata _invite
  ) external onlyOwner {
    invites[_key] = _invite;
    emit Invited(_key, _cid);
  }

  function enableBurnToMint(
    address archetype,
    uint16 ratio,
    uint64 start,
    uint64 limit
  ) external onlyOwner {
    burnConfig = BurnConfig({
      archetype: Archetype(archetype),
      enabled: true,
      ratio: ratio,
      start: start,
      limit: limit
    });
  }

  function disableBurnToMint() external onlyOwner {
    burnConfig = BurnConfig({
      enabled: false,
      ratio: 0,
      archetype: Archetype(address(0)),
      start: 0,
      limit: 0
    });
  }

  //
  // PLATFORM ONLY
  //
  function setSuperAffiliatePayout(address superAffiliatePayout) external onlyPlatform {
    config.superAffiliatePayout = superAffiliatePayout;
  }

  //
  // INTERNAL
  //
  function _startTokenId() internal view virtual override returns (uint256) {
    return 1;
  }

  function payoutEth(address affiliate, uint256 quantity) internal {
    uint128 value = uint128(msg.value);

    uint128 affiliateWad = 0;
    if (affiliate != address(0)) {
      affiliateWad = (value * config.affiliateFee) / 10000;
      affiliateBalance[affiliate] += affiliateWad;
      emit Referral(affiliate, affiliateWad, quantity);
    }

    uint128 superAffiliateWad = 0;
    if (config.superAffiliatePayout != address(0)) {
      superAffiliateWad = ((value * config.platformFee) / 2) / 10000;
      affiliateBalance[config.superAffiliatePayout] += superAffiliateWad;
    }

    OwnerBalance memory balance = ownerBalance;
    uint128 platformWad = ((value * config.platformFee) / 10000) - superAffiliateWad;
    uint128 ownerWad = value - affiliateWad - platformWad - superAffiliateWad;
    ownerBalance = OwnerBalance({
      owner: balance.owner + ownerWad,
      platform: balance.platform + platformWad
    });
  }

  function validateMint(
    Auth calldata auth,
    uint256 quantity,
    address affiliate,
    bytes calldata signature
  ) internal view {
    Invite memory i = invites[auth.key];

    if (affiliate != address(0)) {
      if (affiliate == PLATFORM || affiliate == owner() || affiliate == msg.sender) {
        revert InvalidReferral();
      }
      validateAffiliate(affiliate, signature, config.affiliateSigner);
    }

    if (i.limit == 0) {
      revert MintingPaused();
    }

    if (!verify(auth, msg.sender)) {
      revert WalletUnauthorizedToMint();
    }

    if (block.timestamp < i.start) {
      revert MintNotYetStarted();
    }

    if (i.limit < config.maxSupply) {
      uint256 totalAfterMint = minted[msg.sender][auth.key] + quantity;

      if (totalAfterMint > i.limit) {
        revert NumberOfMintsExceeded();
      }
    }

    if (quantity > config.maxBatchSize) {
      revert MaxBatchSizeExceeded();
    }

    if ((_totalMinted() + quantity) > config.maxSupply) {
      revert MaxSupplyExceeded();
    }

    uint256 cost = computePrice(i.price, quantity, affiliate != address(0));

    if (msg.value < cost) {
      revert InsufficientEthSent();
    }

    if (msg.value > cost) {
      revert ExcessiveEthSent();
    }
  }

  function validateAffiliate(
    address affiliate,
    bytes calldata signature,
    address affiliateSigner
  ) internal view {
    bytes32 signedMessagehash = ECDSA.toEthSignedMessageHash(
      keccak256(abi.encodePacked(affiliate))
    );
    address signer = ECDSA.recover(signedMessagehash, signature);

    if (signer != affiliateSigner) {
      revert InvalidSignature();
    }
  }

  function verify(Auth calldata auth, address account) internal pure returns (bool) {
    if (auth.key == "") return true;

    return MerkleProofLib.verify(auth.proof, auth.key, keccak256(abi.encodePacked(account)));
  }

  modifier onlyPlatform() {
    require(PLATFORM == _msgSenderERC721A(), "caller is not the platform");
    _;
  }

  // OPTIONAL ROYALTY ENFORCEMENT WITH OPENSEA
  function enableRoyaltyEnforcement() external onlyOwner {
    if (royaltyEnforcementLocked) {
      revert LockedForever();
    }
    _registerForOperatorFiltering();
    royaltyEnforcementEnabled = true;
  }

  function disableRoyaltyEnforcement() external onlyOwner{
    if (royaltyEnforcementLocked) {
      revert LockedForever();
    }
    royaltyEnforcementEnabled = false;
  }

  /// @notice the password is "forever"
  function lockRoyaltyEnforcement(string memory password) external onlyOwner {
    if (keccak256(abi.encodePacked(password)) != keccak256(abi.encodePacked("forever"))) {
      revert WrongPassword();
    }

    royaltyEnforcementLocked = true;
  }

  function setApprovalForAll(address operator, bool approved) 
  public override onlyAllowedOperatorApproval(operator, royaltyEnforcementEnabled) {
      super.setApprovalForAll(operator, approved);
  }

  function approve(address operator, uint256 tokenId)
  public override onlyAllowedOperatorApproval(operator, royaltyEnforcementEnabled) {
      super.approve(operator, tokenId);
  }

  function transferFrom(address from, address to, uint256 tokenId)
  public override onlyAllowedOperator(from, royaltyEnforcementEnabled) {
      super.transferFrom(from, to, tokenId);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId)
  public override onlyAllowedOperator(from, royaltyEnforcementEnabled) {
      super.safeTransferFrom(from, to, tokenId);
  }

  function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
  public override onlyAllowedOperator(from, royaltyEnforcementEnabled) {
      super.safeTransferFrom(from, to, tokenId, data);
  }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creator: Chiru Labs

pragma solidity ^0.8.4;

import "./IERC721AUpgradeable.sol";
import {ERC721AStorage} from "./ERC721AStorage.sol";
import "./ERC721A__Initializable.sol";

/**
 * @dev Interface of ERC721 token receiver.
 */
interface ERC721A__IERC721ReceiverUpgradeable {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title ERC721A
 *
 * @dev Implementation of the [ERC721](https://eips.ethereum.org/EIPS/eip-721)
 * Non-Fungible Token Standard, including the Metadata extension.
 * Optimized for lower gas during batch mints.
 *
 * Token IDs are minted in sequential order (e.g. 0, 1, 2, 3, ...)
 * starting from `_startTokenId()`.
 *
 * Assumptions:
 *
 * - An owner cannot have more than 2**64 - 1 (max value of uint64) of supply.
 * - The maximum token ID cannot exceed 2**256 - 1 (max value of uint256).
 */
contract ERC721AUpgradeable is ERC721A__Initializable, IERC721AUpgradeable {
    using ERC721AStorage for ERC721AStorage.Layout;

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Mask of an entry in packed address data.
    uint256 private constant _BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;

    // The bit position of `numberMinted` in packed address data.
    uint256 private constant _BITPOS_NUMBER_MINTED = 64;

    // The bit position of `numberBurned` in packed address data.
    uint256 private constant _BITPOS_NUMBER_BURNED = 128;

    // The bit position of `aux` in packed address data.
    uint256 private constant _BITPOS_AUX = 192;

    // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
    uint256 private constant _BITMASK_AUX_COMPLEMENT = (1 << 192) - 1;

    // The bit position of `startTimestamp` in packed ownership.
    uint256 private constant _BITPOS_START_TIMESTAMP = 160;

    // The bit mask of the `burned` bit in packed ownership.
    uint256 private constant _BITMASK_BURNED = 1 << 224;

    // The bit position of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITPOS_NEXT_INITIALIZED = 225;

    // The bit mask of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITMASK_NEXT_INITIALIZED = 1 << 225;

    // The bit position of `extraData` in packed ownership.
    uint256 private constant _BITPOS_EXTRA_DATA = 232;

    // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
    uint256 private constant _BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

    // The mask of the lower 160 bits for addresses.
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    // The maximum `quantity` that can be minted with {_mintERC2309}.
    // This limit is to prevent overflows on the address data entries.
    // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
    // is required to cause an overflow, which is unrealistic.
    uint256 private constant _MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

    // The `Transfer` event signature is given by:
    // `keccak256(bytes("Transfer(address,address,uint256)"))`.
    bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    function __ERC721A_init(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        __ERC721A_init_unchained(name_, symbol_);
    }

    function __ERC721A_init_unchained(string memory name_, string memory symbol_) internal onlyInitializingERC721A {
        ERC721AStorage.layout()._name = name_;
        ERC721AStorage.layout()._symbol = symbol_;
        ERC721AStorage.layout()._currentIndex = _startTokenId();
    }

    // =============================================================
    //                   TOKEN COUNTING OPERATIONS
    // =============================================================

    /**
     * @dev Returns the starting token ID.
     * To change the starting token ID, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function _nextTokenId() internal view virtual returns (uint256) {
        return ERC721AStorage.layout()._currentIndex;
    }

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than `_currentIndex - _startTokenId()` times.
        unchecked {
            return ERC721AStorage.layout()._currentIndex - ERC721AStorage.layout()._burnCounter - _startTokenId();
        }
    }

    /**
     * @dev Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view virtual returns (uint256) {
        // Counter underflow is impossible as `_currentIndex` does not decrement,
        // and it is initialized to `_startTokenId()`.
        unchecked {
            return ERC721AStorage.layout()._currentIndex - _startTokenId();
        }
    }

    /**
     * @dev Returns the total number of tokens burned.
     */
    function _totalBurned() internal view virtual returns (uint256) {
        return ERC721AStorage.layout()._burnCounter;
    }

    // =============================================================
    //                    ADDRESS DATA OPERATIONS
    // =============================================================

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return ERC721AStorage.layout()._packedAddressData[owner] & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return
            (ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_NUMBER_MINTED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return
            (ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_NUMBER_BURNED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        return uint64(ERC721AStorage.layout()._packedAddressData[owner] >> _BITPOS_AUX);
    }

    /**
     * Sets the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal virtual {
        uint256 packed = ERC721AStorage.layout()._packedAddressData[owner];
        uint256 auxCasted;
        // Cast `aux` with assembly to avoid redundant masking.
        assembly {
            auxCasted := aux
        }
        packed = (packed & _BITMASK_AUX_COMPLEMENT) | (auxCasted << _BITPOS_AUX);
        ERC721AStorage.layout()._packedAddressData[owner] = packed;
    }

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // The interface IDs are constants representing the first 4 bytes
        // of the XOR of all function selectors in the interface.
        // See: [ERC165](https://eips.ethereum.org/EIPS/eip-165)
        // (e.g. `bytes4(i.functionA.selector ^ i.functionB.selector ^ ...)`)
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f; // ERC165 interface ID for ERC721Metadata.
    }

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return ERC721AStorage.layout()._name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return ERC721AStorage.layout()._symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId))) : '';
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return '';
    }

    // =============================================================
    //                     OWNERSHIPS OPERATIONS
    // =============================================================

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return address(uint160(_packedOwnershipOf(tokenId)));
    }

    /**
     * @dev Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around over time.
     */
    function _ownershipOf(uint256 tokenId) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(_packedOwnershipOf(tokenId));
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct at `index`.
     */
    function _ownershipAt(uint256 index) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(ERC721AStorage.layout()._packedOwnerships[index]);
    }

    /**
     * @dev Initializes the ownership slot minted at `index` for efficiency purposes.
     */
    function _initializeOwnershipAt(uint256 index) internal virtual {
        if (ERC721AStorage.layout()._packedOwnerships[index] == 0) {
            ERC721AStorage.layout()._packedOwnerships[index] = _packedOwnershipOf(index);
        }
    }

    /**
     * Returns the packed ownership data of `tokenId`.
     */
    function _packedOwnershipOf(uint256 tokenId) private view returns (uint256) {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr)
                if (curr < ERC721AStorage.layout()._currentIndex) {
                    uint256 packed = ERC721AStorage.layout()._packedOwnerships[curr];
                    // If not burned.
                    if (packed & _BITMASK_BURNED == 0) {
                        // Invariant:
                        // There will always be an initialized ownership slot
                        // (i.e. `ownership.addr != address(0) && ownership.burned == false`)
                        // before an unintialized ownership slot
                        // (i.e. `ownership.addr == address(0) && ownership.burned == false`)
                        // Hence, `curr` will not underflow.
                        //
                        // We can directly compare the packed value.
                        // If the address is zero, packed will be zero.
                        while (packed == 0) {
                            packed = ERC721AStorage.layout()._packedOwnerships[--curr];
                        }
                        return packed;
                    }
                }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct from `packed`.
     */
    function _unpackedOwnership(uint256 packed) private pure returns (TokenOwnership memory ownership) {
        ownership.addr = address(uint160(packed));
        ownership.startTimestamp = uint64(packed >> _BITPOS_START_TIMESTAMP);
        ownership.burned = packed & _BITMASK_BURNED != 0;
        ownership.extraData = uint24(packed >> _BITPOS_EXTRA_DATA);
    }

    /**
     * @dev Packs ownership data into a single uint256.
     */
    function _packOwnershipData(address owner, uint256 flags) private view returns (uint256 result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // `owner | (block.timestamp << _BITPOS_START_TIMESTAMP) | flags`.
            result := or(owner, or(shl(_BITPOS_START_TIMESTAMP, timestamp()), flags))
        }
    }

    /**
     * @dev Returns the `nextInitialized` flag set if `quantity` equals 1.
     */
    function _nextInitializedFlag(uint256 quantity) private pure returns (uint256 result) {
        // For branchless setting of the `nextInitialized` flag.
        assembly {
            // `(quantity == 1) << _BITPOS_NEXT_INITIALIZED`.
            result := shl(_BITPOS_NEXT_INITIALIZED, eq(quantity, 1))
        }
    }

    // =============================================================
    //                      APPROVAL OPERATIONS
    // =============================================================

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);

        if (_msgSenderERC721A() != owner)
            if (!isApprovedForAll(owner, _msgSenderERC721A())) {
                revert ApprovalCallerNotOwnerNorApproved();
            }

        ERC721AStorage.layout()._tokenApprovals[tokenId].value = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

        return ERC721AStorage.layout()._tokenApprovals[tokenId].value;
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == _msgSenderERC721A()) revert ApproveToCaller();

        ERC721AStorage.layout()._operatorApprovals[_msgSenderERC721A()][operator] = approved;
        emit ApprovalForAll(_msgSenderERC721A(), operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return ERC721AStorage.layout()._operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted. See {_mint}.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return
            _startTokenId() <= tokenId &&
            tokenId < ERC721AStorage.layout()._currentIndex && // If within bounds,
            ERC721AStorage.layout()._packedOwnerships[tokenId] & _BITMASK_BURNED == 0; // and not burned.
    }

    /**
     * @dev Returns whether `msgSender` is equal to `approvedAddress` or `owner`.
     */
    function _isSenderApprovedOrOwner(
        address approvedAddress,
        address owner,
        address msgSender
    ) private pure returns (bool result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // Mask `msgSender` to the lower 160 bits, in case the upper bits somehow aren't clean.
            msgSender := and(msgSender, _BITMASK_ADDRESS)
            // `msgSender == owner || msgSender == approvedAddress`.
            result := or(eq(msgSender, owner), eq(msgSender, approvedAddress))
        }
    }

    /**
     * @dev Returns the storage slot and value for the approved address of `tokenId`.
     */
    function _getApprovedSlotAndAddress(uint256 tokenId)
        private
        view
        returns (uint256 approvedAddressSlot, address approvedAddress)
    {
        ERC721AStorage.TokenApprovalRef storage tokenApproval = ERC721AStorage.layout()._tokenApprovals[tokenId];
        // The following is equivalent to `approvedAddress = _tokenApprovals[tokenId].value`.
        assembly {
            approvedAddressSlot := tokenApproval.slot
            approvedAddress := sload(approvedAddressSlot)
        }
    }

    // =============================================================
    //                      TRANSFER OPERATIONS
    // =============================================================

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        if (address(uint160(prevOwnershipPacked)) != from) revert TransferFromIncorrectOwner();

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        // The nested ifs save around 20+ gas over a compound boolean condition.
        if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
            if (!isApprovedForAll(from, _msgSenderERC721A())) revert TransferCallerNotOwnerNorApproved();

        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // We can directly increment and decrement the balances.
            --ERC721AStorage.layout()._packedAddressData[from]; // Updates: `balance -= 1`.
            ++ERC721AStorage.layout()._packedAddressData[to]; // Updates: `balance += 1`.

            // Updates:
            // - `address` to the next owner.
            // - `startTimestamp` to the timestamp of transfering.
            // - `burned` to `false`.
            // - `nextInitialized` to `true`.
            ERC721AStorage.layout()._packedOwnerships[tokenId] = _packOwnershipData(
                to,
                _BITMASK_NEXT_INITIALIZED | _nextExtraData(from, to, prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (ERC721AStorage.layout()._packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != ERC721AStorage.layout()._currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        ERC721AStorage.layout()._packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, '');
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0)
            if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
                revert TransferToNonERC721ReceiverImplementer();
            }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token IDs
     * are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token IDs
     * have been transferred. This includes minting.
     * And also called after one token has been burned.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * `from` - Previous owner of the given token ID.
     * `to` - Target address that will receive the token.
     * `tokenId` - Token ID to be transferred.
     * `_data` - Optional data to send along with the call.
     *
     * Returns whether the call correctly returned the expected magic value.
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try
            ERC721A__IERC721ReceiverUpgradeable(to).onERC721Received(_msgSenderERC721A(), from, tokenId, _data)
        returns (bytes4 retval) {
            return retval == ERC721A__IERC721ReceiverUpgradeable(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    // =============================================================
    //                        MINT OPERATIONS
    // =============================================================

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = ERC721AStorage.layout()._currentIndex;
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // `balance` and `numberMinted` have a maximum limit of 2**64.
        // `tokenId` has a maximum limit of 2**256.
        unchecked {
            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            ERC721AStorage.layout()._packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            ERC721AStorage.layout()._packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            uint256 toMasked;
            uint256 end = startTokenId + quantity;

            // Use assembly to loop and emit the `Transfer` event for gas savings.
            // The duplicated `log4` removes an extra check and reduces stack juggling.
            // The assembly, together with the surrounding Solidity code, have been
            // delicately arranged to nudge the compiler into producing optimized opcodes.
            assembly {
                // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
                toMasked := and(to, _BITMASK_ADDRESS)
                // Emit the `Transfer` event.
                log4(
                    0, // Start of data (0, since no data).
                    0, // End of data (0, since no data).
                    _TRANSFER_EVENT_SIGNATURE, // Signature.
                    0, // `address(0)`.
                    toMasked, // `to`.
                    startTokenId // `tokenId`.
                )

                for {
                    let tokenId := add(startTokenId, 1)
                } iszero(eq(tokenId, end)) {
                    tokenId := add(tokenId, 1)
                } {
                    // Emit the `Transfer` event. Similar to above.
                    log4(0, 0, _TRANSFER_EVENT_SIGNATURE, 0, toMasked, tokenId)
                }
            }
            if (toMasked == 0) revert MintToZeroAddress();

            ERC721AStorage.layout()._currentIndex = end;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * This function is intended for efficient minting only during contract creation.
     *
     * It emits only one {ConsecutiveTransfer} as defined in
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309),
     * instead of a sequence of {Transfer} event(s).
     *
     * Calling this function outside of contract creation WILL make your contract
     * non-compliant with the ERC721 standard.
     * For full ERC721 compliance, substituting ERC721 {Transfer} event(s) with the ERC2309
     * {ConsecutiveTransfer} event is only permissible during contract creation.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {ConsecutiveTransfer} event.
     */
    function _mintERC2309(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = ERC721AStorage.layout()._currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();
        if (quantity > _MAX_MINT_ERC2309_QUANTITY_LIMIT) revert MintERC2309QuantityExceedsLimit();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are unrealistic due to the above check for `quantity` to be below the limit.
        unchecked {
            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            ERC721AStorage.layout()._packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            ERC721AStorage.layout()._packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            emit ConsecutiveTransfer(startTokenId, startTokenId + quantity - 1, address(0), to);

            ERC721AStorage.layout()._currentIndex = startTokenId + quantity;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * See {_mint}.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        _mint(to, quantity);

        unchecked {
            if (to.code.length != 0) {
                uint256 end = ERC721AStorage.layout()._currentIndex;
                uint256 index = end - quantity;
                do {
                    if (!_checkContractOnERC721Received(address(0), to, index++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (index < end);
                // Reentrancy protection.
                if (ERC721AStorage.layout()._currentIndex != end) revert();
            }
        }
    }

    /**
     * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, '');
    }

    // =============================================================
    //                        BURN OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_burn(tokenId, false)`.
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        address from = address(uint160(prevOwnershipPacked));

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        if (approvalCheck) {
            // The nested ifs save around 20+ gas over a compound boolean condition.
            if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
                if (!isApprovedForAll(from, _msgSenderERC721A())) revert TransferCallerNotOwnerNorApproved();
        }

        _beforeTokenTransfers(from, address(0), tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // Updates:
            // - `balance -= 1`.
            // - `numberBurned += 1`.
            //
            // We can directly decrement the balance, and increment the number burned.
            // This is equivalent to `packed -= 1; packed += 1 << _BITPOS_NUMBER_BURNED;`.
            ERC721AStorage.layout()._packedAddressData[from] += (1 << _BITPOS_NUMBER_BURNED) - 1;

            // Updates:
            // - `address` to the last owner.
            // - `startTimestamp` to the timestamp of burning.
            // - `burned` to `true`.
            // - `nextInitialized` to `true`.
            ERC721AStorage.layout()._packedOwnerships[tokenId] = _packOwnershipData(
                from,
                (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED) | _nextExtraData(from, address(0), prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (ERC721AStorage.layout()._packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != ERC721AStorage.layout()._currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        ERC721AStorage.layout()._packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, address(0), tokenId);
        _afterTokenTransfers(from, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            ERC721AStorage.layout()._burnCounter++;
        }
    }

    // =============================================================
    //                     EXTRA DATA OPERATIONS
    // =============================================================

    /**
     * @dev Directly sets the extra data for the ownership data `index`.
     */
    function _setExtraDataAt(uint256 index, uint24 extraData) internal virtual {
        uint256 packed = ERC721AStorage.layout()._packedOwnerships[index];
        if (packed == 0) revert OwnershipNotInitializedForExtraData();
        uint256 extraDataCasted;
        // Cast `extraData` with assembly to avoid redundant masking.
        assembly {
            extraDataCasted := extraData
        }
        packed = (packed & _BITMASK_EXTRA_DATA_COMPLEMENT) | (extraDataCasted << _BITPOS_EXTRA_DATA);
        ERC721AStorage.layout()._packedOwnerships[index] = packed;
    }

    /**
     * @dev Called during each token transfer to set the 24bit `extraData` field.
     * Intended to be overridden by the cosumer contract.
     *
     * `previousExtraData` - the value of `extraData` before transfer.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _extraData(
        address from,
        address to,
        uint24 previousExtraData
    ) internal view virtual returns (uint24) {}

    /**
     * @dev Returns the next extra data for the packed ownership data.
     * The returned result is shifted into position.
     */
    function _nextExtraData(
        address from,
        address to,
        uint256 prevOwnershipPacked
    ) private view returns (uint256) {
        uint24 extraData = uint24(prevOwnershipPacked >> _BITPOS_EXTRA_DATA);
        return uint256(_extraData(from, to, extraData)) << _BITPOS_EXTRA_DATA;
    }

    // =============================================================
    //                       OTHER OPERATIONS
    // =============================================================

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * If you are writing GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC721A() internal view virtual returns (address) {
        return msg.sender;
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit),
            // but we allocate 0x80 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 32-byte word to store the length,
            // and 3 32-byte words to store a maximum of 78 digits. Total: 0x20 + 3 * 0x20 = 0x80.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, str)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @dev This is a base contract to aid in writing upgradeable diamond facet contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */

import {ERC721A__InitializableStorage} from "./ERC721A__InitializableStorage.sol";

abstract contract ERC721A__Initializable {
    using ERC721A__InitializableStorage for ERC721A__InitializableStorage.Layout;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializerERC721A() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(
            ERC721A__InitializableStorage.layout()._initializing
                ? _isConstructor()
                : !ERC721A__InitializableStorage.layout()._initialized,
            'ERC721A__Initializable: contract is already initialized'
        );

        bool isTopLevelCall = !ERC721A__InitializableStorage.layout()._initializing;
        if (isTopLevelCall) {
            ERC721A__InitializableStorage.layout()._initializing = true;
            ERC721A__InitializableStorage.layout()._initialized = true;
        }

        _;

        if (isTopLevelCall) {
            ERC721A__InitializableStorage.layout()._initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializingERC721A() {
        require(
            ERC721A__InitializableStorage.layout()._initializing,
            'ERC721A__Initializable: contract is not initializing'
        );
        _;
    }

    /// @dev Returns true if and only if the function is running in the constructor
    function _isConstructor() private view returns (bool) {
        // extcodesize checks the size of the code stored in an address, and
        // address returns the current address. Since the code is still not
        // deployed when running a constructor, any checks on its code size will
        // yield zero, making it an effective way to detect if a contract is
        // under construction or not.
        address self = address(this);
        uint256 cs;
        assembly {
            cs := extcodesize(self)
        }
        return cs == 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

import 'erc721a-upgradeable/contracts/ERC721A__Initializable.sol';
import 'erc721a-upgradeable/contracts/ERC721AUpgradeable.sol';

pragma solidity ^0.8.4;

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
abstract contract ERC721A__OwnableUpgradeable is ERC721A__Initializable, ERC721AUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializingERC721A {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializingERC721A {
        _transferOwnership(_msgSenderERC721A());
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
        require(owner() == _msgSenderERC721A(), "Ownable: caller is not the owner");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized verification of proof of inclusion for a leaf in a Merkle tree.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/MerkleProofLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/MerkleProofLib.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/MerkleProof.sol)
library MerkleProofLib {
    function verify(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool isValid) {
        assembly {
            if proof.length {
                // Left shift by 5 is equivalent to multiplying by 0x20.
                let end := add(proof.offset, shl(5, proof.length))
                // Initialize `offset` to the offset of `proof` in the calldata.
                let offset := proof.offset
                // Iterate over proof elements to compute root hash.
                // prettier-ignore
                for {} 1 {} {
                    // Slot of `leaf` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, gt(leaf, calldataload(offset)))
                    // Store elements to hash contiguously in scratch space.
                    // Scratch space is 64 bytes (0x00 - 0x3f) and both elements are 32 bytes.
                    mstore(scratch, leaf)
                    mstore(xor(scratch, 0x20), calldataload(offset))
                    // Reuse `leaf` to store the hash to reduce stack operations.
                    leaf := keccak256(0x00, 0x40)
                    offset := add(offset, 0x20)
                    // prettier-ignore
                    if iszero(lt(offset, end)) { break }
                }
            }
            isValid := eq(leaf, root)
        }
    }

    function verifyMultiProof(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32[] calldata leafs,
        bool[] calldata flags
    ) internal pure returns (bool isValid) {
        // Rebuilds the root by consuming and producing values on a queue.
        // The queue starts with the `leafs` array, and goes into a `hashes` array.
        // After the process, the last element on the queue is verified
        // to be equal to the `root`.
        //
        // The `flags` array denotes whether the sibling
        // should be popped from the queue (`flag == true`), or
        // should be popped from the `proof` (`flag == false`).
        assembly {
            // If the number of flags is correct.
            // prettier-ignore
            for {} eq(add(leafs.length, proof.length), add(flags.length, 1)) {} {
                // Left shift by 5 is equivalent to multiplying by 0x20.
                // Compute the end calldata offset of `leafs`.
                let leafsEnd := add(leafs.offset, shl(5, leafs.length))
                // These are the calldata offsets.
                let leafsOffset := leafs.offset
                let flagsOffset := flags.offset
                let proofOffset := proof.offset

                // We can use the free memory space for the queue.
                // We don't need to allocate, since the queue is temporary.
                let hashesFront := mload(0x40)
                let hashesBack := hashesFront
                // This is the end of the memory for the queue.
                let end := add(hashesBack, shl(5, flags.length))

                // For the case where `proof.length + leafs.length == 1`.
                if iszero(flags.length) {
                    // If `proof.length` is zero, `leafs.length` is 1.
                    if iszero(proof.length) {
                        isValid := eq(calldataload(leafsOffset), root)
                        break
                    }
                    // If `leafs.length` is zero, `proof.length` is 1.
                    if iszero(leafs.length) {
                        isValid := eq(calldataload(proofOffset), root)
                        break
                    }
                }

                // prettier-ignore
                for {} 1 {} {
                    let a := 0
                    // Pops a value from the queue into `a`.
                    switch lt(leafsOffset, leafsEnd)
                    case 0 {
                        // Pop from `hashes` if there are no more leafs.
                        a := mload(hashesFront)
                        hashesFront := add(hashesFront, 0x20)
                    }
                    default {
                        // Otherwise, pop from `leafs`.
                        a := calldataload(leafsOffset)
                        leafsOffset := add(leafsOffset, 0x20)
                    }

                    let b := 0
                    // If the flag is false, load the next proof,
                    // else, pops from the queue.
                    switch calldataload(flagsOffset)
                    case 0 {
                        // Loads the next proof.
                        b := calldataload(proofOffset)
                        proofOffset := add(proofOffset, 0x20)
                    }
                    default {
                        // Pops a value from the queue into `a`.
                        switch lt(leafsOffset, leafsEnd)
                        case 0 {
                            // Pop from `hashes` if there are no more leafs.
                            b := mload(hashesFront)
                            hashesFront := add(hashesFront, 0x20)
                        }
                        default {
                            // Otherwise, pop from `leafs`.
                            b := calldataload(leafsOffset)
                            leafsOffset := add(leafsOffset, 0x20)
                        }
                    }
                    // Advance to the next flag offset.
                    flagsOffset := add(flagsOffset, 0x20)

                    // Slot of `a` in scratch space.
                    // If the condition is true: 0x20, otherwise: 0x00.
                    let scratch := shl(5, gt(a, b))
                    // Hash the scratch space and push the result onto the queue.
                    mstore(scratch, a)
                    mstore(xor(scratch, 0x20), b)
                    mstore(hashesBack, keccak256(0x00, 0x40))
                    hashesBack := add(hashesBack, 0x20)
                    // prettier-ignore
                    if iszero(lt(hashesBack, end)) { break }
                }
                // Checks if the last value in the queue is same as the root.
                isValid := eq(mload(sub(hashesBack, 0x20)), root)
                break
            }
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
library LibString {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CUSTOM ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error HexLengthInsufficient();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     DECIMAL OPERATIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function toString(uint256 value) internal pure returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits. Total: 5 * 0x20 = 0xa0.
            let m := add(mload(0x40), 0xa0)
            // Update the free memory pointer to allocate.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   HEXADECIMAL OPERATIONS                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function toHexString(uint256 value, uint256 length) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, `length * 2` bytes
            // for the digits, 0x02 bytes for the prefix, and 0x20 bytes for the length.
            // We add 0x20 to the total and round down to a multiple of 0x20.
            // (0x20 + 0x20 + 0x02 + 0x20) = 0x62.
            let m := add(start, and(add(shl(1, length), 0x62), not(0x1f)))
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let temp := value
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for {} 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                length := sub(length, 1)
                // prettier-ignore
                if iszero(length) { break }
            }

            if temp {
                // Store the function selector of `HexLengthInsufficient()`.
                mstore(0x00, 0x2194895a)
                // Revert with (offset, size).
                revert(0x1c, 0x04)
            }

            // Compute the string's length.
            let strLength := add(sub(end, str), 2)
            // Move the pointer and write the "0x" prefix.
            str := sub(str, 0x20)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, strLength)
        }
    }

    function toHexString(uint256 value) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the trailing zeros padding, 0x20 bytes for the length,
            // 0x02 bytes for the prefix, and 0x40 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x20 + 0x02 + 0x40) is 0xa0.
            let m := add(start, 0xa0)
            // Allocate the memory.
            mstore(0x40, m)
            // Assign the `str` to the end.
            str := sub(m, 0x20)
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end to calculate the length later.
            let end := str
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                // prettier-ignore
                if iszero(temp) { break }
            }

            // Compute the string's length.
            let strLength := add(sub(end, str), 2)
            // Move the pointer and write the "0x" prefix.
            str := sub(str, 0x20)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, strLength)
        }
    }

    function toHexString(address value) internal pure returns (string memory str) {
        assembly {
            let start := mload(0x40)
            // We need 0x20 bytes for the length, 0x02 bytes for the prefix,
            // and 0x28 bytes for the digits.
            // The next multiple of 0x20 above (0x20 + 0x02 + 0x28) is 0x60.
            str := add(start, 0x60)

            // Allocate the memory.
            mstore(0x40, str)
            // Store "0123456789abcdef" in scratch space.
            mstore(0x0f, 0x30313233343536373839616263646566)

            let length := 20
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 2)
                mstore8(add(str, 1), mload(and(temp, 15)))
                mstore8(str, mload(and(shr(4, temp), 15)))
                temp := shr(8, temp)
                length := sub(length, 1)
                // prettier-ignore
                if iszero(length) { break }
            }

            // Move the pointer and write the "0x" prefix.
            str := sub(str, 32)
            mstore(str, 0x3078)
            // Move the pointer and write the length.
            str := sub(str, 2)
            mstore(str, 42)
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   OTHER STRING OPERATIONS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function replace(
        string memory subject,
        string memory search,
        string memory replacement
    ) internal pure returns (string memory result) {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)

            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)

            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                let h := 0
                if iszero(lt(searchLength, 32)) {
                    h := keccak256(search, searchLength)
                }
                let m := shl(3, sub(32, and(searchLength, 31)))
                let s := mload(search)
                // prettier-ignore
                for {} 1 {} {
                    let t := mload(subject)
                    // Whether the first `searchLength % 32` bytes of 
                    // `subject` and `search` matches.
                    if iszero(shr(m, xor(t, s))) {
                        if h {
                            if iszero(eq(keccak256(subject, searchLength), h)) {
                                mstore(result, t)
                                result := add(result, 1)
                                subject := add(subject, 1)
                                // prettier-ignore
                                if iszero(lt(subject, subjectSearchEnd)) { break }
                                continue
                            }
                        }
                        // Copy the `replacement` one word at a time.
                        // prettier-ignore
                        for { let o := 0 } 1 {} {
                            mstore(add(result, o), mload(add(replacement, o)))
                            o := add(o, 0x20)
                            // prettier-ignore
                            if iszero(lt(o, replacementLength)) { break }
                        }
                        result := add(result, replacementLength)
                        subject := add(subject, searchLength)    
                        if iszero(searchLength) {
                            mstore(result, t)
                            result := add(result, 1)
                            subject := add(subject, 1)
                        }
                        // prettier-ignore
                        if iszero(lt(subject, subjectSearchEnd)) { break }
                        continue
                    }
                    mstore(result, t)
                    result := add(result, 1)
                    subject := add(subject, 1)
                    // prettier-ignore
                    if iszero(lt(subject, subjectSearchEnd)) { break }
                }
            }

            let resultRemainder := result
            result := add(mload(0x40), 0x20)
            let k := add(sub(resultRemainder, result), sub(subjectEnd, subject))
            // Copy the rest of the string one word at a time.
            // prettier-ignore
            for {} lt(subject, subjectEnd) {} {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            // Allocate memory for the length and the bytes,
            // rounded up to a multiple of 32.
            mstore(0x40, add(result, and(add(k, 0x40), not(0x1f))))
            result := sub(result, 0x20)
            mstore(result, k)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Gas optimized ECDSA wrapper.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/ECDSA.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/ECDSA.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/cryptography/ECDSA.sol)
library ECDSA {
    function recover(bytes32 hash, bytes calldata signature) internal view returns (address result) {
        assembly {
            if eq(signature.length, 65) {
                // Copy the free memory pointer so that we can restore it later.
                let m := mload(0x40)
                // Directly copy `r` and `s` from the calldata.
                calldatacopy(0x40, signature.offset, 0x40)

                // If `s` in lower half order, such that the signature is not malleable.
                // prettier-ignore
                if iszero(gt(mload(0x60), 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0)) {
                    mstore(0x00, hash)
                    // Compute `v` and store it in the scratch space.
                    mstore(0x20, byte(0, calldataload(add(signature.offset, 0x40))))
                    pop(
                        staticcall(
                            gas(), // Amount of gas left for the transaction.
                            0x01, // Address of `ecrecover`.
                            0x00, // Start of input.
                            0x80, // Size of input.
                            0x40, // Start of output.
                            0x20 // Size of output.
                        )
                    )
                    // Restore the zero slot.
                    mstore(0x60, 0)
                    // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                    result := mload(sub(0x60, returndatasize()))
                }
                // Restore the free memory pointer.
                mstore(0x40, m)
            }
        }
    }

    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal view returns (address result) {
        assembly {
            // Copy the free memory pointer so that we can restore it later.
            let m := mload(0x40)
            // prettier-ignore
            let s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

            // If `s` in lower half order, such that the signature is not malleable.
            // prettier-ignore
            if iszero(gt(s, 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0)) {
                mstore(0x00, hash)
                mstore(0x20, add(shr(255, vs), 27))
                mstore(0x40, r)
                mstore(0x60, s)
                pop(
                    staticcall(
                        gas(), // Amount of gas left for the transaction.
                        0x01, // Address of `ecrecover`.
                        0x00, // Start of input.
                        0x80, // Size of input.
                        0x40, // Start of output.
                        0x20 // Size of output.
                    )
                )
                // Restore the zero slot.
                mstore(0x60, 0)
                // `returndatasize()` will be `0x20` upon success, and `0x00` otherwise.
                result := mload(sub(0x60, returndatasize()))
            }
            // Restore the free memory pointer.
            mstore(0x40, m)
        }
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 result) {
        assembly {
            // Store into scratch space for keccak256.
            mstore(0x20, hash)
            mstore(0x00, "\x00\x00\x00\x00\x19Ethereum Signed Message:\n32")
            // 0x40 - 0x04 = 0x3c
            result := keccak256(0x04, 0x3c)
        }
    }

    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32 result) {
        assembly {
            // We need at most 128 bytes for Ethereum signed message header.
            // The max length of the ASCII reprenstation of a uint256 is 78 bytes.
            // The length of "\x19Ethereum Signed Message:\n" is 26 bytes (i.e. 0x1a).
            // The next multiple of 32 above 78 + 26 is 128 (i.e. 0x80).

            // Instead of allocating, we temporarily copy the 128 bytes before the
            // start of `s` data to some variables.
            let m3 := mload(sub(s, 0x60))
            let m2 := mload(sub(s, 0x40))
            let m1 := mload(sub(s, 0x20))
            // The length of `s` is in bytes.
            let sLength := mload(s)

            let ptr := add(s, 0x20)

            // `end` marks the end of the memory which we will compute the keccak256 of.
            let end := add(ptr, sLength)

            // Convert the length of the bytes to ASCII decimal representation
            // and store it into the memory.
            // prettier-ignore
            for { let temp := sLength } 1 {} {
                ptr := sub(ptr, 1)
                mstore8(ptr, add(48, mod(temp, 10)))
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            // Copy the header over to the memory.
            mstore(sub(ptr, 0x20), "\x00\x00\x00\x00\x00\x00\x19Ethereum Signed Message:\n")
            // Compute the keccak256 of the memory.
            result := keccak256(sub(ptr, 0x1a), sub(end, sub(ptr, 0x1a)))

            // Restore the previous memory.
            mstore(s, sLength)
            mstore(sub(s, 0x20), m1)
            mstore(sub(s, 0x40), m2)
            mstore(sub(s, 0x60), m3)
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Optimized and flexible operator filterer to abide to OpenSea's
/// mandatory on-chain royalty enforcement in order for new collections to
/// receive royalties.
/// For more information, see:
/// See: https://github.com/ProjectOpenSea/operator-filter-registry
abstract contract OperatorFilterer {
    /// @dev The default OpenSea operator blocklist subscription.
    address internal constant _DEFAULT_SUBSCRIPTION = 0x3cc6CddA760b79bAfa08dF41ECFA224f810dCeB6;

    /// @dev The OpenSea operator filter registry.
    address internal constant _OPERATOR_FILTER_REGISTRY = 0x000000000000AAeB6D7670E522A718067333cd4E;

    /// @dev Registers the current contract to OpenSea's operator filter,
    /// and subscribe to the default OpenSea operator blocklist.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering() internal virtual {
        _registerForOperatorFiltering(_DEFAULT_SUBSCRIPTION, true);
    }

    /// @dev Registers the current contract to OpenSea's operator filter.
    /// Note: Will not revert nor update existing settings for repeated registration.
    function _registerForOperatorFiltering(address subscriptionOrRegistrantToCopy, bool subscribe) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            let functionSelector := 0x7d3e3dbe // `registerAndSubscribe(address,address)`.

            // Clean the upper 96 bits of `subscriptionOrRegistrantToCopy` in case they are dirty.
            subscriptionOrRegistrantToCopy := shr(96, shl(96, subscriptionOrRegistrantToCopy))
            // prettier-ignore
            for {} iszero(subscribe) {} {
                if iszero(subscriptionOrRegistrantToCopy) {
                    functionSelector := 0x4420e486 // `register(address)`.
                    break
                }
                functionSelector := 0xa0af2903 // `registerAndCopyEntries(address,address)`.
                break
            }
            // Store the function selector.
            mstore(0x00, shl(224, functionSelector))
            // Store the `address(this)`.
            mstore(0x04, address())
            // Store the `subscriptionOrRegistrantToCopy`.
            mstore(0x24, subscriptionOrRegistrantToCopy)
            // Register into the registry.
            pop(call(gas(), _OPERATOR_FILTER_REGISTRY, 0, 0x00, 0x44, 0x00, 0x00))
            // Restore the part of the free memory pointer that was overwritten,
            // which is guaranteed to be zero, because of Solidity's memory size limits.
            mstore(0x24, 0)
        }
    }

    /// @dev Modifier to guard a function and revert if `from` is a blocked operator.
    /// Can be turned on / off via `enabled`.
    /// For gas efficiency, you can use tight variable packing to efficiently read / write
    /// the boolean value for `enabled`.
    modifier onlyAllowedOperator(address from, bool enabled) virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // This code prioritizes runtime gas costs on a chain with the registry.
            // As such, we will not use `extcodesize`, but rather abuse the behavior
            // of `staticcall` returning 1 when called on an empty / missing contract,
            // to avoid reverting when a chain does not have the registry.

            if enabled {
                // Check if `from` is not equal to `msg.sender`,
                // discarding the upper 96 bits of `from` in case they are dirty.
                if iszero(eq(shr(96, shl(96, from)), caller())) {
                    // Store the function selector of `isOperatorAllowed(address,address)`,
                    // shifted left by 6 bytes, which is enough for 8tb of memory.
                    // We waste 6-3 = 3 bytes to save on 6 runtime gas (PUSH1 0x224 SHL).
                    mstore(0x00, 0xc6171134001122334455)
                    // Store the `address(this)`.
                    mstore(0x1a, address())
                    // Store the `msg.sender`.
                    mstore(0x3a, caller())

                    // `isOperatorAllowed` always returns true if it does not revert.
                    if iszero(staticcall(gas(), _OPERATOR_FILTER_REGISTRY, 0x16, 0x44, 0x00, 0x00)) {
                        // Bubble up the revert if the staticcall reverts.
                        returndatacopy(0x00, 0x00, returndatasize())
                        revert(0x00, returndatasize())
                    }

                    // We'll skip checking if `from` is inside the blacklist.
                    // Even though that can block transferring out of wrapper contracts,
                    // we don't want tokens to be stuck.

                    // Restore the part of the free memory pointer that was overwritten,
                    // which is guaranteed to be zero, if less than 8tb of memory is used.
                    mstore(0x3a, 0)
                }
            }
        }
        _;
    }

    /// @dev Modifier to guard a function from approving a blocked operator.
    /// Can be turned on / off via `enabled`.
    /// For efficiency, you can use tight variable packing to efficiently read / write
    /// the boolean value for `enabled`.
    modifier onlyAllowedOperatorApproval(address operator, bool enabled) virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // For more information on the optimization techniques used,
            // see the comments in `onlyAllowedOperator`.

            if enabled {
                // Store the function selector of `isOperatorAllowed(address,address)`,
                mstore(0x00, 0xc6171134001122334455)
                // Store the `address(this)`.
                mstore(0x1a, address())
                // Store the `operator`, discarding the upper 96 bits in case they are dirty.
                mstore(0x3a, shr(96, shl(96, operator)))

                // `isOperatorAllowed` always returns true if it does not revert.
                if iszero(staticcall(gas(), _OPERATOR_FILTER_REGISTRY, 0x16, 0x44, 0x00, 0x00)) {
                    // Bubble up the revert if the staticcall reverts.
                    returndatacopy(0x00, 0x00, returndatasize())
                    revert(0x00, returndatasize())
                }

                // Restore the part of the free memory pointer that was overwritten.
                mstore(0x3a, 0)
            }
        }
        _;
    }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721AUpgradeable {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * The caller cannot approve to their own address.
     */
    error ApproveToCaller();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
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
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
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
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
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
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
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
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
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
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library ERC721AStorage {
    // Reference type for token approval.
    struct TokenApprovalRef {
        address value;
    }

    struct Layout {
        // =============================================================
        //                            STORAGE
        // =============================================================

        // The next token ID to be minted.
        uint256 _currentIndex;
        // The number of tokens burned.
        uint256 _burnCounter;
        // Token name
        string _name;
        // Token symbol
        string _symbol;
        // Mapping from token ID to ownership details
        // An empty struct value does not necessarily mean the token is unowned.
        // See {_packedOwnershipOf} implementation for details.
        //
        // Bits Layout:
        // - [0..159]   `addr`
        // - [160..223] `startTimestamp`
        // - [224]      `burned`
        // - [225]      `nextInitialized`
        // - [232..255] `extraData`
        mapping(uint256 => uint256) _packedOwnerships;
        // Mapping owner address to address data.
        //
        // Bits Layout:
        // - [0..63]    `balance`
        // - [64..127]  `numberMinted`
        // - [128..191] `numberBurned`
        // - [192..255] `aux`
        mapping(address => uint256) _packedAddressData;
        // Mapping from token ID to approved address.
        mapping(uint256 => ERC721AStorage.TokenApprovalRef) _tokenApprovals;
        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) _operatorApprovals;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256('ERC721A.contracts.storage.ERC721A');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

/**
 * @dev This is a base storage for the  initialization function for upgradeable diamond facet contracts
 **/

library ERC721A__InitializableStorage {
    struct Layout {
        /*
         * Indicates that the contract has been initialized.
         */
        bool _initialized;
        /*
         * Indicates that the contract is in the process of being initialized.
         */
        bool _initializing;
    }

    bytes32 internal constant STORAGE_SLOT = keccak256("ERC721A.contracts.storage.initializable.facet");

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}