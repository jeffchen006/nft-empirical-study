//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "./IPancakePair.sol";
import "./ILock.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract Lock is ILock {
  using SafeERC20Upgradeable for IERC20MetadataUpgradeable;
  address[] public override liquidities;
  address[] public override tokens;

  mapping(address=>TokenList[]) public liquidityList;
  mapping(address=>TokenList[]) public tokenList;
  function add(address _token, uint256 _endDateTime, uint256 _amount, address _owner, bool _isLiquidity) external override{
    require(_amount>0, "zero amount!");
    require(_token!=address(0x0),"token!");
    require(_owner!=address(0x0),"owner!");
    if(_isLiquidity){      
      require(_endDateTime>=block.timestamp+30 days,"duration!");
      address token0=IPancakePair(_token).token0();
      address token1=IPancakePair(_token).token1();
      require(token0!=address(0x0) && token1!=address(0x0), "not a liquidity");
      IERC20MetadataUpgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);
      if(liquidityList[_token].length==0){
        liquidities.push(_token);
        liquidityList[_token].push(TokenList({
            amount:_amount,
            startDateTime:block.timestamp,
            endDateTime:_endDateTime,
            owner:_owner,
            creator:msg.sender
          }));
        
        
      }else{
        bool isExisted=false;
        for(uint i=0;i<liquidityList[_token].length;i++){
          if(liquidityList[_token][i].endDateTime==_endDateTime){
            if(liquidityList[_token][i].amount==0){
              liquidityList[_token][i].startDateTime=block.timestamp;
            }
            liquidityList[_token][i].amount=liquidityList[_token][i].amount+_amount;
            isExisted=true;
            break;
          }
        }
        if(!isExisted){
          liquidityList[_token].push(TokenList({
            amount:_amount,
            startDateTime:block.timestamp,
            endDateTime:_endDateTime,
            owner:liquidityList[_token][0].owner!=address(0x0) ? liquidityList[_token][0].owner : _owner,
            creator:msg.sender
          }));
        } 
      }
      // string memory token0Name=IERC20Metadata(token0).name();
      // string memory token1Name=IERC20Metadata(token1).name();
      // string memory token0Symbol=IERC20Metadata(token0).symbol();
      // string memory token1Symbol=IERC20Metadata(token1).symbol();
      emit LiquidityLockAdded(_token, _amount, _owner, IERC20MetadataUpgradeable(token0).name(), 
      IERC20MetadataUpgradeable(token1).name(), 
      IERC20MetadataUpgradeable(token0).symbol(), 
      IERC20MetadataUpgradeable(token1).symbol(), _endDateTime, block.timestamp);    
    }else{
      require(_endDateTime>=block.timestamp+1 days,"duration!");
      IERC20MetadataUpgradeable(_token).safeTransferFrom(msg.sender, address(this), _amount);
      if(tokenList[_token].length==0){
        tokens.push(_token);
        tokenList[_token].push(TokenList({
            amount:_amount,
            startDateTime:block.timestamp,
            endDateTime:_endDateTime,
            owner:_owner,
            creator:msg.sender
          }));     
      }else{
        bool isExisted=false;
        for(uint i=0;i<tokenList[_token].length;i++){
          if(tokenList[_token][i].endDateTime==_endDateTime){
            if(tokenList[_token][i].amount==0){
              tokenList[_token][i].startDateTime=block.timestamp;
            }
            tokenList[_token][i].amount=tokenList[_token][i].amount+_amount;
            isExisted=true;
            break;
          }
        }
        if(!isExisted){
          tokenList[_token].push(TokenList({
            amount:_amount,
            startDateTime:block.timestamp,
            endDateTime:_endDateTime,
            owner:tokenList[_token][0].owner!=address(0x0) ? tokenList[_token][0].owner : _owner,
            creator:msg.sender
          }));
        }   
      }
      string memory name=IERC20MetadataUpgradeable(_token).name();
      string memory symbol=IERC20MetadataUpgradeable(_token).symbol();
      uint8 decimals=IERC20MetadataUpgradeable(_token).decimals();
      emit TokenLockAdded(_token, _amount, _owner, name, symbol, decimals, _endDateTime, block.timestamp);   
    }
    
  }
  function unlockLiquidity(address _token) external override returns (bool){
    bool isExisted=false;
    uint256 _amount;
    for(uint i=0;i<liquidityList[_token].length;i++){
      if(liquidityList[_token][i].owner==msg.sender && liquidityList[_token][i].endDateTime<block.timestamp && liquidityList[_token][i].amount>0){
        isExisted=true;
        _amount=_amount+liquidityList[_token][i].amount;
        liquidityList[_token][i].amount=0;
      }
    }
    require(isExisted==true, "no existed");
    IERC20MetadataUpgradeable(_token).safeTransfer(msg.sender, _amount);      
    for(uint i=0;i<liquidityList[_token].length;i++){
      if(liquidityList[_token][i].amount==0){
        liquidityList[_token][i]=liquidityList[_token][liquidityList[_token].length-1];
        liquidityList[_token].pop();
      }
    }
    if(liquidityList[_token].length==0){
      for(uint i=0;i<liquidities.length;i++){
        if(liquidities[i]==_token){
          liquidities[i]=liquidities[liquidities.length-1];
          liquidities.pop();
          break;
        }
      }
      
    }    
    emit UnlockLiquidity(_token, _amount, block.timestamp, msg.sender);
    return isExisted;
  }
  function unlockToken(address _token) external override returns (bool){
    bool isExisted=false;
    uint256 _amount;
    for(uint i=0;i<tokenList[_token].length;i++){
      if(tokenList[_token][i].owner==msg.sender && tokenList[_token][i].endDateTime<block.timestamp && tokenList[_token][i].amount>0){
        isExisted=true;
        _amount=_amount+tokenList[_token][i].amount;
        tokenList[_token][i].amount=0;
      }
    }
    require(isExisted==true, "no existed");
    IERC20MetadataUpgradeable(_token).safeTransfer(msg.sender, _amount);    
    for(uint i=0;i<tokenList[_token].length;i++){
      if(tokenList[_token][i].amount==0){
        tokenList[_token][i]=tokenList[_token][tokenList[_token].length-1];
        tokenList[_token].pop();
      }
    }
    if(tokenList[_token].length==0){
      for(uint i=0;i<tokens.length;i++){
        if(tokens[i]==_token){
          tokens[i]=tokens[tokens.length-1];
          tokens.pop();
          break;
        }
      }
    }
    emit UnlockToken(_token, _amount, block.timestamp, msg.sender);
    return isExisted;
  }

  function extendLock(address _token, uint256 _endDateTime, bool _isLiquidity, uint256 _updateEndDateTime)external override{
    require(_endDateTime<_updateEndDateTime, "wrong timer");
    bool isExisted=false;
    if(_isLiquidity){
      for(uint i=0;i<liquidityList[_token].length;i++){
        if(liquidityList[_token][i].owner==msg.sender && liquidityList[_token][i].endDateTime==_endDateTime && liquidityList[_token][i].amount>0){
          isExisted=true;
          liquidityList[_token][i].endDateTime=_updateEndDateTime;
        }
      }
    }else{
      for(uint i=0;i<tokenList[_token].length;i++){
        if(tokenList[_token][i].owner==msg.sender && tokenList[_token][i].endDateTime==_endDateTime && tokenList[_token][i].amount>0){
          isExisted=true;          
          tokenList[_token][i].endDateTime=_updateEndDateTime;          
        }
      }
    }
    require(isExisted, "No lock");
    emit LockExtended(_token, _endDateTime, _isLiquidity, _updateEndDateTime, msg.sender);
  }
  function getLiquidityAddresses() public view returns(address[] memory){
    return liquidities;
  }
  function getTokenAddresses() public view returns(address[] memory){
    return tokens;
  }
  function getTokenDetails(address token) public view returns(TokenList[] memory){
    return tokenList[token];
  }
  function getLiquidityDetails(address token) public view returns(TokenList[] memory){
    return liquidityList[token];
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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

//SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function initialize(address, address) external;
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ILock {
    event LiquidityLockAdded(
        address token,
        uint256 amount,
        address owner,
        string token0Name,
        string token1Name,
        string token0Symbol,
        string token1Symbol,
        uint256 endDateTime,
        uint256 startDateTime
    );
    event TokenLockAdded(
        address token,
        uint256 amount,
        address owner,
        string name,
        string symbol,
        uint8 decimals,
        uint256 endDateTime,
        uint256 startDateTime
    );
    event UnlockLiquidity(address token, uint256 amount, uint256 endDateTime, address owner);
    event UnlockToken(address token, uint256 amount, uint256 endDateTime, address owner);
    event LockExtended(
        address token,
        uint256 endDateTime,
        bool isLiquidity,
        uint256 updateEndDateTime,
        address owner
    );
    struct TokenList {
        uint256 amount;
        uint256 startDateTime;
        uint256 endDateTime;
        address owner;
        address creator;
    }

    function liquidities(uint256) external view returns (address);

    function tokens(uint256) external view returns (address);

    function add(
        address _token,
        uint256 _endDateTime,
        uint256 _amount,
        address _owner,
        bool _isLiquidity
    ) external;

    function unlockLiquidity(address _token) external returns (bool);

    function unlockToken(address _token) external returns (bool);

    function extendLock(
        address _token,
        uint256 _endDateTime,
        bool _isLiquidity,
        uint256 _updateEndDateTime
    ) external;
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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