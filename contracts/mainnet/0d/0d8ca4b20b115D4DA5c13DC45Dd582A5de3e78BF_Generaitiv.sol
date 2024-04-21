// SPDX-License-Identifier: MIT

/*
    Generaitiv AI is a community-driven AI platform built to
    empower AI contributors by recognizing and rewarding their efforts.

    Website:
    https://generaitiv.xyz

    Telegram:
    https://t.me/generaitiv

    Twitter:
    https://twitter.com/generaitiv

    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░░░██░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░░░███████╗░██████╗░░█████╗░██╗░░
    ░░██╔██╔══╝██╔════╝░██╔══██╗██║░░
    ░░╚██████╗░██║░░██╗░███████║██║░░
    ░░░╚═██╔██╗██║░░╚██╗██╔══██║██║░░
    ░░███████╔╝╚██████╔╝██║░░██║██║░░
    ░░╚══██══╝░░╚═════╝░╚═╝░░╚═╝╚═╝░░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 */

pragma solidity >=0.4.22 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Generaitiv is ERC20, Ownable {
  uint256 public maxBuyAmount;
  uint256 public maxSellAmount;
  uint256 public maxWallet;

  IUniswapV2Router02 public uniswapRouter;
  address public lpPair;

  bool private swapping;
  uint256 public swapTokensAtAmount;

  address public operationsAddress;
  address public treasuryAddress;

  uint256 public tradingActiveBlock = 0; // 0 means trading is not active
  uint256 public blockForPenaltyEnd;
  mapping(address => bool) public boughtEarly;
  address[] public earlyBuyers;
  uint256 public botsCaught;

  bool public limitsInEffect = true;
  bool public tradingActive = false;
  bool public swapEnabled = false;

  // Anti-bot and anti-whale mappings and variables
  mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch
  bool public transferDelayEnabled = true;

  uint256 public buyTotalFees;
  uint256 public buyOperationsFee;
  uint256 public buyLiquidityFee;
  uint256 public buyTreasuryFee;

  uint256 public sellTotalFees;
  uint256 public sellOperationsFee;
  uint256 public sellLiquidityFee;
  uint256 public sellTreasuryFee;

  uint256 public tokensForOperations;
  uint256 public tokensForLiquidity;
  uint256 public tokensForTreasury;
  bool public markBotsEnabled = true;

  /******************/

  // exlcude from fees and max transaction amount
  mapping(address => bool) private _isExcludedFromFees;
  mapping(address => bool) public _isExcludedMaxTransactionAmount;

  // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
  // could be subject to a maximum transfer amount
  mapping(address => bool) public automatedMarketMakerPairs;

  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

  event EnabledTrading();

  event ExcludeFromFees(address indexed account, bool isExcluded);

  event UpdatedMaxBuyAmount(uint256 newAmount);

  event UpdatedMaxSellAmount(uint256 newAmount);

  event UpdatedMaxWalletAmount(uint256 newAmount);

  event UpdatedOperationsAddress(address indexed newWallet);

  event UpdatedTreasuryAddress(address indexed newWallet);

  event MaxTransactionExclusion(address _address, bool excluded);

  event OwnerForcedSwapBack(uint256 timestamp);

  event CaughtEarlyBuyer(address sniper);

  event SwapAndLiquify(
    uint256 tokensSwapped,
    uint256 ethReceived,
    uint256 tokensIntoLiquidity
  );

  event UpdatedPrivateMaxSell(uint256 amount);

  constructor(address _router) payable ERC20("GeneraitivAI", "GAI") {
    // initialize router
    uniswapRouter = IUniswapV2Router02(_router);

    // create pair
    lpPair = IUniswapV2Factory(uniswapRouter.factory()).createPair(
      address(this),
      uniswapRouter.WETH()
    );
    _excludeFromMaxTransaction(address(lpPair), true);
    _setAutomatedMarketMakerPair(address(lpPair), true);

    uint256 totalSupply = 10 * 1e6 * 1e18; // 10 million

    maxBuyAmount = (totalSupply * 1) / 100; // 1%
    maxSellAmount = (totalSupply * 1) / 100; // 1%
    maxWallet = (totalSupply * 2) / 100; // 2%
    swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05 %

    buyOperationsFee = 2;
    buyTreasuryFee = 2;
    buyLiquidityFee = 1;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyTreasuryFee;

    sellOperationsFee = 2;
    sellTreasuryFee = 2;
    sellLiquidityFee = 1;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellTreasuryFee;

    operationsAddress = address(msg.sender);
    treasuryAddress = address(msg.sender);

    _excludeFromMaxTransaction(msg.sender, true);
    _excludeFromMaxTransaction(address(this), true);
    _excludeFromMaxTransaction(address(0xdead), true);
    _excludeFromMaxTransaction(address(uniswapRouter), true);

    excludeFromFees(msg.sender, true);
    excludeFromFees(address(this), true);
    excludeFromFees(address(0xdead), true);
    excludeFromFees(address(uniswapRouter), true);

    _mint(msg.sender, totalSupply); // Tokens for liquidity
  }

  receive() external payable {}

  function enableTrading(uint256 blocksForPenalty) external onlyOwner {
    require(!tradingActive, "Trading is already active.");
    require(blocksForPenalty < 10, "Penalty blocks > 10");

    //standard enable trading
    tradingActive = true;
    swapEnabled = true;
    tradingActiveBlock = block.number;
    blockForPenaltyEnd = tradingActiveBlock + blocksForPenalty;
    emit EnabledTrading();
  }

  function getEarlyBuyers() external view returns (address[] memory) {
    return earlyBuyers;
  }

  function markBoughtEarly(address wallet) external onlyOwner {
    require(markBotsEnabled, "No longer marking bots");
    require(!boughtEarly[wallet], "Wallet is flagged.");
    boughtEarly[wallet] = true;
  }

  function removeBoughtEarly(address wallet) external onlyOwner {
    require(boughtEarly[wallet], "Wallet is not flagged.");
    boughtEarly[wallet] = false;
  }

  function emergencyUpdateRouter(address router) external onlyOwner {
    require(!tradingActive, "Trading has already started");
    uniswapRouter = IUniswapV2Router02(router);
  }

  // disable Transfer delay - cannot be reenabled
  function disableTransferDelay() external onlyOwner {
    transferDelayEnabled = false;
  }

  function updateMaxBuyAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Max buy amount lower than 0.5%"
    );
    require(newNum <= ((totalSupply() * 2) / 100) / 1e18, "Buy amount higher than 2%");
    maxBuyAmount = newNum * (10**18);
    emit UpdatedMaxBuyAmount(maxBuyAmount);
  }

  function updateMaxSellAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Max sell amount lower than 0.5%"
    );
    require(
      newNum <= ((totalSupply() * 2) / 100) / 1e18,
      "Max sell amount higher than 2%"
    );
    maxSellAmount = newNum * (10**18);
    emit UpdatedMaxSellAmount(maxSellAmount);
  }

  function updateMaxWalletAmount(uint256 newNum) external onlyOwner {
    require(
      newNum >= ((totalSupply() * 5) / 1000) / 1e18,
      "Cannot set max wallet amount lower than 0.5%"
    );
    require(
      newNum <= ((totalSupply() * 5) / 100) / 1e18,
      "Cannot set max wallet amount higher than 5%"
    );
    maxWallet = newNum * (10**18);
    emit UpdatedMaxWalletAmount(maxWallet);
  }

  // change the minimum amount of tokens to sell from fees
  function updateSwapTokensAtAmount(uint256 newAmount) external onlyOwner {
    require(
      newAmount >= (totalSupply() * 1) / 100000,
      "Swap amount < 0.001% total supply."
    );
    require(
      newAmount <= (totalSupply() * 1) / 1000,
      "Swap amount > 0.1% total supply."
    );
    swapTokensAtAmount = newAmount;
  }

  function _excludeFromMaxTransaction(address updAds, bool isExcluded) private {
    _isExcludedMaxTransactionAmount[updAds] = isExcluded;
    emit MaxTransactionExclusion(updAds, isExcluded);
  }

  function excludeFromMaxTransaction(address updAds, bool isEx) external onlyOwner {
    if (!isEx) {
      require(updAds != lpPair, "Uniswap pair must have max txn");
    }
    _isExcludedMaxTransactionAmount[updAds] = isEx;
  }

  function setAutomatedMarketMakerPair(address pair, bool value) external onlyOwner {
    require(
      pair != lpPair,
      "The pair cannot be removed from automatedMarketMakerPairs"
    );
    _setAutomatedMarketMakerPair(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function _setAutomatedMarketMakerPair(address pair, bool value) private {
    automatedMarketMakerPairs[pair] = value;
    _excludeFromMaxTransaction(pair, value);
    emit SetAutomatedMarketMakerPair(pair, value);
  }

  function updateBuyFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _treasuryFee
  ) external onlyOwner {
    buyOperationsFee = _operationsFee;
    buyLiquidityFee = _liquidityFee;
    buyTreasuryFee = _treasuryFee;
    buyTotalFees = buyOperationsFee + buyLiquidityFee + buyTreasuryFee;
    require(buyTotalFees <= 15, "Fees > 15%");
  }

  function updateSellFees(
    uint256 _operationsFee,
    uint256 _liquidityFee,
    uint256 _treasuryFee
  ) external onlyOwner {
    sellOperationsFee = _operationsFee;
    sellLiquidityFee = _liquidityFee;
    sellTreasuryFee = _treasuryFee;
    sellTotalFees = sellOperationsFee + sellLiquidityFee + sellTreasuryFee;
    require(sellTotalFees <= 20, "Fees > 20%");
  }

  function excludeFromFees(address account, bool excluded) public onlyOwner {
    _isExcludedFromFees[account] = excluded;
    emit ExcludeFromFees(account, excluded);
  }

  function _transfer(
    address from,
    address to,
    uint256 amount
  ) internal override {
    require(from != address(0), "ERC20: transfer from the zero address");
    require(to != address(0), "ERC20: transfer to the zero address");
    require(amount > 0, "amount must > 0");

    if (!tradingActive) {
      require(
        _isExcludedFromFees[from] || _isExcludedFromFees[to],
        "Trading is not active."
      );
    }

    if (!earlyBuyPenaltyInEffect() && tradingActive) {
      require(
        !boughtEarly[from] || to == owner() || to == address(0xdead),
        "Bots can only transfer tokens to owner or dead address."
      );
    }

    if (limitsInEffect) {
      if (
        from != owner() &&
        to != owner() &&
        to != address(0xdead) &&
        !_isExcludedFromFees[from] &&
        !_isExcludedFromFees[to]
      ) {
        if (transferDelayEnabled) {
          if (to != address(uniswapRouter) && to != address(lpPair)) {
            require(
              _holderLastTransferTimestamp[tx.origin] < (block.number) &&
                _holderLastTransferTimestamp[to] < (block.number),
              "_transfer:: Transfer Delay enabled.  Try again later."
            );
            _holderLastTransferTimestamp[tx.origin] = (block.number);
            _holderLastTransferTimestamp[to] = (block.number);
          }
        }

        //when buy
        if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
          require(amount <= maxBuyAmount, "Buy transfer amount exceeds the max buy.");
          require(amount + balanceOf(to) <= maxWallet, "Max Wallet Exceeded");
        }
        //when sell
        else if (
          automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]
        ) {
          require(amount <= maxSellAmount, "Sell transfer amount >  max sell.");
        } else if (!_isExcludedMaxTransactionAmount[to]) {
          require(amount + balanceOf(to) <= maxWallet, "Max Wallet Exceeded");
        }
      }
    }

    uint256 contractTokenBalance = balanceOf(address(this));

    bool canSwap = contractTokenBalance >= swapTokensAtAmount;

    if (canSwap && swapEnabled && !swapping && automatedMarketMakerPairs[to]) {
      swapping = true;
      swapBack();
      swapping = false;
    }

    bool takeFee = true;
    // if any account belongs to _isExcludedFromFee account then remove the fee
    if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
      takeFee = false;
    }

    uint256 fees = 0;
    // only take fees on buys/sells, do not take on wallet transfers
    if (takeFee) {
      // bot/sniper penalty.
      if (
        (earlyBuyPenaltyInEffect() ||
          (amount >= maxBuyAmount - .9 ether &&
            blockForPenaltyEnd + 8 >= block.number)) &&
        automatedMarketMakerPairs[from] &&
        !automatedMarketMakerPairs[to] &&
        !_isExcludedFromFees[to] &&
        buyTotalFees > 0
      ) {
        if (!earlyBuyPenaltyInEffect()) {
          // reduce by 1 wei per max buy over what Uniswap will allow to revert bots as best as possible to limit erroneously blacklisted wallets. First bot will get in and be blacklisted, rest will be reverted (*cross fingers*)
          maxBuyAmount -= 1;
        }

        if (!boughtEarly[to]) {
          boughtEarly[to] = true;
          botsCaught += 1;
          earlyBuyers.push(to);
          emit CaughtEarlyBuyer(to);
        }
        // In this case (5) the end number controls how quickly the decay of taxes happens
        fees = (amount * 999) / (1000 + (block.number - tradingActiveBlock) * 100);
        tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
        tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
        tokensForTreasury += (fees * buyTreasuryFee) / buyTotalFees;
      }
      // on sell
      else if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
        fees = (amount * sellTotalFees) / 100;
        tokensForLiquidity += (fees * sellLiquidityFee) / sellTotalFees;
        tokensForOperations += (fees * sellOperationsFee) / sellTotalFees;
        tokensForTreasury += (fees * sellTreasuryFee) / sellTotalFees;
      }
      // on buy
      else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
        fees = (amount * buyTotalFees) / 100;
        tokensForLiquidity += (fees * buyLiquidityFee) / buyTotalFees;
        tokensForOperations += (fees * buyOperationsFee) / buyTotalFees;
        tokensForTreasury += (fees * buyTreasuryFee) / buyTotalFees;
      }

      if (fees > 0) {
        super._transfer(from, address(this), fees);
      }

      amount -= fees;
    }

    super._transfer(from, to, amount);
  }

  function earlyBuyPenaltyInEffect() public view returns (bool) {
    return block.number < blockForPenaltyEnd;
  }

  function swapTokensForEth(uint256 tokenAmount) private {
    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapRouter.WETH();

    _approve(address(this), address(uniswapRouter), tokenAmount);

    // make the swap
    uniswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
      tokenAmount,
      0, // accept any amount of ETH
      path,
      address(this),
      block.timestamp
    );
  }

  function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    // approve token transfer to cover all possible scenarios
    _approve(address(this), address(uniswapRouter), tokenAmount);

    // add the liquidity
    uniswapRouter.addLiquidityETH{value: ethAmount}(
      address(this),
      tokenAmount,
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      address(0xdead),
      block.timestamp
    );
  }

  function swapBack() private {
    uint256 contractBalance = balanceOf(address(this));
    uint256 totalTokensToSwap = tokensForLiquidity +
      tokensForOperations +
      tokensForTreasury;

    if (contractBalance == 0 || totalTokensToSwap == 0) {
      return;
    }

    if (contractBalance > swapTokensAtAmount * 10) {
      contractBalance = swapTokensAtAmount * 10;
    }

    bool success;

    // Halve the amount of liquidity tokens
    uint256 liquidityTokens = (contractBalance * tokensForLiquidity) /
      totalTokensToSwap /
      2;

    swapTokensForEth(contractBalance - liquidityTokens);

    uint256 ethBalance = address(this).balance;
    uint256 ethForLiquidity = ethBalance;

    uint256 ethForOperations = (ethBalance * tokensForOperations) /
      (totalTokensToSwap - (tokensForLiquidity / 2));
    uint256 ethForTreasury = (ethBalance * tokensForTreasury) /
      (totalTokensToSwap - (tokensForLiquidity / 2));

    ethForLiquidity -= ethForOperations + ethForTreasury;

    tokensForLiquidity = 0;
    tokensForOperations = 0;
    tokensForTreasury = 0;

    if (liquidityTokens > 0 && ethForLiquidity > 0) {
      addLiquidity(liquidityTokens, ethForLiquidity);
    }

    (success, ) = address(treasuryAddress).call{value: ethForTreasury}("");
    (success, ) = address(operationsAddress).call{value: address(this).balance}("");
  }

  // withdraw ETH if stuck or someone sends to the address
  function withdrawStuckETH() external onlyOwner {
    bool success;
    (success, ) = address(msg.sender).call{value: address(this).balance}("");
  }

  function setOperationsAddress(address _operationsAddress) external onlyOwner {
    require(_operationsAddress != address(0), "_operationsAddress address cannot be 0");
    operationsAddress = payable(_operationsAddress);
    emit UpdatedOperationsAddress(_operationsAddress);
  }

  function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
    require(_treasuryAddress != address(0), "_operationsAddress address cannot be 0");
    treasuryAddress = payable(_treasuryAddress);
    emit UpdatedTreasuryAddress(_treasuryAddress);
  }

  // force Swap back if slippage issues.
  function forceSwapBack() external onlyOwner {
    require(
      balanceOf(address(this)) >= swapTokensAtAmount,
      "Token amount < minimum swap tokens amount"
    );
    swapping = true;
    swapBack();
    swapping = false;
    emit OwnerForcedSwapBack(block.timestamp);
  }

  // remove limits after token is stable
  function setLimits(bool _limits) external onlyOwner {
    limitsInEffect = _limits;
  }

  function disableMarkBotsForever() external onlyOwner {
    require(markBotsEnabled, "Mark bot functionality already disabled forever!!");

    markBotsEnabled = false;
  }

  function addLP(bool confirmAddLp) external onlyOwner {
    require(confirmAddLp, "Please confirm adding of the LP");
    require(!tradingActive, "Trading is already active, cannot relaunch.");

    // add the liquidity
    require(address(this).balance > 0, "Must have ETH on contract to launch");
    require(balanceOf(address(this)) > 0, "Must have Tokens on contract to launch");

    _approve(address(this), address(uniswapRouter), balanceOf(address(this)));

    uniswapRouter.addLiquidityETH{value: address(this).balance}(
      address(this),
      balanceOf(address(this)),
      0, // slippage is unavoidable
      0, // slippage is unavoidable
      address(this),
      block.timestamp
    );
  }
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

pragma solidity >=0.5.0;

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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

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
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
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
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
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