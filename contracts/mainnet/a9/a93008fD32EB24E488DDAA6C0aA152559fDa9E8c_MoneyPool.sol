// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import './libraries/DataStruct.sol';

import './logic/Index.sol';
import './logic/Rate.sol';
import './logic/Validation.sol';
import './logic/AssetBond.sol';

import './interfaces/ILToken.sol';
import './interfaces/IDToken.sol';
import './interfaces/IMoneyPool.sol';
import './interfaces/IIncentivePool.sol';
import './interfaces/ITokenizer.sol';

import './MoneyPoolStorage.sol';

/**
 * @title Main contract for ELYFI version 1.
 * @author ELYSIA
 * @notice This is the first version of ELYFI. ELYFI has various contract interactions centered
 * on the Money Pool Contract. Several tokens are issued or destroyed to indicate the status of
 * participants, and all issuance and burn processes are carried out through the Money Pool Contract.
 * The depositor and borrower should approve the ELYFI moneypool contract to move their AssetBond token
 * or ERC20 tokens on their behalf.
 * @dev Only admin can modify the variables and state of the moneypool
 **/
contract MoneyPool is IMoneyPool, MoneyPoolStorage {
  using SafeERC20 for IERC20;
  using Index for DataStruct.ReserveData;
  using Validation for DataStruct.ReserveData;
  using Rate for DataStruct.ReserveData;
  using AssetBond for DataStruct.AssetBondData;

  constructor(uint256 maxReserveCount_, address connector) {
    _connector = IConnector(connector);
    _maxReserveCount = maxReserveCount_;
    _reserveCount += 1;
  }

  /************ MoneyPool Deposit Functions ************/

  /**
   * @notice By depositing virtual assets in the MoneyPool and supply liquidity, depositors can receive
   * interest accruing from the MoneyPool.The return on the deposit arises from the interest on real asset
   * backed loans. MoneyPool depositors who deposit certain cryptoassets receives LTokens equivalent to
   * the deposit amount. LTokens are backed by cryptoassets deposited in the MoneyPool in a 1:1 ratio.
   * @dev Deposits an amount of underlying asset and receive corresponding LTokens.
   * @param asset The address of the underlying asset to deposit
   * @param account The address that will receive the LToken
   * @param amount Deposit amount
   **/
  function deposit(
    address asset,
    address account,
    uint256 amount
  ) external override {
    DataStruct.ReserveData storage reserve = _reserves[asset];

    Validation.validateDeposit(reserve, amount);

    reserve.updateState(asset);

    reserve.updateRates(asset, amount, 0);

    IERC20(asset).safeTransferFrom(msg.sender, reserve.lTokenAddress, amount);

    ILToken(reserve.lTokenAddress).mint(account, amount, reserve.lTokenInterestIndex);

    emit Deposit(asset, account, amount);
  }

  /**
   * @notice The depositors can seize their virtual assets deposited in the MoneyPool whenever they wish.
   * @dev Withdraws an amount of underlying asset from the reserve and burns the corresponding lTokens.
   * @param asset The address of the underlying asset to withdraw
   * @param account The address that will receive the underlying asset
   * @param amount Withdrawl amount
   **/
  function withdraw(
    address asset,
    address account,
    uint256 amount
  ) external override {
    DataStruct.ReserveData storage reserve = _reserves[asset];

    uint256 userLTokenBalance = ILToken(reserve.lTokenAddress).balanceOf(msg.sender);

    uint256 amountToWithdraw = amount;

    if (amount == type(uint256).max) {
      amountToWithdraw = userLTokenBalance;
    }

    Validation.validateWithdraw(reserve, asset, amountToWithdraw, userLTokenBalance);

    reserve.updateState(asset);

    reserve.updateRates(asset, 0, amountToWithdraw);

    ILToken(reserve.lTokenAddress).burn(
      msg.sender,
      account,
      amountToWithdraw,
      reserve.lTokenInterestIndex
    );

    emit Withdraw(asset, msg.sender, account, amountToWithdraw);
  }

  /************ AssetBond Formation Functions ************/

  /**
   * @notice The collateral service provider can take out a loan of value equivalent to the principal
   * recorded in the asset bond data. As asset bonds are deposited as collateral in the Money Pool
   * and loans are made, financial services that link real assets and cryptoassets can be achieved.
   * @dev Transfer asset bond from the collateral service provider to the moneypool and mint dTokens
   *  corresponding to principal. After that, transfer the underlying asset
   * @param asset The address of the underlying asset to withdraw
   * @param tokenId The id of the token to collateralize
   **/
  function borrow(address asset, uint256 tokenId) external override {
    require(_connector.isCollateralServiceProvider(msg.sender), 'OnlyCollateralServiceProvider');
    DataStruct.ReserveData storage reserve = _reserves[asset];
    DataStruct.AssetBondData memory assetBond = ITokenizer(reserve.tokenizerAddress)
    .getAssetBondData(tokenId);

    uint256 borrowAmount = assetBond.principal;
    address receiver = assetBond.borrower;

    Validation.validateBorrow(reserve, assetBond, asset, borrowAmount);

    reserve.updateState(asset);

    ITokenizer(reserve.tokenizerAddress).collateralizeAssetBond(
      msg.sender,
      tokenId,
      borrowAmount,
      reserve.borrowAPY
    );

    IDToken(reserve.dTokenAddress).mint(msg.sender, receiver, borrowAmount, reserve.borrowAPY);

    reserve.updateRates(asset, 0, borrowAmount);

    ILToken(reserve.lTokenAddress).transferUnderlyingTo(receiver, borrowAmount);

    emit Borrow(asset, msg.sender, receiver, tokenId, reserve.borrowAPY, borrowAmount);
  }

  /**
   * @notice repays an amount of underlying asset from the reserve and burns the corresponding lTokens.
   * @dev Transfer total repayment of the underlying asset from msg.sender to the moneypool and
   * burn the corresponding amount of dTokens. Then release the asset bond token which is locked
   * in the moneypool and transfer it to the borrower. The total amount of transferred underlying asset
   * is the sum of the fee on the collateral service provider and debt on the moneypool
   * @param asset The address of the underlying asset to repay
   * @param tokenId The id of the token to retrieve
   **/
  function repay(address asset, uint256 tokenId) external override {
    DataStruct.ReserveData storage reserve = _reserves[asset];
    DataStruct.AssetBondData memory assetBond = ITokenizer(reserve.tokenizerAddress)
    .getAssetBondData(tokenId);

    Validation.validateRepay(reserve, assetBond);

    (uint256 accruedDebtOnMoneyPool, uint256 feeOnCollateralServiceProvider) = assetBond
    .getAssetBondDebtData();

    uint256 totalRetrieveAmount = accruedDebtOnMoneyPool + feeOnCollateralServiceProvider;

    reserve.updateState(asset);

    IERC20(asset).safeTransferFrom(msg.sender, reserve.lTokenAddress, totalRetrieveAmount);

    IDToken(reserve.dTokenAddress).burn(assetBond.borrower, accruedDebtOnMoneyPool);

    reserve.updateRates(asset, totalRetrieveAmount, 0);

    ITokenizer(reserve.tokenizerAddress).releaseAssetBond(assetBond.borrower, tokenId);

    ILToken(reserve.lTokenAddress).mint(
      assetBond.collateralServiceProvider,
      feeOnCollateralServiceProvider,
      reserve.lTokenInterestIndex
    );

    emit Repay(
      asset,
      assetBond.borrower,
      tokenId,
      accruedDebtOnMoneyPool,
      feeOnCollateralServiceProvider
    );
  }

  function liquidate(address asset, uint256 tokenId) external override {
    require(_connector.isCollateralServiceProvider(msg.sender), 'OnlyCollateralServiceProvider');
    DataStruct.ReserveData storage reserve = _reserves[asset];
    DataStruct.AssetBondData memory assetBond = ITokenizer(reserve.tokenizerAddress)
    .getAssetBondData(tokenId);

    Validation.validateLiquidation(reserve, assetBond);

    (uint256 accruedDebtOnMoneyPool, uint256 feeOnCollateralServiceProvider) = assetBond
    .getAssetBondLiquidationData();

    uint256 totalLiquidationAmount = accruedDebtOnMoneyPool + feeOnCollateralServiceProvider;

    reserve.updateState(asset);

    IDToken(reserve.dTokenAddress).burn(assetBond.borrower, accruedDebtOnMoneyPool);

    reserve.updateRates(asset, totalLiquidationAmount, 0);

    IERC20(asset).safeTransferFrom(msg.sender, reserve.lTokenAddress, totalLiquidationAmount);

    ITokenizer(reserve.tokenizerAddress).liquidateAssetBond(msg.sender, tokenId);

    ILToken(reserve.lTokenAddress).mint(
      assetBond.collateralServiceProvider,
      feeOnCollateralServiceProvider,
      reserve.lTokenInterestIndex
    );

    emit Liquidation(
      asset,
      assetBond.borrower,
      tokenId,
      accruedDebtOnMoneyPool,
      feeOnCollateralServiceProvider
    );
  }

  /************ View Functions ************/

  /**
   * @notice LToken Index is an indicator of interest occurring and accrued to liquidity providers
   * who have provided liquidity to the Money Pool. LToken Index is calculated every time user activities
   * occur in the Money Pool, such as loans and repayments by Money Pool participants.
   * @param asset The address of the underlying asset of the reserve
   * @return The LToken interest index of reserve
   */
  function getLTokenInterestIndex(address asset) external view override returns (uint256) {
    return _reserves[asset].getLTokenInterestIndex();
  }

  /**
   * @dev Returns the reserveData struct of underlying asset
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset)
    external
    view
    override
    returns (DataStruct.ReserveData memory)
  {
    return _reserves[asset];
  }

  /************ Configuration Functions ************/

  function addNewReserve(
    address asset,
    address lToken,
    address dToken,
    address interestModel,
    address tokenizer,
    address incentivePool,
    uint256 moneyPoolFactor_
  ) external override onlyMoneyPoolAdmin {
    DataStruct.ReserveData memory newReserveData = DataStruct.ReserveData({
      moneyPoolFactor: moneyPoolFactor_,
      lTokenInterestIndex: WadRayMath.ray(),
      borrowAPY: 0,
      depositAPY: 0,
      lastUpdateTimestamp: block.timestamp,
      lTokenAddress: lToken,
      dTokenAddress: dToken,
      interestModelAddress: interestModel,
      tokenizerAddress: tokenizer,
      id: 0,
      isPaused: false,
      isActivated: true
    });

    _reserves[asset] = newReserveData;
    _addNewReserveToList(asset);

    IIncentivePool(incentivePool).initializeIncentivePool(lToken);

    emit NewReserve(
      asset,
      lToken,
      dToken,
      interestModel,
      tokenizer,
      incentivePool,
      moneyPoolFactor_
    );
  }

  function _addNewReserveToList(address asset) internal {
    uint256 reserveCount = _reserveCount;

    require(reserveCount < _maxReserveCount, 'MaxReserveCountExceeded');

    require(_reserves[asset].id == 0, 'DigitalAssetAlreadyAdded');

    _reserves[asset].id = uint8(reserveCount);
    _reservesList[reserveCount] = asset;

    _reserveCount = reserveCount + 1;
  }

  function deactivateMoneyPool(address asset) external onlyMoneyPoolAdmin {
    _reserves[asset].isActivated = false;
  }

  function activateMoneyPool(address asset) external onlyMoneyPoolAdmin {
    _reserves[asset].isActivated = true;
  }

  function pauseMoneyPool(address asset) external onlyMoneyPoolAdmin {
    _reserves[asset].isPaused = true;
  }

  function unPauseMoneyPool(address asset) external onlyMoneyPoolAdmin {
    _reserves[asset].isPaused = false;
  }

  function updateIncentivePool(address asset, address newIncentivePool)
    external
    onlyMoneyPoolAdmin
  {
    DataStruct.ReserveData storage reserve = _reserves[asset];
    ILToken(reserve.lTokenAddress).updateIncentivePool(newIncentivePool);
  }

  modifier onlyMoneyPoolAdmin {
    require(_connector.isMoneyPoolAdmin(msg.sender), 'OnlyMoneyPoolAdmin');
    _;
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
pragma solidity 0.8.3;

library DataStruct {
  /**
    @notice The main reserve data struct.
   */
  struct ReserveData {
    uint256 moneyPoolFactor;
    uint256 lTokenInterestIndex;
    uint256 borrowAPY;
    uint256 depositAPY;
    uint256 lastUpdateTimestamp;
    address lTokenAddress;
    address dTokenAddress;
    address interestModelAddress;
    address tokenizerAddress;
    uint8 id;
    bool isPaused;
    bool isActivated;
  }

  /**
   * @notice The asset bond data struct.
   * @param ipfsHash The IPFS hash that contains the informations and contracts
   * between Collateral Service Provider and lender.
   * @param maturityTimestamp The amount of time measured in seconds that can elapse
   * before the NPL company liquidate the loan and seize the asset bond collateral.
   * @param borrower The address of the borrower.
   */
  struct AssetBondData {
    AssetBondState state;
    address borrower;
    address signer;
    address collateralServiceProvider;
    uint256 principal;
    uint256 debtCeiling;
    uint256 couponRate;
    uint256 interestRate;
    uint256 delinquencyRate;
    uint256 loanStartTimestamp;
    uint256 collateralizeTimestamp;
    uint256 maturityTimestamp;
    uint256 liquidationTimestamp;
    string ipfsHash; // refactor : gas
    string signerOpinionHash;
  }

  struct AssetBondIdData {
    uint256 nonce;
    uint256 countryCode;
    uint256 collateralServiceProviderIdentificationNumber;
    uint256 collateralLatitude;
    uint256 collateralLatitudeSign;
    uint256 collateralLongitude;
    uint256 collateralLongitudeSign;
    uint256 collateralDetail;
    uint256 collateralCategory;
    uint256 productNumber;
  }

  /**
    @notice The states of asset bond
    * EMPTY: After
    * SETTLED:
    * CONFIRMED:
    * COLLATERALIZED:
    * DELINQUENT:
    * REDEEMED:
    * LIQUIDATED:
   */
  enum AssetBondState {
    EMPTY,
    SETTLED,
    CONFIRMED,
    COLLATERALIZED,
    DELINQUENT,
    REDEEMED,
    LIQUIDATED
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';
import '../libraries/Math.sol';

library Index {
  using WadRayMath for uint256;
  using Index for DataStruct.ReserveData;

  event LTokenIndexUpdated(address indexed asset, uint256 lTokenIndex, uint256 lastUpdateTimestamp);

  /**
   * @dev Returns the ongoing normalized income for the reserve
   * A value of 1e27 means there is no income. As time passes, the income is accrued
   * A value of 2*1e27 means for each unit of asset one unit of income has been accrued
   * @param reserve The reserve object
   * @return the normalized income. expressed in ray
   **/
  function getLTokenInterestIndex(DataStruct.ReserveData storage reserve)
    public
    view
    returns (uint256)
  {
    uint256 lastUpdateTimestamp = reserve.lastUpdateTimestamp;

    // strict equality is not dangerous here
    // divide-before-multiply dangerous-strict-equalities
    if (lastUpdateTimestamp == block.timestamp) {
      return reserve.lTokenInterestIndex;
    }

    uint256 newIndex = Math
    .calculateLinearInterest(reserve.depositAPY, lastUpdateTimestamp, block.timestamp)
    .rayMul(reserve.lTokenInterestIndex);

    return newIndex;
  }

  /**
   * @dev Updates the reserve indexes and the timestamp
   * @param reserve The reserve to be updated
   **/
  function updateState(DataStruct.ReserveData storage reserve, address asset) internal {
    if (reserve.depositAPY == 0) {
      reserve.lastUpdateTimestamp = block.timestamp;
      return;
    }

    reserve.lTokenInterestIndex = getLTokenInterestIndex(reserve);
    reserve.lastUpdateTimestamp = block.timestamp;

    emit LTokenIndexUpdated(asset, reserve.lTokenInterestIndex, reserve.lastUpdateTimestamp);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';
import '../libraries/Math.sol';

import '../interfaces/ILToken.sol';
import '../interfaces/IDToken.sol';
import '../interfaces/ITokenizer.sol';
import '../interfaces/IInterestRateModel.sol';

library Rate {
  using WadRayMath for uint256;
  using Rate for DataStruct.ReserveData;

  event RatesUpdated(
    address indexed underlyingAssetAddress,
    uint256 lTokenIndex,
    uint256 borrowAPY,
    uint256 depositAPY,
    uint256 totalBorrow,
    uint256 totalDeposit
  );

  struct UpdateRatesLocalVars {
    uint256 totalDToken;
    uint256 newBorrowAPY;
    uint256 newDepositAPY;
    uint256 averageBorrowAPY;
    uint256 totalVariableDebt;
  }

  function updateRates(
    DataStruct.ReserveData storage reserve,
    address underlyingAssetAddress,
    uint256 depositAmount,
    uint256 borrowAmount
  ) public {
    UpdateRatesLocalVars memory vars;

    vars.totalDToken = IDToken(reserve.dTokenAddress).totalSupply();

    vars.averageBorrowAPY = IDToken(reserve.dTokenAddress).getTotalAverageRealAssetBorrowRate();

    uint256 lTokenAssetBalance = IERC20(underlyingAssetAddress).balanceOf(reserve.lTokenAddress);
    (vars.newBorrowAPY, vars.newDepositAPY) = IInterestRateModel(reserve.interestModelAddress)
    .calculateRates(
      lTokenAssetBalance,
      vars.totalDToken,
      depositAmount,
      borrowAmount,
      reserve.moneyPoolFactor
    );

    reserve.borrowAPY = vars.newBorrowAPY;
    reserve.depositAPY = vars.newDepositAPY;

    emit RatesUpdated(
      underlyingAssetAddress,
      reserve.lTokenInterestIndex,
      vars.newBorrowAPY,
      vars.newDepositAPY,
      vars.totalDToken,
      lTokenAssetBalance + depositAmount - borrowAmount + vars.totalDToken
    );
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';
import '../libraries/Math.sol';

import '../interfaces/ILToken.sol';

library Validation {
  using WadRayMath for uint256;
  using Validation for DataStruct.ReserveData;

  /**
   * @dev Validate Deposit
   * Check reserve state
   * @param reserve The reserve object
   * @param amount Deposit amount
   **/
  function validateDeposit(DataStruct.ReserveData storage reserve, uint256 amount) public view {
    require(amount != 0, 'InvalidAmount');
    require(!reserve.isPaused, 'ReservePaused');
    require(reserve.isActivated, 'ReserveInactivated');
  }

  /**
   * @dev Validate Withdraw
   * Check reserve state
   * Check user amount
   * Check user total debt(later)
   * @param reserve The reserve object
   * @param amount Withdraw amount
   **/
  function validateWithdraw(
    DataStruct.ReserveData storage reserve,
    address asset,
    uint256 amount,
    uint256 userLTokenBalance
  ) public view {
    require(amount != 0, 'InvalidAmount');
    require(!reserve.isPaused, 'ReservePaused');
    require(reserve.isActivated, 'ReserveInactivated');
    require(amount <= userLTokenBalance, 'InsufficientBalance');
    uint256 availableLiquidity = IERC20(asset).balanceOf(reserve.lTokenAddress);
    require(availableLiquidity >= amount, 'NotEnoughLiquidity');
  }

  function validateBorrow(
    DataStruct.ReserveData storage reserve,
    DataStruct.AssetBondData memory assetBond,
    address asset,
    uint256 borrowAmount
  ) public view {
    require(!reserve.isPaused, 'ReservePaused');
    require(reserve.isActivated, 'ReserveInactivated');
    require(assetBond.state == DataStruct.AssetBondState.CONFIRMED, 'OnlySignedTokenBorrowAllowed');
    require(msg.sender == assetBond.collateralServiceProvider, 'OnlyOwnerBorrowAllowed');
    uint256 availableLiquidity = IERC20(asset).balanceOf(reserve.lTokenAddress);
    require(availableLiquidity >= borrowAmount, 'NotEnoughLiquidity');
    require(block.timestamp >= assetBond.loanStartTimestamp, 'NotTimeForLoanStart');
    require(assetBond.loanStartTimestamp + 18 hours >= block.timestamp, 'TimeOutForCollateralize');
  }

  function validateLTokenTrasfer() internal pure {}

  function validateRepay(
    DataStruct.ReserveData storage reserve,
    DataStruct.AssetBondData memory assetBond
  ) public view {
    require(reserve.isActivated, 'ReserveInactivated');
    require(block.timestamp < assetBond.liquidationTimestamp, 'LoanExpired');
    require(
      (assetBond.state == DataStruct.AssetBondState.COLLATERALIZED ||
        assetBond.state == DataStruct.AssetBondState.DELINQUENT),
      'NotRepayableState'
    );
  }

  function validateLiquidation(
    DataStruct.ReserveData storage reserve,
    DataStruct.AssetBondData memory assetBond
  ) public view {
    require(reserve.isActivated, 'ReserveInactivated');
    require(assetBond.state == DataStruct.AssetBondState.LIQUIDATED, 'NotLiquidatbleState');
  }

  function validateSignAssetBond(DataStruct.AssetBondData storage assetBond) public view {
    require(assetBond.state == DataStruct.AssetBondState.SETTLED, 'OnlySettledTokenSignAllowed');
    require(assetBond.signer == msg.sender, 'NotAllowedSigner');
  }

  function validateSettleAssetBond(DataStruct.AssetBondData memory assetBond) public view {
    require(block.timestamp < assetBond.loanStartTimestamp, 'OnlySettledSigned');
    require(assetBond.loanStartTimestamp != assetBond.maturityTimestamp, 'LoanDurationInvalid');
  }

  function validateTokenId(DataStruct.AssetBondIdData memory idData) internal pure {
    require(idData.collateralLatitude < 9000000, 'InvaildLatitude');
    require(idData.collateralLongitude < 18000000, 'InvaildLongitude');
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';
import '../libraries/Math.sol';
import '../libraries/WadRayMath.sol';
import '../libraries/TimeConverter.sol';

library AssetBond {
  using WadRayMath for uint256;
  using AssetBond for DataStruct.AssetBondData;

  uint256 constant NONCE = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC00;
  uint256 constant COUNTRY_CODE =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFC003FF;
  uint256 constant COLLATERAL_SERVICE_PROVIDER_IDENTIFICATION_NUMBER =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000000003FFFFF;
  uint256 constant COLLATERAL_LATITUDE =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000000FFFFFFFFFFFFFFFFFF;
  uint256 constant COLLATERAL_LATITUDE_SIGNS =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFF;
  uint256 constant COLLATERAL_LONGITUDE =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE0000001FFFFFFFFFFFFFFFFFFFFFFFFF;
  uint256 constant COLLATERAL_LONGITUDE_SIGNS =
    0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
  uint256 constant COLLATERAL_DETAILS =
    0xFFFFFFFFFFFFFFFFFFFFFC0000000003FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
  uint256 constant COLLATERAL_CATEGORY =
    0xFFFFFFFFFFFFFFFFFFF003FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
  uint256 constant PRODUCT_NUMBER =
    0xFFFFFFFFFFFFFFFFC00FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

  uint256 constant NONCE_START = 0;
  uint256 constant COUNTRY_CODE_START = 10;
  uint256 constant COLLATERAL_SERVICE_PROVIDER_IDENTIFICATION_NUMBER_START = 22;
  uint256 constant COLLATERAL_LATITUDE_START = 72;
  uint256 constant COLLATERAL_LATITUDE_SIGNS_START = 100;
  uint256 constant COLLATERAL_LONGITUDE_START = 101;
  uint256 constant COLLATERAL_LONGITUDE_SIGNS_START = 129;
  uint256 constant COLLATERAL_DETAILS_START = 130;
  uint256 constant COLLATERAL_CATEGORY_START = 170;
  uint256 constant PRODUCT_NUMBER_START = 180;

  function parseAssetBondId(uint256 tokenId)
    public
    pure
    returns (DataStruct.AssetBondIdData memory)
  {
    DataStruct.AssetBondIdData memory vars;
    vars.nonce = tokenId & ~NONCE;
    vars.countryCode = (tokenId & ~COUNTRY_CODE) >> COUNTRY_CODE_START;
    vars.collateralServiceProviderIdentificationNumber =
      (tokenId & ~COLLATERAL_SERVICE_PROVIDER_IDENTIFICATION_NUMBER) >>
      COLLATERAL_SERVICE_PROVIDER_IDENTIFICATION_NUMBER_START;
    vars.collateralLatitude = (tokenId & ~COLLATERAL_LATITUDE) >> COLLATERAL_LATITUDE_START;
    vars.collateralLatitudeSign =
      (tokenId & ~COLLATERAL_LATITUDE_SIGNS) >>
      COLLATERAL_LATITUDE_SIGNS_START;
    vars.collateralLongitude = (tokenId & ~COLLATERAL_LONGITUDE) >> COLLATERAL_LONGITUDE_START;
    vars.collateralLongitudeSign =
      (tokenId & ~COLLATERAL_LONGITUDE_SIGNS) >>
      COLLATERAL_LONGITUDE_SIGNS_START;
    vars.collateralDetail = (tokenId & ~COLLATERAL_DETAILS) >> COLLATERAL_DETAILS_START;
    vars.collateralCategory = (tokenId & ~COLLATERAL_CATEGORY) >> COLLATERAL_CATEGORY_START;
    vars.productNumber = (tokenId & ~PRODUCT_NUMBER) >> PRODUCT_NUMBER_START;

    return vars;
  }

  function getAssetBondDebtData(DataStruct.AssetBondData memory assetBondData)
    public
    view
    returns (uint256, uint256)
  {
    if (assetBondData.state != DataStruct.AssetBondState.COLLATERALIZED) {
      return (0, 0);
    }

    uint256 accruedDebtOnMoneyPool = Math
    .calculateCompoundedInterest(
      assetBondData.interestRate,
      assetBondData.collateralizeTimestamp,
      block.timestamp
    ).rayMul(assetBondData.principal);

    uint256 feeOnCollateralServiceProvider = calculateFeeOnRepayment(
      assetBondData,
      block.timestamp
    );

    return (accruedDebtOnMoneyPool, feeOnCollateralServiceProvider);
  }

  struct CalculateFeeOnRepaymentLocalVars {
    TimeConverter.DateTime paymentDateTimeStruct;
    uint256 paymentDate;
    uint256 firstTermRate;
    uint256 secondTermRate;
    uint256 secondTermOverdueRate;
    uint256 thirdTermRate;
    uint256 totalRate;
  }

  function calculateFeeOnRepayment(
    DataStruct.AssetBondData memory assetBondData,
    uint256 paymentTimestamp
  ) internal pure returns (uint256) {
    CalculateFeeOnRepaymentLocalVars memory vars;

    vars.firstTermRate = Math.calculateCompoundedInterest(
      assetBondData.couponRate,
      assetBondData.loanStartTimestamp,
      assetBondData.collateralizeTimestamp
    );

    vars.paymentDateTimeStruct = TimeConverter.parseTimestamp(paymentTimestamp);
    vars.paymentDate = TimeConverter.toTimestamp(
      vars.paymentDateTimeStruct.year,
      vars.paymentDateTimeStruct.month,
      vars.paymentDateTimeStruct.day + 1
    );

    if (paymentTimestamp <= assetBondData.liquidationTimestamp) {
      vars.secondTermRate =
        Math.calculateCompoundedInterest(
          assetBondData.couponRate - assetBondData.interestRate,
          assetBondData.collateralizeTimestamp,
          paymentTimestamp
        ) -
        WadRayMath.ray();
      vars.thirdTermRate =
        Math.calculateCompoundedInterest(
          assetBondData.couponRate,
          paymentTimestamp,
          vars.paymentDate
        ) -
        WadRayMath.ray();

      vars.totalRate = vars.firstTermRate + vars.secondTermRate + vars.thirdTermRate;

      return assetBondData.principal.rayMul(vars.totalRate) - assetBondData.principal;
    }

    vars.secondTermRate =
      Math.calculateCompoundedInterest(
        assetBondData.couponRate - assetBondData.interestRate,
        assetBondData.collateralizeTimestamp,
        assetBondData.maturityTimestamp
      ) -
      WadRayMath.ray();
    vars.secondTermOverdueRate =
      Math.calculateCompoundedInterest(
        assetBondData.couponRate + assetBondData.delinquencyRate - assetBondData.interestRate,
        assetBondData.maturityTimestamp,
        paymentTimestamp
      ) -
      WadRayMath.ray();
    vars.thirdTermRate =
      Math.calculateCompoundedInterest(
        assetBondData.couponRate + assetBondData.delinquencyRate,
        paymentTimestamp,
        vars.paymentDate
      ) -
      WadRayMath.ray();

    vars.totalRate =
      vars.firstTermRate +
      vars.secondTermRate +
      vars.secondTermOverdueRate +
      vars.thirdTermRate;

    return assetBondData.principal.rayMul(vars.totalRate) - assetBondData.principal;
  }

  function getAssetBondLiquidationData(DataStruct.AssetBondData memory assetBondData)
    internal
    view
    returns (uint256, uint256)
  {
    uint256 accruedDebtOnMoneyPool = Math
    .calculateCompoundedInterest(
      assetBondData.interestRate,
      assetBondData.collateralizeTimestamp,
      block.timestamp
    ).rayMul(assetBondData.principal);

    uint256 feeOnCollateralServiceProvider = calculateDebtAmountToLiquidation(
      assetBondData,
      block.timestamp
    );

    return (accruedDebtOnMoneyPool, feeOnCollateralServiceProvider);
  }

  struct CalculateDebtAmountToLiquidationLocalVars {
    TimeConverter.DateTime paymentDateTimeStruct;
    uint256 paymentDate;
    uint256 firstTermRate;
    uint256 secondTermRate;
    uint256 totalRate;
  }

  function calculateDebtAmountToLiquidation(
    DataStruct.AssetBondData memory assetBondData,
    uint256 paymentTimestamp
  ) internal pure returns (uint256) {
    CalculateDebtAmountToLiquidationLocalVars memory vars;
    vars.firstTermRate = Math.calculateCompoundedInterest(
      assetBondData.couponRate,
      assetBondData.loanStartTimestamp,
      assetBondData.maturityTimestamp
    );

    vars.paymentDateTimeStruct = TimeConverter.parseTimestamp(paymentTimestamp);
    vars.paymentDate = TimeConverter.toTimestamp(
      vars.paymentDateTimeStruct.year,
      vars.paymentDateTimeStruct.month,
      vars.paymentDateTimeStruct.day + 1
    );

    vars.secondTermRate =
      Math.calculateCompoundedInterest(
        assetBondData.couponRate + assetBondData.delinquencyRate,
        assetBondData.maturityTimestamp,
        vars.paymentDate
      ) -
      WadRayMath.ray();
    vars.totalRate = vars.firstTermRate + vars.secondTermRate;

    return assetBondData.principal.rayMul(vars.totalRate) - assetBondData.principal;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ILToken is IERC20 {
  /**
   * @dev Emitted after lTokens are minted
   * @param account The receiver of minted lToken
   * @param amount The amount being minted
   * @param index The new liquidity index of the reserve
   **/
  event Mint(address indexed account, uint256 amount, uint256 index);

  /**
   * @dev Emitted after lTokens are burned
   * @param account The owner of the lTokens, getting them burned
   * @param underlyingAssetReceiver The address that will receive the underlying asset
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  event Burn(
    address indexed account,
    address indexed underlyingAssetReceiver,
    uint256 amount,
    uint256 index
  );

  /**
   * @dev Emitted during the transfer action
   * @param account The account whose tokens are being transferred
   * @param to The recipient
   * @param amount The amount being transferred
   * @param index The new liquidity index of the reserve
   **/
  event BalanceTransfer(address indexed account, address indexed to, uint256 amount, uint256 index);

  function mint(
    address account,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @dev Burns lTokens account `account` and sends the equivalent amount of underlying to `receiver`
   * @param account The owner of the lTokens, getting them burned
   * @param receiver The address that will receive the underlying
   * @param amount The amount being burned
   * @param index The new liquidity index of the reserve
   **/
  function burn(
    address account,
    address receiver,
    uint256 amount,
    uint256 index
  ) external;

  /**
   * @dev Returns the address of the underlying asset of this LTokens (E.g. WETH for aWETH)
   **/
  function getUnderlyingAsset() external view returns (address);

  function implicitBalanceOf(address account) external view returns (uint256);

  function implicitTotalSupply() external view returns (uint256);

  function transferUnderlyingTo(address underlyingAssetReceiver, uint256 amount) external;

  function updateIncentivePool(address newIncentivePool) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';

interface IDToken is IERC20Metadata {
  /**
   * @dev Emitted when new stable debt is minted
   * @param account The address of the account who triggered the minting
   * @param receiver The recipient of stable debt tokens
   * @param amount The amount minted
   * @param currentBalance The current balance of the account
   * @param balanceIncrease The increase in balance since the last action of the account
   * @param newRate The rate of the debt after the minting
   * @param avgStableRate The new average stable rate after the minting
   * @param newTotalSupply The new total supply of the stable debt token after the action
   **/
  event Mint(
    address indexed account,
    address indexed receiver,
    uint256 amount,
    uint256 currentBalance,
    uint256 balanceIncrease,
    uint256 newRate,
    uint256 avgStableRate,
    uint256 newTotalSupply
  );

  /**
   * @dev Emitted when new stable debt is burned
   * @param account The address of the account
   * @param amount The amount being burned
   * @param currentBalance The current balance of the account
   * @param balanceIncrease The the increase in balance since the last action of the account
   * @param avgStableRate The new average stable rate after the burning
   * @param newTotalSupply The new total supply of the stable debt token after the action
   **/
  event Burn(
    address indexed account,
    uint256 amount,
    uint256 currentBalance,
    uint256 balanceIncrease,
    uint256 avgStableRate,
    uint256 newTotalSupply
  );

  /**
   * @dev Mints debt token to the `receiver` address.
   * - The resulting rate is the weighted average between the rate of the new debt
   * and the rate of the previous debt
   * @param account The address receiving the borrowed underlying, being the delegatee in case
   * of credit delegate, or same as `receiver` otherwise
   * @param receiver The address receiving the debt tokens
   * @param amount The amount of debt tokens to mint
   * @param rate The rate of the debt being minted
   **/
  function mint(
    address account,
    address receiver,
    uint256 amount,
    uint256 rate
  ) external;

  /**
   * @dev Burns debt of `account`
   * - The resulting rate is the weighted average between the rate of the new debt
   * and the rate of the previous debt
   * @param account The address of the account getting his debt burned
   * @param amount The amount of debt tokens getting burned
   **/
  function burn(address account, uint256 amount) external;

  /**
   * @dev Returns the average rate of all the stable rate loans.
   * @return The average stable rate
   **/
  function getTotalAverageRealAssetBorrowRate() external view returns (uint256);

  /**
   * @dev Returns the stable rate of the account debt
   * @return The stable rate of the account
   **/
  function getUserAverageRealAssetBorrowRate(address account) external view returns (uint256);

  /**
   * @dev Returns the timestamp of the last update of the account
   * @return The timestamp
   **/
  function getUserLastUpdateTimestamp(address account) external view returns (uint256);

  /**
   * @dev Returns the principal, the total supply and the average stable rate
   **/
  function getDTokenData()
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  /**
   * @dev Returns the timestamp of the last update of the total supply
   * @return The timestamp
   **/
  function getTotalSupplyLastUpdated() external view returns (uint256);

  /**
   * @dev Returns the total supply and the average stable rate
   **/
  function getTotalSupplyAndAvgRate() external view returns (uint256, uint256);

  /**
   * @dev Returns the principal debt balance of the account
   * @return The debt balance of the account since the last burn/mint action
   **/
  function principalBalanceOf(address account) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';

interface IMoneyPool {
  event NewReserve(
    address indexed asset,
    address lToken,
    address dToken,
    address interestModel,
    address tokenizer,
    address incentivePool,
    uint256 moneyPoolFactor
  );

  event Deposit(address indexed asset, address indexed account, uint256 amount);

  event Withdraw(
    address indexed asset,
    address indexed account,
    address indexed to,
    uint256 amount
  );

  event Borrow(
    address indexed asset,
    address indexed collateralServiceProvider,
    address indexed borrower,
    uint256 tokenId,
    uint256 borrowAPY,
    uint256 borrowAmount
  );

  event Repay(
    address indexed asset,
    address indexed borrower,
    uint256 tokenId,
    uint256 userDTokenBalance,
    uint256 feeOnCollateralServiceProvider
  );

  event Liquidation(
    address indexed asset,
    address indexed borrower,
    uint256 tokenId,
    uint256 userDTokenBalance,
    uint256 feeOnCollateralServiceProvider
  );

  function deposit(
    address asset,
    address account,
    uint256 amount
  ) external;

  function withdraw(
    address asset,
    address account,
    uint256 amount
  ) external;

  function borrow(address asset, uint256 tokenID) external;

  function repay(address asset, uint256 tokenId) external;

  function liquidate(address asset, uint256 tokenId) external;

  function getLTokenInterestIndex(address asset) external view returns (uint256);

  function getReserveData(address asset) external view returns (DataStruct.ReserveData memory);

  function addNewReserve(
    address asset,
    address lToken,
    address dToken,
    address interestModel,
    address tokenizer,
    address incentivePool,
    uint256 moneyPoolFactor_
  ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';

interface IIncentivePool {
  event ClaimIncentive(address indexed user, uint256 claimedIncentive, uint256 userIncentiveIndex);

  event UpdateIncentivePool(address indexed user, uint256 accruedIncentive, uint256 incentiveIndex);

  event IncentivePoolEnded();

  event RewardPerSecondUpdated(uint256 newAmountPerSecond);

  event IncentiveEndTimestampUpdated(uint256 newEndTimestamp);

  function initializeIncentivePool(address lToken) external;

  function setAmountPerSecond(uint256 newAmountPerSecond) external;

  /**
   * @notice Admin can update incentive pool end timestamp
   */
  function setEndTimestamp(uint256 newEndTimestamp) external;

  function updateIncentivePool(address user) external;

  function beforeTokenTransfer(address from, address to) external;

  function claimIncentive() external;

  function withdrawResidue() external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import '../libraries/DataStruct.sol';

interface ITokenizer is IERC721 {
  /**
   * @notice Emitted when a collateral service provider mints an empty asset bond token.
   * @param account The address of collateral service provider who minted
   * @param tokenId The id of minted token
   **/
  event EmptyAssetBondMinted(address indexed account, uint256 tokenId);

  /**
   * @notice Emitted when a collateral service provider mints an empty asset bond token.
   **/
  event AssetBondSettled(
    address indexed borrower,
    address indexed signer,
    uint256 tokenId,
    uint256 principal,
    uint256 couponRate,
    uint256 delinquencyRate,
    uint256 debtCeiling,
    uint256 maturityTimestamp,
    uint256 liquidationTimestamp,
    uint256 loanStartTimestamp,
    string ifpsHash
  );

  event AssetBondSigned(address indexed signer, uint256 tokenId, string signerOpinionHash);

  event AssetBondCollateralized(
    address indexed account,
    uint256 tokenId,
    uint256 borrowAmount,
    uint256 interestRate
  );

  event AssetBondReleased(address indexed borrower, uint256 tokenId);

  event AssetBondLiquidated(address indexed liquidator, uint256 tokenId);

  function mintAssetBond(address account, uint256 id) external;

  function collateralizeAssetBond(
    address collateralServiceProvider,
    uint256 tokenId,
    uint256 borrowAmount,
    uint256 borrowAPY
  ) external;

  function releaseAssetBond(address account, uint256 tokenId) external;

  function liquidateAssetBond(address account, uint256 tokenId) external;

  function getAssetBondIdData(uint256 tokenId)
    external
    view
    returns (DataStruct.AssetBondIdData memory);

  function getAssetBondData(uint256 tokenId)
    external
    view
    returns (DataStruct.AssetBondData memory);

  function getAssetBondDebtData(uint256 tokenId) external view returns (uint256, uint256);

  function getMinter(uint256 tokenId) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import './libraries/DataStruct.sol';

import './logic/Index.sol';

import './interfaces/IConnector.sol';

contract MoneyPoolStorage {
  using Index for DataStruct.ReserveData;

  mapping(address => DataStruct.ReserveData) internal _reserves;

  mapping(uint256 => address) internal _reservesList;

  uint256 internal _reserveCount;

  uint256 internal _maxReserveCount;

  IConnector internal _connector;
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
pragma solidity 0.8.3;

import './WadRayMath.sol';

library Math {
  using WadRayMath for uint256;

  uint256 internal constant SECONDSPERYEAR = 365 days;

  function calculateLinearInterest(
    uint256 rate,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    uint256 timeDelta = currentTimestamp - uint256(lastUpdateTimestamp);

    return ((rate * timeDelta) / SECONDSPERYEAR) + WadRayMath.ray();
  }

  /**
   * @notice Author : AAVE
   * @dev Function to calculate the interest using a compounded interest rate formula
   * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
   *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
   *
   * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great gas cost reductions
   * The whitepaper contains reference to the approximation and a table showing the margin of error per different time periods
   *
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate compounded during the timeDelta, in ray
   **/
  function calculateCompoundedInterest(
    uint256 rate,
    uint256 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    //solium-disable-next-line
    uint256 exp = currentTimestamp - lastUpdateTimestamp;

    if (exp == 0) {
      return WadRayMath.ray();
    }

    uint256 expMinusOne = exp - 1;

    uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;

    // loss of precision is endurable
    // slither-disable-next-line divide-before-multiply
    uint256 ratePerSecond = rate / SECONDSPERYEAR;

    uint256 basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
    uint256 basePowerThree = basePowerTwo.rayMul(ratePerSecond);

    uint256 secondTerm = (exp * expMinusOne * basePowerTwo) / 2;
    uint256 thirdTerm = (exp * expMinusOne * expMinusTwo * basePowerThree) / 6;

    return WadRayMath.ray() + (ratePerSecond * exp) + secondTerm + thirdTerm;
  }

  function calculateRateInIncreasingBalance(
    uint256 averageRate,
    uint256 totalBalance,
    uint256 amountIn,
    uint256 rate
  ) internal pure returns (uint256, uint256) {
    uint256 weightedAverageRate = totalBalance.wadToRay().rayMul(averageRate);
    uint256 weightedAmountRate = amountIn.wadToRay().rayMul(rate);

    uint256 newTotalBalance = totalBalance + amountIn;
    uint256 newAverageRate = (weightedAverageRate + weightedAmountRate).rayDiv(
      newTotalBalance.wadToRay()
    );

    return (newTotalBalance, newAverageRate);
  }

  function calculateRateInDecreasingBalance(
    uint256 averageRate,
    uint256 totalBalance,
    uint256 amountOut,
    uint256 rate
  ) internal pure returns (uint256, uint256) {
    // if decreasing amount exceeds totalBalance,
    // overall rate and balacne would be set 0
    if (totalBalance <= amountOut) {
      return (0, 0);
    }

    uint256 weightedAverageRate = totalBalance.wadToRay().rayMul(averageRate);
    uint256 weightedAmountRate = amountOut.wadToRay().rayMul(rate);

    if (weightedAverageRate <= weightedAmountRate) {
      return (0, 0);
    }

    uint256 newTotalBalance = totalBalance - amountOut;

    uint256 newAverageRate = (weightedAverageRate - weightedAmountRate).rayDiv(
      newTotalBalance.wadToRay()
    );

    return (newTotalBalance, newAverageRate);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

/**
 * @title WadRayMath library
 * @author Aave
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits precision) and rays (decimals with 27 digits)
 **/

library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant halfWAD = WAD / 2;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant halfRAY = RAY / 2;

  uint256 internal constant WAD_RAY_RATIO = 1e9;

  /**
   * @return One ray, 1e27
   **/
  function ray() internal pure returns (uint256) {
    return RAY;
  }

  /**
   * @return One wad, 1e18
   **/

  function wad() internal pure returns (uint256) {
    return WAD;
  }

  /**
   * @return Half ray, 1e27/2
   **/
  function halfRay() internal pure returns (uint256) {
    return halfRAY;
  }

  /**
   * @return Half ray, 1e18/2
   **/
  function halfWad() internal pure returns (uint256) {
    return halfWAD;
  }

  /**
   * @dev Multiplies two wad, rounding half up to the nearest wad
   * @param a Wad
   * @param b Wad
   * @return The result of a*b, in wad
   **/
  function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    return (a * b + halfWAD) / WAD;
  }

  /**
   * @dev Divides two wad, rounding half up to the nearest wad
   * @param a Wad
   * @param b Wad
   * @return The result of a/b, in wad
   **/
  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, 'Division by Zero');
    uint256 halfB = b / 2;
    return (a * WAD + halfB) / b;
  }

  /**
   * @dev Multiplies two ray, rounding half up to the nearest ray
   * @param a Ray
   * @param b Ray
   * @return The result of a*b, in ray
   **/
  function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0 || b == 0) {
      return 0;
    }
    return (a * b + halfRAY) / RAY;
  }

  /**
   * @dev Divides two ray, rounding half up to the nearest ray
   * @param a Ray
   * @param b Ray
   * @return The result of a/b, in ray
   **/
  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0, 'Division by Zero');
    uint256 halfB = b / 2;
    return (a * RAY + halfB) / b;
  }

  /**
   * @dev Casts ray down to wad
   * @param a Ray
   * @return a casted to wad, rounded half up to the nearest wad
   **/
  function rayToWad(uint256 a) internal pure returns (uint256) {
    uint256 halfRatio = WAD_RAY_RATIO / 2;
    uint256 result = halfRatio + a;
    return result / WAD_RAY_RATIO;
  }

  /**
   * @dev Converts wad up to ray
   * @param a Wad
   * @return a converted in ray
   **/
  function wadToRay(uint256 a) internal pure returns (uint256) {
    uint256 result = a * WAD_RAY_RATIO;
    return result;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';

interface IInterestRateModel {
  function calculateRates(
    uint256 lTokenAssetBalance,
    uint256 totalDTokenBalance,
    uint256 depositAmount,
    uint256 borrowAmount,
    uint256 moneyPoolFactor
  ) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
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
pragma solidity 0.8.3;

/**
 * @title Ethereum timestamp conversion library
 * @author ethereum-datatime
 */
library TimeConverter {
  struct DateTime {
    uint16 year;
    uint8 month;
    uint8 day;
    uint8 hour;
    uint8 minute;
    uint8 second;
    uint8 weekday;
  }

  uint256 constant DAY_IN_SECONDS = 86400;
  uint256 constant YEAR_IN_SECONDS = 31536000;
  uint256 constant LEAP_YEAR_IN_SECONDS = 31622400;

  uint256 constant HOUR_IN_SECONDS = 3600;
  uint256 constant MINUTE_IN_SECONDS = 60;

  uint16 constant ORIGIN_YEAR = 1970;

  function isLeapYear(uint16 year) internal pure returns (bool) {
    if (year % 4 != 0) {
      return false;
    }
    if (year % 100 != 0) {
      return true;
    }
    if (year % 400 != 0) {
      return false;
    }
    return true;
  }

  function leapYearsBefore(uint256 year) internal pure returns (uint256) {
    year -= 1;
    return year / 4 - year / 100 + year / 400;
  }

  function getDaysInMonth(uint8 month, uint16 year) internal pure returns (uint8) {
    if (
      month == 1 ||
      month == 3 ||
      month == 5 ||
      month == 7 ||
      month == 8 ||
      month == 10 ||
      month == 12
    ) {
      return 31;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      return 30;
    } else if (isLeapYear(year)) {
      return 29;
    } else {
      return 28;
    }
  }

  function parseTimestamp(uint256 timestamp) public pure returns (DateTime memory dateTime) {
    uint256 secondsAccountedFor = 0;
    uint256 buf;
    uint8 i;

    // Year
    dateTime.year = getYear(timestamp);
    buf = leapYearsBefore(dateTime.year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * buf;
    secondsAccountedFor += YEAR_IN_SECONDS * (dateTime.year - ORIGIN_YEAR - buf);

    // Month
    uint256 secondsInMonth;
    for (i = 1; i <= 12; i++) {
      secondsInMonth = DAY_IN_SECONDS * getDaysInMonth(i, dateTime.year);
      if (secondsInMonth + secondsAccountedFor > timestamp) {
        dateTime.month = i;
        break;
      }
      secondsAccountedFor += secondsInMonth;
    }

    // Day
    for (i = 1; i <= getDaysInMonth(dateTime.month, dateTime.year); i++) {
      if (DAY_IN_SECONDS + secondsAccountedFor > timestamp) {
        dateTime.day = i;
        break;
      }
      secondsAccountedFor += DAY_IN_SECONDS;
    }

    // Hour
    dateTime.hour = getHour(timestamp);
    // Minute
    dateTime.minute = getMinute(timestamp);
    // Second
    dateTime.second = getSecond(timestamp);
    // Day of week.
    dateTime.weekday = getWeekday(timestamp);
  }

  function getYear(uint256 timestamp) internal pure returns (uint16) {
    uint256 secondsAccountedFor = 0;
    uint16 year;
    uint256 numLeapYears;

    // Year
    year = uint16(ORIGIN_YEAR + timestamp / YEAR_IN_SECONDS);
    numLeapYears = leapYearsBefore(year) - leapYearsBefore(ORIGIN_YEAR);

    secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
    secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

    while (secondsAccountedFor > timestamp) {
      if (isLeapYear(uint16(year - 1))) {
        secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
      } else {
        secondsAccountedFor -= YEAR_IN_SECONDS;
      }
      year -= 1;
    }
    return year;
  }

  function getMonth(uint256 timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).month;
  }

  function getDay(uint256 timestamp) internal pure returns (uint8) {
    return parseTimestamp(timestamp).day;
  }

  function getHour(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60 / 60) % 24);
  }

  function getMinute(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / 60) % 60);
  }

  function getSecond(uint256 timestamp) internal pure returns (uint8) {
    return uint8(timestamp % 60);
  }

  function getWeekday(uint256 timestamp) internal pure returns (uint8) {
    return uint8((timestamp / DAY_IN_SECONDS + 4) % 7);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day
  ) public pure returns (uint256 timestamp) {
    return toTimestamp(year, month, day, 0, 0, 0);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day,
    uint8 hour
  ) public pure returns (uint256 timestamp) {
    return toTimestamp(year, month, day, hour, 0, 0);
  }

  function toTimestamp(
    uint16 year,
    uint8 month,
    uint8 day,
    uint8 hour,
    uint8 minute,
    uint8 second
  ) public pure returns (uint256 timestamp) {
    uint16 i;

    // Year
    for (i = ORIGIN_YEAR; i < year; i++) {
      if (isLeapYear(i)) {
        timestamp += LEAP_YEAR_IN_SECONDS;
      } else {
        timestamp += YEAR_IN_SECONDS;
      }
    }

    // Month
    uint8[12] memory monthDayCounts;
    monthDayCounts[0] = 31;
    if (isLeapYear(year)) {
      monthDayCounts[1] = 29;
    } else {
      monthDayCounts[1] = 28;
    }
    monthDayCounts[2] = 31;
    monthDayCounts[3] = 30;
    monthDayCounts[4] = 31;
    monthDayCounts[5] = 30;
    monthDayCounts[6] = 31;
    monthDayCounts[7] = 31;
    monthDayCounts[8] = 30;
    monthDayCounts[9] = 31;
    monthDayCounts[10] = 30;
    monthDayCounts[11] = 31;

    for (i = 1; i < month; i++) {
      timestamp += DAY_IN_SECONDS * monthDayCounts[i - 1];
    }

    // Day
    timestamp += DAY_IN_SECONDS * (day - 1);
    // Hour
    timestamp += HOUR_IN_SECONDS * (hour);
    // Minute
    timestamp += MINUTE_IN_SECONDS * (minute);
    // Second
    timestamp += second;

    return timestamp;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.3;

import '../libraries/DataStruct.sol';

interface IConnector {
  /**
   * @notice Emitted when an admin adds a council role
   **/
  event NewCouncilAdded(address indexed account);

  /**
   * @notice Emitted when an admin adds a collateral service provider role
   **/
  event NewCollateralServiceProviderAdded(address indexed account);

  /**
   * @notice Emitted when a council role is revoked by admin
   **/
  event CouncilRevoked(address indexed account);

  /**
   * @notice Emitted when a collateral service provider role is revoked by admin
   **/
  event CollateralServiceProviderRevoked(address indexed account);

  function isCollateralServiceProvider(address account) external view returns (bool);

  function isCouncil(address account) external view returns (bool);

  function isMoneyPoolAdmin(address account) external view returns (bool);
}