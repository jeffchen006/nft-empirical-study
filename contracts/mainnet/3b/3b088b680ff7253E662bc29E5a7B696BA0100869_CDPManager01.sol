// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;

import './BaseCDPManager.sol';

import '../interfaces/IOracleRegistry.sol';
import '../interfaces/IOracleUsd.sol';
import '../interfaces/IWETH.sol';
import '../interfaces/IVault.sol';
import '../interfaces/ICDPRegistry.sol';
import '../interfaces/vault-managers/parameters/IVaultManagerParameters.sol';
import '../interfaces/IVaultParameters.sol';
import '../interfaces/IToken.sol';
import "../interfaces/wrapped-assets/IWrappedAsset.sol";

import '../helpers/ReentrancyGuard.sol';
import '../helpers/SafeMath.sol';

/**
 * @title CDPManager01
 **/
contract CDPManager01 is BaseCDPManager {
    using SafeMath for uint;

    address payable public immutable WETH;

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _cdpRegistry The address of the CDP registry
     * @param _vaultManagerBorrowFeeParameters The address of the vault manager borrow fee parameters
     * @param _swappersRegistry The address of the swappers registry
     **/
    constructor(
        address _vaultManagerParameters,
        address _vaultManagerBorrowFeeParameters,
        address _oracleRegistry,
        address _cdpRegistry,
        address _swappersRegistry
    ) BaseCDPManager(_vaultManagerParameters, _vaultManagerBorrowFeeParameters, _oracleRegistry, _cdpRegistry, _swappersRegistry)
    {
        WETH = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault()).weth();
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        require(msg.sender == WETH, "Unit Protocol: RESTRICTED");
    }

    /**
      * @notice Depositing tokens must be pre-approved to Vault address
      * @notice Borrow fee in USDP tokens must be pre-approved to CDP manager address
      * @notice position actually considered as spawned only when debt > 0
      * @dev Deposits collateral and/or borrows USDP
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join(address asset, uint assetAmount, uint usdpAmount) public nonReentrant checkpoint(asset, msg.sender) {
        require(usdpAmount != 0 || assetAmount != 0, "Unit Protocol: USELESS_TX");
        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");

        if (usdpAmount == 0) {
            vault.depositMain(asset, msg.sender, assetAmount);
        } else {
            if (assetAmount != 0) {
                vault.depositMain(asset, msg.sender, assetAmount);
            }

            _mintUsdp(asset, msg.sender, usdpAmount);
            _ensurePositionCollateralization(asset, msg.sender);
        }

        // fire an event
        emit Join(asset, msg.sender, assetAmount, usdpAmount);
    }

    /**
      * @dev Deposits ETH and/or borrows USDP
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function join_Eth(uint usdpAmount) external payable {

        if (msg.value != 0) {
            IWETH(WETH).deposit{value: msg.value}();
            require(IWETH(WETH).transfer(msg.sender, msg.value), "Unit Protocol: WETH_TRANSFER_FAILED");
        }

        join(WETH, msg.value, usdpAmount);
    }

    /**
     * @notice Deposit asset with leverage. All usdp will be swapped to asset and deposited with user's asset
     * @notice For leverage L user must pass usdpAmount = (L - 1) * assetAmount * price
     * @notice User must:
     * @notice  - preapprove asset to vault: to deposit wrapped asset to vault
     * @notice  - preapprove USDP to swapper: swap USDP to additional asset
     * @notice  - preapprove USDP to CDPManager: to charge borrow (issuance) fee
     * @param asset The address of the collateral
     * @param swapper The address of swapper (for swap usdp->asset)
     * @param assetAmount The amount of the collateral to deposit
     * @param usdpAmount The amount of USDP token to borrow
     * @param minSwappedAssetAmount min asset amount which user must get after swap usdpAmount (in case of slippage)
     */
    function joinWithLeverage(
        address asset,
        ISwapper swapper,
        uint assetAmount,
        uint usdpAmount,
        uint minSwappedAssetAmount
    ) public nonReentrant checkpoint(asset, msg.sender) {
        _joinWithLeverage(
            asset,
            asset,
            false,
            swapper,
            assetAmount,
            usdpAmount,
            minSwappedAssetAmount
        );
    }

    /**
      * @notice Deposit asset, stake it if supported, mint wrapped asset and lock it, borrow USDP
      * @notice User must:
      * @notice  - preapprove token to wrappedAsset: to deposit asset to wrapped asset for wrapping
      * @notice  - preapprove wrapped token to vault: to deposit wrapped asset to vault
      * @notice  - preapprove USDP to CDPManager: to charge borrow (issuance) fee
      * @param wrappedAsset Address of wrapped asset
      * @param assetAmount The amount of the collateral to deposit
      * @param usdpAmount The amount of USDP token to borrow
      **/
    function wrapAndJoin(IWrappedAsset wrappedAsset, uint assetAmount, uint usdpAmount) external {
        if (assetAmount != 0) {
            wrappedAsset.deposit(msg.sender, assetAmount);
        }

        join(address(wrappedAsset), assetAmount, usdpAmount);
    }

    /**
     * @notice Wrap and deposit asset with leverage. All usdp will be swapped to asset and deposited with user's asset
     * @notice For leverage L user must pass usdpAmount = (L - 1) * assetAmount * price
     * @notice User must:
     * @notice  - preapprove token to wrappedAsset: to deposit asset to wrapped asset for wrapping
     * @notice  - preapprove wrapped token to vault: to deposit wrapped asset to vault
     * @notice  - preapprove USDP to swapper: swap USDP to additional asset
     * @notice  - preapprove USDP to CDPManager: to charge borrow (issuance) fee
     * @param wrappedAsset The address of wrapped asset
     * @param swapper The address of swapper (for swap usdp->asset)
     * @param assetAmount The amount of the collateral to deposit
     * @param usdpAmount The amount of USDP token to borrow
     * @param minSwappedAssetAmount min asset amount which user must get after swap usdpAmount (in case of slippage)
     */
    function wrapAndJoinWithLeverage(
        IWrappedAsset wrappedAsset,
        ISwapper swapper,
        uint assetAmount,
        uint usdpAmount,
        uint minSwappedAssetAmount
    ) public nonReentrant checkpoint(address(wrappedAsset), msg.sender) {
        _joinWithLeverage(
            address(wrappedAsset),
            address(wrappedAsset.getUnderlyingToken()),
            true,
            swapper,
            assetAmount,
            usdpAmount,
            minSwappedAssetAmount
        );
    }

    /**
      * @notice Tx sender must have a sufficient USDP balance to pay the debt
      * @dev Withdraws collateral and repays specified amount of debt
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to withdraw
      * @param usdpAmount The amount of USDP to repay
      **/
    function exit(address asset, uint assetAmount, uint usdpAmount) public nonReentrant checkpoint(asset, msg.sender) returns (uint) {

        // check usefulness of tx
        require(assetAmount != 0 || usdpAmount != 0, "Unit Protocol: USELESS_TX");

        uint debt = vault.debts(asset, msg.sender);

        // catch full repayment
        if (usdpAmount > debt) { usdpAmount = debt; }

        if (assetAmount == 0) {
            _repay(asset, msg.sender, usdpAmount);
        } else {
            if (debt == usdpAmount) {
                vault.withdrawMain(asset, msg.sender, assetAmount);
                if (usdpAmount != 0) {
                    _repay(asset, msg.sender, usdpAmount);
                }
            } else {
                _ensureOracle(asset);

                // withdraw collateral to the owner address
                vault.withdrawMain(asset, msg.sender, assetAmount);

                if (usdpAmount != 0) {
                    _repay(asset, msg.sender, usdpAmount);
                }

                vault.update(asset, msg.sender);

                _ensurePositionCollateralization(asset, msg.sender);
            }
        }

        // fire an event
        emit Exit(asset, msg.sender, assetAmount, usdpAmount);

        return usdpAmount;
    }

    /**
     * @notice Withdraws collateral and repay debt without USDP needed. assetAmountToSwap would be swaped to USDP internally
     * @notice User must:
     * @notice  - preapprove USDP to vault: pay stability fee
     * @notice  - preapprove asset to swapper: swap asset to USDP
     * @param asset The address of the collateral
     * @param swapper The address of swapper (for swap asset->usdp)
     * @param assetAmountToUser The amount of the collateral to withdraw
     * @param assetAmountToSwap The amount of the collateral to swap to USDP
     * @param minSwappedUsdpAmount min USDP amount which user must get after swap assetAmountToSwap (in case of slippage)
     */
    function exitWithDeleverage(
        address asset,
        ISwapper swapper,
        uint assetAmountToUser,
        uint assetAmountToSwap,
        uint minSwappedUsdpAmount
    ) public nonReentrant checkpoint(asset, msg.sender) returns (uint) {
        return _exitWithDeleverage(
            asset,
            asset,
            false,
            swapper,
            assetAmountToUser,
            assetAmountToSwap,
            minSwappedUsdpAmount
        );
    }

    /**
      * @notice Repayment is the sum of the principal and interest
      * @dev Withdraws collateral and repays specified amount of debt
      * @param asset The address of the collateral
      * @param assetAmount The amount of the collateral to withdraw
      * @param repayment The target repayment amount
      **/
    function exit_targetRepayment(address asset, uint assetAmount, uint repayment) external returns (uint) {

        uint usdpAmount = _calcPrincipal(asset, msg.sender, repayment);

        return exit(asset, assetAmount, usdpAmount);
    }

    /**
      * @notice Withdraws WETH and converts to ETH
      * @param ethAmount ETH amount to withdraw
      * @param usdpAmount The amount of USDP token to repay
      **/
    function exit_Eth(uint ethAmount, uint usdpAmount) public returns (uint) {
        usdpAmount = exit(WETH, ethAmount, usdpAmount);
        require(IWETH(WETH).transferFrom(msg.sender, address(this), ethAmount), "Unit Protocol: WETH_TRANSFER_FROM_FAILED");
        IWETH(WETH).withdraw(ethAmount);
        (bool success, ) = msg.sender.call{value:ethAmount}("");
        require(success, "Unit Protocol: ETH_TRANSFER_FAILED");
        return usdpAmount;
    }

    /**
      * @notice Repayment is the sum of the principal and interest
      * @notice Withdraws WETH and converts to ETH
      * @param ethAmount ETH amount to withdraw
      * @param repayment The target repayment amount
      **/
    function exit_Eth_targetRepayment(uint ethAmount, uint repayment) external returns (uint) {
        uint usdpAmount = _calcPrincipal(WETH, msg.sender, repayment);
        return exit_Eth(ethAmount, usdpAmount);
    }

    /**
      * @notice Withdraws wrapped asset and unwrap it, repays specified amount of debt
      * @param wrappedAsset Address of wrapped asset
      * @param assetAmount The amount of the collateral to withdrae
      * @param usdpAmount The amount of USDP token to repay
      **/
    function unwrapAndExit(IWrappedAsset wrappedAsset, uint assetAmount, uint usdpAmount) public returns (uint) {
        usdpAmount = exit(address(wrappedAsset), assetAmount, usdpAmount);
        if (assetAmount > 0) {
            wrappedAsset.withdraw(msg.sender, assetAmount);
        }

        return usdpAmount;
    }

    /**
      * @notice Withdraws wrapped asset and unwrap it, repays specified amount of debt
      * @notice Repayment is the sum of the principal and interest
      * @param wrappedAsset Address of wrapped asset
      * @param assetAmount The amount of the collateral to withdrae
      * @param repayment The amount of USDP token to repay
      **/
    function unwrapAndExitTargetRepayment(IWrappedAsset wrappedAsset, uint assetAmount, uint repayment) public returns (uint) {
        uint usdpAmount = _calcPrincipal(address(wrappedAsset), msg.sender, repayment);
        return unwrapAndExit(wrappedAsset, assetAmount, usdpAmount);
    }

    /**
     * @notice Withdraws asset and repay debt without USDP needed. assetAmountToSwap would be swaped to USDP internally
     * @notice User must:
     * @notice  - preapprove USDP to vault: pay stability fee
     * @notice  - preapprove asset (underlying token of wrapped asset) to swapper: swap asset to USDP
     * @param wrappedAsset The address of the wrapped asset
     * @param swapper The address of swapper (for swap asset->usdp)
     * @param assetAmountToUser The amount of the collateral to withdraw
     * @param assetAmountToSwap The amount of the collateral to swap to USDP
     * @param minSwappedUsdpAmount min USDP amount which user must get after swap assetAmountToSwap (in case of slippage)
     */
    function unwrapAndExitWithDeleverage(
        IWrappedAsset wrappedAsset,
        ISwapper swapper,
        uint assetAmountToUser,
        uint assetAmountToSwap,
        uint minSwappedUsdpAmount
    ) public nonReentrant checkpoint(address(wrappedAsset), msg.sender) returns (uint) {
        return _exitWithDeleverage(
            address(wrappedAsset),
            address(wrappedAsset.getUnderlyingToken()),
            true,
            swapper,
            assetAmountToUser,
            assetAmountToSwap,
            minSwappedUsdpAmount
        );
    }

    function _joinWithLeverage(
        address asset,
        address tokenToSwap,
        bool isWrappedAsset,
        ISwapper swapper,
        uint assetAmount,
        uint usdpAmount,
        uint minSwappedAssetAmount
    ) internal {
        require(assetAmount != 0 && usdpAmount != 0 && minSwappedAssetAmount != 0, "Unit Protocol: INVALID_AMOUNT");
        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");
        require(swappersRegistry.hasSwapper(swapper), "Unit Protocol: UNKNOWN_SWAPPER");

        uint usdpAmountToUser = _mintUsdp(asset, msg.sender, usdpAmount);
        uint swappedAssetAmount = _swapUsdpToAssetAndCheck(swapper, tokenToSwap, usdpAmountToUser, minSwappedAssetAmount);

        uint totalAssetAmount = assetAmount.add(swappedAssetAmount);
        if (isWrappedAsset) {
            IWrappedAsset(asset).deposit(msg.sender, totalAssetAmount);
        }

        vault.depositMain(asset, msg.sender, totalAssetAmount);
        _ensurePositionCollateralization(asset, msg.sender);

        emit Join(asset, msg.sender, totalAssetAmount, usdpAmount);
        emit JoinWithLeverage(asset, msg.sender, assetAmount, swappedAssetAmount, usdpAmount);
    }

    function _exitWithDeleverage(
        address asset,
        address tokenToSwap,
        bool isWrappedAsset,
        ISwapper swapper,
        uint assetAmountToUser,
        uint assetAmountToSwap,
        uint minSwappedUsdpAmount
    ) internal returns (uint) {
        require(assetAmountToSwap !=0 && minSwappedUsdpAmount != 0, "Unit Protocol: INVALID_AMOUNT");
        require(swappersRegistry.hasSwapper(swapper), "Unit Protocol: UNKNOWN_SWAPPER");

        uint debt = vault.debts(asset, msg.sender);
        require(debt > 0, "Unit Protocol: INVALID_USAGE");

        uint assetAmountToWithdraw = assetAmountToUser.add(assetAmountToSwap);
        vault.withdrawMain(asset, msg.sender, assetAmountToWithdraw);

        if (isWrappedAsset) {
            IWrappedAsset(asset).withdraw(msg.sender, assetAmountToWithdraw);
        }

        uint swappedUsdpAmount = _swapAssetToUsdpAndCheck(swapper, tokenToSwap, assetAmountToSwap, minSwappedUsdpAmount);

        uint usdpAmount = _calcPrincipal(asset, msg.sender, swappedUsdpAmount);
        require(usdpAmount > 0, "Unit Protocol: INVALID_USDP_AMOUNT");

        // catch full repayment
        if (usdpAmount > debt) { usdpAmount = debt; }

        if (debt == usdpAmount) {
            _repay(asset, msg.sender, usdpAmount);
        } else {
            _ensureOracle(asset);

            _repay(asset, msg.sender, usdpAmount);
            vault.update(asset, msg.sender);

            _ensurePositionCollateralization(asset, msg.sender);
        }

        emit Exit(asset, msg.sender, assetAmountToWithdraw, usdpAmount);
        emit ExitWithDeleverage(asset, msg.sender, assetAmountToUser, assetAmountToSwap, usdpAmount);

        return usdpAmount;
    }

    function _ensurePositionCollateralization(address asset, address owner) internal view {
        // collateral value of the position in USD
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        // USD limit of the position
        uint usdLimit = usdValue_q112 * vaultManagerParameters.initialCollateralRatio(asset) / Q112 / 100;

        // revert if collateralization is not enough
        require(vault.getTotalDebt(asset, owner) <= usdLimit, "Unit Protocol: UNDERCOLLATERALIZED");
    }

    // Liquidation Trigger

    /**
     * @dev Triggers liquidation of a position
     * @param asset The address of the collateral token of a position
     * @param owner The owner of the position
     **/
    function triggerLiquidation(address asset, address owner) external nonReentrant {

        _ensureOracle(asset);

        // USD value of the collateral
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        // reverts if a position is not liquidatable
        require(_isLiquidatablePosition(asset, owner, usdValue_q112), "Unit Protocol: SAFE_POSITION");

        uint liquidationDiscount_q112 = usdValue_q112.mul(
            vaultManagerParameters.liquidationDiscount(asset)
        ).div(DENOMINATOR_1E5);

        uint initialLiquidationPrice = usdValue_q112.sub(liquidationDiscount_q112).div(Q112);

        // sends liquidation command to the Vault
        vault.triggerLiquidation(asset, owner, initialLiquidationPrice);

        // fire an liquidation event
        emit LiquidationTriggered(asset, owner);
    }

    function getCollateralUsdValue_q112(address asset, address owner) public view returns (uint) {
        return IOracleUsd(oracleRegistry.oracleByAsset(asset)).assetToUsd(asset, vault.collaterals(asset, owner));
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return boolean value, whether a position is liquidatable
     **/
    function isLiquidatablePosition(
        address asset,
        address owner
    ) external view returns (bool) {
        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        return _isLiquidatablePosition(asset, owner, usdValue_q112);
    }

    /**
     * @dev Calculates current utilization ratio
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return utilization ratio
     **/
    function utilizationRatio(
        address asset,
        address owner
    ) public view returns (uint) {
        uint debt = vault.getTotalDebt(asset, owner);
        if (debt == 0) return 0;

        uint usdValue_q112 = getCollateralUsdValue_q112(asset, owner);

        return debt.mul(100).mul(Q112).div(usdValue_q112);
    }
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;

import "../interfaces/IVault.sol";
import '../interfaces/IVaultParameters.sol';
import "../interfaces/IOracleRegistry.sol";
import "../interfaces/ICDPRegistry.sol";
import '../interfaces/IToken.sol';
import "../interfaces/vault-managers/parameters/IVaultManagerParameters.sol";
import "../interfaces/vault-managers/parameters/IVaultManagerBorrowFeeParameters.sol";
import "../interfaces/swappers/ISwappersRegistry.sol";

import "../helpers/ReentrancyGuard.sol";
import '../helpers/TransferHelper.sol';
import "../helpers/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/**
 * @title BaseCDPManager
 * @dev all common logic should be moved here in future
 **/
abstract contract BaseCDPManager is ReentrancyGuard {
    using SafeMath for uint;

    IVault public immutable vault;
    IVaultParameters public immutable vaultParameters;
    IVaultManagerParameters public immutable vaultManagerParameters;
    IVaultManagerBorrowFeeParameters public immutable vaultManagerBorrowFeeParameters;
    IOracleRegistry public immutable oracleRegistry;
    ICDPRegistry public immutable cdpRegistry;
    ISwappersRegistry public immutable swappersRegistry;
    IERC20 public immutable usdp;

    uint public constant Q112 = 2 ** 112;
    uint public constant DENOMINATOR_1E5 = 1e5;

    /**
     * @dev Trigger when joins are happened
    **/
    event Join(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Log joins with leverage
     **/
    event JoinWithLeverage(address indexed asset, address indexed owner, uint userAssetAmount, uint swappedAssetAmount, uint usdp);

    /**
     * @dev Trigger when exits are happened
    **/
    event Exit(address indexed asset, address indexed owner, uint main, uint usdp);

    /**
     * @dev Log exit with deleverage
     **/
    event ExitWithDeleverage(address indexed asset, address indexed owner, uint assetToUser, uint assetToSwap, uint usdp);

    /**
     * @dev Trigger when liquidations are initiated
    **/
    event LiquidationTriggered(address indexed asset, address indexed owner);

    modifier checkpoint(address asset, address owner) {
        _;
        cdpRegistry.checkpoint(asset, owner);
    }

    /**
     * @param _vaultManagerParameters The address of the contract with Vault manager parameters
     * @param _vaultManagerBorrowFeeParameters The address of the vault manager borrow fee parameters
     * @param _oracleRegistry The address of the oracle registry
     * @param _cdpRegistry The address of the CDP registry
     * @param _swappersRegistry The address of the swappers registry
     **/
    constructor(
        address _vaultManagerParameters,
        address _vaultManagerBorrowFeeParameters,
        address _oracleRegistry,
        address _cdpRegistry,
        address _swappersRegistry
    ) {
        require(
            _vaultManagerParameters != address(0) &&
            _oracleRegistry != address(0) &&
            _cdpRegistry != address(0) &&
            _vaultManagerBorrowFeeParameters != address(0) &&
            _swappersRegistry != address(0)
            , "Unit Protocol: INVALID_ARGS"
        );
        vaultManagerParameters = IVaultManagerParameters(_vaultManagerParameters);
        IVault vaultLocal = IVault(IVaultParameters(IVaultManagerParameters(_vaultManagerParameters).vaultParameters()).vault());
        vault = vaultLocal;
        oracleRegistry = IOracleRegistry(_oracleRegistry);
        cdpRegistry = ICDPRegistry(_cdpRegistry);
        swappersRegistry = ISwappersRegistry(_swappersRegistry);
        vaultManagerBorrowFeeParameters = IVaultManagerBorrowFeeParameters(_vaultManagerBorrowFeeParameters);
        usdp = IERC20(vaultLocal.usdp());
        vaultParameters = IVaultParameters(vaultLocal.vaultParameters());
    }

    /**
     * @notice Charge borrow fee if needed
     */
    function _chargeBorrowFee(address asset, address user, uint usdpAmount) internal returns (uint borrowFee) {
        borrowFee = vaultManagerBorrowFeeParameters.calcBorrowFeeAmount(asset, usdpAmount);
        if (borrowFee == 0) { // very small amount case
            return borrowFee;
        }

        // to fail with concrete reason, not with TRANSFER_FROM_FAILED from safeTransferFrom
        require(usdp.allowance(user, address(this)) >= borrowFee, "Unit Protocol: BORROW_FEE_NOT_APPROVED");

        TransferHelper.safeTransferFrom(
            address(usdp),
            user,
            vaultManagerBorrowFeeParameters.feeReceiver(),
            borrowFee
        );
    }

    // decreases debt
    function _repay(address asset, address owner, uint usdpAmount) internal {
        uint fee = vault.calculateFee(asset, owner, usdpAmount);
        vault.chargeFee(vault.usdp(), owner, fee);

        // burn USDP from the owner's balance
        uint debtAfter = vault.repay(asset, owner, usdpAmount);
        if (debtAfter == 0) {
            // clear unused storage
            vault.destroy(asset, owner);
        }
    }

    /**
     * @dev Calculates liquidation price
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @return Q112-encoded liquidation price
     **/
    function liquidationPrice_q112(
        address asset,
        address owner
    ) external view returns (uint) {
        uint debt = vault.getTotalDebt(asset, owner);
        if (debt == 0) return uint(-1);

        uint collateralLiqPrice = debt.mul(100).mul(Q112).div(vaultManagerParameters.liquidationRatio(asset));

        require(IToken(asset).decimals() <= 18, "Unit Protocol: NOT_SUPPORTED_DECIMALS");

        return collateralLiqPrice / vault.collaterals(asset, owner) / 10 ** (18 - IToken(asset).decimals());
    }

    /**
     * @dev Returned asset amount + charged stability fee on this amount = repayment (in fact <= repayment bcs of rounding error)
     */
    function _calcPrincipal(address asset, address owner, uint repayment) internal view returns (uint) {
        uint multiplier = repayment;
        uint fee = vault.calculateFee(asset, owner, multiplier);

        return repayment * multiplier / (multiplier + fee);
        /*
            x + fee(x) = repayment
            x + x * feePercent * pastTime / 365 days / denominator = repayment
            x * (1 + feePercent * pastTime / 365 days / denominator) = repayment
            x * (1 + fee(1)) = repayment
            x = repayment / (1 + fee(1))
            With usage in such way we have huge rounding error on small pastTime
            Will multipy numerator and denominator of right part with big enough number. Repayment is good enough for this purposes
        */
    }

    /**
     * @dev Determines whether a position is liquidatable
     * @param asset The address of the collateral
     * @param owner The owner of the position
     * @param usdValue_q112 Q112-encoded USD value of the collateral
     * @return boolean value, whether a position is liquidatable
     **/
    function _isLiquidatablePosition(
        address asset,
        address owner,
        uint usdValue_q112
    ) internal view returns (bool) {
        uint debt = vault.getTotalDebt(asset, owner);

        // position is collateralized if there is no debt
        if (debt == 0) return false;

        return debt.mul(100).mul(Q112).div(usdValue_q112) >= vaultManagerParameters.liquidationRatio(asset);
    }

    function _ensureOracle(address asset) internal view virtual returns (uint oracleType) {
        oracleType = oracleRegistry.oracleTypeByAsset(asset);
        require(oracleType != 0, "Unit Protocol: INVALID_ORACLE_TYPE");

        address oracle = oracleRegistry.oracleByType(oracleType);
        require(oracle != address(0), "Unit Protocol: DISABLED_ORACLE");
    }

    function _mintUsdp(address _asset, address _owner, uint _amount) internal returns (uint usdpAmountToUser) {
        uint oracleType = _ensureOracle(_asset);

        bool spawned = vault.debts(_asset, _owner) != 0;
        if (spawned) {
            require(vault.oracleType(_asset, _owner) == oracleType, "Unit Protocol: INCONSISTENT_USER_ORACLE_TYPE");
        } else {
            vault.spawn(_asset, _owner, oracleType);
        }

        vault.borrow(_asset, _owner, _amount);
        uint borrowFee = _chargeBorrowFee(_asset, _owner, _amount);

        return _amount.sub(borrowFee);
    }

    function _swapUsdpToAssetAndCheck(ISwapper swapper, address _asset, uint _usdpAmountToSwap, uint _minSwappedAssetAmount) internal returns(uint swappedAssetAmount) {
        uint assetBalanceBeforeSwap = IERC20(_asset).balanceOf(msg.sender);
        uint usdpBalanceBeforeSwap = usdp.balanceOf(msg.sender);

        swappedAssetAmount = swapper.swapUsdpToAsset(msg.sender, _asset, _usdpAmountToSwap, _minSwappedAssetAmount);

        require(swappedAssetAmount >= _minSwappedAssetAmount, "Unit Protocol: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
        require(IERC20(_asset).balanceOf(msg.sender) == assetBalanceBeforeSwap.add(swappedAssetAmount), "Unit Protocol: INVALID_SWAPPED_ASSET_AMOUNT_RETURNED");
        require(usdp.balanceOf(msg.sender) == usdpBalanceBeforeSwap.sub(_usdpAmountToSwap), "Unit Protocol: INVALID_USDP_AMOUNT_GOT_FOR_SWAP_BY_SWAPPER");
    }

    function _swapAssetToUsdpAndCheck(ISwapper swapper, address _asset, uint _assetAmountToSwap, uint _minSwappedUsdpAmount) internal returns(uint swappedUsdpAmount) {
        uint assetBalanceBeforeSwap = IERC20(_asset).balanceOf(msg.sender);
        uint usdpBalanceBeforeSwap = usdp.balanceOf(msg.sender);

        swappedUsdpAmount = swapper.swapAssetToUsdp(msg.sender, _asset, _assetAmountToSwap, _minSwappedUsdpAmount);

        require(swappedUsdpAmount >= _minSwappedUsdpAmount, "Unit Protocol: SWAPPED_AMOUNT_LESS_THAN_EXPECTED_MINIMUM");
        require(IERC20(_asset).balanceOf(msg.sender) == assetBalanceBeforeSwap.sub(_assetAmountToSwap), "Unit Protocol: INVALID_ASSET_AMOUNT_GOT_FOR_SWAP_BY_SWAPPER");
        require(usdp.balanceOf(msg.sender) == usdpBalanceBeforeSwap.add(swappedUsdpAmount), "Unit Protocol: INVALID_SWAPPED_USDP_AMOUNT_RETURNED");
    }
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;
pragma abicoder v2;

interface IOracleRegistry {

    struct Oracle {
        uint oracleType;
        address oracleAddress;
    }

    function WETH (  ) external view returns ( address );
    function getKeydonixOracleTypes (  ) external view returns ( uint256[] memory );
    function getOracles (  ) external view returns ( Oracle[] memory foundOracles );
    function keydonixOracleTypes ( uint256 ) external view returns ( uint256 );
    function maxOracleType (  ) external view returns ( uint256 );
    function oracleByAsset ( address asset ) external view returns ( address );
    function oracleByType ( uint256 ) external view returns ( address );
    function oracleTypeByAsset ( address ) external view returns ( uint256 );
    function oracleTypeByOracle ( address ) external view returns ( uint256 );
    function setKeydonixOracleTypes ( uint256[] memory _keydonixOracleTypes ) external;
    function setOracle ( uint256 oracleType, address oracle ) external;
    function setOracleTypeForAsset ( address asset, uint256 oracleType ) external;
    function setOracleTypeForAssets ( address[] memory assets, uint256 oracleType ) external;
    function unsetOracle ( uint256 oracleType ) external;
    function unsetOracleForAsset ( address asset ) external;
    function unsetOracleForAssets ( address[] memory assets ) external;
    function vaultParameters (  ) external view returns ( address );
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IOracleUsd {

    // returns Q112-encoded value
    // returned value 10**18 * 2**112 is $1
    function assetToUsd(address asset, uint amount) external view returns (uint);
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IVault {
    function DENOMINATOR_1E2 (  ) external view returns ( uint256 );
    function DENOMINATOR_1E5 (  ) external view returns ( uint256 );
    function borrow ( address asset, address user, uint256 amount ) external returns ( uint256 );
    function calculateFee ( address asset, address user, uint256 amount ) external view returns ( uint256 );
    function changeOracleType ( address asset, address user, uint256 newOracleType ) external;
    function chargeFee ( address asset, address user, uint256 amount ) external;
    function col (  ) external view returns ( address );
    function colToken ( address, address ) external view returns ( uint256 );
    function collaterals ( address, address ) external view returns ( uint256 );
    function debts ( address, address ) external view returns ( uint256 );
    function depositCol ( address asset, address user, uint256 amount ) external;
    function depositEth ( address user ) external payable;
    function depositMain ( address asset, address user, uint256 amount ) external;
    function destroy ( address asset, address user ) external;
    function getTotalDebt ( address asset, address user ) external view returns ( uint256 );
    function lastUpdate ( address, address ) external view returns ( uint256 );
    function liquidate ( address asset, address positionOwner, uint256 mainAssetToLiquidator, uint256 colToLiquidator, uint256 mainAssetToPositionOwner, uint256 colToPositionOwner, uint256 repayment, uint256 penalty, address liquidator ) external;
    function liquidationBlock ( address, address ) external view returns ( uint256 );
    function liquidationFee ( address, address ) external view returns ( uint256 );
    function liquidationPrice ( address, address ) external view returns ( uint256 );
    function oracleType ( address, address ) external view returns ( uint256 );
    function repay ( address asset, address user, uint256 amount ) external returns ( uint256 );
    function spawn ( address asset, address user, uint256 _oracleType ) external;
    function stabilityFee ( address, address ) external view returns ( uint256 );
    function tokenDebts ( address ) external view returns ( uint256 );
    function triggerLiquidation ( address asset, address positionOwner, uint256 initialPrice ) external;
    function update ( address asset, address user ) external;
    function usdp (  ) external view returns ( address );
    function vaultParameters (  ) external view returns ( address );
    function weth (  ) external view returns ( address payable );
    function withdrawCol ( address asset, address user, uint256 amount ) external;
    function withdrawEth ( address user, uint256 amount ) external;
    function withdrawMain ( address asset, address user, uint256 amount ) external;
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

interface ICDPRegistry {

    struct CDP {
        address asset;
        address owner;
    }

    function batchCheckpoint ( address[] calldata assets, address[] calldata owners ) external;
    function batchCheckpointForAsset ( address asset, address[] calldata owners ) external;
    function checkpoint ( address asset, address owner ) external;
    function cr (  ) external view returns ( address );
    function getAllCdps (  ) external view returns ( CDP[] memory r );
    function getCdpsByCollateral ( address asset ) external view returns ( CDP[] memory cdps );
    function getCdpsByOwner ( address owner ) external view returns ( CDP[] memory r );
    function getCdpsCount (  ) external view returns ( uint256 totalCdpCount );
    function getCdpsCountForCollateral ( address asset ) external view returns ( uint256 );
    function isAlive ( address asset, address owner ) external view returns ( bool );
    function isListed ( address asset, address owner ) external view returns ( bool );
    function vault (  ) external view returns ( address );
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IVaultManagerParameters {
    function devaluationPeriod ( address ) external view returns ( uint256 );
    function initialCollateralRatio ( address ) external view returns ( uint256 );
    function liquidationDiscount ( address ) external view returns ( uint256 );
    function liquidationRatio ( address ) external view returns ( uint256 );
    function maxColPercent ( address ) external view returns ( uint256 );
    function minColPercent ( address ) external view returns ( uint256 );
    function setColPartRange ( address asset, uint256 min, uint256 max ) external;
    function setCollateral (
        address asset,
        uint256 stabilityFeeValue,
        uint256 liquidationFeeValue,
        uint256 initialCollateralRatioValue,
        uint256 liquidationRatioValue,
        uint256 liquidationDiscountValue,
        uint256 devaluationPeriodValue,
        uint256 usdpLimit,
        uint256[] calldata oracles,
        uint256 minColP,
        uint256 maxColP
    ) external;
    function setDevaluationPeriod ( address asset, uint256 newValue ) external;
    function setInitialCollateralRatio ( address asset, uint256 newValue ) external;
    function setLiquidationDiscount ( address asset, uint256 newValue ) external;
    function setLiquidationRatio ( address asset, uint256 newValue ) external;
    function vaultParameters (  ) external view returns ( address );
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IVaultParameters {
    function canModifyVault ( address ) external view returns ( bool );
    function foundation (  ) external view returns ( address );
    function isManager ( address ) external view returns ( bool );
    function isOracleTypeEnabled ( uint256, address ) external view returns ( bool );
    function liquidationFee ( address ) external view returns ( uint256 );
    function setCollateral ( address asset, uint256 stabilityFeeValue, uint256 liquidationFeeValue, uint256 usdpLimit, uint256[] calldata oracles ) external;
    function setFoundation ( address newFoundation ) external;
    function setLiquidationFee ( address asset, uint256 newValue ) external;
    function setManager ( address who, bool permit ) external;
    function setOracleType ( uint256 _type, address asset, bool enabled ) external;
    function setStabilityFee ( address asset, uint256 newValue ) external;
    function setTokenDebtLimit ( address asset, uint256 limit ) external;
    function setVaultAccess ( address who, bool permit ) external;
    function stabilityFee ( address ) external view returns ( uint256 );
    function tokenDebtLimit ( address ) external view returns ( uint256 );
    function vault (  ) external view returns ( address );
    function vaultParameters (  ) external view returns ( address );
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IToken {
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWrappedAsset is IERC20 /* IERC20WithOptional */ {

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event PositionMoved(address indexed userFrom, address indexed userTo, uint256 amount);

    event EmergencyWithdraw(address indexed user, uint256 amount);
    event TokenWithdraw(address indexed user, address token, uint256 amount);

    event FeeChanged(uint256 newFeePercent);
    event FeeReceiverChanged(address newFeeReceiver);
    event AllowedBoneLockerSelectorAdded(address boneLocker, bytes4 selector);
    event AllowedBoneLockerSelectorRemoved(address boneLocker, bytes4 selector);

    /**
     * @notice Get underlying token
     */
    function getUnderlyingToken() external view returns (IERC20);

    /**
     * @notice deposit underlying token and send wrapped token to user
     * @dev Important! Only user or trusted contracts must be able to call this method
     */
    function deposit(address _userAddr, uint256 _amount) external;

    /**
     * @notice get wrapped token and return underlying
     * @dev Important! Only user or trusted contracts must be able to call this method
     */
    function withdraw(address _userAddr, uint256 _amount) external;

    /**
     * @notice get pending reward amount for user if reward is supported
     */
    function pendingReward(address _userAddr) external view returns (uint256);

    /**
     * @notice claim pending reward for user if reward is supported
     */
    function claimReward(address _userAddr) external;

    /**
     * @notice Manually move position (or its part) to another user (for example in case of liquidation)
     * @dev Important! Only trusted contracts must be able to call this method
     */
    function movePosition(address _userAddrFrom, address _userAddrTo, uint256 _amount) external;

    /**
     * @dev function for checks that asset is unitprotocol wrapped asset.
     * @dev For wrapped assets must return keccak256("UnitProtocolWrappedAsset")
     */
    function isUnitProtocolWrappedAsset() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

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
contract ReentrancyGuard {
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

    constructor () {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: division by zero");
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2021 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity ^0.7.6;

interface IVaultManagerBorrowFeeParameters {

    /**
     * @notice 1 = 100% = 10000 basis points
     **/
    function BASIS_POINTS_IN_1() external view returns (uint);

    /**
     * @notice Borrow fee receiver
     **/
    function feeReceiver() external view returns (address);

    /**
     * @notice Sets the borrow fee receiver. Only manager is able to call this function
     * @param newFeeReceiver The address of fee receiver
     **/
    function setFeeReceiver(address newFeeReceiver) external;

    /**
     * @notice Sets the base borrow fee in basis points (1bp = 0.01% = 0.0001). Only manager is able to call this function
     * @param newBaseBorrowFeeBasisPoints The borrow fee in basis points
     **/
    function setBaseBorrowFee(uint16 newBaseBorrowFeeBasisPoints) external;

    /**
     * @notice Sets the borrow fee for a particular collateral in basis points (1bp = 0.01% = 0.0001). Only manager is able to call this function
     * @param asset The address of the main collateral token
     * @param newEnabled Is custom fee enabled for asset
     * @param newFeeBasisPoints The borrow fee in basis points
     **/
    function setAssetBorrowFee(address asset, bool newEnabled, uint16 newFeeBasisPoints) external;

    /**
     * @notice Returns borrow fee for particular collateral in basis points (1bp = 0.01% = 0.0001)
     * @param asset The address of the main collateral token
     * @return feeBasisPoints The borrow fee in basis points
     **/
    function getBorrowFee(address asset) external view returns (uint16 feeBasisPoints);

    /**
     * @notice Returns borrow fee for usdp amount for particular collateral
     * @param asset The address of the main collateral token
     * @return The borrow fee
     **/
    function calcBorrowFeeAmount(address asset, uint usdpAmount) external view returns (uint);
}

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;

import "./ISwapper.sol";


interface ISwappersRegistry {
    event SwapperAdded(ISwapper swapper);
    event SwapperRemoved(ISwapper swapper);

    function getSwapperId(ISwapper _swapper) external view returns (uint);
    function getSwapper(uint _id) external view returns (ISwapper);
    function hasSwapper(ISwapper _swapper) external view returns (bool);

    function getSwappersLength() external view returns (uint);
    function getSwappers() external view returns (ISwapper[] memory);
}

// SPDX-License-Identifier: GPL-3.0-or-later

/*
  Copyright 2020 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

// SPDX-License-Identifier: bsl-1.1

/*
  Copyright 2022 Unit Protocol: Artem Zakharov ([email protected]).
*/
pragma solidity 0.7.6;


interface ISwapper {

    /**
     * @notice Predict asset amount after usdp swap
     */
    function predictAssetOut(address _asset, uint256 _usdpAmountIn) external view returns (uint predictedAssetAmount);

    /**
     * @notice Predict USDP amount after asset swap
     */
    function predictUsdpOut(address _asset, uint256 _assetAmountIn) external view returns (uint predictedUsdpAmount);

    /**
     * @notice usdp must be approved to swapper
     * @dev asset must be sent to user after swap
     */
    function swapUsdpToAsset(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external returns (uint swappedAssetAmount);

    /**
     * @notice asset must be approved to swapper
     * @dev usdp must be sent to user after swap
     */
    function swapAssetToUsdp(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external returns (uint swappedUsdpAmount);

    /**
     * @notice DO NOT SEND tokens to contract manually. For usage in contracts only.
     * @dev for gas saving with usage in contracts tokens must be send directly to contract instead
     * @dev asset must be sent to user after swap
     */
    function swapUsdpToAssetWithDirectSending(address _user, address _asset, uint256 _usdpAmount, uint256 _minAssetAmount) external returns (uint swappedAssetAmount);

    /**
     * @notice DO NOT SEND tokens to contract manually. For usage in contracts only.
     * @dev for gas saving with usage in contracts tokens must be send directly to contract instead
     * @dev usdp must be sent to user after swap
     */
    function swapAssetToUsdpWithDirectSending(address _user, address _asset, uint256 _assetAmount, uint256 _minUsdpAmount) external returns (uint swappedUsdpAmount);
}