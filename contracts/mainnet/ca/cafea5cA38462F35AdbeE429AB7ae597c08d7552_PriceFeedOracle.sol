// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.5.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../interfaces/IPriceFeedOracle.sol";

interface Aggregator {
  function latestAnswer() external view returns (int);
}

contract PriceFeedOracle is IPriceFeedOracle {
  using SafeMath for uint;

  struct Asset {
    address aggregator;
    uint8 decimals;
  }

  mapping(address => Asset) public assets;
  address constant public ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address public daiAddress;

  constructor (
    address[] memory assetAddresses,
    address[] memory aggregators,
    uint8[] memory decimals,
    address _daiAddress
  ) public {

    require(assetAddresses.length == aggregators.length, "PriceFeedOracle: length mismatch");
    require(assetAddresses.length == decimals.length, "PriceFeedOracle: length mismatch");

    for (uint i = 0; i < assetAddresses.length; i++) {
      assets[assetAddresses[i]] = Asset(aggregators[i], decimals[i]);
    }

    // This is kept for legacy reasons; still used in MCR.sol
    daiAddress = _daiAddress;
  }

  /**
   * @dev Returns the amount of ether in wei that are equivalent to 1 unit (10 ** decimals) of asset
   * @param asset quoted currency
   * @return price in ether
   */
  function getAssetToEthRate(address asset) public view returns (uint) {

    if (asset == ETH) {
      return 1 ether;
    }

    address aggregatorAddress = assets[asset].aggregator;

    if (aggregatorAddress == address(0)) {
      revert("PriceFeedOracle: Oracle asset not found");
    }

    int rate = Aggregator(aggregatorAddress).latestAnswer();
    require(rate > 0, "PriceFeedOracle: Rate must be > 0");

    return uint(rate);
  }

  /**
  * @dev Returns the amount of currency that is equivalent to ethIn amount of ether.
  * @param assetAddress quoted asset
  * @param ethIn amount of ether to be converted to the currency
  * @return price in ether
  */
  function getAssetForEth(address assetAddress, uint ethIn) external view returns (uint) {

    if (assetAddress == ETH) {
      return ethIn;
    }

    Asset memory asset = assets[assetAddress];
    require(asset.decimals > 0, "PriceFeedOracle: Unknown asset");

    int rate = Aggregator(asset.aggregator).latestAnswer();
    require(rate > 0, "PriceFeedOracle: Rate must be > 0");

    return ethIn.mul(10 ** uint(asset.decimals)).div(uint(rate));
  }

}

pragma solidity ^0.5.0;

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
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.5.0;

interface IPriceFeedOracle {

  function daiAddress() external view returns (address);
  function ETH() external view returns (address);

  function getAssetToEthRate(address asset) external view returns (uint);
  function getAssetForEth(address asset, uint ethIn) external view returns (uint);

}