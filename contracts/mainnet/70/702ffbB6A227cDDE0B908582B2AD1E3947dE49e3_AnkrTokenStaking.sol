// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

interface IGovernable {

    function getGovernanceAddress() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "./IStakingConfig.sol";

interface IStaking {

    function getStakingConfig() external view returns (IStakingConfig);

    function getValidators() external view returns (address[] memory);

//    function isValidatorActive(address validator) external view returns (bool);

    function isValidator(address validator) external view returns (bool);

    function getValidatorStatus(address validator) external view returns (
        address ownerAddress,
        uint8 status,
        uint256 totalDelegated,
        uint32 slashesCount,
        uint64 changedAt,
        uint64 jailedBefore,
        uint64 claimedAt,
        uint16 commissionRate,
        uint96 totalRewards
    );

    function getValidatorStatusAtEpoch(address validator, uint64 epoch) external view returns (
        address ownerAddress,
        uint8 status,
        uint256 totalDelegated,
        uint32 slashesCount,
        uint64 changedAt,
        uint64 jailedBefore,
        uint64 claimedAt,
        uint16 commissionRate,
        uint96 totalRewards
    );

//    function getValidatorByOwner(address owner) external view returns (address);

    function registerValidator(address validator, uint16 commissionRate, uint256 amount) payable external;

    function addValidator(address validator) external;

    function activateValidator(address validator) external;

//    function disableValidator(address validator) external;

//    function releaseValidatorFromJail(address validator) external;

    function changeValidatorCommissionRate(address validator, uint16 commissionRate) external;

    function changeValidatorOwner(address validator, address newOwner) external;

    function getValidatorDelegation(address validator, address delegator) external view returns (
        uint256 delegatedAmount,
        uint64 atEpoch
    );

    function delegate(address validator, uint256 amount) payable external;

    function undelegate(address validator, uint256 amount) external;

    function getValidatorFee(address validator) external view returns (uint256);

    function getPendingValidatorFee(address validator) external view returns (uint256);

    function claimValidatorFee(address validator) external;

    function getDelegatorFee(address validator, address delegator) external view returns (uint256);

    function getPendingDelegatorFee(address validator, address delegator) external view returns (uint256);

    function claimDelegatorFee(address validator) external;

    function claimStakingRewards(address validatorAddress) external;

    function claimPendingUndelegates(address validator) external;

    function calcAvailableForRedelegateAmount(address validator, address delegator) external view returns (uint256 amountToStake, uint256 rewardsDust);

    function calcAvailableForDelegateAmount(uint256 amount) external view returns (uint256 amountToStake, uint256 dust);

    function redelegateDelegatorFee(address validator) external;

    function currentEpoch() external view returns (uint64);

    function nextEpoch() external view returns (uint64);
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "./IGovernable.sol";

interface IStakingConfig is IGovernable {

    function getActiveValidatorsLength() external view returns (uint32);

    function setActiveValidatorsLength(uint32 newValue) external;

    function getEpochBlockInterval() external view returns (uint32);

    function setEpochBlockInterval(uint32 newValue) external;

    function getMisdemeanorThreshold() external view returns (uint32);

    function setMisdemeanorThreshold(uint32 newValue) external;

    function getFelonyThreshold() external view returns (uint32);

    function setFelonyThreshold(uint32 newValue) external;

    function getValidatorJailEpochLength() external view returns (uint32);

    function setValidatorJailEpochLength(uint32 newValue) external;

    function getUndelegatePeriod() external view returns (uint32);

    function setUndelegatePeriod(uint32 newValue) external;

    function getMinValidatorStakeAmount() external view returns (uint256);

    function setMinValidatorStakeAmount(uint256 newValue) external;

    function getMinStakingAmount() external view returns (uint256);

    function setMinStakingAmount(uint256 newValue) external;

    function getGovernanceAddress() external view override returns (address);

    function setGovernanceAddress(address newValue) external;

    function getTreasuryAddress() external view returns (address);

    function setTreasuryAddress(address newValue) external;

    function getLockPeriod() external view returns (uint64);

    function setLockPeriod(uint64 newValue) external;
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IStaking.sol";

interface ITokenStaking is IStaking {

    function getErc20Token() external view returns (IERC20);

    function distributeRewards(address validatorAddress, uint256 amount) external;
}

pragma solidity ^0.8.0;

struct DelegationOpDelegate {
    // @dev stores the last sum(delegated)-sum(undelegated)
    uint112 amount;
    uint64 epoch;
    // last epoch when reward was claimed
    uint64 claimEpoch;
}

struct DelegationOpUndelegate {
    uint112 amount;
    uint64 epoch;
}

struct ValidatorDelegation {
    DelegationOpDelegate[] delegateQueue;
    uint64 delegateGap;
    DelegationOpUndelegate[] undelegateQueue;
    uint64 undelegateGap;
    uint112 withdrawnAmount;
    uint64 withdrawnEpoch;
}

library DelegationUtil {

    function add(
        ValidatorDelegation storage self,
        uint112 amount,
        uint64 epoch
    ) internal {
        // if last pending delegate has the same next epoch then its safe to just increase total
        // staked amount because it can't affect current validator set, but otherwise we must create
        // new record in delegation queue with the last epoch (delegations are ordered by epoch)
        if (self.delegateQueue.length > 0) {
            DelegationOpDelegate storage recentDelegateOp = self.delegateQueue[self.delegateQueue.length - 1];
            // if we already have pending snapshot for the next epoch then just increase new amount,
            // otherwise create next pending snapshot. (tbh it can't be greater, but what we can do here instead?)
            if (recentDelegateOp.epoch >= epoch) {
                recentDelegateOp.amount += amount;
            } else {
                self.delegateQueue.push(DelegationOpDelegate({epoch : epoch, claimEpoch : epoch, amount : recentDelegateOp.amount + amount}));
            }
        } else {
            // there is no any delegations at al, lets create the first one
            self.delegateQueue.push(DelegationOpDelegate({epoch : epoch, claimEpoch : epoch, amount : amount}));
        }
    }

    function addInitial(
        ValidatorDelegation storage self,
        uint112 amount,
        uint64 epoch
    ) internal {
        require(self.delegateQueue.length == 0, "Delegation: already delegated");
        self.delegateQueue.push(DelegationOpDelegate({amount : amount, epoch: epoch, claimEpoch : epoch}));
    }

    // @dev before call check that queue is not empty
    function shrinkDelegations(
        ValidatorDelegation storage self,
        uint112 amount,
        uint64 epoch
    ) internal {
        // pull last item
        DelegationOpDelegate storage recentDelegateOp = self.delegateQueue[self.delegateQueue.length - 1];
        // calc next delegated amount
        uint112 nextDelegatedAmount = recentDelegateOp.amount - amount;
        if (nextDelegatedAmount == 0) {
            delete self.delegateQueue[self.delegateQueue.length - 1];
            self.delegateGap++;
        } else if (recentDelegateOp.epoch >= epoch) {
            // decrease total delegated amount for the next epoch
            recentDelegateOp.amount = nextDelegatedAmount;
        } else {
            // there is no pending delegations, so lets create the new one with the new amount
            self.delegateQueue.push(DelegationOpDelegate({epoch : epoch, claimEpoch: epoch, amount : nextDelegatedAmount}));
        }
        // stash withdrawn amount
        if (epoch > self.withdrawnEpoch) {
            self.withdrawnEpoch = epoch;
            self.withdrawnAmount = amount;
        } else if (epoch == self.withdrawnEpoch) {
            self.withdrawnAmount += amount;
        }
    }

    function getWithdrawn(
        ValidatorDelegation memory self,
        uint64 epoch
    ) internal pure returns (uint112) {
        return epoch >= self.withdrawnEpoch ? 0 : self.withdrawnAmount;
    }

    function calcWithdrawalAmount(ValidatorDelegation memory self, uint64 beforeEpochExclude, bool checkEpoch) internal pure returns (uint256 amount) {
        while (self.undelegateGap < self.undelegateQueue.length) {
            DelegationOpUndelegate memory undelegateOp = self.undelegateQueue[self.undelegateGap];
            if (checkEpoch && undelegateOp.epoch > beforeEpochExclude) {
                break;
            }
            amount += uint256(undelegateOp.amount);
            ++self.undelegateGap;
        }
    }

//    function getStaked(ValidatorDelegation memory self) internal pure returns (uint256) {
//        return self.delegateQueue[self.delegateQueue.length - 1].amount;
//    }

}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

contract Multicall {

    function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            // this is an optimized a bit multicall w/o using of Address library (it safes a lot of bytecode)
            results[i] = _fastDelegateCall(data[i]);
        }
        return results;
    }

    function _fastDelegateCall(bytes memory data) private returns (bytes memory _result) {
        (bool success, bytes memory returnData) = address(this).delegatecall(data);
        if (success) {
            return returnData;
        }
        if (returnData.length > 0) {
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        } else {
            revert();
        }
    }
}

pragma solidity ^0.8.0;

struct ValidatorSnapshot {
    uint96 totalRewards;
    uint112 totalDelegated;
    uint32 slashesCount;
    uint16 commissionRate;
}

library SnapshotUtil {

    // @dev ownerFee_(18+4-4=18) = totalRewards_18 * commissionRate_4 / 1e4
    function getOwnerFee(ValidatorSnapshot memory self) internal pure returns (uint256) {
        return uint256(self.totalRewards) * self.commissionRate / 1e4;
    }

    function create(
        ValidatorSnapshot storage self,
        uint112 initialStake,
        uint16 commissionRate
    ) internal {
        self.totalRewards = 0;
        self.totalDelegated = initialStake;
        self.slashesCount = 0;
        self.commissionRate = commissionRate;
    }

//    function slash(ValidatorSnapshot storage self) internal returns (uint32) {
//        self.slashesCount += 1;
//        return self.slashesCount;
//    }

    function safeDecreaseDelegated(
        ValidatorSnapshot storage self,
        uint112 amount
    ) internal {
        require(self.totalDelegated >= amount, "ValidatorSnapshot: insufficient balance");
        self.totalDelegated -= amount;
    }
}

pragma solidity ^0.8.0;

enum ValidatorStatus {
    NotFound,
    Active,
    Pending,
    Jail
}

struct Validator {
    address validatorAddress;
    address ownerAddress;
    ValidatorStatus status;
    uint64 changedAt;
    uint64 jailedBefore;
    uint64 claimedAt;
}

library ValidatorUtil {

    function isActive(Validator memory self) internal pure returns (bool) {
        return self.status == ValidatorStatus.Active;
    }

    function isOwner(
        Validator memory self,
        address addr
    ) internal pure returns (bool) {
        return self.ownerAddress == addr;
    }

    function create(
        Validator storage self,
        address validatorAddress,
        address validatorOwner,
        ValidatorStatus status,
        uint64 epoch
    ) internal {
        require(self.status == ValidatorStatus.NotFound, "Validator: already exist");
        self.validatorAddress = validatorAddress;
        self.ownerAddress = validatorOwner;
        self.status = status;
        self.changedAt = epoch;
    }

    function activate(
        Validator storage self
    ) internal returns (Validator memory vldtr) {
        require(self.status == ValidatorStatus.Pending, "Validator: bad status");
        self.status = ValidatorStatus.Active;
        return self;
    }

    function disable(
        Validator storage self
    ) internal returns (Validator memory vldtr) {
        require(self.status == ValidatorStatus.Active || self.status == ValidatorStatus.Jail, "Validator: bad status");
        self.status = ValidatorStatus.Pending;
        return self;
    }

//    function jail(
//        Validator storage self,
//        uint64 beforeEpoch
//    ) internal {
//        require(self.status != ValidatorStatus.NotFound, "Validator: not found");
//        self.jailedBefore = beforeEpoch;
//        self.status = ValidatorStatus.Jail;
//    }

//    function unJail(
//        Validator storage self,
//        uint64 epoch
//    ) internal {
//        // make sure validator is in jail
//        require(self.status == ValidatorStatus.Jail, "Validator: bad status");
//        // only validator owner
//        require(msg.sender == self.ownerAddress, "Validator: only owner");
//        require(epoch >= self.jailedBefore, "Validator: still in jail");
//        forceUnJail(self);
//    }

    // @dev release validator from jail
//    function forceUnJail(
//        Validator storage self
//    ) internal {
//        // update validator status
//        self.status = ValidatorStatus.Active;
//        self.jailedBefore = 0;
//    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "../staking/extension/TokenStaking.sol";
import "../staking/StakingConfig.sol";

contract AnkrTokenStaking is TokenStaking {

    function initialize(IStakingConfig stakingConfig, IERC20 ankrToken) external initializer {
        __TokenStaking_init(stakingConfig, ankrToken);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../libs/Multicall.sol";
import "../libs/ValidatorUtil.sol";
import "../libs/SnapshotUtil.sol";
import "../libs/DelegationUtil.sol";

import "../interfaces/IStakingConfig.sol";
import "../interfaces/IStaking.sol";

abstract contract Staking is Initializable, Multicall, IStaking {

    using ValidatorUtil for Validator;
    using SnapshotUtil for ValidatorSnapshot;
    using DelegationUtil for ValidatorDelegation;

    /**
     * This constant indicates precision of storing compact balances in the storage or floating point. Since default
     * balance precision is 256 bits it might gain some overhead on the storage because we don't need to store such huge
     * amount range. That is why we compact balances in uint112 values instead of uint256. By managing this value
     * you can set the precision of your balances, aka min and max possible staking amount. This value depends
     * mostly on your asset price in USD, for example ETH costs 4000$ then if we use 1 ether precision it takes 4000$
     * as min amount that might be problematic for users to do the stake. We can set 1 gwei precision and in this case
     * we increase min staking amount in 1e9 times, but also decreases max staking amount or total amount of staked assets.
     *
     * Here is an universal formula, if your asset is cheap in USD equivalent, like ~1$, then use 1 ether precision,
     * otherwise it might be better to use 1 gwei precision or any other amount that your want.
     *
     * Also be careful with setting `minValidatorStakeAmount` and `minStakingAmount`, because these values has
     * the same precision as specified here. It means that if you set precision 1 ether, then min staking amount of 10
     * tokens should have 10 raw value. For 1 gwei precision 10 tokens min amount should be stored as 10000000000.
     *
     * For the 112 bits we have ~32 decimals lg(2**112)=33.71 (lets round to 32 for simplicity). We split this amount
     * into integer (24) and for fractional (8) parts. It means that we can have only 8 decimals after zero.
     *
     * Based in current params we have next min/max values:
     * - min staking amount: 0.00000001 or 1e-8
     * - max staking amount: 1000000000000000000000000 or 1e+24
     *
     * WARNING: precision must be a 1eN format (A=1, N>0)
     */
    uint256 internal constant BALANCE_COMPACT_PRECISION = 1e10;
    /**
     * Here is min/max commission rates. Lets don't allow to set more than 30% of validator commission, because it's
     * too big commission for validator. Commission rate is a percents divided by 100 stored with 0 decimals as percents*100 (=pc/1e2*1e4)
     *
     * Here is some examples:
     * + 0.3% => 0.3*100=30
     * + 3% => 3*100=300
     * + 30% => 30*100=3000
     */
    uint16 internal constant COMMISSION_RATE_MIN_VALUE = 0; // 0%
    uint16 internal constant COMMISSION_RATE_MAX_VALUE = 3000; // 30%
    /**
     * This gas limit is used for internal transfers, BSC doesn't support berlin and it
     * might cause problems with smart contracts who used to stake transparent proxies or
     * beacon proxies that have a lot of expensive SLOAD instructions.
     */
    uint64 internal constant TRANSFER_GAS_LIMIT = 30_000;
    /**
     * Some items are stored in the queues and we must iterate though them to
     * execute one by one. Somtimes gas might not be enough for the tx execution.
     */
    uint32 internal constant CLAIM_BEFORE_GAS = 100_000;

    // validator events
    event ValidatorAdded(address indexed validator, address owner, uint8 status, uint16 commissionRate);
    event ValidatorModified(address indexed validator, address owner, uint8 status, uint16 commissionRate);
    event ValidatorRemoved(address indexed validator);
    event ValidatorOwnerClaimed(address indexed validator, uint256 amount, uint64 epoch);
    event ValidatorSlashed(address indexed validator, uint32 slashes, uint64 epoch);
    event ValidatorJailed(address indexed validator, uint64 epoch);
    event ValidatorDeposited(address indexed validator, uint256 amount, uint64 epoch);
    event ValidatorReleased(address indexed validator, uint64 epoch);

    // staker events
    event Delegated(address indexed validator, address indexed staker, uint256 amount, uint64 epoch);
    event Undelegated(address indexed validator, address indexed staker, uint256 amount, uint64 epoch);
    event Claimed(address indexed validator, address indexed staker, uint256 amount, uint64 epoch);
    event Redelegated(address indexed validator, address indexed staker, uint256 amount, uint256 dust, uint64 epoch);

    // mapping from validator address to validator
    mapping(address => Validator) internal _validatorsMap;
    // mapping from validator owner to validator address
    mapping(address => address) internal _validatorOwners;
    // list of all validators that are in validators mapping
    address[] internal _activeValidatorsList;
    // mapping with stakers to validators at epoch (validator -> delegator -> delegation)
    mapping(address => mapping(address => ValidatorDelegation)) internal _validatorDelegations;
    // mapping with validator snapshots per each epoch (validator -> epoch -> snapshot)
    mapping(address => mapping(uint64 => ValidatorSnapshot)) internal _validatorSnapshots;
    // chain config with params
    IStakingConfig internal _stakingConfig;
    // reserve some gap for the future upgrades
    uint256[100 - 7] private __reserved;

    function __Staking_init(IStakingConfig stakingConfig) internal {
        _stakingConfig = stakingConfig;
    }

    modifier onlyFromGovernance() virtual {
        require(msg.sender == _stakingConfig.getGovernanceAddress(), "Staking: only governance");
        _;
    }

    function getStakingConfig() external view override returns (IStakingConfig) {
        return _stakingConfig;
    }

    function getValidatorDelegation(address validatorAddress, address delegator) external view override returns (
        uint256 delegatedAmount,
        uint64 atEpoch
    ) {
        ValidatorDelegation memory delegation = _validatorDelegations[validatorAddress][delegator];
        if (delegation.delegateQueue.length == 0) {
            return (0, 0);
        }
        DelegationOpDelegate memory snapshot = delegation.delegateQueue[delegation.delegateQueue.length - 1];
        return (uint256(snapshot.amount) * BALANCE_COMPACT_PRECISION, snapshot.epoch);
    }

    function getDelegateQueue(address validator, address delegator) public view returns(DelegationOpDelegate[] memory queue) {
        ValidatorDelegation memory delegation = _validatorDelegations[validator][delegator];
        uint256 length = delegation.delegateQueue.length;
        uint256 gap = delegation.delegateGap;
        queue = new DelegationOpDelegate[](length - gap);
        for(uint256 i; gap < length;) {
            DelegationOpDelegate memory op = delegation.delegateQueue[gap++];
            op.amount -= delegation.getWithdrawn(op.epoch);
            queue[i++] = op;
        }
    }

    function getValidatorStatus(address validatorAddress) external view override returns (
        address ownerAddress,
        uint8 status,
        uint256 totalDelegated,
        uint32 slashesCount,
        uint64 changedAt,
        uint64 jailedBefore,
        uint64 claimedAt,
        uint16 commissionRate,
        uint96 totalRewards
    ) {
        Validator memory validator = _validatorsMap[validatorAddress];
        ValidatorSnapshot memory snapshot = _validatorSnapshots[validator.validatorAddress][validator.changedAt];
        return (
        ownerAddress = validator.ownerAddress,
        status = uint8(validator.status),
        totalDelegated = uint256(snapshot.totalDelegated) * BALANCE_COMPACT_PRECISION,
        slashesCount = snapshot.slashesCount,
        changedAt = validator.changedAt,
        jailedBefore = validator.jailedBefore,
        claimedAt = validator.claimedAt,
        commissionRate = snapshot.commissionRate,
        totalRewards = snapshot.totalRewards
        );
    }

    function getValidatorStatusAtEpoch(address validatorAddress, uint64 epoch) external view override returns (
        address ownerAddress,
        uint8 status,
        uint256 totalDelegated,
        uint32 slashesCount,
        uint64 changedAt,
        uint64 jailedBefore,
        uint64 claimedAt,
        uint16 commissionRate,
        uint96 totalRewards
    ) {
        Validator memory validator = _validatorsMap[validatorAddress];
        ValidatorSnapshot memory snapshot = _touchValidatorSnapshotImmutable(validator, epoch);
        return (
        ownerAddress = validator.ownerAddress,
        status = uint8(validator.status),
        totalDelegated = uint256(snapshot.totalDelegated) * BALANCE_COMPACT_PRECISION,
        slashesCount = snapshot.slashesCount,
        changedAt = validator.changedAt,
        jailedBefore = validator.jailedBefore,
        claimedAt = validator.claimedAt,
        commissionRate = snapshot.commissionRate,
        totalRewards = snapshot.totalRewards
        );
    }

//    function getValidatorByOwner(address owner) external view override returns (address) {
//        return _validatorOwners[owner];
//    }

//    function releaseValidatorFromJail(address validatorAddress) external override {
//        Validator storage validator = _validatorsMap[validatorAddress];
//        validator.unJail(currentEpoch());
//        _releaseValidatorFromJail(validator);
//    }

//    function forceUnJailValidator(address validatorAddress) external onlyFromGovernance {
//        Validator storage validator = _validatorsMap[validatorAddress];
//        validator.forceUnJail();
//        _releaseValidatorFromJail(validator);
//    }

//    function _releaseValidatorFromJail(Validator storage validator) internal {
//        address validatorAddress = validator.validatorAddress;
//        _activeValidatorsList.push(validatorAddress);
//        // emit event
//        emit ValidatorReleased(validatorAddress, currentEpoch());
//    }

    function undelegate(address validatorAddress, uint256 amount) external override {
        _undelegateFrom(msg.sender, validatorAddress, amount);
    }

    function currentEpoch() public view override returns (uint64) {
        return uint64(block.number / _stakingConfig.getEpochBlockInterval());
    }

    function nextEpoch() public view override returns (uint64) {
        return currentEpoch() + 1;
    }

    function _touchValidatorSnapshot(Validator storage validator, uint64 epoch) internal returns (ValidatorSnapshot storage) {
        ValidatorSnapshot storage snapshot = _validatorSnapshots[validator.validatorAddress][epoch];
        // if snapshot is already initialized then just return it
        if (snapshot.totalDelegated > 0) {
            return snapshot;
        }
        // find previous snapshot to copy parameters from it
        ValidatorSnapshot memory lastModifiedSnapshot = _validatorSnapshots[validator.validatorAddress][validator.changedAt];
        // last modified snapshot might store zero value, for first delegation it might happen and its not critical
        snapshot.totalDelegated = lastModifiedSnapshot.totalDelegated;
        snapshot.commissionRate = lastModifiedSnapshot.commissionRate;
        // we must save last affected epoch for this validator to be able to restore total delegated
        // amount in the future (check condition upper)
        if (epoch > validator.changedAt) {
            validator.changedAt = epoch;
        }
        return snapshot;
    }

    function _touchValidatorSnapshotImmutable(Validator memory validator, uint64 epoch) internal view returns (ValidatorSnapshot memory) {
        ValidatorSnapshot memory snapshot = _validatorSnapshots[validator.validatorAddress][epoch];
        // if snapshot is already initialized then just return it
        if (snapshot.totalDelegated > 0) {
            return snapshot;
        }
        // find previous snapshot to copy parameters from it
        ValidatorSnapshot memory lastModifiedSnapshot = _validatorSnapshots[validator.validatorAddress][validator.changedAt];
        // last modified snapshot might store zero value, for first delegation it might happen and its not critical
        snapshot.totalDelegated = lastModifiedSnapshot.totalDelegated;
        snapshot.commissionRate = lastModifiedSnapshot.commissionRate;
        // return existing or new snapshot
        return snapshot;
    }

    function _delegateTo(address fromDelegator, address toValidator, uint256 amount, bool checkMinStakingAmount) internal {
        // check is minimum delegate amount
        require((!checkMinStakingAmount || amount >= _stakingConfig.getMinStakingAmount()) && amount != 0, "too low");
        require(amount % BALANCE_COMPACT_PRECISION == 0, "no remainder");
        uint112 compactAmount = uint112(amount / BALANCE_COMPACT_PRECISION);
        // make sure amount is greater than min staking amount
        // make sure validator exists at least
        Validator storage validator = _validatorsMap[toValidator];
        require(validator.status != ValidatorStatus.NotFound, "not found");
        uint64 sinceEpoch = nextEpoch();
        // Lets upgrade next snapshot parameters:
        // + find snapshot for the next epoch after current block
        // + increase total delegated amount in the next epoch for this validator
        // + re-save validator because last affected epoch might change
        ValidatorSnapshot storage validatorSnapshot = _touchValidatorSnapshot(validator, sinceEpoch);
        validatorSnapshot.totalDelegated += compactAmount;
        _validatorDelegations[toValidator][fromDelegator].add(compactAmount, sinceEpoch);
        // emit event with the next epoch
        emit Delegated(toValidator, fromDelegator, amount, sinceEpoch);
    }

    function calcUnlockedDelegatedAmount(address validator, address delegator) public view returns (uint256) {
        ValidatorDelegation memory delegation = _validatorDelegations[validator][delegator];
        uint256 unlockedAmount = _calcUnlockedDelegatedAmount(delegation);
        if (unlockedAmount < type(uint256).max || delegation.delegateQueue.length == 0) {
            return unlockedAmount;
        }
        DelegationOpDelegate memory latestDelegate = delegation.delegateQueue[delegation.delegateQueue.length - 1];
        return uint256(latestDelegate.amount) * BALANCE_COMPACT_PRECISION;
    }

    // @dev find actual unlocked amount and extract rewards available for claim
    function _processUnlockedDelegations(
        ValidatorDelegation storage delegation,
        uint64 beforeEpochExclude,
        address delegator,
        address validator,
        uint256 expectedAmount
    ) internal {
        uint64 lockPeriod = _stakingConfig.getLockPeriod();
        uint256 claimableAmount;
        uint112 unlockedAmount;

        // calc last unlocked amount
        for (; delegation.delegateGap < delegation.delegateQueue.length; delegation.delegateGap++) {
            DelegationOpDelegate memory delegateOp = delegation.delegateQueue[delegation.delegateGap];

            // if lock period zero epoch doesn't matter
            if (delegateOp.epoch + lockPeriod < beforeEpochExclude || lockPeriod == 0) {
                // save last unlockedAmount
                unlockedAmount = delegateOp.amount - delegation.getWithdrawn(delegateOp.epoch);
                // extract rewards from delegation before currentEpoch
                (uint256 extracted, uint64 claimEpoch ) = _extractClaimable(delegation, delegation.delegateGap, validator, beforeEpochExclude - 1);
                claimableAmount += extracted;

                // should keep at least one item in queue and update last claimEpoch
                if (delegation.delegateGap == delegation.delegateQueue.length - 1) {
                    delegation.delegateQueue[delegation.delegateGap].claimEpoch = claimEpoch;
                    break;
                } else {
                    delete delegation.delegateQueue[delegation.delegateGap];
                }
            } else {
                break;
            }
        }
        // check that expected amount is unlocked
        // unlocked amount less than zero means that array are empty and shrink will not be called
        require(unlockedAmount == expectedAmount, "still locked");
        // substract expected amount from last item
        delegation.shrinkDelegations(unlockedAmount, beforeEpochExclude);
        // send extracted reward
        if (claimableAmount > 0) {
            _safeTransferWithGasLimit(payable(delegator), claimableAmount);
            emit Claimed(validator, delegator, claimableAmount, beforeEpochExclude);
        }
    }

    function _calcUnlockedDelegatedAmount(ValidatorDelegation memory delegation) internal view returns (uint256 unlockedAmount) {
        uint64 beforeEpochExclude = nextEpoch();
        // if lock period is zero than this feature is disabled
        uint64 lockPeriod = _stakingConfig.getLockPeriod();
        if (lockPeriod == 0) return type(uint256).max;
        // calc last unlocked amount
        for (uint256 i = delegation.delegateGap; i < delegation.delegateQueue.length; i++) {
            DelegationOpDelegate memory delegateOp = delegation.delegateQueue[i];
            if (delegateOp.epoch + lockPeriod < beforeEpochExclude) {
                unlockedAmount = uint256(delegateOp.amount - delegation.getWithdrawn(delegateOp.epoch)) * BALANCE_COMPACT_PRECISION;
            }
        }
        return unlockedAmount;
    }

    function _undelegateFrom(address toDelegator, address fromValidator, uint256 amount) internal {
        // check minimum delegate amount
        require(amount >= _stakingConfig.getMinStakingAmount() && amount != 0, "too low");
        require(amount % BALANCE_COMPACT_PRECISION == 0, "no remainder");
        uint112 undelegateAm = uint112(amount / BALANCE_COMPACT_PRECISION);
        // make sure validator exists at least
        Validator storage validator = _validatorsMap[fromValidator];
        uint64 beforeEpoch = nextEpoch();
        // Lets upgrade next snapshot parameters:
        // + find snapshot for the next epoch after current block
        // + decrease total delegated amount in the next epoch for this validator
        // + re-save validator because last affected epoch might change
        _touchValidatorSnapshot(validator, beforeEpoch).safeDecreaseDelegated(undelegateAm);
        // if last pending delegate has the same next epoch then its safe to just decrease total
        // staked amount because it can't affect current validator set, but otherwise we must create
        // new record in delegation queue with the last epoch (delegations are ordered by epoch)
        ValidatorDelegation storage delegation = _validatorDelegations[fromValidator][toDelegator];
        require(delegation.delegateQueue.length > 0, "insufficient balance");
        DelegationOpDelegate memory recentDelegateOp = delegation.delegateQueue[delegation.delegateQueue.length - 1];
        require(recentDelegateOp.amount >= undelegateAm, "insufficient balance");
        // disallow to undelegate if lock period is not reached yet (make sure we don't have pending undelegates)
        //_transferDelegatorRewards(fromValidator, toDelegator, beforeEpoch, false, true);
        _processUnlockedDelegations(delegation, beforeEpoch, toDelegator, fromValidator, undelegateAm);
        // create new undelegate queue operation with soft lock
        delegation.undelegateQueue.push(DelegationOpUndelegate({amount : undelegateAm, epoch : beforeEpoch + _stakingConfig.getUndelegatePeriod()}));
        // emit event with the next epoch number
        emit Undelegated(fromValidator, toDelegator, amount, beforeEpoch);
    }

    function _transferDelegatorRewards(address validator, address delegator, uint64 beforeEpochExclude, bool withRewards, bool withUndelegates) internal {
        // claim rewards and undelegates
        uint256 availableFunds = _processQueues(validator, delegator, beforeEpochExclude, withRewards, withUndelegates);
        // for transfer claim mode just all rewards to the user
        _safeTransferWithGasLimit(payable(delegator), availableFunds);
        // emit event
        emit Claimed(validator, delegator, availableFunds, beforeEpochExclude);
    }

    function _redelegateDelegatorRewards(address validator, address delegator, uint64 beforeEpochExclude, bool withRewards, bool withUndelegates) internal {
        // claim rewards and undelegates
        uint256 availableFunds = _processQueues(validator, delegator, beforeEpochExclude, withRewards, withUndelegates);
        (uint256 amountToStake, uint256 rewardsDust) = calcAvailableForDelegateAmount(availableFunds);
        // if we have something to re-stake then delegate it to the validator
        if (amountToStake > 0) {
            _delegateTo(delegator, validator, amountToStake, false);
        }
        // if we have dust from staking then send it to user (we can't keep them in the contract)
        if (rewardsDust > 0) {
            _safeTransferWithGasLimit(payable(delegator), rewardsDust);
        }
        // emit event
        emit Redelegated(validator, delegator, amountToStake, rewardsDust, beforeEpochExclude);
    }

    function _processQueues(address validator, address delegator, uint64 beforeEpochExclude, bool withRewards, bool withUndelegates) internal returns (uint256 availableFunds) {
        ValidatorDelegation storage delegation = _validatorDelegations[validator][delegator];
        if (withRewards) {
            availableFunds += _processDelegateQueue(validator, delegation, beforeEpochExclude);
        }
        if (withUndelegates) {
            availableFunds += _processUndelegateQueue(delegation, beforeEpochExclude);
        }
    }

    function _processDelegateQueue(address validator, ValidatorDelegation storage delegation, uint64 beforeEpochExclude) internal returns (uint256 availableFunds) {
        uint64 delegateGap = delegation.delegateGap;
        // lets iterate delegations from delegateGap to queueLength
        for (; delegateGap < delegation.delegateQueue.length && gasleft() > CLAIM_BEFORE_GAS; delegateGap++) {
            // pull delegation
            DelegationOpDelegate memory delegateOp = delegation.delegateQueue[delegateGap];
            if (delegateOp.epoch >= beforeEpochExclude) {
                break;
            }
            (uint256 extracted, uint64 claimedAt) = _extractClaimable(delegation, delegateGap, validator, beforeEpochExclude);
            delegation.delegateQueue[delegateGap].claimEpoch = claimedAt;
            availableFunds += extracted;
        }
    }

    function _processUndelegateQueue(ValidatorDelegation storage delegation, uint64 beforeEpochExclude) internal returns (uint256 availableFunds) {
        uint64 undelegateGap = delegation.undelegateGap;
        for (uint256 queueLength = delegation.undelegateQueue.length; undelegateGap < queueLength && gasleft() > CLAIM_BEFORE_GAS;) {
            DelegationOpUndelegate memory undelegateOp = delegation.undelegateQueue[undelegateGap];
            if (undelegateOp.epoch > beforeEpochExclude) {
                break;
            }
            availableFunds += uint256(undelegateOp.amount) * BALANCE_COMPACT_PRECISION;
            delete delegation.undelegateQueue[undelegateGap];
            ++undelegateGap;
        }
        delegation.undelegateGap = undelegateGap;
        return availableFunds;
    }

    function _calcDelegatorRewardsAndPendingUndelegates(address validator, address delegator, uint64 beforeEpoch, bool withUndelegate) internal view returns (uint256 availableFunds) {
        ValidatorDelegation memory delegation = _validatorDelegations[validator][delegator];
        // process delegate queue to calculate staking rewards
        for (;delegation.delegateGap < delegation.delegateQueue.length; delegation.delegateGap++) {
            DelegationOpDelegate memory delegateOp = delegation.delegateQueue[delegation.delegateGap];
            if (delegateOp.epoch >= beforeEpoch) {
                break;
            }
            (uint256 extracted, /* uint64 claimedAt */) = _extractClaimable(delegation, delegation.delegateGap, validator, beforeEpoch);
            availableFunds += extracted;
        }
        // process all items from undelegate queue
        if (withUndelegate) {
            availableFunds += delegation.calcWithdrawalAmount(beforeEpoch, true) * BALANCE_COMPACT_PRECISION;
        }
        // return available for claim funds
        return availableFunds;
    }

    // extract rewards from claimEpoch to nextDelegationEpoch or beforeEpoch
    function _extractClaimable(
        ValidatorDelegation memory delegation,
        uint64 gap,
        address validator,
        uint256 beforeEpoch
    ) internal view returns (uint256 availableFunds, uint64 lastEpoch) {
        DelegationOpDelegate memory delegateOp = delegation.delegateQueue[gap];
        // if delegateOp was created before field claimEpoch added
        if (delegateOp.claimEpoch == 0) {
            delegateOp.claimEpoch = delegateOp.epoch;
        }

        // we must extract claimable rewards before next delegation
        uint256 nextDelegationEpoch;
        if (gap < delegation.delegateQueue.length - 1) {
            nextDelegationEpoch = delegation.delegateQueue[gap + 1].epoch;
        }

        for (; delegateOp.claimEpoch < beforeEpoch && (nextDelegationEpoch == 0 || delegateOp.claimEpoch < nextDelegationEpoch); delegateOp.claimEpoch++) {
            ValidatorSnapshot memory validatorSnapshot = _validatorSnapshots[validator][delegateOp.claimEpoch];
            if (validatorSnapshot.totalDelegated == 0) {
                continue;
            }
            (uint256 delegatorFee, /*uint256 ownerFee*/, /*uint256 systemFee*/) = _calcValidatorSnapshotEpochPayout(validatorSnapshot);
            availableFunds += delegatorFee * delegateOp.amount / validatorSnapshot.totalDelegated;
        }
        return (availableFunds, delegateOp.claimEpoch);
    }

    function _claimValidatorOwnerRewards(Validator storage validator, uint64 beforeEpoch) internal {
        uint256 availableFunds;
        uint256 systemFee;
        uint64 claimAt = validator.claimedAt;
        for (; claimAt < beforeEpoch && gasleft() > CLAIM_BEFORE_GAS; claimAt++) {
            ValidatorSnapshot memory validatorSnapshot = _validatorSnapshots[validator.validatorAddress][claimAt];
            (/*uint256 delegatorFee*/, uint256 ownerFee, uint256 slashingFee) = _calcValidatorSnapshotEpochPayout(validatorSnapshot);
            availableFunds += ownerFee;
            systemFee += slashingFee;
        }
        validator.claimedAt = claimAt;
        _safeTransferWithGasLimit(payable(validator.ownerAddress), availableFunds);
        // if we have system fee then pay it to treasury account
        if (systemFee > 0) {
            _unsafeTransfer(payable(_stakingConfig.getTreasuryAddress()), systemFee);
        }
        emit ValidatorOwnerClaimed(validator.validatorAddress, availableFunds, beforeEpoch);
    }

    function _calcValidatorOwnerRewards(Validator memory validator, uint64 beforeEpoch) internal view returns (uint256) {
        uint256 availableFunds;
        for (; validator.claimedAt < beforeEpoch; validator.claimedAt++) {
            ValidatorSnapshot memory validatorSnapshot = _validatorSnapshots[validator.validatorAddress][validator.claimedAt];
            (/*uint256 delegatorFee*/, uint256 ownerFee, /*uint256 systemFee*/) = _calcValidatorSnapshotEpochPayout(validatorSnapshot);
            availableFunds += ownerFee;
        }
        return availableFunds;
    }

    function _calcValidatorSnapshotEpochPayout(ValidatorSnapshot memory validatorSnapshot) internal view returns (uint256 delegatorFee, uint256 ownerFee, uint256 systemFee) {
        // detect validator slashing to transfer all rewards to treasury
        if (validatorSnapshot.slashesCount >= _stakingConfig.getMisdemeanorThreshold()) {
            return (delegatorFee, ownerFee, systemFee = validatorSnapshot.totalRewards);
        } else if (validatorSnapshot.totalDelegated == 0) {
            return (delegatorFee, ownerFee = validatorSnapshot.totalRewards, systemFee);
        }
        ownerFee = validatorSnapshot.getOwnerFee();
        delegatorFee = validatorSnapshot.totalRewards - ownerFee;
    }

    function registerValidator(address validatorAddress, uint16 commissionRate, uint256) payable external virtual override {
        uint256 initialStake = msg.value;
        // // initial stake amount should be greater than minimum validator staking amount
        require(initialStake >= _stakingConfig.getMinValidatorStakeAmount(), "too low");
        require(initialStake % BALANCE_COMPACT_PRECISION == 0, "no remainder");
        // add new validator as pending
        _addValidator(validatorAddress, msg.sender, ValidatorStatus.Pending, commissionRate, initialStake, nextEpoch());
    }

    function addValidator(address account) external onlyFromGovernance virtual override {
        _addValidator(account, account, ValidatorStatus.Active, 0, 0, nextEpoch());
    }

    function _addValidator(address validatorAddress, address validatorOwner, ValidatorStatus status, uint16 commissionRate, uint256 initialStake, uint64 sinceEpoch) internal {
        // validator commission rate
        require(commissionRate >= COMMISSION_RATE_MIN_VALUE && commissionRate <= COMMISSION_RATE_MAX_VALUE, "bad commission");
        // init validator default params
        _validatorsMap[validatorAddress].create(validatorAddress, validatorOwner, status, sinceEpoch);
        // save validator owner
        require(_validatorOwners[validatorOwner] == address(0x00), "owner in use");
        _validatorOwners[validatorOwner] = validatorAddress;
        // add new validator to array
        if (status == ValidatorStatus.Active) {
            _activeValidatorsList.push(validatorAddress);
        }
        // push initial validator snapshot at zero epoch with default params
        _validatorSnapshots[validatorAddress][sinceEpoch].create(uint112(initialStake / BALANCE_COMPACT_PRECISION), commissionRate);
        // delegate initial stake to validator owner
        _validatorDelegations[validatorAddress][validatorOwner].addInitial(uint112(initialStake / BALANCE_COMPACT_PRECISION), sinceEpoch);
        emit Delegated(validatorAddress, validatorOwner, initialStake, sinceEpoch);
        // emit event
        emit ValidatorAdded(validatorAddress, validatorOwner, uint8(status), commissionRate);
    }

    function _calcLockPeriod(uint64 sinceEpoch) internal view returns (uint64) {
        uint64 lockPeriod = _stakingConfig.getLockPeriod();
        if (lockPeriod == 0) {
            return 0;
        }
        return sinceEpoch + lockPeriod;
    }

//    function _removeValidatorFromActiveList(address validatorAddress) internal {
//        // find index of validator in validator set
//        int256 indexOf = - 1;
//        for (uint256 i; i < _activeValidatorsList.length; i++) {
//            if (_activeValidatorsList[i] != validatorAddress) continue;
//            indexOf = int256(i);
//            break;
//        }
//        // remove validator from array (since we remove only active it might not exist in the list)
//        if (indexOf >= 0) {
//            if (_activeValidatorsList.length > 1 && uint256(indexOf) != _activeValidatorsList.length - 1) {
//                _activeValidatorsList[uint256(indexOf)] = _activeValidatorsList[_activeValidatorsList.length - 1];
//            }
//            _activeValidatorsList.pop();
//        }
//    }

    function activateValidator(address validatorAddress) external onlyFromGovernance virtual override {
        Validator storage validator = _validatorsMap[validatorAddress];
        validator.activate();
        _activeValidatorsList.push(validatorAddress);
        ValidatorSnapshot storage snapshot = _touchValidatorSnapshot(validator, nextEpoch());
        emit ValidatorModified(validatorAddress, validator.ownerAddress, uint8(validator.status), snapshot.commissionRate);
    }

//    function disableValidator(address validatorAddress) external onlyFromGovernance virtual override {
//        Validator storage validator = _validatorsMap[validatorAddress];
//        validator.disable();
//        _removeValidatorFromActiveList(validatorAddress);
//        ValidatorSnapshot storage snapshot = _touchValidatorSnapshot(validator, nextEpoch());
//        emit ValidatorModified(validatorAddress, validator.ownerAddress, uint8(validator.status), snapshot.commissionRate);
//    }

    function changeValidatorCommissionRate(address validatorAddress, uint16 commissionRate) external override {
        require(commissionRate >= COMMISSION_RATE_MIN_VALUE && commissionRate <= COMMISSION_RATE_MAX_VALUE, "bad commission");
        Validator storage validator = _validatorsMap[validatorAddress];
        require(validator.status != ValidatorStatus.NotFound, "not found");
        require(validator.isOwner(msg.sender), "only owner");
        ValidatorSnapshot storage snapshot = _touchValidatorSnapshot(validator, nextEpoch());
        snapshot.commissionRate = commissionRate;
        emit ValidatorModified(validator.validatorAddress, validator.ownerAddress, uint8(validator.status), commissionRate);
    }

    function changeValidatorOwner(address validatorAddress, address newOwner) external override {
        require(newOwner != address(0x0), "new owner cannot be zero address");
        Validator storage validator = _validatorsMap[validatorAddress];
        require(validator.ownerAddress == msg.sender, "only owner");
        require(_validatorOwners[newOwner] == address(0x00), "owner in use");
        delete _validatorOwners[validator.ownerAddress];
        validator.ownerAddress = newOwner;
        _validatorOwners[newOwner] = validatorAddress;
        ValidatorSnapshot storage snapshot = _touchValidatorSnapshot(validator, nextEpoch());
        emit ValidatorModified(validator.validatorAddress, validator.ownerAddress, uint8(validator.status), snapshot.commissionRate);
    }

//    function isValidatorActive(address account) external override view returns (bool) {
//        if (!_validatorsMap[account].isActive()) {
//            return false;
//        }
//        address[] memory topValidators = getValidators();
//        for (uint256 i; i < topValidators.length; i++) {
//            if (topValidators[i] == account) return true;
//        }
//        return false;
//    }

    function isValidator(address account) external override view returns (bool) {
        return _validatorsMap[account].status != ValidatorStatus.NotFound;
    }

    function getValidators() public view override returns (address[] memory) {
        uint256 n = _activeValidatorsList.length;
        address[] memory orderedValidators = new address[](n);
        for (uint256 i; i < n; i++) {
            orderedValidators[i] = _activeValidatorsList[i];
        }
        // we need to select k top validators out of n
        uint256 k = _stakingConfig.getActiveValidatorsLength();
        if (k > n) {
            k = n;
        }
        for (uint256 i = 0; i < k; i++) {
            uint256 nextValidator = i;
            Validator memory currentMax = _validatorsMap[orderedValidators[nextValidator]];
            ValidatorSnapshot memory maxSnapshot = _validatorSnapshots[currentMax.validatorAddress][currentMax.changedAt];
            for (uint256 j = i + 1; j < n; j++) {
                Validator memory current = _validatorsMap[orderedValidators[j]];
                ValidatorSnapshot memory currentSnapshot = _validatorSnapshots[current.validatorAddress][current.changedAt];
                if (maxSnapshot.totalDelegated < currentSnapshot.totalDelegated) {
                    nextValidator = j;
                    currentMax = current;
                    maxSnapshot = currentSnapshot;
                }
            }
            address backup = orderedValidators[i];
            orderedValidators[i] = orderedValidators[nextValidator];
            orderedValidators[nextValidator] = backup;
        }
        // this is to cut array to first k elements without copying
        assembly {
            mstore(orderedValidators, k)
        }
        return orderedValidators;
    }

    function _depositFee(address validatorAddress, uint256 amount) internal {
        // make sure validator is active
        Validator storage validator = _validatorsMap[validatorAddress];
        require(validator.status != ValidatorStatus.NotFound, "not found");
        uint64 epoch = currentEpoch();
        // increase total pending rewards for validator for current epoch
        ValidatorSnapshot storage currentSnapshot = _touchValidatorSnapshot(validator, epoch);
        currentSnapshot.totalRewards += uint96(amount);
        // validator data might be changed during _touchValidatorSnapshot()
        // emit event
        emit ValidatorDeposited(validatorAddress, amount, epoch);
    }

    function getValidatorFee(address validatorAddress) external override view returns (uint256) {
        // make sure validator exists at least
        Validator memory validator = _validatorsMap[validatorAddress];
        if (validator.status == ValidatorStatus.NotFound) {
            return 0;
        }
        // calc validator rewards
        return _calcValidatorOwnerRewards(validator, currentEpoch());
    }

    function getPendingValidatorFee(address validatorAddress) external override view returns (uint256) {
        // make sure validator exists at least
        Validator memory validator = _validatorsMap[validatorAddress];
        if (validator.status == ValidatorStatus.NotFound) {
            return 0;
        }
        // calc validator rewards
        return _calcValidatorOwnerRewards(validator, nextEpoch());
    }

    function claimValidatorFee(address validatorAddress) external override {
        // make sure validator exists at least
        Validator storage validator = _validatorsMap[validatorAddress];
        // only validator owner can claim deposit fee
        require(validator.isOwner(msg.sender), "only owner");
        // claim all validator fees
        _claimValidatorOwnerRewards(validator, currentEpoch());
    }

    function getDelegatorFee(address validatorAddress, address delegatorAddress) external override view returns (uint256) {
        return _calcDelegatorRewardsAndPendingUndelegates(validatorAddress, delegatorAddress, currentEpoch(), true);
    }

    function getPendingDelegatorFee(address validatorAddress, address delegatorAddress) external override view returns (uint256) {
        return _calcDelegatorRewardsAndPendingUndelegates(validatorAddress, delegatorAddress, nextEpoch(), true);
    }

    function claimDelegatorFee(address validatorAddress) external override {
        // claim all confirmed delegator fees including undelegates
        _transferDelegatorRewards(validatorAddress, msg.sender, currentEpoch(), true, true);
    }

    function getStakingRewards(address validator, address delegator) external view returns (uint256) {
        return _calcDelegatorRewardsAndPendingUndelegates(validator, delegator, currentEpoch(), false);
    }

    function claimStakingRewards(address validatorAddress) external override {
        // claim only staking rewards
        _transferDelegatorRewards(validatorAddress, msg.sender, currentEpoch(), true, false);
    }

    function claimPendingUndelegates(address validator) external override {
        // claim only pending undelegates
        _transferDelegatorRewards(validator, msg.sender, currentEpoch(), false, true);
    }

    /**
     * @notice the amount will not be challenged by MinValidatorStakeAmount
     * @dev should use it for split re/delegate amount into stake-able and dust
     */
    function calcAvailableForDelegateAmount(uint256 amount) public pure override returns (uint256 amountToStake, uint256 dust) {
        amountToStake = (amount / BALANCE_COMPACT_PRECISION) * BALANCE_COMPACT_PRECISION;
        dust = amount - amountToStake;
        return (amountToStake, dust);
    }

    function calcAvailableForRedelegateAmount(address validator, address delegator) external view override returns (uint256 amountToStake, uint256 rewardsDust) {
        uint256 claimableRewards = _calcDelegatorRewardsAndPendingUndelegates(validator, delegator, currentEpoch(), false);
        return calcAvailableForDelegateAmount(claimableRewards);
    }

    function redelegateDelegatorFee(address validator) external override {
        // claim rewards in the redelegate mode (check function code for more info)
        _redelegateDelegatorRewards(validator, msg.sender, currentEpoch(), true, false);
    }

    function _safeTransferWithGasLimit(address payable recipient, uint256 amount) internal virtual {
        (bool success,) = recipient.call{value : amount, gas : TRANSFER_GAS_LIMIT}("");
        require(success);
    }

    function _unsafeTransfer(address payable recipient, uint256 amount) internal virtual {
        (bool success,) = payable(address(recipient)).call{value : amount}("");
        require(success);
    }

//    function _slashValidator(address validatorAddress) internal {
//        // make sure validator exists
//        Validator storage validator = _validatorsMap[validatorAddress];
//        uint64 epoch = currentEpoch();
//        // increase slashes for current epoch
//        uint32 slashesCount = _touchValidatorSnapshot(validator, epoch).slash();
//        _validatorsMap[validatorAddress] = validator;
//        // if validator has a lot of misses then put it in jail for 1 week (if epoch is 1 day)
//        if (slashesCount == _stakingConfig.getFelonyThreshold()) {
//            _validatorsMap[validatorAddress].jail(currentEpoch() + _stakingConfig.getValidatorJailEpochLength());
//            _removeValidatorFromActiveList(validatorAddress);
//            emit ValidatorJailed(validatorAddress, epoch);
//        }
//        // emit event
//        emit ValidatorSlashed(validatorAddress, slashesCount, epoch);
//    }

    function initLastWithdrawn(address validator, address[] calldata delegators) external onlyFromGovernance {
        for (uint256 i; i < delegators.length; i++) {
            ValidatorDelegation memory delegation = _validatorDelegations[validator][delegators[i]];
            // does not affect delegators who already have withdrawEpoch
            if (delegation.delegateQueue.length < 2 ||  delegation.withdrawnEpoch != 0) {
                continue;
            }
            // find last claim and use diff between two ops
            for (uint256 j = delegation.delegateQueue.length - 1; j > delegation.delegateGap; j--) {
                if (delegation.delegateQueue[j].amount < delegation.delegateQueue[j-1].amount) {
                    _validatorDelegations[validator][delegators[i]].withdrawnEpoch = delegation.delegateQueue[j].epoch;
                    _validatorDelegations[validator][delegators[i]].withdrawnAmount = delegation.delegateQueue[j-1].amount - delegation.delegateQueue[j].amount;
                    break;
                }
            }
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../interfaces/IStakingConfig.sol";

contract StakingConfig is Initializable, IStakingConfig {

    event ActiveValidatorsLengthChanged(uint32 prevValue, uint32 newValue);
    event EpochBlockIntervalChanged(uint32 prevValue, uint32 newValue);
    event MisdemeanorThresholdChanged(uint32 prevValue, uint32 newValue);
    event FelonyThresholdChanged(uint32 prevValue, uint32 newValue);
    event ValidatorJailEpochLengthChanged(uint32 prevValue, uint32 newValue);
    event UndelegatePeriodChanged(uint32 prevValue, uint32 newValue);
    event MinValidatorStakeAmountChanged(uint256 prevValue, uint256 newValue);
    event MinStakingAmountChanged(uint256 prevValue, uint256 newValue);
    event GovernanceAddressChanged(address prevValue, address newValue);
    event TreasuryAddressChanged(address prevValue, address newValue);
    event LockPeriodChanged(uint64 prevValue, uint64 newValue);

    struct Slot0 {
        uint32 activeValidatorsLength;
        uint32 epochBlockInterval;
        uint32 misdemeanorThreshold;
        uint32 felonyThreshold;
        uint32 validatorJailEpochLength;
        uint32 undelegatePeriod;
        uint256 minValidatorStakeAmount;
        uint256 minStakingAmount;
        address governanceAddress;
        address treasuryAddress;
        uint64 lockPeriod;
    }

    Slot0 private _slot0;

    function initialize(
        uint32 activeValidatorsLength,
        uint32 epochBlockInterval,
        uint32 misdemeanorThreshold,
        uint32 felonyThreshold,
        uint32 validatorJailEpochLength,
        uint32 undelegatePeriod,
        uint256 minValidatorStakeAmount,
        uint256 minStakingAmount,
        address governanceAddress,
        address treasuryAddress,
        uint64 lockPeriod
    ) external initializer {
        _slot0.activeValidatorsLength = activeValidatorsLength;
        emit ActiveValidatorsLengthChanged(0, activeValidatorsLength);
        _slot0.epochBlockInterval = epochBlockInterval;
        emit EpochBlockIntervalChanged(0, epochBlockInterval);
        _slot0.misdemeanorThreshold = misdemeanorThreshold;
        emit MisdemeanorThresholdChanged(0, misdemeanorThreshold);
        _slot0.felonyThreshold = felonyThreshold;
        emit FelonyThresholdChanged(0, felonyThreshold);
        _slot0.validatorJailEpochLength = validatorJailEpochLength;
        emit ValidatorJailEpochLengthChanged(0, validatorJailEpochLength);
        _slot0.undelegatePeriod = undelegatePeriod;
        emit UndelegatePeriodChanged(0, undelegatePeriod);
        _slot0.minValidatorStakeAmount = minValidatorStakeAmount;
        emit MinValidatorStakeAmountChanged(0, minValidatorStakeAmount);
        _slot0.minStakingAmount = minStakingAmount;
        emit MinStakingAmountChanged(0, minStakingAmount);
        _slot0.governanceAddress = governanceAddress;
        emit GovernanceAddressChanged(address(0x00), governanceAddress);
        _slot0.treasuryAddress = treasuryAddress;
        emit TreasuryAddressChanged(address(0x00), treasuryAddress);
        _slot0.lockPeriod = lockPeriod;
        emit LockPeriodChanged(0, lockPeriod);
    }

    modifier onlyFromGovernance() virtual {
        require(msg.sender == _slot0.governanceAddress, "Staking: only governance");
        _;
    }

    function getSlot0() external view returns (Slot0 memory) {
        return _slot0;
    }

    function getActiveValidatorsLength() external view override returns (uint32) {
        return _slot0.activeValidatorsLength;
    }

    function setActiveValidatorsLength(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.activeValidatorsLength;
        _slot0.activeValidatorsLength = newValue;
        emit ActiveValidatorsLengthChanged(prevValue, newValue);
    }

    function getEpochBlockInterval() external view override returns (uint32) {
        return _slot0.epochBlockInterval;
    }

    function setEpochBlockInterval(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.epochBlockInterval;
        _slot0.epochBlockInterval = newValue;
        emit EpochBlockIntervalChanged(prevValue, newValue);
    }

    function getMisdemeanorThreshold() external view override returns (uint32) {
        return _slot0.misdemeanorThreshold;
    }

    function setMisdemeanorThreshold(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.misdemeanorThreshold;
        _slot0.misdemeanorThreshold = newValue;
        emit MisdemeanorThresholdChanged(prevValue, newValue);
    }

    function getFelonyThreshold() external view override returns (uint32) {
        return _slot0.felonyThreshold;
    }

    function setFelonyThreshold(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.felonyThreshold;
        _slot0.felonyThreshold = newValue;
        emit FelonyThresholdChanged(prevValue, newValue);
    }

    function getValidatorJailEpochLength() external view override returns (uint32) {
        return _slot0.validatorJailEpochLength;
    }

    function setValidatorJailEpochLength(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.validatorJailEpochLength;
        _slot0.validatorJailEpochLength = newValue;
        emit ValidatorJailEpochLengthChanged(prevValue, newValue);
    }

    function getUndelegatePeriod() external view override returns (uint32) {
        return _slot0.undelegatePeriod;
    }

    function setUndelegatePeriod(uint32 newValue) external override onlyFromGovernance {
        uint32 prevValue = _slot0.undelegatePeriod;
        _slot0.undelegatePeriod = newValue;
        emit UndelegatePeriodChanged(prevValue, newValue);
    }

    function getMinValidatorStakeAmount() external view override returns (uint256) {
        return _slot0.minValidatorStakeAmount;
    }

    function setMinValidatorStakeAmount(uint256 newValue) external override onlyFromGovernance {
        uint256 prevValue = _slot0.minValidatorStakeAmount;
        _slot0.minValidatorStakeAmount = newValue;
        emit MinValidatorStakeAmountChanged(prevValue, newValue);
    }

    function getMinStakingAmount() external view override returns (uint256) {
        return _slot0.minStakingAmount;
    }

    function setMinStakingAmount(uint256 newValue) external override onlyFromGovernance {
        uint256 prevValue = _slot0.minStakingAmount;
        _slot0.minStakingAmount = newValue;
        emit MinStakingAmountChanged(prevValue, newValue);
    }

    function getGovernanceAddress() external view override returns (address) {
        return _slot0.governanceAddress;
    }

    function setGovernanceAddress(address newValue) external override onlyFromGovernance {
        address prevValue = _slot0.governanceAddress;
        _slot0.governanceAddress = newValue;
        emit GovernanceAddressChanged(prevValue, newValue);
    }

    function getTreasuryAddress() external view override returns (address) {
        return _slot0.treasuryAddress;
    }

    function setTreasuryAddress(address newValue) external override onlyFromGovernance {
        address prevValue = _slot0.treasuryAddress;
        _slot0.treasuryAddress = newValue;
        emit TreasuryAddressChanged(prevValue, newValue);
    }

    function getLockPeriod() external view override returns (uint64) {
        return _slot0.lockPeriod;
    }

    function setLockPeriod(uint64 newValue) external override onlyFromGovernance {
        uint64 prevValue = _slot0.lockPeriod;
        _slot0.lockPeriod = newValue;
        emit LockPeriodChanged(prevValue, newValue);
    }
}

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.7;

import "../../interfaces/ITokenStaking.sol";

import "../Staking.sol";

contract TokenStaking is Staking, ITokenStaking {

    // address of the erc20 token
    IERC20 internal _erc20Token;
    // reserve some gap for the future upgrades
    uint256[100 - 2] private __reserved;

    function __TokenStaking_init(IStakingConfig chainConfig, IERC20 erc20Token) internal {
        _stakingConfig = chainConfig;
        _erc20Token = erc20Token;
    }

    function getErc20Token() external view override returns (IERC20) {
        return _erc20Token;
    }

    function registerValidator(address validatorAddress, uint16 commissionRate, uint256 amount) external payable virtual override(Staking, IStaking) {
        require(msg.value == 0, "TokenStaking: ERC20 expected");
        // initial stake amount should be greater than minimum validator staking amount
        require(amount >= _stakingConfig.getMinValidatorStakeAmount(), "too low");
        require(amount % BALANCE_COMPACT_PRECISION == 0, "no remainder");
        // transfer tokens
        require(_erc20Token.transferFrom(msg.sender, address(this), amount), "TokenStaking: failed to transfer");
        // add new validator as pending
        _addValidator(validatorAddress, msg.sender, ValidatorStatus.Pending, commissionRate, amount, nextEpoch());
    }

    function delegate(address validatorAddress, uint256 amount) payable external override {
        require(msg.value == 0, "TokenStaking: ERC20 expected");
        require(_erc20Token.transferFrom(msg.sender, address(this), amount), "failed to transfer");
        _delegateTo(msg.sender, validatorAddress, amount, true);
    }

    function distributeRewards(address validatorAddress, uint256 amount) external override {
        require(_erc20Token.transferFrom(msg.sender, address(this), amount), "failed to transfer");
        _depositFee(validatorAddress, amount);
    }

    function _safeTransferWithGasLimit(address payable recipient, uint256 amount) internal override {
        require(_erc20Token.transfer(recipient, amount), "failed to safe transfer");
    }

    function _unsafeTransfer(address payable recipient, uint256 amount) internal override {
        require(_erc20Token.transfer(recipient, amount), "failed to unsafe transfer");
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
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
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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