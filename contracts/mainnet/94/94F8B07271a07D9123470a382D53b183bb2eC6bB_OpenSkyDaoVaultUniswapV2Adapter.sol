// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Context.sol';

import '../dependencies/uniswap-v2/IUniswapV2Router02.sol';
import '../interfaces/IOpenSkySettings.sol';
import '../interfaces/IACLManager.sol';

import '../interfaces/IOpenSkyDaoVaultUniswapV2Adapter.sol';

/**
 * @dev Provide swap services for OpenSkyDaoVault contract.
 * - OpenSkyDaoVault should approve 'amount' of 'token' to this contract first
 * - Receiver of swap is always OpenSkyDaoVault
 * - Only callable by governance
 */
contract OpenSkyDaoVaultUniswapV2Adapter is Context, IOpenSkyDaoVaultUniswapV2Adapter {
    using SafeERC20 for IERC20;

    IOpenSkySettings public immutable SETTINGS;
    address public immutable WETH_ADDRESS;
    address public immutable DAO_VAULT_ADDRESS;
    IUniswapV2Router02 public immutable UNISWAP_ROUTER;

    modifier onlyGovernance() {
        IACLManager ACLManager = IACLManager(SETTINGS.ACLManagerAddress());
        require(ACLManager.isGovernance(_msgSender()), 'ACL_ONLY_GOVERNANCE_CAN_CALL');
        _;
    }

    constructor(
        address settingsAddress,
        address daoVaultAddress,
        address uniswapRouterAddress,
        address wethAddress
    ) {
        SETTINGS = IOpenSkySettings(settingsAddress);
        DAO_VAULT_ADDRESS = daoVaultAddress;
        UNISWAP_ROUTER = IUniswapV2Router02(uniswapRouterAddress);
        WETH_ADDRESS = wethAddress;
    }

    function pullERC20FromDaoVault(address token, uint256 amount) public onlyGovernance {
        IERC20(token).safeTransferFrom(DAO_VAULT_ADDRESS, address(this), amount);
    }

    function swapExactTokensForTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 amountToSwap,
        uint256 minAmountOut,
        bool useEthPath
    ) external onlyGovernance returns (uint256) {
        // step1: pull asset
        pullERC20FromDaoVault(assetToSwapFrom, amountToSwap);

        // step2: approve
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), 0);
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), amountToSwap);

        // step3: swap
        address[] memory path;
        if (useEthPath) {
            path = new address[](3);
            path[0] = assetToSwapFrom;
            path[1] = WETH_ADDRESS;
            path[2] = assetToSwapTo;
        } else {
            path = new address[](2);
            path[0] = assetToSwapFrom;
            path[1] = assetToSwapTo;
        }

        uint256[] memory amounts = UNISWAP_ROUTER.swapExactTokensForTokens(
            amountToSwap,
            minAmountOut,
            path,
            DAO_VAULT_ADDRESS,
            block.timestamp
        );

        emit Swapped(assetToSwapFrom, assetToSwapTo, amounts[0], amounts[amounts.length - 1]);

        return amounts[amounts.length - 1];
    }

    function swapTokensForExactTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 maxAmountToSwap,
        uint256 amountToReceive,
        bool useEthPath
    ) external onlyGovernance returns (uint256) {
        // step1 pull asset
        pullERC20FromDaoVault(assetToSwapFrom, maxAmountToSwap);

        // step2: approve
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), 0);
        IERC20(assetToSwapFrom).safeApprove(address(UNISWAP_ROUTER), maxAmountToSwap);

        // step3: swap
        address[] memory path;
        if (useEthPath) {
            path = new address[](3);
            path[0] = assetToSwapFrom;
            path[1] = WETH_ADDRESS;
            path[2] = assetToSwapTo;
        } else {
            path = new address[](2);
            path[0] = assetToSwapFrom;
            path[1] = assetToSwapTo;
        }

        uint256[] memory amounts = UNISWAP_ROUTER.swapTokensForExactTokens(
            amountToReceive,
            maxAmountToSwap,
            path,
            DAO_VAULT_ADDRESS,
            block.timestamp
        );

        emit Swapped(assetToSwapFrom, assetToSwapTo, amounts[0], amounts[amounts.length - 1]);

        return amounts[0];
    }

    /**
     * @dev Emergency rescue for token stuck on this contract, as failsafe mechanism
     * - Funds should never remain in this contract more time than during transactions
     * - Only callable by governance
     **/
    function rescueTokens(IERC20 token) external onlyGovernance {
        token.safeTransfer(DAO_VAULT_ADDRESS, token.balanceOf(address(this)));
    }
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

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

pragma solidity 0.8.10;

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import '../libraries/types/DataTypes.sol';

interface IOpenSkySettings {
    event InitPoolAddress(address operator, address address_);
    event InitLoanAddress(address operator, address address_);
    event InitVaultFactoryAddress(address operator, address address_);
    event InitIncentiveControllerAddress(address operator, address address_);
    event InitWETHGatewayAddress(address operator, address address_);
    event InitPunkGatewayAddress(address operator, address address_);
    event InitDaoVaultAddress(address operator, address address_);

    event AddToWhitelist(address operator, uint256 reserveId, address nft);
    event RemoveFromWhitelist(address operator, uint256 reserveId, address nft);
    event SetReserveFactor(address operator, uint256 factor);
    event SetPrepaymentFeeFactor(address operator, uint256 factor);
    event SetOverdueLoanFeeFactor(address operator, uint256 factor);
    event SetMoneyMarketAddress(address operator, address address_);
    event SetTreasuryAddress(address operator, address address_);
    event SetACLManagerAddress(address operator, address address_);
    event SetLoanDescriptorAddress(address operator, address address_);
    event SetNftPriceOracleAddress(address operator, address address_);
    event SetInterestRateStrategyAddress(address operator, address address_);
    event AddLiquidator(address operator, address address_);
    event RemoveLiquidator(address operator, address address_);

    function poolAddress() external view returns (address);

    function loanAddress() external view returns (address);

    function vaultFactoryAddress() external view returns (address);

    function incentiveControllerAddress() external view returns (address);

    function wethGatewayAddress() external view returns (address);

    function punkGatewayAddress() external view returns (address);

    function inWhitelist(uint256 reserveId, address nft) external view returns (bool);

    function getWhitelistDetail(uint256 reserveId, address nft) external view returns (DataTypes.WhitelistInfo memory);

    function reserveFactor() external view returns (uint256); // treasury ratio

    function MAX_RESERVE_FACTOR() external view returns (uint256);

    function prepaymentFeeFactor() external view returns (uint256);

    function overdueLoanFeeFactor() external view returns (uint256);

    function moneyMarketAddress() external view returns (address);

    function treasuryAddress() external view returns (address);

    function daoVaultAddress() external view returns (address);

    function ACLManagerAddress() external view returns (address);

    function loanDescriptorAddress() external view returns (address);

    function nftPriceOracleAddress() external view returns (address);

    function interestRateStrategyAddress() external view returns (address);
    
    function isLiquidator(address liquidator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IACLManager {
    function addEmergencyAdmin(address admin) external;
    
    function isEmergencyAdmin(address admin) external view returns (bool);
    
    function removeEmergencyAdmin(address admin) external;
    
    function addGovernance(address admin) external;
    
    function isGovernance(address admin) external view returns (bool);

    function removeGovernance(address admin) external;

    function addPoolAdmin(address admin) external;

    function isPoolAdmin(address admin) external view returns (bool);

    function removePoolAdmin(address admin) external;

    function addLiquidationOperator(address address_) external;

    function isLiquidationOperator(address address_) external view returns (bool);

    function removeLiquidationOperator(address address_) external;

    function addAirdropOperator(address address_) external;

    function isAirdropOperator(address address_) external view returns (bool);

    function removeAirdropOperator(address address_) external;
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IOpenSkyDaoVaultUniswapV2Adapter {
    event Swapped(address fromAsset, address toAsset, uint256 fromAmount, uint256 receivedAmount);

    function pullERC20FromDaoVault(address token, uint256 amount) external;

    function swapExactTokensForTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 amountToSwap,
        uint256 minAmountOut,
        bool useEthPath
    ) external returns (uint256);

    function swapTokensForExactTokens(
        address assetToSwapFrom,
        address assetToSwapTo,
        uint256 maxAmountToSwap,
        uint256 amountToReceive,
        bool useEthPath
    ) external returns (uint256);
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
pragma solidity 0.8.10;

library DataTypes {
    struct ReserveData {
        uint256 reserveId;
        address underlyingAsset;
        address oTokenAddress;
        address moneyMarketAddress;
        uint128 lastSupplyIndex;
        uint256 borrowingInterestPerSecond;
        uint256 lastMoneyMarketBalance;
        uint40 lastUpdateTimestamp;
        uint256 totalBorrows;
        address interestModelAddress;
        uint256 treasuryFactor;
        bool isMoneyMarketOn;
    }

    struct LoanData {
        uint256 reserveId;
        address nftAddress;
        uint256 tokenId;
        address borrower;
        uint256 amount;
        uint128 borrowRate;
        uint128 interestPerSecond;
        uint40 borrowBegin;
        uint40 borrowDuration;
        uint40 borrowOverdueTime;
        uint40 liquidatableTime;
        uint40 extendableTime;
        uint40 borrowEnd;
        LoanStatus status;
    }

    enum LoanStatus {
        NONE,
        BORROWING,
        EXTENDABLE,
        OVERDUE,
        LIQUIDATABLE,
        LIQUIDATING
    }

    struct WhitelistInfo {
        bool enabled;
        string name;
        string symbol;
        uint256 LTV;
        uint256 minBorrowDuration;
        uint256 maxBorrowDuration;
        uint256 extendableDuration;
        uint256 overdueDuration;
    }
}