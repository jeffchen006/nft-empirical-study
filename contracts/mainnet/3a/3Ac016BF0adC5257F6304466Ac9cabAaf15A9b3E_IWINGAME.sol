//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/* 

██╗░██╗░░░░░░░██╗██╗███╗░░██╗░░░░░░░██████╗░░█████╗░███╗░░░███╗███████╗░░░░█████╗░░█████╗░███╗░░░███╗
██║░██║░░██╗░░██║██║████╗░██║░░░░░░██╔════╝░██╔══██╗████╗░████║██╔════╝░░░██╔══██╗██╔══██╗████╗░████║
██║░╚██╗████╗██╔╝██║██╔██╗██║█████╗██║░░██╗░███████║██╔████╔██║█████╗░░░░░██║░░╚═╝██║░░██║██╔████╔██║
██║░░████╔═████║░██║██║╚████║╚════╝██║░░╚██╗██╔══██║██║╚██╔╝██║██╔══╝░░░░░██║░░██╗██║░░██║██║╚██╔╝██║
██║░░╚██╔╝░╚██╔╝░██║██║░╚███║░░░░░░╚██████╔╝██║░░██║██║░╚═╝░██║███████╗██╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═╝░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚══╝░░░░░░░╚═════╝░╚═╝░░╚═╝╚═╝░░░░░╚═╝╚══════╝╚═╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝
 
 */
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IERC20 } from "./interfaces/IERC20.sol";
import { Auth } from "./lib/Auth.sol";
import { IDEXRouter } from "./interfaces/IDEXRouter.sol";
import { IDividendDistributor } from "./interfaces/IDividendDistributor.sol";                                                          

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract IWINGAME is IERC20, Auth {
    using SafeMath for uint256;

    uint256 public constant MASK = type(uint128).max;
    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; //Etherium 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2  ; Rinkeby: 0xc778417E063141139Fce010982780140Aa0cD5Ab //Goeli: 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
    address DEAD = 0x000000000000000000000000000000000000dEaD;
    address ZERO = 0x0000000000000000000000000000000000000000;
    address DEAD_NON_CHECKSUM = 0x000000000000000000000000000000000000dEaD;

    string constant _name = "IWIN GAME";
    string constant _symbol = "IWIN";
    uint8 constant _decimals = 18;

    uint256 _totalSupply = 1_000_000_000 * (10 ** _decimals);
    uint256 public _maxTxAmount = _totalSupply.div(400); // 0.25%

    mapping (address => uint256) _balances;
    uint256 _totalHolder;
    mapping (address => mapping (address => uint256)) _allowances;

    mapping (address => bool) isFeeExempt;
    mapping (address => bool) isFeeExemptRecipient;
    mapping (address => bool) isTxLimitExempt;
    mapping (address => bool) isDividendExempt;
    mapping (address => bool) isWhiteList;

    uint256 liquidityFee = 500;
    uint256 buybackFee = 300;
    uint256 reflectionFee = 500;
    uint256 marketingFee = 200;
    uint256 totalFee = 1500;
    uint256 public buyFee = 500;
    uint256 feeDenominator = 10000;

    address public autoLiquidityReceiver;
    address public marketingFeeReceiver;

    uint256 targetLiquidity = 25;
    uint256 targetLiquidityDenominator = 100;

    IDEXRouter public router;
    address public pair;
    mapping(address=>bool) public isPair;

    uint256 buybackMultiplierNumerator = 200;
    uint256 buybackMultiplierDenominator = 100;
    uint256 buybackMultiplierTriggeredAt;
    uint256 buybackMultiplierLength = 30 minutes;

    bool public autoBuybackEnabled = false;
    mapping (address => bool) buyBacker;
    uint256 autoBuybackCap;
    uint256 autoBuybackAccumulator;
    uint256 autoBuybackAmount;
    uint256 autoBuybackBlockPeriod;
    uint256 autoBuybackBlockLast;

    IDividendDistributor distributor;
    address public distributorAddress;

    uint256 distributorGas = 500000;

    bool public swapEnabled = true;
    uint256 public swapThreshold = _totalSupply / 5000; // 0.02%
    bool inSwap;
    modifier swapping() { inSwap = true; _; inSwap = false;}

    constructor (address _dexRouter) Auth(msg.sender) { 
        router = IDEXRouter(_dexRouter);
        WETH = router.WETH();
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));
        isPair[pair] = true;

        _allowances[address(this)][address(router)] = _totalSupply;
        isFeeExempt[msg.sender] = true;
        isTxLimitExempt[msg.sender] = true;
        isWhiteList[msg.sender] = true;
        isDividendExempt[pair] = true;
        isDividendExempt[address(this)] = true;
        isWhiteList[address(this)] = true;
        isDividendExempt[DEAD] = true;
        isDividendExempt[ZERO] = true;
        isDividendExempt[msg.sender] = true;

        buyBacker[msg.sender] = true;
        autoLiquidityReceiver = msg.sender;
        marketingFeeReceiver = msg.sender;
        approve(_dexRouter, _totalSupply);
        approve(address(pair), _totalSupply);
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable { }

    function withdrawMoney() external onlyOwner{
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function decimals() external pure override returns (uint8) { return _decimals; }
    function symbol() external pure override returns (string memory) { return _symbol; }
    function name() external pure override returns (string memory) { return _name; }
    function getOwner() external view override returns (address) { return owner; }
    modifier onlyBuybacker() { require(buyBacker[msg.sender] == true, ""); _; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }

    function setDividendDistributor(address _distributor) external onlyOwner{
        distributorAddress = _distributor;
        distributor = IDividendDistributor(_distributor);
        isDividendExempt[distributorAddress] = true;
        isWhiteList[distributorAddress] = true;
    }

    function setWhiteList(address holder, bool iswhitelist) external authorized {
        require(holder != address(0), "holder is 0");
        isWhiteList[holder] = iswhitelist;
    }

    function setPair(address _pair, bool _isPair) external authorized {
        isPair[_pair] = _isPair;
        isDividendExempt[_pair] = _isPair;
    }

    function setDexRouter(address _dexRouter) external onlyOwner {
        router = IDEXRouter(_dexRouter);
        WETH = router.WETH();
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));
        isPair[pair] = true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function approveMax(address spender) external returns (bool) {
        return approve(spender, _totalSupply);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if(_allowances[sender][msg.sender] != _totalSupply){
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        if(inSwap||sender == address(distributor)||recipient == address(distributor)){ return _basicTransfer(sender, recipient, amount); }

        checkTxLimit(sender, amount);
        if(shouldSwapBack()){ swapBack(); }
        if(shouldAutoBuyback()){ triggerAutoBuyback(); }

        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        if (_balances[sender] == 0) {
            _totalHolder = _totalHolder - 1;
        }
        uint256 amountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, recipient, amount) : amount;
        if (_balances[recipient] == 0) {
            _totalHolder = _totalHolder + 1;
        }
        _balances[recipient] = _balances[recipient].add(amountReceived);

        if(!isDividendExempt[sender]){ try distributor.setShare(sender, _balances[sender]) {} catch {} }
        if(!isDividendExempt[recipient]){ try distributor.setShare(recipient, _balances[recipient]) {} catch {} }

        try distributor.process(distributorGas) {
            
        } catch {}

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        if (_balances[sender] == 0) {
            _totalHolder = _totalHolder - 1;
        }
        if (_balances[recipient] == 0) {
            _totalHolder = _totalHolder + 1;
        }
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function checkTxLimit(address sender, uint256 amount) internal view {
        require(amount <= _maxTxAmount || isTxLimitExempt[sender], "TX Limit Exceeded");
    }

    function shouldTakeFee(address sender, address recipient) internal view returns (bool) {
        return !(isFeeExempt[sender]||isFeeExemptRecipient[recipient]||isWhiteList[sender]||isWhiteList[recipient]);
    }

    function getTotalFee(address sender, address receiver) public view returns (uint256) {
        //buying
        if(isPair[sender]){ 
            return buyFee;
        //selling
        }else if(isPair[receiver]){ return getMultipliedFee(); } 
        // transfer
        return totalFee;
    }

    function getTotalHolder() public view returns (uint256) {
        return _totalHolder;
    }

    function getMultipliedFee() public view returns (uint256) {
        if (buybackMultiplierTriggeredAt.add(buybackMultiplierLength) > block.timestamp) {
            uint256 remainingTime = buybackMultiplierTriggeredAt.add(buybackMultiplierLength).sub(block.timestamp);
            uint256 feeIncrease = totalFee.mul(buybackMultiplierNumerator).div(buybackMultiplierDenominator).sub(totalFee);
            return totalFee.add(feeIncrease.mul(remainingTime).div(buybackMultiplierLength));
        }
        return totalFee;
    }

    function takeFee(address sender, address receiver, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = amount.mul(getTotalFee(sender, receiver)).div(feeDenominator);
        _balances[address(this)] = _balances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount);
        return amount.sub(feeAmount);
    }

    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && swapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    function swapBack() internal swapping {
        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : liquidityFee;
        uint256 amountToLiquify = swapThreshold.mul(dynamicLiquidityFee).div(totalFee).div(2);
        uint256 amountReflection = swapThreshold.mul(reflectionFee).div(totalFee);
        if(address(distributor) != address(0)){
            _transferFrom(address(this), address(distributor), amountReflection);
            distributor.deposit(amountReflection);
        }
        uint256 amountToSwap = swapThreshold.sub(amountToLiquify).sub(amountReflection);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETH = address(this).balance.sub(balanceBefore);

        uint256 totalETHFee = totalFee.sub(dynamicLiquidityFee.div(2)).sub(reflectionFee);

        uint256 amountETHLiquidity = amountETH.mul(dynamicLiquidityFee).div(totalETHFee).div(2);
        uint256 amountETHMarketing = amountETH.mul(marketingFee).div(totalETHFee);
        
        (bool success,) = payable(marketingFeeReceiver).call{value: amountETHMarketing, gas: 30000}("");
        
        require(success, "Transfer failed.");
        if(amountToLiquify > 0){
            router.addLiquidityETH{value: amountETHLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                autoLiquidityReceiver,
                block.timestamp
            );
            emit AutoLiquify(amountETHLiquidity, amountToLiquify);
        }
    }

    function shouldAutoBuyback() internal view returns (bool) {
        return msg.sender != pair
        && !inSwap
        && autoBuybackEnabled
        && autoBuybackBlockLast + autoBuybackBlockPeriod <= block.number // After N blocks from last buyback
        && address(this).balance >= autoBuybackAmount;
    }

    function triggerTokenBuyback(uint256 amount, bool triggerBuybackMultiplier) external authorized {
        buyTokens(amount, DEAD);
        if(triggerBuybackMultiplier){
            buybackMultiplierTriggeredAt = block.timestamp;
            emit BuybackMultiplierActive(buybackMultiplierLength);
        }
    }

    function clearBuybackMultiplier() external authorized {
        buybackMultiplierTriggeredAt = 0;
    }

    function triggerAutoBuyback() internal {
        buyTokens(autoBuybackAmount, DEAD);
        autoBuybackBlockLast = block.number;
        autoBuybackAccumulator = autoBuybackAccumulator.add(autoBuybackAmount);
        if(autoBuybackAccumulator > autoBuybackCap){ autoBuybackEnabled = false; }
    }

    function buyTokens(uint256 amount, address to) internal swapping {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(this);

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            to,
            block.timestamp
        );
    }

    function setAutoBuybackSettings(bool _enabled, uint256 _cap, uint256 _amount, uint256 _period) external authorized {
        autoBuybackEnabled = _enabled;
        autoBuybackCap = _cap;
        autoBuybackAccumulator = 0;
        autoBuybackAmount = _amount;
        autoBuybackBlockPeriod = _period;
        autoBuybackBlockLast = block.number;
    }

    function setBuybackMultiplierSettings(uint256 numerator, uint256 denominator, uint256 length) external authorized {
        require(numerator / denominator <= 2 && numerator > denominator);
        buybackMultiplierNumerator = numerator;
        buybackMultiplierDenominator = denominator;
        buybackMultiplierLength = length;
    }

    function setTxLimit(uint256 amount) external authorized {
        require(amount >= _totalSupply / 1000);
        _maxTxAmount = amount;
    }

    function setIsDividendExempt(address holder, bool exempt) external authorized {
        require(holder != address(this) && holder != pair);
        isDividendExempt[holder] = exempt;
        if(exempt){
            distributor.setShare(holder, 0);
        }else{
            distributor.setShare(holder, _balances[holder]);
        }
    }

    function setIsFeeExempt(address holder, bool exempt) external authorized {
        isFeeExempt[holder] = exempt;
    }

    function setIsFeeExemptRecipient(address holder, bool exempt) external authorized {
        isFeeExemptRecipient[holder] = exempt;
    }

    function setIsTxLimitExempt(address holder, bool exempt) external authorized {
        isTxLimitExempt[holder] = exempt;
    }

    function setFees(uint256 _liquidityFee, uint256 _buybackFee, uint256 _reflectionFee, uint256 _marketingFee, uint256 _feeDenominator) external authorized {
        liquidityFee = _liquidityFee;
        buybackFee = _buybackFee;
        reflectionFee = _reflectionFee;
        marketingFee = _marketingFee;
        totalFee = _liquidityFee.add(_buybackFee).add(_reflectionFee).add(_marketingFee);
        require(totalFee <= 3000, "Total fee less than 30%");
        feeDenominator = _feeDenominator;
        require(totalFee < feeDenominator/4);
    }

    function setBuyFee(uint256 _buyFee) external authorized {
        require(_buyFee <= 1000, "Buy fee less than 10%");
        buyFee = _buyFee;
    }

    function setFeeReceivers(address _autoLiquidityReceiver, address _marketingFeeReceiver) external authorized {
        autoLiquidityReceiver = _autoLiquidityReceiver;
        marketingFeeReceiver = _marketingFeeReceiver;
    }

    function setSwapBackSettings(bool _enabled, uint256 _amount) external authorized {
        swapEnabled = _enabled;
        swapThreshold = _amount;
    }

    function setTargetLiquidity(uint256 _target, uint256 _denominator) external authorized {
        targetLiquidity = _target;
        targetLiquidityDenominator = _denominator;
    }

    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external authorized {
        distributor.setDistributionCriteria(_minPeriod, _minDistribution);
    }

    function setDistributorSettings(uint256 gas) external authorized {
        require(gas < 750000);
        distributorGas = gas;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply.sub(balanceOf(DEAD)).sub(balanceOf(ZERO));
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256) {
        return accuracy.mul(balanceOf(pair).mul(2)).div(getCirculatingSupply());
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }
 

    event AutoLiquify(uint256 amountETH, uint256 amountBOG);
    event BuybackMultiplierActive(uint256 duration);
}

// SPDX-License-Identifier: MIT
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function name() external view returns (string memory);
    function getOwner() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
/**
 * Allows for contract ownership along with multi-address authorization
 */
abstract contract Auth {
    address internal owner;
    mapping (address => bool) internal authorizations;

    constructor(address _owner) {
        owner = _owner;
        authorizations[_owner] = true;
    }

    /**
     * Function modifier to require caller to be contract owner
     */
    modifier onlyOwner() {
        require(isOwner(msg.sender), "!OWNER"); _;
    }

    /**
     * Function modifier to require caller to be authorized
     */
    modifier authorized() {
        require(isAuthorized(msg.sender), "!AUTHORIZED"); _;
    }

    /**
     * Authorize address. Owner only
     */
    function authorize(address adr) public onlyOwner {
        authorizations[adr] = true;
    }

    /**
     * Remove address' authorization. Owner only
     */
    function unauthorize(address adr) public onlyOwner {
        authorizations[adr] = false;
    }

    /**
     * Check if address is owner
     */
    function isOwner(address account) public view returns (bool) {
        return account == owner;
    }

    /**
     * Return address' authorization status
     */
    function isAuthorized(address adr) public view returns (bool) {
        return authorizations[adr];
    }

    /**
     * Transfer ownership to new address. Caller must be owner. Leaves old owner authorized
     */
    function transferOwnership(address payable adr) public onlyOwner {
        owner = adr;
        authorizations[adr] = true;
        emit OwnershipTransferred(adr);
    }

    event OwnershipTransferred(address owner);
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IDEXRouter {
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

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDividendDistributor {
    function setDistributionCriteria(uint256 _minPeriod, uint256 _minDistribution) external;
    function setShare(address shareholder, uint256 amount) external;
    function deposit(uint256 amount) external;
    function process(uint256 gas) external;
}