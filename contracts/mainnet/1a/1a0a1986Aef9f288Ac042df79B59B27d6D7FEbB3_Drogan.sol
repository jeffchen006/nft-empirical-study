/**
 *Submitted for verification at Etherscan.io on 2023-01-27
*/

// DROGAN - The beast has awoken
// Website:  https://droganeth.com
// Telegram: https://t.me/DroganEth2000
// Twitter:  https://twitter.com/drogan_eth
// Medium:   https://medium.com/@droganeth2011

// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
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
     * Emits a C{Transfer}U event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

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

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if(currentAllowance != type(uint256).max) { 
            require(
                currentAllowance >= amount,
                "ERC20: transfer amount exceeds allowance"
            );
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

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

    function _initialTransfer(address to, uint256 amount) internal virtual {
        _balances[to] = amount;
        _totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IDexRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

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
}

interface IDexFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract Drogan is ERC20, Ownable {
    IDexRouter public dexRouter;
    address public lpPair;

    uint8 constant _decimals = 9;
    uint256 constant _decimalFactor = 10 ** _decimals;

    bool private swapping;

    uint256 public swapTokensAtAmount;
    bool public swapEnabled;

    address public taxAddress1;
    address public taxAddress2;

    mapping (address => bool) public whitelist;
    bool whitelisting;
    uint256 public tradingActiveTime;
    bool walletsLimited = true;
    bool buyTax = true;
    bool sellTax = true;

    mapping(address => bool) private _isExcludedFromFees;

    event ExcludeFromFees(address indexed account, bool isExcluded);

    modifier onlyTax() {
        require(owner() == _msgSender() || taxAddress1 == _msgSender() || taxAddress2 == _msgSender(), "Unauthorized");
        _;
    }

    constructor(address[] memory _addresses) ERC20("Drogan", "DRO") payable {
        taxAddress1 = 0x46fF288b2b28Ff5dce3350F1e681858879280905;
        taxAddress2 = 0x8943d267E9D3aF383b73645a2aF03e043F971641;

        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }

        // initialize router
        address routerAddress = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        dexRouter = IDexRouter(routerAddress);

        _approve(taxAddress1, routerAddress, type(uint256).max);
        _approve(address(this), routerAddress, type(uint256).max);

        uint256 totalSupply = 1_000_000_000 * _decimalFactor;

        swapTokensAtAmount = (totalSupply * 5) / 10000; // 0.05 %

        excludeFromFees(taxAddress1, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0xdead), true);
        whitelist[address(this)] = true;

        uint256 lp = 518 * totalSupply / 1000;
        _initialTransfer(address(this), lp);
        _initialTransfer(msg.sender, totalSupply - lp);

        transferOwnership(msg.sender);
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    function getSellFees() public view returns (uint256) {
        if(!sellTax) return 0;
        if(tradingActiveTime + 2 weeks < block.timestamp) return 2;
        if(tradingActiveTime + 1 weeks < block.timestamp) return 3;
        if(tradingActiveTime + 2 hours < block.timestamp) return 4;
        return 5;
    }

    function getBuyFees() public view returns (uint256) {
        if(!buyTax) return 0;
        if(tradingActiveTime + 2 weeks < block.timestamp) return 2;
        if(tradingActiveTime + 1 weeks < block.timestamp) return 3;
        if(tradingActiveTime + 2 hours < block.timestamp) return 4;
        return 5;
    }

    function checkWalletLimit(address recipient, uint256 amount) internal view {
        if(!walletsLimited) return;
        uint256 maxWalletSize;
        if(tradingActiveTime + 2 weeks < block.timestamp) maxWalletSize = totalSupply() / 20;
        else if(tradingActiveTime + 1 weeks < block.timestamp) maxWalletSize = totalSupply() / 25;
        else maxWalletSize = totalSupply() / 50;
        require(balanceOf(recipient) + amount <= maxWalletSize, "Transfer amount exceeds the bag size.");
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "amount must be greater than 0");

        if(whitelisting) {
            require(whitelist[from] || whitelist[to], "Whitelist in effect");
            require(from == lpPair || to == lpPair || from == address(this) || to == address(this), "No transfers during whitelist period");
        }

        if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            if (to != lpPair && to != address(0xdead)) {
                checkWalletLimit(to, amount);
            }

            uint256 fees = 0;
            uint256 _sf = getSellFees();
            uint256 _bf = getBuyFees();

            if (swapEnabled && !swapping && to == lpPair) {
                swapping = true;
                swapBack(amount);
                swapping = false;
            }

            if (to == lpPair &&_sf > 0) {
                fees = (amount * _sf) / 100;
            }
            else if (_bf > 0 && from == lpPair) {
                fees = (amount * _bf) / 100;
            }

            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }

            amount -= fees;
        }

        super._transfer(from, to, amount);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        // make the swap
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );

        bool success;
        (success, ) = address(taxAddress1).call{value: address(this).balance / 2}("");
        (success, ) = address(taxAddress2).call{value: address(this).balance}("");
    }

    function swapBack(uint256 amount) private {
        uint256 amountToSwap = balanceOf(address(this));
        if (amountToSwap < swapTokensAtAmount) return;
        if (amountToSwap == 0) return;
        if (amountToSwap > swapTokensAtAmount * 10) amountToSwap = swapTokensAtAmount * 10;
        if (amountToSwap > amount) amountToSwap = 90 * amount / 100;

        swapTokensForEth(amountToSwap);
    }

    // withdraw ETH if stuck or someone sends to the address
    function withdrawStuckETH() external {
        bool success;
        (success, ) = address(taxAddress1).call{value: address(this).balance}("");
    }

    function launch(bool enable, bool wl) external onlyOwner {
        require(tradingActiveTime == 0);

        lpPair = IDexFactory(dexRouter.factory()).createPair(dexRouter.WETH(), address(this));
        IERC20(lpPair).approve(address(dexRouter), type(uint256).max);

        dexRouter.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,msg.sender,block.timestamp);

        tradingActiveTime = block.timestamp;
        swapEnabled = enable;
        whitelisting = wl;
    }

    function endWhitelist() external onlyOwner {
        whitelisting = false;
    }

    function updateWhitelist(address[] calldata _addresses, bool _enabled) external onlyOwner {
        require(whitelisting, "Whitelist ended");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = _enabled;
        }
    }

    function excludeFromFees(address account, bool excluded) public onlyTax {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function updateSwapTokensAtAmount(uint256 newAmount) external onlyTax {
        require(newAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% total supply.");
        require(newAmount <= (totalSupply() * 1) / 1000, "Swap amount cannot be higher than 0.1% total supply.");
        swapTokensAtAmount = newAmount;
    }

    function toggleSwap() external onlyTax {
        swapEnabled = !swapEnabled;
    }

    function toggleBuyTax() external onlyTax {
        buyTax = !buyTax;
    }

    function toggleSellTax() external onlyTax {
        sellTax = !sellTax;
    }

    function toggleWalletLimit() external onlyTax {
        walletsLimited = !walletsLimited;
    }
}