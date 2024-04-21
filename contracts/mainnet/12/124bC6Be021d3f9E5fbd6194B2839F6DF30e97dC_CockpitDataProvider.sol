/**
 *Submitted for verification at Etherscan.io on 2022-11-05
*/

// SPDX-License-Identifier: BUSL-1.1
// File: contracts/libraries/errors/IporErrors.sol


pragma solidity 0.8.15;

library IporErrors {
    // 000-199 - general codes

    /// @notice General problem, address is wrong
    string public constant WRONG_ADDRESS = "IPOR_000";

    /// @notice General problem. Wrong decimals
    string public constant WRONG_DECIMALS = "IPOR_001";

    string public constant ADDRESSES_MISMATCH = "IPOR_002";

    //@notice Trader doesnt have enought tokens to execute transaction
    string public constant ASSET_BALANCE_TOO_LOW = "IPOR_003";

    string public constant VALUE_NOT_GREATER_THAN_ZERO = "IPOR_004";

    string public constant INPUT_ARRAYS_LENGTH_MISMATCH = "IPOR_005";

    //@notice Amount is too low to transfer
    string public constant NOT_ENOUGH_AMOUNT_TO_TRANSFER = "IPOR_006";

    //@notice msg.sender is not an appointed owner, so cannot confirm his appointment to be an owner of a specific smart contract
    string public constant SENDER_NOT_APPOINTED_OWNER = "IPOR_007";

    //only milton can have access to function
    string public constant CALLER_NOT_MILTON = "IPOR_008";

    string public constant CHUNK_SIZE_EQUAL_ZERO = "IPOR_009";

    string public constant CHUNK_SIZE_TOO_BIG = "IPOR_010";
}

// File: contracts/interfaces/types/MiltonStorageTypes.sol


pragma solidity 0.8.15;

/// @title Types used in MiltonStorage smart contract
library MiltonStorageTypes {
    /// @notice struct representing swap's ID and direction
    /// @dev direction = 0 - Pay Fixed - Receive Floating, direction = 1 - Receive Fixed - Pay Floating
    struct IporSwapId {
        /// @notice Swap ID
        uint256 id;
        /// @notice Swap direction, 0 - Pay Fixed Receive Floating, 1 - Receive Fixed Pay Floating
        uint8 direction;
    }

    /// @notice Struct containing extended balance information.
    /// @dev extended information includes: opening fee balance, liquidation deposit balance,
    /// IPOR publication fee balance, treasury balance, all balances are in 18 decimals
    struct ExtendedBalancesMemory {
        /// @notice Swap's balance for Pay Fixed leg
        uint256 totalCollateralPayFixed;
        /// @notice Swap's balance for Receive Fixed leg
        uint256 totalCollateralReceiveFixed;
        /// @notice Liquidity Pool's Balance
        uint256 liquidityPool;
        /// @notice Stanley's (Asset Management) balance
        uint256 vault;
        /// @notice IPOR publication fee balance. This balance is used to subsidise the oracle operations
        uint256 iporPublicationFee;
        /// @notice Balance of the DAO's treasury. Fed by portion of the opening and income fees set by the DAO
        uint256 treasury;
    }
}

// File: contracts/interfaces/types/AmmTypes.sol


pragma solidity 0.8.15;

/// @title Types used in interfaces strictly related to AMM (Automated Market Maker).
/// @dev Used by IMilton and IMiltonStorage interfaces.
library AmmTypes {
    /// @notice enum describing Swap's state, ACTIVE - when the swap is opened, INACTIVE when it's closed
    enum SwapState {
        INACTIVE,
        ACTIVE
    }

    /// @notice Structure which represents Swap's data that will be saved in the storage.
    /// Refer to the documentation https://ipor-labs.gitbook.io/ipor-labs/automated-market-maker/ipor-swaps for more information.
    struct NewSwap {
        /// @notice Account / trader who opens the Swap
        address buyer;
        /// @notice Epoch timestamp of when position was opened by the trader.
        uint256 openTimestamp;
        /// @notice Swap's collateral amount.
        /// @dev value represented in 18 decimals
        uint256 collateral;
        /// @notice Swap's notional amount.
        /// @dev value represented in 18 decimals
        uint256 notional;
        /// @notice Quantity of Interest Bearing Token (IBT) at moment when position was opened.
        /// @dev value represented in 18 decimals
        uint256 ibtQuantity;
        /// @notice Fixed interest rate at which the position has been opened.
        /// @dev value represented in 18 decimals
        uint256 fixedInterestRate;
        /// @notice Liquidation deposit is retained when the swap is opened. It is then paid back to agent who closes the derivative at maturity.
        /// It can be both trader or community member. Trader receives the deposit back when he chooses to close the derivative before maturity.
        /// @dev value represented in 18 decimals
        uint256 liquidationDepositAmount;
        /// @notice Opening fee amount part which is allocated in Liquidity Pool Balance. This fee is calculated as a rate of the swap's collateral.
        /// @dev value represented in 18 decimals
        uint256 openingFeeLPAmount;
        /// @notice Opening fee amount part which is allocated in Treasury Balance. This fee is calculated as a rate of the swap's collateral.
        /// @dev value represented in 18 decimals
        uint256 openingFeeTreasuryAmount;
    }

    /// @notice Struct representing assets (ie. stablecoin) related to Swap that is presently being opened.
    /// @dev all values represented in 18 decimals
    struct OpenSwapMoney {
        /// @notice Total Amount of asset that is sent from buyer to Milton when opening swap.
        uint256 totalAmount;
        /// @notice Swap's collateral
        uint256 collateral;
        /// @notice Swap's notional
        uint256 notional;
        /// @notice Opening Fee - part allocated as a profit of the Liquidity Pool
        uint256 openingFeeLPAmount;
        /// @notice  Part of the fee set aside for subsidizing the oracle that publishes IPOR rate. Flat fee set by the DAO.
        /// @notice Opening Fee - part allocated in Treasury balance. Part of the fee set asside for subsidising the oracle that publishes IPOR rate. Flat fee set by the DAO.
        uint256 openingFeeTreasuryAmount;
        /// @notice Fee set aside for subsidizing the oracle that publishes IPOR rate. Flat fee set by the DAO.
        uint256 iporPublicationFee;
        /// @notice Liquidation deposit is retained when the swap is opened. Value represented in 18 decimals.
        uint256 liquidationDepositAmount;
    }
}

// File: contracts/interfaces/types/IporTypes.sol


pragma solidity 0.8.15;

/// @title Struct used across various interfaces in IPOR Protocol.
library IporTypes {
    /// @notice The struct describing the IPOR and its params calculated for the time when it was most recently updated and the change that took place since the update.
    /// Namely, the interest that would be computed into IBT should the rebalance occur.
    struct AccruedIpor {
        /// @notice IPOR Index Value
        /// @dev value represented in 18 decimals
        uint256 indexValue;
        /// @notice IBT Price (IBT - Interest Bearing Token). For more information reffer to the documentation:
        /// https://ipor-labs.gitbook.io/ipor-labs/interest-rate-derivatives/ibt
        /// @dev value represented in 18 decimals
        uint256 ibtPrice;
        /// @notice Exponential Moving Average
        /// @dev value represented in 18 decimals
        uint256 exponentialMovingAverage;
        /// @notice Exponential Weighted Moving Variance
        /// @dev value represented in 18 decimals
        uint256 exponentialWeightedMovingVariance;
    }

    /// @notice Struct representing swap item, used for listing and in internal calculations
    struct IporSwapMemory {
        /// @notice Swap's unique ID
        uint256 id;
        /// @notice Swap's buyer
        address buyer;
        /// @notice Swap opening epoch timestamp
        uint256 openTimestamp;
        /// @notice Epoch when the swap will reach its maturity
        uint256 endTimestamp;
        /// @notice Index position of this Swap in an array of swaps' identification associated to swap buyer
        /// @dev Field used for gas optimization purposes, it allows for quick removal by id in the array.
        /// During removal the last item in the array is switched with the one that just has been removed.
        uint256 idsIndex;
        /// @notice Swap's collateral
        /// @dev value represented in 18 decimals
        uint256 collateral;
        /// @notice Swap's notional amount
        /// @dev value represented in 18 decimals
        uint256 notional;
        /// @notice Swap's notional amount denominated in the Interest Bearing Token (IBT)
        /// @dev value represented in 18 decimals
        uint256 ibtQuantity;
        /// @notice Fixed interest rate at which the position has been opened
        /// @dev value represented in 18 decimals
        uint256 fixedInterestRate;
        /// @notice Liquidation deposit amount
        /// @dev value represented in 18 decimals
        uint256 liquidationDepositAmount;
        /// @notice State of the swap
        /// @dev 0 - INACTIVE, 1 - ACTIVE
        uint256 state;
    }

    /// @notice Struct representing balances used internally for asset calculations
    /// @dev all balances in 18 decimals
    struct MiltonBalancesMemory {
        /// @notice Sum of all collateral put forward by the derivative buyer's on  Pay Fixed & Receive Floating leg.
        uint256 totalCollateralPayFixed;
        /// @notice Sum of all collateral put forward by the derivative buyer's on  Pay Floating & Receive Fixed leg.
        uint256 totalCollateralReceiveFixed;
        /// @notice Liquidity Pool Balance. This balance is where the liquidity from liquidity providers and the opening fee are accounted for,
        /// @dev Amount of opening fee accounted in this balance is defined by _OPENING_FEE_FOR_TREASURY_PORTION_RATE param.
        uint256 liquidityPool;
        /// @notice Vault's balance, describes how much asset has been transfered to Asset Management Vault (Stanley)
        uint256 vault;
    }
}

// File: contracts/interfaces/IMiltonStorage.sol


pragma solidity 0.8.15;




/// @title Interface for interaction with Milton Storage smart contract, reposnsible for managing AMM storage.
interface IMiltonStorage {
    /// @notice Returns current version of Milton Storage
    /// @return current Milton Storage version, integer.
    function getVersion() external pure returns (uint256);

    /// @notice Gets last swap ID.
    /// @dev swap ID is incremented when new position is opened, last swap ID is used in Pay Fixed and Receive Fixed swaps.
    /// @return last swap ID, integer
    function getLastSwapId() external view returns (uint256);

    /// @notice Gets balance struct
    /// @dev Balance contains:
    /// # Pay Fixed Total Collateral
    /// # Receive Fixed Total Collateral
    /// # Liquidity Pool and Vault balances.
    /// @return balance structure {IporTypes.MiltonBalancesMemory}
    function getBalance() external view returns (IporTypes.MiltonBalancesMemory memory);

    /// @notice Gets balance with extended information: IPOR publication fee balance and Treasury balance.
    /// @return balance structure {MiltonStorageTypes.ExtendedBalancesMemory}
    function getExtendedBalance()
        external
        view
        returns (MiltonStorageTypes.ExtendedBalancesMemory memory);

    /// @notice Gets total outstanding notional.
    /// @return totalNotionalPayFixed Sum of notional amount of all swaps for Pay-Fixed leg, represented in 18 decimals
    /// @return totalNotionalReceiveFixed Sum of notional amount of all swaps for Receive-Fixed leg, represented in 18 decimals
    function getTotalOutstandingNotional()
        external
        view
        returns (uint256 totalNotionalPayFixed, uint256 totalNotionalReceiveFixed);

    /// @notice Gets Pay-Fixed swap for a given swap ID
    /// @param swapId swap ID.
    /// @return swap structure {IporTypes.IporSwapMemory}
    function getSwapPayFixed(uint256 swapId)
        external
        view
        returns (IporTypes.IporSwapMemory memory);

    /// @notice Gets Receive-Fixed swap for a given swap ID
    /// @param swapId swap ID.
    /// @return swap structure {IporTypes.IporSwapMemory}
    function getSwapReceiveFixed(uint256 swapId)
        external
        view
        returns (IporTypes.IporSwapMemory memory);

    /// @notice Gets active Pay-Fixed swaps for a given account address.
    /// @param account account address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Pay-Fixed swaps
    /// @return swaps array where each element has structure {IporTypes.IporSwapMemory}
    function getSwapsPayFixed(
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Gets active Receive-Fixed swaps for a given account address.
    /// @param account account address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Receive Fixed swaps
    /// @return swaps array where each element has structure {IporTypes.IporSwapMemory}
    function getSwapsReceiveFixed(
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Gets active Pay-Fixed swaps IDs for a given account address.
    /// @param account account address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Pay-Fixed IDs
    /// @return ids list of IDs
    function getSwapPayFixedIds(
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, uint256[] memory ids);

    /// @notice Gets active Receive-Fixed swaps IDs for a given account address.
    /// @param account account address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Receive-Fixed IDs
    /// @return ids list of IDs
    function getSwapReceiveFixedIds(
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, uint256[] memory ids);

    /// @notice Gets active Pay-Fixed and Receive-Fixed swaps IDs for a given account address.
    /// @param account account address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Pay-Fixed and Receive-Fixed IDs.
    /// @return ids array where each element has structure {MiltonStorageTypes.IporSwapId}
    function getSwapIds(
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, MiltonStorageTypes.IporSwapId[] memory ids);

    /// @notice Calculates SOAP for a given IBT price and timestamp. For more information refer to the documentation: https://ipor-labs.gitbook.io/ipor-labs/automated-market-maker/soap
    /// @param ibtPrice IBT (Interest Bearing Token) price
    /// @param calculateTimestamp epoch timestamp, the time for which SOAP is calculated
    /// @return soapPayFixed SOAP for Pay-Fixed and Receive-Floating leg, represented in 18 decimals
    /// @return soapReceiveFixed SOAP for Receive-Fixed and Pay-Floating leg, represented in 18 decimals
    /// @return soap Sum of SOAP for Pay-Fixed leg and Receive-Fixed leg , represented in 18 decimals
    function calculateSoap(uint256 ibtPrice, uint256 calculateTimestamp)
        external
        view
        returns (
            int256 soapPayFixed,
            int256 soapReceiveFixed,
            int256 soap
        );

    /// @notice Calculates SOAP for Pay-Fixed leg at given IBT price and time.
    /// @param ibtPrice IBT (Interest Bearing Token) price
    /// @param calculateTimestamp epoch timestamp, the time for which SOAP is calculated
    /// @return soapPayFixed SOAP for Pay-Fixed leg, represented in 18 decimals
    function calculateSoapPayFixed(uint256 ibtPrice, uint256 calculateTimestamp)
        external
        view
        returns (int256 soapPayFixed);

    /// @notice Calculates SOAP for Receive-Fixed leg at given IBT price and time.
    /// @param ibtPrice IBT (Interest Bearing Token) price
    /// @param calculateTimestamp epoch timestamp, the time for which SOAP is calculated
    /// @return soapReceiveFixed SOAP for Receive-Fixed leg, represented in 18 decimals
    function calculateSoapReceiveFixed(uint256 ibtPrice, uint256 calculateTimestamp)
        external
        view
        returns (int256 soapReceiveFixed);

    /// @notice add liquidity to the Liquidity Pool. Function available only to Joseph.
    /// @param account account address who execute request for redeem asset amount
    /// @param assetAmount amount of asset added to balance of Liquidity Pool, represented in 18 decimals
    /// @param cfgMaxLiquidityPoolBalance max liquidity pool balance taken from Joseph configuration, represented in 18 decimals.
    /// @param cfgMaxLpAccountContribution max liquidity pool account contribution taken from Joseph configuration, represented in 18 decimals.
    function addLiquidity(
        address account,
        uint256 assetAmount,
        uint256 cfgMaxLiquidityPoolBalance,
        uint256 cfgMaxLpAccountContribution
    ) external;

    /// @notice subtract liquidity from the Liquidity Pool. Function available only to Joseph.
    /// @param assetAmount amount of asset subtracted from Liquidity Pool, represented in 18 decimals
    function subtractLiquidity(uint256 assetAmount) external;

    /// @notice Updates structures in storage: balance, swaps, SOAP indicators when new Pay-Fixed swap is opened. Function available only to Milton.
    /// @param newSwap new swap structure {AmmTypes.NewSwap}
    /// @param cfgIporPublicationFee publication fee amount taken from Milton configuration, represented in 18 decimals.
    /// @return new swap ID
    function updateStorageWhenOpenSwapPayFixed(
        AmmTypes.NewSwap memory newSwap,
        uint256 cfgIporPublicationFee
    ) external returns (uint256);

    /// @notice Updates structures in the storage: balance, swaps, SOAP indicators when new Receive-Fixed swap is opened. Function is only available to Milton.
    /// @param newSwap new swap structure {AmmTypes.NewSwap}
    /// @param cfgIporPublicationFee publication fee amount taken from Milton configuration, represented in 18 decimals.
    /// @return new swap ID
    function updateStorageWhenOpenSwapReceiveFixed(
        AmmTypes.NewSwap memory newSwap,
        uint256 cfgIporPublicationFee
    ) external returns (uint256);

    /// @notice Updates structures in the storage: balance, swaps, SOAP indicators when closing Pay-Fixed swap. Function is only available to Milton.
    /// @param liquidator account address that closes the swap
    /// @param iporSwap swap structure {IporTypes.IporSwapMemory}
    /// @param payoff amount that trader has earned or lost on the swap, represented in 18 decimals, it can be negative.
    /// @param closingTimestamp moment when the swap was closed
    /// @param cfgIncomeFeeRate income fee rate used to calculate the income fee deducted from trader profit payoff, configuration param represented in 18 decimals
    /// @param cfgMinLiquidationThresholdToCloseBeforeMaturity configuration param for closing swap validation, describes minimal change in
    /// position value required to close swap before maturity. Value represented in 18 decimals.
    /// @param cfgSecondsToMaturityWhenPositionCanBeClosed configuration param for closing swap validation, describes number of seconds before swap
    /// maturity after which swap can be closed by anybody not only by swap's buyer.
    function updateStorageWhenCloseSwapPayFixed(
        address liquidator,
        IporTypes.IporSwapMemory memory iporSwap,
        int256 payoff,
        uint256 closingTimestamp,
        uint256 cfgIncomeFeeRate,
        uint256 cfgMinLiquidationThresholdToCloseBeforeMaturity,
        uint256 cfgSecondsToMaturityWhenPositionCanBeClosed
    ) external;

    /// @notice Updates structures in the storage: balance, swaps, SOAP indicators when closing Receive-Fixed swap.
    /// Function is only available to Milton.
    /// @param liquidator address of account closing the swap
    /// @param iporSwap swap structure {IporTypes.IporSwapMemory}
    /// @param payoff amount that trader has earned or lost, represented in 18 decimals, can be negative.
    /// @param incomeFeeValue amount of fee calculated based on payoff.
    /// @param closingTimestamp moment when swap was closed
    /// @param cfgMinLiquidationThresholdToCloseBeforeMaturity configuration param for closing swap validation, describes minimal change in
    /// position value required to close swap before maturity. Value represented in 18 decimals.
    /// @param cfgSecondsToMaturityWhenPositionCanBeClosed configuration param for closing swap validation, describes number of seconds before swap
    /// maturity after which swap can be closed by anybody not only by swap's buyer.
    function updateStorageWhenCloseSwapReceiveFixed(
        address liquidator,
        IporTypes.IporSwapMemory memory iporSwap,
        int256 payoff,
        uint256 incomeFeeValue,
        uint256 closingTimestamp,
        uint256 cfgMinLiquidationThresholdToCloseBeforeMaturity,
        uint256 cfgSecondsToMaturityWhenPositionCanBeClosed
    ) external;

    /// @notice Updates the balance when Joseph withdraws Milton's assets from Stanley. Function is only available to Milton.
    /// @param withdrawnAmount asset amount that was withdrawn from Stanley to Milton by Joseph, represented in 18 decimals.
    /// @param vaultBalance Asset Management Vault (Stanley) balance, represented in 18 decimals
    function updateStorageWhenWithdrawFromStanley(uint256 withdrawnAmount, uint256 vaultBalance)
        external;

    /// @notice Updates the balance when Joseph deposits Milton's assets to Stanley. Function is only available to Milton.
    /// @param depositAmount asset amount deposited from Milton to Stanley by Joseph, represented in 18 decimals.
    /// @param vaultBalance actual Asset Management Vault(Stanley) balance , represented in 18 decimals
    function updateStorageWhenDepositToStanley(uint256 depositAmount, uint256 vaultBalance)
        external;

    /// @notice Updates the balance when Joseph transfers Milton's assets to Charlie Treasury's multisig wallet. Function is only available to Joseph.
    /// @param transferredAmount asset amount transferred to Charlie Treasury multisig wallet.
    function updateStorageWhenTransferToCharlieTreasury(uint256 transferredAmount) external;

    /// @notice Updates the balance when Joseph transfers Milton's assets to Treasury's multisig wallet. Function is only available to Joseph.
    /// @param transferredAmount asset amount transferred to Treasury's multisig wallet.
    function updateStorageWhenTransferToTreasury(uint256 transferredAmount) external;

    /// @notice Sets Milton's address. Function is only available to the smart contract Owner.
    /// @param milton Milton's address
    function setMilton(address milton) external;

    /// @notice Sets Joseph's address. Function is only available to smart contract Owner.
    /// @param joseph Joseph's address
    function setJoseph(address joseph) external;

    /// @notice Pauses current smart contract, it can be executed only by the Owner
    /// @dev Emits {Paused} event from Milton.
    function pause() external;

    /// @notice Unpauses current smart contract, it can be executed only by the Owner
    /// @dev Emits {Unpaused} event from Milton.
    function unpause() external;

    /// @notice Emmited when Milton address has changed by the smart contract Owner.
    /// @param changedBy account address that has changed Milton's address
    /// @param oldMilton old Milton's address
    /// @param newMilton new Milton's address
    event MiltonChanged(address changedBy, address oldMilton, address newMilton);

    /// @notice Emmited when Joseph address has been changed by smart contract Owner.
    /// @param changedBy account address that has changed Jospeh's address
    /// @param oldJoseph old Joseph's address
    /// @param newJoseph new Joseph's address
    event JosephChanged(address changedBy, address oldJoseph, address newJoseph);
}

// File: contracts/interfaces/types/MiltonTypes.sol


pragma solidity 0.8.15;


/// @title Structs used in Milton smart contract
library MiltonTypes {
    /// @notice Swap direction (long = Pay Fixed and Receive a Floating or short = receive fixed and pay a floating)
    enum SwapDirection {
        /// @notice When taking the "long" position the trader will pay a fixed rate and receive a floating rate.
        /// for more information refer to the documentation https://ipor-labs.gitbook.io/ipor-labs/automated-market-maker/ipor-swaps
        PAY_FIXED_RECEIVE_FLOATING,
        /// @notice When taking the "short" position the trader will pay a floating rate and receive a fixed rate.
        PAY_FLOATING_RECEIVE_FIXED
    }

    /// @notice Collection of swap attributes connected with IPOR Index
    /// @dev all values are in 18 decimals
    struct IporSwapIndicator {
        /// @notice IPOR Index value at the time of swap opening
        uint256 iporIndexValue;
        /// @notice IPOR Interest Bearing Token (IBT) price at the time of swap opening
        uint256 ibtPrice;
        /// @notice Swap's notional denominated in IBT
        uint256 ibtQuantity;
        /// @notice Fixed interest rate at which the position has been opened,
        /// it is quote from spread documentation
        uint256 fixedInterestRate;
    }

    /// @notice Structure describes one swap processed by closeSwaps method, information about swap ID and flag if this swap was closed during execution closeSwaps method.
    struct IporSwapClosingResult {
        /// @notice Swap ID
        uint256 swapId;
        /// @notice Flag describe if swap was closed during this execution
        bool closed;
    }
}

// File: contracts/interfaces/IMilton.sol


pragma solidity 0.8.15;




/// @title Interface for interaction with Milton.
interface IMilton {
    /// @notice Calculates spread for the current block.
    /// @dev All values represented in 18 decimals.
    /// @return spreadPayFixed spread for Pay-Fixed leg.
    /// @return spreadReceiveFixed spread for Receive-Fixed leg.
    function calculateSpread()
        external
        view
        returns (int256 spreadPayFixed, int256 spreadReceiveFixed);

    /// @notice Calculates the SOAP for the current block
    /// @dev All values represented in 18 decimals.
    /// @return soapPayFixed SOAP for Pay-Fixed leg.
    /// @return soapReceiveFixed SOAP for Receive-Fixed leg.
    /// @return soap total SOAP - sum of Pay-Fixed and Receive-Fixed SOAP.
    function calculateSoap()
        external
        view
        returns (
            int256 soapPayFixed,
            int256 soapReceiveFixed,
            int256 soap
        );

    /// @notice Opens Pay-Fixed (and Receive-Floating) swap with given parameters.
    /// @dev Emits `OpenSwap` event from Milton, {Transfer} event from ERC20 asset.
    /// @param totalAmount Total amount transferred from the buyer to Milton for the purpose of opening a swap. Represented in decimals specific for asset.
    /// @param acceptableFixedInterestRate Max quote value which trader accepts in case of rate slippage. Value represented in 18 decimals.
    /// @param leverage Leverage used in this posistion. Value represented in 18 decimals.
    /// @return Swap ID in Pay-Fixed swaps list
    function openSwapPayFixed(
        uint256 totalAmount,
        uint256 acceptableFixedInterestRate,
        uint256 leverage
    ) external returns (uint256);

    /// @notice Opens Receive-Fixed (and Pay Floating) swap with given parameters.
    /// @dev Emits `OpenSwap` event from Milton, {Transfer} event from ERC20 asset.
    /// @param totalAmount Total amount transferred from the buyer to Milton for the purpose of opening a swap. Represented in decimals specific for asset.
    /// @param acceptableFixedInterestRate Max quote value which trader accept in case of rate slippage. Value represented in 18 decimals.
    /// @param leverage Leverage used in this posisiton. Value represented in 18 decimals.
    /// @return Swap ID in Pay-Fixed swaps list
    function openSwapReceiveFixed(
        uint256 totalAmount,
        uint256 acceptableFixedInterestRate,
        uint256 leverage
    ) external returns (uint256);

    /// @notice Closes Pay-Fixed swap for given ID.
    /// @dev Emits {CloseSwap} event from Milton, {Transfer} event from ERC20 asset.
    /// @dev Rejects transaction and returns error code IPOR_307 if swapId doesn't have AmmTypes.SwapState.ACTIVE status.
    /// @param swapId Pay-Fixed Swap ID.
    function closeSwapPayFixed(uint256 swapId) external;

    /// @notice Closes Receive-Fixed swap for given ID.
    /// @dev Emits {CloseSwap} event from Milton, {Transfer} event from ERC20 asset.
    /// @dev Rejects transaction and returns error code IPOR_307 if swapId doesn't have AmmTypes.SwapState.ACTIVE status.
    /// @param swapId Receive-Fixed swap ID.
    function closeSwapReceiveFixed(uint256 swapId) external;

    /// @notice Closes list of pay fixed and receive fixed swaps in one transaction.
    /// @dev Emits {CloseSwap} events from Milton, {Transfer} events from ERC20 asset for every swap which was closed within this transaction.
    /// @param payFixedSwapIds list of pay fixed swap ids
    /// @param receiveFixedSwapIds list of receive fixed swap ids
    /// @return closedPayFixedSwaps list of pay fixed swaps with information which one was closed during this particular transaction.
    /// @return closedReceiveFixedSwaps list of receive fixed swaps with information which one was closed during this particular transaction.
    function closeSwaps(uint256[] memory payFixedSwapIds, uint256[] memory receiveFixedSwapIds)
        external
        returns (
            MiltonTypes.IporSwapClosingResult[] memory closedPayFixedSwaps,
            MiltonTypes.IporSwapClosingResult[] memory closedReceiveFixedSwaps
        );

    /// @notice Emmited when trader opens new swap.
    event OpenSwap(
        /// @notice swap ID.
        uint256 indexed swapId,
        /// @notice trader that opened the swap
        address indexed buyer,
        /// @notice underlying asset
        address asset,
        /// @notice swap direction
        MiltonTypes.SwapDirection direction,
        /// @notice money structure related with this swap
        AmmTypes.OpenSwapMoney money,
        /// @notice the moment when swap was opened
        uint256 openTimestamp,
        /// @notice the moment when swap will achieve maturity
        uint256 endTimestamp,
        /// @notice attributes taken from IPOR Index indicators.
        MiltonTypes.IporSwapIndicator indicator
    );

    /// @notice Emmited when trader closes Swap.
    event CloseSwap(
        /// @notice swap ID.
        uint256 indexed swapId,
        /// @notice underlying asset
        address asset,
        /// @notice the moment when swap was closed
        uint256 closeTimestamp,
        /// @notice account that liquidated the swap
        address liquidator,
        /// @notice asset amount after closing swap that has been transferred from Milton to the Buyer. Value represented in 18 decimals.
        uint256 transferredToBuyer,
        /// @notice asset amount after closing swap that has been transferred from Milton to the Liquidator. Value represented in 18 decimals.
        uint256 transferredToLiquidator,
        /// @notice incomeFeeValue value transferred to treasury
        uint256 incomeFeeValue
    );
}

// File: contracts/interfaces/IIporOracle.sol


pragma solidity 0.8.15;


/// @title Interface for interaction with IporOracle, smart contract responsible for managing IPOR Index.
interface IIporOracle {
    /// @notice Returns current version of IporOracle's
    /// @return current IporOracle version
    function getVersion() external pure returns (uint256);

    /// @notice Gets IPOR Index indicators for a given asset
    /// @dev all returned values represented in 18 decimals
    /// @param asset underlying / stablecoin address supported in Ipor Protocol
    /// @return value IPOR Index value for a given asset
    /// @return ibtPrice Interest Bearing Token Price for a given IPOR Index
    /// @return exponentialMovingAverage Exponential moving average for a given IPOR Index
    /// @return exponentialWeightedMovingVariance Exponential weighted movien variance for a given IPOR Index
    /// @return lastUpdateTimestamp Last IPOR Index update done by Charlie off-chain service
    function getIndex(address asset)
        external
        view
        returns (
            uint256 value,
            uint256 ibtPrice,
            uint256 exponentialMovingAverage,
            uint256 exponentialWeightedMovingVariance,
            uint256 lastUpdateTimestamp
        );

    /// @notice Gets accrued IPOR Index indicators for a given timestamp and asset .
    /// @param calculateTimestamp time of accrued IPOR Index calculation
    /// @param asset underlying / stablecoin address supported by IPOR Protocol.
    /// @return accruedIpor structure {IporTypes.AccruedIpor}
    function getAccruedIndex(uint256 calculateTimestamp, address asset)
        external
        view
        returns (IporTypes.AccruedIpor memory accruedIpor);

    /// @notice Calculates accrued Interest Bearing Token price for a given asset and timestamp.
    /// @param asset underlying / stablecoin address supported by IPOR Protocol.
    /// @param calculateTimestamp time of accrued Interest Bearing Token price calculation
    /// @return accrued IBT price, represented in 18 decimals
    function calculateAccruedIbtPrice(address asset, uint256 calculateTimestamp)
        external
        view
        returns (uint256);

    /// @notice Updates IPOR Index for a given asset. Function available only for Updater
    /// @dev Emmits {IporIndexUpdate} event.
    /// @param asset underlying / stablecoin address supported by IPOR Protocol
    /// @param indexValue new IPOR Index value represented in 18 decimals
    function updateIndex(address asset, uint256 indexValue) external;

    /// @notice Updates IPOR indexes for a given assets. Function available only for Updater
    /// @dev Emmits {IporIndexUpdate} event.
    /// @param assets underlying / stablecoin addresses supported by IPOR Protocol
    /// @param indexValues new IPOR Index values
    function updateIndexes(address[] memory assets, uint256[] memory indexValues) external;

    /// @notice Adds new Updater. Updater has right to update IPOR Index. Function available only for Owner.
    /// @param newUpdater new updater address
    function addUpdater(address newUpdater) external;

    /// @notice Removes Updater. Function available only for Owner.
    /// @param updater updater address
    function removeUpdater(address updater) external;

    /// @notice Checks if given account is an Updater.
    /// @param account account for checking
    /// @return 0 if account is not updater, 1 if account is updater.
    function isUpdater(address account) external view returns (uint256);

    /// @notice Adds new asset which IPOR Protocol will support. Function available only for Owner.
    /// @param newAsset new asset address
    /// @param updateTimestamp Time for which exponential moving average and exponential weighted moving variance was calculated
    /// @param exponentialMovingAverage initial Exponential Moving Average for this asset
    /// @param exponentialWeightedMovingVariance initial Exponential Weighted Moving Variance for asset.
    function addAsset(
        address newAsset,
        uint256 updateTimestamp,
        uint256 exponentialMovingAverage,
        uint256 exponentialWeightedMovingVariance
    ) external;

    /// @notice Removes asset which IPOR Protocol will not support. Function available only for Owner.
    /// @param asset  underlying / stablecoin address which currenlty is supported by IPOR Protocol.
    function removeAsset(address asset) external;

    /// @notice Pauses current smart contract, it can be executed only by the Owner
    /// @dev Emits {Paused} event from IporOracle.
    function pause() external;

    /// @notice Unpauses current smart contract, it can be executed only by the Owner
    /// @dev Emits {Unpaused} event from IporOracle.
    function unpause() external;

    /// @notice Emmited when Charlie update IPOR Index.
    /// @param asset underlying / stablecoin address
    /// @param indexValue IPOR Index value represented in 18 decimals
    /// @param quasiIbtPrice quasi Interest Bearing Token price represented in 18 decimals.
    /// @param exponentialMovingAverage Exponential Moving Average represented in 18 decimals.
    /// @param exponentialWeightedMovingVariance Exponential Weighted Moving Variance
    /// @param updateTimestamp moment when IPOR Index was updated.
    event IporIndexUpdate(
        address asset,
        uint256 indexValue,
        uint256 quasiIbtPrice,
        uint256 exponentialMovingAverage,
        uint256 exponentialWeightedMovingVariance,
        uint256 updateTimestamp
    );

    /// @notice event emitted when IPOR Index Updater is added by Owner
    /// @param newUpdater new Updater address
    event IporIndexAddUpdater(address newUpdater);

    /// @notice event emitted when IPOR Index Updater is removed by Owner
    /// @param updater updater address
    event IporIndexRemoveUpdater(address updater);

    /// @notice event emitted when new asset is added by Owner to list of assets supported in IPOR Protocol.
    /// @param newAsset new asset address
    /// @param updateTimestamp update timestamp
    /// @param exponentialMovingAverage Exponential Moving Average for asset
    /// @param exponentialWeightedMovingVariance Exponential Weighted Moving Variance for asset
    event IporIndexAddAsset(
        address newAsset,
        uint256 updateTimestamp,
        uint256 exponentialMovingAverage,
        uint256 exponentialWeightedMovingVariance
    );

    /// @notice event emitted when asset is removed by Owner from list of assets supported in IPOR Protocol.
    /// @param asset asset address
    event IporIndexRemoveAsset(address asset);
}

// File: contracts/libraries/Constants.sol


pragma solidity 0.8.15;

library Constants {
    uint256 public constant MAX_VALUE =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    uint256 public constant D18 = 1e18;
    int256 public constant D18_INT = 1e18;
    uint256 public constant D36 = 1e36;
    uint256 public constant D54 = 1e54;

    uint256 public constant YEAR_IN_SECONDS = 365 days;
    uint256 public constant WAD_YEAR_IN_SECONDS = D18 * YEAR_IN_SECONDS;
    int256 public constant WAD_YEAR_IN_SECONDS_INT = int256(WAD_YEAR_IN_SECONDS);
    uint256 public constant WAD_P2_YEAR_IN_SECONDS = D18 * D18 * YEAR_IN_SECONDS;
    int256 public constant WAD_P2_YEAR_IN_SECONDS_INT = int256(WAD_P2_YEAR_IN_SECONDS);

    uint256 public constant MAX_CHUNK_SIZE = 50;

    //@notice By default every swap takes 28 days, this variable show this value in seconds
    uint256 public constant SWAP_DEFAULT_PERIOD_IN_SECONDS = 60 * 60 * 24 * 28;
}

// File: contracts/interfaces/types/CockpitTypes.sol


pragma solidity 0.8.15;

/// @title Types used in comunication with Cockpit - an internal webapp responsible for IPOR Protocol diagnosis and monitoring.
/// @dev used by ICockpitDataProvider interface
library CockpitTypes {
    /// @notice Struct groupping important addresses used by CockpitDataProvider,
    /// struct represent data for a specific asset ie. USDT, USDC, DAI etc.
    struct AssetConfig {
        /// @notice Milton (AMM) address
        address milton;
        /// @notice MiltonStorage address
        address miltonStorage;
        /// @notice Joseph (part of AMM responsible for Liquidity Pool management) address
        address joseph;
        /// @notice ipToken address (Liquidity Pool Token)
        address ipToken;
        /// @notice ivToken address (IPOR Vault Token)
        address ivToken;
    }

    /// @notice Structure used to represent IPOR Index data in Cockpit web app
    struct IporFront {
        /// @notice Asset Symbol ie. USDT, USDC, DAI etc.
        string asset;
        /// @notice IPOR Index Value
        /// @dev value represented in 18 decimals
        uint256 indexValue;
        /// @notice Interest Bearing Token (IBT) Price
        /// @dev value represented in 18 decimals
        uint256 ibtPrice;
        /// @notice Exponential Moving Average
        /// @dev value represented in 18 decimals
        uint256 exponentialMovingAverage;
        /// @notice Exponential Weighted Moving Variance
        /// @dev value represented in 18 decimals
        uint256 exponentialWeightedMovingVariance;
        /// @notice Epoch timestamp of most recent IPOR publication
        /// @dev value represented in 18 decimals
        uint256 lastUpdateTimestamp;
    }
}

// File: contracts/interfaces/ICockpitDataProvider.sol


pragma solidity 0.8.15;



/// @title Interface of IPOR Protocol for interaction with external diagnostics web applications
interface ICockpitDataProvider {
    /// @notice Returns current version of Cockpit Data Provider
    /// @return current Cockpit Data Provider version
    function getVersion() external pure returns (uint256);

    /// @notice gets list all IPOR Indexes for all supported assets
    /// @return List of all IPOR Indexes for all supported assets in IPOR Protocol
    function getIndexes() external view returns (CockpitTypes.IporFront[] memory);

    /// @notice Gets asset's sender balance
    /// @param asset asset / stablecoin address
    /// @return sender balance in decimals specific for given asset
    function getMyTotalSupply(address asset) external view returns (uint256);

    /// @notice Gets sender's ipToken balance
    /// @param asset asset / stablecoin address
    /// @return sender ipToken balance represented in 18 decimals
    function getMyIpTokenBalance(address asset) external view returns (uint256);

    /// @notice Gets sender's ivToken balance
    /// @param asset asset / stablecoin address
    /// @return sender ivToken balance represented in 18 decimals
    function getMyIvTokenBalance(address asset) external view returns (uint256);

    /// @notice Gets sender's allowance in Milton
    /// @param asset asset / stablecoin address
    /// @return sender allowance in Milton represented in decimals specific for given asset
    function getMyAllowanceInMilton(address asset) external view returns (uint256);

    /// @notice Gets sender allowance in Joseph
    /// @param asset asset / stablecoin address
    /// @return sender allowance in Joseph represented in decimals specific for given asset
    function getMyAllowanceInJoseph(address asset) external view returns (uint256);

    /// @notice Gets the list of active Pay Fixed Receive Floating swaps in Milton for a given asset and address
    /// @param asset asset / stablecoin address
    /// @param account account address for which list of swaps is scoped
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of active Pay Fixed swaps in Milton
    /// @return swaps list of active swaps for a given filter
    function getSwapsPayFixed(
        address asset,
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Gets the list of active Receive Fixed Pay Floating Swaps in Milton for a given asset and address
    /// @param asset asset / stablecoin address
    /// @param account account address for which list of swaps is scoped
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of Receive Fixed swaps in Milton
    /// @return swaps list of active swaps for a given filter
    function getSwapsReceiveFixed(
        address asset,
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Gets list of active Pay Fixed Receive Floating Swaps in Milton of sender for a given asset
    /// @param asset asset / stablecoin address
    /// @param offset offset for paging
    /// @param chunkSize page size for paging
    /// @return totalCount total number of Pay Fixed swaps in Milton for a current user
    /// @return swaps list of active swaps for a given asset
    function getMySwapsPayFixed(
        address asset,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Gets list of active Receive Fixed Pay Floating Swaps in Milton of sender for a given asset
    /// @param asset asset / stablecoin address
    /// @param offset offset for paging functionality purposes
    /// @param chunkSize page size for paging functionality purposes
    /// @return totalCount total amount of Receive Fixed swaps in Milton for a current user
    /// @return swaps list of active swaps for a given asset
    function getMySwapsReceiveFixed(
        address asset,
        uint256 offset,
        uint256 chunkSize
    ) external view returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps);

    /// @notice Calculates spread value for a given asset based on a current Milton balance,
    /// SOAP, utilization and IPOR Index indicators.
    /// @param asset asset / stablecoin address
    /// @return spreadPayFixed Spread value for Pay Fixed leg for a given asset
    /// @return spreadReceiveFixed Spread value for Receive Fixed leg for a given asset
    function calculateSpread(address asset)
        external
        view
        returns (int256 spreadPayFixed, int256 spreadReceiveFixed);
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
}

// File: @openzeppelin/contracts-upgradeable/utils/StorageSlotUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

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
library StorageSlotUpgradeable {
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
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/beacon/IBeaconUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// File: @openzeppelin/contracts-upgradeable/interfaces/draft-IERC1822Upgradeable.sol


// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol


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

// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;


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

// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol


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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;



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
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// File: contracts/security/IporOwnableUpgradeable.sol


pragma solidity 0.8.15;



contract IporOwnableUpgradeable is OwnableUpgradeable {
    address private _appointedOwner;

    event AppointedToTransferOwnership(address indexed appointedOwner);

    function transferOwnership(address appointedOwner) public override onlyOwner {
        require(appointedOwner != address(0), IporErrors.WRONG_ADDRESS);
        _appointedOwner = appointedOwner;
        emit AppointedToTransferOwnership(appointedOwner);
    }

    function confirmTransferOwnership() public onlyAppointedOwner {
        _appointedOwner = address(0);
        _transferOwnership(_msgSender());
    }

    modifier onlyAppointedOwner() {
        require(_appointedOwner == _msgSender(), IporErrors.SENDER_NOT_APPOINTED_OWNER);
        _;
    }
}

// File: @openzeppelin/contracts-upgradeable/proxy/ERC1967/ERC1967UpgradeUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;






/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol


// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;




/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// File: @openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol


// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
}

// File: @openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: contracts/facades/cockpit/CockpitDataProvider.sol


pragma solidity 0.8.15;












contract CockpitDataProvider is
    Initializable,
    UUPSUpgradeable,
    IporOwnableUpgradeable,
    ICockpitDataProvider
{
    address internal _iporOracle;
    mapping(address => CockpitTypes.AssetConfig) internal _assetConfig;
    address[] internal _assets;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address iporOracle,
        address[] memory assets,
        address[] memory miltons,
        address[] memory miltonStorages,
        address[] memory josephs,
        address[] memory ipTokens,
        address[] memory ivTokens
    ) public initializer {
        __Ownable_init();
        __UUPSUpgradeable_init();
        require(iporOracle != address(0), IporErrors.WRONG_ADDRESS);
        require(
            assets.length == miltons.length && assets.length == miltonStorages.length,
            IporErrors.INPUT_ARRAYS_LENGTH_MISMATCH
        );

        _iporOracle = iporOracle;
        _assets = assets;

        uint256 assetsLength = assets.length;
        for (uint256 i = 0; i != assetsLength; i++) {
            require(assets[i] != address(0), IporErrors.WRONG_ADDRESS);
            require(miltons[i] != address(0), IporErrors.WRONG_ADDRESS);
            require(miltonStorages[i] != address(0), IporErrors.WRONG_ADDRESS);
            require(josephs[i] != address(0), IporErrors.WRONG_ADDRESS);
            require(ipTokens[i] != address(0), IporErrors.WRONG_ADDRESS);
            require(ivTokens[i] != address(0), IporErrors.WRONG_ADDRESS);

            _assetConfig[assets[i]] = CockpitTypes.AssetConfig(
                miltons[i],
                miltonStorages[i],
                josephs[i],
                ipTokens[i],
                ivTokens[i]
            );
        }
    }

    function getVersion() external pure override returns (uint256) {
        return 1;
    }

    function getIndexes() external view override returns (CockpitTypes.IporFront[] memory) {
        CockpitTypes.IporFront[] memory indexes = new CockpitTypes.IporFront[](_assets.length);

        uint256 assetsLength = _assets.length;
        for (uint256 i = 0; i != assetsLength; i++) {
            indexes[i] = _createIporFront(_assets[i]);
        }
        return indexes;
    }

    function getMyIpTokenBalance(address asset) external view override returns (uint256) {
        IERC20 token = IERC20(_assetConfig[asset].ipToken);
        return token.balanceOf(_msgSender());
    }

    function getMyIvTokenBalance(address asset) external view override returns (uint256) {
        IERC20 token = IERC20(_assetConfig[asset].ivToken);
        return token.balanceOf(_msgSender());
    }

    function getMyTotalSupply(address asset) external view override returns (uint256) {
        IERC20 token = IERC20(asset);
        return token.balanceOf(_msgSender());
    }

    function getMyAllowanceInMilton(address asset) external view override returns (uint256) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        IERC20 token = IERC20(asset);
        return token.allowance(_msgSender(), config.milton);
    }

    function getMyAllowanceInJoseph(address asset) external view override returns (uint256) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        IERC20 token = IERC20(asset);
        return token.allowance(_msgSender(), config.joseph);
    }

    function getSwapsPayFixed(
        address asset,
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view override returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        return IMiltonStorage(config.miltonStorage).getSwapsPayFixed(account, offset, chunkSize);
    }

    function getSwapsReceiveFixed(
        address asset,
        address account,
        uint256 offset,
        uint256 chunkSize
    ) external view override returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        return
            IMiltonStorage(config.miltonStorage).getSwapsReceiveFixed(account, offset, chunkSize);
    }

    function getMySwapsPayFixed(
        address asset,
        uint256 offset,
        uint256 chunkSize
    ) external view override returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        return
            IMiltonStorage(config.miltonStorage).getSwapsPayFixed(_msgSender(), offset, chunkSize);
    }

    function getMySwapsReceiveFixed(
        address asset,
        uint256 offset,
        uint256 chunkSize
    ) external view override returns (uint256 totalCount, IporTypes.IporSwapMemory[] memory swaps) {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        return
            IMiltonStorage(config.miltonStorage).getSwapsReceiveFixed(
                _msgSender(),
                offset,
                chunkSize
            );
    }

    function calculateSpread(address asset)
        external
        view
        override
        returns (int256 spreadPayFixed, int256 spreadReceiveFixed)
    {
        CockpitTypes.AssetConfig memory config = _assetConfig[asset];
        IMilton milton = IMilton(config.milton);

        try milton.calculateSpread() returns (int256 _spreadPayFixed, int256 _spreadReceiveFixed) {
            spreadPayFixed = _spreadPayFixed;
            spreadReceiveFixed = _spreadReceiveFixed;
        } catch {
            spreadPayFixed = 999999999999999999999;
            spreadReceiveFixed = 999999999999999999999;
        }
    }

    function _createIporFront(address asset)
        internal
        view
        returns (CockpitTypes.IporFront memory iporFront)
    {
        (
            uint256 value,
            uint256 ibtPrice,
            uint256 exponentialMovingAverage,
            uint256 exponentialWeightedMovingVariance,
            uint256 date
        ) = IIporOracle(_iporOracle).getIndex(asset);

        iporFront = CockpitTypes.IporFront(
            IERC20MetadataUpgradeable(asset).symbol(),
            value,
            ibtPrice,
            exponentialMovingAverage,
            exponentialWeightedMovingVariance,
            date
        );
    }

    //solhint-disable no-empty-blocks
    function _authorizeUpgrade(address) internal override onlyOwner {}
}