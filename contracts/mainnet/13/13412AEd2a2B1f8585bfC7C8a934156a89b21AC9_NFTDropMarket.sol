/*
  ･
   *　★
      ･ ｡
        　･　ﾟ☆ ｡
  　　　 *　★ ﾟ･｡ *  ｡
          　　* ☆ ｡･ﾟ*.｡
      　　　ﾟ *.｡☆｡★　･
​
                      `                     .-:::::-.`              `-::---...```
                     `-:`               .:+ssssoooo++//:.`       .-/+shhhhhhhhhhhhhyyyssooo:
                    .--::.            .+ossso+/////++/:://-`   .////+shhhhhhhhhhhhhhhhhhhhhy
                  `-----::.         `/+////+++///+++/:--:/+/-  -////+shhhhhhhhhhhhhhhhhhhhhy
                 `------:::-`      `//-.``.-/+ooosso+:-.-/oso- -////+shhhhhhhhhhhhhhhhhhhhhy
                .--------:::-`     :+:.`  .-/osyyyyyyso++syhyo.-////+shhhhhhhhhhhhhhhhhhhhhy
              `-----------:::-.    +o+:-.-:/oyhhhhhhdhhhhhdddy:-////+shhhhhhhhhhhhhhhhhhhhhy
             .------------::::--  `oys+/::/+shhhhhhhdddddddddy/-////+shhhhhhhhhhhhhhhhhhhhhy
            .--------------:::::-` +ys+////+yhhhhhhhddddddddhy:-////+yhhhhhhhhhhhhhhhhhhhhhy
          `----------------::::::-`.ss+/:::+oyhhhhhhhhhhhhhhho`-////+shhhhhhhhhhhhhhhhhhhhhy
         .------------------:::::::.-so//::/+osyyyhhhhhhhhhys` -////+shhhhhhhhhhhhhhhhhhhhhy
       `.-------------------::/:::::..+o+////+oosssyyyyyyys+`  .////+shhhhhhhhhhhhhhhhhhhhhy
       .--------------------::/:::.`   -+o++++++oooosssss/.     `-//+shhhhhhhhhhhhhhhhhhhhyo
     .-------   ``````.......--`        `-/+ooooosso+/-`          `./++++///:::--...``hhhhyo
                                              `````
   *　
      ･ ｡
　　　　･　　ﾟ☆ ｡
  　　　 *　★ ﾟ･｡ *  ｡
          　　* ☆ ｡･ﾟ*.｡
      　　　ﾟ *.｡☆｡★　･
    *　　ﾟ｡·*･｡ ﾟ*
  　　　☆ﾟ･｡°*. ﾟ
　 ･ ﾟ*｡･ﾟ★｡
　　･ *ﾟ｡　　 *
　･ﾟ*｡★･
 ☆∴｡　*
･ ｡
*/

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./mixins/shared/FETHNode.sol";
import "./mixins/shared/FoundationTreasuryNode.sol";
import "./mixins/shared/Gap10000.sol";
import "./mixins/shared/MarketFees.sol";
import "./mixins/shared/MarketSharedCore.sol";
import "./mixins/shared/SendValueWithFallbackWithdraw.sol";

import "./mixins/nftDropMarket/NFTDropMarketCore.sol";
import "./mixins/nftDropMarket/NFTDropMarketFixedPriceSale.sol";

error NFTDropMarket_NFT_Already_Minted();

/**
 * @title A market for minting NFTs with Foundation.
 * @author batu-inal & HardlyDifficult
 */
contract NFTDropMarket is
  Initializable,
  FoundationTreasuryNode,
  FETHNode,
  MarketSharedCore,
  NFTDropMarketCore,
  ReentrancyGuardUpgradeable,
  SendValueWithFallbackWithdraw,
  MarketFees,
  Gap10000,
  NFTDropMarketFixedPriceSale
{
  /**
   * @notice Set immutable variables for the implementation contract.
   * @dev Using immutable instead of constants allows us to use different values on testnet.
   * @param treasury The Foundation Treasury contract address.
   * @param feth The FETH ERC-20 token contract address.
   * @param royaltyRegistry The Royalty Registry contract address.
   */
  constructor(
    address payable treasury,
    address feth,
    address royaltyRegistry
  )
    FoundationTreasuryNode(treasury)
    FETHNode(feth)
    MarketFees(
      /* protocolFeeInBasisPoints: */
      1500,
      royaltyRegistry,
      /* assumePrimarySale: */
      true
    )
    initializer // solhint-disable-next-line no-empty-blocks
  {}

  /**
   * @notice Called once to configure the contract after the initial proxy deployment.
   * @dev This farms the initialize call out to inherited contracts as needed to initialize mutable variables.
   */
  function initialize() external initializer {
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();
  }

  /**
   * @inheritdoc MarketSharedCore
   * @dev Returns address(0) if the NFT has already been sold, otherwise checks for a listing in this market.
   */
  function _getSellerOf(address nftContract, uint256 tokenId)
    internal
    view
    override(MarketSharedCore, NFTDropMarketFixedPriceSale)
    returns (address payable seller)
  {
    // Check the current owner first in case it has been sold.
    try IERC721(nftContract).ownerOf(tokenId) returns (address owner) {
      if (owner != address(0)) {
        // If sold, return address(0) since that owner cannot sell via this market.
        return payable(address(0));
      }
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    return super._getSellerOf(nftContract, tokenId);
  }

  /**
   * @inheritdoc MarketSharedCore
   * @dev Reverts if the NFT has already been sold, otherwise checks for a listing in this market.
   */
  function _getSellerOrOwnerOf(address nftContract, uint256 tokenId)
    internal
    view
    override
    returns (address payable sellerOrOwner)
  {
    // Check the current owner first in case it has been sold.
    try IERC721(nftContract).ownerOf(tokenId) returns (address owner) {
      if (owner != address(0)) {
        // Once an NFT has been minted, it cannot be sold through this contract.
        revert NFTDropMarket_NFT_Already_Minted();
      }
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    sellerOrOwner = super._getSellerOf(nftContract, tokenId);
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@manifoldxyz/royalty-registry-solidity/contracts/IRoyaltyRegistry.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../../interfaces/standards/royalties/IGetFees.sol";
import "../../interfaces/standards/royalties/IGetRoyalties.sol";
import "../../interfaces/standards/royalties/IOwnable.sol";
import "../../interfaces/standards/royalties/IRoyaltyInfo.sol";
import "../../interfaces/standards/royalties/ITokenCreator.sol";

import "../../libraries/ArrayLibrary.sol";
import "../../libraries/OZERC165Checker.sol";

import "./Constants.sol";
import "./FoundationTreasuryNode.sol";
import "./SendValueWithFallbackWithdraw.sol";
import "./MarketSharedCore.sol";

error NFTMarketFees_Address_Does_Not_Support_IRoyaltyRegistry();
error NFTMarketFees_Invalid_Protocol_Fee();

/**
 * @title A mixin to distribute funds when an NFT is sold.
 * @author batu-inal & HardlyDifficult
 */
abstract contract MarketFees is FoundationTreasuryNode, MarketSharedCore, SendValueWithFallbackWithdraw {
  using AddressUpgradeable for address;
  using ArrayLibrary for address payable[];
  using ArrayLibrary for uint256[];
  using ERC165Checker for address;
  using OZERC165Checker for address;

  /**
   * @dev Removing old unused variables in an upgrade safe way. Was:
   * uint256 private _primaryFoundationFeeBasisPoints;
   * uint256 private _secondaryFoundationFeeBasisPoints;
   * uint256 private _secondaryCreatorFeeBasisPoints;
   * mapping(address => mapping(uint256 => bool)) private _nftContractToTokenIdToFirstSaleCompleted;
   */
  uint256[4] private __gap_was_fees;

  /// @notice The royalties sent to creator recipients on secondary sales.
  uint256 private constant CREATOR_ROYALTY_DENOMINATOR = BASIS_POINTS / 1_000; // 10%
  /// @notice The fee collected by Foundation for sales facilitated by this market contract.
  uint256 private immutable PROTOCOL_FEE_IN_BASIS_POINTS;
  /// @notice The fee collected by the buy referrer for sales facilitated by this market contract.
  ///         This fee is calculated from the total protocol fee.
  uint256 private constant BUY_REFERRER_FEE_DENOMINATOR = BASIS_POINTS / 100; // 1%

  IRoyaltyRegistry private immutable royaltyRegistry;

  /// @notice The address of this contract's implementation.
  /// @dev This is used when making stateless external calls to this contract,
  /// saving gas over hopping through the proxy which is only necessary when accessing state.
  MarketFees private immutable implementationAddress;

  /// @notice True for the Drop market which only performs primary sales. False if primary & secondary are supported.
  bool private immutable assumePrimarySale;

  /**
   * @notice Emitted when an NFT sold with a referrer.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param buyReferrer The account which received the buy referral incentive.
   * @param buyReferrerFee The portion of the protocol fee collected by the buy referrer.
   * @param buyReferrerSellerFee The portion of the owner revenue collected by the buy referrer (not implemented).
   */
  event BuyReferralPaid(
    address indexed nftContract,
    uint256 indexed tokenId,
    address buyReferrer,
    uint256 buyReferrerFee,
    uint256 buyReferrerSellerFee
  );

  /**
   * @notice Configures the registry allowing for royalty overrides to be defined.
   * @param _royaltyRegistry The registry to use for royalty overrides.
   * @param _assumePrimarySale True for the Drop market which only performs primary sales.
   * False if primary & secondary are supported.
   */
  constructor(
    uint16 protocolFeeInBasisPoints,
    address _royaltyRegistry,
    bool _assumePrimarySale
  ) {
    if (
      protocolFeeInBasisPoints < BASIS_POINTS / BUY_REFERRER_FEE_DENOMINATOR ||
      protocolFeeInBasisPoints + BASIS_POINTS / CREATOR_ROYALTY_DENOMINATOR >= BASIS_POINTS
    ) {
      /* If the protocol fee is invalid, revert:
       * Protocol fee must be greater than the buy referrer fee since referrer fees are deducted from the protocol fee.
       * The protocol fee must leave room for the creator royalties.
       */
      revert NFTMarketFees_Invalid_Protocol_Fee();
    }
    PROTOCOL_FEE_IN_BASIS_POINTS = protocolFeeInBasisPoints;

    if (!_royaltyRegistry.supportsInterface(type(IRoyaltyRegistry).interfaceId)) {
      revert NFTMarketFees_Address_Does_Not_Support_IRoyaltyRegistry();
    }
    royaltyRegistry = IRoyaltyRegistry(_royaltyRegistry);

    assumePrimarySale = _assumePrimarySale;

    // In the constructor, `this` refers to the implementation address. Everywhere else it'll be the proxy.
    implementationAddress = this;
  }

  /**
   * @notice Distributes funds to foundation, creator recipients, and NFT owner after a sale.
   */
  function _distributeFunds(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    uint256 price,
    address payable buyReferrer
  )
    internal
    returns (
      uint256 totalFees,
      uint256 creatorRev,
      uint256 sellerRev
    )
  {
    if (price == 0) {
      // When the sale price is 0, there are no revenue to distribute.
      return (0, 0, 0);
    }

    address payable[] memory creatorRecipients;
    uint256[] memory creatorShares;

    uint256 buyReferrerFee;
    (totalFees, creatorRecipients, creatorShares, sellerRev, buyReferrerFee) = _getFees(
      nftContract,
      tokenId,
      seller,
      price,
      buyReferrer
    );

    // Pay the creator(s)
    // If just a single recipient was defined, use a larger gas limit in order to support in-contract split logic.
    uint256 creatorGasLimit = creatorRecipients.length == 1
      ? SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS
      : SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT;
    unchecked {
      for (uint256 i = 0; i < creatorRecipients.length; ++i) {
        _sendValueWithFallbackWithdraw(creatorRecipients[i], creatorShares[i], creatorGasLimit);
        // Sum the total creator rev from shares
        // creatorShares is in ETH so creatorRev will not overflow here.
        creatorRev += creatorShares[i];
      }
    }

    // Pay the seller
    _sendValueWithFallbackWithdraw(seller, sellerRev, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);

    // Pay the protocol fee
    _sendValueWithFallbackWithdraw(getFoundationTreasury(), totalFees, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);

    // Pay the buy referrer fee
    if (buyReferrerFee != 0) {
      _sendValueWithFallbackWithdraw(buyReferrer, buyReferrerFee, SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT);
      emit BuyReferralPaid(nftContract, tokenId, buyReferrer, buyReferrerFee, 0);
      unchecked {
        // Add the referrer fee back into the total fees so that all 3 return fields sum to the total price for events
        totalFees += buyReferrerFee;
      }
    }
  }

  /**
   * @notice Returns how funds will be distributed for a sale at the given price point.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @param price The sale price to calculate the fees for.
   * @return totalFees How much will be sent to the Foundation treasury and/or referrals.
   * @return creatorRev How much will be sent across all the `creatorRecipients` defined.
   * @return creatorRecipients The addresses of the recipients to receive a portion of the creator fee.
   * @return creatorShares The percentage of the creator fee to be distributed to each `creatorRecipient`.
   * If there is only one `creatorRecipient`, this may be an empty array.
   * Otherwise `creatorShares.length` == `creatorRecipients.length`.
   * @return sellerRev How much will be sent to the owner/seller of the NFT.
   * If the NFT is being sold by the creator, this may be 0 and the full revenue will appear as `creatorRev`.
   * @return seller The address of the owner of the NFT.
   * If `sellerRev` is 0, this may be `address(0)`.
   */
  function getFeesAndRecipients(
    address nftContract,
    uint256 tokenId,
    uint256 price
  )
    external
    view
    returns (
      uint256 totalFees,
      uint256 creatorRev,
      address payable[] memory creatorRecipients,
      uint256[] memory creatorShares,
      uint256 sellerRev,
      address payable seller
    )
  {
    seller = _getSellerOrOwnerOf(nftContract, tokenId);
    (totalFees, creatorRecipients, creatorShares, sellerRev, ) = _getFees(
      nftContract,
      tokenId,
      seller,
      price,
      // Notice: Setting this value is a breaking change for the FNDMiddleware contract.
      // Will be wired in an upcoming release to communicate the buy referral information.
      payable(0)
    );

    // Sum the total creator rev from shares
    unchecked {
      for (uint256 i = 0; i < creatorShares.length; ++i) {
        creatorRev += creatorShares[i];
      }
    }
  }

  /**
   * @notice Returns the address of the registry allowing for royalty configuration overrides.
   * @dev See https://royaltyregistry.xyz/
   * @return registry The address of the royalty registry contract.
   */
  function getRoyaltyRegistry() external view returns (address registry) {
    registry = address(royaltyRegistry);
  }

  /**
   * @notice **For internal use only.**
   * @dev This function is external to allow using try/catch but is not intended for external use.
   * This checks the token creator.
   */
  function internalGetTokenCreator(address nftContract, uint256 tokenId)
    external
    view
    returns (address payable creator)
  {
    creator = ITokenCreator(nftContract).tokenCreator{ gas: READ_ONLY_GAS_LIMIT }(tokenId);
  }

  /**
   * @notice **For internal use only.**
   * @dev This function is external to allow using try/catch but is not intended for external use.
   * If ERC2981 royalties (or getRoyalties) are defined by the NFT contract, allow this standard to define immutable
   * royalties that cannot be later changed via the royalty registry.
   */
  function internalGetImmutableRoyalties(address nftContract, uint256 tokenId)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory splitPerRecipientInBasisPoints)
  {
    // 1st priority: ERC-2981
    if (nftContract.supportsERC165InterfaceUnchecked(type(IRoyaltyInfo).interfaceId)) {
      try IRoyaltyInfo(nftContract).royaltyInfo{ gas: READ_ONLY_GAS_LIMIT }(tokenId, BASIS_POINTS) returns (
        address receiver,
        uint256 royaltyAmount
      ) {
        // Manifold contracts return (address(this), 0) when royalties are not defined
        // - so ignore results when the amount is 0
        if (royaltyAmount > 0) {
          recipients = new address payable[](1);
          recipients[0] = payable(receiver);
          splitPerRecipientInBasisPoints = new uint256[](1);
          // The split amount is assumed to be 100% when only 1 recipient is returned
          return (recipients, splitPerRecipientInBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }

    // 2nd priority: getRoyalties
    if (nftContract.supportsERC165InterfaceUnchecked(type(IGetRoyalties).interfaceId)) {
      try IGetRoyalties(nftContract).getRoyalties{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
        address payable[] memory _recipients,
        uint256[] memory recipientBasisPoints
      ) {
        if (_recipients.length != 0 && _recipients.length == recipientBasisPoints.length) {
          return (_recipients, recipientBasisPoints);
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }
  }

  /**
   * @notice **For internal use only.**
   * @dev This function is external to allow using try/catch but is not intended for external use.
   * This checks for royalties defined in the royalty registry or via a non-standard royalty API.
   */
  // solhint-disable-next-line code-complexity
  function internalGetMutableRoyalties(
    address nftContract,
    uint256 tokenId,
    address payable creator
  ) external view returns (address payable[] memory recipients, uint256[] memory splitPerRecipientInBasisPoints) {
    /* Overrides must support ERC-165 when registered, except for overrides defined by the registry owner.
       If that results in an override w/o 165 we may need to upgrade the market to support or ignore that override. */
    // The registry requires overrides are not 0 and contracts when set.
    // If no override is set, the nftContract address is returned.

    try royaltyRegistry.getRoyaltyLookupAddress{ gas: READ_ONLY_GAS_LIMIT }(nftContract) returns (
      address overrideContract
    ) {
      if (overrideContract != nftContract) {
        nftContract = overrideContract;

        // The functions above are repeated here if an override is set.

        // 3rd priority: ERC-2981 override
        if (nftContract.supportsERC165InterfaceUnchecked(type(IRoyaltyInfo).interfaceId)) {
          try IRoyaltyInfo(nftContract).royaltyInfo{ gas: READ_ONLY_GAS_LIMIT }(tokenId, BASIS_POINTS) returns (
            address receiver,
            uint256 royaltyAmount
          ) {
            // Manifold contracts return (address(this), 0) when royalties are not defined
            // - so ignore results when the amount is 0
            if (royaltyAmount != 0) {
              recipients = new address payable[](1);
              recipients[0] = payable(receiver);
              splitPerRecipientInBasisPoints = new uint256[](1);
              // The split amount is assumed to be 100% when only 1 recipient is returned
              return (recipients, splitPerRecipientInBasisPoints);
            }
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }

        // 4th priority: getRoyalties override
        if (recipients.length == 0 && nftContract.supportsERC165InterfaceUnchecked(type(IGetRoyalties).interfaceId)) {
          try IGetRoyalties(nftContract).getRoyalties{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
            address payable[] memory _recipients,
            uint256[] memory recipientBasisPoints
          ) {
            if (_recipients.length != 0 && _recipients.length == recipientBasisPoints.length) {
              return (_recipients, recipientBasisPoints);
            }
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }
      }
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Ignore out of gas errors and continue using the nftContract address
    }

    // 5th priority: getFee* from contract or override
    if (nftContract.supportsERC165InterfaceUnchecked(type(IGetFees).interfaceId)) {
      try IGetFees(nftContract).getFeeRecipients{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
        address payable[] memory _recipients
      ) {
        if (_recipients.length != 0) {
          try IGetFees(nftContract).getFeeBps{ gas: READ_ONLY_GAS_LIMIT }(tokenId) returns (
            uint256[] memory recipientBasisPoints
          ) {
            if (_recipients.length == recipientBasisPoints.length) {
              return (_recipients, recipientBasisPoints);
            }
          } catch // solhint-disable-next-line no-empty-blocks
          {
            // Fall through
          }
        }
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }

    // 6th priority: tokenCreator w/ or w/o requiring 165 from contract or override
    if (creator != address(0)) {
      // Only pay the tokenCreator if there wasn't another royalty defined
      recipients = new address payable[](1);
      recipients[0] = creator;
      splitPerRecipientInBasisPoints = new uint256[](1);
      // The split amount is assumed to be 100% when only 1 recipient is returned
      return (recipients, splitPerRecipientInBasisPoints);
    }

    // 7th priority: owner from contract or override
    try IOwnable(nftContract).owner{ gas: READ_ONLY_GAS_LIMIT }() returns (address owner) {
      if (owner != address(0)) {
        // Only pay the owner if there wasn't another royalty defined
        recipients = new address payable[](1);
        recipients[0] = payable(owner);
        splitPerRecipientInBasisPoints = new uint256[](1);
        // The split amount is assumed to be 100% when only 1 recipient is returned
        return (recipients, splitPerRecipientInBasisPoints);
      }
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    // If no valid payment address or creator is found, return 0 recipients
  }

  /**
   * @notice Calculates how funds should be distributed for the given sale details.
   * @dev When the NFT is being sold by the `tokenCreator`, all the seller revenue will
   * be split with the royalty recipients defined for that NFT.
   */
  // solhint-disable-next-line code-complexity
  function _getFees(
    address nftContract,
    uint256 tokenId,
    address payable seller,
    uint256 price,
    address payable buyReferrer
  )
    private
    view
    returns (
      uint256 totalFees,
      address payable[] memory creatorRecipients,
      uint256[] memory creatorShares,
      uint256 sellerRev,
      uint256 buyReferrerFee
    )
  {
    // Calculate the protocol fee
    totalFees = (price * PROTOCOL_FEE_IN_BASIS_POINTS) / BASIS_POINTS;

    address payable creator;
    try implementationAddress.internalGetTokenCreator(nftContract, tokenId) returns (address payable _creator) {
      creator = _creator;
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    try implementationAddress.internalGetImmutableRoyalties(nftContract, tokenId) returns (
      address payable[] memory _recipients,
      uint256[] memory _splitPerRecipientInBasisPoints
    ) {
      (creatorRecipients, creatorShares) = (_recipients, _splitPerRecipientInBasisPoints);
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Fall through
    }

    if (creatorRecipients.length == 0) {
      // Check mutable royalties only if we didn't find results from the immutable API
      try implementationAddress.internalGetMutableRoyalties(nftContract, tokenId, creator) returns (
        address payable[] memory _recipients,
        uint256[] memory _splitPerRecipientInBasisPoints
      ) {
        (creatorRecipients, creatorShares) = (_recipients, _splitPerRecipientInBasisPoints);
      } catch // solhint-disable-next-line no-empty-blocks
      {
        // Fall through
      }
    }

    if (creatorRecipients.length != 0 || assumePrimarySale) {
      uint256 creatorRev;
      if (assumePrimarySale) {
        // All revenue should go to the creator recipients
        unchecked {
          // totalFees is always < price.
          creatorRev = price - totalFees;
        }
        if (creatorRecipients.length == 0) {
          // If no creators were found via the royalty APIs, then set that recipient to the seller's address
          creatorRecipients = new address payable[](1);
          creatorRecipients[0] = seller;
          creatorShares = new uint256[](1);
          // The split amount is assumed to be 100% when only 1 recipient is returned
        }
      } else if (seller == creator || (creatorRecipients.length != 0 && seller == creatorRecipients[0])) {
        // When sold by the creator, all revenue is split if applicable.
        unchecked {
          // totalFees is always < price.
          creatorRev = price - totalFees;
        }
      } else {
        // Rounding favors the owner first, then creator, and foundation last.
        unchecked {
          // Safe math is not required when dividing by a non-zero constant.
          creatorRev = price / CREATOR_ROYALTY_DENOMINATOR;
        }
        sellerRev = price - totalFees - creatorRev;
      }

      // Cap the max number of recipients supported
      creatorRecipients.capLength(MAX_ROYALTY_RECIPIENTS);
      creatorShares.capLength(MAX_ROYALTY_RECIPIENTS);

      // Sum the total shares defined
      uint256 totalShares;
      if (creatorRecipients.length > 1) {
        unchecked {
          for (uint256 i = 0; i < creatorRecipients.length; ++i) {
            if (creatorRecipients[i] == seller) {
              // If the seller is any of the recipients defined, assume a primary sale
              creatorRev += sellerRev;
              sellerRev = 0;
            }
            if (creatorShares[i] > BASIS_POINTS) {
              // If the numbers are >100% we ignore the fee recipients and pay just the first instead
              totalShares = 0;
              break;
            }
            totalShares += creatorShares[i];
          }
        }

        if (totalShares == 0) {
          // If no shares were defined or shares were out of bounds, pay only the first recipient
          creatorRecipients.capLength(1);
          creatorShares.capLength(1);
        }
      }

      // Send payouts to each additional recipient if more than 1 was defined
      uint256 totalRoyaltiesDistributed;
      for (uint256 i = 1; i < creatorRecipients.length; ) {
        uint256 royalty = (creatorRev * creatorShares[i]) / totalShares;
        totalRoyaltiesDistributed += royalty;
        creatorShares[i] = royalty;
        unchecked {
          ++i;
        }
      }

      // Send the remainder to the 1st creator, rounding in their favor
      creatorShares[0] = creatorRev - totalRoyaltiesDistributed;
    } else {
      // No royalty recipients found.
      unchecked {
        // totalFees is always < price.
        sellerRev = price - totalFees;
      }
    }

    if (buyReferrer != address(0) && buyReferrer != msg.sender && buyReferrer != seller && buyReferrer != creator) {
      unchecked {
        buyReferrerFee = price / BUY_REFERRER_FEE_DENOMINATOR;

        // buyReferrerFee is always <= totalFees
        totalFees -= buyReferrerFee;
      }
    }
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[1_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @title A placeholder contract leaving room for new mixins to be added to the future.
 * @author batu-inal & HardlyDifficult
 */
abstract contract Gap10000 {
  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[10_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../../interfaces/internal/roles/IAdminRole.sol";
import "../../interfaces/internal/roles/IOperatorRole.sol";

error FoundationTreasuryNode_Address_Is_Not_A_Contract();
error FoundationTreasuryNode_Caller_Not_Admin();
error FoundationTreasuryNode_Caller_Not_Operator();

/**
 * @title A mixin that stores a reference to the Foundation treasury contract.
 * @notice The treasury collects fees and defines admin/operator roles.
 * @author batu-inal & HardlyDifficult
 */
abstract contract FoundationTreasuryNode {
  using AddressUpgradeable for address payable;

  /// @dev This value was replaced with an immutable version.
  address payable private __gap_was_treasury;

  /// @notice The address of the treasury contract.
  address payable private immutable treasury;

  /// @notice Requires the caller is a Foundation admin.
  modifier onlyFoundationAdmin() {
    if (!IAdminRole(treasury).isAdmin(msg.sender)) {
      revert FoundationTreasuryNode_Caller_Not_Admin();
    }
    _;
  }

  /// @notice Requires the caller is a Foundation operator.
  modifier onlyFoundationOperator() {
    if (!IOperatorRole(treasury).isOperator(msg.sender)) {
      revert FoundationTreasuryNode_Caller_Not_Operator();
    }
    _;
  }

  /**
   * @notice Set immutable variables for the implementation contract.
   * @dev Assigns the treasury contract address.
   */
  constructor(address payable _treasury) {
    if (!_treasury.isContract()) {
      revert FoundationTreasuryNode_Address_Is_Not_A_Contract();
    }
    treasury = _treasury;
  }

  /**
   * @notice Gets the Foundation treasury contract.
   * @dev This call is used in the royalty registry contract.
   * @return treasuryAddress The address of the Foundation treasury contract.
   */
  function getFoundationTreasury() public view returns (address payable treasuryAddress) {
    treasuryAddress = treasury;
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[2_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../../interfaces/internal/IFethMarket.sol";

error FETHNode_FETH_Address_Is_Not_A_Contract();
error FETHNode_Only_FETH_Can_Transfer_ETH();

/**
 * @title A mixin for interacting with the FETH contract.
 * @author batu-inal & HardlyDifficult
 */
abstract contract FETHNode {
  using AddressUpgradeable for address;
  using AddressUpgradeable for address payable;

  /// @notice The FETH ERC-20 token for managing escrow and lockup.
  IFethMarket internal immutable feth;

  constructor(address _feth) {
    if (!_feth.isContract()) {
      revert FETHNode_FETH_Address_Is_Not_A_Contract();
    }

    feth = IFethMarket(_feth);
  }

  /**
   * @notice Only used by FETH. Any direct transfer from users will revert.
   */
  receive() external payable {
    if (msg.sender != address(feth)) {
      revert FETHNode_Only_FETH_Can_Transfer_ETH();
    }
  }

  /**
   * @notice Withdraw the msg.sender's available FETH balance if they requested more than the msg.value provided.
   * @dev This may revert if the msg.sender is non-receivable.
   * This helper should not be used anywhere that may lead to locked assets.
   * @param totalAmount The total amount of ETH required (including the msg.value).
   * @param shouldRefundSurplus If true, refund msg.value - totalAmount to the msg.sender.
   */
  function _tryUseFETHBalance(uint256 totalAmount, bool shouldRefundSurplus) internal {
    if (totalAmount > msg.value) {
      // Withdraw additional ETH required from the user's available FETH balance.
      unchecked {
        // The if above ensures delta will not underflow.
        // Withdraw ETH from the user's account in the FETH token contract,
        // making the funds available in this contract as ETH.
        feth.marketWithdrawFrom(msg.sender, totalAmount - msg.value);
      }
    } else if (shouldRefundSurplus && totalAmount < msg.value) {
      // Return any surplus ETH to the user.
      unchecked {
        // The if above ensures this will not underflow
        payable(msg.sender).sendValue(msg.value - totalAmount);
      }
    }
  }

  /**
   * @notice Gets the FETH contract used to escrow offer funds.
   * @return fethAddress The FETH contract address.
   */
  function getFethAddress() external view returns (address fethAddress) {
    fethAddress = address(feth);
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "./FETHNode.sol";

/**
 * @title A place for common modifiers and functions used by various market mixins, if any.
 * @dev This also leaves a gap which can be used to add a new mixin to the top of the inheritance tree.
 * @author batu-inal & HardlyDifficult
 */
abstract contract MarketSharedCore is FETHNode {
  /**
   * @notice Checks who the seller for an NFT is if listed in this market.
   * @param nftContract The address of the NFT contract.
   * @param tokenId The id of the NFT.
   * @return seller The seller which listed this NFT for sale, or address(0) if not listed.
   */
  function getSellerOf(address nftContract, uint256 tokenId) external view returns (address payable seller) {
    seller = _getSellerOf(nftContract, tokenId);
  }

  /**
   * @notice Checks who the seller for an NFT is if listed in this market.
   */
  function _getSellerOf(address nftContract, uint256 tokenId) internal view virtual returns (address payable seller);

  /**
   * @notice Checks who the seller for an NFT is if listed in this market or returns the current owner.
   */
  function _getSellerOrOwnerOf(address nftContract, uint256 tokenId)
    internal
    view
    virtual
    returns (address payable sellerOrOwner);

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[500] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./FETHNode.sol";

/**
 * @title A mixin for sending ETH with a fallback withdraw mechanism.
 * @notice Attempt to send ETH and if the transfer fails or runs out of gas, store the balance
 * in the FETH token contract for future withdrawal instead.
 * @dev This mixin was recently switched to escrow funds in FETH.
 * Once we have confirmed all pending balances have been withdrawn, we can remove the escrow tracking here.
 * @author batu-inal & HardlyDifficult
 */
abstract contract SendValueWithFallbackWithdraw is FETHNode {
  using AddressUpgradeable for address payable;

  /// @dev Removing old unused variables in an upgrade safe way.
  uint256 private __gap_was_pendingWithdrawals;

  /**
   * @notice Emitted when escrowed funds are withdrawn to FETH.
   * @param user The account which has withdrawn ETH.
   * @param amount The amount of ETH which has been withdrawn.
   */
  event WithdrawalToFETH(address indexed user, uint256 amount);

  /**
   * @notice Attempt to send a user or contract ETH.
   * If it fails store the amount owned for later withdrawal in FETH.
   * @dev This may fail when sending ETH to a contract that is non-receivable or exceeds the gas limit specified.
   */
  function _sendValueWithFallbackWithdraw(
    address payable user,
    uint256 amount,
    uint256 gasLimit
  ) internal {
    if (amount == 0) {
      return;
    }
    // Cap the gas to prevent consuming all available gas to block a tx from completing successfully
    // solhint-disable-next-line avoid-low-level-calls
    (bool success, ) = user.call{ value: amount, gas: gasLimit }("");
    if (!success) {
      // Store the funds that failed to send for the user in the FETH token
      feth.depositFor{ value: amount }(user);
      emit WithdrawalToFETH(user, amount);
    }
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[999] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @title A place for common modifiers and functions used by various market mixins, if any.
 * @dev This also leaves a gap which can be used to add a new mixin to the top of the inheritance tree.
 * @author batu-inal & HardlyDifficult
 */
abstract contract NFTDropMarketCore {
  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[1_000] private __gap;
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

import "../../interfaces/internal/INFTDropCollectionMint.sol";

import "../../libraries/OZERC165Checker.sol";
import "../shared/Constants.sol";
import "../shared/MarketFees.sol";

/// @param limitPerAccount The limit of tokens an account can purchase.
error NFTDropMarketFixedPriceSale_Cannot_Buy_More_Than_Limit(uint256 limitPerAccount);
error NFTDropMarketFixedPriceSale_Limit_Per_Account_Must_Be_Set();
error NFTDropMarketFixedPriceSale_Mint_Permission_Required();
error NFTDropMarketFixedPriceSale_Must_Buy_At_Least_One_Token();
error NFTDropMarketFixedPriceSale_Must_Have_Sale_In_Progress();
error NFTDropMarketFixedPriceSale_Must_Not_Be_Sold_Out();
error NFTDropMarketFixedPriceSale_Must_Not_Have_Pending_Sale();
error NFTDropMarketFixedPriceSale_Must_Support_Collection_Mint_Interface();
error NFTDropMarketFixedPriceSale_Must_Support_ERC721();
error NFTDropMarketFixedPriceSale_Only_Callable_By_Collection_Owner();
/// @param mintCost The total cost for this purchase.
error NFTDropMarketFixedPriceSale_Too_Much_Value_Provided(uint256 mintCost);
error NFTDropMarketFixedPriceSale_Mint_Count_Mismatch(uint256 targetBalance);

/**
 * @title Allows creators to list a drop collection for sale at a fixed price point.
 * @dev Listing a collection for sale in this market requires the collection to implement
 * the functions in `INFTDropCollectionMint` and to register that interface with ERC165.
 * Additionally the collection must implement access control, or more specifically:
 * `hasRole(bytes32(0), msg.sender)` must return true when called from the creator or admin's account
 * and `hasRole(keccak256("MINTER_ROLE", address(this)))` must return true for this market's address.
 * @author batu-inal & HardlyDifficult
 */
abstract contract NFTDropMarketFixedPriceSale is MarketFees {
  using AddressUpgradeable for address;
  using AddressUpgradeable for address payable;
  using ERC165Checker for address;
  using OZERC165Checker for address;

  /**
   * @notice Configuration for the terms of the sale.
   * @dev This structure is packed in order to consume just a single slot.
   */
  struct FixedPriceSaleConfig {
    /**
     * @notice The seller for the drop.
     */
    address payable seller;
    /**
     * @notice The fixed price per NFT in the collection.
     * @dev The maximum price that can be set on an NFT is ~1.2M (2^80/10^18) ETH.
     */
    uint80 price;
    /**
     * @notice The max number of NFTs an account may have while minting.
     */
    uint16 limitPerAccount;
  }

  /**
   * @notice Stores the current sale information for all drop contracts.
   */
  mapping(address => FixedPriceSaleConfig) private nftContractToFixedPriceSaleConfig;

  /**
   * @notice The `role` type used to validate drop collections have granted this market access to mint.
   * @return `keccak256("MINTER_ROLE")`
   */
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  /**
   * @notice Emitted when a collection is listed for sale.
   * @param nftContract The address of the NFT drop collection.
   * @param seller The address for the seller which listed this for sale.
   * @param price The price per NFT minted.
   * @param limitPerAccount The max number of NFTs an account may have while minting.
   */
  event CreateFixedPriceSale(
    address indexed nftContract,
    address indexed seller,
    uint256 price,
    uint256 limitPerAccount
  );

  /**
   * @notice Emitted when NFTs are minted from the drop.
   * @dev The total price paid by the buyer is `totalFees + creatorRev`.
   * @param nftContract The address of the NFT drop collection.
   * @param buyer The address of the buyer.
   * @param firstTokenId The tokenId for the first NFT minted.
   * The other minted tokens are assigned sequentially, so `firstTokenId` - `firstTokenId + count - 1` were minted.
   * @param count The number of NFTs minted.
   * @param totalFees The amount of ETH that was sent to Foundation & referrals for this sale.
   * @param creatorRev The amount of ETH that was sent to the creator for this sale.
   */
  event MintFromFixedPriceDrop(
    address indexed nftContract,
    address indexed buyer,
    uint256 indexed firstTokenId,
    uint256 count,
    uint256 totalFees,
    uint256 creatorRev
  );

  /**
   * @notice Create a fixed price sale drop.
   * @param nftContract The address of the NFT drop collection.
   * @param price The price per NFT minted.
   * Set price to 0 for a first come first serve airdrop-like drop.
   * @param limitPerAccount The max number of NFTs an account may have while minting.
   * @dev Notes:
   *   a) The sale is final and can not be updated or canceled.
   *   b) The sale is immediately kicked off.
   *   c) Any collection that abides by `INFTDropCollectionMint` and `IAccessControl` is supported.
   */
  /* solhint-disable-next-line code-complexity */
  function createFixedPriceSale(
    address nftContract,
    uint80 price,
    uint16 limitPerAccount
  ) external {
    // Confirm the drop collection is supported
    if (!nftContract.supportsInterface(type(INFTDropCollectionMint).interfaceId)) {
      revert NFTDropMarketFixedPriceSale_Must_Support_Collection_Mint_Interface();
    }
    // The check above already confirmed general 165 support
    if (!nftContract.supportsERC165InterfaceUnchecked(type(IERC721).interfaceId)) {
      revert NFTDropMarketFixedPriceSale_Must_Support_ERC721();
    }
    if (INFTDropCollectionMint(nftContract).numberOfTokensAvailableToMint() == 0) {
      revert NFTDropMarketFixedPriceSale_Must_Not_Be_Sold_Out();
    }

    // Use the AccessControl interface to confirm the msg.sender has permissions to list.
    if (!IAccessControl(nftContract).hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
      revert NFTDropMarketFixedPriceSale_Only_Callable_By_Collection_Owner();
    }
    // And that this contract has permission to mint.
    if (!IAccessControl(nftContract).hasRole(MINTER_ROLE, address(this))) {
      revert NFTDropMarketFixedPriceSale_Mint_Permission_Required();
    }

    // Validate input params.
    if (limitPerAccount == 0) {
      revert NFTDropMarketFixedPriceSale_Limit_Per_Account_Must_Be_Set();
    }
    // Any price is supported, including 0.

    // Confirm this collection has not already been listed.
    FixedPriceSaleConfig storage saleConfig = nftContractToFixedPriceSaleConfig[nftContract];
    if (saleConfig.seller != payable(0)) {
      revert NFTDropMarketFixedPriceSale_Must_Not_Have_Pending_Sale();
    }

    // Save the sale details.
    saleConfig.seller = payable(msg.sender);
    saleConfig.price = price;
    saleConfig.limitPerAccount = limitPerAccount;
    emit CreateFixedPriceSale(nftContract, msg.sender, price, limitPerAccount);
  }

  /**
   * @notice Used to mint `count` number of NFTs from the collection.
   * @param nftContract The address of the NFT drop collection.
   * @param count The number of NFTs to mint.
   * @param buyReferrer The address which referred this purchase, or address(0) if n/a.
   * @return firstTokenId The tokenId for the first NFT minted.
   * The other minted tokens are assigned sequentially, so `firstTokenId` - `firstTokenId + count - 1` were minted.
   * @dev This call may revert if the collection has sold out, has an insufficient number of tokens available,
   * or if the market's minter permissions were removed.
   * If insufficient msg.value is included, the msg.sender's available FETH token balance will be used.
   */
  function mintFromFixedPriceSale(
    address nftContract,
    uint16 count,
    address payable buyReferrer
  ) external payable returns (uint256 firstTokenId) {
    // Validate input params.
    if (count == 0) {
      revert NFTDropMarketFixedPriceSale_Must_Buy_At_Least_One_Token();
    }

    FixedPriceSaleConfig memory saleConfig = nftContractToFixedPriceSaleConfig[nftContract];

    // Confirm that the buyer will not exceed the limit specified after minting.
    uint256 targetBalance = IERC721(nftContract).balanceOf(msg.sender) + count;
    if (targetBalance > saleConfig.limitPerAccount) {
      if (saleConfig.limitPerAccount == 0) {
        // Provide a more targeted error if the collection has not been listed.
        revert NFTDropMarketFixedPriceSale_Must_Have_Sale_In_Progress();
      }
      revert NFTDropMarketFixedPriceSale_Cannot_Buy_More_Than_Limit(saleConfig.limitPerAccount);
    }

    // Calculate the total cost, considering the `count` requested.
    uint256 mintCost;
    unchecked {
      // Can not overflow as 2^80 * 2^16 == 2^96 max which fits in 256 bits.
      mintCost = uint256(saleConfig.price) * count;
    }

    // The sale price is immutable so the buyer is aware of how much they will be paying when their tx is broadcasted.
    if (msg.value > mintCost) {
      // Since price is known ahead of time, if too much ETH is sent then something went wrong.
      revert NFTDropMarketFixedPriceSale_Too_Much_Value_Provided(mintCost);
    }
    // Withdraw from the user's available FETH balance if insufficient msg.value was included.
    _tryUseFETHBalance(mintCost, false);

    // Mint the NFTs.
    firstTokenId = INFTDropCollectionMint(nftContract).mintCountTo(count, msg.sender);

    if (IERC721(nftContract).balanceOf(msg.sender) != targetBalance) {
      revert NFTDropMarketFixedPriceSale_Mint_Count_Mismatch(targetBalance);
    }

    // Distribute revenue from this sale.
    (uint256 totalFees, uint256 creatorRev, ) = _distributeFunds(
      nftContract,
      firstTokenId,
      saleConfig.seller,
      mintCost,
      buyReferrer
    );

    emit MintFromFixedPriceDrop(nftContract, msg.sender, firstTokenId, count, totalFees, creatorRev);
  }

  /**
   * @notice Returns the max number of NFTs a given account may mint.
   * @param nftContract The address of the NFT drop collection.
   * @param user The address of the user which will be minting.
   * @return numberThatCanBeMinted How many NFTs the user can mint.
   */
  function getAvailableCountFromFixedPriceSale(address nftContract, address user)
    external
    view
    returns (uint256 numberThatCanBeMinted)
  {
    (, , uint256 limitPerAccount, uint256 numberOfTokensAvailableToMint, bool marketCanMint) = getFixedPriceSale(
      nftContract
    );
    if (!marketCanMint) {
      // No one can mint in the current state.
      return 0;
    }
    uint256 currentBalance = IERC721(nftContract).balanceOf(user);
    if (currentBalance >= limitPerAccount) {
      // User has exhausted their limit.
      return 0;
    }

    unchecked {
      numberThatCanBeMinted = limitPerAccount - currentBalance;
    }
    if (numberThatCanBeMinted > numberOfTokensAvailableToMint) {
      // User has more tokens available than the collection has available.
      numberThatCanBeMinted = numberOfTokensAvailableToMint;
    }
  }

  /**
   * @notice Returns details for a drop collection's fixed price sale.
   * @param nftContract The address of the NFT drop collection.
   * @return seller The address of the seller which listed this drop for sale.
   * This value will be address(0) if the collection is not listed or has sold out.
   * @return price The price per NFT minted.
   * @return limitPerAccount The max number of NFTs an account may have while minting.
   * @return numberOfTokensAvailableToMint The total number of NFTs that may still be minted.
   * @return marketCanMint True if this contract has permissions to mint from the given collection.
   */
  function getFixedPriceSale(address nftContract)
    public
    view
    returns (
      address payable seller,
      uint256 price,
      uint256 limitPerAccount,
      uint256 numberOfTokensAvailableToMint,
      bool marketCanMint
    )
  {
    try INFTDropCollectionMint(nftContract).numberOfTokensAvailableToMint() returns (uint256 count) {
      if (count != 0) {
        try IAccessControl(nftContract).hasRole(MINTER_ROLE, address(this)) returns (bool hasRole) {
          marketCanMint = hasRole;
        } catch {
          // The contract is not supported - return default values.
          return (payable(0), 0, 0, 0, false);
        }

        FixedPriceSaleConfig memory saleConfig = nftContractToFixedPriceSaleConfig[nftContract];
        seller = saleConfig.seller;
        price = saleConfig.price;
        limitPerAccount = saleConfig.limitPerAccount;
        numberOfTokensAvailableToMint = count;
      }
      // Else minted completed -- return default values.
    } catch // solhint-disable-next-line no-empty-blocks
    {
      // Contract not supported or self destructed - return default values
    }
  }

  /**
   * @inheritdoc MarketSharedCore
   * @dev Returns the seller for a collection if listed and not already sold out.
   */
  function _getSellerOf(
    address nftContract,
    uint256 /* tokenId */
  ) internal view virtual override returns (address payable seller) {
    (seller, , , , ) = getFixedPriceSale(nftContract);
  }

  /**
   * @notice This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint256[1_000] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @title Helper functions for arrays.
 * @author batu-inal & HardlyDifficult
 */
library ArrayLibrary {
  /**
   * @notice Reduces the size of an array if it's greater than the specified max size,
   * using the first maxSize elements.
   */
  function capLength(address payable[] memory data, uint256 maxLength) internal pure {
    if (data.length > maxLength) {
      assembly {
        mstore(data, maxLength)
      }
    }
  }

  /**
   * @notice Reduces the size of an array if it's greater than the specified max size,
   * using the first maxSize elements.
   */
  function capLength(uint256[] memory data, uint256 maxLength) internal pure {
    if (data.length > maxLength) {
      assembly {
        mstore(data, maxLength)
      }
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

/**
 * From https://github.com/OpenZeppelin/openzeppelin-contracts
 * Copying the method below which is currently unreleased.
 */

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title Library to query ERC165 support.
 * @dev Library used to query support of an interface declared via {IERC165}.
 *
 * Note that these functions return the actual result of the query: they do not
 * `revert` if an interface is not supported. It is up to the caller to decide
 * what to do in these cases.
 */
library OZERC165Checker {
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
  function supportsERC165InterfaceUnchecked(address account, bytes4 interfaceId) internal view returns (bool) {
    bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
    (bool success, bytes memory result) = account.staticcall{ gas: 30_000 }(encodedParams);
    if (result.length < 32) return false;
    return success && abi.decode(result, (uint256)) > 0;
  }
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/// Constant values shared across mixins.

/**
 * @dev 100% in basis points.
 */
uint256 constant BASIS_POINTS = 10_000;

/**
 * @dev The default admin role defined by OZ ACL modules.
 */
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/**
 * @dev Cap the number of royalty recipients.
 * A cap is required to ensure gas costs are not too high when a sale is settled.
 */
uint256 constant MAX_ROYALTY_RECIPIENTS = 5;

/**
 * @dev The minimum increase of 10% required when making an offer or placing a bid.
 */
uint256 constant MIN_PERCENT_INCREMENT_DENOMINATOR = BASIS_POINTS / 1_000;

/**
 * @dev The gas limit used when making external read-only calls.
 * This helps to ensure that external calls does not prevent the market from executing.
 */
uint256 constant READ_ONLY_GAS_LIMIT = 40_000;

/**
 * @dev Default royalty cut paid out on secondary sales.
 * Set to 10% of the secondary sale.
 */
uint96 constant ROYALTY_IN_BASIS_POINTS = 1_000;

/**
 * @dev 10%, expressed as a denominator for more efficient calculations.
 */
uint256 constant ROYALTY_RATIO = BASIS_POINTS / ROYALTY_IN_BASIS_POINTS;

/**
 * @dev The gas limit to send ETH to multiple recipients, enough for a 5-way split.
 */
uint256 constant SEND_VALUE_GAS_LIMIT_MULTIPLE_RECIPIENTS = 210_000;

/**
 * @dev The gas limit to send ETH to a single recipient, enough for a contract with a simple receiver.
 */
uint256 constant SEND_VALUE_GAS_LIMIT_SINGLE_RECIPIENT = 20_000;

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice An interface for communicating fees to 3rd party marketplaces.
 * @dev Originally implemented in mainnet contract 0x44d6e8933f8271abcf253c72f9ed7e0e4c0323b3
 */
interface IGetFees {
  /**
   * @notice Get the recipient addresses to which creator royalties should be sent.
   * @dev The expected royalty amounts are communicated with `getFeeBps`.
   * @param tokenId The ID of the NFT to get royalties for.
   * @return recipients An array of addresses to which royalties should be sent.
   */
  function getFeeRecipients(uint256 tokenId) external view returns (address payable[] memory recipients);

  /**
   * @notice Get the creator royalty amounts to be sent to each recipient, in basis points.
   * @dev The expected recipients are communicated with `getFeeRecipients`.
   * @param tokenId The ID of the NFT to get royalties for.
   * @return royaltiesInBasisPoints The array of fees to be sent to each recipient, in basis points.
   */
  function getFeeBps(uint256 tokenId) external view returns (uint256[] memory royaltiesInBasisPoints);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.12;

interface IOwnable {
  /**
   * @dev Returns the address of the current owner.
   */
  function owner() external view returns (address);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

interface IGetRoyalties {
  /**
   * @notice Get the creator royalties to be sent.
   * @dev The data is the same as when calling `getFeeRecipients` and `getFeeBps` separately.
   * @param tokenId The ID of the NFT to get royalties for.
   * @return recipients An array of addresses to which royalties should be sent.
   * @return royaltiesInBasisPoints The array of fees to be sent to each recipient, in basis points.
   */
  function getRoyalties(uint256 tokenId)
    external
    view
    returns (address payable[] memory recipients, uint256[] memory royaltiesInBasisPoints);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice Interface for EIP-2981: NFT Royalty Standard.
 * For more see: https://eips.ethereum.org/EIPS/eip-2981.
 */
interface IRoyaltyInfo {
  /**
   * @notice Get the creator royalties to be sent.
   * @param tokenId The ID of the NFT to get royalties for.
   * @param salePrice The total price of the sale.
   * @return receiver The address to which royalties should be sent.
   * @return royaltyAmount The total amount that should be sent to the `receiver`.
   */
  function royaltyInfo(uint256 tokenId, uint256 salePrice)
    external
    view
    returns (address receiver, uint256 royaltyAmount);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

interface ITokenCreator {
  /**
   * @notice Returns the creator of this NFT collection.
   * @param tokenId The ID of the NFT to get the creator payment address for.
   * @return creator The creator of this collection.
   */
  function tokenCreator(uint256 tokenId) external view returns (address payable creator);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
                /// @solidity memory-safe-assembly
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

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @dev Royalty registry interface
 */
interface IRoyaltyRegistry is IERC165 {

     event RoyaltyOverride(address owner, address tokenAddress, address royaltyAddress);

    /**
     * Override the location of where to look up royalty information for a given token contract.
     * Allows for backwards compatibility and implementation of royalty logic for contracts that did not previously support them.
     * 
     * @param tokenAddress    - The token address you wish to override
     * @param royaltyAddress  - The royalty override address
     */
    function setRoyaltyLookupAddress(address tokenAddress, address royaltyAddress) external;

    /**
     * Returns royalty address location.  Returns the tokenAddress by default, or the override if it exists
     *
     * @param tokenAddress    - The token address you are looking up the royalty for
     */
    function getRoyaltyLookupAddress(address tokenAddress) external view returns(address);

    /**
     * Whether or not the message sender can override the royalty address for the given token address
     *
     * @param tokenAddress    - The token address you are looking up the royalty for
     */
    function overrideAllowed(address tokenAddress) external view returns(bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.2) (utils/introspection/ERC165Checker.sol)

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
        // prepare call
        bytes memory encodedParams = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);

        // perform static call
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly {
            success := staticcall(30000, account, add(encodedParams, 0x20), mload(encodedParams), 0x00, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0x00)
        }

        return success && returnSize >= 0x20 && returnValue > 0;
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

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice Interface for OperatorRole which wraps a role from
 * OpenZeppelin's AccessControl for easy integration.
 * @author batu-inal & HardlyDifficult
 */
interface IOperatorRole {
  function isOperator(address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice Interface for AdminRole which wraps the default admin role from
 * OpenZeppelin's AccessControl for easy integration.
 * @author batu-inal & HardlyDifficult
 */
interface IAdminRole {
  function isAdmin(address account) external view returns (bool);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice Interface for functions the market uses in FETH.
 * @author batu-inal & HardlyDifficult
 */
interface IFethMarket {
  function depositFor(address account) external payable;

  function marketLockupFor(address account, uint256 amount) external payable returns (uint256 expiration);

  function marketWithdrawFrom(address from, uint256 amount) external;

  function marketWithdrawLocked(
    address account,
    uint256 expiration,
    uint256 amount
  ) external;

  function marketUnlockFor(
    address account,
    uint256 expiration,
    uint256 amount
  ) external;

  function marketChangeLockup(
    address unlockFrom,
    uint256 unlockExpiration,
    uint256 unlockAmount,
    address lockupFor,
    uint256 lockupAmount
  ) external payable returns (uint256 expiration);
}

// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.12;

/**
 * @notice The required interface for collections to support the NFTDropMarket.
 * @dev This interface must be registered as a ERC165 supported interface to support the NFTDropMarket.
 * @author batu-inal & HardlyDifficult
 */
interface INFTDropCollectionMint {
  function mintCountTo(uint16 count, address to) external returns (uint256 firstTokenId);

  function numberOfTokensAvailableToMint() external view returns (uint256 count);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../contracts/NFTDropMarket.sol";

contract $NFTDropMarket is NFTDropMarket {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    event $_distributeFunds_Returned(uint256 arg0, uint256 arg1, uint256 arg2);

    constructor(address payable treasury, address feth, address royaltyRegistry) NFTDropMarket(treasury, feth, royaltyRegistry) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_getSellerOf(address nftContract,uint256 tokenId) external view returns (address payable) {
        return super._getSellerOf(nftContract,tokenId);
    }

    function $_getSellerOrOwnerOf(address nftContract,uint256 tokenId) external view returns (address payable) {
        return super._getSellerOrOwnerOf(nftContract,tokenId);
    }

    function $_distributeFunds(address nftContract,uint256 tokenId,address payable seller,uint256 price,address payable buyReferrer) external returns (uint256, uint256, uint256) {
        (uint256 ret0, uint256 ret1, uint256 ret2) = super._distributeFunds(nftContract,tokenId,seller,price,buyReferrer);
        emit $_distributeFunds_Returned(ret0, ret1, ret2);
        return (ret0, ret1, ret2);
    }

    function $_sendValueWithFallbackWithdraw(address payable user,uint256 amount,uint256 gasLimit) external {
        return super._sendValueWithFallbackWithdraw(user,amount,gasLimit);
    }

    function $__ReentrancyGuard_init() external {
        return super.__ReentrancyGuard_init();
    }

    function $__ReentrancyGuard_init_unchained() external {
        return super.__ReentrancyGuard_init_unchained();
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }

    function $_disableInitializers() external {
        return super._disableInitializers();
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/interfaces/internal/IFethMarket.sol";

abstract contract $IFethMarket is IFethMarket {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/interfaces/internal/INFTDropCollectionMint.sol";

abstract contract $INFTDropCollectionMint is INFTDropCollectionMint {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/internal/roles/IAdminRole.sol";

abstract contract $IAdminRole is IAdminRole {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/internal/roles/IOperatorRole.sol";

abstract contract $IOperatorRole is IOperatorRole {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/standards/royalties/IGetFees.sol";

abstract contract $IGetFees is IGetFees {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/standards/royalties/IGetRoyalties.sol";

abstract contract $IGetRoyalties is IGetRoyalties {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/standards/royalties/IOwnable.sol";

abstract contract $IOwnable is IOwnable {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/standards/royalties/IRoyaltyInfo.sol";

abstract contract $IRoyaltyInfo is IRoyaltyInfo {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../../contracts/interfaces/standards/royalties/ITokenCreator.sol";

abstract contract $ITokenCreator is ITokenCreator {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../contracts/libraries/ArrayLibrary.sol";

contract $ArrayLibrary {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    function $capLength(address payable[] calldata data,uint256 maxLength) external pure {
        return ArrayLibrary.capLength(data,maxLength);
    }

    function $capLength(uint256[] calldata data,uint256 maxLength) external pure {
        return ArrayLibrary.capLength(data,maxLength);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../contracts/libraries/OZERC165Checker.sol";

contract $OZERC165Checker {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    function $supportsERC165InterfaceUnchecked(address account,bytes4 interfaceId) external view returns (bool) {
        return OZERC165Checker.supportsERC165InterfaceUnchecked(account,interfaceId);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/nftDropMarket/NFTDropMarketCore.sol";

contract $NFTDropMarketCore is NFTDropMarketCore {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/nftDropMarket/NFTDropMarketFixedPriceSale.sol";

abstract contract $NFTDropMarketFixedPriceSale is NFTDropMarketFixedPriceSale {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    event $_distributeFunds_Returned(uint256 arg0, uint256 arg1, uint256 arg2);

    constructor(address payable _treasury, address _feth, uint16 protocolFeeInBasisPoints, address _royaltyRegistry, bool _assumePrimarySale) FoundationTreasuryNode(_treasury) FETHNode(_feth) MarketFees(protocolFeeInBasisPoints, _royaltyRegistry, _assumePrimarySale) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_getSellerOf(address nftContract,uint256 arg1) external view returns (address payable) {
        return super._getSellerOf(nftContract,arg1);
    }

    function $_distributeFunds(address nftContract,uint256 tokenId,address payable seller,uint256 price,address payable buyReferrer) external returns (uint256, uint256, uint256) {
        (uint256 ret0, uint256 ret1, uint256 ret2) = super._distributeFunds(nftContract,tokenId,seller,price,buyReferrer);
        emit $_distributeFunds_Returned(ret0, ret1, ret2);
        return (ret0, ret1, ret2);
    }

    function $_sendValueWithFallbackWithdraw(address payable user,uint256 amount,uint256 gasLimit) external {
        return super._sendValueWithFallbackWithdraw(user,amount,gasLimit);
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/Constants.sol";

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/FETHNode.sol";

contract $FETHNode is FETHNode {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor(address _feth) FETHNode(_feth) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/FoundationTreasuryNode.sol";

contract $FoundationTreasuryNode is FoundationTreasuryNode {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor(address payable _treasury) FoundationTreasuryNode(_treasury) {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/Gap10000.sol";

contract $Gap10000 is Gap10000 {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor() {}

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/MarketFees.sol";

abstract contract $MarketFees is MarketFees {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    event $_distributeFunds_Returned(uint256 arg0, uint256 arg1, uint256 arg2);

    constructor(address payable _treasury, address _feth, uint16 protocolFeeInBasisPoints, address _royaltyRegistry, bool _assumePrimarySale) FoundationTreasuryNode(_treasury) FETHNode(_feth) MarketFees(protocolFeeInBasisPoints, _royaltyRegistry, _assumePrimarySale) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_distributeFunds(address nftContract,uint256 tokenId,address payable seller,uint256 price,address payable buyReferrer) external returns (uint256, uint256, uint256) {
        (uint256 ret0, uint256 ret1, uint256 ret2) = super._distributeFunds(nftContract,tokenId,seller,price,buyReferrer);
        emit $_distributeFunds_Returned(ret0, ret1, ret2);
        return (ret0, ret1, ret2);
    }

    function $_sendValueWithFallbackWithdraw(address payable user,uint256 amount,uint256 gasLimit) external {
        return super._sendValueWithFallbackWithdraw(user,amount,gasLimit);
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/MarketSharedCore.sol";

abstract contract $MarketSharedCore is MarketSharedCore {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor(address _feth) FETHNode(_feth) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.6.0;

import "../../../contracts/mixins/shared/SendValueWithFallbackWithdraw.sol";

contract $SendValueWithFallbackWithdraw is SendValueWithFallbackWithdraw {
    bytes32 public __hh_exposed_bytecode_marker = "hardhat-exposed";

    constructor(address _feth) FETHNode(_feth) {}

    function $feth() external view returns (IFethMarket) {
        return feth;
    }

    function $_sendValueWithFallbackWithdraw(address payable user,uint256 amount,uint256 gasLimit) external {
        return super._sendValueWithFallbackWithdraw(user,amount,gasLimit);
    }

    function $_tryUseFETHBalance(uint256 totalAmount,bool shouldRefundSurplus) external {
        return super._tryUseFETHBalance(totalAmount,shouldRefundSurplus);
    }
}