// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(msg.sender);
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
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./interfaces/IHTTERC20.sol";
import "./interfaces/IHTTPrivateSale.sol";
import "./libraries/SafeMath.sol";
import "./access/Ownable.sol";

contract HTTPrivateSale is IHTTPrivateSale, Ownable {
    using SafeMath for uint256;

    uint8 constant _decimals = 18;
    IHTTERC20 _httTokenContract;
    mapping(uint256 => Version) _versions;
    mapping(uint256 => mapping(address => uint256)) _versionBuyer;
    uint256 _currentVersion;
    bool _enable;

    constructor(address httTokenAddress) {
        _httTokenContract = IHTTERC20(httTokenAddress);
        _enable = false;
        _currentVersion = 0;
        _httTokenContract.approve(address(this), type(uint256).max);
    }

    modifier versionExist() {
        require(
            _versions[_currentVersion].initialized,
            "Private sale version not found"
        );
        _;
    }

    function balance() external view returns (uint256) {
        return _httTokenContract.balanceOf(address(this));
    }

    function hasEnable() external view override returns (bool) {
        return _enable;
    }

    function _setEnable(bool isEnable) internal {
        _enable = isEnable;
        emit StatusChanged(msg.sender, isEnable);
    }

    function enable(bool isEnable) external override onlyOwner {
        _setEnable(isEnable);
    }

    function addVersion(
        uint256 minBuyable,
        uint256 maxBuyable,
        uint256 supply,
        uint256 rate,
        bool enableVersion
    ) external override onlyOwner {
        require(minBuyable > 0, "Should put minBuyable > 0");
        require(maxBuyable > 0, "Should put maxBuyable > 0");
        require(maxBuyable > minBuyable, "Should put maxBuyable > minBuyable");
        require(supply > 0 && supply <= this.balance(), "Invalid supply");
        require(rate > 0, "Should put rate > 0");
        _versions[_currentVersion.add(1)] = Version(
            _currentVersion.add(1),
            true,
            minBuyable,
            maxBuyable,
            supply,
            0,
            rate
        );
        _currentVersion = _currentVersion.add(1);
        _setEnable(enableVersion);
    }

    function currentVersion()
        external
        view
        override
        versionExist
        returns (Version memory)
    {
        return _versions[_currentVersion];
    }

    function setRate(uint256 rate) external override versionExist onlyOwner {
        require(rate > 0, "Should put rate > 0");
        _versions[_currentVersion].rate = rate;
        emit RateChanged(msg.sender, _currentVersion, rate);
    }

    function buy() external payable override {
        require(
            _versions[_currentVersion].initialized,
            "Private sale version not found"
        );
        require(_enable, "Not enable yet");

        uint256 _boughtAmount = _versionBuyer[_currentVersion][msg.sender];
        uint256 httAmount = (msg.value / _versions[_currentVersion].rate) *
            10**_decimals;
        require(
            _boughtAmount.add(httAmount) <=
                _versions[_currentVersion].maxBuyable,
            "Over maxable"
        );
        require(
            httAmount >= _versions[_currentVersion].minBuyable &&
                httAmount <= this.balance() &&
                httAmount <= _versions[_currentVersion].totalSupply.sub(_versions[_currentVersion].soldSupply),
            "Invalid amount"
        );
        _httTokenContract.transfer(msg.sender, httAmount);
        _versions[_currentVersion].soldSupply = _versions[_currentVersion]
            .soldSupply
            .add(httAmount);
        _versionBuyer[_currentVersion][msg.sender] = _versionBuyer[
            _currentVersion
        ][msg.sender].add(httAmount);
        emit HttSold(
            msg.sender,
            _currentVersion,
            msg.value,
            _versions[_currentVersion].rate
        );
    }

    function boughtAmount()
        external
        view
        override
        versionExist
        returns (uint256)
    {
        return _versionBuyer[_currentVersion][msg.sender];
    }

    function withdrawEth() external override onlyOwner {
        address payable sender = payable(msg.sender);
        sender.transfer(address(this).balance);
    }

    function withdrawHTT() external override onlyOwner {
        _httTokenContract.transferFrom(address(this), owner(), this.balance());
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IHTTERC20 {
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
    function burn(uint256 amount) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IHTTPrivateSale {
    event MinChanged(
        address indexed owner,
        uint256 version,
        uint256 minBuyable
    );
    event MaxChanged(
        address indexed owner,
        uint256 version,
        uint256 maxBuyable
    );
    event RateChanged(address indexed owner, uint256 version, uint256 rate);
    event StatusChanged(address indexed owner, bool value);
    event SupplyChanged(address indexed owner, uint256 version, uint256 supply);
    event HttSold(
        address indexed buyer,
        uint256 version,
        uint256 amount,
        uint256 rate
    );

    struct Version {
        uint256 version;
        bool initialized;
        uint256 minBuyable;
        uint256 maxBuyable;
        uint256 totalSupply;
        uint256 soldSupply;
        uint256 rate;
    }

    function currentVersion() external view returns (Version memory);

    function addVersion(
        uint256 minBuyable,
        uint256 maxBuyable,
        uint256 supply,
        uint256 rate,
        bool enableVersion
    ) external;

    function enable(bool isEnable) external;

    function hasEnable() external view returns (bool);

    function setRate(uint256 rate) external;

    function buy() external payable;

    function boughtAmount() external view returns (uint256);

    function withdrawEth() external;

    function withdrawHTT() external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./interfaces/IHTTERC20.sol";
import "./interfaces/IHTTPrivateSale.sol";
import "./libraries/SafeMath.sol";
import "./access/Ownable.sol";

contract HTTERC20 is IHTTERC20, Ownable {
    using SafeMath for uint256;

    string constant _name = "HiTrade Token";
    string constant _symbol = "HTT";
    uint8 constant _decimals = 18;
    uint256 _totalSupply = 1_000_000_000e18;

    mapping(address => uint256) public _balances;
    mapping(address => mapping(address => uint256)) public _allowances;
    mapping(address => uint256) public _nonces;

    bytes32 public _DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant _PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    constructor() {
        uint256 chainId;
        address owner = msg.sender;
        assembly {
            chainId := chainid()
        }
        _balances[owner] = uint96(_totalSupply);
        emit Transfer(address(0), owner, _totalSupply);
        _DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function _burn(address from, uint256 value) internal {
        require(_balances[from] >= value, "ERC20: burn amount exceeds balance");
        _balances[from] = _balances[from].sub(value);
        _totalSupply = _totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) private {
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        emit Transfer(from, to, value);
    }

    function name() public pure virtual override returns (string memory) {
        return _name;
    }

    function symbol() public pure virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public pure virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function DOMAIN_SEPARATOR() public view virtual override returns (bytes32) {
        return _DOMAIN_SEPARATOR;
    }

    function PERMIT_TYPEHASH() public pure virtual override returns (bytes32) {
        return _PERMIT_TYPEHASH;
    }

    function burn(uint256 amount) external override onlyOwner {
        _burn(msg.sender, amount);
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function nonces(address owner) external view override returns (uint256) {
        return _nonces[owner];
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        if (_allowances[from][msg.sender] != type(uint256).max) {
            _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(
                value
            );
        }
        _transfer(from, to, value);
        return true;
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "HTT: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        _nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "HTT: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }
}