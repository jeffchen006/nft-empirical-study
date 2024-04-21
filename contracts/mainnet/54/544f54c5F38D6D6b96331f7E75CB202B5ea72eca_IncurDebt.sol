// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

import "../interfaces/IOHM.sol";
import "../interfaces/IgOHM.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IStrategy.sol";
import "../interfaces/IIncurDebt.sol";
import "../types/OlympusAccessControlledV2.sol";

error IncurDebt_NotBorrower(address _borrower);
error IncurDebt_InvaildNumber(uint256 _amount);
error IncurDebt_WrongTokenAddress(address _token);
error IncurDebt_AlreadyBorrower(address _borrower);
error IncurDebt_AboveGlobalDebtLimit(uint256 _limit);
error IncurDebt_AboveBorrowersDebtLimit(uint256 _limit);
error IncurDebt_StrategyUnauthorized(address _strategy);
error IncurDebt_AmountAboveBorrowerBalance(uint256 _amount);
error IncurDebt_OHMAmountMoreThanAvailableLoan(uint256 _amount);
error IncurDebt_BorrowerHasNoOutstandingDebt(address _borrower);
error IncurDebt_BorrowerStillHasOutstandingDebt(address _borrower);
error IncurDebt_InvalidAddress();

/// @title IncurDebt
/// @notice Contract that allows users to use the treasury's incurdebt function.
/// It allows users(other DAOs) to borrow OHM against their sOHM/gOHM to use to provide liquidity for their token.
contract IncurDebt is OlympusAccessControlledV2, IIncurDebt {
    using SafeERC20 for IERC20;

    event GlobalLimitChanged(uint256 _limit);
    event BorrowerAllowed(address indexed _borrower, bool _lpBorrower, bool _nonLpBorrower);
    event BorrowerRevoked(address indexed _borrower);
    event BorrowerDebtLimitSet(address indexed _borrower, uint256 _limit);

    event BorrowerDeposit(address indexed _borrower, uint256 _amountToDeposit);
    event Borrowed(
        address indexed _borrower,
        uint256 _amountToBorrow,
        uint256 _borrowersDebt,
        uint256 _totalOutstandingGlobalDebt
    );
    event DebtPaidWithOHM(
        address indexed _borrower,
        uint256 _paidDebt,
        uint256 _currentDebt,
        uint256 _totalOutstandingGlobalDebt
    );
    event DebtPaidWithCollateral(
        address indexed _borrower,
        uint256 _paidDebt,
        uint256 _currentCollateral,
        uint256 _totalOutstandingGlobalDebt
    );
    event DebtPaidWithCollateralAndBurnTheRest(
        address indexed _borrower,
        uint256 _paidDebt,
        uint256 _totalOutstandingGlobalDebt,
        uint256 _collateralLeftToBurn
    );
    event DebtPaidWithCollateralAndWithdrawTheRest(
        address indexed _borrower,
        uint256 _paidDebt,
        uint256 _totalOutstandingGlobalDebt,
        uint256 _collateralLeftForWithdraw
    );
    event LpInteraction(
        address indexed _borrower,
        uint256 _ohmBorrowed,
        uint256 _liquidityCreated,
        uint256 _currentDebt,
        uint256 _totalOutstandingGlobalDebt
    );

    event LpWithdrawn(address indexed _borrower, uint256 _liquidity, address _lpToken);

    event Withdrawal(address indexed _borrower, uint256 _amountToWithdraw, uint256 _currentCollateral);

    uint256 public globalDebtLimit;
    uint256 public totalOutstandingGlobalDebt;

    address public immutable OHM;
    address public immutable gOHM;
    address public immutable sOHM;
    address public immutable staking;
    address public immutable treasury;

    struct Borrower {
        uint128 debt;
        uint128 limit;
        uint128 collateralInGOHM; // Total amount of collateral priced in gOHM. This includes gOHM and sOHM entitled to the user.
        uint128 unwrappedGOHM; // Amount of gOHM that is converted to sOHM to be used for incurdebt. To be converted back before withdrawal.
        bool isNonLpBorrower;
        bool isLpBorrower;
    }

    mapping(address => Borrower) public borrowers;
    mapping(address => bool) public strategies;
    mapping(address => mapping(address => uint256)) public lpTokenOwnership; // lp token -> user -> amount

    constructor(
        address _OHM,
        address _gOHM,
        address _sOHM,
        address _staking,
        address _treasury,
        address _olympusAuthority
    ) OlympusAccessControlledV2(IOlympusAuthority(_olympusAuthority)) {
        if (_OHM == address(0)) revert IncurDebt_InvalidAddress();
        if (_gOHM == address(0)) revert IncurDebt_InvalidAddress();
        if (_sOHM == address(0)) revert IncurDebt_InvalidAddress();
        if (_staking == address(0)) revert IncurDebt_InvalidAddress();
        if (_treasury == address(0)) revert IncurDebt_InvalidAddress();
        if (_olympusAuthority == address(0)) revert IncurDebt_InvalidAddress();

        OHM = _OHM;
        gOHM = _gOHM;
        sOHM = _sOHM;
        staking = _staking;
        treasury = _treasury;
        IERC20(OHM).safeApprove(treasury, type(uint256).max);
        IERC20(gOHM).safeApprove(staking, type(uint256).max);
        IERC20(sOHM).safeApprove(staking, type(uint256).max);
    }

    modifier isBorrower(address _borrower) {
        if (!borrowers[_borrower].isNonLpBorrower && !borrowers[_borrower].isLpBorrower)
            revert IncurDebt_NotBorrower(_borrower);
        _;
    }

    modifier isStrategyApproved(address _strategy) {
        if (!strategies[_strategy]) revert IncurDebt_StrategyUnauthorized(_strategy);
        _;
    }

    /************************
     * Governor Functions
     ************************/

    /// @notice sets the maximum debt limit for the system
    /// - onlyOwner (or governance)
    /// - must be greater than or equal to existing debt
    /// @param _limit in OHM
    function setGlobalDebtLimit(uint256 _limit) external override onlyGovernor {
        globalDebtLimit = _limit;
        emit GlobalLimitChanged(_limit);
    }

    /// @notice whitelist a strategy contract to be used for createLP and removeLP
    /// - onlyOwner (or governance)
    /// @param _strategyAddress address of the strategy contract
    function whitelistStrategy(address _strategyAddress) external onlyGovernor {
        strategies[_strategyAddress] = true;
        IERC20(OHM).approve(_strategyAddress, type(uint256).max);
    }

    /// @notice lets a user become a LP borrower
    /// - onlyOwner (or governance)
    /// @param _borrower the address that will interact with contract
    function allowLPBorrower(address _borrower) external override onlyGovernor {
        if (borrowers[_borrower].isNonLpBorrower) revert IncurDebt_AlreadyBorrower(_borrower);

        borrowers[_borrower].isLpBorrower = true;

        emit BorrowerAllowed(_borrower, true, false);
    }

    /// @notice lets a user become a Non LP borrower
    /// - onlyOwner (or governance)
    /// @param _borrower the address that will interact with contract
    function allowNonLPBorrower(address _borrower) external override onlyGovernor {
        if (borrowers[_borrower].isLpBorrower) revert IncurDebt_AlreadyBorrower(_borrower);

        borrowers[_borrower].isNonLpBorrower = true;

        emit BorrowerAllowed(_borrower, false, true);
    }

    /// @notice sets the maximum debt limit for a borrower
    /// - onlyOwner (or governance)
    /// - limit must be greater than or equal to borrower's outstanding debt
    /// @param _borrower the address that will interact with contract
    /// @param _limit borrower's debt limit in OHM
    function setBorrowerDebtLimit(address _borrower, uint256 _limit)
        external
        override
        onlyGovernor
        isBorrower(_borrower)
    {
        if (_limit < borrowers[_borrower].debt) revert IncurDebt_AboveBorrowersDebtLimit(_limit);

        borrowers[_borrower].limit = uint128(_limit);
        emit BorrowerDebtLimitSet(_borrower, _limit);
    }

    /// @notice revoke user right to borrow
    /// - onlyOwner (or governance)
    /// - user must be borrower
    /// - borrower must not have outstanding debt
    /// @param _borrower the address that will interact with contract
    function revokeBorrower(address _borrower) external override onlyGovernor isBorrower(_borrower) {
        if (borrowers[_borrower].debt != 0) revert IncurDebt_BorrowerStillHasOutstandingDebt(_borrower);

        borrowers[_borrower].isNonLpBorrower = false;
        borrowers[_borrower].isLpBorrower = false;

        emit BorrowerRevoked(_borrower);
    }

    /// @notice Governor repays borrower debt using collateral and sends remaining tokens to borrower
    /// - onlyOwner (or governance)
    /// - sends remaining tokens to owner in sOHM
    /// @param _borrower the address that will interact with contract
    function forceRepay(address _borrower) external override onlyGovernor {
        (uint256 collateralRemaining, uint256 paidDebt) = _repay(_borrower);
        borrowers[_borrower].collateralInGOHM = 0;

        IERC20(gOHM).transfer(_borrower, collateralRemaining);

        emit DebtPaidWithCollateralAndWithdrawTheRest(
            _borrower,
            paidDebt,
            totalOutstandingGlobalDebt,
            collateralRemaining
        );
    }

    /// @notice Governor seize and burn _borrowers collateral and forgive debt
    /// - will burn all collateral, including excess of debt
    /// - onlyGovernance
    /// @param _borrower the account to seize collateral
    function seize(address _borrower) external override onlyGovernor {
        (uint256 seizedCollateral, uint256 paidDebt) = _repay(_borrower);
        borrowers[_borrower].collateralInGOHM = 0;

        uint256 amountToBurn = IStaking(staking).unstake(address(this), seizedCollateral, false, false); // unstakes gOHM to OHM and burn
        IOHM(OHM).burn(amountToBurn);

        emit DebtPaidWithCollateralAndBurnTheRest(_borrower, paidDebt, totalOutstandingGlobalDebt, seizedCollateral);
    }

    /// @notice lets governor withdraw tokens incase of airdrop or error
    /// - onlyOwner (or governance)
    /// @param _tokenAddress the address of the token
    /// @param _amount amount of tokens to withdraw
    function withdrawToken(address _tokenAddress, uint256 _amount) external override onlyGovernor {
        IERC20(_tokenAddress).safeTransfer(msg.sender, _amount);
    }

    /************************
     * Borrower Functions
     ************************/

    /// @notice deposits gOHM to use as collateral
    /// - msg.sender must be a borrower
    /// - this contract must have been approved _amount
    /// @param _amount amount of gOHM
    function deposit(uint256 _amount) external override isBorrower(msg.sender) {
        borrowers[msg.sender].collateralInGOHM += uint128(_amount);

        IERC20(gOHM).safeTransferFrom(msg.sender, address(this), _amount);

        emit BorrowerDeposit(msg.sender, _amount);
    }

    /// @notice allow borrowers to borrow OHM
    /// - msg.sender must be a borrower
    /// - _ohmAmount must be less than or equal to borrowers debt limit
    /// - _ohmAmount must be less than or equal to borrowers available loan limit
    /// @param _ohmAmount amount of OHM to borrow
    function borrow(uint256 _ohmAmount) external override {
        Borrower storage borrower = borrowers[msg.sender];
        if (!borrower.isNonLpBorrower) revert IncurDebt_NotBorrower(msg.sender);

        _borrow(_ohmAmount);
        IERC20(OHM).safeTransfer(msg.sender, _ohmAmount);

        emit Borrowed(msg.sender, _ohmAmount, borrower.debt, totalOutstandingGlobalDebt);
    }

    ///@notice creates an LP position by borrowing OHM
    ///- msg.sender must be whitelisted
    ///- the strategy must be whitelisted
    ///- the strategy contract must have been approved _pairAmount of _pairToken
    ///- _ohmAmount must be less than or equal to available debt
    ///@param _ohmAmount the desired amount of OHM to borrow
    ///@param _strategy the address of the AMM strategy to use
    ///@param _strategyParams strategy-specific params
    ///@return number of LP tokens created
    function createLP(
        uint256 _ohmAmount,
        address _strategy,
        bytes calldata _strategyParams
    ) external override isStrategyApproved(_strategy) returns (uint256) {
        Borrower storage borrower = borrowers[msg.sender];

        if (!borrower.isLpBorrower) revert IncurDebt_NotBorrower(msg.sender);

        _borrow(_ohmAmount);

        (uint256 liquidity, uint256 ohmUnused, address lpTokenAddress) = IStrategy(_strategy).addLiquidity(
            _strategyParams,
            _ohmAmount,
            msg.sender
        );

        lpTokenOwnership[lpTokenAddress][msg.sender] += liquidity;

        if (ohmUnused > 0) {
            borrower.debt -= uint128(ohmUnused);
            totalOutstandingGlobalDebt -= (ohmUnused);
            ITreasury(treasury).repayDebtWithOHM(ohmUnused);
        }

        emit LpInteraction(msg.sender, _ohmAmount - ohmUnused, liquidity, borrower.debt, totalOutstandingGlobalDebt);
        return liquidity;
    }

    ///@notice unwinds an LP position and pays off OHM debt. Excess ohm is sent back to caller.
    ///@param _liquidity the amount of LP tokens to remove.
    ///@param _strategy the address of the AMM strategy to use
    ///@param _lpToken address of lp token to remove liquidity from
    ///@param _strategyParams strategy-specific params
    ///@return ohmRecieved of _pair token send to _to and OHM to pay
    function removeLP(
        uint256 _liquidity,
        address _strategy,
        address _lpToken,
        bytes calldata _strategyParams
    ) external override isStrategyApproved(_strategy) returns (uint256 ohmRecieved) {
        Borrower storage borrower = borrowers[msg.sender];
        if (!borrower.isLpBorrower) revert IncurDebt_NotBorrower(msg.sender);

        if (_liquidity > lpTokenOwnership[_lpToken][msg.sender])
            revert IncurDebt_AmountAboveBorrowerBalance(_liquidity);

        lpTokenOwnership[_lpToken][msg.sender] -= _liquidity;

        IERC20(_lpToken).safeTransfer(_strategy, _liquidity);

        ohmRecieved = IStrategy(_strategy).removeLiquidity(_strategyParams, _liquidity, _lpToken, msg.sender);

        uint256 ohmToRepay;

        if (borrower.debt < ohmRecieved) {
            ohmToRepay = borrower.debt;
            totalOutstandingGlobalDebt -= borrower.debt;

            borrower.debt = 0;
            IERC20(OHM).safeTransfer(msg.sender, ohmRecieved - ohmToRepay);
        } else {
            ohmToRepay = ohmRecieved;
            totalOutstandingGlobalDebt -= ohmRecieved;
            borrower.debt = uint128(borrower.debt - ohmRecieved);
        }

        ITreasury(treasury).repayDebtWithOHM(ohmToRepay);

        emit LpInteraction(msg.sender, ohmToRepay, _liquidity, borrower.debt, totalOutstandingGlobalDebt);
    }

    ///@notice withdraws LP to the user that created it.
    ///@dev If user still has debt outstanding, repay that debt with collateral.
    ///@param _liquidity the amount of LP tokens to withdraw.
    ///@param _lpToken address of lp token to withdraw liquidity from
    function withdrawLP(uint256 _liquidity, address _lpToken) external {
        if (!borrowers[msg.sender].isLpBorrower) revert IncurDebt_NotBorrower(msg.sender);

        if (_liquidity > lpTokenOwnership[_lpToken][msg.sender])
            revert IncurDebt_AmountAboveBorrowerBalance(_liquidity);

        if (borrowers[msg.sender].debt != 0) repayDebtWithCollateral();

        lpTokenOwnership[_lpToken][msg.sender] -= _liquidity;

        IERC20(_lpToken).safeTransfer(msg.sender, _liquidity);
        emit LpWithdrawn(msg.sender, _liquidity, _lpToken);
    }

    /// @notice withdraws gOHM
    /// - msg.sender must be a borrower
    /// - _amount (in OHM) must be less than or equal to depositedOhm - debt
    /// @param _amount amount of gOHM to withdraw
    function withdraw(uint256 _amount) external override isBorrower(msg.sender) {
        if (_amount == 0) revert IncurDebt_InvaildNumber(_amount);
        Borrower storage borrower = borrowers[msg.sender];

        if (IgOHM(gOHM).balanceFrom(_amount) > getAvailableToBorrow())
            revert IncurDebt_AmountAboveBorrowerBalance(_amount);

        if (_amount > borrower.collateralInGOHM - borrower.unwrappedGOHM) {
            uint256 amountGOHMToWrap = borrower.unwrappedGOHM + _amount - borrower.collateralInGOHM;
            borrower.unwrappedGOHM -= uint128(amountGOHMToWrap);
            uint256 amountOHMNeededToWrap = IgOHM(gOHM).balanceFrom(amountGOHMToWrap);
            IStaking(staking).wrap(address(this), amountOHMNeededToWrap);
        }

        borrower.collateralInGOHM -= uint128(_amount);
        IERC20(gOHM).transfer(msg.sender, _amount);

        emit Withdrawal(msg.sender, _amount, borrower.collateralInGOHM);
    }

    /// @notice repay debt with collateral
    /// - msg.sender must be a borrower
    /// - borrower must have outstanding debt
    function repayDebtWithCollateral() public override {
        Borrower storage borrower = borrowers[msg.sender];
        (uint256 currentCollateral, uint256 paidDebt) = _repay(msg.sender);

        borrower.collateralInGOHM = uint128(currentCollateral);

        emit DebtPaidWithCollateral(msg.sender, paidDebt, currentCollateral, totalOutstandingGlobalDebt);
    }

    /// @notice repay debt with collateral and withdraw the accrued earnings in sOHM
    /// - msg.sender must be a borrower
    /// - borrower must have outstanding debt
    function repayDebtWithCollateralAndWithdrawTheRest() external override {
        (uint256 collateralRemaining, uint256 paidDebt) = _repay(msg.sender);
        borrowers[msg.sender].collateralInGOHM = 0;

        IERC20(gOHM).transfer(msg.sender, collateralRemaining);

        emit DebtPaidWithCollateralAndWithdrawTheRest(
            msg.sender,
            paidDebt,
            totalOutstandingGlobalDebt,
            collateralRemaining
        );
    }

    /// @notice deposits OHM to pay debt
    /// - msg.sender must be a borrower
    /// - msg.sender's OHM allowance must be >= _ohmAmount
    /// - borrower must have outstanding debt
    /// @param _ohmAmount amount of OHM to borrow
    function repayDebtWithOHM(uint256 _ohmAmount) external override isBorrower(msg.sender) {
        Borrower storage borrower = borrowers[msg.sender];

        if (borrower.debt == 0) revert IncurDebt_BorrowerHasNoOutstandingDebt(msg.sender);
        if (_ohmAmount > borrower.debt) {
            _ohmAmount = borrower.debt;
        }

        totalOutstandingGlobalDebt -= _ohmAmount;
        borrower.debt -= uint128(_ohmAmount);

        IERC20(OHM).safeTransferFrom(msg.sender, address(this), _ohmAmount);
        ITreasury(treasury).repayDebtWithOHM(_ohmAmount);

        emit DebtPaidWithOHM(msg.sender, _ohmAmount, borrower.debt, totalOutstandingGlobalDebt);
    }

    /// @notice gets available OHM to borrow for account
    /// @return amount OHM available to borrow
    function getAvailableToBorrow() public view returns (uint256) {
        uint256 ohmBalance = IgOHM(gOHM).balanceFrom(borrowers[msg.sender].collateralInGOHM);
        return ohmBalance - borrowers[msg.sender].debt;
    }

    /// @notice borrows OHM against collateral
    /// @dev if user's collateral is in GOHM unwrap it to sOHM to be used as collateral
    /// @param _ohmAmount amount of OHM to borrow
    function _borrow(uint256 _ohmAmount) internal {
        Borrower storage borrower = borrowers[msg.sender];

        if (_ohmAmount > borrower.limit - borrower.debt) revert IncurDebt_AboveBorrowersDebtLimit(_ohmAmount);
        if (_ohmAmount > getAvailableToBorrow()) revert IncurDebt_OHMAmountMoreThanAvailableLoan(_ohmAmount);

        borrower.debt += uint128(_ohmAmount);
        totalOutstandingGlobalDebt += _ohmAmount;
        if (totalOutstandingGlobalDebt > globalDebtLimit) revert IncurDebt_AboveGlobalDebtLimit(globalDebtLimit);

        uint256 totalDebtInGOHM = IgOHM(gOHM).balanceTo(borrower.debt);

        if (totalDebtInGOHM > borrower.unwrappedGOHM) {
            //is there issue comparing uint256 to uint128
            uint128 amountToUnwrap = borrower.collateralInGOHM - borrower.unwrappedGOHM;
            borrower.unwrappedGOHM += amountToUnwrap;
            IStaking(staking).unwrap(address(this), amountToUnwrap); // Due to rounding error should have tiny less sOhm in wallet than amount they borrowed. Keep small sOhm amount in wallet to make sure no errors.
        }

        ITreasury(treasury).incurDebt(_ohmAmount, OHM);
    }

    /// @notice pays borrower debit and return left collateral and paid debt
    /// @param _borrower the account debit needs to be paid
    /// @return collateralRemaining left collateral after paying debit
    /// @return paidDebt debt paid
    function _repay(address _borrower)
        internal
        isBorrower(_borrower)
        returns (uint256 collateralRemaining, uint256 paidDebt)
    {
        Borrower storage borrower = borrowers[_borrower];
        if (borrower.debt == 0) revert IncurDebt_BorrowerHasNoOutstandingDebt(_borrower);

        uint256 debt = borrower.debt;
        totalOutstandingGlobalDebt -= debt;
        borrower.debt = 0;
        uint256 sOHMToWrap = IgOHM(gOHM).balanceFrom(borrower.unwrappedGOHM) - debt;
        borrower.unwrappedGOHM = 0;

        IStaking(staking).unstake(address(this), debt, false, true); // unstakes sOHM portion of collateral
        ITreasury(treasury).repayDebtWithOHM(debt);

        IStaking(staking).wrap(address(this), sOHMToWrap); // wrap up remaining sOHM into gOHM

        collateralRemaining = borrower.collateralInGOHM - IgOHM(gOHM).balanceTo(debt);
        paidDebt = debt;
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for depositing to a Balancer pool
    /// @param _poolId The ID for the pool you wish to deploy assets into
    /// @param _assets A sorted (by address) list of all of the tokens in the relevant pool
    /// @param _maxAmountsIn The maximum amount of each token in the _assets list you would like to send to the pool
    ///                      These amounts need to match by index to the assets in _assets
    /// @param _minimumBPT The minimum number of balancer pool tokens you would like to receive
    function encodeBalancerCreateParams(
        bytes32 _poolId,
        address[] memory _assets,
        uint256[] memory _maxAmountsIn,
        uint256 _minimumBPT
    ) external pure override returns (bytes memory encodedParams) {
        encodedParams = abi.encode(_poolId, _assets, _maxAmountsIn, _minimumBPT);
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for removing from a Balancer pool
    /// @param _poolId The ID for the pool you wish to deploy assets into
    /// @param _assets A sorted (by address) list of the tokens in the pool
    /// @param _minAmountsOut The minimum amount of each token in the _assets list you expect to receive
    ///                       These amounts need to match by index to the assets in _assets
    function encodeBalancerRemoveParams(
        bytes32 _poolId,
        address[] memory _assets,
        uint256[] memory _minAmountsOut
    ) external pure override returns (bytes memory encodedParams) {
        encodedParams = abi.encode(_poolId, _assets, _minAmountsOut);
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for depositing to a Curve pool
    /// @param _amounts The amount of each token to deposit to the Curve pool
    /// @param _min_mint_amount The minimum amount of LP tokens to receive. Otherwise revert deposit.
    /// @param _pairTokenAddress The address for the non-OHM token in the Curve pair
    /// @param _poolAddress The address of the Curve pool to deposit into
    function encodeCurveCreateParams(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount,
        address _pairTokenAddress,
        address _poolAddress
    ) external pure override returns (bytes memory encodedParams) {
        encodedParams = abi.encode(_amounts, _min_mint_amount, _pairTokenAddress, _poolAddress);
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for a Curve pool
    /// @param _burn_amount Amount of Curve Pool LP tokens to burn and get assets back for
    /// @param _min_amounts The minimum amounts of each token in the pool to receive back. Otherwise revert.
    function encodeCurveRemoveParams(uint256 _burn_amount, uint256[2] memory _min_amounts)
        external
        pure
        override
        returns (bytes memory encodedParams)
    {
        encodedParams = abi.encode(_burn_amount, _min_amounts);
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for a Uniswap or Sushiswap pool
    /// @param _tokenA The first token in the pool
    /// @param _tokenB The second token in the pool
    /// @param _amountADesired The amount of token A you wish to deposit into the pool
    /// @param _amountBDesired The amount of token B you wish to deposit into the pool
    /// @param _amountAMin The minimum amount of token A you would accept depositing. Otherwise revert.
    /// @param _amountBMin The minimum amount of token B you would accept depositing. Otherwise revet.
    function encodeUniswapCreateParams(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external pure override returns (bytes memory encodedParams) {
        encodedParams = abi.encode(_tokenA, _tokenB, _amountADesired, _amountBDesired, _amountAMin, _amountBMin);
    }

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for a Uniswap or Sushiswap pool
    /// @param _tokenA The first token in the pool
    /// @param _tokenB The second token in the pool
    /// @param _liquidity Amount of liquidity tokens to send back and remove liquidity for
    /// @param _amountAMin The minimum amount of token A you would accept back for the liquidity tokens you've returned
    /// @param _amountBMin The minimum amount of token B you would accept back for the liquidity tokens you've returned
    function encodeUniswapRemoveParams(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external pure override returns (bytes memory encodedParams) {
        encodedParams = abi.encode(_tokenA, _tokenB, _liquidity, _amountAMin, _amountBMin);
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

import "./IERC20.sol";

interface IOHM is IERC20 {
    function mint(address account_, uint256 amount_) external;

    function burn(uint256 amount) external;

    function burnFrom(address account_, uint256 amount_) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

import "./IERC20.sol";

interface IgOHM is IERC20 {
    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    function index() external view returns (uint256);

    function balanceFrom(uint256 _amount) external view returns (uint256);

    function balanceTo(uint256 _amount) external view returns (uint256);

    function migrate(address _staking, address _sOHM) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.7.5;

import {IERC20} from "../interfaces/IERC20.sol";

/// @notice Safe IERC20 and ETH transfer library that safely handles missing return values.
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v3-periphery/blob/main/contracts/libraries/TransferHelper.sol)
/// Taken from Solmate
library SafeERC20 {
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FAILED");
    }

    function safeApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.approve.selector, to, amount)
        );

        require(success && (data.length == 0 || abi.decode(data, (bool))), "APPROVE_FAILED");
    }

    function safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}(new bytes(0));

        require(success, "ETH_TRANSFER_FAILED");
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

interface IStaking {
    function stake(
        address _to,
        uint256 _amount,
        bool _rebasing,
        bool _claim
    ) external returns (uint256);

    function claim(address _recipient, bool _rebasing) external returns (uint256);

    function forfeit() external returns (uint256);

    function toggleLock() external;

    function unstake(
        address _to,
        uint256 _amount,
        bool _trigger,
        bool _rebasing
    ) external returns (uint256);

    function wrap(address _to, uint256 _amount) external returns (uint256 gBalance_);

    function unwrap(address _to, uint256 _amount) external returns (uint256 sBalance_);

    function rebase() external;

    function index() external view returns (uint256);

    function contractBalance() external view returns (uint256);

    function totalStaked() external view returns (uint256);

    function supplyInWarmup() external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

interface ITreasury {
    function deposit(
        uint256 _amount,
        address _token,
        uint256 _profit
    ) external returns (uint256);

    function withdraw(uint256 _amount, address _token) external;

    function tokenValue(address _token, uint256 _amount) external view returns (uint256 value_);

    function mint(address _recipient, uint256 _amount) external;

    function manage(address _token, uint256 _amount) external;

    function incurDebt(uint256 amount_, address token_) external;

    function repayDebtWithReserve(uint256 amount_, address token_) external;

    function excessReserves() external view returns (uint256);

    function baseSupply() external view returns (uint256);

    function repayDebtWithOHM(uint256 _amount) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.10;

/**
    @title IStrategy
    @notice This interface is implemented by strategy contracts to provide liquidity on behalf of incurdebt contract.
 */
interface IStrategy {
    /**
        @notice Add liquidity to the dex using this strategy.
        @dev Some strategies like uniswap will have tokens left over which is either sent back to 
        incur debt contract (OHM) or back to LPer's wallet address (pair token). Other strategies like
        curve will have no leftover tokens.
        This function is also only for LPing for pools with two tokens. Do not use this for pools with more than 2 tokens.
        @param _data Data needed to input into external call to add liquidity. Different for different strategies.
        @param _ohmAmount amount of OHM to LP 
        @param _user address of user that called incur debt function to do this operation.
        @return liquidity : total amount of lp tokens gained.
        ohmUnused : total amount of ohm unused in LP process and sent back to incur debt address.
        lpTokenAddress : address of LP token gained.
    */
    function addLiquidity(
        bytes memory _data,
        uint256 _ohmAmount,
        address _user
    )
        external
        returns (
            uint256 liquidity,
            uint256 ohmUnused,
            address lpTokenAddress
        );

    /**
        @notice Remove liquidity to the dex using this strategy.
        @param _data Data needed to input into external call to remove liquidity. Different for different strategies.
        @param _liquidity amount of LP tokens to remove liquidity from.
        @param _lpTokenAddress address of LP token to remove.
        @param _user address of user that called incur debt function to do this operation.
        @return ohmRecieved : total amount of ohm recieved from removing the LP. Send back to incurdebt contract.
    */
    function removeLiquidity(
        bytes memory _data,
        uint256 _liquidity,
        address _lpTokenAddress,
        address _user
    ) external returns (uint256 ohmRecieved);
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.4;

/// @notice simplified IncurDebt to work as a Tokemak controller
/// @dev this contract must be given OHMDEBTOR on the treasury
interface IIncurDebt {
    /* ========== TOKEMAK FUNCTIONS ========== */

    /**
     * @notice deposits gOHM to use as collateral
     * - msg.sender must be a borrower
     * - this contract must have been approved _amount
     * @param _amount amount of gOHM
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice allow borrowers to borrow OHM
     * - msg.sender must be a borrower
     * - _ohmAmount must be less than or equal to borrowers debt limit
     * - _ohmAmount must be less than or equal to borrowers available loan limit
     * @param _ohmAmount amount of OHM to borrow
     */
    function borrow(uint256 _ohmAmount) external;

    /**
     * @notice withdraws gOHM
     * - msg.sender must be a borrower
     * - _amount (in OHM) must be less than or equal to depositedOhm - debt
     * @param _amount amount of gOHM/sOHM to withdraw
     */
    function withdraw(uint256 _amount) external;

    /**
     * @notice Creates an LP position by borrowing OHM
     * - msg.sender must be whitelisted
     * - the strategy must be whitelisted
     * - the strategy contract must have been approved _pairAmount of _pairToken
     * - _ohmAmount must be less than or equal to available debt
     * @param _ohmAmount the desired amount of OHM to borrow
     * @param _strategy the address of the AMM strategy to use
     * @param _strategyParams strategy-specific params
     * @return number of LP tokens created
     */
    function createLP(
        uint256 _ohmAmount,
        address _strategy,
        bytes calldata _strategyParams
    ) external returns (uint256);

    /**
     * @notice unwinds an LP position and pays off OHM debt. Excess ohm is sent back to caller.
     * @param _liquidity the amount of LP tokens to remove.
     * @param _strategy the address of the AMM strategy to use
     * @param _lpToken address of lp token to remove liquidity from
     * @param _strategyParams strategy-specific params
     * @return ohmRecieved of _pair token send to _to and OHM to pay
     */
    function removeLP(
        uint256 _liquidity,
        address _strategy,
        address _lpToken,
        bytes calldata _strategyParams
    ) external returns (uint256);

    /**
     * @notice repay debt with collateral
     * - msg.sender must be a borrower
     * - borrower must have outstanding debt
     */
    function repayDebtWithCollateral() external;

    /**
     * @notice repay debt with collateral and withdraw the accrued earnings to gOHM
     * - msg.sender must be a borrower
     * - borrower must have outstanding debt
     */
    function repayDebtWithCollateralAndWithdrawTheRest() external;

    /**
     * @notice deposits OHM to pay debt
     * - msg.sender must be a borrower
     * - msg.sender's OHM allowance must be >= _ohmAmount
     * - borrower must have outstanding debt
     * @param _ohmAmount amount of OHM to borrow
     */
    function repayDebtWithOHM(uint256 _ohmAmount) external;

    /**
     * @notice gets available OHM to borrow for account
     * @return amount OHM available to borrow
     */
    function getAvailableToBorrow() external view returns (uint256);

    /* ========== MANAGEMENT FUNCTIONS ========== */

    /**
     * @notice sets the maximum debt limit for the system
     * - onlyOwner (or governance)
     * - must be greater than or equal to existing debt
     * @param _limit in OHM
     */
    function setGlobalDebtLimit(uint256 _limit) external;

    /// @notice lets a user become a LP borrower
    /// - onlyOwner (or governance)
    /// - user must not be borrower
    /// @param _borrower the address that will interact with contract
    function allowLPBorrower(address _borrower) external;

    /// @notice lets a user become a Non LP borrower
    /// - onlyOwner (or governance)
    /// - user must not be borrower
    /// @param _borrower the address that will interact with contract
    function allowNonLPBorrower(address _borrower) external;

    /**
     * @notice sets the maximum debt limit for a borrower
     * - onlyOwner (or governance)
     * - limit must be greater than or equal to borrower's outstanding debt
     * - limit must be less than or equal to the global debt limit
     * @param _borrower the address that will interact with contract
     * @param _limit borrower's debt limit in OHM
     */
    function setBorrowerDebtLimit(address _borrower, uint256 _limit) external;

    /**
     * @notice revoke user right to borrow
     * - onlyOwner (or governance)
     * - user must be borrower
     * - borrower must not have outstanding debt
     * @param _borrower the address that will interact with contract
     */
    function revokeBorrower(address _borrower) external;

    /**
     * @notice repays debt using collateral and returns remaining tokens to borrower
     * - onlyOwner (or governance)
     * - sends remaining tokens to owner in GOHM
     * @param _borrower the address that will interact with contract
     */
    function forceRepay(address _borrower) external;

    /**
     * @notice seize and burn _borrowers collateral and forgive debt
     * - will burn all collateral, including excess of debt
     * - onlyGovernance
     * @param _borrower the account to seize
     */
    function seize(address _borrower) external;

    /// @notice lets governor withdraw tokens incase of airdrop or error
    /// - onlyOwner (or governance)
    /// @param _tokenAddress the address of the token
    /// @param _amount amount of tokens to withdraw
    function withdrawToken(address _tokenAddress, uint256 _amount) external;

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for depositing to a Balancer pool
    /// @param _poolId The ID for the pool you wish to deploy assets into
    /// @param _assets A sorted (by address) list of all of the tokens in the relevant pool
    /// @param _maxAmountsIn The maximum amount of each token in the _assets list you would like to send to the pool
    ///                      These amounts need to match by index to the assets in _assets
    /// @param _minimumBPT The minimum number of balancer pool tokens you would like to receive
    function encodeBalancerCreateParams(
        bytes32 _poolId,
        address[] memory _assets,
        uint256[] memory _maxAmountsIn,
        uint256 _minimumBPT
    ) external pure returns (bytes memory encodedParams);

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for removing from a Balancer pool
    /// @param _poolId The ID for the pool you wish to deploy assets into
    /// @param _assets A sorted (by address) list of the tokens in the pool
    /// @param _minAmountsOut The minimum amount of each token in the _assets list you expect to receive
    ///                       These amounts need to match by index to the assets in _assets
    function encodeBalancerRemoveParams(
        bytes32 _poolId,
        address[] memory _assets,
        uint256[] memory _minAmountsOut
    ) external pure returns (bytes memory encodedParams);

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for depositing to a Curve pool
    /// @param _amounts The amount of each token to deposit to the Curve pool
    /// @param _min_mint_amount The minimum amount of LP tokens to receive. Otherwise revert deposit.
    /// @param _pairTokenAddress The address for the non-OHM token in the Curve pair
    /// @param _poolAddress The address of the Curve pool to deposit into
    function encodeCurveCreateParams(
        uint256[2] memory _amounts,
        uint256 _min_mint_amount,
        address _pairTokenAddress,
        address _poolAddress
    ) external pure returns (bytes memory encodedParams);

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for a Curve pool
    /// @param _burn_amount Amount of Curve Pool LP tokens to burn and get assets back for
    /// @param _min_amounts The minimum amounts of each token in the pool to receive back. Otherwise revert.
    function encodeCurveRemoveParams(uint256 _burn_amount, uint256[2] memory _min_amounts)
        external
        pure
        returns (bytes memory encodedParams);

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the createLP function
    ///         for a Uniswap or Sushiswap pool
    /// @param _tokenA The first token in the pool
    /// @param _tokenB The second token in the pool
    /// @param _amountADesired The amount of token A you wish to deposit into the pool
    /// @param _amountBDesired The amount of token B you wish to deposit into the pool
    /// @param _amountAMin The minimum amount of token A you would accept depositing. Otherwise revert.
    /// @param _amountBMin The minimum amount of token B you would accept depositing. Otherwise revet.
    function encodeUniswapCreateParams(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external pure returns (bytes memory encodedParams);

    /// @notice Encodes the necessary parameters to pass as _strategyParams in the removeLP function
    ///         for a Uniswap or Sushiswap pool
    /// @param _tokenA The first token in the pool
    /// @param _tokenB The second token in the pool
    /// @param _liquidity Amount of liquidity tokens to send back and remove liquidity for
    /// @param _amountAMin The minimum amount of token A you would accept back for the liquidity tokens you've returned
    /// @param _amountBMin The minimum amount of token B you would accept back for the liquidity tokens you've returned
    function encodeUniswapRemoveParams(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) external pure returns (bytes memory encodedParams);
}

pragma solidity ^0.8.10;

import "../interfaces/IOlympusAuthority.sol";

error UNAUTHORIZED();
error AUTHORITY_INITIALIZED();

/// @dev Reasoning for this contract = modifiers literaly copy code
/// instead of pointing towards the logic to execute. Over many
/// functions this bloats contract size unnecessarily.
/// imho modifiers are a meme.
abstract contract OlympusAccessControlledV2 {
    /* ========== EVENTS ========== */

    event AuthorityUpdated(IOlympusAuthority authority);

    /* ========== STATE VARIABLES ========== */

    IOlympusAuthority public authority;

    /* ========== Constructor ========== */

    constructor(IOlympusAuthority _authority) {
        authority = _authority;
        emit AuthorityUpdated(_authority);
    }

    /* ========== "MODIFIERS" ========== */

    modifier onlyGovernor {
	_onlyGovernor();
	_;
    }

    modifier onlyGuardian {
	_onlyGuardian();
	_;
    }

    modifier onlyPolicy {
	_onlyPolicy();
	_;
    }

    modifier onlyVault {
	_onlyVault();
	_;
    }

    /* ========== GOV ONLY ========== */

    function initializeAuthority(IOlympusAuthority _newAuthority) internal {
        if (authority != IOlympusAuthority(address(0))) revert AUTHORITY_INITIALIZED();
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }

    function setAuthority(IOlympusAuthority _newAuthority) external {
        _onlyGovernor();
        authority = _newAuthority;
        emit AuthorityUpdated(_newAuthority);
    }

    /* ========== INTERNAL CHECKS ========== */

    function _onlyGovernor() internal view {
        if (msg.sender != authority.governor()) revert UNAUTHORIZED();
    }

    function _onlyGuardian() internal view {
        if (msg.sender != authority.guardian()) revert UNAUTHORIZED();
    }

    function _onlyPolicy() internal view {
        if (msg.sender != authority.policy()) revert UNAUTHORIZED();
    }

    function _onlyVault() internal view {
        if (msg.sender != authority.vault()) revert UNAUTHORIZED();
    }
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.7.5;

interface IOlympusAuthority {
    /* ========== EVENTS ========== */

    event GovernorPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event GuardianPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event PolicyPushed(address indexed from, address indexed to, bool _effectiveImmediately);
    event VaultPushed(address indexed from, address indexed to, bool _effectiveImmediately);

    event GovernorPulled(address indexed from, address indexed to);
    event GuardianPulled(address indexed from, address indexed to);
    event PolicyPulled(address indexed from, address indexed to);
    event VaultPulled(address indexed from, address indexed to);

    /* ========== VIEW ========== */

    function governor() external view returns (address);

    function guardian() external view returns (address);

    function policy() external view returns (address);

    function vault() external view returns (address);
}