// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/math/SafeMath.sol';

import '../libraries/FixedPointMath.sol';
import '../libraries/TransferHelper.sol';
import '../interfaces/IDetailedERC20.sol';
import '../interfaces/IHarvestVaultAdapter.sol';
import '../interfaces/IHarvestVault.sol';
import '../interfaces/IHarvestFarm.sol';

/// @title YearnVaultAdapter
///
/// @dev A vault adapter implementation which wraps a yEarn vault.
contract HarvestVaultAdapter is IHarvestVaultAdapter {
	using FixedPointMath for FixedPointMath.uq192x64;
	using TransferHelper for address;
	using SafeMath for uint256;

	/// @dev The vault that the adapter is wrapping.
	IHarvestVault public vault;

	IHarvestFarm public farm;

	/// @dev The address which has admin control over this contract.
	address public admin;

	/// @dev The decimals of the token.
	uint256 public decimals;

	address public treasury;

	constructor(
		IHarvestVault _vault,
		IHarvestFarm _farm,
		address _admin,
		address _treasury
	) public {
		vault = _vault;
		farm = _farm;
		admin = _admin;
		treasury = _treasury;
		updateVaultApproval();
		updateFarmApproval();
		decimals = _vault.decimals();
	}

	/// @dev A modifier which reverts if the caller is not the admin.
	modifier onlyAdmin() {
		require(admin == msg.sender, 'HarvestVaultAdapter: only admin');
		_;
	}

	/// @dev Gets the token that the vault accepts.
	///
	/// @return the accepted token.
	function token() external view override returns (address) {
		return vault.underlying();
	}

	function lpToken() external view override returns (address) {
		return address(vault);
	}

	function lpTokenInFarm() public view override returns (uint256) {
		return farm.balanceOf(address(this));
	}

	/// @dev Gets the total value of the assets that the adapter holds in the vault.
	///
	/// @return the total assets.
	function totalValue() external view override returns (uint256) {
		return _sharesToTokens(lpTokenInFarm());
	}

	/// @dev Deposits tokens into the vault.
	///
	/// @param _amount the amount of tokens to deposit into the vault.
	function deposit(uint256 _amount) external override {
		vault.deposit(_amount);
	}

	/// @dev Withdraws tokens from the vault to the recipient.
	///
	/// This function reverts if the caller is not the admin.
	///
	/// @param _recipient the account to withdraw the tokes to.
	/// @param _amount    the amount of tokens to withdraw.
	function withdraw(address _recipient, uint256 _amount) external override onlyAdmin {
		vault.withdraw(_tokensToShares(_amount));
		address _token = vault.underlying();
		uint256 _balance = IERC20(_token).balanceOf(address(this));
		_token.safeTransfer(_recipient, _balance);
	}

	/// @dev stake into farming pool.
	function stake(uint256 _amount) external override {
		farm.stake(_amount);
	}

	/// @dev unstake from farming pool.
	function unstake(uint256 _amount) external override onlyAdmin {
		farm.withdraw(_tokensToShares(_amount));
	}

	function claim() external override {
		farm.getReward();
		address _rewardToken = farm.rewardToken();
		uint256 _balance = IERC20(_rewardToken).balanceOf(address(this));
		if (_balance > 0) {
			_rewardToken.safeTransfer(treasury, _balance);
		}
	}

	/// @dev Updates the vaults approval of the token to be the maximum value.
	function updateVaultApproval() public {
		address _token = vault.underlying();
		_token.safeApprove(address(vault), uint256(-1));
	}

	/// @dev Update the farm approval.
	function updateFarmApproval() public {
		address(vault).safeApprove(address(farm), uint256(-1));
	}

	/// @dev Computes the number of tokens an amount of shares is worth.
	///
	/// @param _sharesAmount the amount of shares.
	///
	/// @return the number of tokens the shares are worth.

	function _sharesToTokens(uint256 _sharesAmount) internal view returns (uint256) {
		return _sharesAmount.mul(vault.getPricePerFullShare()).div(10**decimals);
	}

	/// @dev Computes the number of shares an amount of tokens is worth.
	///
	/// @param _tokensAmount the amount of shares.
	///
	/// @return the number of shares the tokens are worth.
	function _tokensToShares(uint256 _tokensAmount) internal view returns (uint256) {
		return _tokensAmount.mul(10**decimals).div(vault.getPricePerFullShare());
	}
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;


library FixedPointMath {
  uint256 public constant DECIMALS = 18;
  uint256 public constant SCALAR = 10**DECIMALS;

  struct uq192x64 {
    uint256 x;
  }

  function fromU256(uint256 value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require(value == 0 || (x = value * SCALAR) / SCALAR == value);
    return uq192x64(x);
  }

  function maximumValue() internal pure returns (uq192x64 memory) {
    return uq192x64(uint256(-1));
  }

  function add(uq192x64 memory self, uq192x64 memory value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require((x = self.x + value.x) >= self.x);
    return uq192x64(x);
  }

  function add(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    return add(self, fromU256(value));
  }

  function sub(uq192x64 memory self, uq192x64 memory value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require((x = self.x - value.x) <= self.x);
    return uq192x64(x);
  }

  function sub(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    return sub(self, fromU256(value));
  }

  function mul(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    uint256 x;
    require(value == 0 || (x = self.x * value) / value == self.x);
    return uq192x64(x);
  }

  function div(uq192x64 memory self, uint256 value) internal pure returns (uq192x64 memory) {
    require(value != 0);
    return uq192x64(self.x / value);
  }

  function cmp(uq192x64 memory self, uq192x64 memory value) internal pure returns (int256) {
    if (self.x < value.x) {
      return -1;
    }

    if (self.x > value.x) {
      return 1;
    }

    return 0;
  }

  function decode(uq192x64 memory self) internal pure returns (uint256) {
    return self.x / SCALAR;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

interface IDetailedERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

interface IHarvestVaultAdapter {
	function totalValue() external view returns (uint256);

	function deposit(uint256) external;

	function withdraw(address, uint256) external;

	function token() external view returns (address);

	function lpToken() external view returns (address);

	function lpTokenInFarm() external view returns (uint256);

	function stake(uint256) external;

	function unstake(uint256) external;

	function claim() external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHarvestVault is IERC20 {
	function underlying() external view returns (address);

	function totalValue() external view returns (uint256);

	function deposit(uint256) external;

	function withdraw(uint256) external;

	function getPricePerFullShare() external view returns (uint256);

	function decimals() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.6.5 <0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IHarvestFarm {
	function rewardToken() external view returns (address);

	function lpToken() external view returns (address);

	function getReward() external;

	function stake(uint256 amount) external;

	function withdraw(uint256) external;

	function rewards(address) external returns (uint256);

	function balanceOf(address) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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