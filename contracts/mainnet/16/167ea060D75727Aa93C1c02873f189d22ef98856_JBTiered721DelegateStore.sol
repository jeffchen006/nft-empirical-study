// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '@paulrberg/contracts/math/PRBMath.sol';
import './interfaces/IJBTiered721DelegateStore.sol';
import './libraries/JBBitmap.sol';
import './structs/JBBitmapWord.sol';
import './structs/JBStored721Tier.sol';

/**
  @title
  JBTiered721DelegateStore

  @notice
  The contract that stores and manages the NFT's data.

  @dev
  Adheres to -
  IJBTiered721DelegateStore: General interface for the methods in this contract that interact with the blockchain's state according to the protocol's rules.
*/
contract JBTiered721DelegateStore is IJBTiered721DelegateStore {
  using JBBitmap for mapping(uint256 => uint256);
  using JBBitmap for JBBitmapWord;

  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//

  error CANT_MINT_MANUALLY();
  error INSUFFICIENT_AMOUNT();
  error INSUFFICIENT_RESERVES();
  error INVALID_CATEGORY_SORT_ORDER();
  error INVALID_CATEGORY();
  error INVALID_LOCKED_UNTIL();
  error INVALID_ROYALTY_RATE();
  error INVALID_QUANTITY();
  error INVALID_TIER();
  error MAX_TIERS_EXCEEDED();
  error NO_QUANTITY();
  error OUT();
  error RESERVED_RATE_NOT_ALLOWED();
  error MANUAL_MINTING_NOT_ALLOWED();
  error PRICING_RESOLVER_CHANGES_LOCKED();
  error TIER_LOCKED();
  error TIER_REMOVED();
  error VOTING_UNITS_NOT_ALLOWED();

  //*********************************************************************//
  // ------------------------- public constants ------------------------ //
  //*********************************************************************//
  uint256 public constant override MAX_ROYALTY_RATE = 200;

  //*********************************************************************//
  // -------------------- private constant properties ------------------ //
  //*********************************************************************//

  uint256 private constant _ONE_BILLION = 1_000_000_000;

  /** 
    @notice 
    The timestamp to add on to tier lock timestamps. 

    @dev
    Useful so the stored lock timestamp per-tier can fit in a smaller storage slot.
    
  */
  uint256 private constant _BASE_LOCK_TIMESTAMP = 1672531200;

  //*********************************************************************//
  // --------------------- internal stored properties ------------------ //
  //*********************************************************************//

  /** 
    @notice
    The tier ID that should come after the given tier ID when sorting by contribution floor.

    @dev
    If empty, assume the next tier ID should come after. 

    _nft The NFT contract to get ordered tier ID from.
    _tierId The tier ID to get a tier after relative to.
  */
  mapping(address => mapping(uint256 => uint256)) internal _tierIdAfter;

  /**
    @notice
    An optional beneficiary for the reserved token of a given tier.

    _nft The NFT contract to which the reserved token beneficiary belongs.
    _tierId the ID of the tier.
  */
  mapping(address => mapping(uint256 => address)) internal _reservedTokenBeneficiaryOf;

  /**
    @notice
    An optional beneficiary for the royalty of a given tier.

    _nft The NFT contract to which the royalty beneficiary belongs.
    _tierId the ID of the tier.
  */
  mapping(address => mapping(uint256 => address)) internal _royaltyBeneficiaryOf;

  /** 
    @notice
    The stored reward tier. 

    _nft The NFT contract to which the tiers belong.
    _tierId The incremental ID of the tier, starting with 1.
  */
  mapping(address => mapping(uint256 => JBStored721Tier)) internal _storedTierOf;

  /**
    @notice
    Flags that influence the behavior of each NFT.

    _nft The NFT for which the flags apply.
  */
  mapping(address => JBTiered721Flags) internal _flagsOf;

  /** 
    @notice
    For each tier ID, a bitmap containing flags indicating if the tier has been removed. 

    _nft The NFT contract to which the tier belong.
    _depth The bitmap row.
    _word The row content bitmap.
  */
  mapping(address => mapping(uint256 => uint256)) internal _isTierRemovedBitmapWord;

  /** 
    @notice
    For each NFT, the tier ID that comes last when sorting. 

    @dev
    If not set, it is assumed the `maxTierIdOf` is the last sorted.

    _nft The NFT contract to which the tier belongs.
  */
  mapping(address => uint256) internal _trackedLastSortTierIdOf;

  /** 
    @notice
    The ID of the first tier in each category.

    _nft The NFT contract to get the tier ID of.
    _category The category to get the first tier ID of.
  */
  mapping(address => mapping(uint256 => uint256)) internal _startingTierIdOfCategory;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /** 
    @notice
    The biggest tier ID used. 

    @dev
    This may not include the last tier ID if it has been removed.

    _nft The NFT contract to get the number of tiers.
  */
  mapping(address => uint256) public override maxTierIdOf;

  /** 
    @notice
    Each account's balance within a specific tier.

    _nft The NFT contract to which the tier balances belong.
    _owner The address to get a balance for. 
    _tierId The ID of the tier to get a balance within.
  */
  mapping(address => mapping(address => mapping(uint256 => uint256))) public override tierBalanceOf;

  /**
    @notice 
    The number of reserved tokens that have been minted for each tier. 

    _nft The NFT contract to which the reserve data belong.
    _tierId The ID of the tier to get a minted reserved token count for.
   */
  mapping(address => mapping(uint256 => uint256)) public override numberOfReservesMintedFor;

  /**
    @notice 
    The number of tokens that have been burned for each tier. 

    _nft The NFT contract to which the burned data belong.
    _tierId The ID of the tier to get a burned token count for.
   */
  mapping(address => mapping(uint256 => uint256)) public override numberOfBurnedFor;

  /** 
    @notice
    The beneficiary of reserved tokens when the tier doesn't specify a beneficiary.

    _nft The NFT contract to which the reserved token beneficiary applies.
  */
  mapping(address => address) public override defaultReservedTokenBeneficiaryOf;

  /** 
    @notice
    The beneficiary of royalties when the tier doesn't specify a beneficiary.

    _nft The NFT contract to which the royalty beneficiary applies.
  */
  mapping(address => address) public override defaultRoyaltyBeneficiaryOf;

  /**
    @notice
    The first owner of each token ID, stored on first transfer out.

    _nft The NFT contract to which the token belongs.
    _tokenId The ID of the token to get the stored first owner of.
  */
  mapping(address => mapping(uint256 => address)) public override firstOwnerOf;

  /**
    @notice
    The common base for the tokenUri's

    _nft The NFT for which the base URI applies.
  */
  mapping(address => string) public override baseUriOf;

  /**
    @notice
    Custom token URI resolver, supersedes base URI.

    _nft The NFT for which the token URI resolver applies.
  */
  mapping(address => IJBTokenUriResolver) public override tokenUriResolverOf;

  /**
    @notice
    Contract metadata uri.

    _nft The NFT for which the contract URI resolver applies.
  */
  mapping(address => string) public override contractUriOf;

  /**
    @notice
    When using this contract to manage token uri's, those are stored as 32bytes, based on IPFS hashes stripped down.

    _nft The NFT contract to which the encoded upfs uri belongs.
    _tierId the ID of the tier
  */
  mapping(address => mapping(uint256 => bytes32)) public override encodedIPFSUriOf;

  //*********************************************************************//
  // ------------------------- external views -------------------------- //
  //*********************************************************************//

  /** 
    @notice
    Gets an array of all the active tiers. 

    @param _nft The NFT contract to get tiers for.
    @param _category The category of the tiers to get. Send 0 for any category.
    @param _startingId The starting tier ID of the array of tiers sorted by contribution floor. Send 0 to start at the beginning.
    @param _size The number of tiers to include.

    @return _tiers All the tiers.
  */
  function tiers(
    address _nft,
    uint256 _category,
    uint256 _startingId,
    uint256 _size
  ) external view override returns (JB721Tier[] memory _tiers) {
    // Keep a reference to the last tier ID.
    uint256 _lastTierId = _lastSortedTierIdOf(_nft);

    // Initialize an array with the appropriate length.
    _tiers = new JB721Tier[](_size);

    // Count the number of included tiers.
    uint256 _numberOfIncludedTiers;

    // Get a reference to the tier ID being iterated on, starting with the first tier ID if not specified.
    uint256 _currentSortedTierId = _startingId != 0
      ? _startingId
      : _firstSortedTierIdOf(_nft, _category);

    // Keep a reference to the tier being iterated on.
    JBStored721Tier memory _storedTier;

    // Initialize a BitmapWord for isRemoved
    JBBitmapWord memory _bitmapWord = _isTierRemovedBitmapWord[_nft].readId(_currentSortedTierId);

    // Make the sorted array.
    while (_currentSortedTierId != 0 && _numberOfIncludedTiers < _size) {
      // Reset the bitmap if the current tier ID is outside the currently stored word.
      if (_bitmapWord.refreshBitmapNeeded(_currentSortedTierId))
        _bitmapWord = _isTierRemovedBitmapWord[_nft].readId(_currentSortedTierId);

      if (!_bitmapWord.isTierIdRemoved(_currentSortedTierId)) {
        _storedTier = _storedTierOf[_nft][_currentSortedTierId];

        // Get a reference to the reserved token beneficiary.
        address _reservedTokenBeneficiary = reservedTokenBeneficiaryOf(_nft, _currentSortedTierId);

        // If a category is specified and matches, add the the returned values.
        if (_category == 0 || _storedTier.category == _category)
          // Add the tier to the array being returned.
          _tiers[_numberOfIncludedTiers++] = JB721Tier({
            id: _currentSortedTierId,
            contributionFloor: _storedTier.contributionFloor,
            lockedUntil: _storedTier.lockedUntil == 0
              ? 0
              : _BASE_LOCK_TIMESTAMP + _storedTier.lockedUntil,
            remainingQuantity: _storedTier.remainingQuantity,
            initialQuantity: _storedTier.initialQuantity,
            votingUnits: _storedTier.votingUnits,
            // No reserved rate if no beneficiary set.
            reservedRate: _reservedTokenBeneficiary == address(0) ? 0 : _storedTier.reservedRate,
            reservedTokenBeneficiary: _reservedTokenBeneficiary,
            royaltyRate: _storedTier.royaltyRate,
            royaltyBeneficiary: _resolvedRoyaltyBeneficiaryOf(_nft, _currentSortedTierId),
            encodedIPFSUri: encodedIPFSUriOf[_nft][_currentSortedTierId],
            category: _storedTier.category,
            allowManualMint: _storedTier.allowManualMint,
            transfersPausable: _storedTier.transfersPausable
          });
          // If the tier's category is greater than the category sought after, break.
        else if (_category > 0 && _storedTier.category > _category) _currentSortedTierId = 0;
      }

      // Set the next sorted tier ID.
      _currentSortedTierId = _nextSortedTierIdOf(_nft, _currentSortedTierId, _lastTierId);
    }

    // Resize the array if there are removed tiers
    if (_numberOfIncludedTiers != _size)
      assembly ('memory-safe') {
        mstore(_tiers, _numberOfIncludedTiers)
      }
  }

  /** 
    @notice
    Return the tier for the specified ID. 

    @param _nft The NFT to get a tier within.
    @param _id The ID of the tier to get. 

    @return The tier.
  */
  function tier(address _nft, uint256 _id) external view override returns (JB721Tier memory) {
    // Get the stored tier.
    JBStored721Tier memory _storedTier = _storedTierOf[_nft][_id];

    // Get a reference to the reserved token beneficiary.
    address _reservedTokenBeneficiary = reservedTokenBeneficiaryOf(_nft, _id);

    return
      JB721Tier({
        id: _id,
        contributionFloor: _storedTier.contributionFloor,
        lockedUntil: _storedTier.lockedUntil == 0
          ? 0
          : _BASE_LOCK_TIMESTAMP + _storedTier.lockedUntil,
        remainingQuantity: _storedTier.remainingQuantity,
        initialQuantity: _storedTier.initialQuantity,
        votingUnits: _storedTier.votingUnits,
        // No reserved rate if no beneficiary set.
        reservedRate: _reservedTokenBeneficiary == address(0) ? 0 : _storedTier.reservedRate,
        reservedTokenBeneficiary: _reservedTokenBeneficiary,
        royaltyRate: _storedTier.royaltyRate,
        royaltyBeneficiary: _resolvedRoyaltyBeneficiaryOf(_nft, _id),
        encodedIPFSUri: encodedIPFSUriOf[_nft][_id],
        category: _storedTier.category,
        allowManualMint: _storedTier.allowManualMint,
        transfersPausable: _storedTier.transfersPausable
      });
  }

  /**  
    @notice
    Return the tier for the specified token ID. 

    @param _nft The NFT to get a tier within.
    @param _tokenId The ID of token to return the tier of. 

    @return The tier.
  */
  function tierOfTokenId(
    address _nft,
    uint256 _tokenId
  ) external view override returns (JB721Tier memory) {
    // Get a reference to the tier's ID.
    uint256 _tierId = tierIdOfToken(_tokenId);

    // Get the stored tier.
    JBStored721Tier memory _storedTier = _storedTierOf[_nft][_tierId];

    // Get a reference to the reserved token beneficiary.
    address _reservedTokenBeneficiary = reservedTokenBeneficiaryOf(_nft, _tierId);

    return
      JB721Tier({
        id: _tierId,
        contributionFloor: _storedTier.contributionFloor,
        lockedUntil: _storedTier.lockedUntil == 0
          ? 0
          : _BASE_LOCK_TIMESTAMP + _storedTier.lockedUntil,
        remainingQuantity: _storedTier.remainingQuantity,
        initialQuantity: _storedTier.initialQuantity,
        votingUnits: _storedTier.votingUnits,
        // No reserved rate if beneficiary is not set.
        reservedRate: _reservedTokenBeneficiary == address(0) ? 0 : _storedTier.reservedRate,
        reservedTokenBeneficiary: _reservedTokenBeneficiary,
        royaltyRate: _storedTier.royaltyRate,
        royaltyBeneficiary: _resolvedRoyaltyBeneficiaryOf(_nft, _tierId),
        encodedIPFSUri: encodedIPFSUriOf[_nft][_tierId],
        category: _storedTier.category,
        allowManualMint: _storedTier.allowManualMint,
        transfersPausable: _storedTier.transfersPausable
      });
  }

  /** 
    @notice 
    The total supply of issued NFTs from all tiers.

    @param _nft The NFT to get a total supply of.

    @return supply The total number of NFTs between all tiers.
  */
  function totalSupply(address _nft) external view override returns (uint256 supply) {
    // Keep a reference to the tier being iterated on.
    JBStored721Tier storage _storedTier;

    // Keep a reference to the greatest tier ID.
    uint256 _maxTierId = maxTierIdOf[_nft];

    for (uint256 _i = _maxTierId; _i != 0; ) {
      // Set the tier being iterated on.
      _storedTier = _storedTierOf[_nft][_i];

      // Increment the total supply with the amount used already.
      supply += _storedTier.initialQuantity - _storedTier.remainingQuantity;

      unchecked {
        --_i;
      }
    }
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _nft The NFT to get a number of reserved tokens outstanding.
    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.

    @return The outstanding number of reserved tokens within the tier.
  */
  function numberOfReservedTokensOutstandingFor(
    address _nft,
    uint256 _tierId
  ) external view override returns (uint256) {
    return _numberOfReservedTokensOutstandingFor(_nft, _tierId, _storedTierOf[_nft][_tierId]);
  }

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _nft The NFT to get voting units within.
    @param _account The account to get voting units for.

    @return units The voting units for the account.
  */
  function votingUnitsOf(
    address _nft,
    address _account
  ) external view virtual override returns (uint256 units) {
    // Keep a reference to the greatest tier ID.
    uint256 _maxTierId = maxTierIdOf[_nft];

    // Keep a reference to the balance being iterated on.
    uint256 _balance;

    // Loop through all tiers.
    for (uint256 _i = _maxTierId; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      _balance = tierBalanceOf[_nft][_account][_i];

      if (_balance != 0)
        // Add the tier's voting units.
        units += _balance * _storedTierOf[_nft][_i].votingUnits;

      unchecked {
        --_i;
      }
    }
  }

  /**
    @notice
    The voting units for an account from its NFTs across all tiers. NFTs have a tier-specific preset number of voting units. 

    @param _nft The NFT to get voting units within.
    @param _account The account to get voting units for.
    @param _tierId The ID of the tier to get voting units for.

    @return The voting units for the account.
  */
  function tierVotingUnitsOf(
    address _nft,
    address _account,
    uint256 _tierId
  ) external view virtual override returns (uint256) {
    // Get a reference to the account's balance in this tier.
    uint256 _balance = tierBalanceOf[_nft][_account][_tierId];

    if (_balance == 0) return 0;

    // Add the tier's voting units.
    return _balance * _storedTierOf[_nft][_tierId].votingUnits;
  }

  /**
    @notice
    Resolves the encoded tier IPFS URI of the tier for the given token.

    @param _nft The NFT contract to which the encoded IPFS URI belongs.
    @param _tokenId the ID of the token.

    @return The encoded IPFS URI.
  */
  function encodedTierIPFSUriOf(
    address _nft,
    uint256 _tokenId
  ) external view override returns (bytes32) {
    return encodedIPFSUriOf[_nft][tierIdOfToken(_tokenId)];
  }

  /** 
    @notice
    Flags that influence the behavior of each NFT.

    @param _nft The NFT for which the flags apply.

    @return The flags.
  */
  function flagsOf(address _nft) external view override returns (JBTiered721Flags memory) {
    return _flagsOf[_nft];
  }

  /** 
    @notice
    Tier removed from the current tiering

    @param _nft The NFT for which the removed tier is being queried.
    @param _tierId The tier ID to check if removed.

    @return True if the tier has been removed
  */
  function isTierRemoved(address _nft, uint256 _tierId) external view override returns (bool) {
    JBBitmapWord memory _bitmapWord = _isTierRemovedBitmapWord[_nft].readId(_tierId);

    return _bitmapWord.isTierIdRemoved(_tierId);
  }

  /**
    @notice 
    Royalty info conforming to EIP-2981.

    @param _nft The NFT for which the royalty applies.
    @param _tokenId The ID of the token that the royalty is for.
    @param _salePrice The price being paid for the token.

    @return receiver The address of the royalty's receiver.
    @return royaltyAmount The amount of the royalty.
  */
  function royaltyInfo(
    address _nft,
    uint256 _tokenId,
    uint256 _salePrice
  ) external view override returns (address receiver, uint256 royaltyAmount) {
    // Get a reference to the tier's ID.
    uint256 _tierId = tierIdOfToken(_tokenId);

    // Get the stored royalty beneficiary.
    address _royaltyBeneficiaryOfTier = _resolvedRoyaltyBeneficiaryOf(_nft, _tierId);

    // If no beneificary, return no royalty.
    if (_royaltyBeneficiaryOfTier == address(0)) return (address(0), 0);

    // Get the stored tier.
    JBStored721Tier memory _storedTier = _storedTierOf[_nft][_tierId];

    // Return the royalty portion of the sale.
    return (
      _royaltyBeneficiaryOfTier,
      PRBMath.mulDiv(_salePrice, _storedTier.royaltyRate, MAX_ROYALTY_RATE)
    );
  }

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /** 
    @notice 
    The total number of tokens owned by the given owner. 

    @param _nft The NFT to get a balance from.
    @param _owner The address to check the balance of.

    @return balance The number of tokens owners by the owner across all tiers.
  */
  function balanceOf(address _nft, address _owner) public view override returns (uint256 balance) {
    // Keep a reference to the greatest tier ID.
    uint256 _maxTierId = maxTierIdOf[_nft];

    // Loop through all tiers.
    for (uint256 _i = _maxTierId; _i != 0; ) {
      // Get a reference to the account's balance in this tier.
      balance += tierBalanceOf[_nft][_owner][_i];

      unchecked {
        --_i;
      }
    }
  }

  /**
    @notice
    The cumulative weight the given token IDs have in redemptions compared to the `totalRedemptionWeight`.

    @param _nft The NFT for which the redemption weight is being calculated.
    @param _tokenIds The IDs of the tokens to get the cumulative redemption weight of.

    @return weight The weight.
  */
  function redemptionWeightOf(
    address _nft,
    uint256[] calldata _tokenIds
  ) public view override returns (uint256 weight) {
    // Get a reference to the total number of tokens.
    uint256 _numberOfTokenIds = _tokenIds.length;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _numberOfTokenIds; ) {
      weight += _storedTierOf[_nft][tierIdOfToken(_tokenIds[_i])].contributionFloor;

      unchecked {
        ++_i;
      }
    }
  }

  /**
    @notice
    The cumulative weight that all token IDs have in redemptions.

    @param _nft The NFT for which the redemption weight is being calculated.

    @return weight The total weight.
  */
  function totalRedemptionWeight(address _nft) public view override returns (uint256 weight) {
    // Keep a reference to the greatest tier ID.
    uint256 _maxTierId = maxTierIdOf[_nft];

    // Keep a reference to the tier being iterated on.
    JBStored721Tier memory _storedTier;

    // Add each token's tier's contribution floor to the weight.
    for (uint256 _i; _i < _maxTierId; ) {
      // Keep a reference to the stored tier.
      unchecked {
        _storedTier = _storedTierOf[_nft][_i + 1];
      }

      // Add the tier's contribution floor multiplied by the quantity minted.
      weight +=
        _storedTier.contributionFloor *
        ((_storedTier.initialQuantity - _storedTier.remainingQuantity) +
          _numberOfReservedTokensOutstandingFor(_nft, _i + 1, _storedTier));

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    The tier number of the provided token ID. 

    @dev
    Tier's are 1 indexed from the `tiers` array, meaning the 0th element of the array is tier 1.

    @param _tokenId The ID of the token to get the tier number of. 

    @return The tier number of the specified token ID.
  */
  function tierIdOfToken(uint256 _tokenId) public pure override returns (uint256) {
    return _tokenId / _ONE_BILLION;
  }

  /** 
    @notice
    The reserved token beneficiary for each tier. 

    @param _nft The NFT to get the reserved token beneficiary within.
    @param _tierId The ID of the tier to get a reserved token beneficiary of.

    @return The reserved token beneficiary.
  */
  function reservedTokenBeneficiaryOf(
    address _nft,
    uint256 _tierId
  ) public view override returns (address) {
    // Get the stored reserved token beneficiary.
    address _storedReservedTokenBeneficiaryOfTier = _reservedTokenBeneficiaryOf[_nft][_tierId];

    // If the tier has a beneficiary return it.
    if (_storedReservedTokenBeneficiaryOfTier != address(0))
      return _storedReservedTokenBeneficiaryOfTier;

    // Return the default.
    return defaultReservedTokenBeneficiaryOf[_nft];
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /** 
    @notice
    Adds tiers. 

    @param _tiersToAdd The tiers to add.

    @return tierIds The IDs of the tiers added.
  */
  function recordAddTiers(
    JB721TierParams[] calldata _tiersToAdd
  ) external override returns (uint256[] memory tierIds) {
    // Get a reference to the number of new tiers.
    uint256 _numberOfNewTiers = _tiersToAdd.length;

    // Keep a reference to the greatest tier ID.
    uint256 _currentMaxTierIdOf = maxTierIdOf[msg.sender];

    // Make sure the max number of tiers hasn't been reached.
    if (_currentMaxTierIdOf + _numberOfNewTiers > type(uint16).max) revert MAX_TIERS_EXCEEDED();

    // Keep a reference to the current last sorted tier ID.
    uint256 _currentLastSortedTierId = _lastSortedTierIdOf(msg.sender);

    // Initialize an array with the appropriate length.
    tierIds = new uint256[](_numberOfNewTiers);

    // Keep a reference to the starting sort ID for sorting new tiers if needed.
    // There's no need for sorting if there are currently no tiers.
    uint256 _startSortedTierId = _currentMaxTierIdOf == 0 ? 0 : _firstSortedTierIdOf(msg.sender, 0);

    // Keep track of the previous tier ID.
    uint256 _previous;

    // Keep a reference to the tier being iterated on.
    JB721TierParams memory _tierToAdd;

    // Keep a reference to the flags.
    JBTiered721Flags memory _flags = _flagsOf[msg.sender];

    for (uint256 _i; _i < _numberOfNewTiers; ) {
      // Set the tier being iterated on.
      _tierToAdd = _tiersToAdd[_i];

      // Make sure the max is enforced.
      if (_tierToAdd.initialQuantity > _ONE_BILLION - 1) revert INVALID_QUANTITY();
       
      // Keep a reference to the previous tier.
      JB721TierParams memory _previousTier;

      // Category can't be 0.
      if (_tierToAdd.category == 0) revert INVALID_CATEGORY();

      // Make sure the tier's category is greater than or equal to the previous tier's category.
      if (_i != 0) {
        // Set the reference to the previous tier.
        _previousTier = _tiersToAdd[_i - 1];

        // Check category sort order.
        if (_tierToAdd.category < _previousTier.category) revert INVALID_CATEGORY_SORT_ORDER();
      }

      // Make sure there are no voting units set if they're not allowed.
      if (_flags.lockVotingUnitChanges && _tierToAdd.votingUnits != 0)
        revert VOTING_UNITS_NOT_ALLOWED();

      // Make sure a reserved rate isn't set if changes should be locked, or if manual minting is allowed.
      if (
        (_flags.lockReservedTokenChanges || _tierToAdd.allowManualMint) &&
        _tierToAdd.reservedRate != 0
      ) revert RESERVED_RATE_NOT_ALLOWED();

      // Make sure manual minting is not set if not allowed.
      if (_flags.lockManualMintingChanges && _tierToAdd.allowManualMint)
        revert MANUAL_MINTING_NOT_ALLOWED();

      // Make sure there is some quantity.
      if (_tierToAdd.initialQuantity == 0) revert NO_QUANTITY();

      // Make sure the locked until is in the future if provided.
      if (_tierToAdd.lockedUntil != 0 && _tierToAdd.lockedUntil < block.timestamp)
        revert INVALID_LOCKED_UNTIL();

      // Make sure the royalty rate is within the bounds.
      if (_tierToAdd.royaltyRate > MAX_ROYALTY_RATE) revert INVALID_ROYALTY_RATE();

      // Get a reference to the tier ID.
      uint256 _tierId = _currentMaxTierIdOf + _i + 1;

      // Add the tier with the iterative ID.
      _storedTierOf[msg.sender][_tierId] = JBStored721Tier({
        contributionFloor: uint80(_tierToAdd.contributionFloor),
        lockedUntil: _tierToAdd.lockedUntil == 0
          ? uint40(0)
          : uint40(_tierToAdd.lockedUntil - _BASE_LOCK_TIMESTAMP),
        remainingQuantity: uint40(_tierToAdd.initialQuantity),
        initialQuantity: uint40(_tierToAdd.initialQuantity),
        votingUnits: uint16(_tierToAdd.votingUnits),
        reservedRate: uint16(_tierToAdd.reservedRate),
        royaltyRate: uint8(_tierToAdd.royaltyRate),
        category: uint8(_tierToAdd.category),
        allowManualMint: _tierToAdd.allowManualMint,
        transfersPausable: _tierToAdd.transfersPausable
      });

      // If this is the first tier in a new category, store its ID as such.
      if (_previousTier.category != _tierToAdd.category) 
        _startingTierIdOfCategory[msg.sender][_tierToAdd.category] = _tierId;

      // Set the reserved token beneficiary if needed.
      if (_tierToAdd.reservedTokenBeneficiary != address(0))
        if (_tierToAdd.shouldUseReservedTokenBeneficiaryAsDefault) {
          if (defaultReservedTokenBeneficiaryOf[msg.sender] != _tierToAdd.reservedTokenBeneficiary)
            defaultReservedTokenBeneficiaryOf[msg.sender] = _tierToAdd.reservedTokenBeneficiary;
        } else
          _reservedTokenBeneficiaryOf[msg.sender][_tierId] = _tierToAdd.reservedTokenBeneficiary;

      // Set the royalty beneficiary if needed.
      if (_tierToAdd.royaltyBeneficiary != address(0))
        if (_tierToAdd.shouldUseRoyaltyBeneficiaryAsDefault) {
          if (defaultRoyaltyBeneficiaryOf[msg.sender] != _tierToAdd.royaltyBeneficiary)
            defaultRoyaltyBeneficiaryOf[msg.sender] = _tierToAdd.royaltyBeneficiary;
        } else _royaltyBeneficiaryOf[msg.sender][_tierId] = _tierToAdd.royaltyBeneficiary;

      // Set the encodedIPFSUri if needed.
      if (_tierToAdd.encodedIPFSUri != bytes32(0))
        encodedIPFSUriOf[msg.sender][_tierId] = _tierToAdd.encodedIPFSUri;

      if (_startSortedTierId != 0) {
        // Keep track of the sorted tier ID.
        uint256 _currentSortedTierId = _startSortedTierId;

        // Initialize a BitmapWord for isRemoved
        JBBitmapWord memory _bitmapWord = _isTierRemovedBitmapWord[msg.sender].readId(
          _currentSortedTierId
        );

        // Keep a reference to the tier ID to iterate on next.
        uint256 _next;

        while (_currentSortedTierId != 0) {
          // Reset the bitmap word if the current tier ID is outside the currently stored word.
          if (_bitmapWord.refreshBitmapNeeded(_currentSortedTierId))
            _bitmapWord = _isTierRemovedBitmapWord[msg.sender].readId(_currentSortedTierId);

          // Set the next tier ID.
          _next = _nextSortedTierIdOf(msg.sender, _currentSortedTierId, _currentLastSortedTierId);

          // If the category is less than or equal to the tier being iterated on and the tier being iterated isn't among those being added, store the order.
          if (_tierToAdd.category <= _storedTierOf[msg.sender][_currentSortedTierId].category && _currentSortedTierId <= _currentMaxTierIdOf) {
            // If the tier ID being iterated on isn't the next tier ID, set the after.
            if (_currentSortedTierId != _tierId + 1)
              _tierIdAfter[msg.sender][_tierId] = _currentSortedTierId;

            // If this is the first tier being added, track the current last sorted tier ID if it's not already tracked.
            if (
              _trackedLastSortTierIdOf[msg.sender] != _currentLastSortedTierId
            ) _trackedLastSortTierIdOf[msg.sender] = _currentLastSortedTierId;

            // If the previous after tier ID was set to something else, set the previous after.
            if (_previous != _tierId - 1 || _tierIdAfter[msg.sender][_previous] != 0)
              // Set the tier after the previous one being iterated on as the tier being added, or 0 if the tier ID is incremented.
              _tierIdAfter[msg.sender][_previous] = _previous == _tierId - 1 ? 0 : _tierId;

            // For the next tier being added, start at the tier just placed.
            _startSortedTierId = _currentSortedTierId;

            // The tier just added is the previous for the next tier being added.
            _previous = _tierId;

            // Set current to zero to break out of the loop.
            _currentSortedTierId = 0;
          }
          // If the tier being iterated on is the last tier, add the tier after it.
          else if (_next == 0 || _next > _currentMaxTierIdOf) {
            if (_tierId != _currentSortedTierId + 1)
              _tierIdAfter[msg.sender][_currentSortedTierId] = _tierId;

            // For the next tier being added, start at this current tier ID.
            _startSortedTierId = _tierId;

            // Break out.
            _currentSortedTierId = 0;

            // If there's currently a last sorted tier ID tracked, override it.
            if (_trackedLastSortTierIdOf[msg.sender] != 0) _trackedLastSortTierIdOf[msg.sender] = 0;
          }
          // Move on to the next tier ID.
          else {
            // Set the previous tier ID to be the current tier ID.
            _previous = _currentSortedTierId;

            // Go to the next tier ID.
            _currentSortedTierId = _next;
          }
        }
      }

      // Set the tier ID in the returned value.
      tierIds[_i] = _tierId;

      unchecked {
        ++_i;
      }
    }

    maxTierIdOf[msg.sender] = _currentMaxTierIdOf + _numberOfNewTiers;
  }

  /** 
    @notice
    Mint a token within the tier for the provided value.

    @dev
    Only a project owner can mint tokens.

    @param _tierId The ID of the tier to mint within.
    @param _count The number of reserved tokens to mint. 

    @return tokenIds The IDs of the tokens being minted as reserves.
  */
  function recordMintReservesFor(
    uint256 _tierId,
    uint256 _count
  ) external override returns (uint256[] memory tokenIds) {
    // Get a reference to the tier.
    JBStored721Tier storage _storedTier = _storedTierOf[msg.sender][_tierId];

    // Get a reference to the number of reserved tokens mintable for the tier.
    uint256 _numberOfReservedTokensOutstanding = _numberOfReservedTokensOutstandingFor(
      msg.sender,
      _tierId,
      _storedTier
    );

    // Can't mint more reserves than expected.
    if (_count > _numberOfReservedTokensOutstanding) revert INSUFFICIENT_RESERVES();

    // Increment the number of reserved tokens minted.
    numberOfReservesMintedFor[msg.sender][_tierId] += _count;

    // Initialize an array with the appropriate length.
    tokenIds = new uint256[](_count);

    // Keep a reference to the number of burned in the tier.
    uint256 _numberOfBurnedFromTier = numberOfBurnedFor[msg.sender][_tierId];

    for (uint256 _i; _i < _count; ) {
      // Generate the tokens.
      tokenIds[_i] = _generateTokenId(
        _tierId,
        _storedTier.initialQuantity - --_storedTier.remainingQuantity + _numberOfBurnedFromTier
      );

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Sets the reserved token beneficiary.

    @param _beneficiary The reserved token beneficiary.
  */
  function recordSetDefaultReservedTokenBeneficiary(address _beneficiary) external override {
    defaultReservedTokenBeneficiaryOf[msg.sender] = _beneficiary;
  }

  /** 
    @notice
    Record a token transfer.

    @param _tierId The ID the tier being transferred.
    @param _from The sender of the token.
    @param _to The recipient of the token.
  */
  function recordTransferForTier(uint256 _tierId, address _from, address _to) external override {
    // If this is not a mint then subtract the tier balance from the original holder.
    if (_from != address(0))
      // decrease the tier balance for the sender
      --tierBalanceOf[msg.sender][_from][_tierId];

    // if this is a burn the balance is not added
    if (_to != address(0)) {
      unchecked {
        // increase the tier balance for the beneficiary
        ++tierBalanceOf[msg.sender][_to][_tierId];
      }
    }
  }

  /** 
    @notice
    Remove tiers. 

    @param _tierIds The tiers IDs to remove.
  */
  function recordRemoveTierIds(uint256[] calldata _tierIds) external override {
    // Get a reference to the number of tiers being removed.
    uint256 _numTiers = _tierIds.length;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    for (uint256 _i; _i < _numTiers; ) {
      // Set the tier being iterated on, 0-indexed
      _tierId = _tierIds[_i];

      // If the tier is locked throw an error.
      if (_storedTierOf[msg.sender][_tierId].lockedUntil + _BASE_LOCK_TIMESTAMP >= block.timestamp)
        revert TIER_LOCKED();

      // Set the tier as removed.
      _isTierRemovedBitmapWord[msg.sender].removeTier(_tierId);

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Mints a token in all provided tiers.

    @param _amount The amount to base the mints on. All mints' price floors must fit in this amount.
    @param _tierIds The IDs of the tier to mint from.
    @param _isManualMint A flag indicating if the mint is being made manually by the NFT's owner.

    @return tokenIds The IDs of the tokens minted.
    @return leftoverAmount The amount leftover after the mint.
  */
  function recordMint(
    uint256 _amount,
    uint16[] calldata _tierIds,
    bool _isManualMint
  ) external override returns (uint256[] memory tokenIds, uint256 leftoverAmount) {
    // Set the leftover amount as the initial amount.
    leftoverAmount = _amount;

    // Get a reference to the number of tiers.
    uint256 _numberOfTiers = _tierIds.length;

    // Keep a reference to the tier being iterated on.
    JBStored721Tier storage _storedTier;

    // Keep a reference to the tier ID being iterated on.
    uint256 _tierId;

    // Initialize an array with the appropriate length.
    tokenIds = new uint256[](_numberOfTiers);

    // Initialize a BitmapWord for isRemoved.
    JBBitmapWord memory _bitmapWord = _isTierRemovedBitmapWord[msg.sender].readId(_tierIds[0]);

    for (uint256 _i; _i < _numberOfTiers; ) {
      // Set the tier ID being iterated on.
      _tierId = _tierIds[_i];

      // Reset the bitmap if the current tier ID is outside the currently stored word.
      if (_bitmapWord.refreshBitmapNeeded(_tierId))
        _bitmapWord = _isTierRemovedBitmapWord[msg.sender].readId(_tierId);

      // Make sure the tier hasn't been removed.
      if (_bitmapWord.isTierIdRemoved(_tierId)) revert TIER_REMOVED();

      // Keep a reference to the tier being iterated on.
      _storedTier = _storedTierOf[msg.sender][_tierId];

      // If this is a manual mint, make sure manual minting is allowed.
      if (_isManualMint && !_storedTier.allowManualMint) revert CANT_MINT_MANUALLY();

      // Make sure the provided tier exists.
      if (_storedTier.initialQuantity == 0) revert INVALID_TIER();

      // Make sure the amount meets the tier's contribution floor.
      if (_storedTier.contributionFloor > leftoverAmount) revert INSUFFICIENT_AMOUNT();

      // Make sure there are enough units available.
      if (
        _storedTier.remainingQuantity -
          _numberOfReservedTokensOutstandingFor(msg.sender, _tierId, _storedTier) ==
        0
      ) revert OUT();

      // Mint the tokens.
      unchecked {
        // Keep a reference to the token ID.
        tokenIds[_i] = _generateTokenId(
          _tierId,
          _storedTier.initialQuantity -
            --_storedTier.remainingQuantity +
            numberOfBurnedFor[msg.sender][_tierId]
        );
      }

      // Update the leftover amount;
      leftoverAmount = leftoverAmount - _storedTier.contributionFloor;

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Records burned tokens.

    @param _tokenIds The IDs of the tokens burned.
  */
  function recordBurn(uint256[] calldata _tokenIds) external override {
    // Get a reference to the number of token IDs provided.
    uint256 _numberOfTokenIds = _tokenIds.length;

    // Keep a reference to the token ID being iterated on.
    uint256 _tokenId;

    // Iterate through all tokens to increment the burn count.
    for (uint256 _i; _i < _numberOfTokenIds; ) {
      // Set the token's ID.
      _tokenId = _tokenIds[_i];

      uint256 _tierId = tierIdOfToken(_tokenId);

      // Increment the number burned for the tier.
      numberOfBurnedFor[msg.sender][_tierId]++;

      _storedTierOf[msg.sender][_tierId].remainingQuantity++;

      unchecked {
        ++_i;
      }
    }
  }

  /** 
    @notice
    Sets the first owner of a token.

    @param _tokenId The ID of the token having the first owner set.
    @param _owner The owner to set as the first owner.
  */
  function recordSetFirstOwnerOf(uint256 _tokenId, address _owner) external override {
    firstOwnerOf[msg.sender][_tokenId] = _owner;
  }

  /** 
    @notice
    Sets the base URI. 

    @param _uri The base URI to set.
  */
  function recordSetBaseUri(string calldata _uri) external override {
    baseUriOf[msg.sender] = _uri;
  }

  /** 
    @notice
    Sets the contract URI. 

    @param _uri The contract URI to set.
  */
  function recordSetContractUri(string calldata _uri) external override {
    contractUriOf[msg.sender] = _uri;
  }

  /** 
    @notice
    Sets the token URI resolver. 

    @param _resolver The resolver to set.
  */
  function recordSetTokenUriResolver(IJBTokenUriResolver _resolver) external override {
    tokenUriResolverOf[msg.sender] = _resolver;
  }

  /** 
    @notice
    Sets the encoded IPFS URI of a tier. 

    @param _tierId The ID of the tier to set the encoded IPFS uri of.
    @param _encodedIPFSUri The encoded IPFS uri to set.
  */
  function recordSetEncodedIPFSUriOf(uint256 _tierId, bytes32 _encodedIPFSUri) external override {
    encodedIPFSUriOf[msg.sender][_tierId] = _encodedIPFSUri;
  }

  /** 
    @notice
    Sets flags. 

    @param _flags The flag to sets.
  */
  function recordFlags(JBTiered721Flags calldata _flags) external override {
    _flagsOf[msg.sender] = _flags;
  }

  /** 
    @notice
    Removes removed tiers from sequencing.

    @param _nft The NFT contract to clean tiers for.
  */
  function cleanTiers(address _nft) external override {
    // Keep a reference to the last tier ID.
    uint256 _lastSortedTierId = _lastSortedTierIdOf(_nft);

    // Get a reference to the tier ID being iterated on, starting with the starting tier ID.
    uint256 _currentSortedTierId = _firstSortedTierIdOf(_nft, 0);

    // Keep track of the previous non-removed tier ID.
    uint256 _previous;

    // Initialize a BitmapWord for isRemoved.
    JBBitmapWord memory _bitmapWord = _isTierRemovedBitmapWord[_nft].readId(_currentSortedTierId);

    // Make the sorted array.
    while (_currentSortedTierId != 0) {
      // Reset the bitmap if the current tier ID is outside the currently stored word.
      if (_bitmapWord.refreshBitmapNeeded(_currentSortedTierId))
        _bitmapWord = _isTierRemovedBitmapWord[_nft].readId(_currentSortedTierId);

      if (!_bitmapWord.isTierIdRemoved(_currentSortedTierId)) {
        // If the current tier ID being iterated on isn't an increment of the previous, set the correct tier after if needed.
        if (_currentSortedTierId != _previous + 1) {
          if (_tierIdAfter[_nft][_previous] != _currentSortedTierId)
            _tierIdAfter[_nft][_previous] = _currentSortedTierId;
          // Otherwise if the current tier ID is an increment of the previous and the tier ID after isn't 0, set it to 0.
        } else if (_tierIdAfter[_nft][_previous] != 0) _tierIdAfter[_nft][_previous] = 0;

        // Set the previous tier ID to be the current tier ID.
        _previous = _currentSortedTierId;
      }
      // Set the next sorted tier ID.
      _currentSortedTierId = _nextSortedTierIdOf(_nft, _currentSortedTierId, _lastSortedTierId);
    }

    emit CleanTiers(_nft, msg.sender);
  }

  //*********************************************************************//
  // ------------------------ internal functions ----------------------- //
  //*********************************************************************//

  /** 
    @notice
    The royalty beneficiary for each tier. 

    @param _nft The NFT to get the royalty beneficiary within.
    @param _tierId The ID of the tier to get a royalty beneficiary of.

    @return The reserved token beneficiary.
  */
  function _resolvedRoyaltyBeneficiaryOf(
    address _nft,
    uint256 _tierId
  ) internal view returns (address) {
    // Get the stored royalty beneficiary.
    address _storedRoyaltyBeneficiaryOfTier = _royaltyBeneficiaryOf[_nft][_tierId];

    // If the tier has a beneficiary return it.
    if (_storedRoyaltyBeneficiaryOfTier != address(0)) return _storedRoyaltyBeneficiaryOfTier;

    // Return the default.
    return defaultRoyaltyBeneficiaryOf[_nft];
  }

  /** 
    @notice
    The number of reserved tokens that can currently be minted within the tier. 

    @param _nft The NFT to get reserved tokens outstanding.
    @param _tierId The ID of the tier to get a number of reserved tokens outstanding.
    @param _storedTier The tier to get a number of reserved tokens outstanding.

    @return numberReservedTokensOutstanding The outstanding number of reserved tokens within the tier.
  */
  function _numberOfReservedTokensOutstandingFor(
    address _nft,
    uint256 _tierId,
    JBStored721Tier memory _storedTier
  ) internal view returns (uint256) {
    // No reserves outstanding if no mints or no reserved rate.
    if (
      _storedTier.reservedRate == 0 ||
      _storedTier.initialQuantity == _storedTier.remainingQuantity ||
      reservedTokenBeneficiaryOf(_nft, _tierId) == address(0)
    ) return 0;

    // The number of reserved tokens of the tier already minted.
    uint256 _reserveTokensMinted = numberOfReservesMintedFor[_nft][_tierId];

    // If only the reserved token (from the rounding up) has been minted so far, return 0.
    if (_storedTier.initialQuantity - _reserveTokensMinted == _storedTier.remainingQuantity)
      return 0;

    // Get a reference to the number of tokens already minted in the tier, not counting reserves or burned tokens.
    uint256 _numberOfNonReservesMinted = _storedTier.initialQuantity -
      _storedTier.remainingQuantity -
      _reserveTokensMinted;

    // Get the number of reserved tokens mintable given the number of non reserved tokens minted. This will round down.
    uint256 _numberReservedTokensMintable = _numberOfNonReservesMinted / _storedTier.reservedRate;

    // Round up.
    if (_numberOfNonReservesMinted % _storedTier.reservedRate > 0) ++_numberReservedTokensMintable;

    // Make sure there are more mintable than have been minted. This is possible if some tokens have been burned.
    if (_reserveTokensMinted > _numberReservedTokensMintable) return 0;

    // Return the difference between the amount mintable and the amount already minted.
    return _numberReservedTokensMintable - _reserveTokensMinted;
  }

  /** 
    @notice
    Finds the token ID and tier given a contribution amount. 

    @param _tierId The ID of the tier to generate an ID for.
    @param _tokenNumber The number of the token in the tier.

    @return The ID of the token.
  */
  function _generateTokenId(uint256 _tierId, uint256 _tokenNumber) internal pure returns (uint256) {
    return (_tierId * _ONE_BILLION) + _tokenNumber;
  }

  /** 
    @notice 
    The next sorted tier ID. 

    @param _nft The NFT for which the sorted tier ID applies.
    @param _id The ID relative to which the next sorted ID will be returned.
    @param _max The maximum possible ID.

    @return The ID.
  */
  function _nextSortedTierIdOf(
    address _nft,
    uint256 _id,
    uint256 _max
  ) internal view returns (uint256) {
    // If this is the last tier, return zero.
    if (_id == _max) return 0;

    // Update the current tier ID to be the one saved to be after, if it exists.
    uint256 _storedNext = _tierIdAfter[_nft][_id];

    if (_storedNext != 0) return _storedNext;

    // Otherwise increment the current.
    return _id + 1;
  }

  /** 
    @notice
    The first sorted tier ID of an NFT.

    @param _nft The NFT to get the first sorted tier ID of.
    @param _category The category to get the first sorted tier ID of. Send 0 for the first overall sorted ID.

    @return id The first sorted tier ID.
  */
  function _firstSortedTierIdOf(
    address _nft,
    uint256 _category
  ) internal view returns (uint256 id) {
    id = _category == 0 ? _tierIdAfter[_nft][0] : _startingTierIdOfCategory[_nft][_category];
    // Start at the first tier ID if nothing is specified.
    if (id == 0) id = 1;
  }

  /** 
    @notice
    The last sorted tier ID of an NFT.

    @param _nft The NFT to get the last sorted tier ID of.

    @return id The last sorted tier ID.
  */
  function _lastSortedTierIdOf(address _nft) internal view returns (uint256 id) {
    id = _trackedLastSortTierIdOf[_nft];
    // Start at the first ID if nothing is specified.
    if (id == 0) id = maxTierIdOf[_nft];
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@jbx-protocol/juice-contracts-v3/contracts/interfaces/IJBTokenUriResolver.sol';
import './../structs/JB721TierParams.sol';
import './../structs/JB721Tier.sol';
import './../structs/JBTiered721Flags.sol';

interface IJBTiered721DelegateStore {
  event CleanTiers(address indexed nft, address caller);

  function MAX_ROYALTY_RATE() external view returns (uint256);

  function totalSupply(address _nft) external view returns (uint256);

  function balanceOf(address _nft, address _owner) external view returns (uint256);

  function maxTierIdOf(address _nft) external view returns (uint256);

  function tiers(
    address _nft,
    uint256 _category,
    uint256 _startingSortIndex,
    uint256 _size
  ) external view returns (JB721Tier[] memory tiers);

  function tier(address _nft, uint256 _id) external view returns (JB721Tier memory tier);

  function tierBalanceOf(
    address _nft,
    address _owner,
    uint256 _tier
  ) external view returns (uint256);

  function tierOfTokenId(address _nft, uint256 _tokenId)
    external
    view
    returns (JB721Tier memory tier);

  function tierIdOfToken(uint256 _tokenId) external pure returns (uint256);

  function encodedIPFSUriOf(address _nft, uint256 _tierId) external view returns (bytes32);

  function firstOwnerOf(address _nft, uint256 _tokenId) external view returns (address);

  function redemptionWeightOf(address _nft, uint256[] memory _tokenIds)
    external
    view
    returns (uint256 weight);

  function totalRedemptionWeight(address _nft) external view returns (uint256 weight);

  function numberOfReservedTokensOutstandingFor(address _nft, uint256 _tierId)
    external
    view
    returns (uint256);

  function numberOfReservesMintedFor(address _nft, uint256 _tierId) external view returns (uint256);

  function numberOfBurnedFor(address _nft, uint256 _tierId) external view returns (uint256);

  function isTierRemoved(address _nft, uint256 _tierId) external view returns (bool);

  function flagsOf(address _nft) external view returns (JBTiered721Flags memory);

  function votingUnitsOf(address _nft, address _account) external view returns (uint256 units);

  function tierVotingUnitsOf(
    address _nft,
    address _account,
    uint256 _tierId
  ) external view returns (uint256 units);

  function defaultReservedTokenBeneficiaryOf(address _nft) external view returns (address);

  function defaultRoyaltyBeneficiaryOf(address _nft) external view returns (address);

  function reservedTokenBeneficiaryOf(address _nft, uint256 _tierId)
    external
    view
    returns (address);

  function baseUriOf(address _nft) external view returns (string memory);

  function contractUriOf(address _nft) external view returns (string memory);

  function tokenUriResolverOf(address _nft) external view returns (IJBTokenUriResolver);

  function encodedTierIPFSUriOf(address _nft, uint256 _tokenId) external view returns (bytes32);

  function royaltyInfo(
    address _nft,
    uint256 _tokenId,
    uint256 _salePrice
  ) external view returns (address receiver, uint256 royaltyAmount);

  function recordAddTiers(JB721TierParams[] memory _tierData)
    external
    returns (uint256[] memory tierIds);

  function recordMintReservesFor(uint256 _tierId, uint256 _count)
    external
    returns (uint256[] memory tokenIds);

  function recordBurn(uint256[] memory _tokenIds) external;

  function recordSetDefaultReservedTokenBeneficiary(address _beneficiary) external;

  function recordMint(
    uint256 _amount,
    uint16[] calldata _tierIds,
    bool _isManualMint
  ) external returns (uint256[] memory tokenIds, uint256 leftoverAmount);

  function recordTransferForTier(
    uint256 _tierId,
    address _from,
    address _to
  ) external;

  function recordRemoveTierIds(uint256[] memory _tierIds) external;

  function recordSetFirstOwnerOf(uint256 _tokenId, address _owner) external;

  function recordSetBaseUri(string memory _uri) external;

  function recordSetContractUri(string memory _uri) external;

  function recordSetTokenUriResolver(IJBTokenUriResolver _resolver) external;

  function recordSetEncodedIPFSUriOf(uint256 _tierId, bytes32 _encodedIPFSUri) external;

  function recordFlags(JBTiered721Flags calldata _flag) external;

  function cleanTiers(address _nft) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import '../structs/JBBitmapWord.sol';

/**
  @notice
  Utilities to manage bool bitmap storing the inactive tiers.
*/
library JBBitmap {
  /**
    @notice
    Initialize a BitmapWord struct, based on the mapping storage pointer and a given index.
  */
  function readId(mapping(uint256 => uint256) storage self, uint256 _index)
    internal
    view
    returns (JBBitmapWord memory)
  {
    uint256 _depth = _retrieveDepth(_index);

    return JBBitmapWord({currentWord: self[_depth], currentDepth: _depth});
  }

  /**
    @notice
    Returns the status of a given bit, in the single word stored in a BitmapWord struct.
  */
  function isTierIdRemoved(JBBitmapWord memory self, uint256 _index) internal pure returns (bool) {
    return (self.currentWord >> (_index % 256)) & 1 == 1;
  }

  /**
    @notice
    Returns the status of a bit in a given bitmap (index is the index in the reshaped bitmap matrix 1*n).
  */
  function isTierIdRemoved(mapping(uint256 => uint256) storage self, uint256 _index)
    internal
    view
    returns (bool)
  {
    uint256 _depth = _retrieveDepth(_index);
    return isTierIdRemoved(JBBitmapWord({currentWord: self[_depth], currentDepth: _depth}), _index);
  }

  /**
    @notice
    Flip the bit at a given index to true (this is a one-way operation).
  */
  function removeTier(mapping(uint256 => uint256) storage self, uint256 _index) internal {
    uint256 _depth = _retrieveDepth(_index);
    self[_depth] |= uint256(1 << (_index % 256));
  }

  /**
    @notice
    Return true if the index is in an another word than the one stored in the BitmapWord struct.
  */
  function refreshBitmapNeeded(JBBitmapWord memory self, uint256 _index)
    internal
    pure
    returns (bool)
  {
    return _retrieveDepth(_index) != self.currentDepth;
  }

  // Lib internal

  /**
    @notice
    Return the lines of the bitmap matrix where an index lies.
  */
  function _retrieveDepth(uint256 _index) internal pure returns (uint256) {
    return _index >> 8; // div by 256
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
  @member id The tier's ID.
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed or paused.
  @member remainingQuantity Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @member reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member reservedRateBeneficiary The beneificary of the reserved tokens for this tier.
  @member royaltyRate The percentage of each of the NFT sales that should be routed to the royalty beneficiary. Out of MAX_ROYALTY_RATE.
  @member royaltyBeneficiary The beneificary of the royalty.
  @member encodedIPFSUri The URI to use for each token within the tier.
  @member category A category to group NFT tiers by.
  @member allowManualMint A flag indicating if the contract's owner can mint from this tier on demand.
  @member transfersPausable A flag indicating if transfers from this tier can be pausable. 
*/
struct JB721Tier {
  uint256 id;
  uint256 contributionFloor;
  uint256 lockedUntil;
  uint256 remainingQuantity;
  uint256 initialQuantity;
  uint256 votingUnits;
  uint256 reservedRate;
  address reservedTokenBeneficiary;
  uint256 royaltyRate;
  address royaltyBeneficiary;
  bytes32 encodedIPFSUri;
  uint256 category;
  bool allowManualMint;
  bool transfersPausable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed or paused.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @memver reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member reservedRateBeneficiary The beneificary of the reserved tokens for this tier.
  @member royaltyRate The percentage of each of the NFT sales that should be routed to the royalty beneficiary. Out of MAX_ROYALTY_RATE.
  @member royaltyBeneficiary The beneificary of the royalty.
  @member encodedIPFSUri The URI to use for each token within the tier.
  @member category A category to group NFT tiers by.
  @member allowManualMint A flag indicating if the contract's owner can mint from this tier on demand.
  @member shouldUseReservedRateBeneficiaryAsDefault A flag indicating if the `reservedTokenBeneficiary` should be stored as the default beneficiary for all tiers.
  @member shouldUseRoyaltyBeneficiaryAsDefault A flag indicating if the `royaltyBeneficiary` should be stored as the default beneficiary for all tiers.
  @member transfersPausable A flag indicating if transfers from this tier can be pausable. 
*/
struct JB721TierParams {
  uint80 contributionFloor;
  uint48 lockedUntil;
  uint40 initialQuantity;
  uint16 votingUnits;
  uint16 reservedRate;
  address reservedTokenBeneficiary;
  uint8 royaltyRate;
  address royaltyBeneficiary;
  bytes32 encodedIPFSUri;
  uint8 category;
  bool allowManualMint;
  bool shouldUseReservedTokenBeneficiaryAsDefault;
  bool shouldUseRoyaltyBeneficiaryAsDefault;
  bool transfersPausable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
  @member The information stored at the index.
  @member The index.
*/
struct JBBitmapWord {
  uint256 currentWord;
  uint256 currentDepth;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
  @member contributionFloor The minimum contribution to qualify for this tier.
  @member lockedUntil The time up to which this tier cannot be removed. The application uses this value added to the timestamp for 1672531200 (Jan 1, 2023 00:00 UTC), allowing for storage in 40 bits. 
  @member remainingQuantity Remaining number of tokens in this tier. Together with idCeiling this enables for consecutive, increasing token ids to be issued to contributors.
  @member initialQuantity The initial `remainingAllowance` value when the tier was set.
  @member votingUnits The amount of voting significance to give this tier compared to others.
  @member reservedRate The number of minted tokens needed in the tier to allow for minting another reserved token.
  @member royaltyRate The percentage of each of the NFT sales that should be routed to the royalty beneficiary. Out of MAX_ROYALTY_RATE.
  @member category A category to group NFT tiers by.
  @member allowManualMint A flag indicating if the contract's owner can mint from this tier on demand.
  @member transfersPausable A flag indicating if transfers from this tier can be pausable. 
*/
struct JBStored721Tier {
  uint80 contributionFloor;
  uint40 lockedUntil;
  uint40 remainingQuantity;
  uint40 initialQuantity;
  uint16 votingUnits;
  uint16 reservedRate;
  uint8 royaltyRate;
  uint8 category;
  bool allowManualMint;
  bool transfersPausable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** 
  @member lockReservedTokenChanges A flag indicating if reserved tokens can change over time by adding new tiers with a reserved rate.
  @member lockVotingUnitChanges A flag indicating if voting unit expectations can change over time by adding new tiers with voting units.
  @member lockManualMintingChanges A flag indicating if manual minting expectations can change over time by adding new tiers with manual minting.
  @member preventOverspending A flag indicating if payments sending more than the value the NFTs being minted are worth should be reverted. 
*/
struct JBTiered721Flags {
  bool lockReservedTokenChanges;
  bool lockVotingUnitChanges;
  bool lockManualMintingChanges;
  bool preventOverspending;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBTokenUriResolver {
  function getUri(uint256 _projectId) external view returns (string memory tokenUri);
}

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

import "prb-math/contracts/PRBMath.sol";

// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4;

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivFixedPointOverflow(uint256 prod1);

/// @notice Emitted when the result overflows uint256.
error PRBMath__MulDivOverflow(uint256 prod1, uint256 denominator);

/// @notice Emitted when one of the inputs is type(int256).min.
error PRBMath__MulDivSignedInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows int256.
error PRBMath__MulDivSignedOverflow(uint256 rAbs);

/// @notice Emitted when the input is MIN_SD59x18.
error PRBMathSD59x18__AbsInputTooSmall();

/// @notice Emitted when ceiling a number overflows SD59x18.
error PRBMathSD59x18__CeilOverflow(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__DivInputTooSmall();

/// @notice Emitted when one of the intermediary unsigned results overflows SD59x18.
error PRBMathSD59x18__DivOverflow(uint256 rAbs);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathSD59x18__ExpInputTooBig(int256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathSD59x18__Exp2InputTooBig(int256 x);

/// @notice Emitted when flooring a number underflows SD59x18.
error PRBMathSD59x18__FloorUnderflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format overflows SD59x18.
error PRBMathSD59x18__FromIntOverflow(int256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format underflows SD59x18.
error PRBMathSD59x18__FromIntUnderflow(int256 x);

/// @notice Emitted when the product of the inputs is negative.
error PRBMathSD59x18__GmNegativeProduct(int256 x, int256 y);

/// @notice Emitted when multiplying the inputs overflows SD59x18.
error PRBMathSD59x18__GmOverflow(int256 x, int256 y);

/// @notice Emitted when the input is less than or equal to zero.
error PRBMathSD59x18__LogInputTooSmall(int256 x);

/// @notice Emitted when one of the inputs is MIN_SD59x18.
error PRBMathSD59x18__MulInputTooSmall();

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__MulOverflow(uint256 rAbs);

/// @notice Emitted when the intermediary absolute result overflows SD59x18.
error PRBMathSD59x18__PowuOverflow(uint256 rAbs);

/// @notice Emitted when the input is negative.
error PRBMathSD59x18__SqrtNegativeInput(int256 x);

/// @notice Emitted when the calculating the square root overflows SD59x18.
error PRBMathSD59x18__SqrtOverflow(int256 x);

/// @notice Emitted when addition overflows UD60x18.
error PRBMathUD60x18__AddOverflow(uint256 x, uint256 y);

/// @notice Emitted when ceiling a number overflows UD60x18.
error PRBMathUD60x18__CeilOverflow(uint256 x);

/// @notice Emitted when the input is greater than 133.084258667509499441.
error PRBMathUD60x18__ExpInputTooBig(uint256 x);

/// @notice Emitted when the input is greater than 192.
error PRBMathUD60x18__Exp2InputTooBig(uint256 x);

/// @notice Emitted when converting a basic integer to the fixed-point format format overflows UD60x18.
error PRBMathUD60x18__FromUintOverflow(uint256 x);

/// @notice Emitted when multiplying the inputs overflows UD60x18.
error PRBMathUD60x18__GmOverflow(uint256 x, uint256 y);

/// @notice Emitted when the input is less than 1.
error PRBMathUD60x18__LogInputTooSmall(uint256 x);

/// @notice Emitted when the calculating the square root overflows UD60x18.
error PRBMathUD60x18__SqrtOverflow(uint256 x);

/// @notice Emitted when subtraction underflows UD60x18.
error PRBMathUD60x18__SubUnderflow(uint256 x, uint256 y);

/// @dev Common mathematical functions used in both PRBMathSD59x18 and PRBMathUD60x18. Note that this shared library
/// does not always assume the signed 59.18-decimal fixed-point or the unsigned 60.18-decimal fixed-point
/// representation. When it does not, it is explicitly mentioned in the NatSpec documentation.
library PRBMath {
    /// STRUCTS ///

    struct SD59x18 {
        int256 value;
    }

    struct UD60x18 {
        uint256 value;
    }

    /// STORAGE ///

    /// @dev How many trailing decimals can be represented.
    uint256 internal constant SCALE = 1e18;

    /// @dev Largest power of two divisor of SCALE.
    uint256 internal constant SCALE_LPOTD = 262144;

    /// @dev SCALE inverted mod 2^256.
    uint256 internal constant SCALE_INVERSE =
        78156646155174841979727994598816262306175212592076161876661_508869554232690281;

    /// FUNCTIONS ///

    /// @notice Calculates the binary exponent of x using the binary fraction method.
    /// @dev Has to use 192.64-bit fixed-point numbers.
    /// See https://ethereum.stackexchange.com/a/96594/24693.
    /// @param x The exponent as an unsigned 192.64-bit fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function exp2(uint256 x) internal pure returns (uint256 result) {
        unchecked {
            // Start from 0.5 in the 192.64-bit fixed-point format.
            result = 0x800000000000000000000000000000000000000000000000;

            // Multiply the result by root(2, 2^-i) when the bit at position i is 1. None of the intermediary results overflows
            // because the initial result is 2^191 and all magic factors are less than 2^65.
            if (x & 0x8000000000000000 > 0) {
                result = (result * 0x16A09E667F3BCC909) >> 64;
            }
            if (x & 0x4000000000000000 > 0) {
                result = (result * 0x1306FE0A31B7152DF) >> 64;
            }
            if (x & 0x2000000000000000 > 0) {
                result = (result * 0x1172B83C7D517ADCE) >> 64;
            }
            if (x & 0x1000000000000000 > 0) {
                result = (result * 0x10B5586CF9890F62A) >> 64;
            }
            if (x & 0x800000000000000 > 0) {
                result = (result * 0x1059B0D31585743AE) >> 64;
            }
            if (x & 0x400000000000000 > 0) {
                result = (result * 0x102C9A3E778060EE7) >> 64;
            }
            if (x & 0x200000000000000 > 0) {
                result = (result * 0x10163DA9FB33356D8) >> 64;
            }
            if (x & 0x100000000000000 > 0) {
                result = (result * 0x100B1AFA5ABCBED61) >> 64;
            }
            if (x & 0x80000000000000 > 0) {
                result = (result * 0x10058C86DA1C09EA2) >> 64;
            }
            if (x & 0x40000000000000 > 0) {
                result = (result * 0x1002C605E2E8CEC50) >> 64;
            }
            if (x & 0x20000000000000 > 0) {
                result = (result * 0x100162F3904051FA1) >> 64;
            }
            if (x & 0x10000000000000 > 0) {
                result = (result * 0x1000B175EFFDC76BA) >> 64;
            }
            if (x & 0x8000000000000 > 0) {
                result = (result * 0x100058BA01FB9F96D) >> 64;
            }
            if (x & 0x4000000000000 > 0) {
                result = (result * 0x10002C5CC37DA9492) >> 64;
            }
            if (x & 0x2000000000000 > 0) {
                result = (result * 0x1000162E525EE0547) >> 64;
            }
            if (x & 0x1000000000000 > 0) {
                result = (result * 0x10000B17255775C04) >> 64;
            }
            if (x & 0x800000000000 > 0) {
                result = (result * 0x1000058B91B5BC9AE) >> 64;
            }
            if (x & 0x400000000000 > 0) {
                result = (result * 0x100002C5C89D5EC6D) >> 64;
            }
            if (x & 0x200000000000 > 0) {
                result = (result * 0x10000162E43F4F831) >> 64;
            }
            if (x & 0x100000000000 > 0) {
                result = (result * 0x100000B1721BCFC9A) >> 64;
            }
            if (x & 0x80000000000 > 0) {
                result = (result * 0x10000058B90CF1E6E) >> 64;
            }
            if (x & 0x40000000000 > 0) {
                result = (result * 0x1000002C5C863B73F) >> 64;
            }
            if (x & 0x20000000000 > 0) {
                result = (result * 0x100000162E430E5A2) >> 64;
            }
            if (x & 0x10000000000 > 0) {
                result = (result * 0x1000000B172183551) >> 64;
            }
            if (x & 0x8000000000 > 0) {
                result = (result * 0x100000058B90C0B49) >> 64;
            }
            if (x & 0x4000000000 > 0) {
                result = (result * 0x10000002C5C8601CC) >> 64;
            }
            if (x & 0x2000000000 > 0) {
                result = (result * 0x1000000162E42FFF0) >> 64;
            }
            if (x & 0x1000000000 > 0) {
                result = (result * 0x10000000B17217FBB) >> 64;
            }
            if (x & 0x800000000 > 0) {
                result = (result * 0x1000000058B90BFCE) >> 64;
            }
            if (x & 0x400000000 > 0) {
                result = (result * 0x100000002C5C85FE3) >> 64;
            }
            if (x & 0x200000000 > 0) {
                result = (result * 0x10000000162E42FF1) >> 64;
            }
            if (x & 0x100000000 > 0) {
                result = (result * 0x100000000B17217F8) >> 64;
            }
            if (x & 0x80000000 > 0) {
                result = (result * 0x10000000058B90BFC) >> 64;
            }
            if (x & 0x40000000 > 0) {
                result = (result * 0x1000000002C5C85FE) >> 64;
            }
            if (x & 0x20000000 > 0) {
                result = (result * 0x100000000162E42FF) >> 64;
            }
            if (x & 0x10000000 > 0) {
                result = (result * 0x1000000000B17217F) >> 64;
            }
            if (x & 0x8000000 > 0) {
                result = (result * 0x100000000058B90C0) >> 64;
            }
            if (x & 0x4000000 > 0) {
                result = (result * 0x10000000002C5C860) >> 64;
            }
            if (x & 0x2000000 > 0) {
                result = (result * 0x1000000000162E430) >> 64;
            }
            if (x & 0x1000000 > 0) {
                result = (result * 0x10000000000B17218) >> 64;
            }
            if (x & 0x800000 > 0) {
                result = (result * 0x1000000000058B90C) >> 64;
            }
            if (x & 0x400000 > 0) {
                result = (result * 0x100000000002C5C86) >> 64;
            }
            if (x & 0x200000 > 0) {
                result = (result * 0x10000000000162E43) >> 64;
            }
            if (x & 0x100000 > 0) {
                result = (result * 0x100000000000B1721) >> 64;
            }
            if (x & 0x80000 > 0) {
                result = (result * 0x10000000000058B91) >> 64;
            }
            if (x & 0x40000 > 0) {
                result = (result * 0x1000000000002C5C8) >> 64;
            }
            if (x & 0x20000 > 0) {
                result = (result * 0x100000000000162E4) >> 64;
            }
            if (x & 0x10000 > 0) {
                result = (result * 0x1000000000000B172) >> 64;
            }
            if (x & 0x8000 > 0) {
                result = (result * 0x100000000000058B9) >> 64;
            }
            if (x & 0x4000 > 0) {
                result = (result * 0x10000000000002C5D) >> 64;
            }
            if (x & 0x2000 > 0) {
                result = (result * 0x1000000000000162E) >> 64;
            }
            if (x & 0x1000 > 0) {
                result = (result * 0x10000000000000B17) >> 64;
            }
            if (x & 0x800 > 0) {
                result = (result * 0x1000000000000058C) >> 64;
            }
            if (x & 0x400 > 0) {
                result = (result * 0x100000000000002C6) >> 64;
            }
            if (x & 0x200 > 0) {
                result = (result * 0x10000000000000163) >> 64;
            }
            if (x & 0x100 > 0) {
                result = (result * 0x100000000000000B1) >> 64;
            }
            if (x & 0x80 > 0) {
                result = (result * 0x10000000000000059) >> 64;
            }
            if (x & 0x40 > 0) {
                result = (result * 0x1000000000000002C) >> 64;
            }
            if (x & 0x20 > 0) {
                result = (result * 0x10000000000000016) >> 64;
            }
            if (x & 0x10 > 0) {
                result = (result * 0x1000000000000000B) >> 64;
            }
            if (x & 0x8 > 0) {
                result = (result * 0x10000000000000006) >> 64;
            }
            if (x & 0x4 > 0) {
                result = (result * 0x10000000000000003) >> 64;
            }
            if (x & 0x2 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }
            if (x & 0x1 > 0) {
                result = (result * 0x10000000000000001) >> 64;
            }

            // We're doing two things at the same time:
            //
            //   1. Multiply the result by 2^n + 1, where "2^n" is the integer part and the one is added to account for
            //      the fact that we initially set the result to 0.5. This is accomplished by subtracting from 191
            //      rather than 192.
            //   2. Convert the result to the unsigned 60.18-decimal fixed-point format.
            //
            // This works because 2^(191-ip) = 2^ip / 2^191, where "ip" is the integer part "2^n".
            result *= SCALE;
            result >>= (191 - (x >> 64));
        }
    }

    /// @notice Finds the zero-based index of the first one in the binary representation of x.
    /// @dev See the note on msb in the "Find First Set" Wikipedia article https://en.wikipedia.org/wiki/Find_first_set
    /// @param x The uint256 number for which to find the index of the most significant bit.
    /// @return msb The index of the most significant bit as an uint256.
    function mostSignificantBit(uint256 x) internal pure returns (uint256 msb) {
        if (x >= 2**128) {
            x >>= 128;
            msb += 128;
        }
        if (x >= 2**64) {
            x >>= 64;
            msb += 64;
        }
        if (x >= 2**32) {
            x >>= 32;
            msb += 32;
        }
        if (x >= 2**16) {
            x >>= 16;
            msb += 16;
        }
        if (x >= 2**8) {
            x >>= 8;
            msb += 8;
        }
        if (x >= 2**4) {
            x >>= 4;
            msb += 4;
        }
        if (x >= 2**2) {
            x >>= 2;
            msb += 2;
        }
        if (x >= 2**1) {
            // No need to shift x any more.
            msb += 1;
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv.
    ///
    /// Requirements:
    /// - The denominator cannot be zero.
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The multiplicand as an uint256.
    /// @param y The multiplier as an uint256.
    /// @param denominator The divisor as an uint256.
    /// @return result The result as an uint256.
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        // Handle non-overflow cases, 256 by 256 division.
        if (prod1 == 0) {
            unchecked {
                result = prod0 / denominator;
            }
            return result;
        }

        // Make sure the result is less than 2^256. Also prevents denominator == 0.
        if (prod1 >= denominator) {
            revert PRBMath__MulDivOverflow(prod1, denominator);
        }

        ///////////////////////////////////////////////
        // 512 by 256 division.
        ///////////////////////////////////////////////

        // Make division exact by subtracting the remainder from [prod1 prod0].
        uint256 remainder;
        assembly {
            // Compute remainder using mulmod.
            remainder := mulmod(x, y, denominator)

            // Subtract 256 bit number from 512 bit number.
            prod1 := sub(prod1, gt(remainder, prod0))
            prod0 := sub(prod0, remainder)
        }

        // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
        // See https://cs.stackexchange.com/q/138556/92363.
        unchecked {
            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 lpotdod = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by lpotdod.
                denominator := div(denominator, lpotdod)

                // Divide [prod1 prod0] by lpotdod.
                prod0 := div(prod0, lpotdod)

                // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one.
                lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * lpotdod;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /// @notice Calculates floor(x*y÷1e18) with full precision.
    ///
    /// @dev Variant of "mulDiv" with constant folding, i.e. in which the denominator is always 1e18. Before returning the
    /// final result, we add 1 if (x * y) % SCALE >= HALF_SCALE. Without this, 6.6e-19 would be truncated to 0 instead of
    /// being rounded to 1e-18.  See "Listing 6" and text above it at https://accu.org/index.php/journals/1717.
    ///
    /// Requirements:
    /// - The result must fit within uint256.
    ///
    /// Caveats:
    /// - The body is purposely left uncommented; see the NatSpec comments in "PRBMath.mulDiv" to understand how this works.
    /// - It is assumed that the result can never be type(uint256).max when x and y solve the following two equations:
    ///     1. x * y = type(uint256).max * SCALE
    ///     2. (x * y) % SCALE >= SCALE / 2
    ///
    /// @param x The multiplicand as an unsigned 60.18-decimal fixed-point number.
    /// @param y The multiplier as an unsigned 60.18-decimal fixed-point number.
    /// @return result The result as an unsigned 60.18-decimal fixed-point number.
    function mulDivFixedPoint(uint256 x, uint256 y) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }

        if (prod1 >= SCALE) {
            revert PRBMath__MulDivFixedPointOverflow(prod1);
        }

        uint256 remainder;
        uint256 roundUpUnit;
        assembly {
            remainder := mulmod(x, y, SCALE)
            roundUpUnit := gt(remainder, 499999999999999999)
        }

        if (prod1 == 0) {
            unchecked {
                result = (prod0 / SCALE) + roundUpUnit;
                return result;
            }
        }

        assembly {
            result := add(
                mul(
                    or(
                        div(sub(prod0, remainder), SCALE_LPOTD),
                        mul(sub(prod1, gt(remainder, prod0)), add(div(sub(0, SCALE_LPOTD), SCALE_LPOTD), 1))
                    ),
                    SCALE_INVERSE
                ),
                roundUpUnit
            )
        }
    }

    /// @notice Calculates floor(x*y÷denominator) with full precision.
    ///
    /// @dev An extension of "mulDiv" for signed numbers. Works by computing the signs and the absolute values separately.
    ///
    /// Requirements:
    /// - None of the inputs can be type(int256).min.
    /// - The result must fit within int256.
    ///
    /// @param x The multiplicand as an int256.
    /// @param y The multiplier as an int256.
    /// @param denominator The divisor as an int256.
    /// @return result The result as an int256.
    function mulDivSigned(
        int256 x,
        int256 y,
        int256 denominator
    ) internal pure returns (int256 result) {
        if (x == type(int256).min || y == type(int256).min || denominator == type(int256).min) {
            revert PRBMath__MulDivSignedInputTooSmall();
        }

        // Get hold of the absolute values of x, y and the denominator.
        uint256 ax;
        uint256 ay;
        uint256 ad;
        unchecked {
            ax = x < 0 ? uint256(-x) : uint256(x);
            ay = y < 0 ? uint256(-y) : uint256(y);
            ad = denominator < 0 ? uint256(-denominator) : uint256(denominator);
        }

        // Compute the absolute value of (x*y)÷denominator. The result must fit within int256.
        uint256 rAbs = mulDiv(ax, ay, ad);
        if (rAbs > uint256(type(int256).max)) {
            revert PRBMath__MulDivSignedOverflow(rAbs);
        }

        // Get the signs of x, y and the denominator.
        uint256 sx;
        uint256 sy;
        uint256 sd;
        assembly {
            sx := sgt(x, sub(0, 1))
            sy := sgt(y, sub(0, 1))
            sd := sgt(denominator, sub(0, 1))
        }

        // XOR over sx, sy and sd. This is checking whether there are one or three negative signs in the inputs.
        // If yes, the result should be negative.
        result = sx ^ sy ^ sd == 0 ? -int256(rAbs) : int256(rAbs);
    }

    /// @notice Calculates the square root of x, rounding down.
    /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
    ///
    /// Caveats:
    /// - This function does not work with fixed-point numbers.
    ///
    /// @param x The uint256 number for which to calculate the square root.
    /// @return result The result as an uint256.
    function sqrt(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) {
            return 0;
        }

        // Set the initial guess to the least power of two that is greater than or equal to sqrt(x).
        uint256 xAux = uint256(x);
        result = 1;
        if (xAux >= 0x100000000000000000000000000000000) {
            xAux >>= 128;
            result <<= 64;
        }
        if (xAux >= 0x10000000000000000) {
            xAux >>= 64;
            result <<= 32;
        }
        if (xAux >= 0x100000000) {
            xAux >>= 32;
            result <<= 16;
        }
        if (xAux >= 0x10000) {
            xAux >>= 16;
            result <<= 8;
        }
        if (xAux >= 0x100) {
            xAux >>= 8;
            result <<= 4;
        }
        if (xAux >= 0x10) {
            xAux >>= 4;
            result <<= 2;
        }
        if (xAux >= 0x8) {
            result <<= 1;
        }

        // The operations can never overflow because the result is max 2^127 when it enters this block.
        unchecked {
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1;
            result = (result + x / result) >> 1; // Seven iterations should be enough
            uint256 roundedDownResult = x / result;
            return result >= roundedDownResult ? roundedDownResult : result;
        }
    }
}