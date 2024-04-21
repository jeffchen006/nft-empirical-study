//SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "./AbstractLocker_v30.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

contract BalanceLocker_v30 is Initializable, ContextUpgradeable, OwnableUpgradeable,
    ERC20BurnableUpgradeable, AbstractLocker_v30
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    string private constant _LP_NAME = 'BAG Bridge LP';
    string private constant _LP_SYMBOL = 'BBLP';
    uint8 private _decimals;
    uint256 public lpFeeShareBP;
    uint256 public lpLockerTokenBalance;
    uint256 public lpLockerTokenBalanceCap;

    /*
    // EIP-2612 https://eips.ethereum.org/EIPS/eip-2612
    bytes32 public LP_DOMAIN_SEPARATOR;
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant LP_PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => CountersUpgradeable.Counter) private _nonces;
    */

    // Oracle
    bytes32 private constant LIQUIDITY_REFUND_TYPEHASH=keccak256(abi.encodePacked(
        "LiquidityRefund(uint256 claimId,uint256 sourceChainGuid,address sourceLockerAddress,address sourceAddress,uint256 amount,uint256 deadline)"
    ));

    function initialize(
        uint256 _chainGuid,
        address _lockerToken,
        address _oracleAddress,
        address _feeAddress,
        uint16 _feeBP,
        uint16 _lpFeeShareBP,
        uint256 _lpLockerTokenBalanceCap
    ) public initializer {
        __BalanceLocker_init(_chainGuid, _lockerToken, _oracleAddress, _feeAddress, _feeBP,
            _lpFeeShareBP, _lpLockerTokenBalanceCap);
    }

    function __BalanceLocker_init(
        uint256 _chainGuid,
        address _lockerToken,
        address _oracleAddress,
        address _feeAddress,
        uint16 _feeBP,
        uint16 _lpFeeShareBP,
        uint256 _lpLockerTokenBalanceCap
    ) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ERC20_init_unchained(_LP_NAME, _LP_SYMBOL);
        _decimals = 18;
        __ERC20Burnable_init_unchained();
        __AbstractLocker_init_unchained(_chainGuid, _lockerToken, _oracleAddress, _feeAddress, _feeBP);
        __BalanceLocker_init_unchained(_lpFeeShareBP, _lpLockerTokenBalanceCap);
    }

    function __BalanceLocker_init_unchained(
        uint16 _lpFeeShareBP,
        uint256 _lpLockerTokenBalanceCap
    ) internal initializer {
        require(_lpFeeShareBP <= 10000, 'initialize: invalid lpFeeShareBP');

        /*
        LP_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(_LP_NAME)),
                keccak256(bytes('1')),
                evmChainId,
                address(this)
            )
        );
        */
        lpLockerTokenBalance = 0;
        lpFeeShareBP = _lpFeeShareBP;
        lpLockerTokenBalanceCap = _lpLockerTokenBalanceCap;
    }

    function setLpLockerTokenBalanceCap(uint256 _cap) external onlyOwner {
        lpLockerTokenBalanceCap = _cap;
    }

    // AbstractLocker overrides

    function _receiveTokens(
        address _fromAddress,
        uint256 _amount
    ) virtual internal override {
        // transfer in tokens
        IERC20Upgradeable(lockerToken).safeTransferFrom(
            address(_fromAddress),
            address(this),
            _amount
        );
    }

    function _sendTokens(
        address _toAddress,
        uint256 _amount
    ) virtual internal override {
        require(IERC20Upgradeable(lockerToken).balanceOf(address(this)) >= _amount,
            'sendTokens: insufficient funds');
        // transfer out tokens
        IERC20Upgradeable(lockerToken).safeTransfer(
            address(_toAddress),
            _amount
        );
    }

    function _sendFees(
        uint256 _feeAmount
    ) virtual internal override {
        uint256 lpFeeAmount = _feeAmount * lpFeeShareBP / 10000;
        uint256 netFeeAmount = _feeAmount - lpFeeAmount;

        lpLockerTokenBalance = lpLockerTokenBalance + lpFeeAmount;
        // increment LP fee balance
        _sendTokens(feeAddress, netFeeAmount);
    }

    // EIP-2612 functions - https://eips.ethereum.org/EIPS/eip-2612
    /*
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        // Checks
        require(deadline >= block.timestamp, 'permit: expired');
        bytes32 digest = keccak256(
            abi.encodePacked(
                '\x19\x01',
                LP_DOMAIN_SEPARATOR,
                keccak256(abi.encode(LP_PERMIT_TYPEHASH,
                    owner, spender, value, _nonces[owner].current(), deadline))
            )
        );
        address recoveredAddress = ECDSAUpgradeable.recover(digest, v, r, s);
        require(recoveredAddress != address(0) && recoveredAddress == owner,
            'permit: invalid');

        // Effects
        _nonces[owner].increment();

        // Interactions
        _approve(owner, spender, value);
    }

    function nonces(address owner) public view returns (uint256) {
        return _nonces[owner].current();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return LP_DOMAIN_SEPARATOR;
    }
    */

    // Liquidity management functions

    function calcNewLiquidity(
        uint256 _newAmount
    ) view internal returns (uint liquidity) {
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            liquidity = _newAmount;
        } else {
            liquidity = _newAmount * totalSupply / lpLockerTokenBalance;
        }
    }

    function liquidityAdd(
        uint256 _amount,
        address _to,
        uint256 _deadline
    ) external {
        // Checks
        require(_deadline >= block.timestamp, 'liquidityAdd: expired');
        require(_amount > 0, 'liquidityAdd: zero amount');
        require(lpLockerTokenBalance + _amount < lpLockerTokenBalanceCap, 'liquidityAdd: cap exceeded');

        // Effects
        uint256 liquidity = calcNewLiquidity(_amount);
        lpLockerTokenBalance = lpLockerTokenBalance + _amount;

        // Interactions
        _receiveTokens(msg.sender, _amount);

        _mint(_to, liquidity);
        emit LiquidityAdd(msg.sender, _to, _amount);
    }

    function liquidityRemove(
        uint256 _targetChainGuid,
        address _targetLockerAddress,
        address _targetAddress,
        uint256 _liquidity,
        bool _payImmediateFee,
        uint256 _deadline
    ) external {
        // Checks
        require(_deadline >= block.timestamp, 'liquidityRemove: expired');
        require(_liquidity > 0, 'liquidityRemove: zero liquidity');
        bool sameLocker = (address(this) == _targetLockerAddress) && (chainGuid == _targetChainGuid);
        require(!(_payImmediateFee && sameLocker), 'liquidityRemove: invalid fee');
        uint256 totalSupply = totalSupply();
        require(_liquidity <= totalSupply, 'liquidityRemove: invalid liquidity');

        // Effects
        uint256 removedAmount = lpLockerTokenBalance * _liquidity / totalSupply;
        require(lpLockerTokenBalance >= removedAmount, 'liquidityRemove: negative balance');
        lpLockerTokenBalance = lpLockerTokenBalance - removedAmount;

        // Interactions
        burn(_liquidity);
        if (sameLocker) {
            // immediate removal is allowed
            _sendTokens(_targetAddress, removedAmount);
        }
        // otherwise wait for oracle to confirm claim time based on fee payment
        emit LiquidityRemove(msg.sender, _targetChainGuid, _targetLockerAddress, _targetAddress, removedAmount);
    }

    function liquidityRefund(
        uint256 _claimId,
        uint256 _sourceChainGuid,
        address _sourceLockerAddress,
        address _sourceAddress,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Checks
        require(_deadline >= block.timestamp, 'liquidityRefund: expired');
        require(chainGuid == _sourceChainGuid, 'liquidityRefund: wrong chain');
        require(address(this) == _sourceLockerAddress, 'liquidityRefund: wrong locker');
        require(claims[_claimId] == false, 'liquidityRefund: claim used');
        require(IERC20Decimals(lockerToken).decimals() == tokenDecimals, 'liquidityRefund: bad decimals');

        // values must cover all non-signature arguments to the external function call
        bytes32 values = keccak256(abi.encode(
            LIQUIDITY_REFUND_TYPEHASH,
            _claimId, _sourceChainGuid, _sourceLockerAddress, _sourceAddress, _amount, _deadline
        ));
        _verify(values, _v, _r, _s);

        // Effects
        claims[_claimId] = true;
        uint256 liquidity = calcNewLiquidity(_amount);
        lpLockerTokenBalance = lpLockerTokenBalance + _amount;

        // Interactions
        _mint(_sourceAddress, liquidity);

        emit LiquidityRefund(msg.sender, _sourceAddress, _amount);
    }

    function setupTokenDecimals() public override onlyOwner {
        super.setupTokenDecimals();
        require(tokenDecimals<=255, 'setupTokenDecimals: invalid decimals');
        _decimals = tokenDecimals;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    uint256[50] private __gap;
}

//SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20Decimals {
    function decimals() external returns (uint8);
}

abstract contract AbstractLocker_v30 is Initializable, OwnableUpgradeable {
    string constant EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA = "\x19\x01";
    bytes32 constant EIP712_DOMAIN_TYPEHASH=keccak256(abi.encodePacked(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    ));
    bytes32 private constant BRIDGE_WITHDRAW_TYPEHASH=keccak256(abi.encodePacked(
        "BridgeWithdraw(uint256 claimId,uint256 targetChainGuid,address targetLockerAddress,address targetAddress,uint256 amount,uint256 deadline)"
    ));
    bytes32 private constant BRIDGE_REFUND_TYPEHASH=keccak256(abi.encodePacked(
        "BridgeRefund(uint256 claimId,uint256 sourceChainGuid,address sourceLockerAddress,address sourceAddress,uint256 amount)"
    ));
    bytes32 private constant LIQUIDITY_WITHDRAW_TYPEHASH=keccak256(abi.encodePacked(
        "LiquidityWithdraw(uint256 claimId,uint256 targetChainGuid,address targetLockerAddress,address targetAddress,uint256 amount,uint256 deadline,bool bypassFee)"
    ));
    bytes32 private ORACLE_DOMAIN_SEPARATOR;
    uint256 public chainGuid;
    uint256 public evmChainId;
    address public lockerToken;
    address public feeAddress;
    uint16 public feeBP;
    bool public maintenanceMode;
    mapping(address => bool) public oracles;
    mapping(uint256 => bool) public claims;
    uint8 public tokenDecimals;

    event BridgeDeposit(address indexed sender, uint256 indexed targetChainGuid, address targetLockerAddress, address indexed targetAddress, uint256 amount);
    event BridgeWithdraw(address indexed sender, address indexed targetAddress,  uint256 amount);
    event BridgeRefund(address indexed sender, address indexed sourceAddress, uint256 amount);

    event LiquidityAdd(address indexed sender, address indexed to, uint256 amount);
    event LiquidityRemove(address indexed sender, uint256 indexed targetChainGuid, address targetLockerAddress, address indexed targetAddress, uint256 amount);
    event LiquidityWithdraw(address indexed sender, uint256 indexed targetChainGuid, address targetLockerAddress, address indexed targetAddress, uint256 amount);
    event LiquidityRefund(address indexed sender, address indexed sourceAddress, uint256 amount);

    function __AbstractLocker_init(
        uint256 _chainGuid,
        address _lockerToken,
        address _oracleAddress,
        address _feeAddress,
        uint16 _feeBP
    ) internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __AbstractLocker_init_unchained(_chainGuid, _lockerToken, _oracleAddress, _feeAddress, _feeBP);
    }

    function __AbstractLocker_init_unchained(
        uint256 _chainGuid,
        address _lockerToken,
        address _oracleAddress,
        address _feeAddress,
        uint16 _feeBP
    ) internal initializer {
        require(_feeBP <= 10000, "initialize: invalid fee");

        uint256 _evmChainId;
        assembly {
            _evmChainId := chainid()
        }
        chainGuid = _chainGuid;
        evmChainId = _evmChainId;
        lockerToken = _lockerToken;
        feeAddress = _feeAddress;
        feeBP = _feeBP;
        maintenanceMode = false;
        oracles[_oracleAddress] = true;

        bytes32 _ORACLE_DOMAIN_SEPARATOR = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256("BAG Locker Oracle"),
            keccak256("2"),
            _evmChainId,
            address(this)
        ));
        ORACLE_DOMAIN_SEPARATOR = _ORACLE_DOMAIN_SEPARATOR;

        setupTokenDecimals();
    }

    modifier live {
        require(!maintenanceMode, "locker: maintenance mode");
        _;
    }

    function setupTokenDecimals() public virtual onlyOwner {
        tokenDecimals = IERC20Decimals(lockerToken).decimals();
    }

    // Update fee address
    function setFeeAddress(address _feeAddress) external {
        require(msg.sender == feeAddress, "setFeeAddress: not authorized");
        feeAddress = _feeAddress;
    }

    // Update fee bps
    function setFeeBP(uint16 _feeBP) external onlyOwner {
        require(_feeBP <= 10000, "setFeeBP: invalid fee");
        feeBP = _feeBP;
    }

    // Update oracle address
    function addOracleAddress(address _oracleAddress) external onlyOwner {
        oracles[_oracleAddress] = true;
    }

    function removeOracleAddress(address _oracleAddress) external onlyOwner {
        oracles[_oracleAddress] = false;
    }

    // Update maintenance mode
    function setMaintenanceMode(bool _maintenanceMode) external onlyOwner {
        maintenanceMode = _maintenanceMode;
    }

    // Check if the claim has been processed and return current block time and number
    function isClaimed(uint256 _claimId) external view returns (bool, uint256, uint256) {
        return (claims[_claimId], block.timestamp, block.number);
    }

    // Deposit funds to locker from transfer to another chain
    function bridgeDeposit(
        uint256 _targetChainGuid,
        address _targetLockerAddress,
        address _targetAddress,
        uint256 _amount,
        uint256 _deadline
    ) external live {
        // Checks
        require(_targetChainGuid != chainGuid || _targetLockerAddress != address(this), 'bridgeDeposit: same locker');
        require(_amount > 0, 'bridgeDeposit: zero amount');
        require(_deadline >= block.timestamp, 'bridgeDeposit: invalid deadline');

        // Effects

        // Interaction
        _receiveTokens(msg.sender, _amount);

        emit BridgeDeposit(msg.sender, _targetChainGuid, _targetLockerAddress, _targetAddress, _amount);
    }

    // Withdraw tokens on a new chain with a valid claim from the oracle
    function bridgeWithdraw(
        uint256 _claimId,
        uint256 _targetChainGuid,
        address _targetLockerAddress,
        address _targetAddress,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Checks
        require(chainGuid == _targetChainGuid, 'bridgeWithdraw: wrong chain');
        require(address(this) == _targetLockerAddress, 'bridgeWithdraw: wrong locker');
        require(_deadline >= block.timestamp, 'bridgeWithdraw: claim expired');
        require(claims[_claimId] == false, 'bridgeWithdraw: claim used');
        require(IERC20Decimals(lockerToken).decimals() == tokenDecimals, 'bridgeWithdraw: bad decimals');

        uint256 feeAmount = _amount * feeBP / 10000;
        uint256 netAmount = _amount - feeAmount;

        // values must cover all non-signature arguments to the external function call
        bytes32 values = keccak256(abi.encode(
            BRIDGE_WITHDRAW_TYPEHASH,
            _claimId, _targetChainGuid, _targetLockerAddress, _targetAddress, _amount, _deadline
        ));
        _verify(values, _v, _r, _s);

        // Effects
        claims[_claimId] = true;

        // Interactions
        if (feeAmount > 0) {
            _sendFees(feeAmount);
        }
        _sendTokens(_targetAddress, netAmount);

        emit BridgeWithdraw(msg.sender, _targetAddress, _amount);
    }

    // Refund tokens on the original chain with a valid claim from the oracle
    function bridgeRefund(
        uint256 _claimId,
        uint256 _sourceChainGuid,
        address _sourceLockerAddress,
        address _sourceAddress,
        uint256 _amount,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Checks
        require((chainGuid == _sourceChainGuid) && (address(this) == _sourceLockerAddress), 'bridgeRefund: wrong chain');
        require(claims[_claimId] == false, 'bridgeRefund: claim used');
        require(IERC20Decimals(lockerToken).decimals() == tokenDecimals, 'bridgeRefund: bad decimals');

        // values must cover all non-signature arguments to the external function call
        bytes32 values = keccak256(abi.encode(
            BRIDGE_REFUND_TYPEHASH,
            _claimId, _sourceChainGuid, _sourceLockerAddress, _sourceAddress, _amount
        ));
        _verify(values, _v, _r, _s);

        // Effects
        claims[_claimId] = true;

        // Interactions
        _sendTokens(_sourceAddress, _amount);

        emit BridgeRefund(msg.sender, _sourceAddress, _amount);
    }


    // Withdraw tokens on a new chain with a valid claim from the oracle
    function liquidityWithdraw(
        uint256 _claimId,
        uint256 _targetChainGuid,
        address _targetLockerAddress,
        address _targetAddress,
        uint256 _amount,
        uint256 _deadline,
        bool _bypassFee,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Checks
        require(chainGuid == _targetChainGuid, 'liquidityWithdraw: wrong chain');
        require(address(this) == _targetLockerAddress, 'liquidityWithdraw: wrong locker');
        require(_deadline >= block.timestamp, 'liquidityWithdraw: claim expired');
        require(claims[_claimId] == false, 'liquidityWithdraw: claim used');
        require(IERC20Decimals(lockerToken).decimals() == tokenDecimals, 'liquidityWithdraw: bad decimals');

        // values must cover all non-signature arguments to the publexternalic function call
        bytes32 values = keccak256(abi.encode(
            LIQUIDITY_WITHDRAW_TYPEHASH,
            _claimId, _targetChainGuid, _targetLockerAddress, _targetAddress, _amount, _deadline, _bypassFee
        ));
        _verify(values, _v, _r, _s);

        // Effects
        claims[_claimId] = true;

        // Interactions
        uint256 feeAmount = _bypassFee ? 0 : _amount * feeBP / 10000;
        uint256 netAmount = _amount - feeAmount;
        if (feeAmount > 0) {
            _sendFees(feeAmount);
        }
        _sendTokens(_targetAddress, netAmount);

        emit LiquidityWithdraw(msg.sender, _targetChainGuid, _targetLockerAddress, _targetAddress, _amount);
    }

    // Verifies that the claim signature is from a trusted source
    function _verify(
        bytes32 _values,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal view {
        bytes32 digest = keccak256(abi.encodePacked(
            EIP191_PREFIX_FOR_EIP712_STRUCTURED_DATA,
            ORACLE_DOMAIN_SEPARATOR,
            _values
        ));
        address recoveredAddress = ECDSAUpgradeable.recover(digest, _v, _r, _s);
        require(oracles[recoveredAddress], 'verify: tampered sig');
    }

    function _receiveTokens(
        address _fromAddress,
        uint256 _amount
    ) virtual internal;

    function _sendTokens(
        address _toAddress,
        uint256 _amount
    ) virtual internal;

    function _sendFees(
        uint256 _feeAmount
    ) virtual internal;

    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
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
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC20Upgradeable.sol";
import "../../../utils/ContextUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20BurnableUpgradeable is Initializable, ContextUpgradeable, ERC20Upgradeable {
    function __ERC20Burnable_init() internal initializer {
        __Context_init_unchained();
        __ERC20Burnable_init_unchained();
    }

    function __ERC20Burnable_init_unchained() internal initializer {
    }
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "ERC20: burn amount exceeds allowance");
        unchecked {
            _approve(account, _msgSender(), currentAllowance - amount);
        }
        _burn(account, amount);
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library CountersUpgradeable {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSAUpgradeable {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        // Check the signature length
        // - case 65: r,s,v signature (standard)
        // - case 64: r,vs signature (cf https://eips.ethereum.org/EIPS/eip-2098) _Available since v4.1._
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else if (signature.length == 64) {
            bytes32 r;
            bytes32 vs;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            assembly {
                r := mload(add(signature, 0x20))
                vs := mload(add(signature, 0x40))
            }
            return tryRecover(hash, r, vs);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s;
        uint8 v;
        assembly {
            s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
            v := add(shr(255, vs), 27)
        }
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
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
    function __ERC20_init(string memory name_, string memory symbol_) internal initializer {
        __Context_init_unchained();
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal initializer {
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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
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
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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