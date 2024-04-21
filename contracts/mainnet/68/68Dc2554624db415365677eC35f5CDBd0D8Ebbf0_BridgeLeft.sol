// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "SafeERC20.sol";
import "Ownable.sol";
import "EnumerableSet.sol";
import "ReentrancyGuard.sol";

import "IUniswapV2Router02.sol";
//import "IUniswapV2Router02.sol";


/** @title BridgeLeft
  * @notice user wants to make a payment for an order
  *   orderId: 42
  *   orderUSDAmount: 123
  *
  * call paymentERC20(orderId=42, orderUSDAmount=123, payableToken=XXX, ...) or paymentERC20 or paymentETH
  *       |
  *       |   ~ contract adds serviceFee
  *       |   ~ contract swaps payableToken to stablecoin
  *       |__________________
  *       |                  |
  *       V                  V
  *   destination       serviceFeeTreasury
**/
contract BridgeLeft is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // we always pass USD with 6 decimals
    // in functions: estimateFee, paymentStablecoin, estimatePayableTokenAmount, paymentERC20, paymentETH
    uint256 constant public USD_DECIMALS = 6;

    uint256 internal constant ONE_PERCENT = 100;  // 1%
    uint256 public constant FEE_DENOMINATOR = 100 * ONE_PERCENT;  // 100%
    uint256 public feeNumerator = 5 * ONE_PERCENT;

    address public serviceFeeTreasury;  // this is a service fee for the project support

    bool public whitelistAllTokens;  // do we want to accept all erc20 token as a payment? todo: be careful with deflationary etc
    EnumerableSet.AddressSet internal _whitelistTokens;  // erc20 tokens we accept as a payment (before swap)  //todo gas optimisations
    EnumerableSet.AddressSet internal _whitelistStablecoins;  // stablecoins we accept as a final payment method  //todo gas optimisations
    mapping (address => uint256) public stablecoinDecimals;

    address immutable public router;  // dex router we use todo: maybe make it updateable or just deploy new contract?

    // we need orderId
    // if someone from 2 different browsers will try to make a payment, the backend
    // will not be able to understand which transfer match which order
    // we also need (user -> order -> flag) mapping because if we use (order -> flag) mapping
    // other malicious user may front-run the client and make him sad :-(
    mapping (address /*user*/ => mapping (bytes16 /*orderId*/ => bool)) public userPaidOrders;

    event ServiceFeeTreasurySet(address indexed value);
    event WhitelistAllTokensSet(bool value);
    event TokenAddedToWhitelistStablecoins(address indexed token, uint256 decimals);
    event TokenAddedToWhitelist(address indexed token);
    event TokenRemovedFromWhitelistStablecoins(address indexed token);
    event TokenRemovedFromWhitelist(address indexed token);
    event OrderPaid(
        bytes16 orderId,
        uint256 orderUSDAmount,
        address destination,
        address payer,
        address payableToken,
        uint256 payableTokenAmount,
        address stablecoin,
        uint256 serviceFeeUSDAmount
    );

    constructor(
        address routerAddress,
        address serviceFeeTreasuryAddress
    ) {
        require(routerAddress != address(0), "zero address");
        router = routerAddress;

        require(serviceFeeTreasuryAddress != address(0), "zero address");
        serviceFeeTreasury = serviceFeeTreasuryAddress;
    }

    function setServiceFeeTreasury(address serviceFeeTreasuryAddress) external onlyOwner {
        require(serviceFeeTreasuryAddress != address(0), "zero address");
        serviceFeeTreasury = serviceFeeTreasuryAddress;
        emit ServiceFeeTreasurySet(serviceFeeTreasuryAddress);
    }

    function setWhitelistAllTokens(bool value) external onlyOwner {
        whitelistAllTokens = value;
        emit WhitelistAllTokensSet(value);
    }

    function getWhitelistedTokens() external view returns(address[] memory) {
        uint256 length = _whitelistTokens.length();
        address[] memory result = new address[](length);
        for (uint256 i=0; i < length; ++i) {
            result[i] = _whitelistTokens.at(i);
        }
        return result;
    }

    function getWhitelistedStablecoins() external view returns(address[] memory) {
        uint256 length = _whitelistStablecoins.length();
        address[] memory result = new address[](length);
        for (uint256 i=0; i < length; ++i) {
            result[i] = _whitelistStablecoins.at(i);
        }
        return result;
    }

    function isTokenWhitelisted(address token) external view returns(bool) {
        return _whitelistTokens.contains(token);
    }

    function isWhitelistedStablecoin(address token) public view returns(bool) {
        return _whitelistStablecoins.contains(token);
    }

    modifier onlyWhitelistedTokenOrAllWhitelisted(address token) {
        require(whitelistAllTokens || _whitelistTokens.contains(token), "not whitelisted");
        _;
    }

    function addTokenToWhitelist(address token) external onlyOwner {
        require(_whitelistTokens.add(token), "already whitelisted");
        emit TokenAddedToWhitelist(token);
    }

    function removeTokenFromWhitelist(address token) external onlyOwner {
        require(_whitelistTokens.remove(token), "not whitelisted");
        emit TokenRemovedFromWhitelist(token);
    }

    function addTokenToWhitelistStablecoins(address token, uint256 decimals) external onlyOwner {
        require(_whitelistStablecoins.add(token), "already whitelisted stablecoin");
        stablecoinDecimals[token] = decimals;
        emit TokenAddedToWhitelistStablecoins(token, decimals);
    }

    function removeTokenFromWhitelistStablecoins(address token) external onlyOwner {
        require(_whitelistStablecoins.remove(token), "not whitelisted stablecoin");
        delete stablecoinDecimals[token];
        emit TokenRemovedFromWhitelistStablecoins(token);
    }

    function setFeeNumerator(uint256 newFeeNumerator) external onlyOwner {
        require(newFeeNumerator <= 1000, "Max fee numerator: 1000");
        feeNumerator = newFeeNumerator;
    }

    // ==== payment

    function estimateFee(
        uint256 orderUSDAmount  // 6 decimals
    ) view external returns(uint256) {
        return orderUSDAmount * feeNumerator / FEE_DENOMINATOR;
    }

    // not supporting deflationary or transfer-fee stablecoin (warning: usdt IS transfer-fee stablecoin but fee=0 now)
    function paymentStablecoin(
        bytes16 orderId,
        uint256 orderUSDAmount,  // 6 decimals
        address destination,
        address stablecoin
    ) external nonReentrant {
        require(destination != address(0), "zero address");
        require(!userPaidOrders[msg.sender][orderId], "order already paid");
        require(isWhitelistedStablecoin(stablecoin), "the end path is not stablecoin");
        userPaidOrders[msg.sender][orderId] = true;

        uint256 orderUSDAmountERC20DECIMALS = orderUSDAmount * (10 ** stablecoinDecimals[stablecoin]) / (10 ** USD_DECIMALS);
        uint256 feeStablecoinAmount = orderUSDAmount * feeNumerator / FEE_DENOMINATOR;
        uint256 feeStablecoinAmountERC20DECIMALS = feeStablecoinAmount * (10 ** stablecoinDecimals[stablecoin]) / (10 ** USD_DECIMALS);

        IERC20(stablecoin).safeTransferFrom(msg.sender, destination, orderUSDAmountERC20DECIMALS);
        IERC20(stablecoin).safeTransferFrom(msg.sender, serviceFeeTreasury, feeStablecoinAmountERC20DECIMALS);

        emit OrderPaid({
            orderId: orderId,
            orderUSDAmount: orderUSDAmount,
            destination: destination,
            payer: msg.sender,
            payableToken: stablecoin,
            payableTokenAmount: (orderUSDAmountERC20DECIMALS + feeStablecoinAmountERC20DECIMALS),
            stablecoin: stablecoin,
            serviceFeeUSDAmount: feeStablecoinAmount
        });
    }

    // view method to return how much tokens should be transferred
    function estimatePayableTokenAmount(
        uint256 orderUSDAmount,  // 6 decimals
        address[] calldata path
    ) external view onlyWhitelistedTokenOrAllWhitelisted(path[0]) returns(uint256) {
        require(isWhitelistedStablecoin(path[path.length-1]), "the end path is not stablecoin");
        uint256 orderUSDAmountERC20DECIMALS = orderUSDAmount * (10 ** stablecoinDecimals[path[path.length-1]]) / (10 ** USD_DECIMALS);
        uint256[] memory amounts = IUniswapV2Router02(router).getAmountsIn(orderUSDAmountERC20DECIMALS, path);
        return amounts[0];
    }

    // not supporting deflationary tokens (99.9% of cases)
    function paymentERC20(
        bytes16 orderId,
        uint256 orderUSDAmount,  // 6 decimals
        address destination,
        uint256 payableTokenMaxAmount,
        uint256 deadline,
        address[] calldata path
    ) external onlyWhitelistedTokenOrAllWhitelisted(path[0]) nonReentrant {
        require(destination != address(0), "zero address");
        require(!userPaidOrders[msg.sender][orderId], "order already paid");
        require(isWhitelistedStablecoin(path[path.length-1]), "the end path is not stablecoin");
        userPaidOrders[msg.sender][orderId] = true;

        uint256 orderUSDAmountERC20DECIMALS = orderUSDAmount * (10 ** stablecoinDecimals[path[path.length-1]]) / (10 ** USD_DECIMALS);
        uint256 feeStablecoinAmount = orderUSDAmount * feeNumerator / FEE_DENOMINATOR;

        uint256 amountIn;

        {
            uint256 feeStablecoinAmountERC20DECIMALS = feeStablecoinAmount * (10 ** stablecoinDecimals[path[path.length-1]]) / (10 ** USD_DECIMALS);
            uint256 totalAmountERC20DECIMALS = orderUSDAmountERC20DECIMALS + feeStablecoinAmountERC20DECIMALS;
            amountIn = IUniswapV2Router02(router).getAmountsIn(totalAmountERC20DECIMALS, path)[0];  // todo think about 2x cycle
            require(amountIn <= payableTokenMaxAmount, "insufficient payableTokenMaxAmount");
            IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
            IERC20(path[0]).safeApprove(router, amountIn);  // think: approve type(uint256).max once
            IUniswapV2Router02(router).swapExactTokensForTokens({
                amountIn: amountIn,
                amountOutMin: totalAmountERC20DECIMALS,
                path: path,
                to: address(this),
                deadline: deadline
            });
            IERC20(path[path.length-1]).safeTransfer(destination, orderUSDAmountERC20DECIMALS);
            IERC20(path[path.length-1]).safeTransfer(serviceFeeTreasury, feeStablecoinAmountERC20DECIMALS);
        }

        // no dust tokens are rest on the SC balance since we use getAmountsIn

        emit OrderPaid({
            orderId: orderId,
            orderUSDAmount: orderUSDAmount,
            destination: destination,
            payer: msg.sender,
            payableToken: path[0],
            payableTokenAmount: amountIn,
            stablecoin: path[path.length-1],
            serviceFeeUSDAmount: feeStablecoinAmount
        });
    }

    // supporting deflationary tokens (0.1% of cases)
    // todo think about it and test it well!
//    function paymentERC20SupportingFeeOnTransfer(
//        bytes16 orderId,
//        uint256 orderUSDAmount,
//        address destination,
//        uint256 payableTokenMaxAmount,
//        uint256 deadline,
//        address[] calldata path,
//        uint256 minTokensRestAmountToReturn
//    ) external onlyWhitelistedTokenOrAllWhitelisted(path[0]) nonReentrant {
//        address stablecoin = path[path.length-1];
//
//        require(destination != address(0), "zero address");
//        require(!userPaidOrders[msg.sender][orderId], "order already paid");
//        require(isWhitelistedStablecoin(stablecoin), "the end path is not stablecoin");
//        userPaidOrders[msg.sender][orderId] = true;
//
//        uint256 feeStablecoinAmount = orderUSDAmount * feeNumerator / FEE_DENOMINATOR;
//
//        uint256 contractStablecoinBalanceBefore = IERC20(stablecoin).balanceOf(address(this));
//        uint256 payableTokenReceivedAmount;
//
//        {
//            uint256 contractPayableTokenBalanceBefore = IERC20(path[0]).balanceOf(address(this));
//            IERC20(path[0]).safeTransferFrom(msg.sender, address(this), payableTokenMaxAmount);
//            uint256 contractPayableTokenBalanceAfterTransfer = IERC20(path[0]).balanceOf(address(this));
//            payableTokenReceivedAmount = contractPayableTokenBalanceAfterTransfer - contractPayableTokenBalanceBefore;
//        }
//
//        IERC20(path[0]).safeApprove(router, payableTokenReceivedAmount);
//
//        IUniswapV2Router02(router).swapExactTokensForTokensSupportingFeeOnTransferTokens({
//            amountIn: payableTokenReceivedAmount,
//            amountOutMin: orderUSDAmount + feeStablecoinAmount,
//            path: path,
//            to: address(this),
//            deadline: deadline
//        });
//
//        IERC20(stablecoin).safeTransfer(destination, orderUSDAmount);
//        IERC20(stablecoin).safeTransfer(serviceFeeTreasury, feeStablecoinAmount);
//
//        // send rest of stablecoins to msg.sender
//        {
//            uint256 stablecoinTokenRestAmount = IERC20(path[0]).balanceOf(address(this)) - contractStablecoinBalanceBefore;
//            if (stablecoinTokenRestAmount >= minTokensRestAmountToReturn) {  // do not return dust
//                IERC20(stablecoin).safeTransfer(msg.sender, stablecoinTokenRestAmount);
//            }
//        }
//
//        emit OrderPaid({
//            orderId: orderId,
//            orderUSDAmount: orderUSDAmount,
//            destination: destination,
//            payer: msg.sender,
//            payableToken: path[0],
//            payableTokenAmount: payableTokenReceivedAmount,
//            stablecoin: stablecoin,
//            serviceFeeUSDAmount: feeStablecoinAmount
//        });
//    }

    function paymentETH(
        bytes16 orderId,
        uint256 orderUSDAmount,  // 6 decimals
        address destination,
        uint256 deadline,
        address[] calldata path,
        uint256 minETHRestAmountToReturn
    ) external payable onlyWhitelistedTokenOrAllWhitelisted(path[0]) nonReentrant {
        address stablecoin = path[path.length-1];

        require(destination != address(0), "zero address");
        require(!userPaidOrders[msg.sender][orderId], "order already paid");
        require(isWhitelistedStablecoin(stablecoin), "the end path is not stablecoin");
        userPaidOrders[msg.sender][orderId] = true;

        uint256 feeStablecoinAmount = orderUSDAmount * feeNumerator / FEE_DENOMINATOR;

        _paymentETHProcess(
            orderUSDAmount,  // 6 decimals
            destination,
            deadline,
            path,
            minETHRestAmountToReturn,
            feeStablecoinAmount
        );

        emit OrderPaid({
            orderId: orderId,
            orderUSDAmount: orderUSDAmount,
            destination: destination,
            payer: msg.sender,
            payableToken: address(0),
            payableTokenAmount: msg.value,
            stablecoin: stablecoin,
            serviceFeeUSDAmount: feeStablecoinAmount
        });
    }

    function _paymentETHProcess(
        uint256 orderUSDAmount,  // 6 decimals
        address destination,
        uint256 deadline,
        address[] calldata path,
        uint256 minETHRestAmountToReturn,
        uint256 feeStablecoinAmount
    ) internal {
        uint256 orderUSDAmountERC20DECIMALS = orderUSDAmount * (10 ** stablecoinDecimals[path[path.length-1]]) / (10 ** USD_DECIMALS);
        uint256 feeStablecoinAmountERC20DECIMALS = feeStablecoinAmount * (10 ** stablecoinDecimals[path[path.length-1]]) / (10 ** USD_DECIMALS);
        uint256 totalAmountERC20DECIMALS = orderUSDAmountERC20DECIMALS + feeStablecoinAmountERC20DECIMALS;
        uint256[] memory amounts = IUniswapV2Router02(router).swapETHForExactTokens{value: msg.value}(
            totalAmountERC20DECIMALS,
            path,
            address(this),
            deadline
        );

        // send rest of tokens to msg.sender
        {
            uint256 ethRest = msg.value - amounts[0];
            if (ethRest >= minETHRestAmountToReturn) {
                (bool sent, /*bytes memory data*/) = payable(msg.sender).call{value: ethRest}("");
                require(sent, "Failed to send Ether");
            }
        }

        IERC20(path[path.length-1]).safeTransfer(destination, orderUSDAmountERC20DECIMALS);
        IERC20(path[path.length-1]).safeTransfer(serviceFeeTreasury, feeStablecoinAmountERC20DECIMALS);
    }

    // ==== withdraw occasionally transferred tokens from the contract (or dust)

    fallback() external payable { }  // we need it to receive eth on the contract from uniswap
    
    function withdrawERC20To(IERC20 token, address recipient, uint256 amount) external onlyOwner {
        token.safeTransfer(recipient, amount);
    }

    function withdrawETHTo(address recipient, uint256 amount) external onlyOwner {
        // https://solidity-by-example.org/sending-ether/
        (bool sent, /*bytes memory data*/) = payable(recipient).call{value: amount}("");
        require(sent, "Failed to send Ether");
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "IERC20.sol";
import "Address.sol";

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

pragma solidity ^0.8.0;

import "Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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
}

pragma solidity >=0.6.2;

import "IUniswapV2Router01.sol";

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}