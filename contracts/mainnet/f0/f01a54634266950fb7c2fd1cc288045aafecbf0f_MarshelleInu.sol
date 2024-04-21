/**
 *Submitted for verification at Etherscan.io on 2022-10-10
*/

//SPDX-License-Identifier: MIT

// File: contracts/MarshelleErrors.sol


pragma solidity ^0.8.17;

error InvalidSwapTokenAmount(
    string errorMsg
);
error InvalidMaxTradeAmount(
    string errorMsg
);
error InvalidMaxWalletAmount(
    string errorMsg
);
error InvalidTotalFees(
    string errorMsg
);
error InvalidAutomatedMarketMakerPair(
    address pair,
    string errorMsg
);
error TransferFromZeroAddress(
    address from,
    address to
);
error TransferError(string errorMsg);
error InvalidAntibot(string errorMsg);
error InvalidMultiBuy(string errorMsg);
error TradingNotActive(string errorMsg);
error MaxWalletExceeded(string errorMsg);
error MaxTransactionExceeded(string errorMsg);

// File: contracts/IterableMapping.sol

pragma solidity ^0.8.17;
library IterableMapping {
    // Iterable mapping from address to uint;
    struct Map {
        address[] keys;
        mapping(address => uint) values;
        mapping(address => uint) indexOf;
        mapping(address => bool) inserted;
    }
 
    function get(Map storage map, address key) internal view returns (uint) {
        return map.values[key];
    }
 
    function getIndexOfKey(Map storage map, address key) internal view returns (int) {
        if(!map.inserted[key]) {
            return -1;
        }
        return int(map.indexOf[key]);
    }
 
    function getKeyAtIndex(Map storage map, uint index) internal view returns (address) {
        return map.keys[index];
    }
 
 
 
    function size(Map storage map) internal view returns (uint) {
        return map.keys.length;
    }
 
    function set(Map storage map, address key, uint val) internal {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }
 
    function remove(Map storage map, address key) internal {
        if (!map.inserted[key]) {
            return;
        }
 
        delete map.inserted[key];
        delete map.values[key];
 
        uint index = map.indexOf[key];
        uint lastIndex = map.keys.length - 1;
        address lastKey = map.keys[lastIndex];
 
        map.indexOf[lastKey] = index;
        delete map.indexOf[key];
 
        map.keys[index] = lastKey;
        map.keys.pop();
    }
}
// File: contracts/IUniswapV2Factory.sol


pragma solidity ^0.8.17;

interface IUniswapV2Factory {
    
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
 
    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);
 
    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);
    
    function allPairsLength() external view returns (uint);
 
    function createPair(address tokenA, address tokenB) external returns (address pair);
 
    function setFeeTo(address) external;
 
    function setFeeToSetter(address) external;
}
 



// File: contracts/IUniswapV2Pair.sol

pragma solidity ^0.8.17;


interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function factory() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function kLast() external view returns (uint256);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

////// src/IUniswapV2Router02.sol
/* pragma solidity 0.8.10; */
/* pragma experimental ABIEncoderV2; */

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
// File: contracts/IDividendPayingTokenOptional.sol



pragma solidity ^0.8.7;


/// @title Dividend-Paying Token Optional Interface
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev OPTIONAL functions for a dividend-paying token contract.
interface IDividendPayingTokenOptional {
  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function withdrawableDividendOf(address _owner) external view returns(uint256);

  /// @notice View the amount of dividend in wei that an address has withdrawn.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has withdrawn.
  function withdrawnDividendOf(address _owner) external view returns(uint256);

  /// @notice View the amount of dividend in wei that an address has earned in total.
  /// @dev accumulativeDividendOf(_owner) = withdrawableDividendOf(_owner) + withdrawnDividendOf(_owner)
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has earned in total.
  function accumulativeDividendOf(address _owner) external view returns(uint256);
}
// File: contracts/IDividendPayingToken.sol



pragma solidity ^0.8.7;


/// @title Dividend-Paying Token Interface
/// @dev An interface for a dividend-paying token contract.
interface IDividendPayingToken {
  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function dividendOf(address _owner) external view returns(uint256);

  /// @notice Distributes ether to token holders as dividends.
  /// @dev SHOULD distribute the paid ether to token holders as dividends.
  ///  SHOULD NOT directly transfer ether to token holders in this function.
  ///  MUST emit a `DividendsDistributed` event when the amount of distributed ether is greater than 0.
  function distributeDividends() external payable;

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev SHOULD transfer `dividendOf(msg.sender)` wei to `msg.sender`, and `dividendOf(msg.sender)` SHOULD be 0 after the transfer.
  ///  MUST emit a `DividendWithdrawn` event if the amount of ether transferred is greater than 0.
  function withdrawDividend() external;

  /// @dev This event MUST emit when ether is distributed to token holders.
  /// @param from The address which sends ether to this contract.
  /// @param weiAmount The amount of distributed ether in wei.
  event DividendsDistributed(
    address indexed from,
    uint256 weiAmount
  );

  /// @dev This event MUST emit when an address withdraws their dividend.
  /// @param to The address which withdraws ether from this contract.
  /// @param weiAmount The amount of withdrawn ether in wei.
  event DividendWithdrawn(
    address indexed to,
    uint256 weiAmount
  );
}
// File: contracts/SafeMathInt.sol

pragma solidity ^0.8.17;

library SafeMathInt {
  function mul(int256 a, int256 b) internal pure returns (int256) {
    // Prevent overflow when multiplying INT256_MIN with -1
    // https://github.com/RequestNetwork/requestNetwork/issues/43
    require(!(a == - 2**255 && b == -1) && !(b == - 2**255 && a == -1));
 
    int256 c = a * b;
    require((b == 0) || (c / b == a));
    return c;
  }
 
  function div(int256 a, int256 b) internal pure returns (int256) {
    // Prevent overflow when dividing INT256_MIN by -1
    // https://github.com/RequestNetwork/requestNetwork/issues/43
    require(!(a == - 2**255 && b == -1) && (b > 0));
 
    return a / b;
  }
 
  function sub(int256 a, int256 b) internal pure returns (int256) {
    require((b >= 0 && a - b <= a) || (b < 0 && a - b > a));
 
    return a - b;
  }
 
  function add(int256 a, int256 b) internal pure returns (int256) {
    int256 c = a + b;
    require((b >= 0 && c >= a) || (b < 0 && c < a));
    return c;
  }
 
  function toUint256Safe(int256 a) internal pure returns (uint256) {
    require(a >= 0);
    return uint256(a);
  }
}
// File: contracts/SafeMathUint.sol

pragma solidity ^0.8.17;

/**
 * @title SafeMathUint
 * @dev Math operations with safety checks that revert on error
 */
library SafeMathUint {
  function toInt256Safe(uint256 a) internal pure returns (int256) {
    int256 b = int256(a);
    require(b >= 0);
    return b;
  }
}
// File: @openzeppelin/contracts/utils/math/SafeMath.sol


// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
library SafeMath {
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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

// File: contracts/IUniswapV2Router.sol


pragma solidity ^0.8.17;

interface IUniswapV2Router {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/interfaces/IERC20.sol


// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;


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

// File: @openzeppelin/contracts/utils/Context.sol


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

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;




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
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
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
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
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
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
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
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
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
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
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

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


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
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
}

// File: contracts/DividendPayingToken.sol



pragma solidity ^0.8.17;








/// @title Dividend-Paying Token
/// @dev A mintable ERC20 token that allows anyone to pay and distribute ether
///  to token holders as dividends and allows token holders to withdraw their dividends.
///  Reference: the source code of PoWH3D: https://etherscan.io/address/0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe#code
contract DividendPayingToken is ERC20, IDividendPayingToken, IDividendPayingTokenOptional, Ownable {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  // With `magnitude`, we can properly distribute dividends even if the amount of received ether is small.
  // For more discussion about choosing the value of `magnitude`,
  //  see https://github.com/ethereum/EIPs/issues/1726#issuecomment-472352728
  uint256 constant internal magnitude = 2**128;

  uint256 internal magnifiedDividendPerShare;

  // About dividendCorrection:
  // If the token balance of a `_user` is never changed, the dividend of `_user` can be computed with:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user)`.
  // When `balanceOf(_user)` is changed (via minting/burning/transferring tokens),
  //   `dividendOf(_user)` should not be changed,
  //   but the computed value of `dividendPerShare * balanceOf(_user)` is changed.
  // To keep the `dividendOf(_user)` unchanged, we add a correction term:
  //   `dividendOf(_user) = dividendPerShare * balanceOf(_user) + dividendCorrectionOf(_user)`,
  //   where `dividendCorrectionOf(_user)` is updated whenever `balanceOf(_user)` is changed:
  //   `dividendCorrectionOf(_user) = dividendPerShare * (old balanceOf(_user)) - (new balanceOf(_user))`.
  // So now `dividendOf(_user)` returns the same value before and after `balanceOf(_user)` is changed.
  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping(address => bool) internal _isAuth;

  address public dividendToken;

  uint256 public totalDividendsDistributed;

  constructor(string memory _name, string memory _symbol, address _dividendToken) ERC20(_name, _symbol) {
    dividendToken = _dividendToken;
    _isAuth[msg.sender] = true;
  }

  /// @dev Distributes dividends whenever ether is paid to this contract.
  receive() external payable {
    distributeDividends();
  }

  /// @notice Distributes ether to token holders as dividends.
  /// @dev It reverts if the total supply of tokens is 0.
  /// It emits the `DividendsDistributed` event if the amount of received ether is greater than 0.
  /// About undistributed ether:
  ///   In each distribution, there is a small amount of ether not distributed,
  ///     the magnified amount of which is
  ///     `(msg.value * magnitude) % totalSupply()`.
  ///   With a well-chosen `magnitude`, the amount of undistributed ether
  ///     (de-magnified) in a distribution can be less than 1 wei.
  ///   We can actually keep track of the undistributed ether in a distribution
  ///     and try to distribute it in the next distribution,
  ///     but keeping track of such data on-chain costs much more than
  ///     the saved ether, so we don't do that.
  function distributeDividends() public override payable {
    require(totalSupply() > 0);

    if (msg.value > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (msg.value).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, msg.value);

      totalDividendsDistributed = totalDividendsDistributed.add(msg.value);
    }
  }


  
  function distributeTokenDividends(uint256 amount) public onlyOwner {
    require(totalSupply() > 0);

    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, amount);

      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }


  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
  function withdrawDividend() public virtual override {
    _withdrawDividendOfUser(payable(msg.sender));
  }

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
  function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
    uint256 _withdrawableDividend = withdrawableDividendOf(user);
    if (_withdrawableDividend > 0) {
      withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
      emit DividendWithdrawn(user, _withdrawableDividend);
      (bool success,) = user.call{value: _withdrawableDividend, gas: 3000}("");

      if(!success) {
        withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
        return 0;
      }

      return _withdrawableDividend;
    }

    return 0;
  }


  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function dividendOf(address _owner) public view override returns(uint256) {
    return withdrawableDividendOf(_owner);
  }

  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function withdrawableDividendOf(address _owner) public view override returns(uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  /// @notice View the amount of dividend in wei that an address has withdrawn.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has withdrawn.
  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }


  /// @notice View the amount of dividend in wei that an address has earned in total.
  /// @dev accumulativeDividendOf(_owner) = withdrawableDividendOf(_owner) + withdrawnDividendOf(_owner)
  /// = (magnifiedDividendPerShare * balanceOf(_owner) + magnifiedDividendCorrections[_owner]) / magnitude
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has earned in total.
  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
    return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
  }


  /// @dev Set the address of the dividend token
  /// @param _dividendToken address of the dividend token being set
  function setDividendTokenAddress(address _dividendToken) external virtual onlyOwner{
      dividendToken = _dividendToken;
  }

    
  /// @dev Set Authorized accounts for calling external functionts
  /// @param account address of the account being authorized
  function setAuth(address account, bool status) external onlyOwner{
      _isAuth[account] = status;
  }

  /// @dev Internal function that transfer tokens from one address to another.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param from The address to transfer from.
  /// @param to The address to transfer to.
  /// @param value The amount to be transferred.
  function _transfer(address from, address to, uint256 value) internal virtual override {
    require(false);

    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
  }

  /// @dev Internal function that mints tokens to an account.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param account The account that will receive the created tokens.
  /// @param value The amount that will be created.
  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  /// @dev Internal function that burns an amount of the token of a given account.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param account The account whose tokens will be burnt.
  /// @param value The amount that will be burnt.
  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
}
// File: contracts/MarshelleInuDividendTracker.sol

pragma solidity ^0.8.17;






contract MarshelleInuDividendTracker is DividendPayingToken {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;
 
    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;
 
    mapping (address => bool) public excludedFromDividends;
 
    mapping (address => uint256) public lastClaimTimes;
 
    uint256 public claimWait;
    uint256 public minimumTokenBalanceForDividends;

    

    event ExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(
        uint256 indexed newValue, 
        uint256 indexed oldValue
    );
 
    event Claim(
        address indexed account, 
        uint256 amount, 
        bool indexed automatic
    );
 
    constructor(address _dividentToken) DividendPayingToken("MarshelleInu_Tracker", "MarshelleInu_Tracker",_dividentToken) {
    	claimWait = 60;
        minimumTokenBalanceForDividends = 1_000_0 * (10**18);
    }
 
    function _transfer(address, address, uint256) pure internal override {
        require(false, "MarshelleInu_Tracker: No transfers allowed");
    }
 
    function withdrawDividend() pure public override {
        require(false, "MarshelleInu_Tracker: withdrawDividend disabled. Use the 'claim' function on the main MarshelleInu contract.");
    }
 
    function setDividendTokenAddress(address newToken) external override onlyOwner {
      dividendToken = newToken;
    }


    function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
        require(_newMinimumBalance != minimumTokenBalanceForDividends, "New mimimum balance for dividend cannot be same as current minimum balance");
        minimumTokenBalanceForDividends = _newMinimumBalance * (10**9);
    }


 
    function excludeFromDividends(address account) external onlyOwner {
    	require(!excludedFromDividends[account],"Address already excluded from dividends");
    	excludedFromDividends[account] = true;
 
    	_setBalance(account, 0);
    	tokenHoldersMap.remove(account);
 
    	emit ExcludeFromDividends(account);
    }
    function includeInDividends(address account) external onlyOwner {
        excludedFromDividends[account] = false;
    }
 
    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 3600 && newClaimWait <= 86400, "MarshelleInu_Tracker: claimWait must be updated to between 1 and 24 hours");
        require(newClaimWait != claimWait, "MarshelleInu_Tracker: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }
 
    function getLastProcessedIndex() external view returns(uint256) {
    	return lastProcessedIndex;
    }
 
    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }
 
 
    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;
 
        index = tokenHoldersMap.getIndexOfKey(account);
 
        iterationsUntilProcessed = -1;
 
        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;
 
 
                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }
 
 
        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);
 
        lastClaimTime = lastClaimTimes[account];
 
        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;
 
        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }
 
    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
    	if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }
 
        address account = tokenHoldersMap.getKeyAtIndex(index);
 
        return getAccount(account);
    }
 
    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    	if(lastClaimTime > block.timestamp)  {
    		return false;
    	}
 
    	return block.timestamp.sub(lastClaimTime) >= claimWait;
    }
 
    function setBalance(
        address payable account, 
        uint256 newBalance
    ) external onlyOwner {
    	if(excludedFromDividends[account]) {
    		return;
    	}
 
    	if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
    		tokenHoldersMap.set(account, newBalance);
    	}
    	else {
            _setBalance(account, 0);
    		tokenHoldersMap.remove(account);
    	}
 
    	processAccount(account, true);
    }
 
    function process(uint256 gas) public returns (uint256, uint256, uint256) {
    	uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
 
    	if(numberOfTokenHolders == 0) {
    		return (0, 0, lastProcessedIndex);
    	}
 
    	uint256 _lastProcessedIndex = lastProcessedIndex;
 
    	uint256 gasUsed = 0;
 
    	uint256 gasLeft = gasleft();
 
    	uint256 iterations = 0;
    	uint256 claims = 0;
 
    	while(gasUsed < gas && iterations < numberOfTokenHolders) {
    		_lastProcessedIndex++;
 
    		if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
    			_lastProcessedIndex = 0;
    		}
 
    		address account = tokenHoldersMap.keys[_lastProcessedIndex];
 
    		if(canAutoClaim(lastClaimTimes[account])) {
    			if(processAccount(payable(account), true)) {
    				claims++;
    			}
    		}
 
    		iterations++;
 
    		uint256 newGasLeft = gasleft();
 
    		if(gasLeft > newGasLeft) {
    			gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
    		}
 
    		gasLeft = newGasLeft;
    	}
 
    	lastProcessedIndex = _lastProcessedIndex;
 
    	return (iterations, claims, lastProcessedIndex);
    }
 
    function processAccount(
        address payable account, 
        bool automatic
    ) public onlyOwner returns (bool) {

        uint256 amount = _withdrawDividendOfUser(account);
 
    	if(amount > 0) {
    		lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
    		return true;
    	}
 
    	return false;
    }
}

// File: contracts/MarshelleInu.sol


pragma solidity ^0.8.17;

/*****
 *   ,---.    ,---.   ____    .-------.       .-'''-. .---.  .---.     .-''-.    .---.     .---.       .-''-.          .-./`) ,---.   .--.  ___    _
 *   |    \  /    | .'  __ `. |  _ _   \     / _     \|   |  |_ _|   .'_ _   \   | ,_|     | ,_|     .'_ _   \         \ .-.')|    \  |  |.'   |  | |
 *   |  ,  \/  ,  |/   '  \  \| ( ' )  |    (`' )/`--'|   |  ( ' )  / ( ` )   ',-./  )   ,-./  )    / ( ` )   '        / `-' \|  ,  \ |  ||   .'  | |
 *   |  |\_   /|  ||___|  /  ||(_ o _) /   (_ o _).   |   '-(_{;}_). (_ o _)  |\  '_ '`) \  '_ '`) . (_ o _)  |         `-'`"`|  |\_ \|  |.'  '_  | |
 *   |  _( )_/ |  |   _.-`   || (_,_).' __  (_,_). '. |      (_,_) |  (_,_)___| > (_)  )  > (_)  ) |  (_,_)___|         .---. |  _( )_\  |'   ( \.-.|
 *   | (_ o _) |  |.'   _    ||  |\ \  |  |.---.  \  :| _ _--.   | '  \   .---.(  .  .-' (  .  .-' '  \   .---.         |   | | (_ o _)  |' (`. _` /|
 *   |  (_,_)  |  ||  _( )_  ||  | \ `'   /\    `-'  ||( ' ) |   |  \  `-'    / `-'`-'|___`-'`-'|___\  `-'    /         |   | |  (_,_)\  || (_ (_) _)
 *   |  |      |  |\ (_ o _) /|  |  \    /  \       / (_{;}_)|   |   \       /   |        \|        \\       /          |   | |  |    |  | \ /  . \ /
 *   '--'      '--' '.(_,_).' ''-'   `'-'    `-...-'  '(_,_) '---'    `'-..-'    `--------``--------` `'-..-'           '---' '--'    '--'  ``-'`-''
 *****/










contract MarshelleInu  is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router private uniswapV2Router;
    MarshelleInuDividendTracker public marshelleInuDividendTracker;
    
    address private uniswapV2Pair;
    address public constant deadAddress = address(0xdead);
    address public MRI = address(0x0913dDAE242839f8995c0375493f9a1A3Bddc977);
    address public marketingWallet = address(0x4EB85dA43eb3587E21294d4d5a6922892CF12658);
    address public devWallet = address(0x721a025a1dA21C22Cc811E3117053939D31047Ce);

    // boolean
    bool private isSwapping;
    bool swapAndLiquifyEnabled;
    bool public ProcessDividendStatus;
    // uint
    uint256 public _totalSupply;
    uint256 public maxBuyTxAmount;
    uint256 public maxSellTxAmount;
    uint256 public maxWalletAmount;
    uint256 public swapAndLiquifyThreshold;
    uint256 public tradingEnabledAt;

    uint256 private buyTotalFees;
    uint256 private buyMarketingFee;
    uint256 private buyDevFee;
    uint256 private buyLiquidityFee;
    uint256 private buyReflectionsFee;

    uint256 private sellTotalFees;
    uint256 private sellMarketingFee;
    uint256 private sellDevFee;
    uint256 private sellLiquidityFee;
    uint256 private sellReflectionsFee;


    uint256 private tokensForMarketing;
    uint256 private tokensForDev;
    uint256 private tokensForLiquidity;
    uint256 private tokensForReflections;

    uint256 public gasForProcessing = 300000;

    // mappings
    mapping(address => bool) public _isExcludedFromFees;
    mapping(address => bool) public _isExcludedFromMaxTrade;
    mapping(address => bool) public _isExcludedFromMaxWallet;
    mapping(address => bool) public automatedMarketMakerPairs;
  //  mapping(address => bool) public presaleAcc;


    event UpdateBuyFees(
        uint256 buyTotalFees,
        uint256 buyMarketingFee,
        uint256 buyDevFee,
        uint256 buyLiquidityFee,
        uint256 buyReflectionsFee
    );
    event UpdateSellFees(
        uint256 sellTotalFees,
        uint256 sellMarketingFee,
        uint256 sellDevFee,
        uint256 sellLiquidityFee,
        uint256 sellReflectionsFee
    );
    event UpdateUniswapV2Router(
        address indexed newRouter,
        address indexed oldRouter
    );
    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeFromMaxTrade(address indexed account, bool isExcluded);
    event ExcludeFromMaxWallet(address indexed account, bool isExcluded);
    event SetAutomatedMarketMakerPair(
        address indexed pair,
        bool indexed status
    );
    event UpdateDevWallet(address indexed newWallet, address indexed oldWallet);
    event UpdateMarketingWallet(
        address indexed newWallet,
        address indexed oldWallet
    );
    event UpdateDividendToken(address indexed oldDividendToken, address indexed newDividendToken);
    event IncludeInDividends(address indexed wallet);
    event ExcludeFromDividends(address indexed wallet);
    event UpdateDividendTracker(
        address oldDividendTracker,
        address newDividendTracker
    );
    event UpdateDividendAddress(
        address oldDividendAddress,
        address newDividendAddress
    );
    event UpdateSwapAndLiquify(bool enabled);
    event UpadateDividendEnabled(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiquidity
    );
    event SendDividends(uint256 tokensSwapped, uint256 amount);
    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor() ERC20("MarshelleInu", "ELLE") {
        IUniswapV2Router _uniswapV2Router = IUniswapV2Router(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D  
        );

        uniswapV2Router = _uniswapV2Router;

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        _initializeVariables();

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(msg.sender, _totalSupply);
    }

    receive() external payable {}

    // initialize state variables at deploy
    function _initializeVariables() private {
        _isExcludedFromFees[uniswapV2Pair] = true;

        _isExcludedFromMaxTrade[uniswapV2Pair] = true;
        _isExcludedFromMaxWallet[uniswapV2Pair] = true;
        automatedMarketMakerPairs[uniswapV2Pair] = true;

        // exclude from paying fees or having max transaction amount
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[deadAddress] = true;

        _isExcludedFromMaxTrade[owner()] = true;
        _isExcludedFromMaxTrade[address(this)] = true;
        _isExcludedFromMaxTrade[deadAddress] = true;
        _isExcludedFromMaxWallet[owner()] = true;
     //   _isExcludedFromMaxWallet[address(Oxdead)] = true;
        _isExcludedFromMaxWallet[address(this)] = true;
        marshelleInuDividendTracker = new MarshelleInuDividendTracker(MRI);
        marshelleInuDividendTracker.setAuth(owner(), true);
//        _allowances[address(this)][address(uniswapV2Router)] = uint256(-1);
    //    _allowances[address(this)][address(router)] = uint256(-1);

        marshelleInuDividendTracker.excludeFromDividends(address(marshelleInuDividendTracker));
        marshelleInuDividendTracker.excludedFromDividends(address(this));
        marshelleInuDividendTracker.excludedFromDividends(address(uniswapV2Router));        
        marshelleInuDividendTracker.excludedFromDividends(deadAddress);
        marshelleInuDividendTracker.excludedFromDividends(owner());

 //       presaleAcc[owner()] = true;
        _totalSupply = 1_000_000_000 * 1e18;
        maxBuyTxAmount = 20_000_000 * 1e18; // 2% of total supply
        maxSellTxAmount = 10_000_000 * 1e18; // 1% of total supply
        maxWalletAmount = 20_000_000 * 1e18; // 2% of total supply
        swapAndLiquifyThreshold = (_totalSupply * 2) / 10000; // 0.02% contarct swap

        buyMarketingFee = 3;
        buyDevFee = 1;
        buyLiquidityFee = 2;
        buyReflectionsFee = 2;
        buyTotalFees =
            buyMarketingFee +
            buyDevFee +
            buyLiquidityFee +
            buyReflectionsFee;

        sellMarketingFee = 7;
        sellDevFee = 1;
        sellLiquidityFee = 2;
        sellReflectionsFee = 2;
        sellTotalFees =
            sellMarketingFee +
            sellDevFee +
            sellLiquidityFee +
            sellReflectionsFee;

        ProcessDividendStatus = true;
        marketingWallet = deadAddress;
        devWallet = deadAddress;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        //tx utility vars
        //        uint256 trade_type = 0;

        bool overSwapThreshold = balanceOf(address(this)) >=
            swapAndLiquifyThreshold;


        if (!isSwapping) {
            // not a contract swap

            if (automatedMarketMakerPairs[from]) {
                //buy transaction

                if (!_isExcludedFromMaxTrade[to]) {
                    // tx limit
                    if (amount > maxBuyTxAmount)
                        revert TransferError("Exceeded max buy TxAmount");
                }

                if (!_isExcludedFromMaxWallet[to]) {
                    // wallet limit
                    if (balanceOf(to) + amount > maxWalletAmount)
                        revert TransferError("Exceeded max buy TxAmount");
                }

                // takeFees - buy
                if (buyTotalFees > 0 && !_isExcludedFromFees[to]) {
                    uint256 txFees = (amount * buyTotalFees) / 100;
                    amount -= txFees;
                    tokensForMarketing +=
                        (txFees * buyMarketingFee) /
                        buyTotalFees;
                    tokensForDev += (txFees * buyDevFee) / buyTotalFees;
                    tokensForLiquidity +=
                        (txFees * buyLiquidityFee) /
                        buyTotalFees;
                    tokensForReflections +=
                        (txFees * buyReflectionsFee) /
                        buyTotalFees;
                    super._transfer(from, address(this), txFees);
                }
            } else if (automatedMarketMakerPairs[to]) {
                //sell transaction
                if (
                    swapAndLiquifyEnabled &&
                    sellTotalFees > 0 &&
                    overSwapThreshold
                ) swapBack();   

                if (!_isExcludedFromMaxTrade[from]) {
                    if (amount > maxSellTxAmount)
                        revert TransferError("Exceeded max sell TxAmount");
                }
                // check whether to sell from the contract
                
            // takefees - sell
            if (sellTotalFees > 0 && !_isExcludedFromFees[from]) {
                uint256 txFees = (amount * sellTotalFees) / 100;
                amount -= txFees;
                tokensForMarketing +=
                    (txFees * sellMarketingFee) /
                    sellTotalFees;
                tokensForDev += (txFees * sellDevFee) / sellTotalFees;
                tokensForLiquidity +=
                    (txFees * sellLiquidityFee) /
                    sellTotalFees;
                tokensForReflections +=
                    (txFees * sellReflectionsFee) /
                    sellTotalFees;

                super._transfer(from, address(this), txFees);
            }
        }
        }

        // transfer tokens erc20 standard
        super._transfer(from, to, amount);

        //set dividends
        try
            marshelleInuDividendTracker.setBalance(payable(from), balanceOf(from))
        {} catch {}
        try
            marshelleInuDividendTracker.setBalance(payable(to), balanceOf(to))
        {} catch {}
        // auto-claims one time per transaction
        if (!isSwapping && ProcessDividendStatus) {
            uint256 gas = gasForProcessing;

            try marshelleInuDividendTracker.process(gas) returns (
                uint256 iterations,
                uint256 claims,
                uint256 lastProcessedIndex
            ) {
                emit ProcessedDividendTracker(
                    iterations,
                    claims,
                    lastProcessedIndex,
                    true,
                    gas,
                    tx.origin
                );
            } catch {}
        }
    }


    function swapTokensForETH(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadAddress,
            block.timestamp
        );
    }

    function swapETHForMRI(uint256 ethAmount) private {

        if(ethAmount > 0){
            address[] memory path = new address[](2);
            path[0] = uniswapV2Router.WETH();
            path[1] = MRI;
            
            uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: ethAmount}(
                0,
                path,
                address(this),
                block.timestamp
            );
        }
    }

    function swapBack() private {
        isSwapping = true; 
        uint256 contractBalance = balanceOf(address(this));

        uint256 totalTokens = tokensForDev +
            tokensForMarketing +
            tokensForLiquidity +
            tokensForReflections;
            
        bool success;
        uint256 swapBalance;
        if (contractBalance == 0 || totalTokens == 0) {
            return;
        }

        if(totalTokens > swapAndLiquifyThreshold){
            // never swap more than the threshold
            swapBalance = swapAndLiquifyThreshold;
        } else{
            swapBalance = totalTokens;
        }
        
        // Halve the amount of liquidity tokens

        uint256 liquidityTokens = (swapBalance * tokensForLiquidity) /
            totalTokens /
            2;
        uint256 amountToSwapForETH = swapBalance - liquidityTokens;

        uint256 initialETHBalance = address(this).balance;

        swapTokensForETH(amountToSwapForETH);

        uint256 ethBalance = address(this).balance - initialETHBalance;

        uint256 ethForDev = (ethBalance * tokensForDev) / totalTokens;

        uint256 ethForLiquidity = (ethBalance * tokensForLiquidity) /
            totalTokens;

        uint256 ethForReflections = (ethBalance * tokensForReflections) /
            totalTokens;

        (success, ) = address(devWallet).call{value: ethForDev}("");

        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
            emit SwapAndLiquify(
                amountToSwapForETH,
                ethForLiquidity,
                tokensForLiquidity
            );
        }

        swapETHForMRI(ethForReflections);

        uint256 tokenBalance = IERC20(MRI).balanceOf(address(this));
        success = IERC20(MRI).transfer(
            address(marshelleInuDividendTracker),
            tokenBalance
        );

        if (success) {
            marshelleInuDividendTracker.distributeTokenDividends(tokenBalance);
            emit SendDividends(tokenBalance, ethForReflections);
        }

        (success, ) = address(marketingWallet).call{
            value: address(this).balance
        }("");

        contractBalance = balanceOf(address(this));

        tokensForLiquidity =
            (contractBalance * sellLiquidityFee) /
            sellTotalFees;
        tokensForMarketing =
            (contractBalance * sellMarketingFee) /
            sellTotalFees;
        tokensForDev = (contractBalance * sellDevFee) / sellTotalFees;
        tokensForReflections =
            (contractBalance * sellReflectionsFee) /
            sellTotalFees;

        isSwapping = false;
    }    

    function manualSwapBack() external onlyOwner{
        if(balanceOf(address(this)) > 0 )
            swapBack();       
    }
    

    function claim() external {
        marshelleInuDividendTracker.processAccount(payable(msg.sender), false);
    }

    /////////////////////////////////////////////////////////////////////////////////////
    ///// Setter functions
    /////////////////////////////////////////////////////////////////////////////////////



    /**
     * @dev Change the threshold for making the contract sell and adding liquidity
     * @param newThreshold : new
     */
    function updateSwapTokensAtAmount(uint256 newThreshold)
        external
        onlyOwner
        returns (bool)
    {
        if (newThreshold < (totalSupply() * 1) / 100000)
            revert InvalidSwapTokenAmount(
                "Swap amount cannot be lower than 0.001% total supply."
            );
    if (newThreshold > (totalSupply() * 1) / 1000)
            revert InvalidSwapTokenAmount(
                "Swap amount cannot be higher than 0.1% total supply."
            );
        swapAndLiquifyThreshold = newThreshold;
        return true;
    }

    function updateMaxTxnAmount(uint256 newMaxBuy, uint256 newMaxSell)
        external
        onlyOwner
    {
        if (newMaxBuy < ((totalSupply() * 5) / 1000) / 1e18)
            revert InvalidMaxTradeAmount(
                "Cannot set max buy lower than 0.5%"
            );
        if (newMaxSell < ((totalSupply() * 5) / 1000) / 1e18)
            revert InvalidMaxTradeAmount(
                "Cannot set max sell lower than 0.5%"
            );

        maxBuyTxAmount = newMaxBuy * (10**18);
        maxSellTxAmount = newMaxSell * (10**18);
    }

    function updateMaxWalletAmount(uint256 newMaxWallet) external onlyOwner {
        if (newMaxWallet < ((totalSupply() * 5) / 1000) / 1e18)
            revert InvalidMaxWalletAmount(
                "Cannot set maxWallet lower than 0.5%"
            );
        maxWalletAmount = newMaxWallet * (10**18);
    }

    function excludeFromMaxWallet(address account, bool isExcluded)
        external
        onlyOwner
    {
        _isExcludedFromMaxWallet[account] = isExcluded;
        emit ExcludeFromMaxWallet(account, isExcluded);
    }

    function excludeFromMaxTrade(address account, bool isExcluded)
        external
        onlyOwner
    {
        _isExcludedFromMaxTrade[account] = isExcluded;
        emit ExcludeFromMaxTrade(account, isExcluded);
    }

    function excludeFromFees(address account, bool isExcluded)
        external
        onlyOwner
    {
        _isExcludedFromFees[account] = isExcluded;
        emit ExcludeFromFees(account, isExcluded);
    }

    function setAutomatedMarketMakerPair(address pair, bool status)
        external
        onlyOwner
    {
        automatedMarketMakerPairs[pair] = status;
        emit SetAutomatedMarketMakerPair(pair, status);
    }

    function updateBuyFees(
        uint256 _buyMarketingFee,
        uint256 _buyDevFee,
        uint256 _buyLiquidityFee,
        uint256 _buyReflectionsFee
    ) external onlyOwner {
        buyMarketingFee = _buyMarketingFee;
        buyDevFee = _buyDevFee;
        buyLiquidityFee = _buyLiquidityFee;
        buyReflectionsFee = _buyReflectionsFee;
        buyTotalFees = 
            buyMarketingFee +
            buyDevFee +
            buyLiquidityFee +
            buyReflectionsFee;
        if (sellTotalFees + buyTotalFees > 25)
            revert InvalidTotalFees("Total Fees must be less than 25%");
        emit UpdateBuyFees(
            buyTotalFees,
            buyMarketingFee,
            buyDevFee,
            buyLiquidityFee,
            buyReflectionsFee
        );
    }

    function updateSellFees(
        uint256 _sellMarketingFee,
        uint256 _sellDevFee,
        uint256 _sellLiquidityFee,
        uint256 _sellReflectionsFee
    ) external onlyOwner {
        sellMarketingFee = _sellMarketingFee;
        sellDevFee = _sellDevFee;
        sellLiquidityFee = _sellLiquidityFee;
        sellReflectionsFee = _sellReflectionsFee;
        sellTotalFees =
            sellMarketingFee +
            sellDevFee +
            sellLiquidityFee +
            sellReflectionsFee;
        if (sellTotalFees + buyTotalFees > 25)
            revert InvalidTotalFees("Total Fees must be less than 25%");
        emit UpdateSellFees(
            sellTotalFees,
            sellMarketingFee,
            sellDevFee,
            sellLiquidityFee,
            sellReflectionsFee
        );
    }

    function setDevWallet (address payable _devWallet) external onlyOwner{
        address oldAddress = devWallet;
        devWallet = _devWallet;
        emit UpdateDevWallet(oldAddress, _devWallet);
    }

    function setMarketingWallet(address payable _marketingWallet) external onlyOwner{
        address oldAddress = marketingWallet;
        marketingWallet = _marketingWallet;
        emit UpdateMarketingWallet(oldAddress, _marketingWallet);
    }


    function setSwapAndLiquifyEnabled(
        bool _status
        ) external onlyOwner {
        
        swapAndLiquifyEnabled = _status;
    }

    /////////////////////////////////////////////////////////////////////////////////////
    //// dividend setters
    /////////////////////////////////////////////////////////////////////////////////////

    function processDividendTracker(uint256 gas) external {
        (
            uint256 iterations,
            uint256 claims,
            uint256 lastProcessedIndex
        ) = marshelleInuDividendTracker.process(gas);
        emit ProcessedDividendTracker(
            iterations,
            claims,
            lastProcessedIndex,
            false,
            gas,
            tx.origin
        );
    }

    function updateDividendAddress(address newDividendAddress)
        external
        onlyOwner
    {
        address oldAddress = MRI;
        MRI = newDividendAddress;
        marshelleInuDividendTracker.setDividendTokenAddress(newDividendAddress);
        emit UpdateDividendToken(oldAddress, MRI);
    }

    function updateDividendInclusion(address account, bool isIncluded) external onlyOwner {
        if(isIncluded){
            marshelleInuDividendTracker.includeInDividends(account);
            emit IncludeInDividends(account);
        } else{
            marshelleInuDividendTracker.excludeFromDividends(account);
            emit ExcludeFromDividends(account);
        }
    }

    /////////////////////////////////////////////////////////////////////////////////////
    ///// Getter functions
    /////////////////////////////////////////////////////////////////////////////////////

    function getLastProcessedIndex() external view returns (uint256) {
        return marshelleInuDividendTracker.getLastProcessedIndex();
    }

    function getNumberOfMarshelleDividendTokenHolders()
        external
        view
        returns (uint256)
    {
        return marshelleInuDividendTracker.getNumberOfTokenHolders();
    }

    function getNumberOfMarshelleDividends() external view returns (uint256) {
        return marshelleInuDividendTracker.totalSupply();
    }

    function getClaimWait() external view returns (uint256) {
        return marshelleInuDividendTracker.claimWait();
    }

    function getTotalMarshelleDividendsDistributed()
        external
        view
        returns (uint256)
    {
        return marshelleInuDividendTracker.totalDividendsDistributed();
    }

    function withdrawableMarshelleDividendOf(address account)
        public
        view
        returns (uint256)
    {
        return marshelleInuDividendTracker.withdrawableDividendOf(account);
    }

    function marshelleInuDividendTokenBalanceOf(address account)
        public
        view
        returns (uint256)
    {
        return marshelleInuDividendTracker.balanceOf(account);
    }

    function getAccountMarshelleDividendsInfo(address account)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return marshelleInuDividendTracker.getAccount(account);
    }

    function getAccountMarshelleDividendsInfoAtIndex(uint256 index)
        external
        view
        returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return marshelleInuDividendTracker.getAccountAtIndex(index);
    }

    function getBuyFees()
        external
        view
        returns (
            uint256 _buyMarketingFee,
            uint256 _buyDevFee,
            uint256 _buyLiquidityFee,
            uint256 _buyReflectionsFee
        )
    {
        return (buyMarketingFee, 
                buyDevFee, 
                buyLiquidityFee, 
                buyReflectionsFee);
    }

    function getSellFees()
        external
        view
        returns (
            uint256 _sellMarketingFee,
            uint256 _sellDevFee,
            uint256 _sellLiquidityFee,
            uint256 _sellReflectionFee
        )
    {
        return (
            sellMarketingFee,
            sellDevFee,
            sellLiquidityFee,
            sellReflectionsFee
        );
    }
}