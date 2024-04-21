// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import './ParrotRewards.sol';

contract Parrot is ERC20, Ownable {
  uint256 private constant PERCENT_DENOMENATOR = 1000;

  address public developmentWallet;
  address public treasuryWallet;
  address public liquidityWallet;

  uint256 public buyDevelopmentFee = 20; // 2%
  uint256 public buyTreasuryFee = 20; // 2%
  uint256 public buyLiquidityFee = 20; // 2%
  uint256 public buyTotalFees =
    buyDevelopmentFee + buyTreasuryFee + buyLiquidityFee;

  uint256 public sellDevelopmentFee = 20; // 2%
  uint256 public sellTreasuryFee = 20; // 2%
  uint256 public sellLiquidityFee = 20; // 2%
  uint256 public sellTotalFees =
    sellDevelopmentFee + sellTreasuryFee + sellLiquidityFee;

  uint256 public tokensForDevelopment;
  uint256 public tokensForTreasury;
  uint256 public tokensForLiquidity;

  ParrotRewards private _rewards;
  mapping(address => bool) private _isTaxExcluded;
  bool private _taxesOff;

  uint256 public maxTxnAmount;
  mapping(address => bool) public isExcludedMaxTxnAmount;
  uint256 public maxWallet;
  mapping(address => bool) public isExcludedMaxWallet;

  uint256 public liquifyRate = 10; // 1% of LP balance

  address public uniswapV2Pair;
  IUniswapV2Router02 public uniswapV2Router;
  mapping(address => bool) public marketMakingPairs;

  mapping(address => bool) private _isBlacklisted;

  bool private _swapEnabled = true;
  bool private _swapping = false;
  modifier lockSwap() {
    _swapping = true;
    _;
    _swapping = false;
  }

  constructor() ERC20('Parrot', 'PRT') {
    _mint(msg.sender, 1_000_000_000 * 10**18);

    IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
      0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
    );
    address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
      .createPair(address(this), _uniswapV2Router.WETH());
    marketMakingPairs[_uniswapV2Pair] = true;
    uniswapV2Pair = _uniswapV2Pair;
    uniswapV2Router = _uniswapV2Router;

    maxTxnAmount = (totalSupply() * 1) / 100; // 1% supply
    maxWallet = (totalSupply() * 1) / 100; // 1% supply

    _rewards = new ParrotRewards(address(this));
    _rewards.transferOwnership(msg.sender);
    _isTaxExcluded[address(this)] = true;
    _isTaxExcluded[msg.sender] = true;
    isExcludedMaxTxnAmount[address(this)] = true;
    isExcludedMaxTxnAmount[msg.sender] = true;
    isExcludedMaxWallet[address(this)] = true;
    isExcludedMaxWallet[msg.sender] = true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual override {
    bool _isBuy = marketMakingPairs[sender] &&
      recipient != address(uniswapV2Router);
    bool _isSell = marketMakingPairs[recipient];
    bool _isSwap = _isBuy || _isSell;
    address _marketMakingPair;

    if (!_isBuy) {
      require(!_isBlacklisted[recipient], 'blacklisted wallet');
      require(!_isBlacklisted[sender], 'blacklisted wallet');
      require(!_isBlacklisted[_msgSender()], 'blacklisted wallet');
    }

    if (_isSwap) {
      if (_isBuy) {
        // buy
        _marketMakingPair = sender;

        if (!isExcludedMaxTxnAmount[recipient]) {
          require(
            amount <= maxTxnAmount,
            'cannot swap more than max transaction amount'
          );
        }
      } else {
        // sell
        _marketMakingPair = recipient;

        if (!isExcludedMaxTxnAmount[sender]) {
          require(
            amount <= maxTxnAmount,
            'cannot swap more than max transaction amount'
          );
        }
      }
    }

    // enforce on buys and wallet/wallet transfers only
    if (!_isSell && !isExcludedMaxWallet[recipient]) {
      require(
        amount + balanceOf(recipient) <= maxWallet,
        'max wallet exceeded'
      );
    }

    uint256 _minSwap = totalSupply();
    if (_marketMakingPair != address(0)) {
      _minSwap =
        (balanceOf(_marketMakingPair) * liquifyRate) /
        PERCENT_DENOMENATOR;
      _minSwap = _minSwap == 0 ? totalSupply() : _minSwap;
    }
    bool _overMin = tokensForDevelopment +
      tokensForTreasury +
      tokensForLiquidity >=
      _minSwap;
    if (_swapEnabled && !_swapping && _overMin && sender != _marketMakingPair) {
      _swap(_minSwap);
    }

    uint256 tax = 0;
    if (
      _isSwap &&
      !_taxesOff &&
      !(_isTaxExcluded[sender] || _isTaxExcluded[recipient])
    ) {
      if (_isBuy) {
        tax = (amount * buyTotalFees) / PERCENT_DENOMENATOR;
        tokensForDevelopment += (tax * buyDevelopmentFee) / buyTotalFees;
        tokensForTreasury += (tax * buyTreasuryFee) / buyTotalFees;
        tokensForLiquidity += (tax * buyLiquidityFee) / buyTotalFees;
      } else {
        // sell
        tax = (amount * sellTotalFees) / PERCENT_DENOMENATOR;
        tokensForDevelopment += (tax * sellDevelopmentFee) / sellTotalFees;
        tokensForTreasury += (tax * sellTreasuryFee) / sellTotalFees;
        tokensForLiquidity += (tax * sellLiquidityFee) / sellTotalFees;
      }
      if (tax > 0) {
        super._transfer(sender, address(this), tax);
      }
    }

    super._transfer(sender, recipient, amount - tax);

    _trueUpTaxTokens();
  }

  function _swap(uint256 _amountToSwap) private lockSwap {
    uint256 _tokensForDevelopment = tokensForDevelopment;
    uint256 _tokensForTreasury = tokensForTreasury;
    uint256 _tokensForLiquidity = tokensForLiquidity;

    // the max amount we want to swap is _amountToSwap, so make sure if
    // the amount of tokens that are available to swap is more than that,
    // that we adjust the tokens to swap to be max that amount.
    if (
      _tokensForDevelopment + _tokensForTreasury + _tokensForLiquidity >
      _amountToSwap
    ) {
      _tokensForLiquidity = _tokensForLiquidity > _amountToSwap
        ? _amountToSwap
        : _tokensForLiquidity;
      uint256 _remaining = _amountToSwap - _tokensForLiquidity;
      _tokensForTreasury =
        (_remaining * buyTreasuryFee) /
        (buyTreasuryFee + buyDevelopmentFee);
      _tokensForDevelopment = _remaining - _tokensForTreasury;
    }

    uint256 _balBefore = address(this).balance;
    uint256 _liquidityTokens = _tokensForLiquidity / 2;
    uint256 _finalAmountToSwap = _tokensForDevelopment +
      _tokensForTreasury +
      _liquidityTokens;

    // generate the uniswap pair path of token -> weth
    address[] memory path = new address[](2);
    path[0] = address(this);
    path[1] = uniswapV2Router.WETH();

    _approve(address(this), address(uniswapV2Router), _finalAmountToSwap);
    uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
      _finalAmountToSwap,
      0,
      path,
      address(this),
      block.timestamp
    );

    uint256 balToProcess = address(this).balance - _balBefore;
    if (balToProcess > 0) {
      uint256 _treasuryETH = (balToProcess * _tokensForTreasury) /
        _finalAmountToSwap;
      uint256 _developmentETH = (balToProcess * _tokensForDevelopment) /
        _finalAmountToSwap;
      uint256 _liquidityETH = balToProcess - _treasuryETH - _developmentETH;
      _processFees(
        _developmentETH,
        _treasuryETH,
        _liquidityETH,
        _liquidityTokens
      );
    }

    tokensForDevelopment -= _tokensForDevelopment;
    tokensForTreasury -= _tokensForTreasury;
    tokensForLiquidity -= _tokensForLiquidity;
  }

  function _addLp(uint256 tokenAmount, uint256 ethAmount) private {
    _approve(address(this), address(uniswapV2Router), tokenAmount);
    uniswapV2Router.addLiquidityETH{ value: ethAmount }(
      address(this),
      tokenAmount,
      0,
      0,
      liquidityWallet == address(0) ? owner() : liquidityWallet,
      block.timestamp
    );
  }

  function _processFees(
    uint256 _developmentETH,
    uint256 _treasuryETH,
    uint256 _liquidityETH,
    uint256 _liquidityTokens
  ) private {
    if (_developmentETH > 0) {
      address _developmentWallet = developmentWallet == address(0)
        ? owner()
        : developmentWallet;
      payable(_developmentWallet).call{ value: _developmentETH }('');
    }

    if (_treasuryETH > 0) {
      address _treasuryWallet = treasuryWallet == address(0)
        ? owner()
        : treasuryWallet;
      payable(_treasuryWallet).call{ value: _treasuryETH }('');
    }

    if (_liquidityETH > 0 && _liquidityTokens > 0) {
      _addLp(_liquidityTokens, _liquidityETH);
    }
  }

  function _trueUpTaxTokens() internal {
    uint256 _latestBalance = balanceOf(address(this));
    uint256 _latestDesiredBal = tokensForDevelopment +
      tokensForTreasury +
      tokensForLiquidity;
    if (_latestDesiredBal != _latestBalance) {
      if (_latestDesiredBal > _latestBalance) {
        bool _areExcessMoreThanBal = tokensForDevelopment + tokensForTreasury >
          _latestBalance;
        tokensForTreasury = _areExcessMoreThanBal ? 0 : tokensForTreasury;
        tokensForDevelopment = _areExcessMoreThanBal ? 0 : tokensForDevelopment;
      }
      tokensForLiquidity =
        _latestBalance -
        tokensForTreasury -
        tokensForDevelopment;
    }
  }

  function rewardsContract() external view returns (address) {
    return address(_rewards);
  }

  function isBlacklisted(address wallet) external view returns (bool) {
    return _isBlacklisted[wallet];
  }

  function blacklistWallet(address wallet) external onlyOwner {
    require(
      wallet != address(uniswapV2Router),
      'cannot not blacklist dex router'
    );
    require(!_isBlacklisted[wallet], 'wallet is already blacklisted');
    _isBlacklisted[wallet] = true;
  }

  function forgiveBlacklistedWallet(address wallet) external onlyOwner {
    require(_isBlacklisted[wallet], 'wallet is not blacklisted');
    _isBlacklisted[wallet] = false;
  }

  function setBuyTaxes(
    uint256 _developmentFee,
    uint256 _treasuryFee,
    uint256 _liquidityFee
  ) external onlyOwner {
    buyDevelopmentFee = _developmentFee;
    buyTreasuryFee = _treasuryFee;
    buyLiquidityFee = _liquidityFee;
    buyTotalFees = buyDevelopmentFee + buyTreasuryFee + buyLiquidityFee;
    require(
      buyTotalFees <= (PERCENT_DENOMENATOR * 15) / 100,
      'tax cannot be more than 15%'
    );
  }

  function setSellTaxes(
    uint256 _developmentFee,
    uint256 _treasuryFee,
    uint256 _liquidityFee
  ) external onlyOwner {
    sellDevelopmentFee = _developmentFee;
    sellTreasuryFee = _treasuryFee;
    sellLiquidityFee = _liquidityFee;
    sellTotalFees = sellDevelopmentFee + sellTreasuryFee + sellLiquidityFee;
    require(
      sellTotalFees <= (PERCENT_DENOMENATOR * 15) / 100,
      'tax cannot be more than 15%'
    );
  }

  function setMarketMakingPair(address _addy, bool _isPair) external onlyOwner {
    marketMakingPairs[_addy] = _isPair;
  }

  function setDevelopmentWallet(address _wallet) external onlyOwner {
    developmentWallet = _wallet;
  }

  function setTreasuryWallet(address _wallet) external onlyOwner {
    treasuryWallet = _wallet;
  }

  function setLiquidityWallet(address _wallet) external onlyOwner {
    liquidityWallet = _wallet;
  }

  function setMaxTxnAmount(uint256 _numTokens) external onlyOwner {
    require(
      _numTokens >= (totalSupply() * 1) / 1000,
      'must be more than 0.1% supply'
    );
    maxTxnAmount = _numTokens;
  }

  function setMaxWallet(uint256 _numTokens) external onlyOwner {
    require(
      _numTokens >= (totalSupply() * 5) / 1000,
      'must be more than 0.5% supply'
    );
    maxWallet = _numTokens;
  }

  function setLiquifyRate(uint256 _rate) external onlyOwner {
    require(_rate <= PERCENT_DENOMENATOR / 10, 'must be less than 10%');
    liquifyRate = _rate;
  }

  function setIsTaxExcluded(address _wallet, bool _isExcluded)
    external
    onlyOwner
  {
    _isTaxExcluded[_wallet] = _isExcluded;
  }

  function setIsExcludeFromMaxTxnAmount(address _wallet, bool _isExcluded)
    external
    onlyOwner
  {
    isExcludedMaxTxnAmount[_wallet] = _isExcluded;
  }

  function setIsExcludeFromMaxWallet(address _wallet, bool _isExcluded)
    external
    onlyOwner
  {
    isExcludedMaxWallet[_wallet] = _isExcluded;
  }

  function setTaxesOff(bool _areOff) external onlyOwner {
    _taxesOff = _areOff;
  }

  function setSwapEnabled(bool _enabled) external onlyOwner {
    _swapEnabled = _enabled;
  }

  function withdrawTokens(address _tokenAddy, uint256 _amount)
    external
    onlyOwner
  {
    require(_tokenAddy != address(this), 'cannot withdraw this token');
    IERC20 _token = IERC20(_tokenAddy);
    _amount = _amount > 0 ? _amount : _token.balanceOf(address(this));
    require(_amount > 0, 'make sure there is a balance available to withdraw');
    _token.transfer(owner(), _amount);
  }

  function withdrawETH() external onlyOwner {
    payable(owner()).call{ value: address(this).balance }('');
  }

  receive() external payable {}
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
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';
import './interfaces/IParrotRewards.sol';

contract ParrotRewards is IParrotRewards, Ownable {
  uint256 private constant ONE_DAY = 60 * 60 * 24;
  int256 private constant OFFSET19700101 = 2440588;

  struct Reward {
    uint256 totalExcluded;
    uint256 totalRealised;
    uint256 lastClaim;
  }

  struct Share {
    uint256 amount;
    uint256 lockedTime;
  }

  uint256 public timeLock = 30 days;
  address public shareholderToken;
  uint256 public totalLockedUsers;
  uint256 public totalSharesDeposited;

  uint8 public minDayOfMonthCanLock = 1;
  uint8 public maxDayOfMonthCanLock = 5;

  // amount of shares a user has
  mapping(address => Share) public shares;
  // reward information per user
  mapping(address => Reward) public rewards;

  uint256 public totalRewards;
  uint256 public totalDistributed;
  uint256 public rewardsPerShare;

  uint256 private constant ACC_FACTOR = 10**36;

  event ClaimReward(address wallet);
  event DistributeReward(address indexed wallet, address payable receiver);
  event DepositRewards(address indexed wallet, uint256 amountETH);

  constructor(address _shareholderToken) {
    shareholderToken = _shareholderToken;
  }

  function lock(uint256 _amount) external {
    uint256 _currentDayOfMonth = _dayOfMonth(block.timestamp);
    require(
      _currentDayOfMonth >= minDayOfMonthCanLock &&
        _currentDayOfMonth <= maxDayOfMonthCanLock,
      'outside of allowed lock window'
    );
    address shareholder = msg.sender;
    IERC20 tokenContract = IERC20(shareholderToken);
    _amount = _amount == 0 ? tokenContract.balanceOf(shareholder) : _amount;
    tokenContract.transferFrom(shareholder, address(this), _amount);
    _addShares(shareholder, _amount);
  }

  function unlock(uint256 _amount) external {
    address shareholder = msg.sender;
    require(
      block.timestamp >= shares[shareholder].lockedTime + timeLock,
      'must wait the time lock before unstaking'
    );
    _amount = _amount == 0 ? shares[shareholder].amount : _amount;
    require(_amount > 0, 'need tokens to unlock');
    require(
      _amount <= shares[shareholder].amount,
      'cannot unlock more than you have locked'
    );
    IERC20(shareholderToken).transfer(shareholder, _amount);
    _removeShares(shareholder, _amount);
  }

  function _addShares(address shareholder, uint256 amount) internal {
    _distributeReward(shareholder);

    uint256 sharesBefore = shares[shareholder].amount;
    totalSharesDeposited += amount;
    shares[shareholder].amount += amount;
    shares[shareholder].lockedTime = block.timestamp;
    if (sharesBefore == 0 && shares[shareholder].amount > 0) {
      totalLockedUsers++;
    }
    rewards[shareholder].totalExcluded = getCumulativeRewards(
      shares[shareholder].amount
    );
  }

  function _removeShares(address shareholder, uint256 amount) internal {
    amount = amount == 0 ? shares[shareholder].amount : amount;
    require(
      shares[shareholder].amount > 0 && amount <= shares[shareholder].amount,
      'you can only unlock if you have some lockd'
    );
    _distributeReward(shareholder);

    totalSharesDeposited -= amount;
    shares[shareholder].amount -= amount;
    if (shares[shareholder].amount == 0) {
      totalLockedUsers--;
    }
    rewards[shareholder].totalExcluded = getCumulativeRewards(
      shares[shareholder].amount
    );
  }

  function depositRewards() public payable override {
    _depositRewards(msg.value);
  }

  function _depositRewards(uint256 _amount) internal {
    require(_amount > 0, 'must provide ETH to deposit');
    require(totalSharesDeposited > 0, 'must be shares deposited');

    totalRewards += _amount;
    rewardsPerShare += (ACC_FACTOR * _amount) / totalSharesDeposited;
    emit DepositRewards(msg.sender, _amount);
  }

  function _distributeReward(address shareholder) internal {
    if (shares[shareholder].amount == 0) {
      return;
    }

    uint256 amount = getUnpaid(shareholder);

    rewards[shareholder].totalRealised += amount;
    rewards[shareholder].totalExcluded = getCumulativeRewards(
      shares[shareholder].amount
    );
    rewards[shareholder].lastClaim = block.timestamp;

    if (amount > 0) {
      address payable receiver = payable(shareholder);
      totalDistributed += amount;
      uint256 balanceBefore = address(this).balance;
      receiver.call{ value: amount }('');
      require(address(this).balance >= balanceBefore - amount);
      emit DistributeReward(shareholder, receiver);
    }
  }

  function _dayOfMonth(uint256 _timestamp) internal pure returns (uint256) {
    (, , uint256 day) = _daysToDate(_timestamp / ONE_DAY);
    return day;
  }

  // date conversion algorithm from http://aa.usno.navy.mil/faq/docs/JD_Formula.php
  function _daysToDate(uint256 _days)
    internal
    pure
    returns (
      uint256,
      uint256,
      uint256
    )
  {
    int256 __days = int256(_days);

    int256 L = __days + 68569 + OFFSET19700101;
    int256 N = (4 * L) / 146097;
    L = L - (146097 * N + 3) / 4;
    int256 _year = (4000 * (L + 1)) / 1461001;
    L = L - (1461 * _year) / 4 + 31;
    int256 _month = (80 * L) / 2447;
    int256 _day = L - (2447 * _month) / 80;
    L = _month / 11;
    _month = _month + 2 - 12 * L;
    _year = 100 * (N - 49) + _year + L;

    return (uint256(_year), uint256(_month), uint256(_day));
  }

  function claimReward() external override {
    _distributeReward(msg.sender);
    emit ClaimReward(msg.sender);
  }

  // returns the unpaid rewards
  function getUnpaid(address shareholder) public view returns (uint256) {
    if (shares[shareholder].amount == 0) {
      return 0;
    }

    uint256 earnedRewards = getCumulativeRewards(shares[shareholder].amount);
    uint256 rewardsExcluded = rewards[shareholder].totalExcluded;
    if (earnedRewards <= rewardsExcluded) {
      return 0;
    }

    return earnedRewards - rewardsExcluded;
  }

  function getCumulativeRewards(uint256 share) internal view returns (uint256) {
    return (share * rewardsPerShare) / ACC_FACTOR;
  }

  function getLockedShares(address user)
    external
    view
    override
    returns (uint256)
  {
    return shares[user].amount;
  }

  function setMinDayOfMonthCanLock(uint8 _day) external onlyOwner {
    require(_day <= maxDayOfMonthCanLock, 'can set min day above max day');
    minDayOfMonthCanLock = _day;
  }

  function setMaxDayOfMonthCanLock(uint8 _day) external onlyOwner {
    require(_day >= minDayOfMonthCanLock, 'can set max day below min day');
    maxDayOfMonthCanLock = _day;
  }

  function setTimeLock(uint256 numSec) external onlyOwner {
    require(numSec <= 365 days, 'must be less than a year');
    timeLock = numSec;
  }

  receive() external payable {
    _depositRewards(msg.value);
  }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IParrotRewards {
  function claimReward() external;

  function depositRewards() external payable;

  function getLockedShares(address wallet) external view returns (uint256);

  function lock(uint256 amount) external;

  function unlock(uint256 amount) external;
}