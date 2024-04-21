// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ExtendSafeERC20} from "./ExtendSafeERC20.sol";
import {IController} from "./interfaces/IController.sol";
import {IOracle} from "./interfaces/IOracle.sol";
import {ILock} from "./interfaces/ILock.sol";
import {Ownable} from "./Ownable.sol";

contract Minter is Ownable, ReentrancyGuard {
    using ExtendSafeERC20 for IERC20;
    using SafeERC20 for IERC20;
    

    address public controllerAddress;
    address public lockAddress;

    // mapping token address to target priceAPIConsumer
    mapping(address => uint256) public targetPrices;

    mapping(bytes =>  uint256) public borrowBalances;          // id -> uAsset ballance
    mapping(bytes =>  uint256) public collateralBalances;      // id -> collateral ballance
    
    mapping(bytes => address) public accounts;                  // id -> account
    mapping(bytes => uint256) public userBalances;              // id -> user balance locked
    mapping(bytes => uint256) public updatedLockTime;           // id -> updated time
    mapping(bytes => uint8) public typeBorrow;                  // id -> 1: borrow, 2: short
    mapping(bytes => uint256) public totalClaimedById;          // id -> total amount claimed
    mapping(bytes => address) public uAssetAddressById;         // id -> uAssetAddress

    event BorrowAsset(
        address indexed userAddress,
        bytes id,
        uint256 uAssetAmount,
        uint256 collateralAmount,
        uint256 timestamp
    );

    event Close(
        address indexed userAddress,
        bytes id,
        uint8 typeId,
        uint256 uAssetAmount,
        uint256 collateralAmount,
        uint256 timestamp
    );

    event Short(
        address indexed userAddress,
        bytes id,
        uint256 uAssetAmount,
        uint256 collateralAmount,
        uint256 timestamp
    );

    event EditShort(
        address indexed userAddress,
        bytes id,
        uint8 isLocked,
        uint256 uAssetAmount,
        uint256 collateralAmount,
        uint256 timestamp
    );

    event Liquidation (
        address indexed buyer,
        address indexed account,
        bytes id,
        uint256 uAssetAmount,
        uint256 collateralAmount,
        uint256 timestamp,
        uint256 discountRate
    );

    event ClaimToken(
        address indexed claimer,
        bytes id,
        uint256 amount, 
        uint256 timestamp
    );

    event ClaimAll(
        address indexed claimer,
        bytes[] ids
    );

    constructor() {
    }

    modifier onlyAdmin() {
        require(IController(controllerAddress).admins(msg.sender) || msg.sender == owner(), "Only admin");
        _;
    }

    function setControllerAddress(address _controllerAddress) external onlyOwner {
        controllerAddress = _controllerAddress;
    }

    function addMoreCollateralAmount(address uAssetAddress, uint256 collateralAmount, bytes memory id) external onlyAdmin {
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), collateralAmount);
        collateralBalances[id] += collateralAmount;
    }
    
    function lock(bytes memory id, uint256 tokenAmount) internal {
        userBalances[id] += tokenAmount;
        updatedLockTime[id] = block.timestamp;
    } 
    
    function isClaimable(bytes memory id) external view returns (bool){
        uint256 lockTime = IController(controllerAddress).lockTime();
        if(updatedLockTime[id] == 0) return false;
        return (block.timestamp - updatedLockTime[id] > lockTime);
    }

    function claimById(bytes memory id) public nonReentrant {
        require(msg.sender == accounts[id], "Cannot call claim the same id with different account");
        uint256 lockTime = IController(controllerAddress).lockTime();
        require((block.timestamp - updatedLockTime[id]) > lockTime, "Still locking");
        require(userBalances[id] > 0, "Nothing to be claimed");
        uint256 tokenAmount = userBalances[id];
        address uAssetAddress = uAssetAddressById[id];
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        IERC20(collateralAddress).safeTransfer(msg.sender, tokenAmount);
        totalClaimedById[id] += tokenAmount;
        delete userBalances[id];
        delete updatedLockTime[id];
        emit ClaimToken(msg.sender, id, tokenAmount, block.timestamp);
    }
    
    function claimAll(bytes[] memory ids) external {
        uint256 lockTime = IController(controllerAddress).lockTime();
        for(uint256 i = 0; i < ids.length; i++) {
            if(block.timestamp - updatedLockTime[ids[i]] > lockTime && userBalances[ids[i]] > 0) {
                claimById(ids[i]);
            }
        }
        emit ClaimAll(msg.sender, ids);
    }

    function borrow(address uAssetAddress, uint256 uAssetAmount, uint256 collateralAmount, bytes memory id) external nonReentrant {
        if(accounts[id] == address(0)) accounts[id] = msg.sender;
        if(typeBorrow[id] == 0) typeBorrow[id] = 1;
        {
            require(msg.sender == accounts[id], "Cannot call borrow the same id with different account");
            require(collateralBalances[id] == 0, "Cannot call borrow with existed id");
            require(typeBorrow[id] == 1, "Cannot call borrow with different type id");
        }
        {
            uAssetAddressById[id] = uAssetAddress;
        }
        uint256 ttl = IController(controllerAddress).ttl();
        uint16 minCollateralRatio = IController(controllerAddress).minCollateralRatio();
        // uint16 maxCollateralRatio = IController(controllerAddress).maxCollateralRatio();
        uint16 calculationDecimal = IController(controllerAddress).calculationDecimal();

        address oracleAddress = IController(controllerAddress).oracles(uAssetAddress);
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);

        (uint256 targetPrice, uint256 updatedTime) = IOracle(oracleAddress).getTargetValue();
        require(block.timestamp - updatedTime <= ttl, "Target price is not updated");
        
        uint256 realCollateralAmount = (targetPrice * uAssetAmount) / (10 ** ERC20(uAssetAddress).decimals());
        require(realCollateralAmount * minCollateralRatio <= collateralAmount * (10**calculationDecimal), "less than min collateral ratio");
        // require(realCollateralAmount * maxCollateralRatio >= collateralAmount * (10**calculationDecimal), "greater than max collateral ratio");
        IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), collateralAmount);
        IERC20(uAssetAddress).safeMint(msg.sender, uAssetAmount);
        borrowBalances[id] = uAssetAmount;
        collateralBalances[id] = collateralAmount;
        emit BorrowAsset(msg.sender, id, uAssetAmount, collateralAmount, block.timestamp);
    }

    function editBorrow(address uAssetAddress, uint256 uAssetAmount, uint256 collateralAmount, bytes memory id) public nonReentrant {
        require(msg.sender == accounts[id], "Cannot call edit borrow the same id with different account");
        require(collateralBalances[id] > 0, "Cannot call edit borrow with unexisted id");
        require(typeBorrow[id] == 1, "Cannot call edit borrow with different type id");
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        // require(collateralAddress != address(0), "Collateral address is 0");
        address oracleAddress = IController(controllerAddress).oracles(uAssetAddress);
        // require(oracleAddress != address(0), "Oracle address is 0");
        (uint256 targetPrice, uint256 updatedTime) = IOracle(oracleAddress).getTargetValue();
        
        {
            uint256 ttl = IController(controllerAddress).ttl();
            
            
            if(block.timestamp - updatedTime > ttl) {
                require(uAssetAmount == borrowBalances[id], "Outside of market hour");
            } else {
                if(uAssetAmount < borrowBalances[id]) {
                    uint256 diff = borrowBalances[id] - uAssetAmount;
                    IERC20(uAssetAddress).safeTransferFrom(msg.sender, address(this), diff);
                    IERC20(uAssetAddress).safeBurn(diff);
                } else if (uAssetAmount > borrowBalances[id]) {
                    uint256 diff = uAssetAmount - borrowBalances[id];
                    IERC20(uAssetAddress).safeMint(msg.sender, diff);
                }
            }
        }
        {
            uint16 minCollateralRatio = IController(controllerAddress).minCollateralRatio();
            // uint16 maxCollateralRatio = IController(controllerAddress).maxCollateralRatio();
            uint16 calculationDecimal = IController(controllerAddress).calculationDecimal();
            
            uint256 realCollateralAmount = (targetPrice * uAssetAmount) / (10 ** ERC20(uAssetAddress).decimals());
            require(realCollateralAmount * minCollateralRatio <= collateralAmount * (10**calculationDecimal), "less than min collateral ratio");
            // require(realCollateralAmount * maxCollateralRatio >= collateralAmount * (10**calculationDecimal), "greater than max collateral ratio");
        }
        
        if(collateralAmount < collateralBalances[id]) {
            uint256 diff = collateralBalances[id] - collateralAmount;
            IERC20(collateralAddress).safeTransfer(msg.sender, diff);
        } else if(collateralAmount > collateralBalances[id]){
            uint256 diff = collateralAmount - collateralBalances[id];
            IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), diff);
        }
        
        borrowBalances[id] = uAssetAmount;
        collateralBalances[id] = collateralAmount;
        emit BorrowAsset(msg.sender, id, uAssetAmount, collateralAmount, block.timestamp);
    }

    function close(address uAssetAddress, bytes memory id) external nonReentrant {
        require(msg.sender == accounts[id], "Cannot call close the same id with different account");
        require(collateralBalances[id] > 0, "Cannot call close with unexisted id");
        uint256 uAssetAmount = borrowBalances[id];
        uint256 collateralAmount = collateralBalances[id];
        if (uAssetAmount > 0) {
            IERC20(uAssetAddress).safeTransferFrom(msg.sender, address(this), uAssetAmount);
            IERC20(uAssetAddress).safeBurn(uAssetAmount);
        }
        
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        require(collateralAddress != address(0), "Collateral address is 0");
        address oracleAddress = IController(controllerAddress).oracles(uAssetAddress);
        (uint256 targetPrice, ) = IOracle(oracleAddress).getTargetValue();
        uint256 fee = targetPrice * uAssetAmount * 15 / (10 ** ERC20(uAssetAddress).decimals() * 1000);
        if(fee < collateralBalances[id]) {
            collateralAmount -= fee;
            IERC20(collateralAddress).safeTransfer(msg.sender, collateralAmount);
            IERC20(collateralAddress).safeTransfer(owner(), fee);
        }
        
        borrowBalances[id] = 0;
        collateralBalances[id] = 0;
        
        emit Close(msg.sender, id, typeBorrow[id], uAssetAmount, collateralAmount, block.timestamp);
    }

    function short(address uAssetAddress, uint256 uAssetAmount, uint256 collateralAmount,uint256 deadline, uint16 slippage, bytes memory id) external nonReentrant {
        if(accounts[id] == address(0)) accounts[id] = msg.sender;
        if(typeBorrow[id] == 0) typeBorrow[id] = 2;
        {
            require(msg.sender == accounts[id], "Cannot call short the same id with different account"); 
            require(collateralBalances[id] == 0, "Cannot call short with existed id");
            require(typeBorrow[id] == 2, "Cannot call short with different type id");
        }
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        {
            uAssetAddressById[id] = uAssetAddress;
        }
        {
            uint256 ttl = IController(controllerAddress).ttl();
            address oracleAddress = IController(controllerAddress).oracles(uAssetAddress);
            (uint256 targetPrice, uint256 updatedTime) = IOracle(oracleAddress).getTargetValue();
            _checkShort(uAssetAddress, updatedTime, ttl, targetPrice, uAssetAmount, collateralAmount);
        }
        {
            IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), collateralAmount);
            IERC20(uAssetAddress).safeMint(address(this), uAssetAmount);
            borrowBalances[id] = uAssetAmount;
            collateralBalances[id] = collateralAmount;
        }
        {
            IERC20(uAssetAddress).safeApprove(IController(controllerAddress).router(), uAssetAmount);
        }
        {
            address[] memory path = new address[](2);
            uint[] memory reserve = new uint[](2);
            {
                address poolAddress = IController(controllerAddress).pools(uAssetAddress);
                address token0 = IUniswapV2Pair(poolAddress).token0();
                address token1 = IUniswapV2Pair(poolAddress).token1();
                (uint reserve0, uint reserve1,) = IUniswapV2Pair(poolAddress).getReserves();
                
                path[0] = uAssetAddress;
                path[1] = token1;
                reserve[0] = reserve0;
                reserve[1] = reserve1;
                if (token1 == uAssetAddress) {
                    path[1] = token0;
                    reserve[0] = reserve1;
                    reserve[1] = reserve0;
                }
            }
            bytes memory id_ = id;
            uint256 amountOutMin = IUniswapV2Router02(IController(controllerAddress).router()).getAmountOut(uAssetAmount, reserve[0], reserve[1]) * (10000 - slippage) / 10000;
            uint256 balanceBefore = IERC20(path[1]).balanceOf(address(this));
            IUniswapV2Router02(IController(controllerAddress).router()).swapExactTokensForTokensSupportingFeeOnTransferTokens(uAssetAmount, amountOutMin, path, address(this), deadline);
            uint256 amountOut = IERC20(path[1]).balanceOf(address(this)) - balanceBefore;
            lock(id_, amountOut);
            emit Short(msg.sender, id_, uAssetAmount, collateralAmount, block.timestamp);
        }
    }
    
    function editShort(address uAssetAddress, uint256 uAssetAmount, uint256 collateralAmount, uint256 deadline, uint16 slippage, bytes memory id) external nonReentrant {
        {
            require(msg.sender == accounts[id], "Cannot call edit short the same id with different account"); 
            require(collateralBalances[id] > 0, "Cannot call edit short with unexisted id");
            require(typeBorrow[id] == 2, "Cannot call edit short with different type id");
        }
        uint8 isLocked = 0;
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        uint256 ttl = IController(controllerAddress).ttl();
        address oracleAddress = IController(controllerAddress).oracles(uAssetAddress);
        (uint256 targetPrice, uint256 updatedTime) = IOracle(oracleAddress).getTargetValue();
        {
            _checkShort(uAssetAddress, updatedTime, ttl, targetPrice, uAssetAmount, collateralAmount);
        }

        if(collateralAmount < collateralBalances[id]) {
            uint256 diff = collateralBalances[id] - collateralAmount;
            IERC20(collateralAddress).safeTransfer(msg.sender, diff);
        } else if(collateralAmount > collateralBalances[id]){
            uint256 diff = collateralAmount - collateralBalances[id];
            IERC20(collateralAddress).safeTransferFrom(msg.sender, address(this), diff);
        }
        
        if(block.timestamp - updatedTime > ttl) {
            require(uAssetAmount == borrowBalances[id], "Outside of market hour");
        } else {
            if(uAssetAmount < borrowBalances[id]) {
                uint256 diff = borrowBalances[id] - uAssetAmount;
                address addr = uAssetAddress;
                IERC20(addr).safeTransferFrom(msg.sender, address(this), diff);
                IERC20(addr).safeBurn(diff);
            } else if (uAssetAmount > borrowBalances[id]) {
                uint256 diff = uAssetAmount - borrowBalances[id];
                address addr = uAssetAddress;
                uint256 deadline_ = deadline;
                {
                    IERC20(addr).safeMint(address(this), diff);
                }
                address[] memory path = new address[](2);
                uint[] memory reserve = new uint[](2);
                {
                    (uint reserve0, uint reserve1,) = IUniswapV2Pair(IController(controllerAddress).pools(addr)).getReserves();
                    path[0] = addr;
                    path[1] = IUniswapV2Pair(IController(controllerAddress).pools(addr)).token1();
                    reserve[0] = reserve0;
                    reserve[1] = reserve1;
                    if (IUniswapV2Pair(IController(controllerAddress).pools(addr)).token1() == addr) {
                        path[1] = IUniswapV2Pair(IController(controllerAddress).pools(addr)).token0();
                        reserve[0] = reserve1;
                        reserve[1] = reserve0;
                    }
                }
                {
                    IERC20(addr).safeApprove(IController(controllerAddress).router(), diff);
                }
                {
                    uint256 amountOutMin = IUniswapV2Router02(IController(controllerAddress).router()).getAmountOut(diff, reserve[0], reserve[1]) * (10000 - slippage) / 10000;
                    uint256 balanceBefore = IERC20(path[1]).balanceOf(address(this));
                    IUniswapV2Router02(IController(controllerAddress).router()).swapExactTokensForTokensSupportingFeeOnTransferTokens(diff, amountOutMin, path, address(this), deadline_);
                    uint256 amountOut = IERC20(path[1]).balanceOf(address(this)) - balanceBefore;
                    lock(id, amountOut);
                }
                isLocked = 1;
            }
        }
        
        borrowBalances[id] = uAssetAmount;
        collateralBalances[id] = collateralAmount;
        emit EditShort(msg.sender, id, isLocked, uAssetAmount, collateralAmount, block.timestamp);
    }

    function liquidation(address userAddress, address uAssetAddress, uint256 uAssetAmount, bytes memory id) external nonReentrant {
        require(userAddress == accounts[id], "Wrong account to be liquidated");
        require(borrowBalances[id] >= uAssetAmount, "Over liquidation");
        
        uint16 calculationDecimal = IController(controllerAddress).calculationDecimal();
        uint16 discountRate = IController(controllerAddress).discountRates(uAssetAddress);
        (uint256 targetPrice, uint256 updatedTime) = IOracle(IController(controllerAddress).oracles(uAssetAddress)).getTargetValue();
        
        {
            _checkLiquidation(uAssetAddress, targetPrice, updatedTime, borrowBalances[id], collateralBalances[id], calculationDecimal, discountRate);
        }
        
        uint256 discountedCollateralValue = 
            (uAssetAmount * targetPrice * 985 / 1000) / (10 ** ERC20(uAssetAddress).decimals())
            * (10**calculationDecimal)
            / (10**calculationDecimal - discountRate);
            
        address collateralAddress = IController(controllerAddress).collateralForToken(uAssetAddress);
        if (discountedCollateralValue <= collateralBalances[id]) {
            IERC20(uAssetAddress).safeTransferFrom(msg.sender, address(this), uAssetAmount);
            IERC20(uAssetAddress).safeBurn(uAssetAmount);
            IERC20(collateralAddress).safeTransfer(msg.sender, discountedCollateralValue);
            borrowBalances[id] -= uAssetAmount;
            collateralBalances[id] -= discountedCollateralValue;
            if(borrowBalances[id] == 0) {
                IERC20(collateralAddress).safeTransfer(userAddress, collateralBalances[id]);
                collateralBalances[id] = 0;
            }
            emit Liquidation(msg.sender, userAddress, id, uAssetAmount, discountedCollateralValue, block.timestamp, discountRate);
        } else {
            uint256 collateralBalance = collateralBalances[id];
            uint256 uAssetNeeded =  collateralBalance * ((10**calculationDecimal) - discountRate) * (10 ** ERC20(uAssetAddress).decimals()) / ((10**calculationDecimal) * targetPrice * 985 / 1000);
            // uint256 remainedAmount = uAssetAmount - refundUAssetAmount;
            {
                IERC20(uAssetAddress).safeTransferFrom(msg.sender, address(this), uAssetNeeded);
                IERC20(uAssetAddress).safeBurn(uAssetNeeded);
                IERC20(collateralAddress).safeTransfer(msg.sender, collateralBalance);
            }
            {
                borrowBalances[id] -= uAssetNeeded;
                collateralBalances[id] = 0;
            }
            emit Liquidation(msg.sender, userAddress, id, uAssetNeeded, collateralBalance, block.timestamp, discountRate);
        }
    }
    
    function _checkShort(address uAssetAddress, uint256 updatedTime, uint256 ttl, uint256 targetPrice, uint256 uAssetAmount, uint256 collateralAmount) internal view {
        uint16 minCollateralRatio = IController(controllerAddress).minCollateralRatio();
        uint16 maxCollateralRatio = IController(controllerAddress).maxCollateralRatio();
        uint16 calculationDecimal = IController(controllerAddress).calculationDecimal();
        
        require(block.timestamp - updatedTime <= ttl, "Target price is not updated");
        uint256 realCollateralAmount = targetPrice * uAssetAmount / (10 ** ERC20(uAssetAddress).decimals());
        require(realCollateralAmount * minCollateralRatio <= collateralAmount * (10**calculationDecimal), "less than min collateral ratio");
        require(realCollateralAmount * maxCollateralRatio >= collateralAmount * (10**calculationDecimal), "greater than max collateral ratio");
    }
    
    function _checkLiquidation(address uAssetAddress, uint256 targetPrice, uint256 updatedTime, uint256 borrowBalance, uint256 collateralBalance, uint16 calculationDecimal, uint16 discountRate) internal view {
        uint16 minCollateralRatio = IController(controllerAddress).minCollateralRatio();
        uint256 realCollateralAmount = targetPrice * borrowBalance / (10 ** ERC20(uAssetAddress).decimals());
        require(realCollateralAmount * minCollateralRatio > collateralBalance * (10**calculationDecimal), "More than min");
        uint16 configDiscountRate = IController(controllerAddress).discountRates(uAssetAddress);
        if (configDiscountRate < discountRate) {
            discountRate = configDiscountRate;
        }
        uint256 ttl = IController(controllerAddress).ttl();
        require(block.timestamp - updatedTime <= ttl, "Not updated");
    }

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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

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

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
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

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

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
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

library ExtendSafeERC20 {

    using Address for address;

    function safeMint(IERC20 tokenAddress, address receiver, uint256 amount) internal {
        bytes memory data = address(tokenAddress).functionCall(abi.encodeWithSignature("mint(address,uint256)", receiver, amount));
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "ExtendSafeERC20: Mint ops did not succeed");
        }
    }

    function safeBurn(IERC20 tokenAddress, uint256 amount) internal {
        bytes memory data = address(tokenAddress).functionCall(abi.encodeWithSignature("burn(uint256)", amount));
        if (data.length > 0) {
            require(abi.decode(data, (bool)), "ExtendSafeERC20: Burn ops did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IController {
    function admins(address) external view returns(bool);
    function ttl() external view returns(uint256);
    function lockTime() external view returns(uint256);
    function minCollateralRatio() external view returns(uint16);
    function maxCollateralRatio() external view returns(uint16);
    function calculationDecimal() external pure returns(uint16);
    function discountRates(address) external view returns(uint16);
    function acceptedCollateral(address) external view returns(bool);
    function mintContract() external view returns(address);
    function lockContract() external view returns(address);
    function limitOfferContract() external view returns(address);
    function router() external view returns(address);
    function oracles(address) external view returns(address);
    function pools(address) external view returns(address);
    function collateralForToken(address) external view returns(address);
    function tokenForOracle(address) external view returns(address);
    function royaltyFeeRatio() external view returns(uint256);
    function recieverAddress() external view returns(address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOracle {
    function getTargetValue() external view returns(uint256, uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILock {
    function lock(address userAddress, address tokenAddress, uint256 tokenAmount) external;
    function claim(address tokenAddress) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

contract Ownable {
    bytes32 private constant ownerPosition = keccak256("owner.contract:2022");

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    modifier onlyOwner() {
        require(msg.sender == owner(), "Caller not proxy owner");
        _;
    }

    constructor() {
        _setOwner(msg.sender);
    }

    function owner() public view returns (address _owner) {
        bytes32 position = ownerPosition;
        assembly {
            _owner := sload(position)
        }
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner(), "New owner is the current owner");
        emit OwnershipTransferred(owner(), _newOwner);
        _setOwner(_newOwner);
    }

    function _setOwner(address _newOwner) internal {
        bytes32 position = ownerPosition;
        assembly {
            sstore(position, _newOwner)
        }
    }
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