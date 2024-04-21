/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './lib/SafeERC20.sol';
import './interfaces/ERC20FeeProxy.sol';

/**
 * @title   ERC20EscrowToPay
 * @notice  Request Invoice with Escrow.
 */
contract ERC20EscrowToPay is Ownable {
  using SafeERC20 for IERC20;

  IERC20FeeProxy public paymentProxy;

  struct Request {
    address tokenAddress;
    address payee;
    address payer;
    uint256 amount;
    uint256 unlockDate;
    uint256 emergencyClaimDate;
    bool emergencyState;
    bool isFrozen;
  }

  /**
   * @notice Mapping is used to store the Requests in escrow.
   */
  mapping(bytes => Request) public requestMapping;

  /**
   * @notice Duration of emergency claim period that payee can initiate.
   *         The payer can reverse this claim within this period.
   */
  uint256 public emergencyClaimPeriod = 24 weeks;

  /**
   * @notice Duration of Escrow freeze period that payer can initiate.
   *         This lock is irreversable, once the funds are frozen, payer must wait for the whole period.
   */
  uint256 public frozenPeriod = 52 weeks;

  /**
   * @notice Modifier checks if msg.sender is the requestpayment payer.
   * @param _paymentRef Reference of the requestpayment related.
   * @dev It requires msg.sender to be equal to requestMapping[_paymentRef].payer.
   */
  modifier OnlyPayer(bytes memory _paymentRef) {
    require(msg.sender == requestMapping[_paymentRef].payer, 'Not Authorized.');
    _;
  }

  /**
   * @notice Modifier checks if msg.sender is the requestpayment payee.
   * @param _paymentRef Reference of the requestpayment related.
   * @dev It requires msg.sender to be equal to requestMapping[_paymentRef].payee.
   */
  modifier OnlyPayee(bytes memory _paymentRef) {
    require(msg.sender == requestMapping[_paymentRef].payee, 'Not Authorized.');
    _;
  }

  /**
   * @notice Modifier checks that the request is not already is in escrow.
   * @param _paymentRef Reference of the payment related.
   * @dev It requires the requestMapping[_paymentRef].amount to be zero.
   */
  modifier IsNotInEscrow(bytes memory _paymentRef) {
    require(requestMapping[_paymentRef].amount == 0, 'Already in Escrow.');
    _;
  }

  /**
   * @notice Modifier checks if the request already is in escrow.
   * @param _paymentRef Reference of the payment related.
   * @dev It requires the requestMapping[_paymentRef].amount to have a value above zero.
   */
  modifier IsInEscrow(bytes memory _paymentRef) {
    require(requestMapping[_paymentRef].amount > 0, 'Not in escrow.');
    _;
  }

  /**
   * @notice Modifier checks if the request already is in emergencyState.
   * @param _paymentRef Reference of the payment related.
   * @dev It requires the requestMapping[_paymentRef].emergencyState to be false.
   */
  modifier IsNotInEmergencyState(bytes memory _paymentRef) {
    require(!requestMapping[_paymentRef].emergencyState, 'In emergencyState');
    _;
  }

  /**
   * @notice Modifier checks that the request is not frozen.
   * @param _paymentRef Reference of the payment related.
   * @dev It requires the requestMapping[_paymentRef].isFrozen to be false.
   */
  modifier IsNotFrozen(bytes memory _paymentRef) {
    require(!requestMapping[_paymentRef].isFrozen, 'Request Frozen!');
    _;
  }

  /**
   * @notice Emitted when a request has been frozen.
   * @param paymentReference Reference of the payment related.
   */
  event RequestFrozen(bytes indexed paymentReference);

  /**
   * @notice Emitted when an emergency claim is initiated by payee.
   * @param paymentReference Reference of the payment related.
   */
  event InitiatedEmergencyClaim(bytes indexed paymentReference);

  /**
   * @notice Emitted when an emergency claim has been reverted by payer.
   * @param paymentReference Reference of the payment related.
   */
  event RevertedEmergencyClaim(bytes indexed paymentReference);

  /**
   * @notice Emitted when transaction to and from the escrow has been executed.
   * @param tokenAddress Address of the ERC20 token smart contract.
   * @param to Address to the payment issuer, alias payee.
   * @param amount Amount transfered.
   * @param paymentReference Reference of the payment related.
   * @param feeAmount Set to zero when emited by _withdraw function.
   * @param feeAddress Set to address(0) when emited by _withdraw function.
   */
  event TransferWithReferenceAndFee(
    address tokenAddress,
    address to,
    uint256 amount,
    bytes indexed paymentReference,
    uint256 feeAmount,
    address feeAddress
  );

  constructor(address _paymentProxyAddress, address _admin) {
    paymentProxy = IERC20FeeProxy(_paymentProxyAddress);
    transferOwnership(_admin);
  }

  /**
   * @notice receive function reverts and returns the funds to the sender.
   */
  receive() external payable {
    revert('not payable receive');
  }

  function setEmergencyClaimPeriod(uint256 _emergencyClaimPeriod) external onlyOwner {
    emergencyClaimPeriod = _emergencyClaimPeriod;
  }

  function setFrozenPeriod(uint256 _frozenPeriod) external onlyOwner {
    frozenPeriod = _frozenPeriod;
  }

  /**
   * @notice Stores the invoice details, and transfers funds to this Escrow contract.
   * @param _tokenAddress Address of the ERC20 token smart contract.
   * @param _to Address to the payment issuer, alias payee.
   * @param _amount Amount to transfer.
   * @param _paymentRef Reference of the payment related.
   * @param _feeAmount Amount of fee to be paid.
   * @param _feeAddress Address to where the fees will be paid.
   * @dev Uses modifier IsNotInEscrow.
   * @dev Uses transferFromWithReferenceAndFee() to transfer funds from the msg.sender,
   * into the escrowcontract and pays the _fees to the _feeAdress.
   * @dev Emits RequestInEscrow(_paymentRef) when the funds are in escrow.
   */
  function payEscrow(
    address _tokenAddress,
    address _to,
    uint256 _amount,
    bytes memory _paymentRef,
    uint256 _feeAmount,
    address _feeAddress
  ) external IsNotInEscrow(_paymentRef) {
    if (_amount == 0 || _feeAmount == 0) revert('Zero Value');

    requestMapping[_paymentRef] = Request(
      _tokenAddress,
      _to,
      msg.sender,
      _amount,
      0,
      0,
      false,
      false
    );

    (bool status, ) = address(paymentProxy).delegatecall(
      abi.encodeWithSignature(
        'transferFromWithReferenceAndFee(address,address,uint256,bytes,uint256,address)',
        _tokenAddress,
        address(this),
        _amount,
        _paymentRef,
        _feeAmount,
        _feeAddress
      )
    );
    require(status, 'transferFromWithReferenceAndFee failed');
  }

  /**
   * @notice Locks the request funds for the payer to recover them
   *         after 12 months and cancel any emergency claim.
   * @param _paymentRef Reference of the Invoice related.
   * @dev Uses modifiers OnlyPayer, IsInEscrow and IsNotFrozen.
   * @dev unlockDate is set with block.timestamp + twelve months..
   */
  function freezeRequest(bytes memory _paymentRef)
    external
    OnlyPayer(_paymentRef)
    IsInEscrow(_paymentRef)
    IsNotFrozen(_paymentRef)
  {
    if (requestMapping[_paymentRef].emergencyState) {
      requestMapping[_paymentRef].emergencyState = false;
      requestMapping[_paymentRef].emergencyClaimDate = 0;
      emit RevertedEmergencyClaim(_paymentRef);
    }

    requestMapping[_paymentRef].isFrozen = true;
    requestMapping[_paymentRef].unlockDate = block.timestamp + frozenPeriod;

    emit RequestFrozen(_paymentRef);
  }

  /**
   * @notice Closes an open escrow and pays the request to payee.
   * @param _paymentRef Reference of the related Invoice.
   * @dev Uses OnlyPayer, IsInEscrow, IsNotInEmergencyState and IsNotFrozen.
   */
  function payRequestFromEscrow(bytes memory _paymentRef)
    external
    OnlyPayer(_paymentRef)
    IsInEscrow(_paymentRef)
    IsNotInEmergencyState(_paymentRef)
    IsNotFrozen(_paymentRef)
  {
    require(_withdraw(_paymentRef, requestMapping[_paymentRef].payee), 'Withdraw Failed!');
  }

  /**
   * @notice Allows the payee to initiate an emergency claim after a six months lockperiod .
   * @param _paymentRef Reference of the related Invoice.
   * @dev Uses modifiers OnlyPayee, IsInEscrow, IsNotInEmergencyState and IsNotFrozen.
   */
  function initiateEmergencyClaim(bytes memory _paymentRef)
    external
    OnlyPayee(_paymentRef)
    IsInEscrow(_paymentRef)
    IsNotInEmergencyState(_paymentRef)
    IsNotFrozen(_paymentRef)
  {
    requestMapping[_paymentRef].emergencyClaimDate = block.timestamp + emergencyClaimPeriod;
    requestMapping[_paymentRef].emergencyState = true;

    emit InitiatedEmergencyClaim(_paymentRef);
  }

  /**
   * @notice Allows the payee claim funds after a six months emergency lockperiod .
   * @param _paymentRef Reference of the related Invoice.
   * @dev Uses modifiers OnlyPayee, IsInEscrow and IsNotFrozen.
   */
  function completeEmergencyClaim(bytes memory _paymentRef)
    external
    OnlyPayee(_paymentRef)
    IsInEscrow(_paymentRef)
    IsNotFrozen(_paymentRef)
  {
    require(
      requestMapping[_paymentRef].emergencyState &&
        requestMapping[_paymentRef].emergencyClaimDate <= block.timestamp,
      'Not yet!'
    );

    requestMapping[_paymentRef].emergencyState = false;
    requestMapping[_paymentRef].emergencyClaimDate = 0;

    require(_withdraw(_paymentRef, requestMapping[_paymentRef].payee), 'Withdraw failed!');
  }

  /**
   * @notice Reverts the emergencyState to false and cancels emergencyClaim.
   * @param _paymentRef Reference of the Invoice related.
   * @dev Uses modifiers OnlyPayer, IsInEscrow and IsNotFrozen.
   * @dev Resets emergencyState to false and emergencyClaimDate to zero.
   */
  function revertEmergencyClaim(bytes memory _paymentRef)
    external
    OnlyPayer(_paymentRef)
    IsInEscrow(_paymentRef)
    IsNotFrozen(_paymentRef)
  {
    require(requestMapping[_paymentRef].emergencyState, 'EmergencyClaim NOT initiated');
    requestMapping[_paymentRef].emergencyState = false;
    requestMapping[_paymentRef].emergencyClaimDate = 0;

    emit RevertedEmergencyClaim(_paymentRef);
  }

  /**
   * @notice Refunds to payer after twelve months and delete the escrow.
   * @param  _paymentRef Reference of the Invoice related.
   * @dev requires that the request .isFrozen = true and .unlockDate to
   *      be lower or equal to block.timestamp.
   */
  function refundFrozenFunds(bytes memory _paymentRef)
    external
    IsInEscrow(_paymentRef)
    IsNotInEmergencyState(_paymentRef)
  {
    require(requestMapping[_paymentRef].isFrozen, 'Not frozen!');
    require(requestMapping[_paymentRef].unlockDate <= block.timestamp, 'Not Yet!');

    requestMapping[_paymentRef].isFrozen = false;

    require(_withdraw(_paymentRef, requestMapping[_paymentRef].payer), 'Withdraw Failed!');
  }

  /**
   * @notice Withdraw the funds from the escrow.
   * @param _paymentRef Reference of the related Invoice.
   * @param _receiver Receiving address.
   * @dev Internal function to withdraw funds from escrow, to a given reciever.
   * @dev Emits TransferWithReferenceAndFee() when payee is the _receiver.
   * @dev Asserts .amount, .isFrozen and .emergencyState are reset before deleted.
   */
  function _withdraw(bytes memory _paymentRef, address _receiver)
    internal
    IsInEscrow(_paymentRef)
    IsNotInEmergencyState(_paymentRef)
    IsNotFrozen(_paymentRef)
    returns (bool result)
  {
    require(_receiver != address(0), 'ZERO adddress');
    require(requestMapping[_paymentRef].amount > 0, 'ZERO Amount');

    IERC20 requestedToken = IERC20(requestMapping[_paymentRef].tokenAddress);

    uint256 _amount = requestMapping[_paymentRef].amount;
    requestMapping[_paymentRef].amount = 0;

    // Checks if the requestedToken is allowed to spend.
    if (requestedToken.allowance(address(this), address(paymentProxy)) < _amount) {
      approvePaymentProxyToSpend(address(requestedToken));
    }

    paymentProxy.transferFromWithReferenceAndFee(
      address(requestedToken),
      _receiver,
      _amount,
      _paymentRef,
      0,
      address(0)
    );

    assert(requestMapping[_paymentRef].amount == 0);
    assert(!requestMapping[_paymentRef].isFrozen);
    assert(!requestMapping[_paymentRef].emergencyState);

    delete requestMapping[_paymentRef];

    return true;
  }

  /**
   * @notice Authorizes the proxy to spend a new request currency (ERC20).
   * @param _erc20Address Address of an ERC20 used as the request currency.
   */
  function approvePaymentProxyToSpend(address _erc20Address) public {
    IERC20 erc20 = IERC20(_erc20Address);
    uint256 max = 2**256 - 1;
    erc20.safeApprove(address(paymentProxy), max);
  }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

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

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

/**
 * @title SafeERC20
 * @notice Works around implementations of ERC20 with transferFrom not returning success status.
 */
library SafeERC20 {
  /**
   * @notice Call transferFrom ERC20 function and validates the return data of a ERC20 contract call.
   * @dev This is necessary because of non-standard ERC20 tokens that don't have a return value.
   * @return result The return value of the ERC20 call, returning true for non-standard tokens
   */
  function safeTransferFrom(
    IERC20 _token,
    address _from,
    address _to,
    uint256 _amount
  ) internal returns (bool result) {
    // solium-disable-next-line security/no-low-level-calls
    (bool success, bytes memory data) = address(_token).call(
      abi.encodeWithSignature('transferFrom(address,address,uint256)', _from, _to, _amount)
    );

    return success && (data.length == 0 || abi.decode(data, (bool)));
  }

  /**
   * @notice Call approve ERC20 function and validates the return data of a ERC20 contract call.
   * @dev This is necessary because of non-standard ERC20 tokens that don't have a return value.
   * @return result The return value of the ERC20 call, returning true for non-standard tokens
   */
  function safeApprove(
    IERC20 _token,
    address _spender,
    uint256 _amount
  ) internal returns (bool result) {
    // solium-disable-next-line security/no-low-level-calls
    (bool success, bytes memory data) = address(_token).call(
      abi.encodeWithSignature('approve(address,uint256)', _spender, _amount)
    );

    return success && (data.length == 0 || abi.decode(data, (bool)));
  }

  /**
   * @notice Call transfer ERC20 function and validates the return data of a ERC20 contract call.
   * @dev This is necessary because of non-standard ERC20 tokens that don't have a return value.
   * @return result The return value of the ERC20 call, returning true for non-standard tokens
   */
  function safeTransfer(
    IERC20 _token,
    address _to,
    uint256 _amount
  ) internal returns (bool result) {
    // solium-disable-next-line security/no-low-level-calls
    (bool success, bytes memory data) = address(_token).call(
      abi.encodeWithSignature('transfer(address,uint256)', _to, _amount)
    );

    return success && (data.length == 0 || abi.decode(data, (bool)));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20FeeProxy {
  event TransferWithReferenceAndFee(
    address tokenAddress,
    address to,
    uint256 amount,
    bytes indexed paymentReference,
    uint256 feeAmount,
    address feeAddress
  );

  function transferFromWithReferenceAndFee(
    address _tokenAddress,
    address _to,
    uint256 _amount,
    bytes calldata _paymentReference,
    uint256 _feeAmount,
    address _feeAddress
  ) external;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

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