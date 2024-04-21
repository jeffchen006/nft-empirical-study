/**
 *Submitted for verification at Etherscan.io on 2023-06-03
*/

// File: @openzeppelin/contracts/utils/Context.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)
/*

website: https://proof-of-stake.site/

Twitter: https://twitter.com/PoS_token

Telegram: https://t.me/ProofofStakeToken

*/

pragma solidity ^0.8.20;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _setOwner(msg.sender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata, Ownable {
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

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
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
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

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

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
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

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

pragma solidity ^0.8.20;

contract PoS is ERC20 {
    constructor() ERC20("Proof Of Stake", "$PoS") {
        _mint(msg.sender, 1000000000 * 10**decimals());
    }

    uint256 minLockTimeTime = 7140; //1 day 7140
    //1 month => 214214 blocks
    uint256 rewardPerBlock = 28; //0.00000028% per block or 5% per 30 days
    uint256 rewardDevider = 10000000000;
    uint256 stakedTokens = 0;
    uint256 claimedTokens = 0;

    mapping(address => uint256) private _stakingAmount;
    mapping(address => bool) private _stakingAlready;
    mapping(address => uint256) private _stakingStart;
    mapping(address => uint256) private _midStakeClaim;
    mapping(address => uint256) private _claimAmount;
    mapping(address => bool) private _withdrawAlready;

    mapping(address => uint256) private _claimed;

    function stake(uint256 amount) external {
        require(amount > 0);
        require(balanceOf(msg.sender) > 0);
        require(!_stakingAlready[msg.sender]);

        _transfer(msg.sender, address(this), amount);
        _stakingAmount[msg.sender] += amount;
        _stakingAlready[msg.sender] = true;
        _stakingStart[msg.sender] = block.timestamp;
        _midStakeClaim[msg.sender] = block.timestamp;
        stakedTokens += amount;
    }

    function unStake() external {
        require(_stakingAmount[msg.sender] > 0, "You do not stake any tokens!");

        if (_stakingStart[msg.sender] + minLockTimeTime <= block.timestamp) {
            uint256 reward = rewardPerBlock *(block.timestamp - _midStakeClaim[msg.sender]) *(_stakingAmount[msg.sender] / rewardDevider);
            _mint(msg.sender, reward);
            claimedTokens += reward;
            _claimed[msg.sender] += reward;
        }

        _transfer(address(this), msg.sender, _stakingAmount[msg.sender]);
        stakedTokens -= _stakingAmount[msg.sender];
        _stakingAlready[msg.sender] = false;
        _stakingAmount[msg.sender] = 0;
    }

    function claimRewards() external {
        require(_stakingStart[msg.sender] + minLockTimeTime <= block.timestamp);
        require(_stakingAlready[msg.sender]);

        uint256 reward = rewardPerBlock *(block.timestamp - _midStakeClaim[msg.sender]) *(_stakingAmount[msg.sender] / rewardDevider);
        _mint(msg.sender, reward);
        claimedTokens += reward;
        _claimed[msg.sender] += reward;
        _midStakeClaim[msg.sender] = block.timestamp;
    }

    function addressStake(address user) public view virtual returns (uint256){
        return _stakingAmount[user];
    }

    function toClaim(address user) public view virtual returns (uint256){
        if(_stakingStart[user] + minLockTimeTime <= block.timestamp){
            return rewardPerBlock *(block.timestamp - _midStakeClaim[user]) *(_stakingAmount[user] / rewardDevider);
        }
        return 0;
    }

    function totalStake() public view virtual returns (uint256){
        return stakedTokens;
    }

    function addressClaimed(address user) public view virtual returns (uint256){
        return _claimed[user];
    }

    function totalClaimed() public view virtual returns (uint256){
        return claimedTokens;
    }
}