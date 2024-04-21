/**
 *Submitted for verification at Etherscan.io on 2022-08-24
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
   
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

contract TokenClaim {
    using SafeERC20 for IERC20;
    
  address public admin;
  address public signer;
    
    //user => claim round => claim status
    mapping(address => mapping(uint256 => bool)) public userClaim;
    mapping(address => bool) public isClaimed;
    //user => refund status
    mapping(address => bool) public userRefund;
    mapping(address => uint256) public totalClaimed;
    mapping(address => uint256) public totalRefunded;
  
    // token => claim round 
    uint256 public currentClaimRound;
    uint256 public totalTokenClaimed;
    uint256 public claimedCount;
    
  address public idoToken;
  address public refundToken;
  
  uint256 public refundEndAt;
  uint256 public claimStartAt;
  
  event EventClaimed(
    address indexed recipient,
    uint amount,
    uint date
  );

  event EventRefunded(
    address indexed recipient,
    uint amount,
    uint date
  );
  
  event EventSetConfig(
    address _refundTk,
    address _idoToken,
    uint256 _refundBlock,
    uint256 _claimTime
      );

event EventEmergencyWithdraw(
    address _token, 
    address _to, 
    uint256 _amount
    );

    constructor() 
    {
        admin = msg.sender; 
    }

   function init(
    address _idoToken, 
    address _refundToken,
    address _signer,
    uint256 _startClaimAt,
    uint256 _refundEndAt
  ) 
  external 
  {
    require(msg.sender == admin, 'only admin');
    refundToken = _refundToken;
    idoToken = _idoToken;
    refundEndAt = _refundEndAt;
    claimStartAt = _startClaimAt;
    signer = _signer;
  }

  function setSigner( address _signer) external {
    require(msg.sender == admin, 'only admin');
    require(_signer != address(0), '_signer is zero address');
    signer = _signer;
  }


  function setAdm( address _newAdmin) external {
    require(msg.sender == admin, 'only admin');
    require(_newAdmin != address(0), '_newAdmin is zero address');
    admin = _newAdmin;
  }


    function setCurrentRound(
    uint256 _claimRound
  ) 
    external 
  {
    require(msg.sender == admin, 'only admin');

       if (_claimRound > 0 ){
        currentClaimRound = _claimRound;
        }
        
    }

  function setConfig(
    address _refundTk,
    address _idoToken,
    uint256 _refundEndAt,
    uint256 _claimTime
  ) 
    external 
  {
    require(msg.sender == admin, 'only admin');
    
    if (_refundTk != address(0)) {
        refundToken = _refundTk;    
    }
    
    if (_idoToken != address(0)) {
        idoToken = _idoToken;    
    }
    
    if (_refundEndAt > 0) {
        refundEndAt = _refundEndAt;        
    }
    
    if (_claimTime > 0) {
        claimStartAt = _claimTime;        
    }
    
    emit EventSetConfig(
        _refundTk,
        _idoToken,
        _refundEndAt,
        _claimTime
        );
  }

  function emergencyWithdraw(
    address _token, 
    address _to, 
    uint256 _amount
  ) 
    external 
  {
    require(msg.sender == admin,'Not allowed');
    IERC20(_token).safeTransfer(_to, _amount);
    emit EventEmergencyWithdraw(
         _token, 
        _to, 
         _amount
        );
  }
  
  function claimTokens(
    uint256 _amount,
    uint256 _claimRound,
    bytes calldata sig
      ) 
    external 
  {
    address recipient = msg.sender;
    bytes32 message = prefixed(keccak256(abi.encodePacked(
      recipient, 
      _amount,
      _claimRound,
      address(this)
    )));
     // must be in whitelist 
    require(recoverSigner(message, sig) == signer , 'wrong signature');
    uint256 thisBal = IERC20(idoToken).balanceOf(address(this));
    require(currentClaimRound > 0 && _claimRound <= currentClaimRound,'Invalid claim round');
    require(userClaim[recipient][_claimRound] == false,'Already claimed');
    require(claimStartAt > 0,'Claim has not started yet');
    require(block.timestamp > claimStartAt,'Claim has not started yet');
    // already refunded
    require(userRefund[recipient] == false,'Refunded');
    require(thisBal >= _amount,'Not enough balance');
     if (thisBal > 0) {
        userClaim[recipient][_claimRound] = true;
        isClaimed[recipient] = true;
        totalClaimed[recipient] = totalClaimed[recipient] + _amount;
        totalTokenClaimed += _amount;
        claimedCount += 1;
        IERC20(idoToken).safeTransfer(recipient, _amount);
        
        emit EventClaimed(
          recipient,
          _amount,
          block.timestamp
        );
     } 
  }
  
  
  function refund(
    uint256 _amount,
    bytes calldata sig
      ) 
      external 
    {
    address recipient = msg.sender;
    uint256 thisBal = IERC20(refundToken).balanceOf(address(this));
    require(thisBal >= _amount,'Not enough balance');
    require(claimStartAt > 0,'Not yet started');
     bytes32 message = prefixed(keccak256(abi.encodePacked(
      recipient, 
      _amount,
      address(this)
    )));
      // must be in whitelist 
    require(recoverSigner(message, sig) == signer , 'wrong signature');
    require(block.timestamp < refundEndAt, 'Refund is no longer allowed');
    require(refundEndAt > 0, 'Not refundable');
    require(userRefund[recipient] == false,'Refunded');
    require(isClaimed[recipient] == false, 'Already claimed');
    
    if (thisBal > 0) {
        userRefund[recipient] = true;
        totalRefunded[recipient] = totalRefunded[recipient] + _amount;
        IERC20(refundToken).safeTransfer(recipient, _amount);
        emit EventRefunded(
          recipient,
          _amount,
          block.timestamp
        );   
    }
  }
  
  
  function prefixed(bytes32 hash) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(
      '\x19Ethereum Signed Message:\n32', 
      hash
    ));
  }

  function recoverSigner(bytes32 message, bytes memory sig)
    internal
    pure
    returns (address)
  {
    uint8 v;
    bytes32 r;
    bytes32 s;
  
    (v, r, s) = splitSignature(sig);
  
    return ecrecover(message, v, r, s);
  }

  function splitSignature(bytes memory sig)
    internal
    pure
    returns (uint8, bytes32, bytes32)
  {
    require(sig.length == 65);
  
    bytes32 r;
    bytes32 s;
    uint8 v;
  
    assembly {
        // first 32 bytes, after the length prefix
        r := mload(add(sig, 32))
        // second 32 bytes
        s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
        v := byte(0, mload(add(sig, 96)))
    }
  
    return (v, r, s);
  }
}