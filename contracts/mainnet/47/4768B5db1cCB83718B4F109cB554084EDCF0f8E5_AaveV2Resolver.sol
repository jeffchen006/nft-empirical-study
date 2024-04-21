// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./interfaces.sol";
import "./helpers.sol";

contract Resolver is AaveHelpers {
    constructor(
        address _wethAddr,
        address _aaveAddressProvider,
        address _aaveProtocolDataProvider,
        address _chainlinkEthFeed,
        address _aaveIncentivesAddress
    )
        AaveHelpers(
            _wethAddr,
            _aaveAddressProvider,
            _aaveProtocolDataProvider,
            _chainlinkEthFeed,
            _aaveIncentivesAddress
        )
    {}

    function getPosition(address user, address[] memory tokens)
        public
        view
        returns (AaveUserTokenData[] memory, AaveUserData memory)
    {
        AaveAddressProvider addrProvider = AaveAddressProvider(
            getAaveAddressProvider()
        );
        uint256 length = tokens.length;
        address[] memory _tokens = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            _tokens[i] = tokens[i] == getEthAddr() ? getWethAddr() : tokens[i];
        }

        AaveUserTokenData[] memory tokensData = new AaveUserTokenData[](length);
        (TokenPrice[] memory tokenPrices, uint256 ethPrice) = getTokensPrices(
            addrProvider,
            _tokens
        );

        for (uint256 i = 0; i < length; i++) {
            tokensData[i] = getTokenData(
                AaveProtocolDataProvider(getAaveProtocolDataProvider()),
                user,
                _tokens[i],
                tokenPrices[i].priceInEth,
                tokenPrices[i].priceInUsd
            );
        }

        return (
            tokensData,
            getUserData(
                AaveLendingPool(addrProvider.getLendingPool()),
                user,
                ethPrice,
                _tokens
            )
        );
    }

    function getConfiguration(address user)
        public
        view
        returns (bool[] memory collateral, bool[] memory borrowed)
    {
        AaveAddressProvider addrProvider = AaveAddressProvider(
            getAaveAddressProvider()
        );
        uint256 data = getConfig(
            user,
            AaveLendingPool(addrProvider.getLendingPool())
        ).data;
        address[] memory reserveIndex = getList(
            AaveLendingPool(addrProvider.getLendingPool())
        );

        collateral = new bool[](reserveIndex.length);
        borrowed = new bool[](reserveIndex.length);

        for (uint256 i = 0; i < reserveIndex.length; i++) {
            if (isUsingAsCollateralOrBorrowing(data, i)) {
                collateral[i] = (isUsingAsCollateral(data, i)) ? true : false;
                borrowed[i] = (isBorrowing(data, i)) ? true : false;
            }
        }
    }

    function getReservesList() public view returns (address[] memory data) {
        AaveAddressProvider addrProvider = AaveAddressProvider(
            getAaveAddressProvider()
        );
        data = getList(AaveLendingPool(addrProvider.getLendingPool()));
    }
}

contract AaveV2Resolver is Resolver {
    constructor(
        address _wethAddr,
        address _aaveAddressProvider,
        address _aaveProtocolDataProvider,
        address _chainlinkEthFeed,
        address _aaveIncentivesAddress
    )
        Resolver(
            _wethAddr,
            _aaveAddressProvider,
            _aaveProtocolDataProvider,
            _chainlinkEthFeed,
            _aaveIncentivesAddress
        )
    {}

    string public constant name = "AaveV2-Resolver";
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface AaveProtocolDataProvider {
    function getUserReserveData(address asset, address user)
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

    function getReserveTokensAddresses(address asset)
        external
        view
        returns (
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress
        );
}

interface AaveLendingPool {
    struct UserConfigurationMap {
        uint256 data;
    }

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

    function getUserConfiguration(address user)
        external
        view
        returns (UserConfigurationMap memory);

    function getReservesList() external view returns (address[] memory);
}

interface TokenInterface {
    function totalSupply() external view returns (uint256);
}

interface AaveAddressProvider {
    function getLendingPool() external view returns (address);

    function getPriceOracle() external view returns (address);
}

interface AavePriceOracle {
    function getAssetPrice(address _asset) external view returns (uint256);

    function getAssetsPrices(address[] calldata _assets)
        external
        view
        returns (uint256[] memory);

    function getSourceOfAsset(address _asset) external view returns (uint256);

    function getFallbackOracle() external view returns (uint256);
}

interface AaveIncentivesInterface {
    struct AssetData {
        uint128 emissionPerSecond;
        uint128 lastUpdateTimestamp;
        uint256 index;
    }

    function getRewardsBalance(address[] calldata assets, address user)
        external
        view
        returns (uint256);

    function assets(address asset) external view returns (AssetData memory);
}

interface ChainLinkInterface {
    function latestAnswer() external view returns (int256);

    function decimals() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "./interfaces.sol";

import {DSMath} from "../utils/dsmath.sol";

contract AaveHelpers is DSMath {
    address internal wethAddr;
    address internal aaveAddressProvider;
    address internal aaveProtocolDataProvider;
    address internal chainlinkEthFeed;
    address internal aaveIncentivesAddress;

    constructor(
        address _wethAddr,
        address _aaveAddressProvider,
        address _aaveProtocolDataProvider,
        address _chainlinkEthFeed,
        address _aaveIncentivesAddress
    ) {
        wethAddr = _wethAddr;
        aaveAddressProvider = _aaveAddressProvider;
        aaveProtocolDataProvider = _aaveProtocolDataProvider;
        chainlinkEthFeed = _chainlinkEthFeed;
        aaveIncentivesAddress = _aaveIncentivesAddress;
    }

    /**
     * @dev Return ethereum address
     */
    function getEthAddr() internal pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // ETH Address
    }

    /**
     * @dev Return Weth address
     */
    function getWethAddr() internal view returns (address) {
        // return 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // Kovan WETH Address
        return wethAddr;
    }

    /**
     * @dev get Aave Provider Address
     */
    function getAaveAddressProvider() internal view returns (address) {
        // return 0x88757f2f99175387aB4C6a4b3067c77A695b0349; // Kovan
        // return 0x8bD206df9853d23bE158A9F7065Cf60A7A5F05DF; // private
        return aaveAddressProvider;
    }

    /**
     * @dev get Aave Protocol Data Provider
     */
    function getAaveProtocolDataProvider() internal view returns (address) {
        // return 0x3c73A5E5785cAC854D468F727c606C07488a29D6; // Kovan
        // return 0xBE24eEC0e36B39346Ccb1DFF7a4A9ef58383358E; // private
        return aaveProtocolDataProvider;
    }

    /**
     * @dev get Chainlink ETH price feed Address
     */
    function getChainlinkEthFeed() internal view returns (address) {
        // return 0x9326BFA02ADD2366b30bacB125260Af641031331; //kovan
        // return 0x912992e0A37D6D3328Fea81E2001BCa44DC764Dc; //private
        return chainlinkEthFeed;
    }

    /**
     * @dev Aave Incentives address
     */
    function getAaveIncentivesAddress() internal view returns (address) {
        // return 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5; // mainnet
        return aaveIncentivesAddress;
    }

    struct AaveUserTokenData {
        uint256 tokenPriceInEth; //
        uint256 tokenPriceInUsd;
        uint256 supplyBalance;
        uint256 stableBorrowBalance;
        uint256 variableBorrowBalance;
        uint256 supplyRate;
        uint256 stableBorrowRate;
        uint256 userStableBorrowRate;
        uint256 variableBorrowRate;
        bool isCollateral;
        AaveTokenData aaveTokenData;
    }

    struct AaveUserData {
        uint256 totalCollateralETH;
        uint256 totalBorrowsETH;
        uint256 availableBorrowsETH;
        uint256 currentLiquidationThreshold;
        uint256 ltv;
        uint256 healthFactor;
        uint256 ethPriceInUsd;
        uint256 pendingRewards;
    }

    struct AaveTokenData {
        uint256 ltv;
        uint256 threshold;
        uint256 reserveFactor;
        bool usageAsCollEnabled;
        bool borrowEnabled;
        bool stableBorrowEnabled;
        bool isActive;
        bool isFrozen;
        uint256 totalSupply;
        uint256 availableLiquidity;
        uint256 totalStableDebt;
        uint256 totalVariableDebt;
        // uint256 collateralEmission;
        // uint256 debtEmission;
    }

    struct TokenPrice {
        uint256 priceInEth;
        uint256 priceInUsd;
    }

    function getTokensPrices(
        AaveAddressProvider _aaveAddressProvider,
        address[] memory tokens
    )
        internal
        view
        returns (TokenPrice[] memory tokenPrices, uint256 ethPrice)
    {
        uint256[] memory _tokenPrices = AavePriceOracle(
            _aaveAddressProvider.getPriceOracle()
        ).getAssetsPrices(tokens);
        ethPrice = uint256(
            ChainLinkInterface(getChainlinkEthFeed()).latestAnswer()
        );
        tokenPrices = new TokenPrice[](_tokenPrices.length);
        for (uint256 i = 0; i < _tokenPrices.length; i++) {
            tokenPrices[i] = TokenPrice(
                _tokenPrices[i],
                wmul(_tokenPrices[i], uint256(ethPrice) * 10**10)
            );
        }
    }

    function collateralData(AaveProtocolDataProvider aaveData, address token)
        internal
        view
        returns (AaveTokenData memory aaveTokenData)
    {
        (
            ,
            aaveTokenData.ltv,
            aaveTokenData.threshold,
            ,
            aaveTokenData.reserveFactor,
            aaveTokenData.usageAsCollEnabled,
            aaveTokenData.borrowEnabled,
            aaveTokenData.stableBorrowEnabled,
            aaveTokenData.isActive,
            aaveTokenData.isFrozen
        ) = aaveData.getReserveConfigurationData(token);

        (address aToken, , ) = aaveData.getReserveTokensAddresses(token);

        aaveTokenData.totalSupply = TokenInterface(aToken).totalSupply();
    }

    function getTokenData(
        AaveProtocolDataProvider aaveData,
        address user,
        address token,
        uint256 tokenPriceInEth,
        uint256 tokenPriceInUsd
    ) internal view returns (AaveUserTokenData memory tokenData) {
        AaveTokenData memory aaveTokenData = collateralData(aaveData, token);

        (
            tokenData.supplyBalance,
            tokenData.stableBorrowBalance,
            tokenData.variableBorrowBalance,
            ,
            ,
            tokenData.userStableBorrowRate,
            ,
            ,
            tokenData.isCollateral
        ) = aaveData.getUserReserveData(token, user);

        (
            aaveTokenData.availableLiquidity,
            aaveTokenData.totalStableDebt,
            aaveTokenData.totalVariableDebt,
            tokenData.supplyRate,
            tokenData.variableBorrowRate,
            tokenData.stableBorrowRate,
            ,
            ,
            ,

        ) = aaveData.getReserveData(token);

        tokenData.tokenPriceInEth = tokenPriceInEth;
        tokenData.tokenPriceInUsd = tokenPriceInUsd;
        tokenData.aaveTokenData = aaveTokenData;
    }

    function getPendingRewards(address[] memory _tokens, address user)
        internal
        view
        returns (uint256 rewards)
    {
        uint256 arrLength = 2 * _tokens.length;
        address[] memory _atokens = new address[](arrLength);
        AaveProtocolDataProvider aaveData = AaveProtocolDataProvider(
            getAaveProtocolDataProvider()
        );
        for (uint256 i = 0; i < _tokens.length; i++) {
            (_atokens[2 * i], , _atokens[2 * i + 1]) = aaveData
                .getReserveTokensAddresses(_tokens[i]);
        }
        rewards = AaveIncentivesInterface(getAaveIncentivesAddress())
            .getRewardsBalance(_atokens, user);
    }

    function getUserData(
        AaveLendingPool aave,
        address user,
        uint256 ethPriceInUsd,
        address[] memory tokens
    ) internal view returns (AaveUserData memory userData) {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = aave.getUserAccountData(user);
        uint256 pendingRewards;
        if (aaveIncentivesAddress != address(0)) {
            pendingRewards = getPendingRewards(tokens, user);
        }
        userData = AaveUserData(
            totalCollateralETH,
            totalDebtETH,
            availableBorrowsETH,
            currentLiquidationThreshold,
            ltv,
            healthFactor,
            ethPriceInUsd,
            pendingRewards
        );
    }

    function getConfig(address user, AaveLendingPool aave)
        public
        view
        returns (AaveLendingPool.UserConfigurationMap memory data)
    {
        data = aave.getUserConfiguration(user);
    }

    function getList(AaveLendingPool aave)
        public
        view
        returns (address[] memory data)
    {
        data = aave.getReservesList();
    }

    function isUsingAsCollateralOrBorrowing(uint256 self, uint256 reserveIndex)
        public
        pure
        returns (bool)
    {
        require(reserveIndex < 128, "can't be more than 128");
        return (self >> (reserveIndex * 2)) & 3 != 0;
    }

    function isUsingAsCollateral(uint256 self, uint256 reserveIndex)
        public
        pure
        returns (bool)
    {
        require(reserveIndex < 128, "can't be more than 128");
        return (self >> (reserveIndex * 2 + 1)) & 1 != 0;
    }

    function isBorrowing(uint256 self, uint256 reserveIndex)
        public
        pure
        returns (bool)
    {
        require(reserveIndex < 128, "can't be more than 128");
        return (self >> (reserveIndex * 2)) & 1 != 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;

contract DSMath {
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x, "math-not-safe");
    }

    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x - y <= x ? x - y : 0;
    }

    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(y == 0 || (z = x * y) / y == x, "math-not-safe");
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    uint256 internal constant WAD = 10**18;
    uint256 internal constant RAY = 10**27;

    function rmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }

    function wmul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }

    function rdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    function wdiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
}