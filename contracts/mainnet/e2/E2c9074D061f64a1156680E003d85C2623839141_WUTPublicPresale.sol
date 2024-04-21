// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.4;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IERC20Detailed is IERC20Upgradeable {
    function decimals() external returns (uint8);
}

contract WUTPublicPresale is ReentrancyGuardUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    // Constants
    uint256 public constant EXTRA_PRICE = 3;
    uint256 public constant MAX_ALLOCATION = 3_000_000 * 10**18;

    uint256 public constant PIRANHA_ALLOCATION_FACTOR = 3000; // 30%
    uint256 public constant WHALE_ALLOCATION_FACTOR = 3000; // 30%

    uint256 public PIRANHA_BLOCKS_COUNT;
    uint256 public MIN_WHALE_DEPOSIT;
    uint256 public SOFT_CAP;
    uint256 public HARD_CAP;
    uint256 public MIN_TOTAL_DEPOSIT;

    uint256 public REL; // WUT / Sale Token decimals relation

    // Parameters
    uint256 public firstStageStartBlock;
    uint256 public secondStageStartBlock;
    uint256 public presaleEndBlock;

    address public treasurer;
    IERC20Upgradeable public saleToken;
    IERC20Upgradeable public WUT;

    // State
    bool public allowClaim;
    bool public successfulPresale;

    uint256 public totalDeposit;
    mapping(address => uint256) public depositOf;

    uint256 public piranhaTotalDeposit;
    mapping(address => uint256) public piranhaDepositOf;

    uint256 public whaleTotalDeposit;
    mapping(address => uint256) public whaleDepositOf;

    uint256 public sharkTotalDeposit;
    mapping(address => uint256) public sharkDepositOf;

    // Events
    event Deposit(address indexed investor, uint256 amount, uint256 investorDeposit, uint256 totalDeposit);
    event Withdraw(address indexed investor, uint256 amount, uint256 investorDeposit, uint256 totalDeposit);
    event Claim(address indexed investor, uint256 claimAmount, uint256 depositAmount);

    event WhaleDeposit(
        address indexed investor,
        uint256 amount,
        uint256 investorWhaleDeposit,
        uint256 whaleTotalDeposit
    );
    event PiranhaDeposit(
        address indexed investor,
        uint256 amount,
        uint256 investorPiranhaDeposit,
        uint256 piranhaTotalDeposit
    );
    event WhaleWithdraw(
        address indexed investor,
        uint256 amount,
        uint256 investorWhaleDeposit,
        uint256 whaleTotalDeposit
    );
    event PiranhaWithdraw(
        address indexed investor,
        uint256 amount,
        uint256 investorPiranhaDeposit,
        uint256 piranhaTotalDeposit
    );

    event CloseSale(bool successful, uint256 totalInvested, uint256 totalAllocation);

    // Libraries
    using SafeERC20Upgradeable for IERC20Upgradeable;

    function initialize(
        uint256 _firstStageStartBlock,
        uint256 _secondStageStartBlock,
        uint256 _presaleEndBlock,
        uint256 _fastestBlocks,
        uint256 _minWhaleDeposit,
        address _saleToken,
        address _wut,
        address _treasurer
    ) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        firstStageStartBlock = _firstStageStartBlock;
        secondStageStartBlock = _secondStageStartBlock;
        presaleEndBlock = _presaleEndBlock;
        PIRANHA_BLOCKS_COUNT = _fastestBlocks;

        treasurer = _treasurer;
        saleToken = IERC20Upgradeable(_saleToken);
        WUT = IERC20Upgradeable(_wut);

        uint256 dec = IERC20Detailed(_saleToken).decimals();

        SOFT_CAP = 1_000_000 * 10**dec;
        HARD_CAP = 7_000_000 * 10**dec;
        REL = 10**(18 - dec);
        MIN_TOTAL_DEPOSIT = 100_000 * 10**dec;
        MIN_WHALE_DEPOSIT = _minWhaleDeposit;
    }

    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(block.number >= firstStageStartBlock, "Public presale is not active yet");
        require(block.number < secondStageStartBlock, "Unable to deposit after second stage starts");
        saleToken.safeTransferFrom(_msgSender(), address(this), amount);

        if (depositOf[_msgSender()] >= MIN_WHALE_DEPOSIT) {
            whaleTotalDeposit += amount;
            whaleDepositOf[_msgSender()] += amount;
            emit WhaleDeposit(_msgSender(), amount, whaleDepositOf[_msgSender()], whaleTotalDeposit);
        } else if (depositOf[_msgSender()] + amount >= MIN_WHALE_DEPOSIT) {
            whaleTotalDeposit += depositOf[_msgSender()] + amount;
            whaleDepositOf[_msgSender()] += depositOf[_msgSender()] + amount;
            emit WhaleDeposit(_msgSender(), amount, whaleDepositOf[_msgSender()], whaleTotalDeposit);
        }

        if (block.number - firstStageStartBlock <= PIRANHA_BLOCKS_COUNT) {
            piranhaTotalDeposit += amount;
            piranhaDepositOf[_msgSender()] += amount;
            emit PiranhaDeposit(_msgSender(), amount, piranhaDepositOf[_msgSender()], piranhaTotalDeposit);
        }

        if (
            depositOf[_msgSender()] + amount >= MIN_WHALE_DEPOSIT &&
            sharkDepositOf[_msgSender()] != piranhaDepositOf[_msgSender()]
        ) {
            sharkTotalDeposit -= sharkDepositOf[_msgSender()];
            sharkTotalDeposit += piranhaDepositOf[_msgSender()];
            sharkDepositOf[_msgSender()] = piranhaDepositOf[_msgSender()];
        }

        totalDeposit += amount;
        depositOf[_msgSender()] += amount;

        emit Deposit(_msgSender(), amount, depositOf[_msgSender()], totalDeposit);
    }

    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(block.number < presaleEndBlock, "Unable to withdraw funds after presale ends");
        require(amount > 0, "Unable to withdraw 0 amount");

        totalDeposit -= amount;
        depositOf[_msgSender()] -= amount;

        if (whaleDepositOf[_msgSender()] >= amount + MIN_WHALE_DEPOSIT) {
            whaleDepositOf[_msgSender()] -= amount;
            whaleTotalDeposit -= amount;
            emit WhaleWithdraw(_msgSender(), amount, whaleDepositOf[_msgSender()], whaleTotalDeposit);
        } else if (whaleDepositOf[_msgSender()] > 0) {
            whaleTotalDeposit -= whaleDepositOf[_msgSender()];
            whaleDepositOf[_msgSender()] = 0;
            if (sharkDepositOf[_msgSender()] > 0) {
                sharkTotalDeposit -= sharkDepositOf[_msgSender()];
                sharkDepositOf[_msgSender()] = 0;
            }
            emit WhaleWithdraw(_msgSender(), amount, whaleDepositOf[_msgSender()], whaleTotalDeposit);
        }

        if (piranhaDepositOf[_msgSender()] > amount) {
            piranhaDepositOf[_msgSender()] -= amount;
            piranhaTotalDeposit -= amount;
            emit PiranhaWithdraw(_msgSender(), amount, piranhaDepositOf[_msgSender()], piranhaTotalDeposit);
        } else if (piranhaDepositOf[_msgSender()] > 0) {
            piranhaTotalDeposit -= piranhaDepositOf[_msgSender()];
            piranhaDepositOf[_msgSender()] = 0;
            if (sharkDepositOf[_msgSender()] > 0) {
                sharkTotalDeposit -= sharkDepositOf[_msgSender()];
                sharkDepositOf[_msgSender()] = 0;
            }
            emit PiranhaWithdraw(_msgSender(), amount, piranhaDepositOf[_msgSender()], piranhaTotalDeposit);
        }

        if (sharkDepositOf[_msgSender()] >= amount) {
            sharkDepositOf[_msgSender()] -= amount;
            sharkTotalDeposit -= amount;
        } else {
            sharkTotalDeposit -= sharkDepositOf[_msgSender()];
            sharkDepositOf[_msgSender()] = 0;
        }

        saleToken.safeTransfer(_msgSender(), amount);
        emit Withdraw(_msgSender(), amount, depositOf[_msgSender()], totalDeposit);
    }

    function claim() external nonReentrant whenNotPaused {
        require(allowClaim, "Unable to claim WUT before presale ends");
        uint256 depositAmount = depositOf[_msgSender()];

        if (successfulPresale) {
            uint256 claimAmount = calcClaimAmount(_msgSender());
            uint256 usedDeposit = (claimAmount * min(totalDeposit, HARD_CAP)) / calcTotalAllocation();
            uint256 returnAmount = depositAmount > usedDeposit ? depositAmount - usedDeposit : 0;
            WUT.safeTransfer(_msgSender(), min(claimAmount, WUT.balanceOf(address(this))));
            if (returnAmount > 0) {
                saleToken.transfer(_msgSender(), min(returnAmount, saleToken.balanceOf(address(this))));
            }
            if (claimAmount > 0) {
                emit Claim(_msgSender(), claimAmount, depositAmount);
            }
        } else {
            saleToken.transfer(_msgSender(), depositAmount);
        }

        depositOf[_msgSender()] = 0;
        whaleDepositOf[_msgSender()] = 0;
        piranhaDepositOf[_msgSender()] = 0;
        sharkDepositOf[_msgSender()] = 0;
    }

    function drawOut() external nonReentrant {
        require(block.number >= presaleEndBlock, "Unable to draw out funds before presale ends");
        require(!allowClaim, "Unable to draw out funds twice");
        uint256 wutBalance = WUT.balanceOf(address(this));

        if (totalDeposit >= MIN_TOTAL_DEPOSIT) {
            saleToken.safeTransfer(treasurer, min(totalDeposit, HARD_CAP));
            uint256 totalAllocation = calcTotalAllocation();
            require(
                wutBalance >= totalAllocation,
                "Unable to draw out funds before depositing allocated amount of WUT"
            );
            if (wutBalance > totalAllocation) {
                WUT.safeTransfer(treasurer, wutBalance - totalAllocation);
            }
            successfulPresale = true;
            emit CloseSale(true, min(totalDeposit, HARD_CAP), totalAllocation);
        } else {
            WUT.safeTransfer(treasurer, wutBalance);
            emit CloseSale(false, totalDeposit, 0);
        }

        if (!allowClaim) {
            allowClaim = true;
        }
    }

    function balanceOf(address investor)
        external
        view
        returns (
            uint256 depositAmount,
            uint256 claimAmount,
            uint256 returnAmount
        )
    {
        depositAmount = depositOf[investor];
        claimAmount = calcClaimAmount(investor);
        uint256 totalAllocation = calcTotalAllocation();
        if (totalAllocation > 0) {
            uint256 usedDeposit = (claimAmount * min(totalDeposit, HARD_CAP)) / totalAllocation;
            returnAmount = depositAmount > usedDeposit ? depositAmount - usedDeposit : 0;
        }
    }

    struct Parts {
        uint256 piranha;
        uint256 whale;
        uint256 seal;
    }

    function calcClaimAmount(address investor) internal view returns (uint256) {
        if (totalDeposit == 0) {
            return 0;
        }

        uint256 totalInvested = min(totalDeposit, HARD_CAP);
        (
            uint256 totalAllocation,
            uint256 whaleAllocation,
            uint256 piranhaAllocation,
            uint256 sealAllocation
        ) = calcAllocations(totalInvested);

        uint256 piranhaSpent = (piranhaAllocation * totalInvested) / totalAllocation;

        Parts memory parts;
        parts.piranha = calcPiranhaPart(investor, piranhaAllocation);
        parts.whale = calcWhalePart(
            investor,
            piranhaSpent,
            parts.piranha,
            whaleAllocation,
            totalInvested,
            totalAllocation
        );
        uint256 a = (parts.piranha * totalInvested) / totalAllocation + (parts.whale * totalInvested) / totalAllocation;
        parts.seal = depositOf[investor] > a
            ? ((depositOf[investor] - a) * sealAllocation) /
                (totalDeposit -
                    (piranhaAllocation * totalInvested) /
                    totalAllocation -
                    (whaleAllocation * totalInvested) /
                    totalAllocation)
            : 0;

        return parts.seal + parts.piranha + parts.whale;
    }

    function calcPiranhaPart(address investor, uint256 piranhaAllocation) private view returns (uint256) {
        uint256 _piranhaTotalDeposit = piranhaTotalDeposit;
        return _piranhaTotalDeposit > 0 ? (piranhaDepositOf[investor] * piranhaAllocation) / _piranhaTotalDeposit : 0;
    }

    function calcWhalePart(
        address investor,
        uint256 piranhaSpent,
        uint256 piranhaPart,
        uint256 whaleAllocation,
        uint256 totalInvested,
        uint256 totalAllocation
    ) private view returns (uint256) {
        uint256 _piranhaTotalDeposit = piranhaTotalDeposit;
        uint256 whaleShare = whaleTotalDeposit -
            (_piranhaTotalDeposit > 0 ? (sharkTotalDeposit * piranhaSpent) / _piranhaTotalDeposit : 0);
        uint256 p = (piranhaPart * totalInvested) / totalAllocation;
        return
            whaleShare > 0
                ? (whaleDepositOf[investor] > p ? ((whaleDepositOf[investor] - p) * whaleAllocation) / whaleShare : 0)
                : 0;
    }

    function calcAllocations(uint256 totalInvested)
        public
        view
        returns (
            uint256 totalAllocation,
            uint256 whaleAllocation,
            uint256 piranhaAllocation,
            uint256 sealAllocation
        )
    {
        uint256 invested = min(HARD_CAP, totalInvested);
        totalAllocation = calcTotalAllocation();
        whaleAllocation = min(
            (whaleTotalDeposit * totalAllocation) / invested,
            (totalAllocation * WHALE_ALLOCATION_FACTOR) / 10_000
        );
        piranhaAllocation = min(
            (piranhaTotalDeposit * totalAllocation) / invested,
            (totalAllocation * PIRANHA_ALLOCATION_FACTOR) / 10_000
        );
        sealAllocation = totalAllocation - whaleAllocation - piranhaAllocation;
    }

    function calcTotalAllocation() private view returns (uint256) {
        uint256 totalAllocation = (1_000_000 * 10**18) +
            (totalDeposit > SOFT_CAP ? ((totalDeposit - SOFT_CAP) * REL) / EXTRA_PRICE : 0);
        return min(totalAllocation, MAX_ALLOCATION);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
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
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

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
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = _setInitializedVersion(1);
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
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        bool isTopLevelCall = _setInitializedVersion(version);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(version);
        }
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
     */
    function _disableInitializers() internal virtual {
        _setInitializedVersion(type(uint8).max);
    }

    function _setInitializedVersion(uint8 version) private returns (bool) {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, and for the lowest level
        // of initializers, because in other contexts the contract may have been reentered.
        if (_initializing) {
            require(
                version == 1 && !AddressUpgradeable.isContract(address(this)),
                "Initializable: contract is already initialized"
            );
            return false;
        } else {
            require(_initialized < version, "Initializable: contract is already initialized");
            _initialized = version;
            return true;
        }
    }
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
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