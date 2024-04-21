// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./interfaces/ICToken.sol";
import "./interfaces/IFeeDistributor.sol";
import "./interfaces/IWETH.sol";

/**
 * @title Pawnfi's FeeManager Contract
 * @author Pawnfi
 */
contract FeeManager is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private constant DENOMINATOR = 10000;

    uint256 private constant WEEK = 604800;

    /// @notice Start time
    uint256 public startTime;

    /// @notice Lending market fee distribution rate
    uint256 public feeRate;

    /// @notice WETH address
    address public WETH;

    /// @notice incentiveVoting address
    address public incentiveVoting;

    /// @notice feeDistributor address
    address public feeDistributor;

    /**
     * @notice Lending market info 
     * @member lastReserves Reserve from last distribution
     * @member lastTime Last distribution time
     * @member claimed Accumulated fee distribution
     */
    struct MarketInfo {
        uint256 lastReserves;
        uint256 lastTime;
        uint256 claimed;
    }

    /// @notice Get lending market info based on market address
    mapping(address => MarketInfo) public marketInfo;

    /// @notice Get market address based on asset address
    mapping(address => address) public getMarket;

    /// @notice Reward token address
    address public rewardToken;

    /// @notice Interval time for rewards
    uint256 public rewardInterval;

    /// @notice Get refresh reward amount based on market address
    mapping(address => uint256) public marketIncentiveReward;

    /// @notice Emitted when update the interval time for rewards
    event RewardIntervalUpdate(uint256 oldRewardInterval, uint256 newRewardInterval);

    /// @notice Emitted when set refresh reward amount
    event MarketIncentiveRewardUpdate(address indexed market, uint256 newIncentiveReward);

    /// @notice Emitted when updat lending market fee distribution rate
    event FeeRateUpdate(uint256 oldFeeRate, uint256 newFeeRate);

    /// @notice Emitted when set corresponding lending marekt address
    event SetMarket(address indexed asset, address market);

    constructor() initializer {}

    /**
     * @notice Initialize parameters
     * @param owner_ owner address
     * @param feeRate_ Fee distribution rate
     * @param WETH_ WETH address
     * @param feeDistributor_ feeDistributor contract address
     * @param rewardToken_ Reward token address
     */
    function initialize(address owner_, uint256 feeRate_, address WETH_, address incentiveVoting_, address feeDistributor_, address rewardToken_) external initializer {
        _transferOwnership(owner_);
        feeRate = feeRate_;
        WETH = WETH_;
        incentiveVoting = incentiveVoting_;
        feeDistributor = feeDistributor_;
        rewardToken = rewardToken_;
        startTime = IFeeDistributor(feeDistributor_).startTime();
    }

    /**
     * @notice Set interval time for rewards
     * @param newRewardInterval Interval time for rewards
     */
    function setRewardThreshold(uint256 newRewardInterval) external onlyOwner {
        emit RewardIntervalUpdate(rewardInterval, newRewardInterval);
        rewardInterval = newRewardInterval;
    }

    /**
     * @notice Set refresh reward amount  
     * @param market Market address
     * @param newIncentiveReward Refresh reward amount
     * 
     */
    function setMarketIncentiveReward(address market, uint256 newIncentiveReward) external onlyOwner {
        marketIncentiveReward[market] = newIncentiveReward;
        emit MarketIncentiveRewardUpdate(market, newIncentiveReward);
    }

    /**
     * @notice Get current week
     * @return uint256 week number
     */
    function getWeek() public view returns (uint256) {
        if (startTime >= block.timestamp) return 0;
        return (block.timestamp - startTime) / WEEK;
    }

    /**
     * @notice Set lending market fee distribution rate
     * @param newFeeRate New fee distribution rate
     */
    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        emit FeeRateUpdate(feeRate, newFeeRate);
        feeRate = newFeeRate;
    }

    /**
     * @notice Set market address corresponding to the asset
     * @param newAsset Asset address
     * @param newMarket market address
     */
    function setMarket(address newAsset, address newMarket) external onlyOwner {
        getMarket[newAsset] = newMarket;
        emit SetMarket(newAsset, newMarket);
    }

    /**
     * @notice Initialize lending market info
     * @param market lending market
     */
    function initialMarket(address market) public {
        require(msg.sender == incentiveVoting, "Sender not incentiveVoting");
        address pendingAdmin = ICToken(market).pendingAdmin();
        if(pendingAdmin == address(this)) {
            address asset = underlyingAsset(market);
            getMarket[asset] = market;
            ICToken(market)._acceptAdmin();
            uint256 totalReserves = ICToken(market).totalReserves();
            marketInfo[market] = MarketInfo({
                lastReserves: totalReserves,
                lastTime: startTime >= block.timestamp ? startTime : block.timestamp,
                claimed: 0
            });
        }
    }

    /**
     * @notice Withdraw fees allocated by the lending market based on market address
     * @param market market address
     */
    function withdrawFee(address market) public {
        _withdrawFee(market);
    }

    /**
     * @notice Withdraw fees allocated by the lending market based on market address
     * @param asset Asset address
     */
    function withdrawFeeByAsset(address asset) public {
        address market = getMarket[asset];
        _withdrawFee(market);
    }

    /**
     * @notice Withdraw fees allocated by the lending market based on market address
     * @param market market address
     */
    function _withdrawFee(address market) private {
        require(ICToken(market).accrueInterest() == 0, "accrue interest failed");
        uint256 totalReserves = ICToken(market).totalReserves();
        MarketInfo storage info = marketInfo[market];
        uint256 amount = totalReserves - info.lastReserves;

        uint256 nowTime = block.timestamp;
        
        if(amount > 0) {
            uint256 fee = amount * feeRate / DENOMINATOR;
            require(ICToken(market)._reduceReserves(fee) == 0, "reduce reserves failed");

            uint256 week = getWeek();
            address token = underlyingAsset(market);
            if(token == WETH) {
                IWETH(token).deposit{value: fee}();
            }

            _approveMax(token, feeDistributor, fee);
            
            info.claimed += fee;
            info.lastReserves = totalReserves - fee;

            uint256 newWeekStart = startTime + week * WEEK;
            if(newWeekStart > info.lastTime && week > 0) {
                uint256 rewardPerSecond = fee / (nowTime - info.lastTime);
                uint256 oldWeekFee = (newWeekStart - info.lastTime) * rewardPerSecond;
                fee -= oldWeekFee;
                IFeeDistributor(feeDistributor).depositFeeExtra(token, oldWeekFee, week - 1);
            }
            IFeeDistributor(feeDistributor).depositFee(token, fee);
        }
        info.lastTime = nowTime;
    }

    /**
     * @notice Max token approved amount
     * @param token token address
     * @param spender Approved user address
     * @param amount Approved amount
     */
    function _approveMax(address token, address spender, uint256 amount) private {
        uint256 allowance = ICToken(token).allowance(address(this), spender);
        if(allowance < amount) {
            IERC20Upgradeable(token).safeApprove(feeDistributor, 0);
            IERC20Upgradeable(token).safeApprove(feeDistributor, type(uint256).max);
        }
    }

    /**
     * @notice Get the last refresh time and refresh reward of the pool
     * @param markets market address array
     * @return lastFeeClaimInfo Last refresh time
     * @return rewardInfo refresh reward
     */
    function getLastFeeClaimInfo(address[] calldata markets) external view returns (uint256[] memory lastFeeClaimInfo, uint256[] memory rewardInfo) {
        uint length = markets.length;
        lastFeeClaimInfo = new uint256[](length);
        rewardInfo = new uint256[](length);
        for(uint i = 0; i < length; i++) {
            lastFeeClaimInfo[i] = marketInfo[markets[i]].lastTime;
            rewardInfo[i] = marketIncentiveReward[markets[i]];
        }
    }


    /**
     * @notice Claim refresh reward
     * @param markets market address array
     */
    function claimRefreshReward(address[] calldata markets) external {
        uint256 reward;
        for(uint i = 0; i < markets.length; i++) {
            uint lastTime = marketInfo[markets[i]].lastTime;

            if(block.timestamp - rewardInterval >= lastTime) {
                reward += marketIncentiveReward[markets[i]];
                _withdrawFee(markets[i]);
            }
        }
        if(reward > 0) {
            IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, reward);
        }
        
    }

    /**
     * @notice Underlying asset of lending market
     * @param market cToken address
     */
    function underlyingAsset(address market) public view returns (address) {
        if(compareStrings(ICToken(market).symbol(), "iETH")) {
            return WETH;
        } else {
            return ICToken(market).underlying();
        }
    }

    /**
     * @notice Compare strings
     * @param a String a
     * @param b String b
     */
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    }

    /**
     * @notice Call the contract
     * @param target Contract address
     * @param data Encoding of method and parameters
     */
    function execute(address[] calldata target, bytes[] calldata data) external onlyOwner {
        for(uint256 i = 0; i < data.length; i++) {
            AddressUpgradeable.functionCall(target[i], data[i]);
        }
    }

    /*** Admin Functions */

    /**
     * @notice Set corresponding Ctoken's PendingAdmin
     * @param cToken cToken contract address
     * @param newPendingAdmin newPendingAdmin address
     * @return uint 0=success, otherwise a failure
     */
    function _setPendingAdmin(address cToken, address payable newPendingAdmin) external onlyOwner returns (uint) {
        return ICToken(cToken)._setPendingAdmin(newPendingAdmin);
    }

    /**
     * @notice Set Ctoken's Comptroller
     * @param cToken cToken contract address
     * @param newComptroller newComptroller address
     * @return uint 0=success, otherwise a failure
     */
    function _setComptroller(address cToken, address newComptroller) external onlyOwner returns (uint) {
        return ICToken(cToken)._setComptroller(newComptroller);
    }

    /**
     * @notice Set Ctoken's ReserveFactor
     * @param cToken cToken contract address
     * @param newReserveFactorMantissa Reserve factor
     * @return uint 0=success, otherwise a failure
     */
    function _setReserveFactor(address cToken, uint newReserveFactorMantissa) external onlyOwner returns (uint) {
        return ICToken(cToken)._setReserveFactor(newReserveFactorMantissa);
    }

    /**
     * @notice Add market reserve
     * @param cToken cToken contract address
     * @return uint 0=success, otherwise a failure
     */
    function _addReserves(address cToken) external payable onlyOwner returns (uint) {
        _withdrawFee(cToken);
        uint code = ICEther(cToken)._addReserves{value: msg.value}();
        if(code == 0) {
            MarketInfo storage info = marketInfo[cToken];
            info.lastReserves += msg.value;
        }
        return code;
    }

    /**
     * @notice Add market reserve
     * @param cToken cToken contract address
     * @param addAmount Added amount
     * @return uint 0=success, otherwise a failure
     */
    function _addReserves(address cToken, uint addAmount) external onlyOwner returns (uint) {
        _withdrawFee(cToken);
        address asset = underlyingAsset(cToken);
        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, address(this), addAmount);
        _approveMax(asset, cToken, addAmount);
        uint code = ICToken(cToken)._addReserves(addAmount);
        if(code == 0) {
            MarketInfo storage info = marketInfo[cToken];
            info.lastReserves += addAmount;
        }
        return code;
    }

    /**
     * @notice Reduce market reserve
     * @param cToken cToken contract address
     * @param receiver receiver address
     * @param reduceAmount Reduced amount
     * @return uint 0=success, otherwise a failure
     */
    function _reduceReserves(address cToken, address receiver, uint256 reduceAmount) external onlyOwner returns (uint) {
        _withdrawFee(cToken);
        uint code = ICToken(cToken)._reduceReserves(reduceAmount);
        if(code == 0) {
            MarketInfo storage info = marketInfo[cToken];
            info.lastReserves -= reduceAmount;
            address asset = underlyingAsset(cToken);
            if(asset == WETH) {
                payable(receiver).transfer(reduceAmount);
            } else {
                IERC20Upgradeable(asset).safeTransfer(receiver, reduceAmount);
            }
        }
        return code;
    }

    /**
     * @notice Set interest rate model
     * @param cToken cToken contract address
     * @param newInterestRateModel New interest rate model contract address
     * @return uint 0=success, otherwise a failure
     */
    function _setInterestRateModel(address cToken, address newInterestRateModel) external onlyOwner returns (uint) {
        return ICToken(cToken)._setInterestRateModel(newInterestRateModel);
    }

    receive() external payable {}

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

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
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
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
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
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
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface ICToken {
    function name() external view returns(string memory);
    function symbol() external view returns(string memory);

    function transfer(address dst, uint amount) external returns (bool);
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function approve(address spender, uint amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address owner) external view returns (uint);

    function accrueInterest() external returns (uint);

    function admin() external view returns(address);
    function pendingAdmin() external view returns(address);

    function _setPendingAdmin(address payable newPendingAdmin) external returns (uint);
    function _acceptAdmin() external returns (uint);
    function _setComptroller(address newComptroller) external returns (uint);
    function _setReserveFactor(uint newReserveFactorMantissa) external returns (uint);
    function _addReserves(uint addAmount) external returns (uint);
    function _reduceReserves(uint reduceAmount) external returns (uint);
    function _setInterestRateModel(address newInterestRateModel) external returns (uint);

    function totalReserves() external view returns(uint);

    function underlying() external view returns(address);
}

interface ICEther {
    function _addReserves() external payable returns (uint);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface IFeeDistributor {
    function startTime() external view returns(uint256);
    function depositFee(address _token, uint256 _amount) external returns(bool);
    function depositFeeExtra(address _token, uint256 _amount, uint256 _week) external returns(bool);
    function weeklyFeeAmounts(address _token, uint256 _week) external view returns(uint256);
}

// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.0;

interface IWETH {
    function deposit() external payable;

    function withdraw(uint wad) external;
}