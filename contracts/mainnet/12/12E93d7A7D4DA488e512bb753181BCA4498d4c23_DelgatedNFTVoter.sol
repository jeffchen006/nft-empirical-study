// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import './libraries/NFTHelper.sol';
import './interfaces/IGovToken.sol';

contract DelgatedNFTVoter {
  /// this contract is a view only that will let ppl vote on snapshot with delegated tokens from an NFT

  // maps from the delegate to the token to the account
  mapping(address => mapping(address => address)) public accountsDelegated;

  function delegateLockedTokens(address account, address token) external {
    address delegate = IGovToken(token).delegates(account);
    require(delegate != address(0));
    accountsDelegated[delegate][token] = account;
  }

  function getDelegatedVotesFromNFT(
    address token,
    address account,
    address hedgeyNFT
  ) public view returns (uint256) {
    address delegatedFrom = accountsDelegated[account][token];
    address delegatedTo = IGovToken(token).delegates(account);
    address voter;
    if (account == delegatedTo) {
      voter = account;
    } else if (delegatedTo == address(0) && delegatedFrom == address(0)) {
      voter = account;
    } else if (delegatedTo == address(0) && delegatedFrom != address(0)) {
      voter = delegatedFrom;
    } else {
      return 0;
    }
    return NFTHelper.getLockedTokenBalance(hedgeyNFT, voter, token);
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../interfaces/INFT.sol';

/// @notice Library to lock tokens and mint an NFT
/// @notice this NFTHelper is used by the HedgeyOTC contract to lock tokens and instruct the Hedgeys contract to mint an NFT
library NFTHelper {
  /// @dev internal function that handles the locking of the tokens in the NFT Futures contract
  /// @param futureContract is the address of the NFT contract that will mint the NFT and lock tokens
  /// @param _holder address here becomes the owner of the newly minted NFT
  /// @param _token address here is the ERC20 contract address of the tokens being locked by the NFT contract
  /// @param _amount is the amount of tokens that will be locked
  /// @param _unlockDate provides the unlock date which is the expiration date for the Future generated
  function lockTokens(
    address futureContract,
    address _holder,
    address _token,
    uint256 _amount,
    uint256 _unlockDate
  ) internal {
    /// @dev ensure that the _unlockDate is in the future compared to the current block timestamp
    require(_unlockDate > block.timestamp, 'NHL01');
    /// @dev similar to checking the balances for the OTC contract when creating a new deal - we check the current and post balance in the NFT contract
    /// @dev to ensure that 100% of the amount of tokens to be locked are in fact locked in the contract address
    uint256 currentBalance = IERC20(_token).balanceOf(futureContract);
    /// @dev increase allowance so that the NFT contract can pull the total funds
    /// @dev this is a safer way to ensure that the entire amount is delivered to the NFT contract
    SafeERC20.safeIncreaseAllowance(IERC20(_token), futureContract, _amount);
    /// @dev this function points to the NFT Futures contract and calls its function to mint an NFT and generate the locked tokens future struct
    INFT(futureContract).createNFT(_holder, _amount, _token, _unlockDate);
    /// @dev check to make sure that _holder is received by the futures contract equals the total amount we have delivered
    /// @dev this prevents functionality with deflationary or tax tokens that have not whitelisted these address
    uint256 postBalance = IERC20(_token).balanceOf(futureContract);
    assert(postBalance - currentBalance == _amount);
  }

  /// @notice function to get the balances for a given wallet
  function getLockedTokenDetails(address futureContract, address holder)
    internal
    view
    returns (
      uint256[] memory amounts,
      address[] memory tokens,
      uint256[] memory unlockDates
    )
  {
    uint256 holdersBalance = INFT(futureContract).balanceOf(holder);
    /// @dev for loop going through the holders balance to get each of their token IDs
    for (uint256 i = 0; i < holdersBalance; i++) {
      /// @dev gets the tokenId
      uint256 tokenId = INFT(futureContract).tokenOfOwnerByIndex(holder, i);
      /// @dev now we can use that tokenId to get their time lock details
      (uint256 amount, address token, uint256 unlockDate) = INFT(futureContract).futures(tokenId);
      /// @dev add these to the array
      amounts[i] = amount;
      tokens[i] = token;
      unlockDates[i] = unlockDate;
    }
  }

  function getLockedTokenBalance(address futureContract, address holder, address lockedToken) internal view returns (uint256 lockedAmount) {
     uint256 holdersBalance = INFT(futureContract).balanceOf(holder);
    /// @dev for loop going through the holders balance to get each of their token IDs
    for (uint256 i = 0; i < holdersBalance; i++) {
      /// @dev gets the tokenId
      uint256 tokenId = INFT(futureContract).tokenOfOwnerByIndex(holder, i);
      /// @dev now we can use that tokenId to get their time lock details
      (uint256 amount, address token,) = INFT(futureContract).futures(tokenId);
      /// @dev check if the token matches the lockedToken criteria
      if (token == lockedToken) {
        /// @dev if it does - add it to the sum total
        lockedAmount += amount;
      }
    }
  }
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

interface IGovToken {
    function delegates(address account) external view returns (address delegatee);
}

// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

/// @dev this is the one contract call that the OTC needs to interact with the NFT contract
interface INFT {
  /// @notice function for publicly viewing a lockedToken (future) details
  /// @param _id is the id of the NFT which is mapped to the future struct
  /// @dev this returns the amount of tokens locked, the token address and the date that they are unlocked
  function futures(uint256 _id)
    external
    view
    returns (
      uint256 amount,
      address token,
      uint256 unlockDate
    );
    /// @dev Returns the number of tokens in ``owner``'s account.
    function balanceOf(address owner) external view returns (uint256 balance);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);

  /// @param _holder is the new owner of the NFT and timelock future - this can be any address
  /// @param _amount is the amount of tokens that are going to be locked
  /// @param _token is the token address to be locked by the NFT. Use WETH address for ETH - but WETH must be held by the msg.sender
  /// ... as there is no automatic wrapping from ETH to WETH for this function.
  /// @param _unlockDate is the date which the tokens become unlocked and available to be redeemed and withdrawn from the contract
  /// @dev this is a public function that anyone can call
  /// @dev the _holder can be defined as your address, or any chose address - and so you can directly mint NFTs to other addresses
  /// ... in a way to airdrop NFTs directly to contributors
  function createNFT(
    address _holder,
    uint256 _amount,
    address _token,
    uint256 _unlockDate
  ) external returns (uint256);

  /// @dev function for redeeming an NFT
  /// @notice this function will burn the NFT and delete the future struct - in return the locked tokens will be delivered
  function redeemNFT(uint256 _id) external returns (bool);

  /// @notice this event spits out the details of the NFT and future struct when a new NFT & Future is minted
  event NFTCreated(uint256 _i, address _holder, uint256 _amount, address _token, uint256 _unlockDate);

  /// @notice this event spits out the details of the NFT and future structe when an existing NFT and Future is redeemed
  event NFTRedeemed(uint256 _i, address _holder, uint256 _amount, address _token, uint256 _unlockDate);

  /// @notice this event is fired the one time when the baseURI is updated
  event URISet(string newURI);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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

    function safePermit(
        IERC20Permit token,
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
interface IERC20Permit {
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