// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.4;

import {IOracle} from "./interfaces/IOracle.sol";
import "./interfaces/IButtonToken.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title The ButtonToken ERC20 wrapper.
 *
 * @dev The ButtonToken is a rebasing wrapper for fixed balance ERC-20 tokens.
 *
 *      Users deposit the "underlying" (wrapped) tokens and are
 *      minted button (wrapper) tokens with elastic balances
 *      which change up or down when the value of the underlying token changes.
 *
 *      For example: Manny “wraps” 1 Ether when the price of Ether is $1800.
 *      Manny receives 1800 ButtonEther tokens in return.
 *      The overall value of their ButtonEther is the same as their original Ether,
 *      however each unit is now priced at exactly $1. The next day,
 *      the price of Ether changes to $1900. The ButtonEther system detects
 *      this price change, and rebases such that Manny’s balance is
 *      now 1900 ButtonEther tokens, still priced at $1 each.
 *
 *      The ButtonToken math is almost identical to Ampleforth's μFragments.
 *
 *      For AMPL, internal balances are represented using `gons` and
 *          -> internal account balance     `_gonBalances[account]`
 *          -> internal supply scalar       `gonsPerFragment = TOTAL_GONS / _totalSupply`
 *          -> public balance               `_gonBalances[account] * gonsPerFragment`
 *          -> public total supply          `_totalSupply`
 *
 *      In our case internal balances are stored as 'bits'.
 *          -> underlying token unit price  `p_u = price / 10 ^ (PRICE_DECIMALS)`
 *          -> total underlying tokens      `_totalUnderlying`
 *          -> internal account balance     `_accountBits[account]`
 *          -> internal supply scalar       `_bitsPerToken`
                                            ` = TOTAL_BITS / (MAX_UNDERLYING*p_u)`
 *                                          ` = BITS_PER_UNDERLYING*(10^PRICE_DECIMALS)/price`
 *                                          ` = PRICE_BITS / price`
 *          -> user's underlying balance    `(_accountBits[account] / BITS_PER_UNDERLYING`
 *          -> public balance               `_accountBits[account] * _bitsPerToken`
 *          -> public total supply          `_totalUnderlying * p_u`
 *
 *
 */
contract ButtonToken is IButtonToken, Initializable, OwnableUpgradeable {
    // PLEASE READ BEFORE CHANGING ANY ACCOUNTING OR MATH
    // We make the following guarantees:
    // - If address 'A' transfers x button tokens to address 'B'.
    //   A's resulting external balance will be decreased by "precisely" x button tokens,
    //   and B's external balance will be "precisely" increased by x button tokens.
    // - If address 'A' deposits y underlying tokens,
    //   A's resulting underlying balance will increase by "precisely" y.
    // - If address 'A' withdraws y underlying tokens,
    //   A's resulting underlying balance will decrease by "precisely" y.
    //
    using SafeERC20 for IERC20;

    //--------------------------------------------------------------------------
    // Constants

    /// @dev The price has a 8 decimal point precision.
    uint256 public constant PRICE_DECIMALS = 8;

    /// @dev Math constants.
    uint256 private constant MAX_UINT256 = type(uint256).max;

    /// @dev The maximum units of the underlying token that can be deposited into this contract
    ///      ie) for a underlying token with 18 decimals, MAX_UNDERLYING is 1B tokens.
    uint256 public constant MAX_UNDERLYING = 1_000_000_000e18;

    /// @dev TOTAL_BITS is a multiple of MAX_UNDERLYING so that {BITS_PER_UNDERLYING} is an integer.
    ///      Use the highest value that fits in a uint256 for max granularity.
    uint256 private constant TOTAL_BITS = MAX_UINT256 - (MAX_UINT256 % MAX_UNDERLYING);

    /// @dev Number of BITS per unit of deposit.
    uint256 private constant BITS_PER_UNDERLYING = TOTAL_BITS / MAX_UNDERLYING;

    /// @dev Number of BITS per unit of deposit * (1 USD).
    uint256 private constant PRICE_BITS = BITS_PER_UNDERLYING * (10**PRICE_DECIMALS);

    /// @dev TRUE_MAX_PRICE = maximum integer < (sqrt(4*PRICE_BITS + 1) - 1) / 2
    ///      Setting MAX_PRICE to the closest two power which is just under TRUE_MAX_PRICE.
    uint256 public constant MAX_PRICE = (2**96 - 1); // (2^96) - 1

    //--------------------------------------------------------------------------
    // Attributes

    /// @inheritdoc IButtonWrapper
    address public override underlying;

    /// @inheritdoc IButtonToken
    address public override oracle;

    /// @inheritdoc IButtonToken
    uint256 public override lastPrice;

    /// @dev Rebase counter
    uint256 _epoch;

    /// @inheritdoc IERC20Metadata
    string public override name;

    /// @inheritdoc IERC20Metadata
    string public override symbol;

    /// @dev internal balance, bits issued per account
    mapping(address => uint256) private _accountBits;

    /// @dev ERC20 allowances
    mapping(address => mapping(address => uint256)) private _allowances;

    //--------------------------------------------------------------------------
    // Modifiers
    modifier validRecipient(address to) {
        require(to != address(0x0), "ButtonToken: recipient zero address");
        require(to != address(this), "ButtonToken: recipient token address");
        _;
    }

    modifier onAfterRebase() {
        uint256 price;
        bool valid;
        (price, valid) = _queryPrice();
        if (valid) {
            _rebase(price);
        }
        _;
    }

    //--------------------------------------------------------------------------

    /// @param underlying_ The underlying ERC20 token address.
    /// @param name_ The ERC20 name.
    /// @param symbol_ The ERC20 symbol.
    /// @param oracle_ The oracle which provides the underlying token price.
    function initialize(
        address underlying_,
        string memory name_,
        string memory symbol_,
        address oracle_
    ) public override initializer {
        require(underlying_ != address(0), "ButtonToken: invalid underlying reference");

        // Initializing ownership to `msg.sender`
        __Ownable_init();
        underlying = underlying_;
        name = name_;
        symbol = symbol_;

        // MAX_UNDERLYING worth bits are 'pre-mined' to `address(0x)`
        // at the time of construction.
        //
        // During mint, bits are transferred from `address(0x)`
        // and during burn, bits are transferred back to `address(0x)`.
        //
        // No more than MAX_UNDERLYING can be deposited into the ButtonToken contract.
        _accountBits[address(0)] = TOTAL_BITS;

        updateOracle(oracle_);
    }

    //--------------------------------------------------------------------------
    // Owner only actions

    /// @inheritdoc IButtonToken
    function updateOracle(address oracle_) public override onlyOwner {
        uint256 price;
        bool valid;

        oracle = oracle_;
        (price, valid) = _queryPrice();
        require(valid, "ButtonToken: unable to fetch data from oracle");

        emit OracleUpdated(oracle);
        _rebase(price);
    }

    //--------------------------------------------------------------------------
    // ERC20 description attributes

    /// @inheritdoc IERC20Metadata
    function decimals() external view override returns (uint8) {
        return IERC20Metadata(underlying).decimals();
    }

    //--------------------------------------------------------------------------
    // ERC-20 token view methods

    /// @inheritdoc IERC20
    function totalSupply() external view override returns (uint256) {
        uint256 price;
        (price, ) = _queryPrice();
        return _bitsToAmount(_activeBits(), price);
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) external view override returns (uint256) {
        if (account == address(0)) {
            return 0;
        }
        uint256 price;
        (price, ) = _queryPrice();
        return _bitsToAmount(_accountBits[account], price);
    }

    /// @inheritdoc IRebasingERC20
    function scaledTotalSupply() external view override returns (uint256) {
        return _bitsToUAmount(_activeBits());
    }

    /// @inheritdoc IRebasingERC20
    function scaledBalanceOf(address account) external view override returns (uint256) {
        if (account == address(0)) {
            return 0;
        }
        return _bitsToUAmount(_accountBits[account]);
    }

    /// @inheritdoc IERC20
    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    //--------------------------------------------------------------------------
    // ButtonWrapper view methods

    /// @inheritdoc IButtonWrapper
    function totalUnderlying() external view override returns (uint256) {
        return _bitsToUAmount(_activeBits());
    }

    /// @inheritdoc IButtonWrapper
    function balanceOfUnderlying(address who) external view override returns (uint256) {
        if (who == address(0)) {
            return 0;
        }
        return _bitsToUAmount(_accountBits[who]);
    }

    /// @inheritdoc IButtonWrapper
    function underlyingToWrapper(uint256 uAmount) external view override returns (uint256) {
        uint256 price;
        (price, ) = _queryPrice();
        return _bitsToAmount(_uAmountToBits(uAmount), price);
    }

    /// @inheritdoc IButtonWrapper
    function wrapperToUnderlying(uint256 amount) external view override returns (uint256) {
        uint256 price;
        (price, ) = _queryPrice();
        return _bitsToUAmount(_amountToBits(amount, price));
    }

    //--------------------------------------------------------------------------
    // ERC-20 write methods

    /// @inheritdoc IERC20
    function transfer(address to, uint256 amount)
        external
        override
        validRecipient(to)
        onAfterRebase
        returns (bool)
    {
        _transfer(_msgSender(), to, _amountToBits(amount, lastPrice), amount);
        return true;
    }

    /// @inheritdoc IRebasingERC20
    function transferAll(address to)
        external
        override
        validRecipient(to)
        onAfterRebase
        returns (bool)
    {
        uint256 bits = _accountBits[_msgSender()];
        _transfer(_msgSender(), to, bits, _bitsToAmount(bits, lastPrice));
        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override validRecipient(to) onAfterRebase returns (bool) {
        if (_allowances[from][_msgSender()] != type(uint256).max) {
            _allowances[from][_msgSender()] -= amount;
            emit Approval(from, _msgSender(), _allowances[from][_msgSender()]);
        }

        _transfer(from, to, _amountToBits(amount, lastPrice), amount);
        return true;
    }

    /// @inheritdoc IRebasingERC20
    function transferAllFrom(address from, address to)
        external
        override
        validRecipient(to)
        onAfterRebase
        returns (bool)
    {
        uint256 bits = _accountBits[from];
        uint256 amount = _bitsToAmount(bits, lastPrice);

        if (_allowances[from][_msgSender()] != type(uint256).max) {
            _allowances[from][_msgSender()] -= amount;
            emit Approval(from, _msgSender(), _allowances[from][_msgSender()]);
        }

        _transfer(from, to, bits, amount);
        return true;
    }

    /// @inheritdoc IERC20
    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[_msgSender()][spender] = amount;

        emit Approval(_msgSender(), spender, amount);
        return true;
    }

    // @inheritdoc IERC20
    function increaseAllowance(address spender, uint256 addedAmount) external returns (bool) {
        _allowances[_msgSender()][spender] += addedAmount;

        emit Approval(_msgSender(), spender, _allowances[_msgSender()][spender]);
        return true;
    }

    // @inheritdoc IERC20
    function decreaseAllowance(address spender, uint256 subtractedAmount) external returns (bool) {
        if (subtractedAmount >= _allowances[_msgSender()][spender]) {
            delete _allowances[_msgSender()][spender];
        } else {
            _allowances[_msgSender()][spender] -= subtractedAmount;
        }

        emit Approval(_msgSender(), spender, _allowances[_msgSender()][spender]);
        return true;
    }

    //--------------------------------------------------------------------------
    // RebasingERC20 write methods

    /// @inheritdoc IRebasingERC20
    function rebase() external override onAfterRebase {
        return;
    }

    //--------------------------------------------------------------------------
    // ButtonWrapper write methods

    /// @inheritdoc IButtonWrapper
    function mint(uint256 amount) external override onAfterRebase returns (uint256) {
        uint256 bits = _amountToBits(amount, lastPrice);
        uint256 uAmount = _bitsToUAmount(bits);
        _deposit(_msgSender(), _msgSender(), uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function mintFor(address to, uint256 amount) external override onAfterRebase returns (uint256) {
        uint256 bits = _amountToBits(amount, lastPrice);
        uint256 uAmount = _bitsToUAmount(bits);
        _deposit(_msgSender(), to, uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function burn(uint256 amount) external override onAfterRebase returns (uint256) {
        uint256 bits = _amountToBits(amount, lastPrice);
        uint256 uAmount = _bitsToUAmount(bits);
        _withdraw(_msgSender(), _msgSender(), uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function burnTo(address to, uint256 amount) external override onAfterRebase returns (uint256) {
        uint256 bits = _amountToBits(amount, lastPrice);
        uint256 uAmount = _bitsToUAmount(bits);
        _withdraw(_msgSender(), to, uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function burnAll() external override onAfterRebase returns (uint256) {
        uint256 bits = _accountBits[_msgSender()];
        uint256 uAmount = _bitsToUAmount(bits);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), _msgSender(), uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function burnAllTo(address to) external override onAfterRebase returns (uint256) {
        uint256 bits = _accountBits[_msgSender()];
        uint256 uAmount = _bitsToUAmount(bits);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), to, uAmount, amount, bits);
        return uAmount;
    }

    /// @inheritdoc IButtonWrapper
    function deposit(uint256 uAmount) external override onAfterRebase returns (uint256) {
        uint256 bits = _uAmountToBits(uAmount);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _deposit(_msgSender(), _msgSender(), uAmount, amount, bits);
        return amount;
    }

    /// @inheritdoc IButtonWrapper
    function depositFor(address to, uint256 uAmount)
        external
        override
        onAfterRebase
        returns (uint256)
    {
        uint256 bits = _uAmountToBits(uAmount);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _deposit(_msgSender(), to, uAmount, amount, bits);
        return amount;
    }

    /// @inheritdoc IButtonWrapper
    function withdraw(uint256 uAmount) external override onAfterRebase returns (uint256) {
        uint256 bits = _uAmountToBits(uAmount);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), _msgSender(), uAmount, amount, bits);
        return amount;
    }

    /// @inheritdoc IButtonWrapper
    function withdrawTo(address to, uint256 uAmount)
        external
        override
        onAfterRebase
        returns (uint256)
    {
        uint256 bits = _uAmountToBits(uAmount);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), to, uAmount, amount, bits);
        return amount;
    }

    /// @inheritdoc IButtonWrapper
    function withdrawAll() external override onAfterRebase returns (uint256) {
        uint256 bits = _accountBits[_msgSender()];
        uint256 uAmount = _bitsToUAmount(bits);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), _msgSender(), uAmount, amount, bits);
        return amount;
    }

    /// @inheritdoc IButtonWrapper
    function withdrawAllTo(address to) external override onAfterRebase returns (uint256) {
        uint256 bits = _accountBits[_msgSender()];
        uint256 uAmount = _bitsToUAmount(bits);
        uint256 amount = _bitsToAmount(bits, lastPrice);
        _withdraw(_msgSender(), to, uAmount, amount, bits);
        return amount;
    }

    //--------------------------------------------------------------------------
    // Private methods

    /// @dev Internal method to commit deposit state.
    ///      NOTE: Expects bits, uAmount, amount to be pre-calculated.
    function _deposit(
        address from,
        address to,
        uint256 uAmount,
        uint256 amount,
        uint256 bits
    ) private {
        require(amount > 0, "ButtonToken: too few button tokens to mint");

        IERC20(underlying).safeTransferFrom(from, address(this), uAmount);

        _transfer(address(0), to, bits, amount);
    }

    /// @dev Internal method to commit withdraw state.
    ///      NOTE: Expects bits, uAmount, amount to be pre-calculated.
    function _withdraw(
        address from,
        address to,
        uint256 uAmount,
        uint256 amount,
        uint256 bits
    ) private {
        require(amount > 0, "ButtonToken: too few button tokens to burn");

        _transfer(from, address(0), bits, amount);

        IERC20(underlying).safeTransfer(to, uAmount);
    }

    /// @dev Internal method to commit transfer state.
    ///      NOTE: Expects bits/amounts to be pre-calculated.
    function _transfer(
        address from,
        address to,
        uint256 bits,
        uint256 amount
    ) private {
        _accountBits[from] -= bits;
        _accountBits[to] += bits;

        emit Transfer(from, to, amount);

        if (_accountBits[from] == 0) {
            delete _accountBits[from];
        }
    }

    /// @dev Updates the `lastPrice` and recomputes the internal scalar.
    function _rebase(uint256 price) private {
        if (price > MAX_PRICE) {
            price = MAX_PRICE;
        }

        lastPrice = price;

        _epoch++;

        emit Rebase(_epoch, price);
    }

    /// @dev Returns the active "un-mined" bits
    function _activeBits() private view returns (uint256) {
        return TOTAL_BITS - _accountBits[address(0)];
    }

    /// @dev Queries the oracle for the latest price
    ///      If fetched oracle price isn't valid returns the last price,
    ///      else returns the new price from the oracle.
    function _queryPrice() private view returns (uint256, bool) {
        uint256 newPrice;
        bool valid;
        (newPrice, valid) = IOracle(oracle).getData();

        // Note: we consider newPrice == 0 to be invalid because accounting fails with price == 0
        // For example, _bitsPerToken needs to be able to divide by price so a div/0 is caused
        return (valid && newPrice > 0 ? newPrice : lastPrice, valid && newPrice > 0);
    }

    /// @dev Convert button token amount to bits.
    function _amountToBits(uint256 amount, uint256 price) private pure returns (uint256) {
        return amount * _bitsPerToken(price);
    }

    /// @dev Convert underlying token amount to bits.
    function _uAmountToBits(uint256 uAmount) private pure returns (uint256) {
        return uAmount * BITS_PER_UNDERLYING;
    }

    /// @dev Convert bits to button token amount.
    function _bitsToAmount(uint256 bits, uint256 price) private pure returns (uint256) {
        return bits / _bitsPerToken(price);
    }

    /// @dev Convert bits to underlying token amount.
    function _bitsToUAmount(uint256 bits) private pure returns (uint256) {
        return bits / BITS_PER_UNDERLYING;
    }

    /// @dev Internal scalar to convert bits to button tokens.
    function _bitsPerToken(uint256 price) private pure returns (uint256) {
        return PRICE_BITS / price;
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

interface IOracle {
    function getData() external view returns (uint256, bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later

import "./IRebasingERC20.sol";
import "./IButtonWrapper.sol";

// Interface definition for the ButtonToken ERC20 wrapper contract
interface IButtonToken is IButtonWrapper, IRebasingERC20 {
    /// @dev The reference to the oracle which feeds in the
    ///      price of the underlying token.
    function oracle() external view returns (address);

    /// @dev Most recent price recorded from the oracle.
    function lastPrice() external view returns (uint256);

    /// @dev Update reference to the oracle contract and resets price.
    /// @param oracle_ The address of the new oracle.
    function updateOracle(address oracle_) external;

    /// @dev Log to record changes to the oracle.
    /// @param oracle The address of the new oracle.
    event OracleUpdated(address oracle);

    /// @dev Contract initializer
    function initialize(
        address underlying_,
        string memory name_,
        string memory symbol_,
        address oracle_
    ) external;
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

import "../IERC20.sol";
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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
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

// SPDX-License-Identifier: GPL-3.0-or-later

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// Interface definition for Rebasing ERC20 tokens which have a "elastic" external
// balance and "fixed" internal balance. Each user's external balance is
// represented as a product of a "scalar" and the user's internal balance.
//
// From time to time the "Rebase" event updates scaler,
// which increases/decreases all user balances proportionally.
//
// The standard ERC-20 methods are denominated in the elastic balance
//
interface IRebasingERC20 is IERC20, IERC20Metadata {
    /// @notice Returns the fixed balance of the specified address.
    /// @param who The address to query.
    function scaledBalanceOf(address who) external view returns (uint256);

    /// @notice Returns the total fixed supply.
    function scaledTotalSupply() external view returns (uint256);

    /// @notice Transfer all of the sender's balance to a specified address.
    /// @param to The address to transfer to.
    /// @return True on success, false otherwise.
    function transferAll(address to) external returns (bool);

    /// @notice Transfer all balance tokens from one address to another.
    /// @param from The address to send tokens from.
    /// @param to The address to transfer to.
    function transferAllFrom(address from, address to) external returns (bool);

    /// @notice Triggers the next rebase, if applicable.
    function rebase() external;

    /// @notice Event emitted when the balance scalar is updated.
    /// @param epoch The number of rebases since inception.
    /// @param newScalar The new scalar.
    event Rebase(uint256 indexed epoch, uint256 newScalar);
}

// SPDX-License-Identifier: GPL-3.0-or-later

// Interface definition for ButtonWrapper contract, which wraps an
// underlying ERC20 token into a new ERC20 with different characteristics.
// NOTE: "uAmount" => underlying token (wrapped) amount and
//       "amount" => wrapper token amount
interface IButtonWrapper {
    //--------------------------------------------------------------------------
    // ButtonWrapper write methods

    /// @notice Transfers underlying tokens from {msg.sender} to the contract and
    ///         mints wrapper tokens.
    /// @param amount The amount of wrapper tokens to mint.
    /// @return The amount of underlying tokens deposited.
    function mint(uint256 amount) external returns (uint256);

    /// @notice Transfers underlying tokens from {msg.sender} to the contract and
    ///         mints wrapper tokens to the specified beneficiary.
    /// @param to The beneficiary account.
    /// @param amount The amount of wrapper tokens to mint.
    /// @return The amount of underlying tokens deposited.
    function mintFor(address to, uint256 amount) external returns (uint256);

    /// @notice Burns wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @param amount The amount of wrapper tokens to burn.
    /// @return The amount of underlying tokens withdrawn.
    function burn(uint256 amount) external returns (uint256);

    /// @notice Burns wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens to the specified beneficiary.
    /// @param to The beneficiary account.
    /// @param amount The amount of wrapper tokens to burn.
    /// @return The amount of underlying tokens withdrawn.
    function burnTo(address to, uint256 amount) external returns (uint256);

    /// @notice Burns all wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @return The amount of underlying tokens withdrawn.
    function burnAll() external returns (uint256);

    /// @notice Burns all wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @param to The beneficiary account.
    /// @return The amount of underlying tokens withdrawn.
    function burnAllTo(address to) external returns (uint256);

    /// @notice Transfers underlying tokens from {msg.sender} to the contract and
    ///         mints wrapper tokens to the specified beneficiary.
    /// @param uAmount The amount of underlying tokens to deposit.
    /// @return The amount of wrapper tokens mint.
    function deposit(uint256 uAmount) external returns (uint256);

    /// @notice Transfers underlying tokens from {msg.sender} to the contract and
    ///         mints wrapper tokens to the specified beneficiary.
    /// @param to The beneficiary account.
    /// @param uAmount The amount of underlying tokens to deposit.
    /// @return The amount of wrapper tokens mint.
    function depositFor(address to, uint256 uAmount) external returns (uint256);

    /// @notice Burns wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @param uAmount The amount of underlying tokens to withdraw.
    /// @return The amount of wrapper tokens burnt.
    function withdraw(uint256 uAmount) external returns (uint256);

    /// @notice Burns wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back to the specified beneficiary.
    /// @param to The beneficiary account.
    /// @param uAmount The amount of underlying tokens to withdraw.
    /// @return The amount of wrapper tokens burnt.
    function withdrawTo(address to, uint256 uAmount) external returns (uint256);

    /// @notice Burns all wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @return The amount of wrapper tokens burnt.
    function withdrawAll() external returns (uint256);

    /// @notice Burns all wrapper tokens from {msg.sender} and transfers
    ///         the underlying tokens back.
    /// @param to The beneficiary account.
    /// @return The amount of wrapper tokens burnt.
    function withdrawAllTo(address to) external returns (uint256);

    //--------------------------------------------------------------------------
    // ButtonWrapper view methods

    /// @return The address of the underlying token.
    function underlying() external view returns (address);

    /// @return The total underlying tokens held by the wrapper contract.
    function totalUnderlying() external view returns (uint256);

    /// @param who The account address.
    /// @return The underlying token balance of the account.
    function balanceOfUnderlying(address who) external view returns (uint256);

    /// @param uAmount The amount of underlying tokens.
    /// @return The amount of wrapper tokens exchangeable.
    function underlyingToWrapper(uint256 uAmount) external view returns (uint256);

    /// @param amount The amount of wrapper tokens.
    /// @return The amount of underlying tokens exchangeable.
    function wrapperToUnderlying(uint256 amount) external view returns (uint256);
}

// SPDX-License-Identifier: MIT

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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