// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./libraries/PoolDepositable.sol";
import "./libraries/Tierable.sol";
import "./libraries/Suspendable.sol";
import "./libraries/PoolVestingDepositable.sol";

/** @title LockedLBToken.
 * @dev PoolDepositable contract implementation with tiers
 */
contract LockedLBToken is
    Initializable,
    PoolDepositable,
    Tierable,
    Suspendable,
    PoolVestingDepositable
{
    /**
     * @notice Initializer
     * @param _depositToken: the deposited token
     * @param tiersMinAmount: the tiers min amount
     * @param _pauser: the address of the account granted with PAUSER_ROLE
     */
    function initialize(
        IERC20Upgradeable _depositToken,
        uint256[] memory tiersMinAmount,
        address _pauser
    ) external initializer {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Poolable_init_unchained();
        __Depositable_init_unchained(_depositToken);
        __PoolDepositable_init_unchained();
        __Tierable_init_unchained(tiersMinAmount);
        __Pausable_init_unchained();
        __Suspendable_init_unchained(_pauser);
        __PoolVestingable_init_unchained();
        __PoolVestingDepositable_init_unchained();
        __LockedLBToken_init_unchained();
    }

    function __LockedLBToken_init_unchained() internal onlyInitializing {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function _deposit(
        address,
        address,
        uint256
    )
        internal
        pure
        override(PoolDepositable, Depositable, PoolVestingDepositable)
        returns (uint256)
    {
        revert("LockedLBToken: Must deposit with poolIndex");
    }

    function _withdraw(address, uint256)
        internal
        pure
        override(PoolDepositable, Depositable, PoolVestingDepositable)
        returns (uint256)
    {
        revert("LockedLBToken: Must withdraw with poolIndex");
    }

    function _withdraw(
        address,
        uint256,
        uint256
    )
        internal
        pure
        override(PoolDepositable, PoolVestingDepositable)
        returns (uint256)
    {
        revert("LockedLBToken: Must withdraw with on a specific pool type");
    }

    /**
     * @notice Deposit amount token in pool at index `poolIndex` to the sender address balance
     */
    function deposit(uint256 amount, uint256 poolIndex) external whenNotPaused {
        PoolDepositable._deposit(_msgSender(), _msgSender(), amount, poolIndex);
    }

    /**
     * @notice Withdraw amount token in pool at index `poolIndex` from the sender address balance
     */
    function withdraw(uint256 amount, uint256 poolIndex)
        external
        whenNotPaused
    {
        PoolDepositable._withdraw(_msgSender(), amount, poolIndex);
    }

    /**
     * @notice Batch deposits into a vesting pool
     */
    function vestingBatchDeposits(
        address from,
        address[] memory to,
        uint256[] memory amounts,
        uint256 poolIndex
    ) external whenNotPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        PoolVestingDepositable._batchDeposits(from, to, amounts, poolIndex);
    }

    /**
     * @notice Withdraw from a vesting pool
     */
    function vestingWithdraw(uint256 amount, uint256 poolIndex)
        external
        whenNotPaused
    {
        PoolVestingDepositable._withdraw(_msgSender(), amount, poolIndex);
    }

    /**
     * @notice Batch transfer amount from one vesting pool deposit to another
     */
    function transferVestingPoolDeposits(
        address[] calldata accounts,
        uint256[] calldata amounts,
        uint256 fromPoolIndex,
        uint256 toPoolIndex
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            accounts.length == amounts.length,
            "LockedLBToken: account and amounts length are not equal"
        );
        for (uint256 i = 0; i < accounts.length; i++) {
            PoolVestingDepositable._transferVestingPoolDeposit(
                accounts[i],
                amounts[i],
                fromPoolIndex,
                toPoolIndex
            );
        }
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./Poolable.sol";
import "./Depositable.sol";

/** @title PoolDepositable.
@dev This contract manage pool of deposits
*/
abstract contract PoolDepositable is
    Initializable,
    AccessControlUpgradeable,
    Poolable,
    Depositable
{
    using SafeMathUpgradeable for uint256;

    struct UserPoolDeposit {
        uint256 poolIndex; // index of the pool
        uint256 amount; // amount deposited in the pool
        uint256 depositDate; // date of last deposit
    }

    struct BatchDeposit {
        address to; // destination address
        uint256 amount; // amount deposited
        uint256 poolIndex; // index of the pool
    }

    // mapping of deposits for a user
    mapping(address => UserPoolDeposit[]) private _poolDeposits;

    /**
     * @dev Emitted when a user deposit in a pool
     */
    event PoolDeposit(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 poolIndex
    );

    /**
     * @dev Emitted when a user withdraw from a pool
     */
    event PoolWithdraw(address indexed to, uint256 amount, uint256 poolIndex);

    /**
     * @notice Initializer
     * @param _depositToken: the deposited token
     */
    function __PoolDepositable_init(IERC20Upgradeable _depositToken)
        internal
        onlyInitializing
    {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Poolable_init_unchained();
        __Depositable_init_unchained(_depositToken);
        __PoolDepositable_init_unchained();
    }

    function __PoolDepositable_init_unchained() internal onlyInitializing {}

    /**
     * @dev returns the index of a user's pool deposit (`UserPoolDeposit`) for the specified pool at index `poolIndex`
     */
    function _indexOfPoolDeposit(address account, uint256 poolIndex)
        private
        view
        returns (int256)
    {
        for (uint256 i = 0; i < _poolDeposits[account].length; i++) {
            if (_poolDeposits[account][i].poolIndex == poolIndex) {
                return int256(i);
            }
        }
        return -1;
    }

    /**
     * @dev returns the list of pool deposits for an account
     */
    function poolDepositsOf(address account)
        public
        view
        returns (UserPoolDeposit[] memory)
    {
        return _poolDeposits[account];
    }

    /**
     * @dev returns the list of pool deposits for an account
     */
    function poolDepositOf(address account, uint256 poolIndex)
        external
        view
        returns (UserPoolDeposit memory poolDeposit)
    {
        int256 depositIndex = _indexOfPoolDeposit(account, poolIndex);
        if (depositIndex > -1) {
            poolDeposit = _poolDeposits[account][uint256(depositIndex)];
        }
    }

    // block the default implementation
    function _deposit(
        address,
        address,
        uint256
    ) internal pure virtual override returns (uint256) {
        revert("PoolDepositable: Must deposit with poolIndex");
    }

    // block the default implementation
    function _withdraw(address, uint256)
        internal
        pure
        virtual
        override
        returns (uint256)
    {
        revert("PoolDepositable: Must withdraw with poolIndex");
    }

    /**
     * @dev Deposit tokens to pool at `poolIndex`
     */
    function _deposit(
        address from,
        address to,
        uint256 amount,
        uint256 poolIndex
    ) internal virtual whenPoolOpened(poolIndex) returns (uint256) {
        uint256 depositAmount = Depositable._deposit(from, to, amount);

        int256 depositIndex = _indexOfPoolDeposit(to, poolIndex);
        if (depositIndex > -1) {
            UserPoolDeposit storage pool = _poolDeposits[to][
                uint256(depositIndex)
            ];
            pool.amount = pool.amount.add(depositAmount);
            pool.depositDate = block.timestamp; // update date to last deposit
        } else {
            _poolDeposits[to].push(
                UserPoolDeposit({
                    poolIndex: poolIndex,
                    amount: depositAmount,
                    depositDate: block.timestamp
                })
            );
        }

        emit PoolDeposit(from, to, amount, poolIndex);
        return depositAmount;
    }

    /**
     * @dev Withdraw tokens from a specific pool
     */
    function _withdrawPoolDeposit(
        address to,
        uint256 amount,
        UserPoolDeposit storage poolDeposit
    )
        private
        whenUnlocked(poolDeposit.poolIndex, poolDeposit.depositDate)
        returns (uint256)
    {
        require(
            poolDeposit.amount >= amount,
            "PoolDepositable: Pool deposit less than amount"
        );
        require(poolDeposit.amount > 0, "PoolDepositable: No deposit in pool");

        uint256 withdrawAmount = Depositable._withdraw(to, amount);
        poolDeposit.amount = poolDeposit.amount.sub(withdrawAmount);

        emit PoolWithdraw(to, amount, poolDeposit.poolIndex);
        return withdrawAmount;
    }

    /**
     * @dev Withdraw tokens from pool at `poolIndex`
     */
    function _withdraw(
        address to,
        uint256 amount,
        uint256 poolIndex
    ) internal virtual returns (uint256) {
        int256 depositIndex = _indexOfPoolDeposit(to, poolIndex);
        require(depositIndex > -1, "PoolDepositable: Not deposited");
        return
            _withdrawPoolDeposit(
                to,
                amount,
                _poolDeposits[to][uint256(depositIndex)]
            );
    }

    /**
     * @dev Batch deposits token in pools
     */
    function batchDeposits(address from, BatchDeposit[] memory deposits)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < deposits.length; i++) {
            _deposit(
                from,
                deposits[i].to,
                deposits[i].amount,
                deposits[i].poolIndex
            );
        }
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./Depositable.sol";
import "../interfaces/ITierable.sol";

/** @title Tierable.
 * @dev Depositable contract implementation with tiers
 */
abstract contract Tierable is
    Initializable,
    AccessControlUpgradeable,
    Depositable,
    ITierable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256[] private _tiersMinAmount;
    EnumerableSet.AddressSet private _whitelist;

    /**
     * @dev Emitted when tiers amount are changed
     */
    event TiersMinAmountChange(uint256[] amounts);

    /**
     * @dev Emitted when a new account is added to the whitelist
     */
    event AddToWhitelist(address account);

    /**
     * @dev Emitted when an account is removed from the whitelist
     */
    event RemoveFromWhitelist(address account);

    /**
     * @notice Initializer
     * @param _depositToken: the deposited token
     * @param tiersMinAmount: the tiers min amount
     */
    function __Tierable_init(
        IERC20Upgradeable _depositToken,
        uint256[] memory tiersMinAmount
    ) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Depositable_init_unchained(_depositToken);
        __Tierable_init_unchained(tiersMinAmount);
    }

    function __Tierable_init_unchained(uint256[] memory tiersMinAmount)
        internal
        onlyInitializing
    {
        _tiersMinAmount = tiersMinAmount;
    }

    /**
     * @dev Returns the index of the tier for `account`
     * @notice returns -1 if the total deposit of `account` is below the first tier
     */
    function tierOf(address account) public view override returns (int256) {
        // set max tier
        uint256 max = _tiersMinAmount.length;

        // check if account in whitelist
        if (_whitelist.contains(account)) {
            // return max tier
            return int256(max) - 1;
        }

        // check balance of account
        uint256 balance = depositOf(account);
        for (uint256 i = 0; i < max; i++) {
            // return its tier
            if (balance < _tiersMinAmount[i]) return int256(i) - 1;
        }
        // return max tier if balance more than last tiersMinAmount
        return int256(max) - 1;
    }

    /**
     * @notice update the tiers brackets
     * Only callable by owners
     */
    function changeTiersMinAmount(uint256[] memory tiersMinAmount)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _tiersMinAmount = tiersMinAmount;
        emit TiersMinAmountChange(_tiersMinAmount);
    }

    /**
     * @notice returns the list of min amount per tier
     */
    function getTiersMinAmount() external view returns (uint256[] memory) {
        return _tiersMinAmount;
    }

    /**
     * @notice Add new accounts to the whitelist
     * Only callable by owners
     */
    function addToWhitelist(address[] memory accounts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            bool result = _whitelist.add(accounts[i]);
            if (result) emit AddToWhitelist(accounts[i]);
        }
    }

    /**
     * @notice Remove an account from the whitelist
     * Only callable by owners
     */
    function removeFromWhitelist(address[] memory accounts)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        for (uint256 i = 0; i < accounts.length; i++) {
            bool result = _whitelist.remove(accounts[i]);
            if (result) emit RemoveFromWhitelist(accounts[i]);
        }
    }

    /**
     * @notice Remove accounts from whitelist
     * Only callable by owners
     */
    function getWhitelist()
        external
        view
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (address[] memory)
    {
        return _whitelist.values();
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/** @title RoleBasedPausable.
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 */
abstract contract Suspendable is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @notice Initializer
     * @param _pauser: the address of the account granted with PAUSER_ROLE
     */
    function __Suspendable_init(address _pauser) internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Pausable_init_unchained();
        __Suspendable_init_unchained(_pauser);
    }

    function __Suspendable_init_unchained(address _pauser)
        internal
        onlyInitializing
    {
        _setupRole(PAUSER_ROLE, _pauser);
    }

    /**
     * @dev Returns true if the contract is suspended/paused, and false otherwise.
     */
    function suspended() public view virtual returns (bool) {
        return paused();
    }

    /**
     * @notice suspend/pause the contract.
     * Only callable by members of PAUSER_ROLE
     */
    function suspend() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice resume/unpause the contract.
     * Only callable by members of PAUSER_ROLE
     */
    function resume() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./PoolVestingable.sol";
import "./Depositable.sol";

/** @title PoolVestingDepositable.
@dev This contract manage deposits in vesting pools
*/
abstract contract PoolVestingDepositable is
    Initializable,
    PoolVestingable,
    Depositable
{
    using SafeMathUpgradeable for uint256;

    struct UserVestingPoolDeposit {
        uint256 initialAmount; // initial amount deposited in the pool
        uint256 withdrawnAmount; // amount already withdrawn from the pool
    }

    // mapping of deposits for a user
    // user -> pool index -> user deposit
    mapping(address => mapping(uint256 => UserVestingPoolDeposit))
        private _poolDeposits;

    /**
     * @dev Emitted when a user deposit in a pool
     */
    event VestingPoolDeposit(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 poolIndex
    );

    /**
     * @dev Emitted when a user withdraw from a pool
     */
    event VestingPoolWithdraw(
        address indexed to,
        uint256 amount,
        uint256 poolIndex
    );

    /**
     * @dev Emitted when a user deposit is transferred to another pool
     */
    event VestingPoolTransfer(
        address indexed account,
        uint256 amount,
        uint256 fromPoolIndex,
        uint256 toPoolIndex
    );

    /**
     * @notice Initializer
     * @param _depositToken: the deposited token
     */
    function __PoolVestingDepositable_init(IERC20Upgradeable _depositToken)
        internal
        onlyInitializing
    {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __PoolVestingable_init_unchained();
        __Depositable_init_unchained(_depositToken);
        __PoolVestingDepositable_init_unchained();
    }

    function __PoolVestingDepositable_init_unchained()
        internal
        onlyInitializing
    {}

    /**
     * @dev returns the vested amount of a pool deposit
     */
    function _vestedAmountOf(address account, uint256 poolIndex)
        private
        view
        returns (uint256 vestedAmount)
    {
        VestingPool memory pool = getVestingPool(poolIndex);
        for (uint256 i = 0; i < pool.timestamps.length; i++) {
            if (block.timestamp >= pool.timestamps[i]) {
                // this schedule is reached, calculate its amount
                uint256 scheduleAmount = _poolDeposits[account][poolIndex]
                    .initialAmount
                    .mul(pool.ratiosPerHundredThousand[i])
                    .div(100000);
                // add it to vested amount
                vestedAmount = vestedAmount.add(scheduleAmount);
            }
        }
    }

    /**
     * @dev returns the amount that can be withdraw from a pool deposit
     */
    function _withdrawableAmountOf(address account, uint256 poolIndex)
        private
        view
        returns (uint256)
    {
        require(
            poolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid poolIndex"
        );
        return
            _vestedAmountOf(account, poolIndex).sub(
                _poolDeposits[account][poolIndex].withdrawnAmount
            );
    }

    /**
     * @dev returns the list of pool deposits for an account
     */
    function vestingPoolDepositOf(address account, uint256 poolIndex)
        external
        view
        returns (UserVestingPoolDeposit memory)
    {
        require(
            poolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid poolIndex"
        );
        return _poolDeposits[account][poolIndex];
    }

    /**
     * @dev returns vested amount of an account for a specific pool. Public version
     */
    function vestingPoolVestedAmountOf(address account, uint256 poolIndex)
        external
        view
        returns (uint256)
    {
        return _vestedAmountOf(account, poolIndex);
    }

    /**
     * @dev returns the amount that can be withdraw from a pool
     */
    function vestingPoolWithdrawableAmountOf(address account, uint256 poolIndex)
        external
        view
        returns (uint256)
    {
        return _withdrawableAmountOf(account, poolIndex);
    }

    // block the default implementation
    function _deposit(
        address,
        address,
        uint256
    ) internal pure virtual override returns (uint256) {
        revert("PoolVestingDepositable: Must deposit with poolIndex");
    }

    // block the default implementation
    function _withdraw(address, uint256)
        internal
        pure
        virtual
        override
        returns (uint256)
    {
        revert("PoolVestingDepositable: Must withdraw with poolIndex");
    }

    /**
     * @dev Deposit tokens to pool at `poolIndex`
     */
    function _savePoolDeposit(
        address from,
        address to,
        uint256 amount,
        uint256 poolIndex
    ) private {
        require(
            poolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid poolIndex"
        );
        UserVestingPoolDeposit storage poolDeposit = _poolDeposits[to][
            poolIndex
        ];
        poolDeposit.initialAmount = poolDeposit.initialAmount.add(amount);
        emit VestingPoolDeposit(from, to, amount, poolIndex);
    }

    /**
     * @dev Batch deposit tokens to pool at `poolIndex`
     */
    function _batchDeposits(
        address from,
        address[] memory to,
        uint256[] memory amounts,
        uint256 poolIndex
    ) internal virtual returns (uint256) {
        require(
            to.length == amounts.length,
            "PoolVestingDepositable: arrays to and amounts have different length"
        );

        uint256 totalTransferredAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 transferredAmount = Depositable._deposit(
                from,
                to[i],
                amounts[i]
            );
            _savePoolDeposit(from, to[i], transferredAmount, poolIndex);
            totalTransferredAmount = totalTransferredAmount.add(
                transferredAmount
            );
        }

        return totalTransferredAmount;
    }

    /**
     * @dev Withdraw tokens from pool at `poolIndex`
     */
    function _withdraw(
        address to,
        uint256 amount,
        uint256 poolIndex
    ) internal virtual returns (uint256) {
        require(
            poolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid poolIndex"
        );
        UserVestingPoolDeposit storage poolDeposit = _poolDeposits[to][
            poolIndex
        ];
        uint256 withdrawableAmount = _withdrawableAmountOf(to, poolIndex);

        require(
            withdrawableAmount >= amount,
            "PoolVestingDepositable: Withdrawable amount less than amount to withdraw"
        );
        require(
            withdrawableAmount > 0,
            "PoolVestingDepositable: No withdrawable amount to withdraw"
        );

        uint256 withdrawAmount = Depositable._withdraw(to, amount);
        poolDeposit.withdrawnAmount = poolDeposit.withdrawnAmount.add(
            withdrawAmount
        );

        emit VestingPoolWithdraw(to, amount, poolIndex);
        return withdrawAmount;
    }

    /**
     * @dev Transfer amount from one vesting pool deposit to another
     */
    function _transferVestingPoolDeposit(
        address account,
        uint256 amount,
        uint256 fromPoolIndex,
        uint256 toPoolIndex
    ) internal {
        require(
            fromPoolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid fromPoolIndex"
        );
        require(
            toPoolIndex < vestingPoolsLength(),
            "PoolVestingDepositable: Invalid toPoolIndex"
        );

        UserVestingPoolDeposit storage poolDepositFrom = _poolDeposits[account][
            fromPoolIndex
        ];
        UserVestingPoolDeposit storage poolDepositTo = _poolDeposits[account][
            toPoolIndex
        ];

        require(
            poolDepositTo.withdrawnAmount == 0,
            "PoolVestingDepositable: Cannot transfer amount if withdrawnAmount is not equal to 0"
        );

        // update initial amount
        poolDepositTo.initialAmount = poolDepositTo.initialAmount.add(amount);
        poolDepositFrom.initialAmount = poolDepositFrom.initialAmount.sub(
            amount
        );

        emit VestingPoolTransfer(account, amount, fromPoolIndex, toPoolIndex);
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
// OpenZeppelin Contracts v4.4.1 (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role, _msgSender());
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(uint160(account), 20),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
    uint256[49] private __gap;
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
library SafeMathUpgradeable {
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/** @title Poolable.
@dev This contract manage configuration of pools
*/
abstract contract Poolable is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    struct Pool {
        uint256 lockDuration; // locked timespan
        bool opened; // flag indicating if the pool is open
    }

    // pools mapping
    mapping(uint256 => Pool) private _pools;
    uint256 public poolsLength;

    /**
     * @dev Emitted when a pool is created
     */
    event PoolAdded(uint256 poolIndex, Pool pool);

    /**
     * @dev Emitted when a pool is updated
     */
    event PoolUpdated(uint256 poolIndex, Pool pool);

    /**
     * @dev Modifier that checks that the pool at index `poolIndex` is open
     */
    modifier whenPoolOpened(uint256 poolIndex) {
        require(poolIndex < poolsLength, "Poolable: Invalid poolIndex");
        require(_pools[poolIndex].opened, "Poolable: Pool is closed");
        _;
    }

    /**
     * @dev Modifier that checks that the now() - `depositDate` is above or equal to the min lock duration for pool at index `poolIndex`
     */
    modifier whenUnlocked(uint256 poolIndex, uint256 depositDate) {
        require(poolIndex < poolsLength, "Poolable: Invalid poolIndex");
        require(
            depositDate < block.timestamp,
            "Poolable: Invalid deposit date"
        );
        require(
            block.timestamp - depositDate >= _pools[poolIndex].lockDuration,
            "Poolable: Not unlocked"
        );
        _;
    }

    /**
     * @notice Initializer
     */
    function __Poolable_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Poolable_init_unchained();
    }

    function __Poolable_init_unchained() internal onlyInitializing {}

    function getPool(uint256 poolIndex) public view returns (Pool memory) {
        require(poolIndex < poolsLength, "Poolable: Invalid poolIndex");
        return _pools[poolIndex];
    }

    function addPool(Pool calldata pool) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 poolIndex = poolsLength;

        _pools[poolIndex] = Pool({
            lockDuration: pool.lockDuration,
            opened: pool.opened
        });
        poolsLength = poolsLength + 1;

        emit PoolAdded(poolIndex, _pools[poolIndex]);
    }

    function updatePool(uint256 poolIndex, Pool calldata pool)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(poolIndex < poolsLength, "Poolable: Invalid poolIndex");
        Pool storage editedPool = _pools[poolIndex];

        editedPool.lockDuration = pool.lockDuration;
        editedPool.opened = pool.opened;

        emit PoolUpdated(poolIndex, editedPool);
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/** @title Depositable.
@dev It is a contract that allow to deposit an ERC20 token
*/
abstract contract Depositable is Initializable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    // Map of deposits per address
    mapping(address => uint256) private _deposits;

    // the deposited token
    IERC20Upgradeable public depositToken;

    // the total amount deposited
    uint256 public totalDeposit;

    /**
     * @dev Emitted when `amount` tokens are deposited to account (`to`)
     * Note that `amount` may be zero.
     */
    event Deposit(address indexed from, address indexed to, uint256 amount);

    /**
     * @dev Emitted when `amount` tokens are withdrawn to account (`to`)
     * Note that `amount` may be zero.
     */
    event Withdraw(address indexed to, uint256 amount);

    /**
     * @dev Emitted when the deposited token is changed by the admin
     */
    event DepositTokenChange(address indexed token);

    /**
     * @notice Intializer
     * @param _depositToken: the deposited token
     */
    function __Depositable_init(IERC20Upgradeable _depositToken)
        internal
        onlyInitializing
    {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __Depositable_init_unchained(_depositToken);
    }

    function __Depositable_init_unchained(IERC20Upgradeable _depositToken)
        internal
        onlyInitializing
    {
        depositToken = _depositToken;
    }

    /**
     * @dev Handle the deposit (transfer) of `amount` tokens from the `from` address
     * The contract must be approved to spend the tokens from the `from` address before calling this function
     * @param from: the depositor address
     * @param to: the credited address
     * @param amount: amount of token to deposit
     * @return the amount deposited
     */
    function _deposit(
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (uint256) {
        // transfer tokens and check the real amount received
        uint256 balance = depositToken.balanceOf(address(this));
        depositToken.safeTransferFrom(from, address(this), amount);
        uint256 newBalance = depositToken.balanceOf(address(this));

        // replace amount by the real transferred amount
        amount = newBalance.sub(balance);

        // save deposit
        _deposits[to] = _deposits[to].add(amount);
        totalDeposit = totalDeposit.add(amount);
        emit Deposit(from, to, amount);

        return amount;
    }

    /**
     * @dev Remove `amount` tokens from the `to` address deposit balance, and transfer the tokens to the `to` address
     * @param to: the destination address
     * @param amount: amount of token to deposit
     * @return the amount withdrawn
     */
    function _withdraw(address to, uint256 amount)
        internal
        virtual
        returns (uint256)
    {
        require(amount <= _deposits[to], "Depositable: amount too high");

        _deposits[to] = _deposits[to].sub(amount);
        totalDeposit = totalDeposit.sub(amount);
        depositToken.safeTransfer(to, amount);

        emit Withdraw(to, amount);
        return amount;
    }

    /**
     * @notice get the total amount deposited by an address
     */
    function depositOf(address _address) public view virtual returns (uint256) {
        return _deposits[_address];
    }

    /**
     * @notice Change the deposited token
     */
    function changeDepositToken(IERC20Upgradeable _depositToken)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(totalDeposit == 0, "Depositable: total deposit != 0");
        depositToken = _depositToken;

        emit DepositTokenChange(address(_depositToken));
    }

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
        __ERC165_init_unchained();
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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
interface IERC165Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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
// OpenZeppelin Contracts v4.4.0 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

/** @title ITierable contract interface.
 */
interface ITierable {
    function tierOf(address account) external returns (int256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    function __Pausable_init() internal onlyInitializing {
        __Context_init_unchained();
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

/** @title PoolVestingable.
@dev This contract manage configuration of vesting pools
*/
abstract contract PoolVestingable is Initializable, AccessControlUpgradeable {
    using SafeMathUpgradeable for uint256;

    struct VestingPool {
        uint256[] timestamps; // Timestamp at which the associated ratio is available.
        uint256[] ratiosPerHundredThousand; // Ratio of initial amount to be available at the associated timestamp in / 100,000 (100% = 100,000, 1% = 1,000)
    }

    // pools
    VestingPool[] private _pools;

    /**
     * @dev Emitted when a pool is created
     */
    event VestingPoolAdded(uint256 poolIndex, VestingPool pool);

    /**
     * @dev Emitted when a pool is updated
     */
    event VestingPoolUpdated(uint256 poolIndex, VestingPool pool);

    /**
     * @dev Modifier that checks pool is valid
     */
    modifier checkVestingPool(VestingPool calldata pool) {
        // check length of timestamps and ratiosPerHundredThousand are equal
        require(
            pool.timestamps.length == pool.ratiosPerHundredThousand.length,
            "PoolVestingable: Number of timestamps is not equal to number of ratios"
        );

        // check the timestamps are increasing
        // start at i = 1
        for (uint256 i = 1; i < pool.timestamps.length; i++) {
            require(
                pool.timestamps[i - 1] < pool.timestamps[i],
                "PoolVestingable: Timestamps be asc ordered"
            );
        }

        // check sum of ratios = 100,000
        uint256 totalRatio = 0;
        for (uint256 i = 0; i < pool.ratiosPerHundredThousand.length; i++) {
            totalRatio = totalRatio.add(pool.ratiosPerHundredThousand[i]);
        }
        require(
            totalRatio == 100000,
            "PoolVestingable: Sum of ratios per thousand must be equal to 100,000"
        );

        _;
    }

    /**
     * @notice Initializer
     */
    function __PoolVestingable_init() internal onlyInitializing {
        __Context_init_unchained();
        __ERC165_init_unchained();
        __AccessControl_init_unchained();
        __PoolVestingable_init_unchained();
    }

    function __PoolVestingable_init_unchained() internal onlyInitializing {}

    function getVestingPool(uint256 poolIndex)
        public
        view
        returns (VestingPool memory)
    {
        require(
            poolIndex < _pools.length,
            "PoolVestingable: Invalid poolIndex"
        );
        return _pools[poolIndex];
    }

    function vestingPoolsLength() public view returns (uint256) {
        return _pools.length;
    }

    function addVestingPool(VestingPool calldata pool)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        checkVestingPool(pool)
    {
        _pools.push(
            VestingPool({
                timestamps: pool.timestamps,
                ratiosPerHundredThousand: pool.ratiosPerHundredThousand
            })
        );

        emit VestingPoolAdded(_pools.length - 1, _pools[_pools.length - 1]);
    }

    function updateVestingPool(uint256 poolIndex, VestingPool calldata pool)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        checkVestingPool(pool)
    {
        require(
            poolIndex < _pools.length,
            "PoolVestingable: Invalid poolIndex"
        );
        VestingPool storage editedPool = _pools[poolIndex];

        editedPool.timestamps = pool.timestamps;
        editedPool.ratiosPerHundredThousand = pool.ratiosPerHundredThousand;

        emit VestingPoolUpdated(poolIndex, editedPool);
    }

    uint256[50] private __gap;
}