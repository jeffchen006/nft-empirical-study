// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

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
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
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
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
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
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
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
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/ILockSubscription.sol";


// @title Voting Escrow XB3
// @author Curve Finance | Translation to Solidity - Integral Team O
// @license MIT
// @notice Votes have a weight depending on time, so that users are
//         committed to the future of (whatever they are voting for)
// @dev Vote weight decays linearly over time. Lock time cannot be
//     more than `MAXTIME` (2 years).
contract VeToken is ReentrancyGuard {
    using SafeERC20 for ERC20;

    // # Voting escrow to have time-weighted votes
    // # Votes have a weight depending on time, so that users are committed
    // # to the future of (whatever they are voting for).
    // # The weight in this implementation is linear, and lock cannot be more than maxtime:
    // # w ^
    // # 1 +        /
    // #   |      /
    // #   |    /
    // #   |  /
    // #   |/
    // # 0 +--------+------> time
    // #       maxtime (2 years?)

    struct Point {
        int128 bias;
        int128 slope; // - dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    event CommitOwnership(address admin);
    event ApplyOwnership(address admin);
    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 indexed locktime,
        int128 _type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    int128 public constant DEPOSIT_FOR_TYPE = 0;
    int128 public constant CREATE_LOCK_TYPE = 1;
    int128 public constant INCREASE_LOCK_AMOUNT = 2;
    int128 public constant INCREASE_UNLOCK_TIME = 3;

    // General constants
    uint256 public constant YEAR = 86400 * 365;
    uint256 public constant WEEK = 7 * 86400; // all future times are rounded by week
    uint256 public constant MAXTIME = 100 * WEEK; // 2 years (23.333 Months)
    uint256 public constant MULTIPLIER = 10**18;

    uint256 public supply;

    mapping(address => LockedBalance) public locked;
    mapping(address => uint256) internal _lockStarts;

    uint256 public epoch;
    mapping(uint256 => Point) public pointHistory; // epoch -> unsigned point /*Point[100000000000000000000000000000]*/

    // Point[1000000000]
    mapping(address => mapping(uint256 => Point)) public userPointHistory; // user -> Point[user_epoch]

    mapping(address => uint256) public userPointEpoch;
    mapping(uint256 => int128) public slopeChanges; // time -> signed slope change

    address public votingStakingRewards;
    ILockSubscription public registrationMediator;

    mapping(address => bool) public allowedToActWithoutPermission;

    string public name;
    string public symbol;
    string public version;
    uint8 public decimals;

    address public admin;
    address public futureAdmin;

    ERC20 public token;

    uint256 public minLockDuration;

    mapping(address => mapping(address => bool)) public actionAllowance;

    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    // """
    // @notice Contract constructor
    // @param token_addr `ERC20CRV` token address
    // @param _name Token name
    // @param _symbol Token symbol
    // @param _version Contract version - required for Aragon compatibility
    // """
    constructor(
        address tokenAddr,
        address _registrationMediator,
        uint256 _minLockDuration,
        string memory _name,
        string memory _symbol,
        string memory _version
    ) {
        admin = msg.sender;
        pointHistory[0].blk = block.number;
        pointHistory[0].ts = block.timestamp;
        uint256 _decimals = ERC20(tokenAddr).decimals();
        require(_decimals <= 255, "decimalsOverflow");
        decimals = uint8(_decimals);
        name = _name;
        symbol = _symbol;
        version = _version;
        token = ERC20(tokenAddr);
        registrationMediator = ILockSubscription(_registrationMediator);
        _setMinLockDuration(_minLockDuration);
    }

    function _setMinLockDuration(uint256 _minLockDuration) private {
        require(_minLockDuration < MAXTIME, "!badMinLockDuration");
        minLockDuration = _minLockDuration;
    }

    function setMinLockDuration(uint256 _minLockDuration) external onlyAdmin {
        _setMinLockDuration(_minLockDuration);
    }

    function setAllowedToActWithoutPermission(address _allowedAddress, bool _status) external onlyAdmin {
        allowedToActWithoutPermission[_allowedAddress] = _status;
    }

    function setVotingStakingRewards(address _votingStakingRewards) external onlyAdmin {
        require(_votingStakingRewards != address(0), "addressIsZero");
        allowedToActWithoutPermission[votingStakingRewards] = false;
        votingStakingRewards = _votingStakingRewards;
        allowedToActWithoutPermission[_votingStakingRewards] = true;
    }

    // """
    // @notice Transfer ownership of VotingEscrow contract to `addr`
    // @param addr Address to have ownership transferred to
    // """
    function commitTransferOwnership(address addr) external onlyAdmin {
        futureAdmin = addr;
        emit CommitOwnership(addr);
    }

    // """
    // @notice Apply ownership transfer
    // """
    function applyTransferOwnership() external onlyAdmin {
        address _admin = futureAdmin;
        require(_admin != address(0), "adminIsZero");
        admin = _admin;
        emit ApplyOwnership(_admin);
    }

    // """
    // @notice Get the most recently recorded rate of voting power decrease for `addr`
    // @param addr Address of the user wallet
    // @return Value of the slope
    // """
    function getLastUserSlope(address addr) external view returns (int128) {
        uint256 uepoch = userPointEpoch[addr];
        return userPointHistory[addr][uepoch].slope;
    }

    // """
    // @notice Get the timestamp for checkpoint `_idx` for `_addr`
    // @param _addr User wallet address
    // @param _idx User epoch number
    // @return Epoch time of the checkpoint
    // """
    function userPointHistoryTs(address addr, uint256 idx)
        external
        view
        returns (uint256)
    {
        return userPointHistory[addr][idx].ts;
    }

    // """
    // @notice Get timestamp when `_addr`'s lock finishes
    // @param _addr User wallet
    // @return Epoch time of the lock end
    // """
    function lockedEnd(address addr) external view returns (uint256) {
        return locked[addr].end;
    }

    function lockStarts(address addr) external view returns (uint256) {
        return _lockStarts[addr];
    }

    function lockedAmount(address addr) external view returns (uint256) {
        return uint256(uint128(locked[addr].amount));
    }

    // """
    // @notice Record global and per-user data to checkpoint
    // @param addr User's wallet address. No user checkpoint if 0x0
    // @param old_locked Pevious locked amount / end lock time for the user
    // @param new_locked New locked amount / end lock time for the user
    // """
    function _checkpoint(
        address addr,
        LockedBalance memory oldLocked,
        LockedBalance memory newLocked
    ) internal {
        Point memory uOld;
        Point memory uNew;
        int128 oldDSlope = 0;
        int128 newDSlope = 0;
        // uint256 _epoch = epoch;

        if (addr != address(0)) {
            // # Calculate slopes and biases
            // # Kept at zero when they have to
            if (oldLocked.end > block.timestamp && oldLocked.amount > 0) {
                uOld.slope = oldLocked.amount / int128(uint128(MAXTIME));
                uOld.bias =
                    uOld.slope *
                    int128(uint128(oldLocked.end - block.timestamp));
            }
            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                uNew.slope = newLocked.amount / int128(uint128(MAXTIME));
                uNew.bias =
                    uNew.slope *
                    int128(uint128(newLocked.end - block.timestamp));
            }

            // # Read values of scheduled changes in the slope
            // # old_locked.end can be in the past and in the future
            // # new_locked.end can ONLY by in the FUTURE unless everything expired: than zeros
            oldDSlope = slopeChanges[oldLocked.end];
            if (newLocked.end != 0) {
                if (newLocked.end == oldLocked.end) {
                    newDSlope = oldDSlope;
                } else {
                    newDSlope = slopeChanges[newLocked.end];
                }
            }
        }
        Point memory lastPoint = Point({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        });
        if (
            epoch > 0 /*_epoch*/
        ) {
            lastPoint = pointHistory[
                epoch /*_epoch*/
            ];
        }
        // uint256 lastCheckpoint = lastPoint.ts;

        // # initial_last_point is used for extrapolation to calculate block number
        // # (approximately, for *At methods) and save them
        // # as we cannot figure that out exactly from inside the contract

        Point memory initialLastPoint = lastPoint;
        uint256 blockSlope = 0;
        if (block.timestamp > lastPoint.ts) {
            blockSlope =
                (MULTIPLIER * (block.number - lastPoint.blk)) /
                (block.timestamp - lastPoint.ts);
        }

        // # If last point is already recorded in this block, slope=0
        // # But that's ok b/c we know the block in such case
        //
        // # Go over weeks to fill history and calculate what the current point is
        uint256 tI = (lastPoint.ts / WEEK) * WEEK; /*lastCheckpoint*/

        for (uint256 i = 0; i < 255; i++) {
            // # Hopefully it won't happen that this won't get used in 5 years!
            // # If it does, users will be able to withdraw but vote weight will be broken
            tI += WEEK;
            int128 dSlope = 0;

            if (tI > block.timestamp) {
                tI = block.timestamp;
            } else {
                dSlope = slopeChanges[tI];
            }

            lastPoint.bias -=
                lastPoint.slope *
                int128(
                    uint128(
                        tI - lastPoint.ts /*lastCheckpoint*/
                    )
                );
            lastPoint.slope += dSlope;

            if (lastPoint.bias < 0) {
                // # This can happen
                lastPoint.bias = 0;
            }

            if (lastPoint.slope < 0) {
                // # This cannot happen - just in case
                lastPoint.slope = 0;
            }

            // lastCheckpoint = tI;
            lastPoint.ts = tI;
            lastPoint.blk =
                initialLastPoint.blk +
                (blockSlope * (tI - initialLastPoint.ts)) /
                MULTIPLIER;
            epoch += 1; /*_epoch*/

            if (tI == block.timestamp) {
                lastPoint.blk = block.number;
                break;
            } else {
                pointHistory[
                    epoch /*_epoch*/
                ] = lastPoint;
            }
        }

        // epoch = _epoch;
        // # Now point_history is filled until t=now

        if (addr != address(0)) {
            // # If last point was in this block, the slope change has been applied already
            // # But in such case we have 0 slope(s)
            lastPoint.slope += (uNew.slope - uOld.slope);
            lastPoint.bias += (uNew.bias - uOld.bias);
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        // # Record the changed point into history
        pointHistory[
            epoch /*_epoch*/
        ] = lastPoint;

        if (addr != address(0)) {
            // # Schedule the slope changes (slope is going down)
            // # We subtract new_user_slope from [new_locked.end]
            // # and add old_user_slope to [old_locked.end]
            if (oldLocked.end > block.timestamp) {
                // # old_dslope was <something> - u_old.slope, so we cancel that
                oldDSlope += uOld.slope;
                if (newLocked.end == oldLocked.end) {
                    oldDSlope -= uNew.slope;
                }
                slopeChanges[oldLocked.end] = oldDSlope;
            }
            if (newLocked.end > block.timestamp) {
                if (newLocked.end > oldLocked.end) {
                    newDSlope -= uNew.slope;
                    slopeChanges[newLocked.end] = newDSlope;
                }
                // else: we recorded it already in old_dslope
            }

            // Now handle user history
            // uint256 userEpoch = userPointEpoch[addr] + 1;

            userPointEpoch[addr] += 1; //= userPointEpoch[addr] + 1/*userEpoch*/;
            uNew.ts = block.timestamp;
            uNew.blk = block.number;
            userPointHistory[addr][
                userPointEpoch[addr] /*userEpoch*/
            ] = uNew;
        }
    }

    function _canConvertInt128(uint256 value) internal pure returns (bool) {
        return value < 2**127;
    }

    // """
    // @notice Deposit and lock tokens for a user
    // @param _addr User's wallet address
    // @param _value Amount to deposit
    // @param unlock_time New time when to unlock the tokens, or 0 if unchanged
    // @param locked_balance Previous locked amount / timestamp
    // """
    function _depositFor(
        address _addr,
        uint256 _value,
        uint256 unlockTime,
        LockedBalance memory lockedBalance,
        int128 _type
    ) internal {
        LockedBalance memory _locked = LockedBalance({
            amount: lockedBalance.amount,
            end: lockedBalance.end
        });
        uint256 supplyBefore = supply;

        supply = supplyBefore + _value;
        LockedBalance memory oldLocked = lockedBalance;
        // # Adding to existing lock, or if a lock is expired - creating a new one

        require(_canConvertInt128(_value), "!convertInt128");
        _locked.amount += int128(uint128(_value));
        if (unlockTime != 0) {
            _locked.end = unlockTime;
        }
        locked[_addr] = _locked;

        // # Possibilities:
        // # Both old_locked.end could be current or expired (>/< block.timestamp)
        // # value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // # _locked.end > block.timestamp (always)
        _checkpoint(_addr, oldLocked, _locked);


        token.safeTransferFrom(msg.sender, address(this), _value);


        registrationMediator.processLockEvent(
            _addr,
            _lockStarts[_addr],
            _locked.end,
            _value
        );

        emit Deposit(_addr, _value, _locked.end, _type, block.timestamp);
        emit Supply(supplyBefore, supplyBefore + _value);
    }

    // """
    // @notice Record global data to checkpoint
    // """
    function checkpoint() external {
        LockedBalance memory _emptyBalance;
        _checkpoint(address(0), _emptyBalance, _emptyBalance);
    }

    // """
    // @notice Deposit `_value` tokens for `_addr` and add to the lock
    // @dev Anyone (even a smart contract) can deposit for someone else, but
    //      cannot extend their locktime and deposit for a brand new user
    // @param _addr User's wallet address
    // @param _value Amount to add to user's lock
    // """
    function depositFor(address _addr, uint256 _value) external nonReentrant {
        if (!allowedToActWithoutPermission[msg.sender]) {
            require(actionAllowance[_addr][msg.sender], "!allowed");
        }
        LockedBalance memory _locked = locked[_addr];
        require(_value > 0, "!zeroValue");
        require(_locked.amount > 0, "!zeroLockedAmount");
        require(_locked.end > block.timestamp, "lockExpired");
        _depositFor(_addr, _value, 0, _locked, DEPOSIT_FOR_TYPE);
    }

    // """
    // @notice Deposit `_value` tokens for `msg.sender` and lock until `_unlock_time`
    // @param _value Amount to deposit
    // @param _unlock_time Epoch time when tokens unlock, rounded down to whole weeks
    // """
    function createLock(uint256 _value, uint256 _unlockTime)
        external
        nonReentrant
    {
        // assertNotContract(msg.sender);
        _createLockFor(msg.sender, _value, _unlockTime);
    }

    function setCreateLockAllowance(address _spender, bool _status) external {
        actionAllowance[msg.sender][_spender] = _status;
    }

    function _createLockFor(
        address _for,
        uint256 _value,
        uint256 _unlockTime
    ) internal {
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK; // # Locktime is rounded down to weeks
        LockedBalance memory _locked = locked[_for];

        require(_value > 0, "!zeroValue");
        require(_locked.amount == 0, "!withdrawOldTokensFirst");
        require(unlockTime > block.timestamp, "!futureTime");
        require(
            unlockTime >= minLockDuration + block.timestamp,
            "!minLockDuration"
        );
        require(
            unlockTime <= block.timestamp + MAXTIME,
            "invalidFutureTime"
        );

        _lockStarts[_for] = block.timestamp;

        _depositFor(_for, _value, unlockTime, _locked, CREATE_LOCK_TYPE);
    }

    function createLockFor(
        address _for,
        uint256 _value,
        uint256 _unlockTime
    ) external nonReentrant {
        if (!allowedToActWithoutPermission[msg.sender]) {
            require(actionAllowance[_for][msg.sender], "!allowed");
        }
        _createLockFor(_for, _value, _unlockTime);
    }

    // """
    // @notice Deposit `_value` additional tokens for `msg.sender`
    //         without modifying the unlock time
    // @param _value Amount of tokens to deposit and add to the lock
    // """
    function increaseAmount(uint256 _value) external nonReentrant {
        // assertNotContract(msg.sender);
        LockedBalance memory _locked = locked[msg.sender];
        require(_value > 0, "!zeroValue");
        require(_locked.amount > 0, "!zeroLockedAmount");
        require(_locked.end > block.timestamp, "lockExpired");
        _depositFor(msg.sender, _value, 0, _locked, INCREASE_LOCK_AMOUNT);
    }

    function increaseAmountFor(address _account, uint256 _value) external nonReentrant {
        // assertNotContract(msg.sender);
        if (!allowedToActWithoutPermission[msg.sender]) {
            require(actionAllowance[_account][msg.sender], "!allowed");
        }

        LockedBalance memory _locked = locked[_account];
        require(_value > 0, "!zeroValue");
        require(_locked.amount > 0, "!zeroLockedAmount");
        require(_locked.end > block.timestamp, "lockExpired");
        _depositFor(_account, _value, 0, _locked, INCREASE_LOCK_AMOUNT);
    }

    // """
    // @notice Extend the unlock time for `msg.sender` to `_unlock_time`
    // @param _unlock_time New epoch time for unlocking
    // """
    function increaseUnlockTime(uint256 _unlockTime) external nonReentrant {
        // assertNotContract(msg.sender);
        LockedBalance memory _locked = locked[msg.sender];
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK; // Locktime is rounded down to weeks

        require(_locked.end > block.timestamp, "lockExpired");
        require(_locked.amount > 0, "!zeroLockedAmount");
        require(unlockTime > _locked.end, "canOnlyIncreaseLockDuration");
        require(
            unlockTime <= block.timestamp + MAXTIME,
            "lockOnlyToValidFutureTime"
        );

        _depositFor(msg.sender, 0, unlockTime, _locked, INCREASE_UNLOCK_TIME);
    }

    function increaseUnlockTimeFor(address _account, uint256 _unlockTime) external nonReentrant {
        // assertNotContract(msg.sender);
        if (!allowedToActWithoutPermission[msg.sender]) {
            require(actionAllowance[_account][msg.sender], "!allowed");
        }
        LockedBalance memory _locked = locked[_account];
        uint256 unlockTime = (_unlockTime / WEEK) * WEEK; // Locktime is rounded down to weeks

        require(_locked.end > block.timestamp, "lockExpired");
        require(_locked.amount > 0, "!zeroLockedAmount");
        require(unlockTime > _locked.end, "canOnlyIncreaseLockDuration");
        require(
            unlockTime <= block.timestamp + MAXTIME,
            "lockOnlyToValidFutureTime"
        );

        _depositFor(_account, 0, unlockTime, _locked, INCREASE_UNLOCK_TIME);
    }


    // """
    // @notice Withdraw all tokens for `msg.sender`
    // @dev Only possible if the lock has expired
    // """
    function withdraw() external nonReentrant {
        LockedBalance memory _locked = locked[msg.sender];
        require(block.timestamp >= _locked.end, "lockDidntExpired");
        uint256 value = uint256(uint128(_locked.amount));

        LockedBalance memory oldLocked = _locked;
        _locked.end = 0;
        _locked.amount = 0;
        locked[msg.sender] = _locked;
        uint256 supplyBefore = supply;
        supply = supplyBefore - value;

        // # old_locked can have either expired <= timestamp or zero end
        // # _locked has only 0 end
        // # Both can have >= 0 amount
        _checkpoint(msg.sender, oldLocked, _locked);

        registrationMediator.processWitdrawEvent(
            msg.sender,
            value
        );

        token.safeTransfer(msg.sender, value);

        emit Withdraw(msg.sender, value, block.timestamp);
        emit Supply(supplyBefore, supplyBefore - value);
    }

    // """
    // @notice Binary search to estimate timestamp for block number
    // @param _block Block to find
    // @param max_epoch Don't go beyond this epoch
    // @return Approximate timestamp for block
    // """
    function findBlockEpoch(uint256 _block, uint256 maxEpoch)
        internal
        view
        returns (uint256)
    {
        uint256 _min = 0;
        uint256 _max = maxEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    // """
    // @notice Get the current voting power for `msg.sender`
    // @dev Adheres to the ERC20 `balanceOf` interface for Aragon compatibility
    // @param addr User wallet address
    // @param _t Epoch time to return voting power at
    // @return User voting power
    // """
    function balanceOf(address addr) public view returns (uint256) {
        return balanceOf(addr, block.timestamp);
    }

    function balanceOf(address addr, uint256 _t) public view returns (uint256) {
        uint256 _epoch = userPointEpoch[addr];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = userPointHistory[addr][_epoch];
            lastPoint.bias -= lastPoint.slope * int128(uint128(_t - lastPoint.ts));
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            return uint256(uint128(lastPoint.bias));
        }
    }

    // """
    // @notice Measure voting power of `addr` at block height `_block`
    // @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
    // @param addr User's wallet address
    // @param _block Block to calculate the voting power at
    // @return Voting power
    // """
    function balanceOfAt(address addr, uint256 _block)
        external
        view
        returns (uint256)
    {
        // # Copying and pasting totalSupply code because Vyper cannot pass by
        // # reference yet
        require(_block <= block.number, "onlyPast");

        // Binary search
        uint256 _min = 0;
        uint256 _max = userPointEpoch[addr];
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (userPointHistory[addr][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory upoint = userPointHistory[addr][_min];

        uint256 maxEpoch = epoch;
        uint256 _epoch = findBlockEpoch(_block, maxEpoch);
        Point memory point0 = pointHistory[_epoch];
        uint256 dBlock = 0;
        uint256 dT = 0;
        if (_epoch < maxEpoch) {
            Point memory point1 = pointHistory[_epoch + 1];
            dBlock = point1.blk - point0.blk;
            dT = point1.ts - point0.ts;
        } else {
            dBlock = block.number - point0.blk;
            dT = block.timestamp - point0.ts;
        }
        uint256 blockTime = point0.ts;
        if (dBlock != 0) {
            blockTime += (dT * (_block - point0.blk)) / dBlock;
        }

        upoint.bias -= upoint.slope * int128(uint128(blockTime - upoint.ts));
        if (upoint.bias >= 0) {
            return uint256(uint128(upoint.bias));
        } else {
            return 0;
        }
    }

    // """
    // @notice Calculate total voting power at some point in the past
    // @param point The point (bias/slope) to start search from
    // @param t Time to calculate the total voting power at
    // @return Total voting power at that time
    // """
    function supplyAt(Point memory point, uint256 t)
        internal
        view
        returns (uint256)
    {
        Point memory lastPoint = point;
        uint256 tI = (lastPoint.ts / WEEK) * WEEK;
        for (uint256 i = 0; i < 255; i++) {
            tI += WEEK;
            int128 dSlope = 0;
            if (tI > t) {
                tI = t;
            } else {
                dSlope = slopeChanges[tI];
            }
            lastPoint.bias -= lastPoint.slope * int128(uint128(tI - lastPoint.ts));
            if (tI == t) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = tI;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        return uint256(uint128(lastPoint.bias));
    }

    // """
    // @notice Calculate total voting power
    // @dev Adheres to the ERC20 `totalSupply` interface for Aragon compatibility
    // @return Total voting power
    // """
    function totalSupply() external view returns (uint256) {
        return totalSupply(block.timestamp);
    }

    // returns supply of locked tokens
    function lockedSupply() external view returns (uint256) {
        return supply;
    }

    function totalSupply(uint256 t) public view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory lastPoint = pointHistory[_epoch];
        return supplyAt(lastPoint, t);
    }

    // """
    // @notice Calculate total voting power at some point in the past
    // @param _block Block to calculate the total voting power at
    // @return Total voting power at `_block`
    // """
    function totalSupplyAt(uint256 _block) external view returns (uint256) {
        require(_block <= block.number, "onlyPastAllowed");
        uint256 _epoch = epoch;
        uint256 targetEpoch = findBlockEpoch(_block, _epoch);

        Point memory point = pointHistory[targetEpoch];
        uint256 dt = 0; // difference in total voting power between _epoch and targetEpoch

        if (targetEpoch < _epoch) {
            Point memory pointNext = pointHistory[targetEpoch + 1];
            if (point.blk != pointNext.blk) {
                dt =
                    ((_block - point.blk) * (pointNext.ts - point.ts)) /
                    (pointNext.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dt =
                    ((_block - point.blk) * (block.timestamp - point.ts)) /
                    (block.number - point.blk);
            }
        }

        // # Now dt contains info on how far are we beyond point
        return supplyAt(point, point.ts + dt);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

interface ILockSubscription {
    function processLockEvent(
        address account,
        uint256 lockStart,
        uint256 lockEnd,
        uint256 amount
    ) external;

    function processWitdrawEvent(
        address account,
        uint256 amount
    ) external;
}