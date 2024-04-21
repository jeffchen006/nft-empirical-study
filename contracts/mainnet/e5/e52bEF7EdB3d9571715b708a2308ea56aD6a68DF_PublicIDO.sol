pragma solidity 0.6.12;

import "../libraries/SafeMath.sol";
import "../interfaces/IERC20.sol";
import "../libraries/TransferHelper.sol";

contract PublicIDO {
    using SafeMath for uint256;

    address public immutable dev;
    address public usdt;
    address public plexus;
    uint256 public price;
    uint256 public priceP2;
    uint256 public idoStartTime;
    uint256 public idoEndTime;
    uint256 public idoStartTimeP2;
    uint256 public idoEndTimeP2;
    uint256 public lockupBlock;
    uint256 public claimDuringBlock;
    uint256 public plexusTotalValue;
    uint256 public plexusTotalValueP2;
    uint256 public usdtHardCap;
    uint256 public usdtSoftCap;
    uint256 public userHardCap;
    uint256 public userSoftCap;
    uint256 public usdtHardCapP2;
    uint256 public usdtSoftCapP2;
    uint256 public userHardCapP2;
    uint256 public userSoftCapP2;
    uint256 public usdtTotalReciveAmount;
    uint256 public usdtTotalReciveAmountP2;
    address[] public userAddress;
    address[] public userAddressP2;
    uint256 public USDT_ACC_PRECESION = 1e6;
    uint256 public PLX_ACC_PRECESION = 1e18;
    struct UserInfo {
        uint256 amount;
        uint256 amountP2;
        uint256 totalReward;
        uint256 lastRewardBlock;
        uint256 recivePLX;
    }

    mapping(address => UserInfo) public userInfo;
    mapping(address => uint256) public userId;
    mapping(address => uint256) public userIdP2;
    event Deposit(address user, uint256 userDepositAmount, uint256 userPLXTotalReward);
    event Claim(address user, uint256 userClaimAmount, uint256 userRecivePLX);
    event refund(address user, uint256 refundAmount);

    constructor(address _usdt, address _plexus) public {
        usdt = _usdt;
        plexus = _plexus;
        claimDuringBlock = 518400;
        dev = msg.sender;
    }

    function init(
        uint256 _plxTotalValue,
        uint256 _usdtHardCap,
        uint256 _usdtSoftCap,
        uint256 _userHardCap,
        uint256 _userSoftCap
    ) public {
        require(msg.sender == dev);
        plexusTotalValue = _plxTotalValue;
        usdtHardCap = _usdtHardCap;
        usdtSoftCap = _usdtSoftCap;
        userHardCap = _userHardCap;
        userSoftCap = _userSoftCap;
        price = (usdtHardCap / (plexusTotalValue / PLX_ACC_PRECESION));
        IERC20(plexus).transferFrom(msg.sender, address(this), plexusTotalValue);
    }

    function initP2(
        uint256 _plxTotalValueP2,
        uint256 _usdtHardCapP2,
        uint256 _usdtSoftCapP2,
        uint256 _userHardCapP2,
        uint256 _userSoftCapP2
    ) public {
        require(msg.sender == dev);
        plexusTotalValueP2 = _plxTotalValueP2;
        usdtHardCapP2 = _usdtHardCapP2;
        usdtSoftCapP2 = _usdtSoftCapP2;
        userHardCapP2 = _userHardCapP2;
        userSoftCapP2 = _userSoftCapP2;
        priceP2 = (usdtHardCapP2 / (plexusTotalValueP2 / PLX_ACC_PRECESION));
        IERC20(plexus).transferFrom(msg.sender, address(this), plexusTotalValueP2);
    }

    function userLength() public view returns (uint256 user) {
        return userAddress.length;
    }

    function userP2Length() public view returns (uint256 user) {
        return userAddressP2.length;
    }

    function deposit(uint256 _userDepositAmount) public {
        require(block.timestamp >= idoStartTime && block.timestamp <= idoEndTime, "PLEXUS : This is not IDO time.");

        uint256 userDepositAmountInt = (_userDepositAmount / price) * price;

        address depositUser = msg.sender;

        require(
            usdtHardCap.sub(usdtTotalReciveAmount) >= userDepositAmountInt,
            "PLEXUS : The deposit amount exceeds the hardcap."
        );

        TransferHelper.safeTransferFrom(usdt, depositUser, address(this), userDepositAmountInt);
        if (userAddress.length == 0) {
            userAddress.push(depositUser);
            userId[depositUser] = userAddress.length - 1;
        } else if ((userId[depositUser] == 0 && userAddress[0] != depositUser)) {
            userAddress.push(depositUser);
            userId[depositUser] = userAddress.length - 1;
        }
        UserInfo memory user = userInfo[depositUser];
        user.amount = user.amount.add(userDepositAmountInt);

        require(
            _userDepositAmount >= userSoftCap && user.amount <= userHardCap,
            "PLEXUS : The deposit amount exceeds the hardcap."
        );

        usdtTotalReciveAmount = usdtTotalReciveAmount.add(userDepositAmountInt);
        user.totalReward = user.totalReward.add(userDepositAmountInt.mul(PLX_ACC_PRECESION) / price);
        userInfo[depositUser] = user;

        emit Deposit(depositUser, user.amount, user.totalReward);
    }

    function depositP2(uint256 _userDepositAmount) public {
        require(block.timestamp >= idoStartTimeP2 && block.timestamp <= idoEndTimeP2, "PLEXUS : This is not IDO time.");

        uint256 userDepositAmountInt = (_userDepositAmount / priceP2) * priceP2;
        address depositUser = msg.sender;

        require(
            usdtHardCapP2.sub(usdtTotalReciveAmountP2) >= userDepositAmountInt,
            "PLEXUS : The deposit amount exceeds the hardcap."
        );

        IERC20(usdt).transferFrom(depositUser, address(this), userDepositAmountInt);
        if (userAddressP2.length == 0) {
            userAddressP2.push(depositUser);
            userIdP2[depositUser] = userAddressP2.length - 1;
        } else if ((userIdP2[depositUser] == 0 && userAddressP2[0] != depositUser)) {
            userAddressP2.push(depositUser);
            userIdP2[depositUser] = userAddressP2.length - 1;
        }
        UserInfo memory user = userInfo[depositUser];
        user.amountP2 = user.amountP2.add(userDepositAmountInt);

        require(
            _userDepositAmount >= userSoftCapP2 && user.amountP2 <= userHardCapP2,
            "PLEXUS : The deposit amount exceeds the hardcap."
        );
        usdtTotalReciveAmountP2 = usdtTotalReciveAmountP2.add(userDepositAmountInt);
        user.totalReward = user.totalReward.add(userDepositAmountInt.mul(PLX_ACC_PRECESION) / priceP2);
        userInfo[depositUser] = user;

        emit Deposit(depositUser, user.amountP2, user.totalReward);
    }

    function pendingClaim(address _user) public view returns (uint256 pendingAmount) {
        UserInfo memory user = userInfo[_user];
        if (block.number > lockupBlock && lockupBlock != 0) {
            uint256 claimBlock;
            if (block.number > lockupBlock.add(claimDuringBlock)) {
                if (user.lastRewardBlock <= lockupBlock.add(claimDuringBlock)) {
                    pendingAmount = user.totalReward.sub(user.recivePLX);
                } else pendingAmount = 0;
            } else {
                if (userInfo[_user].lastRewardBlock < lockupBlock) {
                    claimBlock = block.number.sub(lockupBlock);
                } else {
                    claimBlock = block.number.sub(user.lastRewardBlock);
                }
                uint256 perBlock = (user.totalReward.mul(PLX_ACC_PRECESION)) / claimDuringBlock;
                pendingAmount = claimBlock.mul(perBlock) / PLX_ACC_PRECESION;
            }
        } else pendingAmount = 0;
    }

    function claim(address _user) public {
        require(block.number >= lockupBlock && lockupBlock != 0, "PLEXUS : lockupBlock not set.");
        UserInfo memory user = userInfo[_user];

        uint256 claimAmount = pendingClaim(_user);
        require(claimAmount != 0, "PLEXUS : There is no claimable amount.");
        if (IERC20(plexus).balanceOf(address(this)) <= claimAmount) {
            claimAmount = IERC20(plexus).balanceOf(address(this));
        }
        TransferHelper.safeTransfer(plexus, _user, claimAmount);
        user.lastRewardBlock = block.number;
        user.recivePLX += claimAmount;
        userInfo[_user] = user;

        emit Claim(_user, claimAmount, user.recivePLX);
    }

    function close(uint256 roopStart, uint256 roopEnd) public {
        require(msg.sender == dev);
        require(block.timestamp > idoEndTime);
        uint256 usdtSoftCapInt = (usdtSoftCap / price) * price;
        if (usdtTotalReciveAmount < usdtSoftCapInt) {
            if (roopEnd >= userAddress.length) {
                roopEnd = userAddress.length;
            }
            for (roopStart; roopStart < roopEnd; roopStart++) {
                UserInfo memory user = userInfo[userAddress[roopStart]];
                if (user.amount != 0) {
                    TransferHelper.safeTransfer(usdt, userAddress[roopStart], user.amount);
                    user.totalReward = user.totalReward.sub(user.amount.mul(PLX_ACC_PRECESION) / price);
                    emit refund(userAddress[roopStart], user.amount);
                    usdtTotalReciveAmount -= user.amount;
                    user.amount = 0;
                    userInfo[userAddress[roopStart]] = user;
                }
            }
        } else {
            TransferHelper.safeTransfer(usdt, dev, usdtTotalReciveAmount);
        }
    }

    function closeP2(uint256 roopStart, uint256 roopEnd) public {
        require(msg.sender == dev);
        require(block.timestamp > idoEndTime);
        uint256 usdtSoftCapInt = (usdtSoftCapP2 / priceP2) * priceP2;
        if (usdtTotalReciveAmountP2 < usdtSoftCapInt) {
            if (roopEnd >= userAddressP2.length) {
                roopEnd = userAddressP2.length;
            }
            for (roopStart; roopStart < roopEnd; roopStart++) {
                UserInfo memory user = userInfo[userAddressP2[roopStart]];
                if (user.amountP2 != 0) {
                    TransferHelper.safeTransfer(usdt, userAddressP2[roopStart], user.amountP2);
                    user.totalReward = user.totalReward.sub(user.amountP2.mul(PLX_ACC_PRECESION) / priceP2);
                    emit refund(userAddressP2[roopStart], user.amountP2);
                    usdtTotalReciveAmountP2 -= user.amountP2;
                    user.amountP2 = 0;
                    userInfo[userAddressP2[roopStart]] = user;
                }
            }
        } else {
            TransferHelper.safeTransfer(usdt, dev, usdtTotalReciveAmountP2);
        }
    }

    function emergencyWithdraw() public {
        require(msg.sender == dev);
        TransferHelper.safeTransfer(plexus, dev, IERC20(plexus).balanceOf(address(this)));
        TransferHelper.safeTransfer(usdt, dev, IERC20(usdt).balanceOf(address(this)));
    }

    function setLockupBlock(uint256 _launchingBlock) public {
        require(msg.sender == dev);
        // ( lunchingBlock + 1month)
        lockupBlock = _launchingBlock.add(172800);
    }

    function setIdoTime(uint256 _startTime, uint256 _endTime) public {
        require(msg.sender == dev);
        idoStartTime = _startTime;
        idoEndTime = _endTime;
    }

    function setIdoTimeP2(uint256 _startTime, uint256 _endTime) public {
        require(msg.sender == dev);
        idoStartTimeP2 = _startTime;
        idoEndTimeP2 = _endTime;
    }

    function idoClosePlxWithdraw() public {
        require(msg.sender == dev);
        uint256 plxWithdrawAmount = plexusTotalValue.sub((usdtTotalReciveAmount / price) * PLX_ACC_PRECESION);
        TransferHelper.safeTransfer(plexus, dev, plxWithdrawAmount);
    }

    function idoClosePlxWithdrawP2() public {
        require(msg.sender == dev);
        uint256 plxWithdrawAmount = plexusTotalValueP2.sub((usdtTotalReciveAmountP2 / priceP2) * PLX_ACC_PRECESION);
        TransferHelper.safeTransfer(plexus, dev, plxWithdrawAmount);
    }

}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.12;

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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.12;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.6.0;

// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: APPROVE_FAILED");
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FAILED");
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TransferHelper: TRANSFER_FROM_FAILED");
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "TransferHelper: KLAY_TRANSFER_FAILED");
    }
}