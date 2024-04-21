// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DSMath} from "../library/DSMath.sol";
import {ProtocolWETH, WethInterface} from "./ProtocolWETH.sol";

contract ProtocolAaveV2 is DSMath, ProtocolWETH {
    // Aave Referral Code

    uint16 internal constant referralCode = 3228;

    address internal constant ethAddr =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    // // Aave Lending Pool Provider
    // AaveLendingPoolProviderInterface internal aaveProvider;
    // // Aave Protocol Data Provider
    // AaveDataProviderInterface internal aaveData;
    // // Aave Price Oracle
    // AavePriceOracleInterface internal aavePrice;
    address public immutable aaveProvider;
    address public immutable aaveData;
    address public immutable aavePrice;

    constructor(
        address _wethAddress,
        address _aaveProvider,
        address _aaveData,
        address _aavePrice
    ) ProtocolWETH(_wethAddress) {
        //0x8bD206df9853d23bE158A9F7065Cf60A7A5F05DF
        aaveProvider = _aaveProvider;
        //0xBE24eEC0e36B39346Ccb1DFF7a4A9ef58383358E
        aaveData = _aaveData;
        //0x4578344f10246e3dc96b7D2c6E7854fF3798678A
        aavePrice = _aavePrice;
    }

    event AaveV2Deposit(
        address indexed token,
        uint256 tokenAmt,
        uint256 getId,
        uint256 setId
    );

    event AaveV2Withdraw(
        address indexed token,
        uint256 tokenAmt,
        uint256 getId,
        uint256 setId
    );

    event AaveV2Borrow(
        address indexed token,
        uint256 tokenAmt,
        uint256 indexed rateMode,
        uint256 getId,
        uint256 setId
    );

    event AaveV2Payback(
        address indexed token,
        uint256 tokenAmt,
        uint256 indexed rateMode,
        uint256 getId,
        uint256 setId
    );

    event AaveV2EnableCollateral(address[] tokens);

    event AaveV2SwapRateMode(address indexed token, uint256 rateMode);

    function depositToken(address token, uint256 amt)
        public
        payable
        returns (uint256 _amt)
    {
        _amt = amt;

        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );

        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        WethInterface tokenContract = WethInterface(_token);

        if (isEth) {
            _amt = _amt == type(uint256).max ? address(this).balance : _amt;
            convertEthToWeth(isEth, tokenContract, _amt);
        } else {
            _amt = _amt == type(uint256).max
                ? tokenContract.balanceOf(address(this))
                : _amt;
        }

        approve(tokenContract, address(aave), _amt);

        aave.deposit(_token, _amt, address(this), referralCode);

        if (!getIsColl(_token)) {
            aave.setUserUseReserveAsCollateral(_token, true);
        }
    }

    function withdrawToken(address token, uint256 amt)
        public
        payable
        returns (uint256 _amt)
    {
        _amt = amt;

        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );
        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        WethInterface tokenContract = WethInterface(_token);

        uint256 initialBal = tokenContract.balanceOf(address(this));
        aave.withdraw(_token, _amt, address(this));
        uint256 finalBal = tokenContract.balanceOf(address(this));

        _amt = sub(finalBal, initialBal);

        convertWethToEth(isEth, tokenContract, _amt);
    }

    function borrowToken(
        address token,
        uint256 amt,
        uint256 rateMode
    ) public payable returns (uint256 _amt) {
        _amt = amt;

        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );

        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        aave.borrow(_token, _amt, rateMode, referralCode, address(this));
        convertWethToEth(isEth, WethInterface(_token), _amt);
    }

    function paybackToken(
        address token,
        uint256 amt,
        uint256 rateMode
    ) public payable returns (uint256 _amt) {
        _amt = amt;

        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );

        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        WethInterface tokenContract = WethInterface(_token);

        _amt = _amt == type(uint256).max
            ? getPaybackBalance(_token, rateMode)
            : _amt;

        require(
            _amt <= getPaybackBalance(_token, rateMode),
            "CHFRY: AAVE repay overfloor"
        );

        if (isEth) convertEthToWeth(isEth, tokenContract, _amt);

        approve(tokenContract, address(aave), _amt);

        aave.repay(_token, _amt, rateMode, address(this));
    }

    function enableTokenCollateral(address[] calldata tokens) public payable {
        uint256 _length = tokens.length;
        require(_length > 0, "0-tokens-not-allowed");

        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );

        for (uint256 i = 0; i < _length; i++) {
            address token = tokens[i];
            if (getCollateralBalance(token) > 0 && !getIsColl(token)) {
                aave.setUserUseReserveAsCollateral(token, true);
            }
        }
    }

    function swapTokenBorrowRateMode(address token, uint256 rateMode)
        public
        payable
    {
        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );

        uint256 currentRateMode = rateMode == 1 ? 2 : 1;

        if (getPaybackBalance(token, currentRateMode) > 0) {
            aave.swapBorrowRateMode(token, rateMode);
        }
    }

    function getIsColl(address token) internal view returns (bool isCol) {
        (, , , , , , , , isCol) = AaveDataProviderInterface(aaveData)
            .getUserReserveData(token, address(this));
    }

    function getPaybackBalance(address token, uint256 rateMode)
        public
        view
        returns (uint256)
    {
        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        (
            ,
            uint256 stableDebt,
            uint256 variableDebt,
            ,
            ,
            ,
            ,
            ,

        ) = AaveDataProviderInterface(aaveData).getUserReserveData(
                _token,
                address(this)
            );
        return rateMode == 1 ? stableDebt : variableDebt;
    }

    function getCollateralBalance(address token)
        public
        view
        returns (uint256 bal)
    {
        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        (bal, , , , , , , , ) = AaveDataProviderInterface(aaveData)
            .getUserReserveData(_token, address(this));
    }

    function getPrice(address token) public view returns (uint256 price) {
        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        price = AavePriceOracleInterface(aavePrice).getAssetPrice(_token);
    }

    function getLTV(address token) public view returns (uint256 ltv) {
        bool isEth = token == ethAddr;
        address _token = isEth ? wethAddr : token;

        (, ltv, , , , , , , , ) = AaveDataProviderInterface(aaveData)
            .getReserveConfigurationData(_token);
    }

    function getUserAccountData()
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );
        (
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        ) = aave.getUserAccountData(address(this));
    }

    function getEOAUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        AaveInterface aave = AaveInterface(
            AaveLendingPoolProviderInterface(aaveProvider).getLendingPool()
        );
        (
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor
        ) = aave.getUserAccountData(user);
    }
}

interface AaveInterface {
    function getReserveData(address asset) external view returns (bytes memory);

    function deposit(
        address _asset,
        uint256 _amount,
        address _onBehalfOf,
        uint16 _referralCode
    ) external;

    function withdraw(
        address _asset,
        uint256 _amount,
        address _to
    ) external;

    function borrow(
        address _asset,
        uint256 _amount,
        uint256 _interestRateMode,
        uint16 _referralCode,
        address _onBehalfOf
    ) external;

    function repay(
        address _asset,
        uint256 _amount,
        uint256 _rateMode,
        address _onBehalfOf
    ) external;

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function setUserUseReserveAsCollateral(
        address _asset,
        bool _useAsCollateral
    ) external;

    function swapBorrowRateMode(address _asset, uint256 _rateMode) external;

    function getUserConfiguration(address user) external view returns (uint256);

    function getReservesList() external view returns (address[] memory);
}

interface AaveLendingPoolProviderInterface {
    function getLendingPool() external view returns (address);

    function getPriceOracle() external view returns (address);
}

interface AavePriceOracleInterface {
    function getAssetPrice(address _asset) external view returns (uint256);
}

interface AaveDataProviderInterface {
    function getReserveTokensAddresses(address _asset)
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );

    function getReserveConfigurationData(address asset)
        external
        view
        returns (
            uint256 decimals,
            uint256 ltv,
            uint256 liquidationThreshold,
            uint256 liquidationBonus,
            uint256 reserveFactor,
            bool usageAsCollateralEnabled,
            bool borrowingEnabled,
            bool stableBorrowRateEnabled,
            bool isActive,
            bool isFrozen
        );

    function getReserveData(address asset)
        external
        view
        returns (
            uint256 availableLiquidity,
            uint256 totalStableDebt,
            uint256 totalVariableDebt,
            uint256 liquidityRate,
            uint256 variableBorrowRate,
            uint256 stableBorrowRate,
            uint256 averageStableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint40 lastUpdateTimestamp
        );

    function getUserReserveData(address _asset, address _user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityRate,
            uint40 stableRateLastUpdated,
            bool usageAsCollateralEnabled
        );
}

interface AaveAddressProviderRegistryInterface {
    function getAddressesProvidersList()
        external
        view
        returns (address[] memory);
}

interface AWethInterface {
    function balanceOf(address _user) external view returns (uint256);
}

interface AaveStakedTokenIncentivesController {
    function getRewardsBalance(address[] calldata assets, address user)
        external
        view
        returns (uint256);

    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to
    ) external returns (uint256);

    function claimRewardsOnBehalf(
        address[] calldata assets,
        uint256 amount,
        address user,
        address to
    ) external returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DSMath {

    uint256 constant WAD = 10**18;
    
    uint256 constant RAY = 10**27;

    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.add(x, y);
    }

    function sub(uint256 x, uint256 y)
        internal
        pure
        virtual
        returns (uint256 z)
    {
        z = SafeMath.sub(x, y);
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.mul(x, y);
    }

    function div(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.div(x, y);
    }

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.add(SafeMath.mul(x, y), WAD / 2) / WAD;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.add(SafeMath.mul(x, WAD), y / 2) / y;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.add(SafeMath.mul(x, RAY), y / 2) / y;
    }

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = SafeMath.add(SafeMath.mul(x, y), RAY / 2) / RAY;
    }

    function toInt(uint256 x) internal pure returns (int256 y) {
        y = int256(x);
        require(y >= 0, "int-overflow");
    }

    function toRad(uint256 wad) internal pure returns (uint256 rad) {
        rad = mul(wad, 10**27);
    }

    function convert18ToDec(uint256 _dec, uint256 _amt)
        internal
        pure
        returns (uint256 amt)
    {
        amt = (_amt / 10**(18 - _dec));
    }

    function convertTo18(uint256 _dec, uint256 _amt)
        internal
        pure
        returns (uint256 amt)
    {
        amt = mul(_amt, 10**(18 - _dec));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface WethInterface {
    function approve(address, uint256) external;
    function deposit() external payable;
    function withdraw(uint) external;
    function decimals() external view returns (uint);
    function balanceOf(address) external view returns (uint);
}

abstract contract ProtocolWETH {

    address public immutable wethAddr;

    constructor(address _wethAddr) {
        wethAddr = _wethAddr;
    }

    function convertEthToWeth(
        bool isEth,
        WethInterface token,
        uint256 amount
    ) internal {
        if (isEth) token.deposit{value: amount}();
    }

    function convertWethToEth(
        bool isEth,
        WethInterface token,
        uint256 amount
    ) internal {
        if (isEth) {
            approve(token, address(token), amount);
            token.withdraw(amount);
        }
    }

    function approve(
        WethInterface token,
        address spender,
        uint256 amount
    ) internal {
        try token.approve(spender, amount) {} catch {
            token.approve(spender, 0);
            token.approve(spender, amount);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}