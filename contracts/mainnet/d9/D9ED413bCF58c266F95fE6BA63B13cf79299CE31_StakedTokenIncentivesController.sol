// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IAaveDistributionManager} from '../interfaces/IAaveDistributionManager.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';

/**
 * @title DistributionManager
 * @notice Accounting contract to manage multiple staking distributions
 * @author Aave
 **/
contract DistributionManager is IAaveDistributionManager {
  using SafeMath for uint256;

  struct AssetData {
    uint104 emissionPerSecond;
    uint104 index;
    uint40 lastUpdateTimestamp;
    mapping(address => uint256) users;
  }

  address public immutable EMISSION_MANAGER;

  uint8 public constant PRECISION = 18;

  mapping(address => AssetData) public assets;

  uint256 internal _distributionEnd;

  modifier onlyEmissionManager() {
    require(msg.sender == EMISSION_MANAGER, 'ONLY_EMISSION_MANAGER');
    _;
  }

  constructor(address emissionManager) {
    EMISSION_MANAGER = emissionManager;
  }

  /// @inheritdoc IAaveDistributionManager
  function setDistributionEnd(uint256 distributionEnd) external override onlyEmissionManager {
    _distributionEnd = distributionEnd;
    emit DistributionEndUpdated(distributionEnd);
  }

  /// @inheritdoc IAaveDistributionManager
  function getDistributionEnd() external view override returns (uint256) {
    return _distributionEnd;
  }

  /// @inheritdoc IAaveDistributionManager
  function DISTRIBUTION_END() external view override returns (uint256) {
    return _distributionEnd;
  }

  /// @inheritdoc IAaveDistributionManager
  function getUserAssetData(address user, address asset) public view override returns (uint256) {
    return assets[asset].users[user];
  }

  /// @inheritdoc IAaveDistributionManager
  function getAssetData(address asset) public view override returns (uint256, uint256, uint256) {
    return (assets[asset].index, assets[asset].emissionPerSecond, assets[asset].lastUpdateTimestamp);
  }

  /**
   * @dev Configure the assets for a specific emission
   * @param assetsConfigInput The array of each asset configuration
   **/
  function _configureAssets(DistributionTypes.AssetConfigInput[] memory assetsConfigInput)
    internal
  {
    for (uint256 i = 0; i < assetsConfigInput.length; i++) {
      AssetData storage assetConfig = assets[assetsConfigInput[i].underlyingAsset];

      _updateAssetStateInternal(
        assetsConfigInput[i].underlyingAsset,
        assetConfig,
        assetsConfigInput[i].totalStaked
      );

      assetConfig.emissionPerSecond = assetsConfigInput[i].emissionPerSecond;

      emit AssetConfigUpdated(
        assetsConfigInput[i].underlyingAsset,
        assetsConfigInput[i].emissionPerSecond
      );
    }
  }

  /**
   * @dev Updates the state of one distribution, mainly rewards index and timestamp
   * @param asset The address of the asset being updated
   * @param assetConfig Storage pointer to the distribution's config
   * @param totalStaked Current total of staked assets for this distribution
   * @return The new distribution index
   **/
  function _updateAssetStateInternal(
    address asset,
    AssetData storage assetConfig,
    uint256 totalStaked
  ) internal returns (uint256) {
    uint256 oldIndex = assetConfig.index;
    uint256 emissionPerSecond = assetConfig.emissionPerSecond;
    uint128 lastUpdateTimestamp = assetConfig.lastUpdateTimestamp;

    if (block.timestamp == lastUpdateTimestamp) {
      return oldIndex;
    }

    uint256 newIndex =
      _getAssetIndex(oldIndex, emissionPerSecond, lastUpdateTimestamp, totalStaked);

    if (newIndex != oldIndex) {
      require(uint104(newIndex) == newIndex, 'Index overflow');
      //optimization: storing one after another saves one SSTORE
      assetConfig.index = uint104(newIndex);
      assetConfig.lastUpdateTimestamp = uint40(block.timestamp);
      emit AssetIndexUpdated(asset, newIndex);
    } else {
      assetConfig.lastUpdateTimestamp = uint40(block.timestamp);
    }

    return newIndex;
  }

  /**
   * @dev Updates the state of an user in a distribution
   * @param user The user's address
   * @param asset The address of the reference asset of the distribution
   * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
   * @param totalStaked Total tokens staked in the distribution
   * @return The accrued rewards for the user until the moment
   **/
  function _updateUserAssetInternal(
    address user,
    address asset,
    uint256 stakedByUser,
    uint256 totalStaked
  ) internal returns (uint256) {
    AssetData storage assetData = assets[asset];
    uint256 userIndex = assetData.users[user];
    uint256 accruedRewards = 0;

    uint256 newIndex = _updateAssetStateInternal(asset, assetData, totalStaked);

    if (userIndex != newIndex) {
      if (stakedByUser != 0) {
        accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
      }

      assetData.users[user] = newIndex;
      emit UserIndexUpdated(user, asset, newIndex);
    }

    return accruedRewards;
  }

  /**
   * @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _claimRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      accruedRewards = accruedRewards.add(
        _updateUserAssetInternal(
          user,
          stakes[i].underlyingAsset,
          stakes[i].stakedByUser,
          stakes[i].totalStaked
        )
      );
    }

    return accruedRewards;
  }

  /**
   * @dev Return the accrued rewards for an user over a list of distribution
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _getUnclaimedRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    view
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      AssetData storage assetConfig = assets[stakes[i].underlyingAsset];
      uint256 assetIndex =
        _getAssetIndex(
          assetConfig.index,
          assetConfig.emissionPerSecond,
          assetConfig.lastUpdateTimestamp,
          stakes[i].totalStaked
        );

      accruedRewards = accruedRewards.add(
        _getRewards(stakes[i].stakedByUser, assetIndex, assetConfig.users[user])
      );
    }
    return accruedRewards;
  }

  /**
   * @dev Internal function for the calculation of user's rewards on a distribution
   * @param principalUserBalance Amount staked by the user on a distribution
   * @param reserveIndex Current index of the distribution
   * @param userIndex Index stored for the user, representation his staking moment
   * @return The rewards
   **/
  function _getRewards(
    uint256 principalUserBalance,
    uint256 reserveIndex,
    uint256 userIndex
  ) internal pure returns (uint256) {
    return principalUserBalance.mul(reserveIndex.sub(userIndex)) / 10**uint256(PRECISION);
  }

  /**
   * @dev Calculates the next value of an specific distribution index, with validations
   * @param currentIndex Current index of the distribution
   * @param emissionPerSecond Representing the total rewards distributed per second per asset unit, on the distribution
   * @param lastUpdateTimestamp Last moment this distribution was updated
   * @param totalBalance of tokens considered for the distribution
   * @return The new index.
   **/
  function _getAssetIndex(
    uint256 currentIndex,
    uint256 emissionPerSecond,
    uint128 lastUpdateTimestamp,
    uint256 totalBalance
  ) internal view returns (uint256) {
    uint256 distributionEnd = _distributionEnd;
    if (
      emissionPerSecond == 0 ||
      totalBalance == 0 ||
      lastUpdateTimestamp == block.timestamp ||
      lastUpdateTimestamp >= distributionEnd
    ) {
      return currentIndex;
    }

    uint256 currentTimestamp =
      block.timestamp > distributionEnd ? distributionEnd : block.timestamp;
    uint256 timeDelta = currentTimestamp.sub(lastUpdateTimestamp);
    return
      emissionPerSecond.mul(timeDelta).mul(10**uint256(PRECISION)).div(totalBalance).add(
        currentIndex
      );
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {DistributionTypes} from '../lib/DistributionTypes.sol';

interface IAaveDistributionManager {
  
  event AssetConfigUpdated(address indexed asset, uint256 emission);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);
  event DistributionEndUpdated(uint256 newDistributionEnd);

  /**
  * @dev Sets the end date for the distribution
  * @param distributionEnd The end date timestamp
  **/
  function setDistributionEnd(uint256 distributionEnd) external;

  /**
  * @dev Gets the end date for the distribution
  * @return The end of the distribution
  **/
  function getDistributionEnd() external view returns (uint256);

  /**
  * @dev for backwards compatibility with the previous DistributionManager used
  * @return The end of the distribution
  **/
  function DISTRIBUTION_END() external view returns(uint256);

   /**
   * @dev Returns the data of an user on a distribution
   * @param user Address of the user
   * @param asset The address of the reference asset of the distribution
   * @return The new index
   **/
   function getUserAssetData(address user, address asset) external view returns (uint256);

   /**
   * @dev Returns the configuration of the distribution for a certain asset
   * @param asset The address of the reference asset of the distribution
   * @return The asset index, the emission per second and the last updated timestamp
   **/
   function getAssetData(address asset) external view returns (uint256, uint256, uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.7.5;

/// @title Optimized overflow and underflow safe math operations
/// @notice Contains methods for doing math operations that revert on overflow or underflow for minimal gas cost
/// inspired by uniswap V3
library SafeMath {
    /// @notice Returns x + y, reverts if sum overflows uint256
    /// @param x The augend
    /// @param y The addend
    /// @return z The sum of x and y
    function add(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x + y) >= x);
    }

    /// @notice Returns x - y, reverts if underflows
    /// @param x The minuend
    /// @param y The subtrahend
    /// @return z The difference of x and y
    function sub(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require((z = x - y) <= x);
    }

    /// @notice Returns x * y, reverts if overflows
    /// @param x The multiplicand
    /// @param y The multiplier
    /// @return z The product of x and y
    function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
        require(x == 0 || (z = x * y) / x == y);
    }

    function div(uint256 x, uint256 y) internal pure returns(uint256) {
        // no need to check for division by zero - solidity already reverts
        return x / y;
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

library DistributionTypes {
  struct AssetConfigInput {
    uint104 emissionPerSecond;
    uint256 totalStaked;
    address underlyingAsset;
  }

  struct UserStakeInput {
    address underlyingAsset;
    uint256 stakedByUser;
    uint256 totalStaked;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {SafeERC20} from '@aave/aave-stake/contracts/lib/SafeERC20.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {VersionedInitializable} from '@aave/aave-stake/contracts/utils/VersionedInitializable.sol';
import {DistributionManager} from './DistributionManager.sol';
import {IStakedTokenWithConfig} from '../interfaces/IStakedTokenWithConfig.sol';
import {IERC20} from '@aave/aave-stake/contracts/interfaces/IERC20.sol';
import {IScaledBalanceToken} from '../interfaces/IScaledBalanceToken.sol';
import {IAaveIncentivesController} from '../interfaces/IAaveIncentivesController.sol';

/**
 * @title StakedTokenIncentivesController
 * @notice Distributor contract for rewards to the Aave protocol, using a staked token as rewards asset.
 * The contract stakes the rewards before redistributing them to the Aave protocol participants.
 * The reference staked token implementation is at https://github.com/aave/aave-stake-v2
 * @author Aave
 **/
contract StakedTokenIncentivesController is
  IAaveIncentivesController,
  VersionedInitializable,
  DistributionManager
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  uint256 public constant REVISION = 2;

  IStakedTokenWithConfig public immutable STAKE_TOKEN;

  mapping(address => uint256) internal _usersUnclaimedRewards;

  // this mapping allows whitelisted addresses to claim on behalf of others
  // useful for contracts that hold tokens to be rewarded but don't have any native logic to claim Liquidity Mining rewards
  mapping(address => address) internal _authorizedClaimers;

  modifier onlyAuthorizedClaimers(address claimer, address user) {
    require(_authorizedClaimers[user] == claimer, 'CLAIMER_UNAUTHORIZED');
    _;
  }

  constructor(IStakedTokenWithConfig stakeToken, address emissionManager)
    DistributionManager(emissionManager)
  {
    STAKE_TOKEN = stakeToken;
  }

  /**
   * @dev Initialize IStakedTokenIncentivesController. Empty after REVISION 1, but maintains the expected interface.
   **/
  function initialize(address) external initializer {}

  /// @inheritdoc IAaveIncentivesController
  function configureAssets(address[] calldata assets, uint256[] calldata emissionsPerSecond)
    external
    override
    onlyEmissionManager
  {
    require(assets.length == emissionsPerSecond.length, 'INVALID_CONFIGURATION');

    DistributionTypes.AssetConfigInput[] memory assetsConfig =
      new DistributionTypes.AssetConfigInput[](assets.length);

    for (uint256 i = 0; i < assets.length; i++) {
      assetsConfig[i].underlyingAsset = assets[i];
      assetsConfig[i].emissionPerSecond = uint104(emissionsPerSecond[i]);

      require(assetsConfig[i].emissionPerSecond == emissionsPerSecond[i], 'INVALID_CONFIGURATION');

      assetsConfig[i].totalStaked = IScaledBalanceToken(assets[i]).scaledTotalSupply();
    }
    _configureAssets(assetsConfig);
  }

  /// @inheritdoc IAaveIncentivesController
  function handleAction(
    address user,
    uint256 totalSupply,
    uint256 userBalance
  ) external override {
    uint256 accruedRewards = _updateUserAssetInternal(user, msg.sender, userBalance, totalSupply);
    if (accruedRewards != 0) {
      _usersUnclaimedRewards[user] = _usersUnclaimedRewards[user].add(accruedRewards);
      emit RewardsAccrued(user, accruedRewards);
    }
  }

  /// @inheritdoc IAaveIncentivesController
  function getRewardsBalance(address[] calldata assets, address user)
    external
    view
    override
    returns (uint256)
  {
    uint256 unclaimedRewards = _usersUnclaimedRewards[user];

    DistributionTypes.UserStakeInput[] memory userState =
      new DistributionTypes.UserStakeInput[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      userState[i].underlyingAsset = assets[i];
      (userState[i].stakedByUser, userState[i].totalStaked) = IScaledBalanceToken(assets[i])
        .getScaledUserBalanceAndSupply(user);
    }
    unclaimedRewards = unclaimedRewards.add(_getUnclaimedRewards(user, userState));
    return unclaimedRewards;
  }

  /// @inheritdoc IAaveIncentivesController
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to
  ) external override returns (uint256) {
    require(to != address(0), 'INVALID_TO_ADDRESS');
    return _claimRewards(assets, amount, msg.sender, msg.sender, to);
  }

  /// @inheritdoc IAaveIncentivesController
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to
  ) external override onlyAuthorizedClaimers(msg.sender, user) returns (uint256) {
    require(user != address(0), 'INVALID_USER_ADDRESS');
    require(to != address(0), 'INVALID_TO_ADDRESS');
    return _claimRewards(assets, amount, msg.sender, user, to);
  }

  /// @inheritdoc IAaveIncentivesController
  function claimRewardsToSelf(address[] calldata assets, uint256 amount)
    external
    override
    returns (uint256)
  {
    return _claimRewards(assets, amount, msg.sender, msg.sender, msg.sender);
  }

  /**
   * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards.
   * @param amount Amount of rewards to claim
   * @param user Address to check and claim rewards
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/

  /// @inheritdoc IAaveIncentivesController
  function setClaimer(address user, address caller) external override onlyEmissionManager {
    _authorizedClaimers[user] = caller;
    emit ClaimerSet(user, caller);
  }

  /// @inheritdoc IAaveIncentivesController
  function getClaimer(address user) external view override returns (address) {
    return _authorizedClaimers[user];
  }

  /// @inheritdoc IAaveIncentivesController
  function getUserUnclaimedRewards(address _user) external view override returns (uint256) {
    return _usersUnclaimedRewards[_user];
  }

  /// @inheritdoc IAaveIncentivesController
  function REWARD_TOKEN() external view override returns (address) {
    return address(STAKE_TOKEN);
  }

  /**
   * @dev returns the revision of the implementation contract
   */
  function getRevision() internal pure override returns (uint256) {
    return REVISION;
  }

  /**
   * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards.
   * @param amount Amount of rewards to claim
   * @param user Address to check and claim rewards
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function _claimRewards(
    address[] calldata assets,
    uint256 amount,
    address claimer,
    address user,
    address to
  ) internal returns (uint256) {
    if (amount == 0) {
      return 0;
    }
    uint256 unclaimedRewards = _usersUnclaimedRewards[user];

    DistributionTypes.UserStakeInput[] memory userState =
      new DistributionTypes.UserStakeInput[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      userState[i].underlyingAsset = assets[i];
      (userState[i].stakedByUser, userState[i].totalStaked) = IScaledBalanceToken(assets[i])
        .getScaledUserBalanceAndSupply(user);
    }

    uint256 accruedRewards = _claimRewards(user, userState);
    if (accruedRewards != 0) {
      unclaimedRewards = unclaimedRewards.add(accruedRewards);
      emit RewardsAccrued(user, accruedRewards);
    }

    if (unclaimedRewards == 0) {
      return 0;
    }

    uint256 amountToClaim = amount > unclaimedRewards ? unclaimedRewards : amount;
    _usersUnclaimedRewards[user] = unclaimedRewards - amountToClaim; // Safe due to the previous line

    STAKE_TOKEN.stake(to, amountToClaim);
    emit RewardsClaimed(user, to, claimer, amountToClaim);

    return amountToClaim;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.7.5;

import {IERC20} from '../interfaces/IERC20.sol';
import {SafeMath} from './SafeMath.sol';
import {Address} from './Address.sol';

/**
 * @title SafeERC20
 * @dev From https://github.com/OpenZeppelin/openzeppelin-contracts
 * Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  using SafeMath for uint256;
  using Address for address;

  function safeTransfer(
    IERC20 token,
    address to,
    uint256 value
  ) internal {
    callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
  }

  function safeTransferFrom(
    IERC20 token,
    address from,
    address to,
    uint256 value
  ) internal {
    callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
  }

  function safeApprove(
    IERC20 token,
    address spender,
    uint256 value
  ) internal {
    require(
      (value == 0) || (token.allowance(address(this), spender) == 0),
      'SafeERC20: approve from non-zero to non-zero allowance'
    );
    callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
  }

  function callOptionalReturn(IERC20 token, bytes memory data) private {
    require(address(token).isContract(), 'SafeERC20: call to non-contract');

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = address(token).call(data);
    require(success, 'SafeERC20: low-level call failed');

    if (returndata.length > 0) {
      // Return data is optional
      // solhint-disable-next-line max-line-length
      require(abi.decode(returndata, (bool)), 'SafeERC20: ERC20 operation did not succeed');
    }
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

/**
 * @title VersionedInitializable
 *
 * @dev Helper contract to support initializer functions. To use it, replace
 * the constructor with a function that has the `initializer` modifier.
 * WARNING: Unlike constructors, initializer functions must be manually
 * invoked. This applies both to deploying an Initializable contract, as well
 * as extending an Initializable contract via inheritance.
 * WARNING: When used with inheritance, manual care must be taken to not invoke
 * a parent initializer twice, or ensure that all initializers are idempotent,
 * because this is not dealt with automatically as with constructors.
 *
 * @author Aave, inspired by the OpenZeppelin Initializable contract
 */
abstract contract VersionedInitializable {
  /**
   * @dev Indicates that the contract has been initialized.
   */
  uint256 internal lastInitializedRevision = 0;

  /**
   * @dev Modifier to use in the initializer function of a contract.
   */
  modifier initializer() {
    uint256 revision = getRevision();
    require(revision > lastInitializedRevision, 'Contract instance has already been initialized');

    lastInitializedRevision = revision;

    _;
  }

  /// @dev returns the revision number of the contract.
  /// Needs to be defined in the inherited class as a constant.
  function getRevision() internal pure virtual returns (uint256);

  // Reserved storage space to allow for layout changes in the future.
  uint256[50] private ______gap;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import {IStakedToken} from '@aave/aave-stake/contracts/interfaces/IStakedToken.sol';

interface IStakedTokenWithConfig is IStakedToken {
  function STAKED_TOKEN() external view returns(address);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 * From https://github.com/OpenZeppelin/openzeppelin-contracts
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

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IScaledBalanceToken {
  /**
   * @dev Returns the scaled balance of the user. The scaled balance is the sum of all the
   * updated stored balance divided by the reserve's liquidity index at the moment of the update
   * @param user The user whose balance is calculated
   * @return The scaled balance of the user
   **/
  function scaledBalanceOf(address user) external view returns (uint256);

  /**
   * @dev Returns the scaled balance of the user and the scaled total supply.
   * @param user The address of the user
   * @return The scaled balance of the user
   * @return The scaled balance and the scaled total supply
   **/
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);

  /**
   * @dev Returns the scaled total supply of the token. Represents sum(debt/index)
   * @return The scaled total supply
   **/
  function scaledTotalSupply() external view returns (uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

pragma experimental ABIEncoderV2;

import {IAaveDistributionManager} from '../interfaces/IAaveDistributionManager.sol';

interface IAaveIncentivesController is IAaveDistributionManager {
  
  event RewardsAccrued(address indexed user, uint256 amount);
  
  event RewardsClaimed(
    address indexed user,
    address indexed to,
    address indexed claimer,
    uint256 amount
  );

  event ClaimerSet(address indexed user, address indexed claimer);

  /**
   * @dev Whitelists an address to claim the rewards on behalf of another address
   * @param user The address of the user
   * @param claimer The address of the claimer
   */
  function setClaimer(address user, address claimer) external;

  /**
   * @dev Returns the whitelisted claimer for a certain address (0x0 if not set)
   * @param user The address of the user
   * @return The claimer address
   */
  function getClaimer(address user) external view returns (address);

  /**
   * @dev Configure assets for a certain rewards emission
   * @param assets The assets to incentivize
   * @param emissionsPerSecond The emission for each asset
   */
  function configureAssets(address[] calldata assets, uint256[] calldata emissionsPerSecond)
    external;


  /**
   * @dev Called by the corresponding asset on any update that affects the rewards distribution
   * @param asset The address of the user
   * @param userBalance The balance of the user of the asset in the lending pool
   * @param totalSupply The total supply of the asset in the lending pool
   **/
  function handleAction(
    address asset,
    uint256 userBalance,
    uint256 totalSupply
  ) external;

  /**
   * @dev Returns the total of rewards of an user, already accrued + not yet accrued
   * @param user The address of the user
   * @return The rewards
   **/
  function getRewardsBalance(address[] calldata assets, address user)
    external
    view
    returns (uint256);

  /**
   * @dev Claims reward for an user, on all the assets of the lending pool, accumulating the pending rewards
   * @param amount Amount of rewards to claim
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to
  ) external returns (uint256);

  /**
   * @dev Claims reward for an user on behalf, on all the assets of the lending pool, accumulating the pending rewards. The caller must
   * be whitelisted via "allowClaimOnBehalf" function by the RewardsAdmin role manager
   * @param amount Amount of rewards to claim
   * @param user Address to check and claim rewards
   * @param to Address that will be receiving the rewards
   * @return Rewards claimed
   **/
  function claimRewardsOnBehalf(
    address[] calldata assets,
    uint256 amount,
    address user,
    address to
  ) external returns (uint256);

  /**
   * @dev Claims rewards for a user, on the specified assets of the lending pool, distributing the pending rewards to self
   * @param assets Incentivized assets on which to claim rewards
   * @param amount Amount of rewards to claim
   * @return Rewards claimed
   **/
  function claimRewardsToSelf(address[] calldata assets, uint256 amount) external returns (uint256);

  /**
   * @dev returns the unclaimed rewards of the user
   * @param user the address of the user
   * @return the unclaimed user rewards
   */
  function getUserUnclaimedRewards(address user) external view returns (uint256);

  /**
  * @dev for backward compatibility with previous implementation of the Incentives controller
  */
  function REWARD_TOKEN() external view returns (address);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

/**
 * @dev From https://github.com/OpenZeppelin/openzeppelin-contracts
 * Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
  /**
   * @dev Returns the addition of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `+` operator.
   *
   * Requirements:
   * - Addition cannot overflow.
   */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, 'SafeMath: addition overflow');

    return c;
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity's `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, 'SafeMath: subtraction overflow');
  }

  /**
   * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
   * overflow (when the result is negative).
   *
   * Counterpart to Solidity's `-` operator.
   *
   * Requirements:
   * - Subtraction cannot overflow.
   */
  function sub(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  /**
   * @dev Returns the multiplication of two unsigned integers, reverting on
   * overflow.
   *
   * Counterpart to Solidity's `*` operator.
   *
   * Requirements:
   * - Multiplication cannot overflow.
   */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, 'SafeMath: multiplication overflow');

    return c;
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, 'SafeMath: division by zero');
  }

  /**
   * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
   * division by zero. The result is rounded towards zero.
   *
   * Counterpart to Solidity's `/` operator. Note: this function uses a
   * `revert` opcode (which leaves remaining gas untouched) while Solidity
   * uses an invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function div(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    // Solidity only automatically asserts when dividing by 0
    require(b > 0, errorMessage);
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold

    return c;
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, 'SafeMath: modulo by zero');
  }

  /**
   * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
   * Reverts with custom message when dividing by zero.
   *
   * Counterpart to Solidity's `%` operator. This function uses a `revert`
   * opcode (which leaves remaining gas untouched) while Solidity uses an
   * invalid opcode to revert (consuming all remaining gas).
   *
   * Requirements:
   * - The divisor cannot be zero.
   */
  function mod(
    uint256 a,
    uint256 b,
    string memory errorMessage
  ) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

/**
 * @dev Collection of functions related to the address type
 * From https://github.com/OpenZeppelin/openzeppelin-contracts
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
    // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
    // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
    // for accounts without code, i.e. `keccak256('')`
    bytes32 codehash;
    bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      codehash := extcodehash(account)
    }
    return (codehash != accountHash && codehash != 0x0);
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
    require(address(this).balance >= amount, 'Address: insufficient balance');

    // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
    (bool success, ) = recipient.call{value: amount}('');
    require(success, 'Address: unable to send value, recipient may have reverted');
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IStakedToken {
  
  function stake(address to, uint256 amount) external;

  function redeem(address to, uint256 amount) external;

  function cooldown() external;

  function claimRewards(address to, uint256 amount) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import {IERC20} from '@aave/aave-stake/contracts/interfaces/IERC20.sol';
import {ILendingPoolAddressesProvider} from '../interfaces/ILendingPoolAddressesProvider.sol';
import {ILendingPoolConfigurator} from '../interfaces/ILendingPoolConfigurator.sol';
import {IAaveIncentivesController} from '../interfaces/IAaveIncentivesController.sol';
import {IAaveEcosystemReserveController} from '../interfaces/IAaveEcosystemReserveController.sol';
import {IProposalIncentivesExecutor} from '../interfaces/IProposalIncentivesExecutor.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {DataTypes} from '../utils/DataTypes.sol';
import {ILendingPoolData} from '../interfaces/ILendingPoolData.sol';
import {IATokenDetailed} from '../interfaces/IATokenDetailed.sol';
import {PercentageMath} from '../utils/PercentageMath.sol';
import {SafeMath} from '../lib/SafeMath.sol';

contract ProposalIncentivesExecutor is IProposalIncentivesExecutor {
  using SafeMath for uint256;
  using PercentageMath for uint256;

  address constant AAVE_TOKEN = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
  address constant POOL_CONFIGURATOR = 0x311Bb771e4F8952E6Da169b425E7e92d6Ac45756;
  address constant ADDRESSES_PROVIDER = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;
  address constant LENDING_POOL = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
  address constant ECO_RESERVE_ADDRESS = 0x1E506cbb6721B83B1549fa1558332381Ffa61A93;
  address constant INCENTIVES_CONTROLLER_PROXY_ADDRESS = 0xd784927Ff2f95ba542BfC824c8a8a98F3495f6b5;
  address constant INCENTIVES_CONTROLLER_IMPL_ADDRESS = 0x83D055D382f25e6793099713505c68a5C7535a35;

  uint256 constant DISTRIBUTION_DURATION = 7776000; // 90 days
  uint256 constant DISTRIBUTION_AMOUNT = 198000000000000000000000; // 198000 AAVE during 90 days

  function execute(
    address[6] memory aTokenImplementations,
    address[6] memory variableDebtImplementations
  ) external override {
    uint256 tokensCounter;

    address[] memory assets = new address[](12);

    // Reserves Order: DAI/GUSD/USDC/USDT/WBTC/WETH
    address payable[6] memory reserves =
      [
        0x6B175474E89094C44Da98b954EedeAC495271d0F,
        0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd,
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
        0xdAC17F958D2ee523a2206206994597C13D831ec7,
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
      ];

    uint256[] memory emissions = new uint256[](12);

    emissions[0] = 1706018518518520; //aDAI
    emissions[1] = 1706018518518520; //vDebtDAI
    emissions[2] = 92939814814815; //aGUSD
    emissions[3] = 92939814814815; //vDebtGUSD
    emissions[4] = 5291203703703700; //aUSDC
    emissions[5] = 5291203703703700; //vDebtUSDC
    emissions[6] = 3293634259259260; //aUSDT
    emissions[7] = 3293634259259260; //vDebtUSDT
    emissions[8] = 1995659722222220; //aWBTC
    emissions[9] = 105034722222222; //vDebtWBTC
    emissions[10] = 2464942129629630; //aETH
    emissions[11] = 129733796296296; //vDebtWETH

    ILendingPoolConfigurator poolConfigurator = ILendingPoolConfigurator(POOL_CONFIGURATOR);
    IAaveIncentivesController incentivesController =
      IAaveIncentivesController(INCENTIVES_CONTROLLER_PROXY_ADDRESS);
    IAaveEcosystemReserveController ecosystemReserveController =
      IAaveEcosystemReserveController(ECO_RESERVE_ADDRESS);

    ILendingPoolAddressesProvider provider = ILendingPoolAddressesProvider(ADDRESSES_PROVIDER);

    //adding the incentives controller proxy to the addresses provider
    provider.setAddress(keccak256('INCENTIVES_CONTROLLER'), INCENTIVES_CONTROLLER_PROXY_ADDRESS);

    //updating the implementation of the incentives controller proxy
    provider.setAddressAsProxy(keccak256('INCENTIVES_CONTROLLER'), INCENTIVES_CONTROLLER_IMPL_ADDRESS);

    require(
      aTokenImplementations.length == variableDebtImplementations.length &&
        aTokenImplementations.length == reserves.length,
      'ARRAY_LENGTH_MISMATCH'
    );

    // Update each reserve AToken implementation, Debt implementation, and prepare incentives configuration input
    for (uint256 x = 0; x < reserves.length; x++) {
      require(
        IATokenDetailed(aTokenImplementations[x]).UNDERLYING_ASSET_ADDRESS() == reserves[x],
        'AToken underlying does not match'
      );
      require(
        IATokenDetailed(variableDebtImplementations[x]).UNDERLYING_ASSET_ADDRESS() == reserves[x],
        'Debt Token underlying does not match'
      );
      DataTypes.ReserveData memory reserveData =
        ILendingPoolData(LENDING_POOL).getReserveData(reserves[x]);

      // Update aToken impl
      poolConfigurator.updateAToken(reserves[x], aTokenImplementations[x]);

      // Update variable debt impl
      poolConfigurator.updateVariableDebtToken(reserves[x], variableDebtImplementations[x]);

      assets[tokensCounter++] = reserveData.aTokenAddress;

      // Configure variable debt token at incentives controller
      assets[tokensCounter++] = reserveData.variableDebtTokenAddress;

    }
    // Transfer AAVE funds to the Incentives Controller
    ecosystemReserveController.transfer(
      AAVE_TOKEN,
      INCENTIVES_CONTROLLER_PROXY_ADDRESS,
      DISTRIBUTION_AMOUNT
    );

    // Enable incentives in aTokens and Variable Debt tokens
    incentivesController.configureAssets(assets, emissions);

    // Sets the end date for the distribution
    incentivesController.setDistributionEnd(block.timestamp + DISTRIBUTION_DURATION);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

/**
 * @title LendingPoolAddressesProvider contract
 * @dev Main registry of addresses part of or connected to the protocol, including permissioned roles
 * - Acting also as factory of proxies and admin of those, so with right to change its implementations
 * - Owned by the Aave Governance
 * @author Aave
 **/
interface ILendingPoolAddressesProvider {
  event MarketIdSet(string newMarketId);
  event LendingPoolUpdated(address indexed newAddress);
  event ConfigurationAdminUpdated(address indexed newAddress);
  event EmergencyAdminUpdated(address indexed newAddress);
  event LendingPoolConfiguratorUpdated(address indexed newAddress);
  event LendingPoolCollateralManagerUpdated(address indexed newAddress);
  event PriceOracleUpdated(address indexed newAddress);
  event LendingRateOracleUpdated(address indexed newAddress);
  event ProxyCreated(bytes32 id, address indexed newAddress);
  event AddressSet(bytes32 id, address indexed newAddress, bool hasProxy);

  function getMarketId() external view returns (string memory);

  function setMarketId(string calldata marketId) external;

  function setAddress(bytes32 id, address newAddress) external;

  function setAddressAsProxy(bytes32 id, address impl) external;

  function getAddress(bytes32 id) external view returns (address);

  function getLendingPool() external view returns (address);

  function setLendingPoolImpl(address pool) external;

  function getLendingPoolConfigurator() external view returns (address);

  function setLendingPoolConfiguratorImpl(address configurator) external;

  function getLendingPoolCollateralManager() external view returns (address);

  function setLendingPoolCollateralManager(address manager) external;

  function getPoolAdmin() external view returns (address);

  function setPoolAdmin(address admin) external;

  function getEmergencyAdmin() external view returns (address);

  function setEmergencyAdmin(address admin) external;

  function getPriceOracle() external view returns (address);

  function setPriceOracle(address priceOracle) external;

  function getLendingRateOracle() external view returns (address);

  function setLendingRateOracle(address lendingRateOracle) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface ILendingPoolConfigurator {
  function updateAToken(address reserve, address implementation) external;

  function updateVariableDebtToken(address reserve, address implementation) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IAaveEcosystemReserveController {
  function AAVE_RESERVE_ECOSYSTEM() external view returns (address);

  function approve(
    address token,
    address recipient,
    uint256 amount
  ) external;

  function owner() external view returns (address);

  function renounceOwnership() external;

  function transfer(
    address token,
    address recipient,
    uint256 amount
  ) external;

  function transferOwnership(address newOwner) external;
}

// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

interface IProposalIncentivesExecutor {
  function execute(
    address[6] memory aTokenImplementations,
    address[6] memory variableDebtImplementation
  ) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

library DataTypes {
  // refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
  struct ReserveData {
    //stores the reserve configuration
    ReserveConfigurationMap configuration;
    //the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    //variable borrow index. Expressed in ray
    uint128 variableBorrowIndex;
    //the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    //the current variable borrow rate. Expressed in ray
    uint128 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint128 currentStableBorrowRate;
    uint40 lastUpdateTimestamp;
    //tokens addresses
    address aTokenAddress;
    address stableDebtTokenAddress;
    address variableDebtTokenAddress;
    //address of the interest rate strategy
    address interestRateStrategyAddress;
    //the id of the reserve. Represents the position in the list of the active reserves
    uint8 id;
  }

  struct ReserveConfigurationMap {
    //bit 0-15: LTV
    //bit 16-31: Liq. threshold
    //bit 32-47: Liq. bonus
    //bit 48-55: Decimals
    //bit 56: Reserve is active
    //bit 57: reserve is frozen
    //bit 58: borrowing is enabled
    //bit 59: stable rate borrowing enabled
    //bit 60-63: reserved
    //bit 64-79: reserve factor
    uint256 data;
  }

  struct UserConfigurationMap {
    uint256 data;
  }

  enum InterestRateMode {NONE, STABLE, VARIABLE}
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma abicoder v2;

import {DataTypes} from '../utils/DataTypes.sol';

interface ILendingPoolData {
  /**
   * @dev Returns the state and configuration of the reserve
   * @param asset The address of the underlying asset of the reserve
   * @return The state of the reserve
   **/
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IATokenDetailed {
  function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded half up
 **/

library PercentageMath {
  uint256 constant PERCENTAGE_FACTOR = 1e4; //percentage plus two decimals
  uint256 constant HALF_PERCENT = PERCENTAGE_FACTOR / 2;

  /**
   * @dev Executes a percentage multiplication
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The percentage of value
   **/
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256) {
    if (value == 0 || percentage == 0) {
      return 0;
    }

    require(
      value <= (type(uint256).max - HALF_PERCENT) / percentage,
      'MATH_MULTIPLICATION_OVERFLOW'
    );

    return (value * percentage + HALF_PERCENT) / PERCENTAGE_FACTOR;
  }

  /**
   * @dev Executes a percentage division
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The value divided the percentage
   **/
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256) {
    require(percentage != 0, 'MATH_DIVISION_BY_ZERO');
    uint256 halfPercentage = percentage / 2;

    require(
      value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR,
      'MATH_MULTIPLICATION_OVERFLOW'
    );

    return (value * PERCENTAGE_FACTOR + halfPercentage) / percentage;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IAaveIncentivesController} from '../interfaces/IAaveIncentivesController.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {IAToken} from '@aave/aave-stake/contracts/interfaces/IAToken.sol';

contract ATokenMock is IAToken {
  IAaveIncentivesController public _aic;
  uint256 internal _userBalance;
  uint256 internal _totalSupply;

  // hack to be able to test event from EI properly
  event RewardsAccrued(address indexed user, uint256 amount);

  // hack to be able to test event from Distribution manager properly
  event AssetConfigUpdated(address indexed asset, uint256 emission);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  constructor(IAaveIncentivesController aic) public {
    _aic = aic;
  }

  function handleActionOnAic(
    address user,
    uint256 totalSupply,
    uint256 userBalance
  ) external {
    _aic.handleAction(user, totalSupply, userBalance);
  }

  function doubleHandleActionOnAic(
    address user,
    uint256 totalSupply,
    uint256 userBalance
  ) external {
    _aic.handleAction(user, totalSupply, userBalance);
    _aic.handleAction(user, totalSupply, userBalance);
  }

  function setUserBalanceAndSupply(uint256 userBalance, uint256 totalSupply) public {
    _userBalance = userBalance;
    _totalSupply = totalSupply;
  }

  function getScaledUserBalanceAndSupply(address user)
    external
    view
    override
    returns (uint256, uint256)
  {
    return (_userBalance, _totalSupply);
  }

  function scaledTotalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function cleanUserState() external {
    _userBalance = 0;
    _totalSupply = 0;
  }
}

pragma solidity ^0.7.5;

interface IAToken {
  function getScaledUserBalanceAndSupply(address user) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {IERC20} from './IERC20.sol';

/**
 * @dev Interface for ERC20 including metadata
 **/
interface IERC20Detailed is IERC20 {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {Context} from './Context.sol';
import {IERC20} from '../interfaces/IERC20.sol';
import {IERC20Detailed} from '../interfaces/IERC20Detailed.sol';
import {SafeMath} from './SafeMath.sol';

/**
 * @title ERC20
 * @notice Basic ERC20 implementation
 * @author Aave
 **/
contract ERC20 is Context, IERC20, IERC20Detailed {
  using SafeMath for uint256;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;
  uint256 private _totalSupply;
  string private _name;
  string private _symbol;
  uint8 private _decimals;

  constructor(
    string memory name,
    string memory symbol,
    uint8 decimals
  ) public {
    _name = name;
    _symbol = symbol;
    _decimals = decimals;
  }

  /**
   * @return the name of the token
   **/
  function name() public view override returns (string memory) {
    return _name;
  }

  /**
   * @return the symbol of the token
   **/
  function symbol() public view override returns (string memory) {
    return _symbol;
  }

  /**
   * @return the decimals of the token
   **/
  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  /**
   * @return the total supply of the token
   **/
  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  /**
   * @return the balance of the token
   **/
  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev executes a transfer of tokens from msg.sender to recipient
   * @param recipient the recipient of the tokens
   * @param amount the amount of tokens being transferred
   * @return true if the transfer succeeds, false otherwise
   **/
  function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    _transfer(_msgSender(), recipient, amount);
    return true;
  }

  /**
   * @dev returns the allowance of spender on the tokens owned by owner
   * @param owner the owner of the tokens
   * @param spender the user allowed to spend the owner's tokens
   * @return the amount of owner's tokens spender is allowed to spend
   **/
  function allowance(address owner, address spender)
    public
    view
    virtual
    override
    returns (uint256)
  {
    return _allowances[owner][spender];
  }

  /**
   * @dev allows spender to spend the tokens owned by msg.sender
   * @param spender the user allowed to spend msg.sender tokens
   * @return true
   **/
  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  /**
   * @dev executes a transfer of token from sender to recipient, if msg.sender is allowed to do so
   * @param sender the owner of the tokens
   * @param recipient the recipient of the tokens
   * @param amount the amount of tokens being transferred
   * @return true if the transfer succeeds, false otherwise
   **/
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(
      sender,
      _msgSender(),
      _allowances[sender][_msgSender()].sub(amount, 'ERC20: transfer amount exceeds allowance')
    );
    return true;
  }

  /**
   * @dev increases the allowance of spender to spend msg.sender tokens
   * @param spender the user allowed to spend on behalf of msg.sender
   * @param addedValue the amount being added to the allowance
   * @return true
   **/
  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  /**
   * @dev decreases the allowance of spender to spend msg.sender tokens
   * @param spender the user allowed to spend on behalf of msg.sender
   * @param subtractedValue the amount being subtracted to the allowance
   * @return true
   **/
  function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
  {
    _approve(
      _msgSender(),
      spender,
      _allowances[_msgSender()][spender].sub(
        subtractedValue,
        'ERC20: decreased allowance below zero'
      )
    );
    return true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual {
    require(sender != address(0), 'ERC20: transfer from the zero address');
    require(recipient != address(0), 'ERC20: transfer to the zero address');

    _beforeTokenTransfer(sender, recipient, amount);

    _balances[sender] = _balances[sender].sub(amount, 'ERC20: transfer amount exceeds balance');
    _balances[recipient] = _balances[recipient].add(amount);
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), 'ERC20: mint to the zero address');

    _beforeTokenTransfer(address(0), account, amount);

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), 'ERC20: burn from the zero address');

    _beforeTokenTransfer(account, address(0), amount);

    _balances[account] = _balances[account].sub(amount, 'ERC20: burn amount exceeds balance');
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), 'ERC20: approve from the zero address');
    require(spender != address(0), 'ERC20: approve to the zero address');

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _setName(string memory newName) internal {
    _name = newName;
  }

  function _setSymbol(string memory newSymbol) internal {
    _symbol = newSymbol;
  }

  function _setDecimals(uint8 newDecimals) internal {
    _decimals = newDecimals;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity 0.7.5;

/**
 * @dev From https://github.com/OpenZeppelin/openzeppelin-contracts
 * Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
  function _msgSender() internal view virtual returns (address payable) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes memory) {
    this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    return msg.data;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {ERC20} from '../lib/ERC20.sol';
import {ITransferHook} from '../interfaces/ITransferHook.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {
  GovernancePowerDelegationERC20
} from '@aave/aave-token/contracts/token/base/GovernancePowerDelegationERC20.sol';

/**
 * @title ERC20WithSnapshot
 * @notice ERC20 including snapshots of balances on transfer-related actions
 * @author Aave
 **/
abstract contract GovernancePowerWithSnapshot is GovernancePowerDelegationERC20 {
  using SafeMath for uint256;

  /**
   * @dev The following storage layout points to the prior StakedToken.sol implementation:
   * _snapshots => _votingSnapshots
   * _snapshotsCounts =>  _votingSnapshotsCounts
   * _aaveGovernance => _aaveGovernance
   */
  mapping(address => mapping(uint256 => Snapshot)) public _votingSnapshots;
  mapping(address => uint256) public _votingSnapshotsCounts;

  /// @dev reference to the Aave governance contract to call (if initialized) on _beforeTokenTransfer
  /// !!! IMPORTANT The Aave governance is considered a trustable contract, being its responsibility
  /// to control all potential reentrancies by calling back the this contract
  ITransferHook public _aaveGovernance;

  function _setAaveGovernance(ITransferHook aaveGovernance) internal virtual {
    _aaveGovernance = aaveGovernance;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface ITransferHook {
  function onTransfer(
    address from,
    address to,
    uint256 amount
  ) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {SafeMath} from '../../open-zeppelin/SafeMath.sol';
import {ERC20} from '../../open-zeppelin/ERC20.sol';
import {
  IGovernancePowerDelegationToken
} from '../../interfaces/IGovernancePowerDelegationToken.sol';

/**
 * @notice implementation of the AAVE token contract
 * @author Aave
 */
abstract contract GovernancePowerDelegationERC20 is ERC20, IGovernancePowerDelegationToken {
  using SafeMath for uint256;
  /// @notice The EIP-712 typehash for the delegation struct used by the contract
  bytes32 public constant DELEGATE_BY_TYPE_TYPEHASH = keccak256(
    'DelegateByType(address delegatee,uint256 type,uint256 nonce,uint256 expiry)'
  );

  bytes32 public constant DELEGATE_TYPEHASH = keccak256(
    'Delegate(address delegatee,uint256 nonce,uint256 expiry)'
  );

  /// @dev snapshot of a value on a specific block, used for votes
  struct Snapshot {
    uint128 blockNumber;
    uint128 value;
  }

  /**
   * @dev delegates one specific power to a delegatee
   * @param delegatee the user which delegated power has changed
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  function delegateByType(address delegatee, DelegationType delegationType) external override {
    _delegateByType(msg.sender, delegatee, delegationType);
  }

  /**
   * @dev delegates all the powers to a specific user
   * @param delegatee the user to which the power will be delegated
   **/
  function delegate(address delegatee) external override {
    _delegateByType(msg.sender, delegatee, DelegationType.VOTING_POWER);
    _delegateByType(msg.sender, delegatee, DelegationType.PROPOSITION_POWER);
  }

  /**
   * @dev returns the delegatee of an user
   * @param delegator the address of the delegator
   **/
  function getDelegateeByType(address delegator, DelegationType delegationType)
    external
    override
    view
    returns (address)
  {
    (, , mapping(address => address) storage delegates) = _getDelegationDataByType(delegationType);

    return _getDelegatee(delegator, delegates);
  }

  /**
   * @dev returns the current delegated power of a user. The current power is the
   * power delegated at the time of the last snapshot
   * @param user the user
   **/
  function getPowerCurrent(address user, DelegationType delegationType)
    external
    override
    view
    returns (uint256)
  {
    (
      mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
      mapping(address => uint256) storage snapshotsCounts,

    ) = _getDelegationDataByType(delegationType);

    return _searchByBlockNumber(snapshots, snapshotsCounts, user, block.number);
  }

  /**
   * @dev returns the delegated power of a user at a certain block
   * @param user the user
   **/
  function getPowerAtBlock(
    address user,
    uint256 blockNumber,
    DelegationType delegationType
  ) external override view returns (uint256) {
    (
      mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
      mapping(address => uint256) storage snapshotsCounts,

    ) = _getDelegationDataByType(delegationType);

    return _searchByBlockNumber(snapshots, snapshotsCounts, user, blockNumber);
  }

  /**
   * @dev returns the total supply at a certain block number
   * used by the voting strategy contracts to calculate the total votes needed for threshold/quorum
   * In this initial implementation with no AAVE minting, simply returns the current supply
   * A snapshots mapping will need to be added in case a mint function is added to the AAVE token in the future
   **/
  function totalSupplyAt(uint256 blockNumber) external override view returns (uint256) {
    return super.totalSupply();
  }

  /**
   * @dev delegates the specific power to a delegatee
   * @param delegatee the user which delegated power has changed
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  function _delegateByType(
    address delegator,
    address delegatee,
    DelegationType delegationType
  ) internal {
    require(delegatee != address(0), 'INVALID_DELEGATEE');

    (, , mapping(address => address) storage delegates) = _getDelegationDataByType(delegationType);

    uint256 delegatorBalance = balanceOf(delegator);

    address previousDelegatee = _getDelegatee(delegator, delegates);

    delegates[delegator] = delegatee;

    _moveDelegatesByType(previousDelegatee, delegatee, delegatorBalance, delegationType);
    emit DelegateChanged(delegator, delegatee, delegationType);
  }

  /**
   * @dev moves delegated power from one user to another
   * @param from the user from which delegated power is moved
   * @param to the user that will receive the delegated power
   * @param amount the amount of delegated power to be moved
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  function _moveDelegatesByType(
    address from,
    address to,
    uint256 amount,
    DelegationType delegationType
  ) internal {
    if (from == to) {
      return;
    }

    (
      mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
      mapping(address => uint256) storage snapshotsCounts,

    ) = _getDelegationDataByType(delegationType);

    if (from != address(0)) {
      uint256 previous = 0;
      uint256 fromSnapshotsCount = snapshotsCounts[from];

      if (fromSnapshotsCount != 0) {
        previous = snapshots[from][fromSnapshotsCount - 1].value;
      } else {
        previous = balanceOf(from);
      }

      _writeSnapshot(
        snapshots,
        snapshotsCounts,
        from,
        uint128(previous),
        uint128(previous.sub(amount))
      );

      emit DelegatedPowerChanged(from, previous.sub(amount), delegationType);
    }
    if (to != address(0)) {
      uint256 previous = 0;
      uint256 toSnapshotsCount = snapshotsCounts[to];
      if (toSnapshotsCount != 0) {
        previous = snapshots[to][toSnapshotsCount - 1].value;
      } else {
        previous = balanceOf(to);
      }

      _writeSnapshot(
        snapshots,
        snapshotsCounts,
        to,
        uint128(previous),
        uint128(previous.add(amount))
      );

      emit DelegatedPowerChanged(to, previous.add(amount), delegationType);
    }
  }

  /**
   * @dev searches a snapshot by block number. Uses binary search.
   * @param snapshots the snapshots mapping
   * @param snapshotsCounts the number of snapshots
   * @param user the user for which the snapshot is being searched
   * @param blockNumber the block number being searched
   **/
  function _searchByBlockNumber(
    mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
    mapping(address => uint256) storage snapshotsCounts,
    address user,
    uint256 blockNumber
  ) internal view returns (uint256) {
    require(blockNumber <= block.number, 'INVALID_BLOCK_NUMBER');

    uint256 snapshotsCount = snapshotsCounts[user];

    if (snapshotsCount == 0) {
      return balanceOf(user);
    }

    // First check most recent balance
    if (snapshots[user][snapshotsCount - 1].blockNumber <= blockNumber) {
      return snapshots[user][snapshotsCount - 1].value;
    }

    // Next check implicit zero balance
    if (snapshots[user][0].blockNumber > blockNumber) {
      return 0;
    }

    uint256 lower = 0;
    uint256 upper = snapshotsCount - 1;
    while (upper > lower) {
      uint256 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
      Snapshot memory snapshot = snapshots[user][center];
      if (snapshot.blockNumber == blockNumber) {
        return snapshot.value;
      } else if (snapshot.blockNumber < blockNumber) {
        lower = center;
      } else {
        upper = center - 1;
      }
    }
    return snapshots[user][lower].value;
  }

  /**
   * @dev returns the delegation data (snapshot, snapshotsCount, list of delegates) by delegation type
   * NOTE: Ideal implementation would have mapped this in a struct by delegation type. Unfortunately,
   * the AAVE token and StakeToken already include a mapping for the snapshots, so we require contracts
   * who inherit from this to provide access to the delegation data by overriding this method.
   * @param delegationType the type of delegation
   **/
  function _getDelegationDataByType(DelegationType delegationType)
    internal
    virtual
    view
    returns (
      mapping(address => mapping(uint256 => Snapshot)) storage, //snapshots
      mapping(address => uint256) storage, //snapshots count
      mapping(address => address) storage //delegatees list
    );

  /**
   * @dev Writes a snapshot for an owner of tokens
   * @param owner The owner of the tokens
   * @param oldValue The value before the operation that is gonna be executed after the snapshot
   * @param newValue The value after the operation
   */
  function _writeSnapshot(
    mapping(address => mapping(uint256 => Snapshot)) storage snapshots,
    mapping(address => uint256) storage snapshotsCounts,
    address owner,
    uint128 oldValue,
    uint128 newValue
  ) internal {
    uint128 currentBlock = uint128(block.number);

    uint256 ownerSnapshotsCount = snapshotsCounts[owner];
    mapping(uint256 => Snapshot) storage snapshotsOwner = snapshots[owner];

    // Doing multiple operations in the same block
    if (
      ownerSnapshotsCount != 0 &&
      snapshotsOwner[ownerSnapshotsCount - 1].blockNumber == currentBlock
    ) {
      snapshotsOwner[ownerSnapshotsCount - 1].value = newValue;
    } else {
      snapshotsOwner[ownerSnapshotsCount] = Snapshot(currentBlock, newValue);
      snapshotsCounts[owner] = ownerSnapshotsCount + 1;
    }
  }

  /**
   * @dev returns the user delegatee. If a user never performed any delegation,
   * his delegated address will be 0x0. In that case we simply return the user itself
   * @param delegator the address of the user for which return the delegatee
   * @param delegates the array of delegates for a particular type of delegation
   **/
  function _getDelegatee(address delegator, mapping(address => address) storage delegates)
    internal
    view
    returns (address)
  {
    address previousDelegatee = delegates[delegator];

    if (previousDelegatee == address(0)) {
      return delegator;
    }

    return previousDelegatee;
  }
}

pragma solidity ^0.7.5;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;

import "./Context.sol";
import "../interfaces/IERC20.sol";
import "./SafeMath.sol";
import "./Address.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of ERC20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string internal _name;
    string internal _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor (string memory name, string memory symbol) public {
        _name = name;
        _symbol = symbol;
        _decimals = 18;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

interface IGovernancePowerDelegationToken {
  
  enum DelegationType {VOTING_POWER, PROPOSITION_POWER}

  /**
   * @dev emitted when a user delegates to another
   * @param delegator the delegator
   * @param delegatee the delegatee
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  event DelegateChanged(
    address indexed delegator,
    address indexed delegatee,
    DelegationType delegationType
  );

  /**
   * @dev emitted when an action changes the delegated power of a user
   * @param user the user which delegated power has changed
   * @param amount the amount of delegated power for the user
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  event DelegatedPowerChanged(address indexed user, uint256 amount, DelegationType delegationType);

  /**
   * @dev delegates the specific power to a delegatee
   * @param delegatee the user which delegated power has changed
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   **/
  function delegateByType(address delegatee, DelegationType delegationType) external virtual;
  /**
   * @dev delegates all the powers to a specific user
   * @param delegatee the user to which the power will be delegated
   **/
  function delegate(address delegatee) external virtual;
  /**
   * @dev returns the delegatee of an user
   * @param delegator the address of the delegator
   **/
  function getDelegateeByType(address delegator, DelegationType delegationType)
    external
    virtual
    view
    returns (address);

  /**
   * @dev returns the current delegated power of a user. The current power is the
   * power delegated at the time of the last snapshot
   * @param user the user
   **/
  function getPowerCurrent(address user, DelegationType delegationType)
    external
    virtual
    view
    returns (uint256);

  /**
   * @dev returns the delegated power of a user at a certain block
   * @param user the user
   **/
  function getPowerAtBlock(
    address user,
    uint256 blockNumber,
    DelegationType delegationType
  ) external virtual view returns (uint256);
 
  /**
  * @dev returns the total supply at a certain block number
  **/
  function totalSupplyAt(uint256 blockNumber) external virtual view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.5;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

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

pragma solidity ^0.7.5;

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
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. `keccak256('')`
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {ERC20} from '@aave/aave-token/contracts/open-zeppelin/ERC20.sol';

import {IERC20} from '../interfaces/IERC20.sol';
import {IStakedToken} from '../interfaces/IStakedToken.sol';
import {ITransferHook} from '../interfaces/ITransferHook.sol';

import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {SafeERC20} from '../lib/SafeERC20.sol';

import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {AaveDistributionManager} from './AaveDistributionManager.sol';
import {GovernancePowerWithSnapshot} from '../lib/GovernancePowerWithSnapshot.sol';

/**
 * @title StakedToken
 * @notice Contract to stake Aave token, tokenize the position and get rewards, inheriting from a distribution manager contract
 * @author Aave
 **/
contract StakedTokenV2 is
  IStakedToken,
  GovernancePowerWithSnapshot,
  VersionedInitializable,
  AaveDistributionManager
{
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  function REVISION() public pure virtual returns (uint256) {
    return 2;
  }

  IERC20 public immutable STAKED_TOKEN;
  IERC20 public immutable REWARD_TOKEN;
  uint256 public immutable COOLDOWN_SECONDS;

  /// @notice Seconds available to redeem once the cooldown period is fullfilled
  uint256 public immutable UNSTAKE_WINDOW;

  /// @notice Address to pull from the rewards, needs to have approved this contract
  address public immutable REWARDS_VAULT;

  mapping(address => uint256) public stakerRewardsToClaim;
  mapping(address => uint256) public stakersCooldowns;

  /// @dev End of Storage layout from StakedToken v1

  /// @dev To see the voting mappings, go to GovernancePowerWithSnapshot.sol
  mapping(address => address) internal _votingDelegates;

  mapping(address => mapping(uint256 => Snapshot)) internal _propositionPowerSnapshots;
  mapping(address => uint256) internal _propositionPowerSnapshotsCounts;
  mapping(address => address) internal _propositionPowerDelegates;

  bytes32 public DOMAIN_SEPARATOR;
  bytes public constant EIP712_REVISION = bytes('1');
  bytes32 internal constant EIP712_DOMAIN =
    keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)');
  bytes32 public constant PERMIT_TYPEHASH =
    keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)');

  /// @dev owner => next valid nonce to submit with permit()
  mapping(address => uint256) public _nonces;

  event Staked(address indexed from, address indexed onBehalfOf, uint256 amount);
  event Redeem(address indexed from, address indexed to, uint256 amount);

  event RewardsAccrued(address user, uint256 amount);
  event RewardsClaimed(address indexed from, address indexed to, uint256 amount);

  event Cooldown(address indexed user);

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address governance
  ) public ERC20(name, symbol) AaveDistributionManager(emissionManager, distributionDuration) {
    STAKED_TOKEN = stakedToken;
    REWARD_TOKEN = rewardToken;
    COOLDOWN_SECONDS = cooldownSeconds;
    UNSTAKE_WINDOW = unstakeWindow;
    REWARDS_VAULT = rewardsVault;
    _aaveGovernance = ITransferHook(governance);
    ERC20._setupDecimals(decimals);
  }

  /**
   * @dev Called by the proxy contract
   **/
  function initialize() external virtual initializer {
    uint256 chainId;

    //solium-disable-next-line
    assembly {
      chainId := chainid()
    }

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(name())),
        keccak256(EIP712_REVISION),
        chainId,
        address(this)
      )
    );
  }

  function stake(address onBehalfOf, uint256 amount) external virtual override {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');
    uint256 balanceOfUser = balanceOf(onBehalfOf);

    uint256 accruedRewards =
      _updateUserAssetInternal(onBehalfOf, address(this), balanceOfUser, totalSupply());
    if (accruedRewards != 0) {
      emit RewardsAccrued(onBehalfOf, accruedRewards);
      stakerRewardsToClaim[onBehalfOf] = stakerRewardsToClaim[onBehalfOf].add(accruedRewards);
    }

    stakersCooldowns[onBehalfOf] = getNextCooldownTimestamp(0, amount, onBehalfOf, balanceOfUser);

    _mint(onBehalfOf, amount);
    IERC20(STAKED_TOKEN).safeTransferFrom(msg.sender, address(this), amount);

    emit Staked(msg.sender, onBehalfOf, amount);
  }

  /**
   * @dev Redeems staked tokens, and stop earning rewards
   * @param to Address to redeem to
   * @param amount Amount to redeem
   **/
  function redeem(address to, uint256 amount) external virtual override {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');
    //solium-disable-next-line
    uint256 cooldownStartTimestamp = stakersCooldowns[msg.sender];
    require(
      block.timestamp > cooldownStartTimestamp.add(COOLDOWN_SECONDS),
      'INSUFFICIENT_COOLDOWN'
    );
    require(
      block.timestamp.sub(cooldownStartTimestamp.add(COOLDOWN_SECONDS)) <= UNSTAKE_WINDOW,
      'UNSTAKE_WINDOW_FINISHED'
    );
    uint256 balanceOfMessageSender = balanceOf(msg.sender);

    uint256 amountToRedeem = (amount > balanceOfMessageSender) ? balanceOfMessageSender : amount;

    _updateCurrentUnclaimedRewards(msg.sender, balanceOfMessageSender, true);

    _burn(msg.sender, amountToRedeem);

    if (balanceOfMessageSender.sub(amountToRedeem) == 0) {
      stakersCooldowns[msg.sender] = 0;
    }

    IERC20(STAKED_TOKEN).safeTransfer(to, amountToRedeem);

    emit Redeem(msg.sender, to, amountToRedeem);
  }

  /**
   * @dev Activates the cooldown period to unstake
   * - It can't be called if the user is not staking
   **/
  function cooldown() external override {
    require(balanceOf(msg.sender) != 0, 'INVALID_BALANCE_ON_COOLDOWN');
    //solium-disable-next-line
    stakersCooldowns[msg.sender] = block.timestamp;

    emit Cooldown(msg.sender);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` to the address `to`
   * @param to Address to stake for
   * @param amount Amount to stake
   **/
  function claimRewards(address to, uint256 amount) external virtual override {
    uint256 newTotalRewards =
      _updateCurrentUnclaimedRewards(msg.sender, balanceOf(msg.sender), false);
    uint256 amountToClaim = (amount == type(uint256).max) ? newTotalRewards : amount;

    stakerRewardsToClaim[msg.sender] = newTotalRewards.sub(amountToClaim, 'INVALID_AMOUNT');

    REWARD_TOKEN.safeTransferFrom(REWARDS_VAULT, to, amountToClaim);

    emit RewardsClaimed(msg.sender, to, amountToClaim);
  }

  /**
   * @dev Internal ERC20 _transfer of the tokenized staked tokens
   * @param from Address to transfer from
   * @param to Address to transfer to
   * @param amount Amount to transfer
   **/
  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    uint256 balanceOfFrom = balanceOf(from);
    // Sender
    _updateCurrentUnclaimedRewards(from, balanceOfFrom, true);

    // Recipient
    if (from != to) {
      uint256 balanceOfTo = balanceOf(to);
      _updateCurrentUnclaimedRewards(to, balanceOfTo, true);

      uint256 previousSenderCooldown = stakersCooldowns[from];
      stakersCooldowns[to] = getNextCooldownTimestamp(
        previousSenderCooldown,
        amount,
        to,
        balanceOfTo
      );
      // if cooldown was set and whole balance of sender was transferred - clear cooldown
      if (balanceOfFrom == amount && previousSenderCooldown != 0) {
        stakersCooldowns[from] = 0;
      }
    }

    super._transfer(from, to, amount);
  }

  /**
   * @dev Updates the user state related with his accrued rewards
   * @param user Address of the user
   * @param userBalance The current balance of the user
   * @param updateStorage Boolean flag used to update or not the stakerRewardsToClaim of the user
   * @return The unclaimed rewards that were added to the total accrued
   **/
  function _updateCurrentUnclaimedRewards(
    address user,
    uint256 userBalance,
    bool updateStorage
  ) internal returns (uint256) {
    uint256 accruedRewards =
      _updateUserAssetInternal(user, address(this), userBalance, totalSupply());
    uint256 unclaimedRewards = stakerRewardsToClaim[user].add(accruedRewards);

    if (accruedRewards != 0) {
      if (updateStorage) {
        stakerRewardsToClaim[user] = unclaimedRewards;
      }
      emit RewardsAccrued(user, accruedRewards);
    }

    return unclaimedRewards;
  }

  /**
   * @dev Calculates the how is gonna be a new cooldown timestamp depending on the sender/receiver situation
   *  - If the timestamp of the sender is "better" or the timestamp of the recipient is 0, we take the one of the recipient
   *  - Weighted average of from/to cooldown timestamps if:
   *    # The sender doesn't have the cooldown activated (timestamp 0).
   *    # The sender timestamp is expired
   *    # The sender has a "worse" timestamp
   *  - If the receiver's cooldown timestamp expired (too old), the next is 0
   * @param fromCooldownTimestamp Cooldown timestamp of the sender
   * @param amountToReceive Amount
   * @param toAddress Address of the recipient
   * @param toBalance Current balance of the receiver
   * @return The new cooldown timestamp
   **/
  function getNextCooldownTimestamp(
    uint256 fromCooldownTimestamp,
    uint256 amountToReceive,
    address toAddress,
    uint256 toBalance
  ) public view returns (uint256) {
    uint256 toCooldownTimestamp = stakersCooldowns[toAddress];
    if (toCooldownTimestamp == 0) {
      return 0;
    }

    uint256 minimalValidCooldownTimestamp =
      block.timestamp.sub(COOLDOWN_SECONDS).sub(UNSTAKE_WINDOW);

    if (minimalValidCooldownTimestamp > toCooldownTimestamp) {
      toCooldownTimestamp = 0;
    } else {
      uint256 fromCooldownTimestamp =
        (minimalValidCooldownTimestamp > fromCooldownTimestamp)
          ? block.timestamp
          : fromCooldownTimestamp;

      if (fromCooldownTimestamp < toCooldownTimestamp) {
        return toCooldownTimestamp;
      } else {
        toCooldownTimestamp = (
          amountToReceive.mul(fromCooldownTimestamp).add(toBalance.mul(toCooldownTimestamp))
        )
          .div(amountToReceive.add(toBalance));
      }
    }

    return toCooldownTimestamp;
  }

  /**
   * @dev Return the total rewards pending to claim by an staker
   * @param staker The staker address
   * @return The rewards
   */
  function getTotalRewardsBalance(address staker) external view returns (uint256) {
    DistributionTypes.UserStakeInput[] memory userStakeInputs =
      new DistributionTypes.UserStakeInput[](1);
    userStakeInputs[0] = DistributionTypes.UserStakeInput({
      underlyingAsset: address(this),
      stakedByUser: balanceOf(staker),
      totalStaked: totalSupply()
    });
    return stakerRewardsToClaim[staker].add(_getUnclaimedRewards(staker, userStakeInputs));
  }

  /**
   * @dev returns the revision of the implementation contract
   * @return The revision
   */
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION();
  }

  /**
   * @dev implements the permit function as for https://github.com/ethereum/EIPs/blob/8a34d644aacf0f9f8f00815307fd7dd5da07655f/EIPS/eip-2612.md
   * @param owner the owner of the funds
   * @param spender the spender
   * @param value the amount
   * @param deadline the deadline timestamp, type(uint256).max for no deadline
   * @param v signature param
   * @param s signature param
   * @param r signature param
   */

  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    require(owner != address(0), 'INVALID_OWNER');
    //solium-disable-next-line
    require(block.timestamp <= deadline, 'INVALID_EXPIRATION');
    uint256 currentValidNonce = _nonces[owner];
    bytes32 digest =
      keccak256(
        abi.encodePacked(
          '\x19\x01',
          DOMAIN_SEPARATOR,
          keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, currentValidNonce, deadline))
        )
      );

    require(owner == ecrecover(digest, v, r, s), 'INVALID_SIGNATURE');
    _nonces[owner] = currentValidNonce.add(1);
    _approve(owner, spender, value);
  }

  /**
   * @dev Writes a snapshot before any operation involving transfer of value: _transfer, _mint and _burn
   * - On _transfer, it writes snapshots for both "from" and "to"
   * - On _mint, only for _to
   * - On _burn, only for _from
   * @param from the from address
   * @param to the to address
   * @param amount the amount to transfer
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    address votingFromDelegatee = _votingDelegates[from];
    address votingToDelegatee = _votingDelegates[to];

    if (votingFromDelegatee == address(0)) {
      votingFromDelegatee = from;
    }
    if (votingToDelegatee == address(0)) {
      votingToDelegatee = to;
    }

    _moveDelegatesByType(
      votingFromDelegatee,
      votingToDelegatee,
      amount,
      DelegationType.VOTING_POWER
    );

    address propPowerFromDelegatee = _propositionPowerDelegates[from];
    address propPowerToDelegatee = _propositionPowerDelegates[to];

    if (propPowerFromDelegatee == address(0)) {
      propPowerFromDelegatee = from;
    }
    if (propPowerToDelegatee == address(0)) {
      propPowerToDelegatee = to;
    }

    _moveDelegatesByType(
      propPowerFromDelegatee,
      propPowerToDelegatee,
      amount,
      DelegationType.PROPOSITION_POWER
    );

    // caching the aave governance address to avoid multiple state loads
    ITransferHook aaveGovernance = _aaveGovernance;
    if (aaveGovernance != ITransferHook(0)) {
      aaveGovernance.onTransfer(from, to, amount);
    }
  }

  function _getDelegationDataByType(DelegationType delegationType)
    internal
    view
    override
    returns (
      mapping(address => mapping(uint256 => Snapshot)) storage, //snapshots
      mapping(address => uint256) storage, //snapshots count
      mapping(address => address) storage //delegatees list
    )
  {
    if (delegationType == DelegationType.VOTING_POWER) {
      return (_votingSnapshots, _votingSnapshotsCounts, _votingDelegates);
    } else {
      return (
        _propositionPowerSnapshots,
        _propositionPowerSnapshotsCounts,
        _propositionPowerDelegates
      );
    }
  }

  /**
   * @dev Delegates power from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param delegationType the type of delegation (VOTING_POWER, PROPOSITION_POWER)
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateByTypeBySig(
    address delegatee,
    DelegationType delegationType,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 structHash =
      keccak256(
        abi.encode(DELEGATE_BY_TYPE_TYPEHASH, delegatee, uint256(delegationType), nonce, expiry)
      );
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0), 'INVALID_SIGNATURE');
    require(nonce == _nonces[signatory]++, 'INVALID_NONCE');
    require(block.timestamp <= expiry, 'INVALID_EXPIRATION');
    _delegateByType(signatory, delegatee, delegationType);
  }

  /**
   * @dev Delegates power from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) public {
    bytes32 structHash = keccak256(abi.encode(DELEGATE_TYPEHASH, delegatee, nonce, expiry));
    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, structHash));
    address signatory = ecrecover(digest, v, r, s);
    require(signatory != address(0), 'INVALID_SIGNATURE');
    require(nonce == _nonces[signatory]++, 'INVALID_NONCE');
    require(block.timestamp <= expiry, 'INVALID_EXPIRATION');
    _delegateByType(signatory, delegatee, DelegationType.VOTING_POWER);
    _delegateByType(signatory, delegatee, DelegationType.PROPOSITION_POWER);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

library DistributionTypes {
  struct AssetConfigInput {
    uint128 emissionPerSecond;
    uint256 totalStaked;
    address underlyingAsset;
  }

  struct UserStakeInput {
    address underlyingAsset;
    uint256 stakedByUser;
    uint256 totalStaked;
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {SafeMath} from '../lib/SafeMath.sol';
import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {IAaveDistributionManager} from '../interfaces/IAaveDistributionManager.sol';

/**
 * @title AaveDistributionManager
 * @notice Accounting contract to manage multiple staking distributions
 * @author Aave
 **/
contract AaveDistributionManager is IAaveDistributionManager {
  using SafeMath for uint256;

  struct AssetData {
    uint128 emissionPerSecond;
    uint128 lastUpdateTimestamp;
    uint256 index;
    mapping(address => uint256) users;
  }

  uint256 internal immutable _oldDistributionEnd;

  address public immutable EMISSION_MANAGER;

  uint8 public constant PRECISION = 18;

  mapping(address => AssetData) public assets;

  event AssetConfigUpdated(address indexed asset, uint256 emission);
  event AssetIndexUpdated(address indexed asset, uint256 index);
  event UserIndexUpdated(address indexed user, address indexed asset, uint256 index);

  constructor(address emissionManager, uint256 distributionDuration) public {
    _oldDistributionEnd = block.timestamp.add(distributionDuration);
    EMISSION_MANAGER = emissionManager;
  }

  /**
   * @dev Configures the distribution of rewards for a list of assets
   * @param assetsConfigInput The list of configurations to apply
   **/
  function configureAssets(DistributionTypes.AssetConfigInput[] calldata assetsConfigInput)
    external
    override
  {
    require(msg.sender == EMISSION_MANAGER, 'ONLY_EMISSION_MANAGER');

    for (uint256 i = 0; i < assetsConfigInput.length; i++) {
      AssetData storage assetConfig = assets[assetsConfigInput[i].underlyingAsset];

      _updateAssetStateInternal(
        assetsConfigInput[i].underlyingAsset,
        assetConfig,
        assetsConfigInput[i].totalStaked
      );

      assetConfig.emissionPerSecond = assetsConfigInput[i].emissionPerSecond;

      emit AssetConfigUpdated(
        assetsConfigInput[i].underlyingAsset,
        assetsConfigInput[i].emissionPerSecond
      );
    }
  }

  /**
   * @dev Updates the state of one distribution, mainly rewards index and timestamp
   * @param underlyingAsset The address used as key in the distribution, for example sAAVE or the aTokens addresses on Aave
   * @param assetConfig Storage pointer to the distribution's config
   * @param totalStaked Current total of staked assets for this distribution
   * @return The new distribution index
   **/
  function _updateAssetStateInternal(
    address underlyingAsset,
    AssetData storage assetConfig,
    uint256 totalStaked
  ) internal returns (uint256) {
    uint256 oldIndex = assetConfig.index;
    uint128 lastUpdateTimestamp = assetConfig.lastUpdateTimestamp;

    if (block.timestamp == lastUpdateTimestamp) {
      return oldIndex;
    }

    uint256 newIndex =
      _getAssetIndex(oldIndex, assetConfig.emissionPerSecond, lastUpdateTimestamp, totalStaked);

    if (newIndex != oldIndex) {
      assetConfig.index = newIndex;
      emit AssetIndexUpdated(underlyingAsset, newIndex);
    }

    assetConfig.lastUpdateTimestamp = uint128(block.timestamp);

    return newIndex;
  }

  /**
   * @dev Updates the state of an user in a distribution
   * @param user The user's address
   * @param asset The address of the reference asset of the distribution
   * @param stakedByUser Amount of tokens staked by the user in the distribution at the moment
   * @param totalStaked Total tokens staked in the distribution
   * @return The accrued rewards for the user until the moment
   **/
  function _updateUserAssetInternal(
    address user,
    address asset,
    uint256 stakedByUser,
    uint256 totalStaked
  ) internal returns (uint256) {
    AssetData storage assetData = assets[asset];
    uint256 userIndex = assetData.users[user];
    uint256 accruedRewards = 0;

    uint256 newIndex = _updateAssetStateInternal(asset, assetData, totalStaked);

    if (userIndex != newIndex) {
      if (stakedByUser != 0) {
        accruedRewards = _getRewards(stakedByUser, newIndex, userIndex);
      }

      assetData.users[user] = newIndex;
      emit UserIndexUpdated(user, asset, newIndex);
    }

    return accruedRewards;
  }

  /**
   * @dev Used by "frontend" stake contracts to update the data of an user when claiming rewards from there
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _claimRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      accruedRewards = accruedRewards.add(
        _updateUserAssetInternal(
          user,
          stakes[i].underlyingAsset,
          stakes[i].stakedByUser,
          stakes[i].totalStaked
        )
      );
    }

    return accruedRewards;
  }

  /**
   * @dev Return the accrued rewards for an user over a list of distribution
   * @param user The address of the user
   * @param stakes List of structs of the user data related with his stake
   * @return The accrued rewards for the user until the moment
   **/
  function _getUnclaimedRewards(address user, DistributionTypes.UserStakeInput[] memory stakes)
    internal
    view
    returns (uint256)
  {
    uint256 accruedRewards = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
      AssetData storage assetConfig = assets[stakes[i].underlyingAsset];
      uint256 assetIndex =
        _getAssetIndex(
          assetConfig.index,
          assetConfig.emissionPerSecond,
          assetConfig.lastUpdateTimestamp,
          stakes[i].totalStaked
        );

      accruedRewards = accruedRewards.add(
        _getRewards(stakes[i].stakedByUser, assetIndex, assetConfig.users[user])
      );
    }
    return accruedRewards;
  }

  /**
   * @dev Internal function for the calculation of user's rewards on a distribution
   * @param principalUserBalance Amount staked by the user on a distribution
   * @param reserveIndex Current index of the distribution
   * @param userIndex Index stored for the user, representation his staking moment
   * @return The rewards
   **/
  function _getRewards(
    uint256 principalUserBalance,
    uint256 reserveIndex,
    uint256 userIndex
  ) internal pure returns (uint256) {
    return principalUserBalance.mul(reserveIndex.sub(userIndex)).div(10**uint256(PRECISION));
  }

  /**
   * @dev Calculates the next value of an specific distribution index, with validations
   * @param currentIndex Current index of the distribution
   * @param emissionPerSecond Representing the total rewards distributed per second per asset unit, on the distribution
   * @param lastUpdateTimestamp Last moment this distribution was updated
   * @param totalBalance of tokens considered for the distribution
   * @return The new index.
   **/
  function _getAssetIndex(
    uint256 currentIndex,
    uint256 emissionPerSecond,
    uint128 lastUpdateTimestamp,
    uint256 totalBalance
  ) internal view returns (uint256) {
    if (
      emissionPerSecond == 0 ||
      totalBalance == 0 ||
      lastUpdateTimestamp == block.timestamp ||
      lastUpdateTimestamp >= _getDistributionEnd()
    ) {
      return currentIndex;
    }

    uint256 currentTimestamp =
      block.timestamp > _getDistributionEnd() ? _getDistributionEnd() : block.timestamp;
    uint256 timeDelta = currentTimestamp.sub(lastUpdateTimestamp);
    return
      emissionPerSecond.mul(timeDelta).mul(10**uint256(PRECISION)).div(totalBalance).add(
        currentIndex
      );
  }

  /**
   * @dev Returns the data of an user on a distribution
   * @param user Address of the user
   * @param asset The address of the reference asset of the distribution
   * @return The new index
   **/
  function getUserAssetData(address user, address asset) public view returns (uint256) {
    return assets[asset].users[user];
  }

  /**
   * @dev Returns the timestamp of the end of the current distribution
   * @notice This field remains virtual to extend at AaveDistributionManageV2, keeping V1 logic
   * @return uint256 unix timestamp
   **/
  function _getDistributionEnd() internal view virtual returns (uint256) {
    return _oldDistributionEnd;
  }

  /**
   * @dev Keeps interface compatibility. Returns the timestamp of the end of the current distribution
   * @return uint256 unix timestamp
   **/
  function DISTRIBUTION_END() external view returns (uint256) {
    return _getDistributionEnd();
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {DistributionTypes} from '../lib/DistributionTypes.sol';

interface IAaveDistributionManager {
  function configureAssets(DistributionTypes.AssetConfigInput[] calldata assetsConfigInput)
    external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {ERC20} from '@aave/aave-token/contracts/open-zeppelin/ERC20.sol';

import {IERC20} from '../interfaces/IERC20.sol';
import {IERC20WithPermit} from '../interfaces/IERC20WithPermit.sol';
import {IStakedToken} from '../interfaces/IStakedToken.sol';
import {IStakedTokenV3} from '../interfaces/IStakedTokenV3.sol';
import {ITransferHook} from '../interfaces/ITransferHook.sol';

import {DistributionTypes} from '../lib/DistributionTypes.sol';
import {SafeMath} from '../lib/SafeMath.sol';
import {SafeERC20} from '../lib/SafeERC20.sol';
import {PercentageMath} from '../lib/PercentageMath.sol';
import {StakedTokenV2} from './StakedTokenV2.sol';

import {VersionedInitializable} from '../utils/VersionedInitializable.sol';
import {AaveDistributionManager} from './AaveDistributionManager.sol';
import {GovernancePowerWithSnapshot} from '../lib/GovernancePowerWithSnapshot.sol';
import {RoleManager} from '../utils/RoleManager.sol';

/**
 * @title StakedToken
 * @notice Contract to stake Aave token, tokenize the position and get rewards, inheriting from a distribution manager contract
 * @author Aave
 **/
contract StakedTokenV3 is StakedTokenV2, IStakedTokenV3, RoleManager {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;
  using PercentageMath for uint256;

  uint256 public constant SLASH_ADMIN_ROLE = 0;
  uint256 public constant COOLDOWN_ADMIN_ROLE = 1;
  uint256 public constant CLAIM_HELPER_ROLE = 2;

  function REVISION() public pure virtual override returns (uint256) {
    return 3;
  }

  //maximum percentage of the underlying that can be slashed in a single realization event
  uint256 internal _maxSlashablePercentage;
  bool _cooldownPaused;

  modifier onlySlashingAdmin {
    require(msg.sender == getAdmin(SLASH_ADMIN_ROLE), 'CALLER_NOT_SLASHING_ADMIN');
    _;
  }

  modifier onlyCooldownAdmin {
    require(msg.sender == getAdmin(COOLDOWN_ADMIN_ROLE), 'CALLER_NOT_COOLDOWN_ADMIN');
    _;
  }

  modifier onlyClaimHelper {
    require(msg.sender == getAdmin(CLAIM_HELPER_ROLE), 'CALLER_NOT_CLAIM_HELPER');
    _;
  }

  event Staked(address indexed from, address indexed to, uint256 amount, uint256 sharesMinted);
  event Redeem(
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 underlyingTransferred
  );
  event CooldownPauseChanged(bool pause);
  event MaxSlashablePercentageChanged(uint256 newPercentage);
  event Slashed(address indexed destination, uint256 amount);
  event CooldownPauseAdminChanged(address indexed newAdmin);
  event SlashingAdminChanged(address indexed newAdmin);

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration,
    string memory name,
    string memory symbol,
    uint8 decimals,
    address governance
  )
    public
    StakedTokenV2(
      stakedToken,
      rewardToken,
      cooldownSeconds,
      unstakeWindow,
      rewardsVault,
      emissionManager,
      distributionDuration,
      name,
      symbol,
      decimals,
      governance
    )
  {}

  /**
   * @dev Inherited from StakedTokenV2, deprecated
   **/
  function initialize() external override {
    revert('DEPRECATED');
  }

  /**
   * @dev Called by the proxy contract
   **/
  function initialize(
    address slashingAdmin,
    address cooldownPauseAdmin,
    address claimHelper,
    uint256 maxSlashablePercentage,
    string calldata name,
    string calldata symbol,
    uint8 decimals
  ) external initializer {
    uint256 chainId;

    //solium-disable-next-line
    assembly {
      chainId := chainid()
    }

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        EIP712_DOMAIN,
        keccak256(bytes(super.name())),
        keccak256(EIP712_REVISION),
        chainId,
        address(this)
      )
    );

    if (REVISION() == 1) {
      _name = name;
      _symbol = symbol;
      _setupDecimals(decimals);
    }

    address[] memory adminsAddresses = new address[](3);
    uint256[] memory adminsRoles = new uint256[](3);

    adminsAddresses[0] = slashingAdmin;
    adminsAddresses[1] = cooldownPauseAdmin;
    adminsAddresses[2] = claimHelper;

    adminsRoles[0] = SLASH_ADMIN_ROLE;
    adminsRoles[1] = COOLDOWN_ADMIN_ROLE;
    adminsRoles[2] = CLAIM_HELPER_ROLE;

    _initAdmins(adminsRoles, adminsAddresses);

    _maxSlashablePercentage = maxSlashablePercentage;
  }

  /**
   * @dev Allows a from to stake STAKED_TOKEN
   * @param to Address of the from that will receive stake token shares
   * @param amount The amount to be staked
   **/
  function stake(address to, uint256 amount) external override(IStakedToken, StakedTokenV2) {
    _stake(msg.sender, to, amount, true);
  }

  /**
   * @dev Allows a from to stake STAKED_TOKEN with gasless approvals (permit)
   * @param to Address of the from that will receive stake token shares
   * @param amount The amount to be staked
   * @param deadline The permit execution deadline
   * @param v The v component of the signed message
   * @param r The r component of the signed message
   * @param s The s component of the signed message
   **/
  function stakeWithPermit(
    address from,
    address to,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external override {
    IERC20WithPermit(address(STAKED_TOKEN)).permit(from, address(this), amount, deadline, v, r, s);
    _stake(from, to, amount, true);
  }

  /**
   * @dev Redeems staked tokens, and stop earning rewards
   * @param to Address to redeem to
   * @param amount Amount to redeem
   **/
  function redeem(address to, uint256 amount) external override(IStakedToken, StakedTokenV2) {
    _redeem(msg.sender, to, amount);
  }

  /**
   * @dev Redeems staked tokens for a user. Only the claim helper contract is allowed to call this function
   * @param from Address to redeem from
   * @param to Address to redeem to
   * @param amount Amount to redeem
   **/
  function redeemOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external override onlyClaimHelper {
    _redeem(from, to, amount);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` to the address `to`
   * @param to Address to send the claimed rewards
   * @param amount Amount to stake
   **/
  function claimRewards(address to, uint256 amount) external override(IStakedToken, StakedTokenV2) {
    _claimRewards(msg.sender, to, amount);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` to the address `to` on behalf of the user. Only the claim helper contract is allowed to call this function
   * @param from The address of the user from to claim
   * @param to Address to send the claimed rewards
   * @param amount Amount to claim
   **/
  function claimRewardsOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external override onlyClaimHelper returns (uint256) {
    return _claimRewards(from, to, amount);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` amd restakes
   * @param to Address to stake to
   * @param amount Amount to claim
   **/
  function claimRewardsAndStake(address to, uint256 amount) external override returns (uint256) {
    require(REWARD_TOKEN == STAKED_TOKEN, 'REWARD_TOKEN_IS_NOT_STAKED_TOKEN');

    uint256 rewardsClaimed = _claimRewards(msg.sender, address(this), amount);
    if (rewardsClaimed != 0) {
      _stake(address(this), to, rewardsClaimed, false);
    }
    return rewardsClaimed;
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` and restakes. Only the claim helper contract is allowed to call this function
   * @param from The address of the from from which to claim
   * @param to Address to stake to
   * @param amount Amount to claim
   **/
  function claimRewardsAndStakeOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external override onlyClaimHelper returns (uint256) {
    require(REWARD_TOKEN == STAKED_TOKEN, 'REWARD_TOKEN_IS_NOT_STAKED_TOKEN');

    uint256 rewardsClaimed = _claimRewards(from, address(this), amount);
    _stake(address(this), to, rewardsClaimed, false);
    return (rewardsClaimed);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` amd redeem
   * @param claimAmount Amount to claim
   * @param redeemAmount Amount to redeem
   * @param to Address to claim and unstake to
   **/
  function claimRewardsAndRedeem(
    address to,
    uint256 claimAmount,
    uint256 redeemAmount
  ) external override {
    _claimRewards(msg.sender, to, claimAmount);
    _redeem(msg.sender, to, redeemAmount);
  }

  /**
   * @dev Claims an `amount` of `REWARD_TOKEN` and redeem. Only the claim helper contract is allowed to call this function
   * @param from The address of the from
   * @param to Address to claim and unstake to
   * @param claimAmount Amount to claim
   * @param redeemAmount Amount to redeem
   **/
  function claimRewardsAndRedeemOnBehalf(
    address from,
    address to,
    uint256 claimAmount,
    uint256 redeemAmount
  ) external override onlyClaimHelper {
    _claimRewards(from, to, claimAmount);
    _redeem(from, to, redeemAmount);
  }

  /**
   * @dev Calculates the exchange rate between the amount of STAKED_TOKEN and the the StakeToken total supply.
   * Slashing will reduce the exchange rate. Supplying STAKED_TOKEN to the stake contract
   * can replenish the slashed STAKED_TOKEN and bring the exchange rate back to 1
   **/
  function exchangeRate() public view override returns (uint256) {
    uint256 currentSupply = totalSupply();

    if (currentSupply == 0) {
      return 1e18; //initial exchange rate is 1:1
    }

    return STAKED_TOKEN.balanceOf(address(this)).mul(1e18).div(currentSupply);
  }

  /**
   * @dev Executes a slashing of the underlying of a certain amount, transferring the seized funds
   * to destination. Decreasing the amount of underlying will automatically adjust the exchange rate
   * @param destination the address where seized funds will be transferred
   * @param amount the amount
   **/
  function slash(address destination, uint256 amount) external override onlySlashingAdmin {
    uint256 balance = STAKED_TOKEN.balanceOf(address(this));

    uint256 maxSlashable = balance.percentMul(_maxSlashablePercentage);

    require(amount <= maxSlashable, 'INVALID_SLASHING_AMOUNT');

    STAKED_TOKEN.safeTransfer(destination, amount);

    emit Slashed(destination, amount);
  }

  /**
   * @dev returns true if the unstake cooldown is paused
   */
  function getCooldownPaused() external view override returns (bool) {
    return _cooldownPaused;
  }

  /**
   * @dev sets the state of the cooldown pause
   * @param paused true if the cooldown needs to be paused, false otherwise
   */
  function setCooldownPause(bool paused) external override onlyCooldownAdmin {
    _cooldownPaused = paused;
    emit CooldownPauseChanged(paused);
  }

  /**
   * @dev sets the admin of the slashing pausing function
   * @param percentage the new maximum slashable percentage
   */
  function setMaxSlashablePercentage(uint256 percentage) external override onlySlashingAdmin {
    require(percentage <= PercentageMath.PERCENTAGE_FACTOR, 'INVALID_SLASHING_PERCENTAGE');

    _maxSlashablePercentage = percentage;
    emit MaxSlashablePercentageChanged(percentage);
  }

  /**
   * @dev returns the current maximum slashable percentage of the stake
   */
  function getMaxSlashablePercentage() external view override returns (uint256) {
    return _maxSlashablePercentage;
  }

  /**
   * @dev returns the revision of the implementation contract
   * @return The revision
   */
  function getRevision() internal pure virtual override returns (uint256) {
    return REVISION();
  }

  function _claimRewards(
    address from,
    address to,
    uint256 amount
  ) internal returns (uint256) {
    uint256 newTotalRewards = _updateCurrentUnclaimedRewards(from, balanceOf(from), false);

    uint256 amountToClaim = (amount == type(uint256).max) ? newTotalRewards : amount;

    stakerRewardsToClaim[from] = newTotalRewards.sub(amountToClaim, 'INVALID_AMOUNT');
    REWARD_TOKEN.safeTransferFrom(REWARDS_VAULT, to, amountToClaim);
    emit RewardsClaimed(from, to, amountToClaim);
    return (amountToClaim);
  }

  function _stake(
    address from,
    address to,
    uint256 amount,
    bool pullFunds
  ) internal {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');

    uint256 balanceOfUser = balanceOf(to);

    uint256 accruedRewards =
      _updateUserAssetInternal(to, address(this), balanceOfUser, totalSupply());

    if (accruedRewards != 0) {
      emit RewardsAccrued(to, accruedRewards);
      stakerRewardsToClaim[to] = stakerRewardsToClaim[to].add(accruedRewards);
    }

    stakersCooldowns[to] = getNextCooldownTimestamp(0, amount, to, balanceOfUser);

    uint256 sharesToMint = amount.mul(1e18).div(exchangeRate());
    _mint(to, sharesToMint);

    if (pullFunds) {
      STAKED_TOKEN.safeTransferFrom(from, address(this), amount);
    }

    emit Staked(from, to, amount, sharesToMint);
  }

  /**
   * @dev Redeems staked tokens, and stop earning rewards
   * @param to Address to redeem to
   * @param amount Amount to redeem
   **/
  function _redeem(
    address from,
    address to,
    uint256 amount
  ) internal {
    require(amount != 0, 'INVALID_ZERO_AMOUNT');
    //solium-disable-next-line
    uint256 cooldownStartTimestamp = stakersCooldowns[from];

    require(
      !_cooldownPaused && block.timestamp > cooldownStartTimestamp.add(COOLDOWN_SECONDS),
      'INSUFFICIENT_COOLDOWN'
    );
    require(
      block.timestamp.sub(cooldownStartTimestamp.add(COOLDOWN_SECONDS)) <= UNSTAKE_WINDOW,
      'UNSTAKE_WINDOW_FINISHED'
    );
    uint256 balanceOfFrom = balanceOf(from);

    uint256 amountToRedeem = (amount > balanceOfFrom) ? balanceOfFrom : amount;

    _updateCurrentUnclaimedRewards(from, balanceOfFrom, true);

    uint256 underlyingToRedeem = amountToRedeem.mul(exchangeRate()).div(1e18);

    _burn(from, amountToRedeem);

    if (balanceOfFrom.sub(amountToRedeem) == 0) {
      stakersCooldowns[from] = 0;
    }

    IERC20(STAKED_TOKEN).safeTransfer(to, underlyingToRedeem);

    emit Redeem(from, to, amountToRedeem, underlyingToRedeem);
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {IERC20} from './IERC20.sol';

interface IERC20WithPermit is IERC20 {
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import {IStakedToken} from './IStakedToken.sol';

interface IStakedTokenV3 is IStakedToken {
  function exchangeRate() external view returns (uint256);

  function getCooldownPaused() external view returns (bool);

  function setCooldownPause(bool paused) external;

  function slash(address destination, uint256 amount) external;

  function getMaxSlashablePercentage() external view returns (uint256);

  function setMaxSlashablePercentage(uint256 percentage) external;

  function stakeWithPermit(
    address from,
    address to,
    uint256 amount,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function claimRewardsOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external returns (uint256);

  function redeemOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external;

  function claimRewardsAndStake(address to, uint256 amount) external returns (uint256);

  function claimRewardsAndRedeem(
    address to,
    uint256 claimAmount,
    uint256 redeemAmount
  ) external;

  function claimRewardsAndStakeOnBehalf(
    address from,
    address to,
    uint256 amount
  ) external returns (uint256);

  function claimRewardsAndRedeemOnBehalf(
    address from,
    address to,
    uint256 claimAmount,
    uint256 redeemAmount
  ) external;
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded half up
 **/

library PercentageMath {
  uint256 constant PERCENTAGE_FACTOR = 1e4; //percentage plus two decimals
  uint256 constant HALF_PERCENT = PERCENTAGE_FACTOR / 2;

  /**
   * @dev Executes a percentage multiplication
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The percentage of value
   **/
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256) {
    if (value == 0 || percentage == 0) {
      return 0;
    }

    require(
      value <= (type(uint256).max - HALF_PERCENT) / percentage,
      "MATH_MULTIPLICATION_OVERFLOW"
    );

    return (value * percentage + HALF_PERCENT) / PERCENTAGE_FACTOR;
  }

  /**
   * @dev Executes a percentage division
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return The value divided the percentage
   **/
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256) {
    require(percentage != 0, "MATH_DIVISION_BY_ZERO");
    uint256 halfPercentage = percentage / 2;

    require(
      value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR,
      "MATH_MULTIPLICATION_OVERFLOW"
    );

    return (value * PERCENTAGE_FACTOR + halfPercentage) / percentage;
  }
}

pragma solidity ^0.7.5;

/**
 * @title RoleManager
 * @notice Generic role manager to manage slashing and cooldown admin in StakedAaveV3.
 *         It implements a claim admin role pattern to safely migrate between different admin addresses
 * @author Aave
 **/
contract RoleManager {
  mapping(uint256 => address) private _admins;
  mapping(uint256 => address) private _pendingAdmins;

  event PendingAdminChanged(address indexed newPendingAdmin);
  event RoleClaimed(address indexed newAdming, uint256 role);

  modifier onlyRoleAdmin(uint256 role) {
    require(_admins[role] == msg.sender, 'CALLER_NOT_ROLE_ADMIN');
    _;
  }

  modifier onlyPendingRoleAdmin(uint256 role) {
    require(_pendingAdmins[role] == msg.sender, 'CALLER_NOT_PENDING_ROLE_ADMIN');
    _;
  }

  /**
  * @dev returns the admin associated with the specific role
  * @param role the role associated with the admin being returned
  **/
  function getAdmin(uint256 role) public view returns (address) {
    return _admins[role];
  }

  /**
  * @dev returns the pending admin associated with the specific role
  * @param role the role associated with the pending admin being returned
  **/
  function getPendingAdmin(uint256 role) public view returns (address) {
    return _pendingAdmins[role];
  }

  /**
  * @dev sets the pending admin for a specific role
  * @param role the role associated with the new pending admin being set
  * @param newPendingAdmin the address of the new pending admin
  **/
  function setPendingAdmin(uint256 role, address newPendingAdmin) public onlyRoleAdmin(role) {
    _pendingAdmins[role] = newPendingAdmin;
    emit PendingAdminChanged(newPendingAdmin);
  }

  /**
  * @dev allows the caller to become a specific role admin
  * @param role the role associated with the admin claiming the new role
  **/
  function claimRoleAdmin(uint256 role) external onlyPendingRoleAdmin(role) {
    _admins[role] = msg.sender;
    emit RoleClaimed(msg.sender, role);
  }

  function _initAdmins(uint256[] memory roles, address[] memory admins) internal {
    require(roles.length == admins.length, 'INCONSISTENT_INITIALIZATION');

    for (uint256 i = 0; i < roles.length; i++) {
      require(_admins[i] == address(0), 'ADMIN_ALREADY_INITIALIZED');
      _admins[roles[i]] = admins[i];
      emit RoleClaimed(admins[i], roles[i]);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import './Proxy.sol';
import './Address.sol';

/**
 * @title BaseUpgradeabilityProxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * This contract implements a proxy that allows to change the
 * implementation address to which it will delegate.
 * Such a change is called an implementation upgrade.
 */
contract BaseUpgradeabilityProxy is Proxy {
  /**
   * @dev Emitted when the implementation is upgraded.
   * @param implementation Address of the new implementation.
   */
  event Upgraded(address indexed implementation);

  /**
   * @dev Storage slot with the address of the current implementation.
   * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
   * validated in the constructor.
   */
  bytes32 internal constant IMPLEMENTATION_SLOT =
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

  /**
   * @dev Returns the current implementation.
   * @return impl Address of the current implementation
   */
  function _implementation() internal view override returns (address impl) {
    bytes32 slot = IMPLEMENTATION_SLOT;
    assembly {
      impl := sload(slot)
    }
  }

  /**
   * @dev Upgrades the proxy to a new implementation.
   * @param newImplementation Address of the new implementation.
   */
  function _upgradeTo(address newImplementation) internal {
    _setImplementation(newImplementation);
    emit Upgraded(newImplementation);
  }

  /**
   * @dev Sets the implementation address of the proxy.
   * @param newImplementation Address of the new implementation.
   */
  function _setImplementation(address newImplementation) internal {
    require(
      Address.isContract(newImplementation),
      'Cannot set a proxy implementation to a non-contract address'
    );

    bytes32 slot = IMPLEMENTATION_SLOT;

    assembly {
      sstore(slot, newImplementation)
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

/**
 * @title Proxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * Implements delegation of calls to other contracts, with proper
 * forwarding of return values and bubbling of failures.
 * It defines a fallback function that delegates all calls to the address
 * returned by the abstract _implementation() internal function.
 */
abstract contract Proxy {
  /**
   * @dev Fallback function.
   * Implemented entirely in `_fallback`.
   */
  fallback() external payable {
    _fallback();
  }

  /**
   * @return The Address of the implementation.
   */
  function _implementation() internal view virtual returns (address);

  /**
   * @dev Delegates execution to an implementation contract.
   * This is a low level function that doesn't return to its internal call site.
   * It will return to the external caller whatever the implementation returns.
   * @param implementation Address to delegate.
   */
  function _delegate(address implementation) internal {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())

      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())

      switch result
        // delegatecall returns 0 on error.
        case 0 {
          revert(0, returndatasize())
        }
        default {
          return(0, returndatasize())
        }
    }
  }

  /**
   * @dev Function that is run as the first thing in the fallback function.
   * Can be redefined in derived contracts to add functionality.
   * Redefinitions must call super._willFallback().
   */
  function _willFallback() internal virtual {}

  /**
   * @dev fallback implementation.
   * Extracted to enable manual triggering.
   */
  function _fallback() internal {
    _willFallback();
    _delegate(_implementation());
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import './BaseUpgradeabilityProxy.sol';

/**
 * @title InitializableUpgradeabilityProxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * Extends BaseUpgradeabilityProxy with an initializer for initializing
 * implementation and init data.
 */
contract InitializableUpgradeabilityProxy is BaseUpgradeabilityProxy {
  /**
   * @dev Contract initializer.
   * @param _logic Address of the initial implementation.
   * @param _data Data to send as msg.data to the implementation to initialize the proxied contract.
   * It should include the signature and the parameters of the function to be called, as described in
   * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
   * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
   */
  function initialize(address _logic, bytes memory _data) public payable {
    require(_implementation() == address(0));
    assert(IMPLEMENTATION_SLOT == bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
    _setImplementation(_logic);
    if (_data.length > 0) {
      (bool success, ) = _logic.delegatecall(_data);
      require(success);
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import './BaseAdminUpgradeabilityProxy.sol';
import './InitializableUpgradeabilityProxy.sol';

/**
 * @title InitializableAdminUpgradeabilityProxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * Extends from BaseAdminUpgradeabilityProxy with an initializer for
 * initializing the implementation, admin, and init data.
 */
contract InitializableAdminUpgradeabilityProxy is
  BaseAdminUpgradeabilityProxy,
  InitializableUpgradeabilityProxy
{
  /**
   * Contract initializer.
   * @param _logic address of the initial implementation.
   * @param _admin Address of the proxy administrator.
   * @param _data Data to send as msg.data to the implementation to initialize the proxied contract.
   * It should include the signature and the parameters of the function to be called, as described in
   * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
   * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
   */
  function initialize(
    address _logic,
    address _admin,
    bytes memory _data
  ) public payable {
    require(_implementation() == address(0));
    InitializableUpgradeabilityProxy.initialize(_logic, _data);
    assert(ADMIN_SLOT == bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1));
    _setAdmin(_admin);
  }

  /**
   * @dev Only fall back when the sender is not the admin.
   */
  function _willFallback() internal override(BaseAdminUpgradeabilityProxy, Proxy) {
    BaseAdminUpgradeabilityProxy._willFallback();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import './UpgradeabilityProxy.sol';

/**
 * @title BaseAdminUpgradeabilityProxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * This contract combines an upgradeability proxy with an authorization
 * mechanism for administrative tasks.
 * All external functions in this contract must be guarded by the
 * `ifAdmin` modifier. See ethereum/solidity#3864 for a Solidity
 * feature proposal that would enable this to be done automatically.
 */
contract BaseAdminUpgradeabilityProxy is BaseUpgradeabilityProxy {
  /**
   * @dev Emitted when the administration has been transferred.
   * @param previousAdmin Address of the previous admin.
   * @param newAdmin Address of the new admin.
   */
  event AdminChanged(address previousAdmin, address newAdmin);

  /**
   * @dev Storage slot with the admin of the contract.
   * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
   * validated in the constructor.
   */

  bytes32 internal constant ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /**
   * @dev Modifier to check whether the `msg.sender` is the admin.
   * If it is, it will run the function. Otherwise, it will delegate the call
   * to the implementation.
   */
  modifier ifAdmin() {
    if (msg.sender == _admin()) {
      _;
    } else {
      _fallback();
    }
  }

  /**
   * @return The address of the proxy admin.
   */
  function admin() external ifAdmin returns (address) {
    return _admin();
  }

  /**
   * @return The address of the implementation.
   */
  function implementation() external ifAdmin returns (address) {
    return _implementation();
  }

  /**
   * @dev Changes the admin of the proxy.
   * Only the current admin can call this function.
   * @param newAdmin Address to transfer proxy administration to.
   */
  function changeAdmin(address newAdmin) external ifAdmin {
    require(newAdmin != address(0), 'Cannot change the admin of a proxy to the zero address');
    emit AdminChanged(_admin(), newAdmin);
    _setAdmin(newAdmin);
  }

  /**
   * @dev Upgrade the backing implementation of the proxy.
   * Only the admin can call this function.
   * @param newImplementation Address of the new implementation.
   */
  function upgradeTo(address newImplementation) external ifAdmin {
    _upgradeTo(newImplementation);
  }

  /**
   * @dev Upgrade the backing implementation of the proxy and call a function
   * on the new implementation.
   * This is useful to initialize the proxied contract.
   * @param newImplementation Address of the new implementation.
   * @param data Data to send as msg.data in the low level call.
   * It should include the signature and the parameters of the function to be called, as described in
   * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
   */
  function upgradeToAndCall(address newImplementation, bytes calldata data)
    external
    payable
    ifAdmin
  {
    _upgradeTo(newImplementation);
    (bool success, ) = newImplementation.delegatecall(data);
    require(success);
  }

  /**
   * @return adm The admin slot.
   */
  function _admin() internal view returns (address adm) {
    bytes32 slot = ADMIN_SLOT;
    assembly {
      adm := sload(slot)
    }
  }

  /**
   * @dev Sets the address of the proxy admin.
   * @param newAdmin Address of the new proxy admin.
   */
  function _setAdmin(address newAdmin) internal {
    bytes32 slot = ADMIN_SLOT;

    assembly {
      sstore(slot, newAdmin)
    }
  }

  /**
   * @dev Only fall back when the sender is not the admin.
   */
  function _willFallback() internal virtual override {
    require(msg.sender != _admin(), 'Cannot call fallback function from the proxy admin');
    super._willFallback();
  }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;

import './BaseUpgradeabilityProxy.sol';

/**
 * @title UpgradeabilityProxy
 * @dev From https://github.com/OpenZeppelin/openzeppelin-sdk/tree/solc-0.6/packages/lib/contracts/upgradeability
 * Extends BaseUpgradeabilityProxy with a constructor for initializing
 * implementation and init data.
 */
contract UpgradeabilityProxy is BaseUpgradeabilityProxy {
  /**
   * @dev Contract constructor.
   * @param _logic Address of the initial implementation.
   * @param _data Data to send as msg.data to the implementation to initialize the proxied contract.
   * It should include the signature and the parameters of the function to be called, as described in
   * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
   * This parameter is optional, if no data is given the initialization call to proxied contract will be skipped.
   */
  constructor(address _logic, bytes memory _data) public payable {
    assert(IMPLEMENTATION_SLOT == bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1));
    _setImplementation(_logic);
    if (_data.length > 0) {
      (bool success, ) = _logic.delegatecall(_data);
      require(success);
    }
  }
}

import '@aave/aave-stake/contracts/lib/InitializableAdminUpgradeabilityProxy.sol';

pragma solidity 0.7.5;

import {IStakedTokenWithConfig} from '../interfaces/IStakedTokenWithConfig.sol';
import {IERC20} from '@aave/aave-stake/contracts/interfaces/IERC20.sol';

contract StakeMock is IStakedTokenWithConfig {
  address public immutable override STAKED_TOKEN;

  constructor(address stakedToken) {
    STAKED_TOKEN = stakedToken;
  }

  function stake(address to, uint256 amount) external override {
      IERC20(STAKED_TOKEN).transferFrom(msg.sender, address(this), amount);
  }

  function redeem(address to, uint256 amount) external override {}

  function cooldown() external override {}

  function claimRewards(address to, uint256 amount) external override {}
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.7.5;
pragma experimental ABIEncoderV2;

import {IERC20} from '../interfaces/IERC20.sol';
import {StakedTokenV3} from './StakedTokenV3.sol';

/**
 * @title StakedAaveV3
 * @notice StakedTokenV3 with AAVE token as staked token
 * @author Aave
 **/
contract StakedAaveV3 is StakedTokenV3 {
  string internal constant NAME = 'Staked Aave';
  string internal constant SYMBOL = 'stkAAVE';
  uint8 internal constant DECIMALS = 18;

  constructor(
    IERC20 stakedToken,
    IERC20 rewardToken,
    uint256 cooldownSeconds,
    uint256 unstakeWindow,
    address rewardsVault,
    address emissionManager,
    uint128 distributionDuration,
    address governance
  )
    public
    StakedTokenV3(
      stakedToken,
      rewardToken,
      cooldownSeconds,
      unstakeWindow,
      rewardsVault,
      emissionManager,
      distributionDuration,
      NAME,
      SYMBOL,
      DECIMALS,
      governance
    )
  {}
}

import '@aave/aave-stake/contracts/stake/StakedAaveV3.sol';