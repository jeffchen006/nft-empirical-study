// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ERC20Helper }           from "../modules/erc20-helper/src/ERC20Helper.sol";
import { IMapleProxyFactory }    from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IMapleProxied }         from "../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";
import { MapleProxiedInternals } from "../modules/maple-proxy-factory/contracts/MapleProxiedInternals.sol";

import { PoolManagerStorage } from "./proxy/PoolManagerStorage.sol";

import {
    IERC20Like,
    IGlobalsLike,
    ILoanLike,
    ILoanManagerLike,
    IPoolDelegateCoverLike,
    IPoolLike,
    IWithdrawalManagerLike
} from "./interfaces/Interfaces.sol";

import { IPoolManager } from "./interfaces/IPoolManager.sol";

/*

    ███╗   ███╗ █████╗ ██████╗ ██╗     ███████╗
    ████╗ ████║██╔══██╗██╔══██╗██║     ██╔════╝
    ██╔████╔██║███████║██████╔╝██║     █████╗
    ██║╚██╔╝██║██╔══██║██╔═══╝ ██║     ██╔══╝
    ██║ ╚═╝ ██║██║  ██║██║     ███████╗███████╗
    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝╚══════╝

   ██████╗  ██████╗  ██████╗ ██╗         ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗
   ██╔══██╗██╔═══██╗██╔═══██╗██║         ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
   ██████╔╝██║   ██║██║   ██║██║         ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
   ██╔═══╝ ██║   ██║██║   ██║██║         ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
   ██║     ╚██████╔╝╚██████╔╝███████╗    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
   ╚═╝      ╚═════╝  ╚═════╝ ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝

*/

contract PoolManager is IPoolManager, MapleProxiedInternals, PoolManagerStorage {

    uint256 public constant HUNDRED_PERCENT = 100_0000;  // Four decimal precision.

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier nonReentrant() {
        require(_locked == 1, "PM:LOCKED");

        _locked = 2;

        _;

        _locked = 1;
    }

    modifier onlyIfNotConfigured() {
        _revertIfConfigured();
        _;
    }

    modifier onlyPoolDelegateOrNotConfigured() {
        _revertIfConfiguredAndNotPoolDelegate();
        _;
    }

    modifier onlyPool() {
        _revertIfNotPool();
        _;
    }

    modifier onlyPoolDelegate() {
        _revertIfNotPoolDelegate();
        _;
    }

    modifier onlyPoolDelegateOrGovernor() {
        _revertIfNeitherPoolDelegateNorGovernor();
        _;
    }

    modifier whenNotPaused() {
        _revertIfPaused();
        _;
    }

    /**************************************************************************************************************************************/
    /*** Migration Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    // NOTE: Can't add whenProtocolNotPaused modifier here, as globals won't be set until
    //       initializer.initialize() is called, and this function is what triggers that initialization.
    function migrate(address migrator_, bytes calldata arguments_) external override whenNotPaused {
        require(msg.sender == _factory(),        "PM:M:NOT_FACTORY");
        require(_migrate(migrator_, arguments_), "PM:M:FAILED");
        require(poolDelegateCover != address(0), "PM:M:DELEGATE_NOT_SET");
    }

    function setImplementation(address implementation_) external override whenNotPaused {
        require(msg.sender == _factory(), "PM:SI:NOT_FACTORY");
        _setImplementation(implementation_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) external override whenNotPaused {
        IGlobalsLike globals_ = IGlobalsLike(globals());

        if (msg.sender == poolDelegate) {
            require(globals_.isValidScheduledCall(msg.sender, address(this), "PM:UPGRADE", msg.data), "PM:U:INVALID_SCHED_CALL");

            globals_.unscheduleCall(msg.sender, "PM:UPGRADE", msg.data);
        } else {
            require(msg.sender == globals_.securityAdmin(), "PM:U:NO_AUTH");
        }

        emit Upgraded(version_, arguments_);

        IMapleProxyFactory(_factory()).upgradeInstance(version_, arguments_);
    }

    /**************************************************************************************************************************************/
    /*** Initial Configuration Function                                                                                                 ***/
    /**************************************************************************************************************************************/

    // NOTE: This function is always called atomically during the deployment process so a DoS attack is not possible.
    function completeConfiguration() external override whenNotPaused onlyIfNotConfigured {
        configured = true;

        emit PoolConfigurationComplete();
    }

    /**************************************************************************************************************************************/
    /*** Ownership Transfer Functions                                                                                                   ***/
    /**************************************************************************************************************************************/

    function acceptPoolDelegate() external override whenNotPaused {
        require(msg.sender == pendingPoolDelegate, "PM:APD:NOT_PENDING_PD");

        IGlobalsLike(globals()).transferOwnedPoolManager(poolDelegate, msg.sender);

        emit PendingDelegateAccepted(poolDelegate, pendingPoolDelegate);

        poolDelegate        = pendingPoolDelegate;
        pendingPoolDelegate = address(0);
    }

    function setPendingPoolDelegate(address pendingPoolDelegate_) external override whenNotPaused onlyPoolDelegate {
        pendingPoolDelegate = pendingPoolDelegate_;

        emit PendingDelegateSet(poolDelegate, pendingPoolDelegate_);
    }

    /**************************************************************************************************************************************/
    /*** Globals Admin Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function setActive(bool active_) external override whenNotPaused {
        require(msg.sender == globals(), "PM:SA:NOT_GLOBALS");
        emit SetAsActive(active = active_);
    }

    /**************************************************************************************************************************************/
    /*** Pool Delegate Admin Functions                                                                                                  ***/
    /**************************************************************************************************************************************/

    function addLoanManager(address loanManagerFactory_)
        external override whenNotPaused onlyPoolDelegateOrNotConfigured returns (address loanManager_)
    {
        require(IGlobalsLike(globals()).isInstanceOf("LOAN_MANAGER_FACTORY", loanManagerFactory_), "PM:ALM:INVALID_FACTORY");

        // NOTE: If removing loan managers is allowed in the future, there will be a need to rethink salts here due to collisions.
        loanManager_ = IMapleProxyFactory(loanManagerFactory_).createInstance(
            abi.encode(address(this)),
            keccak256(abi.encode(address(this), loanManagerList.length))
        );

        isLoanManager[loanManager_] = true;

        loanManagerList.push(loanManager_);

        emit LoanManagerAdded(loanManager_);
    }

    function setAllowedLender(address lender_, bool isValid_) external override whenNotPaused onlyPoolDelegate {
        emit AllowedLenderSet(lender_, isValidLender[lender_] = isValid_);
    }

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_)
        external override whenNotPaused onlyPoolDelegateOrNotConfigured
    {
        require(delegateManagementFeeRate_ <= HUNDRED_PERCENT, "PM:SDMFR:OOB");

        emit DelegateManagementFeeRateSet(delegateManagementFeeRate = delegateManagementFeeRate_);
    }

    function setIsLoanManager(address loanManager_, bool isLoanManager_) external override whenNotPaused onlyPoolDelegate {
        emit IsLoanManagerSet(loanManager_, isLoanManager[loanManager_] = isLoanManager_);

        // Check LoanManager is in the list.
        // NOTE: The factory and instance check are not required as the mapping is being updated for a LoanManager that is in the list.
        for (uint256 i_; i_ < loanManagerList.length; ++i_) {
            if (loanManagerList[i_] == loanManager_) return;
        }

        revert("PM:SILM:INVALID_LM");
    }

    function setLiquidityCap(uint256 liquidityCap_) external override whenNotPaused onlyPoolDelegateOrNotConfigured {
        emit LiquidityCapSet(liquidityCap = liquidityCap_);
    }

    function setOpenToPublic() external override whenNotPaused onlyPoolDelegate {
        openToPublic = true;

        emit OpenToPublic();
    }

    function setWithdrawalManager(address withdrawalManager_) external override whenNotPaused onlyIfNotConfigured {
        address factory_ = IMapleProxied(withdrawalManager_).factory();

        require(IGlobalsLike(globals()).isInstanceOf("WITHDRAWAL_MANAGER_FACTORY", factory_), "PM:SWM:INVALID_FACTORY");
        require(IMapleProxyFactory(factory_).isInstance(withdrawalManager_),                  "PM:SWM:INVALID_INSTANCE");

        emit WithdrawalManagerSet(withdrawalManager = withdrawalManager_);
    }

    /**************************************************************************************************************************************/
    /*** Funding Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function requestFunds(address destination_, uint256 principal_) external override whenNotPaused nonReentrant {
        address asset_   = asset;
        address pool_    = pool;
        address factory_ = IMapleProxied(msg.sender).factory();

        IGlobalsLike globals_ = IGlobalsLike(globals());

        // NOTE: Do not need to check isInstance() as the LoanManager is added to the list on `addLoanManager()` or `configure()`.
        require(principal_ != 0,                                         "PM:RF:INVALID_PRINCIPAL");
        require(globals_.isInstanceOf("LOAN_MANAGER_FACTORY", factory_), "PM:RF:INVALID_FACTORY");
        require(IMapleProxyFactory(factory_).isInstance(msg.sender),     "PM:RF:INVALID_INSTANCE");
        require(isLoanManager[msg.sender],                               "PM:RF:NOT_LM");
        require(IERC20Like(pool_).totalSupply() != 0,                    "PM:RF:ZERO_SUPPLY");
        require(_hasSufficientCover(address(globals_), asset_),          "PM:RF:INSUFFICIENT_COVER");

        // Fetching locked liquidity needs to be done prior to transferring the tokens.
        uint256 lockedLiquidity_ = IWithdrawalManagerLike(withdrawalManager).lockedLiquidity();

        // Transfer the required principal.
        require(destination_ != address(0),                                        "PM:RF:INVALID_DESTINATION");
        require(ERC20Helper.transferFrom(asset_, pool_, destination_, principal_), "PM:RF:TRANSFER_FAIL");

        // The remaining liquidity in the pool must be greater or equal to the locked liquidity.
        require(IERC20Like(asset_).balanceOf(pool_) >= lockedLiquidity_, "PM:RF:LOCKED_LIQUIDITY");
    }

    /**************************************************************************************************************************************/
    /*** Loan Default Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function finishCollateralLiquidation(address loan_) external override whenNotPaused nonReentrant onlyPoolDelegateOrGovernor {
        ( uint256 losses_, uint256 platformFees_ ) = ILoanManagerLike(_getLoanManager(loan_)).finishCollateralLiquidation(loan_);

        _handleCover(losses_, platformFees_);

        emit CollateralLiquidationFinished(loan_, losses_);
    }

    function triggerDefault(address loan_, address liquidatorFactory_)
        external override whenNotPaused nonReentrant onlyPoolDelegateOrGovernor
    {
        require(IGlobalsLike(globals()).isInstanceOf("LIQUIDATOR_FACTORY", liquidatorFactory_), "PM:TD:NOT_FACTORY");

        (
            bool    liquidationComplete_,
            uint256 losses_,
            uint256 platformFees_
        ) = ILoanManagerLike(_getLoanManager(loan_)).triggerDefault(loan_, liquidatorFactory_);

        if (!liquidationComplete_) {
            emit CollateralLiquidationTriggered(loan_);
            return;
        }

        _handleCover(losses_, platformFees_);

        emit CollateralLiquidationFinished(loan_, losses_);
    }

    /**************************************************************************************************************************************/
    /*** Pool Exit Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    function processRedeem(uint256 shares_, address owner_, address sender_)
        external override whenNotPaused nonReentrant onlyPool returns (uint256 redeemableShares_, uint256 resultingAssets_)
    {
        require(owner_ == sender_ || IPoolLike(pool).allowance(owner_, sender_) > 0, "PM:PR:NO_ALLOWANCE");

        ( redeemableShares_, resultingAssets_ ) = IWithdrawalManagerLike(withdrawalManager).processExit(shares_, owner_);
        emit RedeemProcessed(owner_, redeemableShares_, resultingAssets_);
    }

    function processWithdraw(uint256 assets_, address owner_, address sender_)
        external override whenNotPaused nonReentrant returns (uint256 redeemableShares_, uint256 resultingAssets_)
    {
        assets_; owner_; sender_; redeemableShares_; resultingAssets_;  // Silence compiler warnings
        require(false, "PM:PW:NOT_ENABLED");
    }

    function removeShares(uint256 shares_, address owner_)
        external override whenNotPaused nonReentrant onlyPool returns (uint256 sharesReturned_)
    {
        emit SharesRemoved(
            owner_,
            sharesReturned_ = IWithdrawalManagerLike(withdrawalManager).removeShares(shares_, owner_)
        );
    }

    function requestRedeem(uint256 shares_, address owner_, address sender_) external override whenNotPaused nonReentrant onlyPool {
        address pool_ = pool;

        require(ERC20Helper.approve(pool_, withdrawalManager, shares_), "PM:RR:APPROVE_FAIL");

        if (sender_ != owner_ && shares_ == 0) {
            require(IPoolLike(pool_).allowance(owner_, sender_) > 0, "PM:RR:NO_ALLOWANCE");
        }

        IWithdrawalManagerLike(withdrawalManager).addShares(shares_, owner_);

        emit RedeemRequested(owner_, shares_);
    }

    function requestWithdraw(uint256 shares_, uint256 assets_, address owner_, address sender_)
        external override whenNotPaused nonReentrant
    {
        shares_; assets_; owner_; sender_;  // Silence compiler warnings
        require(false, "PM:RW:NOT_ENABLED");
    }

    /**************************************************************************************************************************************/
    /*** Pool Delegate Cover Functions                                                                                                  ***/
    /**************************************************************************************************************************************/

    function depositCover(uint256 amount_) external override whenNotPaused {
        require(ERC20Helper.transferFrom(asset, msg.sender, poolDelegateCover, amount_), "PM:DC:TRANSFER_FAIL");
        emit CoverDeposited(amount_);
    }

    function withdrawCover(uint256 amount_, address recipient_) external override whenNotPaused onlyPoolDelegate {
        recipient_ = recipient_ == address(0) ? msg.sender : recipient_;

        IPoolDelegateCoverLike(poolDelegateCover).moveFunds(amount_, recipient_);

        require(
            IERC20Like(asset).balanceOf(poolDelegateCover) >= IGlobalsLike(globals()).minCoverAmount(address(this)),
            "PM:WC:BELOW_MIN"
        );

        emit CoverWithdrawn(amount_);
    }

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function canCall(bytes32 functionId_, address, bytes memory data_)
        external view override returns (bool canCall_, string memory errorMessage_)
    {
        // NOTE: `caller_` param not named to avoid compiler warning.

        if (IGlobalsLike(globals()).isFunctionPaused(msg.sig)) return (false, "PM:CC:PAUSED");

        if (
            functionId_ == "P:redeem"          ||
            functionId_ == "P:withdraw"        ||
            functionId_ == "P:removeShares"    ||
            functionId_ == "P:requestRedeem"   ||
            functionId_ == "P:requestWithdraw"
        ) return (true, "");

        if (functionId_ == "P:deposit") {
            ( uint256 assets_, address receiver_ ) = abi.decode(data_, (uint256, address));
            return _canDeposit(assets_, receiver_, "P:D:");
        }

        if (functionId_ == "P:depositWithPermit") {
            ( uint256 assets_, address receiver_, , , , ) = abi.decode(data_, (uint256, address, uint256, uint8, bytes32, bytes32));
            return _canDeposit(assets_, receiver_, "P:DWP:");
        }

        if (functionId_ == "P:mint") {
            ( uint256 shares_, address receiver_ ) = abi.decode(data_, (uint256, address));
            return _canDeposit(IPoolLike(pool).previewMint(shares_), receiver_, "P:M:");
        }

        if (functionId_ == "P:mintWithPermit") {
            (
                uint256 shares_,
                address receiver_,
                ,
                ,
                ,
                ,
            ) = abi.decode(data_, (uint256, address, uint256, uint256, uint8, bytes32, bytes32));
            return _canDeposit(IPoolLike(pool).previewMint(shares_), receiver_, "P:MWP:");
        }

        if (functionId_ == "P:transfer") {
            ( address recipient_, ) = abi.decode(data_, (address, uint256));
            return _canTransfer(recipient_, "P:T:");
        }

        if (functionId_ == "P:transferFrom") {
            ( , address recipient_, ) = abi.decode(data_, (address, address, uint256));
            return _canTransfer(recipient_, "P:TF:");
        }

        return (false, "PM:CC:INVALID_FUNCTION_ID");
    }

    function factory() external view override returns (address factory_) {
        factory_ = _factory();
    }

    function globals() public view override returns (address globals_) {
        globals_ = IMapleProxyFactory(_factory()).mapleGlobals();
    }

    function governor() public view override returns (address governor_) {
        governor_ = IGlobalsLike(globals()).governor();
    }

    function hasSufficientCover() public view override returns (bool hasSufficientCover_) {
        hasSufficientCover_ = _hasSufficientCover(globals(), asset);
    }

    function implementation() external view override returns (address implementation_) {
        implementation_ = _implementation();
    }

    function loanManagerListLength() external view override returns (uint256 loanManagerListLength_) {
        loanManagerListLength_ = loanManagerList.length;
    }

    function totalAssets() public view override returns (uint256 totalAssets_) {
        totalAssets_ = IERC20Like(asset).balanceOf(pool);

        uint256 length_ = loanManagerList.length;

        for (uint256 i_; i_ < length_;) {
            totalAssets_ += ILoanManagerLike(loanManagerList[i_]).assetsUnderManagement();
            unchecked { ++i_; }
        }
    }

    /**************************************************************************************************************************************/
    /*** LP Token View Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function convertToExitShares(uint256 assets_) public view override returns (uint256 shares_) {
        shares_ = IPoolLike(pool).convertToExitShares(assets_);
    }

    function getEscrowParams(address, uint256 shares_) external view override returns (uint256 escrowShares_, address destination_) {
        // NOTE: `owner_` param not named to avoid compiler warning.
        ( escrowShares_, destination_) = (shares_, address(this));
    }

    function maxDeposit(address receiver_) external view virtual override returns (uint256 maxAssets_) {
        maxAssets_ = _getMaxAssets(receiver_, totalAssets());
    }

    function maxMint(address receiver_) external view virtual override returns (uint256 maxShares_) {
        uint256 totalAssets_ = totalAssets();
        uint256 maxAssets_   = _getMaxAssets(receiver_, totalAssets_);

        maxShares_ = IPoolLike(pool).previewDeposit(maxAssets_);
    }

    function maxRedeem(address owner_) external view virtual override returns (uint256 maxShares_) {
        uint256 lockedShares_ = IWithdrawalManagerLike(withdrawalManager).lockedShares(owner_);
        maxShares_            = IWithdrawalManagerLike(withdrawalManager).isInExitWindow(owner_) ? lockedShares_ : 0;
    }

    function maxWithdraw(address owner_) external view virtual override returns (uint256 maxAssets_) {
        owner_;          // Silence compiler warning
        maxAssets_ = 0;  // NOTE: always returns 0 as withdraw is not implemented
    }

    function previewRedeem(address owner_, uint256 shares_) external view virtual override returns (uint256 assets_) {
        ( , assets_ ) = IWithdrawalManagerLike(withdrawalManager).previewRedeem(owner_, shares_);
    }

    function previewWithdraw(address owner_, uint256 assets_) external view virtual override returns (uint256 shares_) {
        ( , shares_ ) = IWithdrawalManagerLike(withdrawalManager).previewWithdraw(owner_, assets_);
    }

    function unrealizedLosses() public view override returns (uint256 unrealizedLosses_) {
        uint256 length_ = loanManagerList.length;

        for (uint256 i_; i_ < length_;) {
            unrealizedLosses_ += ILoanManagerLike(loanManagerList[i_]).unrealizedLosses();
            unchecked { ++i_; }
        }

        // NOTE: Use minimum to prevent underflows in the case that `unrealizedLosses` includes late interest and `totalAssets` does not.
        unrealizedLosses_ = _min(unrealizedLosses_, totalAssets());
    }

    /**************************************************************************************************************************************/
    /*** Internal Helper Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function _getLoanManager(address loan_) internal view returns (address loanManager_) {
        loanManager_ = ILoanLike(loan_).lender();

        require(isLoanManager[loanManager_], "PM:GLM:INVALID_LOAN_MANAGER");
    }

    function _handleCover(uint256 losses_, uint256 platformFees_) internal {
        address globals_ = globals();

        uint256 availableCover_ =
            IERC20Like(asset).balanceOf(poolDelegateCover) * IGlobalsLike(globals_).maxCoverLiquidationPercent(address(this)) /
            HUNDRED_PERCENT;

        uint256 toTreasury_ = _min(availableCover_,               platformFees_);
        uint256 toPool_     = _min(availableCover_ - toTreasury_, losses_);

        if (toTreasury_ != 0) {
            IPoolDelegateCoverLike(poolDelegateCover).moveFunds(toTreasury_, IGlobalsLike(globals_).mapleTreasury());
        }

        if (toPool_ != 0) {
            IPoolDelegateCoverLike(poolDelegateCover).moveFunds(toPool_, pool);
        }

        emit CoverLiquidated(toTreasury_, toPool_);
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _canDeposit(uint256 assets_, address receiver_, string memory errorPrefix_)
        internal view returns (bool canDeposit_, string memory errorMessage_)
    {
        if (!active)                                    return (false, _formatErrorMessage(errorPrefix_, "NOT_ACTIVE"));
        if (!openToPublic && !isValidLender[receiver_]) return (false, _formatErrorMessage(errorPrefix_, "LENDER_NOT_ALLOWED"));
        if (assets_ + totalAssets() > liquidityCap)     return (false, _formatErrorMessage(errorPrefix_, "DEPOSIT_GT_LIQ_CAP"));

        return (true, "");
    }

    function _canTransfer(address recipient_, string memory errorPrefix_)
        internal view returns (bool canTransfer_, string memory errorMessage_)
    {
        if (!openToPublic && !isValidLender[recipient_]) return (false, _formatErrorMessage(errorPrefix_, "RECIPIENT_NOT_ALLOWED"));

        return (true, "");
    }

    function _formatErrorMessage(string memory errorPrefix_, string memory partialError_)
        internal pure returns (string memory errorMessage_)
    {
        errorMessage_ = string(abi.encodePacked(errorPrefix_, partialError_));
    }

    function _getMaxAssets(address receiver_, uint256 totalAssets_) internal view returns (uint256 maxAssets_) {
        bool    depositAllowed_ = openToPublic || isValidLender[receiver_];
        uint256 liquidityCap_   = liquidityCap;
        maxAssets_              = liquidityCap_ > totalAssets_ && depositAllowed_ ? liquidityCap_ - totalAssets_ : 0;
    }

    function _hasSufficientCover(address globals_, address asset_) internal view returns (bool hasSufficientCover_) {
        hasSufficientCover_ = IERC20Like(asset_).balanceOf(poolDelegateCover) >= IGlobalsLike(globals_).minCoverAmount(address(this));
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    function _revertIfConfigured() internal view {
        require(!configured, "PM:ALREADY_CONFIGURED");
    }

    function _revertIfConfiguredAndNotPoolDelegate() internal view {
        require(!configured || msg.sender == poolDelegate, "PM:NO_AUTH");
    }

    function _revertIfNotPool() internal view {
        require(msg.sender == pool, "PM:NOT_POOL");
    }

    function _revertIfNotPoolDelegate() internal view {
        require(msg.sender == poolDelegate, "PM:NOT_PD");
    }

    function _revertIfNeitherPoolDelegateNorGovernor() internal view {
        require(msg.sender == poolDelegate || msg.sender == governor(), "PM:NOT_PD_OR_GOV");
    }

    function _revertIfPaused() internal view {
        require(!IGlobalsLike(globals()).isFunctionPaused(msg.sig), "PM:PAUSED");
    }

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { IERC20Like } from "./interfaces/IERC20Like.sol";

/**
 * @title Small Library to standardize erc20 token interactions.
 */
library ERC20Helper {

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function transfer(address token_, address to_, uint256 amount_) internal returns (bool success_) {
        return _call(token_, abi.encodeWithSelector(IERC20Like.transfer.selector, to_, amount_));
    }

    function transferFrom(address token_, address from_, address to_, uint256 amount_) internal returns (bool success_) {
        return _call(token_, abi.encodeWithSelector(IERC20Like.transferFrom.selector, from_, to_, amount_));
    }

    function approve(address token_, address spender_, uint256 amount_) internal returns (bool success_) {
        // If setting approval to zero fails, return false.
        if (!_call(token_, abi.encodeWithSelector(IERC20Like.approve.selector, spender_, uint256(0)))) return false;

        // If `amount_` is zero, return true as the previous step already did this.
        if (amount_ == uint256(0)) return true;

        // Return the result of setting the approval to `amount_`.
        return _call(token_, abi.encodeWithSelector(IERC20Like.approve.selector, spender_, amount_));
    }

    function _call(address token_, bytes memory data_) private returns (bool success_) {
        if (token_.code.length == uint256(0)) return false;

        bytes memory returnData;
        ( success_, returnData ) = token_.call(data_);

        return success_ && (returnData.length == uint256(0) || abi.decode(returnData, (bool)));
    }

}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IDefaultImplementationBeacon } from "../../modules/proxy-factory/contracts/interfaces/IDefaultImplementationBeacon.sol";

/// @title A Maple factory for Proxy contracts that proxy MapleProxied implementations.
interface IMapleProxyFactory is IDefaultImplementationBeacon {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   A default version was set.
     *  @param version_ The default version.
     */
    event DefaultVersionSet(uint256 indexed version_);

    /**
     *  @dev   A version of an implementation, at some address, was registered, with an optional initializer.
     *  @param version_               The version registered.
     *  @param implementationAddress_ The address of the implementation.
     *  @param initializer_           The address of the initializer, if any.
     */
    event ImplementationRegistered(uint256 indexed version_, address indexed implementationAddress_, address indexed initializer_);

    /**
     *  @dev   A proxy contract was deployed with some initialization arguments.
     *  @param version_                 The version of the implementation being proxied by the deployed proxy contract.
     *  @param instance_                The address of the proxy contract deployed.
     *  @param initializationArguments_ The arguments used to initialize the proxy contract, if any.
     */
    event InstanceDeployed(uint256 indexed version_, address indexed instance_, bytes initializationArguments_);

    /**
     *  @dev   A instance has upgraded by proxying to a new implementation, with some migration arguments.
     *  @param instance_           The address of the proxy contract.
     *  @param fromVersion_        The initial implementation version being proxied.
     *  @param toVersion_          The new implementation version being proxied.
     *  @param migrationArguments_ The arguments used to migrate, if any.
     */
    event InstanceUpgraded(address indexed instance_, uint256 indexed fromVersion_, uint256 indexed toVersion_, bytes migrationArguments_);

    /**
     *  @dev   The MapleGlobals was set.
     *  @param mapleGlobals_ The address of a Maple Globals contract.
     */
    event MapleGlobalsSet(address indexed mapleGlobals_);

    /**
     *  @dev   An upgrade path was disabled, with an optional migrator contract.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    event UpgradePathDisabled(uint256 indexed fromVersion_, uint256 indexed toVersion_);

    /**
     *  @dev   An upgrade path was enabled, with an optional migrator contract.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the migrator, if any.
     */
    event UpgradePathEnabled(uint256 indexed fromVersion_, uint256 indexed toVersion_, address indexed migrator_);

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev The default version.
     */
    function defaultVersion() external view returns (uint256 defaultVersion_);

    /**
     *  @dev The address of the MapleGlobals contract.
     */
    function mapleGlobals() external view returns (address mapleGlobals_);

    /**
     *  @dev    Whether the upgrade is enabled for a path from a version to another version.
     *  @param  toVersion_   The initial version.
     *  @param  fromVersion_ The destination version.
     *  @return allowed_     Whether the upgrade is enabled.
     */
    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    /**************************************************************************************************************************************/
    /*** State Changing Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Deploys a new instance proxying the default implementation version, with some initialization arguments.
     *          Uses a nonce and `msg.sender` as a salt for the CREATE2 opcode during instantiation to produce deterministic addresses.
     *  @param  arguments_ The initialization arguments to use for the instance deployment, if any.
     *  @param  salt_      The salt to use in the contract creation process.
     *  @return instance_  The address of the deployed proxy contract.
     */
    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    /**
     *  @dev   Enables upgrading from a version to a version of an implementation, with an optional migrator.
     *         Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     *  @param migrator_    The address of the migrator, if any.
     */
    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    /**
     *  @dev   Disables upgrading from a version to a version of a implementation.
     *         Only the Governor can call this function.
     *  @param fromVersion_ The starting version of the upgrade path.
     *  @param toVersion_   The destination version of the upgrade path.
     */
    function disableUpgradePath(uint256 fromVersion_, uint256 toVersion_) external;

    /**
     *  @dev   Registers the address of an implementation contract as a version, with an optional initializer.
     *         Only the Governor can call this function.
     *  @param version_               The version to register.
     *  @param implementationAddress_ The address of the implementation.
     *  @param initializer_           The address of the initializer, if any.
     */
    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    /**
     *  @dev   Sets the default version.
     *         Only the Governor can call this function.
     *  @param version_ The implementation version to set as the default.
     */
    function setDefaultVersion(uint256 version_) external;

    /**
     *  @dev   Sets the Maple Globals contract.
     *         Only the Governor can call this function.
     *  @param mapleGlobals_ The address of a Maple Globals contract.
     */
    function setGlobals(address mapleGlobals_) external;

    /**
     *  @dev   Upgrades the calling proxy contract's implementation, with some migration arguments.
     *  @param toVersion_ The implementation version to upgrade the proxy contract to.
     *  @param arguments_ The migration arguments, if any.
     */
    function upgradeInstance(uint256 toVersion_, bytes calldata arguments_) external;

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the deterministic address of a potential proxy, given some arguments and salt.
     *  @param  arguments_       The initialization arguments to be used when deploying the proxy.
     *  @param  salt_            The salt to be used when deploying the proxy.
     *  @return instanceAddress_ The deterministic address of a potential proxy.
     */
    function getInstanceAddress(bytes calldata arguments_, bytes32 salt_) external view returns (address instanceAddress_);

    /**
     *  @dev    Returns the address of an implementation version.
     *  @param  version_        The implementation version.
     *  @return implementation_ The address of the implementation.
     */
    function implementationOf(uint256 version_) external view returns (address implementation_);

    /**
     *  @dev    Returns if a given address has been deployed by this factory/
     *  @param  instance_   The address to check.
     *  @return isInstance_ A boolean indication if the address has been deployed by this factory.
     */
    function isInstance(address instance_) external view returns (bool isInstance_);

    /**
     *  @dev    Returns the address of a migrator contract for a migration path (from version, to version).
     *          If oldVersion_ == newVersion_, the migrator is an initializer.
     *  @param  oldVersion_ The old version.
     *  @param  newVersion_ The new version.
     *  @return migrator_   The address of a migrator contract.
     */
    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    /**
     *  @dev    Returns the version of an implementation contract.
     *  @param  implementation_ The address of an implementation contract.
     *  @return version_        The version of the implementation contract.
     */
    function versionOf(address implementation_) external view returns (uint256 version_);

}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { IProxied } from "../../modules/proxy-factory/contracts/interfaces/IProxied.sol";

/// @title A Maple implementation that is to be proxied, must implement IMapleProxied.
interface IMapleProxied is IProxied {

    /**
     *  @dev   The instance was upgraded.
     *  @param toVersion_ The new version of the loan.
     *  @param arguments_ The upgrade arguments, if any.
     */
    event Upgraded(uint256 toVersion_, bytes arguments_);

    /**
     *  @dev   Upgrades a contract implementation to a specific version.
     *         Access control logic critical since caller can force a selfdestruct via a malicious `migrator_` which is delegatecalled.
     *  @param toVersion_ The version to upgrade to.
     *  @param arguments_ Some encoded arguments to use for the upgrade.
     */
    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;

import { ProxiedInternals } from "../modules/proxy-factory/contracts/ProxiedInternals.sol";

/// @title A Maple implementation that is to be proxied, will need MapleProxiedInternals.
abstract contract MapleProxiedInternals is ProxiedInternals { }

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPoolManagerStorage } from "../interfaces/IPoolManagerStorage.sol";

abstract contract PoolManagerStorage is IPoolManagerStorage {

    uint256 internal _locked;  // Used when checking for reentrancy.

    address public override poolDelegate;
    address public override pendingPoolDelegate;

    address public override asset;
    address public override pool;

    address public override poolDelegateCover;
    address public override withdrawalManager;

    bool public override active;
    bool public override configured;
    bool public override openToPublic;

    uint256 public override liquidityCap;
    uint256 public override delegateManagementFeeRate;

    mapping(address => bool) public override isLoanManager;
    mapping(address => bool) public override isValidLender;

    address[] public override loanManagerList;

}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IERC20Like {

    function allowance(address owner_, address spender_) external view returns (uint256 allowance_);

    function balanceOf(address account_) external view returns (uint256 balance_);

    function totalSupply() external view returns (uint256 totalSupply_);

}

interface IGlobalsLike {

    function bootstrapMint(address asset_) external view returns (uint256 bootstrapMint_);

    function governor() external view returns (address governor_);

    function isFunctionPaused(bytes4 sig_) external view returns (bool isFunctionPaused_);

    function isInstanceOf(bytes32 instanceId_, address instance_) external view returns (bool isInstance_);

    function isPoolAsset(address asset_) external view returns (bool isPoolAsset_);

    function isPoolDelegate(address account_) external view returns (bool isPoolDelegate_);

    function isPoolDeployer(address poolDeployer_) external view returns (bool isPoolDeployer_);

    function isValidScheduledCall(address caller_, address contract_, bytes32 functionId_, bytes calldata callData_)
        external view
        returns (bool isValid_);

    function mapleTreasury() external view returns (address mapleTreasury_);

    function maxCoverLiquidationPercent(address poolManager_) external view returns (uint256 maxCoverLiquidationPercent_);

    function migrationAdmin() external view returns (address migrationAdmin_);

    function minCoverAmount(address poolManager_) external view returns (uint256 minCoverAmount_);

    function ownedPoolManager(address poolDelegate_) external view returns (address poolManager_);

    function securityAdmin() external view returns (address securityAdmin_);

    function transferOwnedPoolManager(address fromPoolDelegate_, address toPoolDelegate_) external;

    function unscheduleCall(address caller_, bytes32 functionId_, bytes calldata callData_) external;

}

interface ILoanManagerLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

    function finishCollateralLiquidation(address loan_) external returns (uint256 remainingLosses_, uint256 serviceFee_);

    function triggerDefault(address loan_, address liquidatorFactory_)
        external
        returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);

}

interface ILoanLike {

    function lender() external view returns (address lender_);

}

interface IMapleProxyFactoryLike {

    function mapleGlobals() external view returns (address mapleGlobals_);

}

interface IPoolDelegateCoverLike {

    function moveFunds(uint256 amount_, address recipient_) external;

}

interface IPoolLike is IERC20Like {

    function convertToExitShares(uint256 assets_) external view returns (uint256 shares_);

    function previewDeposit(uint256 assets_) external view returns (uint256 shares_);

    function previewMint(uint256 shares_) external view returns (uint256 assets_);

}

interface IPoolManagerLike {

    function addLoanManager(address loanManagerFactory_) external returns (address loanManager_);

    function canCall(bytes32 functionId_, address caller_, bytes memory data_)
        external view
        returns (bool canCall_, string memory errorMessage_);

    function completeConfiguration() external;

    function getEscrowParams(address owner_, uint256 shares_) external view returns (uint256 escrowShares_, address escrow_);

    function maxDeposit(address receiver_) external view returns (uint256 maxAssets_);

    function maxMint(address receiver_) external view returns (uint256 maxShares_);

    function maxRedeem(address owner_) external view returns (uint256 maxShares_);

    function maxWithdraw(address owner_) external view returns (uint256 maxAssets_);

    function pool() external view returns (address pool_);

    function poolDelegateCover() external view returns (address poolDelegateCover_);

    function previewRedeem(address owner_, uint256 shares_) external view returns (uint256 assets_);

    function previewWithdraw(address owner_, uint256 assets_) external view returns (uint256 shares_);

    function processRedeem(uint256 shares_, address owner_, address sender_)
        external
        returns (uint256 redeemableShares_, uint256 resultingAssets_);

    function processWithdraw(uint256 assets_, address owner_, address sender_)
        external
        returns (uint256 redeemableShares_, uint256 resultingAssets_);

    function removeShares(uint256 shares_, address owner_) external returns (uint256 sharesReturned_);

    function requestRedeem(uint256 shares_, address owner_, address sender_) external;

    function requestWithdraw(uint256 shares_, uint256 assets_, address owner_, address sender_) external;

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) external;

    function setLiquidityCap(uint256 liquidityCap_) external;

    function setWithdrawalManager(address withdrawalManager_) external;

    function totalAssets() external view returns (uint256 totalAssets_);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);

}

interface IWithdrawalManagerLike {

    function addShares(uint256 shares_, address owner_) external;

    function isInExitWindow(address owner_) external view returns (bool isInExitWindow_);

    function lockedLiquidity() external view returns (uint256 lockedLiquidity_);

    function lockedShares(address owner_) external view returns (uint256 lockedShares_);

    function previewRedeem(address owner_, uint256 shares) external view returns (uint256 redeemableShares, uint256 resultingAssets_);

    function previewWithdraw(address owner_, uint256 assets_) external view returns (uint256 redeemableAssets_, uint256 resultingShares_);

    function processExit(uint256 shares_, address account_) external returns (uint256 redeemableShares_, uint256 resultingAssets_);

    function removeShares(uint256 shares_, address owner_) external returns (uint256 sharesReturned_);

}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxied } from "../../modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IPoolManagerStorage } from "./IPoolManagerStorage.sol";

interface IPoolManager is IMapleProxied, IPoolManagerStorage {

    /**************************************************************************************************************************************/
    /*** Events                                                                                                                         ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Emitted when a new allowed lender is called.
     *  @param lender_ The address of the new lender.
     *  @param isValid_ Whether the new lender is valid.
     */
    event AllowedLenderSet(address indexed lender_, bool isValid_);

    /**
     *  @dev   Emitted when a collateral liquidations is finished.
     *  @param loan_             The address of the loan.
     *  @param unrealizedLosses_ The amount of unrealized losses.
     */
    event CollateralLiquidationFinished(address indexed loan_, uint256 unrealizedLosses_);

    /**
     *  @dev   Emitted when a collateral liquidations is triggered.
     *  @param loan_ The address of the loan.
     */
    event CollateralLiquidationTriggered(address indexed loan_);

    /**
     *  @dev   Emitted when cover is deposited.
     *  @param amount_ The amount of cover deposited.
     */
    event CoverDeposited(uint256 amount_);

    /**
     *  @dev   Emitted when cover is liquidated in the case of a loan defaulting.
     *  @param toTreasury_ The amount of cover sent to the Treasury.
     *  @param toPool_     The amount of cover sent to the Pool.
     */
    event CoverLiquidated(uint256 toTreasury_, uint256 toPool_);

    /**
     *  @dev   Emitted when cover is withdrawn.
     *  @param amount_ The amount of cover withdrawn.
     */
    event CoverWithdrawn(uint256 amount_);

    /**
     *  @dev   Emitted when a new management fee rate is set.
     *  @param managementFeeRate_ The amount of management fee rate.
     */
    event DelegateManagementFeeRateSet(uint256 managementFeeRate_);

    /**
     *  @dev   Emitted when a loan manager is set as valid.
     *  @param loanManager_   The address of the loan manager.
     *  @param isLoanManager_ Whether the loan manager is valid.
     */
    event IsLoanManagerSet(address indexed loanManager_, bool isLoanManager_);

    /**
     *  @dev   Emitted when a new liquidity cap is set.
     *  @param liquidityCap_ The value of liquidity cap.
     */
    event LiquidityCapSet(uint256 liquidityCap_);

    /**
     *  @dev   Emitted when a new loan manager is added.
     *  @param loanManager_ The address of the new loan manager.
     */
    event LoanManagerAdded(address indexed loanManager_);

    /**
     *  @dev Emitted when a pool is open to public.
     */
    event OpenToPublic();

    /**
     *  @dev   Emitted when the pending pool delegate accepts the ownership transfer.
     *  @param previousDelegate_ The address of the previous delegate.
     *  @param newDelegate_      The address of the new delegate.
     */
    event PendingDelegateAccepted(address indexed previousDelegate_, address indexed newDelegate_);

    /**
     *  @dev   Emitted when the pending pool delegate is set.
     *  @param previousDelegate_ The address of the previous delegate.
     *  @param newDelegate_      The address of the new delegate.
     */
    event PendingDelegateSet(address indexed previousDelegate_, address indexed newDelegate_);

    /**
     *  @dev Emitted when the pool configuration is marked as complete.
     */
    event PoolConfigurationComplete();

    /**
     *  @dev   Emitted when a redemption of shares from the pool is processed.
     *  @param owner_            The owner of the shares.
     *  @param redeemableShares_ The amount of redeemable shares.
     *  @param resultingAssets_  The amount of assets redeemed.
     */
    event RedeemProcessed(address indexed owner_, uint256 redeemableShares_, uint256 resultingAssets_);

    /**
     *  @dev   Emitted when a redemption of shares from the pool is requested.
     *  @param owner_  The owner of the shares.
     *  @param shares_ The amount of redeemable shares.
     */
    event RedeemRequested(address indexed owner_, uint256 shares_);

    /**
     *  @dev   Emitted when a pool is sets to be active or inactive.
     *  @param active_ Whether the pool is active.
     */
    event SetAsActive(bool active_);

    /**
     *  @dev   Emitted when shares are removed from the pool.
     *  @param owner_  The address of the owner of the shares.
     *  @param shares_ The amount of shares removed.
     */
    event SharesRemoved(address indexed owner_, uint256 shares_);

    /**
     *  @dev   Emitted when the withdrawal manager is set.
     *  @param withdrawalManager_ The address of the withdrawal manager.
     */
    event WithdrawalManagerSet(address indexed withdrawalManager_);

    /**
     *  @dev   Emitted when withdrawal of assets from the pool is processed.
     *  @param owner_            The owner of the assets.
     *  @param redeemableShares_ The amount of redeemable shares.
     *  @param resultingAssets_  The amount of assets redeemed.
     */
    event WithdrawalProcessed(address indexed owner_, uint256 redeemableShares_, uint256 resultingAssets_);

    /**************************************************************************************************************************************/
    /*** Ownership Transfer Functions                                                                                                   ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev Accepts the role of pool delegate.
     */
    function acceptPoolDelegate() external;

    /**
     *  @dev   Sets an address as the pending pool delegate.
     *  @param pendingPoolDelegate_ The address of the new pool delegate.
     */
    function setPendingPoolDelegate(address pendingPoolDelegate_) external;

    /**************************************************************************************************************************************/
    /*** Administrative Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Adds a new loan manager.
     *  @param  loanManagerFactory_ The address of the loan manager factory to use.
     *  @return loanManager_        The address of the new loan manager.
     */
    function addLoanManager(address loanManagerFactory_) external returns (address loanManager_);

    /**
     *  @dev Complete the configuration.
     */
    function completeConfiguration() external;

    /**
     *  @dev   Sets a the pool to be active or inactive.
     *  @param active_ Whether the pool is active.
     */
    function setActive(bool active_) external;

    /**
     *  @dev   Sets a new lender as valid or not.
     *  @param lender_  The address of the new lender.
     *  @param isValid_ Whether the new lender is valid.
     */
    function setAllowedLender(address lender_, bool isValid_) external;

    /**
     *  @dev   Sets the value for the delegate management fee rate.
     *  @param delegateManagementFeeRate_ The value for the delegate management fee rate.
     */
    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) external;

    /**
     *  @dev   Sets if the loanManager is valid in the isLoanManager mapping.
     *  @param loanManager_   The address of the loanManager
     *  @param isLoanManager_ Whether the loanManager is valid.
     */
    function setIsLoanManager(address loanManager_, bool isLoanManager_) external;

    /**
     *  @dev   Sets the value for liquidity cap.
     *  @param liquidityCap_ The value for liquidity cap.
     */
    function setLiquidityCap(uint256 liquidityCap_) external;

    /**
     *  @dev Sets pool open to public depositors.
     */
    function setOpenToPublic() external;

    /**
     *  @dev   Sets the address of the withdrawal manager.
     *  @param withdrawalManager_ The address of the withdrawal manager.
     */
    function setWithdrawalManager(address withdrawalManager_) external;

    /**************************************************************************************************************************************/
    /*** Funding Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   LoanManager can request funds from the pool via the poolManager.
     *  @param destination_ The address to send the funds to.
     *  @param principal_   The principal amount to fund the loan with.
     */
    function requestFunds(address destination_, uint256 principal_) external;

    /**************************************************************************************************************************************/
    /*** Liquidation Functions                                                                                                          ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Finishes the collateral liquidation
     *  @param loan_ Loan that had its collateral liquidated.
     */
    function finishCollateralLiquidation(address loan_) external;

    /**
     *  @dev   Triggers the default of a loan.
     *  @param loan_              Loan to trigger the default.
     *  @param liquidatorFactory_ Factory used to deploy the liquidator.
     */
    function triggerDefault(address loan_, address liquidatorFactory_) external;

    /**************************************************************************************************************************************/
    /*** Exit Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Processes a redemptions of shares for assets from the pool.
     *  @param  shares_           The amount of shares to redeem.
     *  @param  owner_            The address of the owner of the shares.
     *  @param  sender_           The address of the sender of the redeem call.
     *  @return redeemableShares_ The amount of shares redeemed.
     *  @return resultingAssets_  The amount of assets withdrawn.
     */
    function processRedeem(uint256 shares_, address owner_, address sender_)
        external
        returns (uint256 redeemableShares_, uint256 resultingAssets_);

    /**
     *  @dev    Processes a redemptions of shares for assets from the pool.
     *  @param  assets_           The amount of assets to withdraw.
     *  @param  owner_            The address of the owner of the shares.
     *  @param  sender_           The address of the sender of the withdraw call.
     *  @return redeemableShares_ The amount of shares redeemed.
     *  @return resultingAssets_  The amount of assets withdrawn.
     */
    function processWithdraw(uint256 assets_, address owner_, address sender_)
        external
        returns (uint256 redeemableShares_, uint256 resultingAssets_);

    /**
     *  @dev    Requests a redemption of shares from the pool.
     *  @param  shares_         The amount of shares to redeem.
     *  @param  owner_          The address of the owner of the shares.
     *  @return sharesReturned_ The amount of shares withdrawn.
     */
    function removeShares(uint256 shares_, address owner_) external returns (uint256 sharesReturned_);

    /**
     *  @dev   Requests a redemption of shares from the pool.
     *  @param shares_ The amount of shares to redeem.
     *  @param owner_  The address of the owner of the shares.
     *  @param sender_ The address of the sender of the shares.
     */
    function requestRedeem(uint256 shares_, address owner_, address sender_) external;

    /**
     *  @dev   Requests a withdrawal of assets from the pool.
     *  @param shares_ The amount of shares to redeem.
     *  @param assets_ The amount of assets to withdraw.
     *  @param owner_  The address of the owner of the shares.
     *  @param sender_ The address of the sender of the shares.
     */
     function requestWithdraw(uint256 shares_, uint256 assets_, address owner_, address sender_) external;

    /**************************************************************************************************************************************/
    /*** Cover Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev   Deposits cover into the pool.
     *  @param amount_ The amount of cover to deposit.
     */
    function depositCover(uint256 amount_) external;

    /**
     *  @dev   Withdraws cover from the pool.
     *  @param amount_    The amount of cover to withdraw.
     *  @param recipient_ The address of the recipient.
     */
    function withdrawCover(uint256 amount_, address recipient_) external;

    /**************************************************************************************************************************************/
    /*** LP Token View Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Returns the amount of exit shares for the input amount.
     *  @param  amount_  Address of the account.
     *  @return shares_  Amount of shares able to be exited.
     */
    function convertToExitShares(uint256 amount_) external view returns (uint256 shares_);

    /**
     *  @dev    Gets the information of escrowed shares.
     *  @param  owner_        The address of the owner of the shares.
     *  @param  shares_       The amount of shares to get the information of.
     *  @return escrowShares_ The amount of escrowed shares.
     *  @return destination_  The address of the destination.
     */
    function getEscrowParams(address owner_, uint256 shares_) external view returns (uint256 escrowShares_, address destination_);

    /**
     *  @dev   Gets the amount of assets that can be deposited.
     *  @param receiver_  The address to check the deposit for.
     *  @param maxAssets_ The maximum amount assets to deposit.
     */
    function maxDeposit(address receiver_) external view returns (uint256 maxAssets_);

    /**
     *  @dev   Gets the amount of shares that can be minted.
     *  @param receiver_  The address to check the mint for.
     *  @param maxShares_ The maximum amount shares to mint.
     */
    function maxMint(address receiver_) external view returns (uint256 maxShares_);

    /**
     *  @dev   Gets the amount of shares that can be redeemed.
     *  @param owner_     The address to check the redemption for.
     *  @param maxShares_ The maximum amount shares to redeem.
     */
    function maxRedeem(address owner_) external view returns (uint256 maxShares_);

    /**
     *  @dev   Gets the amount of assets that can be withdrawn.
     *  @param owner_     The address to check the withdraw for.
     *  @param maxAssets_ The maximum amount assets to withdraw.
     */
    function maxWithdraw(address owner_) external view returns (uint256 maxAssets_);

    /**
     *  @dev    Gets the amount of shares that can be redeemed.
     *  @param  owner_   The address to check the redemption for.
     *  @param  shares_  The amount of requested shares to redeem.
     *  @return assets_  The amount of assets that will be returned for `shares_`.
     */
    function previewRedeem(address owner_, uint256 shares_) external view returns (uint256 assets_);

    /**
     *  @dev    Gets the amount of assets that can be redeemed.
     *  @param  owner_   The address to check the redemption for.
     *  @param  assets_  The amount of requested shares to redeem.
     *  @return shares_  The amount of assets that will be returned for `assets_`.
     */
    function previewWithdraw(address owner_, uint256 assets_) external view returns (uint256 shares_);

    /**************************************************************************************************************************************/
    /*** View Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    /**
     *  @dev    Checks if a scheduled call can be executed.
     *  @param  functionId_   The function to check.
     *  @param  caller_       The address of the caller.
     *  @param  data_         The data of the call.
     *  @return canCall_      True if the call can be executed, false otherwise.
     *  @return errorMessage_ The error message if the call cannot be executed.
     */
    function canCall(bytes32 functionId_, address caller_, bytes memory data_)
        external view
        returns (bool canCall_, string memory errorMessage_);

    /**
     *  @dev    Gets the address of the globals.
     *  @return globals_ The address of the globals.
     */
    function globals() external view returns (address globals_);

    /**
     *  @dev    Gets the address of the governor.
     *  @return governor_ The address of the governor.
     */
    function governor() external view returns (address governor_);

    /**
     *  @dev    Returns if pool has sufficient cover.
     *  @return hasSufficientCover_ True if pool has sufficient cover.
     */
    function hasSufficientCover() external view returns (bool hasSufficientCover_);

    /**
     *  @dev    Returns the length of the `loanManagerList`.
     *  @return loanManagerListLength_ The length of the `loanManagerList`.
     */
    function loanManagerListLength() external view returns (uint256 loanManagerListLength_);

    /**
     *  @dev    Returns the amount of total assets.
     *  @return totalAssets_ Amount of of total assets.
     */
    function totalAssets() external view returns (uint256 totalAssets_);

    /**
     *  @dev    Returns the amount unrealized losses.
     *  @return unrealizedLosses_ Amount of unrealized losses.
     */
    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

/// @title Interface of the ERC20 standard as needed by ERC20Helper.
interface IERC20Like {

    function approve(address spender_, uint256 amount_) external returns (bool success_);

    function transfer(address recipient_, uint256 amount_) external returns (bool success_);

    function transferFrom(address owner_, address recipient_, uint256 amount_) external returns (bool success_);

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

/// @title An beacon that provides a default implementation for proxies, must implement IDefaultImplementationBeacon.
interface IDefaultImplementationBeacon {

    /// @dev The address of an implementation for proxies.
    function defaultImplementation() external view returns (address defaultImplementation_);

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

/// @title An implementation that is to be proxied, must implement IProxied.
interface IProxied {

    /**
     *  @dev The address of the proxy factory.
     */
    function factory() external view returns (address factory_);

    /**
     *  @dev The address of the implementation contract being proxied.
     */
    function implementation() external view returns (address implementation_);

    /**
     *  @dev   Modifies the proxy's implementation address.
     *  @param newImplementation_ The address of an implementation contract.
     */
    function setImplementation(address newImplementation_) external;

    /**
     *  @dev   Modifies the proxy's storage by delegate-calling a migrator contract with some arguments.
     *         Access control logic critical since caller can force a selfdestruct via a malicious `migrator_` which is delegatecalled.
     *  @param migrator_  The address of a migrator contract.
     *  @param arguments_ Some encoded arguments to use for the migration.
     */
    function migrate(address migrator_, bytes calldata arguments_) external;

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { SlotManipulatable } from "./SlotManipulatable.sol";

/// @title An implementation that is to be proxied, will need ProxiedInternals.
abstract contract ProxiedInternals is SlotManipulatable {

    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.factory') - 1`.
    bytes32 private constant FACTORY_SLOT = bytes32(0x7a45a402e4cb6e08ebc196f20f66d5d30e67285a2a8aa80503fa409e727a4af1);

    /// @dev Storage slot with the address of the current factory. `keccak256('eip1967.proxy.implementation') - 1`.
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);

    /// @dev Delegatecalls to a migrator contract to manipulate storage during an initialization or migration.
    function _migrate(address migrator_, bytes calldata arguments_) internal virtual returns (bool success_) {
        uint256 size;

        assembly {
            size := extcodesize(migrator_)
        }

        if (size == uint256(0)) return false;

        ( success_, ) = migrator_.delegatecall(arguments_);
    }

    /// @dev Sets the factory address in storage.
    function _setFactory(address factory_) internal virtual returns (bool success_) {
        _setSlotValue(FACTORY_SLOT, bytes32(uint256(uint160(factory_))));
        return true;
    }

    /// @dev Sets the implementation address in storage.
    function _setImplementation(address implementation_) internal virtual returns (bool success_) {
        _setSlotValue(IMPLEMENTATION_SLOT, bytes32(uint256(uint160(implementation_))));
        return true;
    }

    /// @dev Returns the factory address.
    function _factory() internal view virtual returns (address factory_) {
        return address(uint160(uint256(_getSlotValue(FACTORY_SLOT))));
    }

    /// @dev Returns the implementation address.
    function _implementation() internal view virtual returns (address implementation_) {
        return address(uint160(uint256(_getSlotValue(IMPLEMENTATION_SLOT))));
    }

}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface IPoolManagerStorage {

    /**
     *  @dev    Returns whether or not a pool is active.
     *  @return active_ True if the pool is active.
     */
    function active() external view returns (bool active_);

    /**
     *  @dev    Gets the address of the funds asset.
     *  @return asset_ The address of the funds asset.
     */
    function asset() external view returns (address asset_);

    /**
     *  @dev    Returns whether or not a pool is configured.
     *  @return configured_ True if the pool is configured.
     */
    function configured() external view returns (bool configured_);

    /**
     *  @dev    Gets the delegate management fee rate.
     *  @return delegateManagementFeeRate_ The value for the delegate management fee rate.
     */
    function delegateManagementFeeRate() external view returns (uint256 delegateManagementFeeRate_);

    /**
     *  @dev    Returns whether or not the given address is a loan manager.
     *  @param  loan_          The address of the loan.
     *  @return isLoanManager_ True if the address is a loan manager.
     */
    function isLoanManager(address loan_) external view returns (bool isLoanManager_);

    /**
     *  @dev    Returns whether or not the given address is a valid lender.
     *  @param  lender_        The address of the lender.
     *  @return isValidLender_ True if the address is a valid lender.
     */
    function isValidLender(address lender_) external view returns (bool isValidLender_);

    /**
     *  @dev    Gets the liquidity cap for the pool.
     *  @return liquidityCap_ The liquidity cap for the pool.
     */
    function liquidityCap() external view returns (uint256 liquidityCap_);

    /**
     *  @dev    Gets the address of the loan manager in the list.
     *  @param  index_       The index to get the address of.
     *  @return loanManager_ The address in the list.
     */
    function loanManagerList(uint256 index_) external view returns (address loanManager_);

    /**
     *  @dev    Returns whether or not a pool is open to public deposits.
     *  @return openToPublic_ True if the pool is open to public deposits.
     */
    function openToPublic() external view returns (bool openToPublic_);

    /**
     *  @dev    Gets the address of the pending pool delegate.
     *  @return pendingPoolDelegate_ The address of the pending pool delegate.
     */
    function pendingPoolDelegate() external view returns (address pendingPoolDelegate_);

    /**
     *  @dev    Gets the address of the pool.
     *  @return pool_ The address of the pool.
     */
    function pool() external view returns (address pool_);

    /**
     *  @dev    Gets the address of the pool delegate.
     *  @return poolDelegate_ The address of the pool delegate.
     */
    function poolDelegate() external view returns (address poolDelegate_);

    /**
     *  @dev    Gets the address of the pool delegate cover.
     *  @return poolDelegateCover_ The address of the pool delegate cover.
     */
    function poolDelegateCover() external view returns (address poolDelegateCover_);

    /**
     *  @dev    Gets the address of the withdrawal manager.
     *  @return withdrawalManager_ The address of the withdrawal manager.
     */
    function withdrawalManager() external view returns (address withdrawalManager_);

}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

abstract contract SlotManipulatable {

    function _getReferenceTypeSlot(bytes32 slot_, bytes32 key_) internal pure returns (bytes32 value_) {
        return keccak256(abi.encodePacked(key_, slot_));
    }

    function _getSlotValue(bytes32 slot_) internal view returns (bytes32 value_) {
        assembly {
            value_ := sload(slot_)
        }
    }

    function _setSlotValue(bytes32 slot_, bytes32 value_) internal {
        assembly {
            sstore(slot_, value_)
        }
    }

}