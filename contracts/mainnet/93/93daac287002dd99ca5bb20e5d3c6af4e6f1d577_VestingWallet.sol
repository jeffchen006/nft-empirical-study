// SPDX-License-Identifier: MIT

/*

Coded with ♥ by

██████╗░███████╗███████╗██╗  ░██╗░░░░░░░██╗░█████╗░███╗░░██╗██████╗░███████╗██████╗░██╗░░░░░░█████╗░███╗░░██╗██████╗░
██╔══██╗██╔════╝██╔════╝██║  ░██║░░██╗░░██║██╔══██╗████╗░██║██╔══██╗██╔════╝██╔══██╗██║░░░░░██╔══██╗████╗░██║██╔══██╗
██║░░██║█████╗░░█████╗░░██║  ░╚██╗████╗██╔╝██║░░██║██╔██╗██║██║░░██║█████╗░░██████╔╝██║░░░░░███████║██╔██╗██║██║░░██║
██║░░██║██╔══╝░░██╔══╝░░██║  ░░████╔═████║░██║░░██║██║╚████║██║░░██║██╔══╝░░██╔══██╗██║░░░░░██╔══██║██║╚████║██║░░██║
██████╔╝███████╗██║░░░░░██║  ░░╚██╔╝░╚██╔╝░╚█████╔╝██║░╚███║██████╔╝███████╗██║░░██║███████╗██║░░██║██║░╚███║██████╔╝
╚═════╝░╚══════╝╚═╝░░░░░╚═╝  ░░░╚═╝░░░╚═╝░░░╚════╝░╚═╝░░╚══╝╚═════╝░╚══════╝╚═╝░░╚═╝╚══════╝╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░

https://defi.sucks

*/

pragma solidity >=0.8.4 <0.9.0;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import './Governable.sol';
import './interfaces/IVestingWallet.sol';

contract VestingWallet is IVestingWallet, Governable {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  EnumerableSet.AddressSet internal _vestedTokens;
  EnumerableSet.AddressSet internal _beneficiaries;
  mapping(address => EnumerableSet.AddressSet) internal _tokensPerBeneficiary; // beneficiary => [tokens]
  /// @inheritdoc IVestingWallet
  mapping(address => uint256) public override totalAmountPerToken; // token => amount
  /// @inheritdoc IVestingWallet
  mapping(address => mapping(address => Benefit)) public override benefits; // token => beneficiary => benefit

  constructor(address _governance) Governable(_governance) {}

  // Views

  /// @inheritdoc IVestingWallet
  function releaseDate(address _token, address _beneficiary) external view override returns (uint256) {
    Benefit memory _benefit = benefits[_token][_beneficiary];

    return _benefit.startDate + _benefit.duration;
  }

  /// @inheritdoc IVestingWallet
  function releasableAmount(address _token, address _beneficiary) external view override returns (uint256) {
    Benefit memory _benefit = benefits[_token][_beneficiary];

    return _releasableSchedule(_benefit) - _benefit.released;
  }

  /// @inheritdoc IVestingWallet
  function getBeneficiaries() external view override returns (address[] memory) {
    return _beneficiaries.values();
  }

  /// @inheritdoc IVestingWallet
  function getTokens() external view override returns (address[] memory) {
    return _vestedTokens.values();
  }

  /// @inheritdoc IVestingWallet
  function getTokensOf(address _beneficiary) external view override returns (address[] memory) {
    return _tokensPerBeneficiary[_beneficiary].values();
  }

  // Methods

  /// @inheritdoc IVestingWallet
  function addBenefit(
    address _beneficiary,
    uint256 _startDate,
    uint256 _duration,
    address _token,
    uint256 _amount
  ) external override onlyGovernance {
    _addBenefit(_beneficiary, _startDate, _duration, _token, _amount);
    totalAmountPerToken[_token] += _amount;

    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
  }

  /// @inheritdoc IVestingWallet
  function addBenefits(
    address _token,
    address[] calldata __beneficiaries,
    uint256[] calldata _amounts,
    uint256 _startDate,
    uint256 _duration
  ) external override onlyGovernance {
    uint256 _length = __beneficiaries.length;
    if (_length != _amounts.length) revert WrongLengthAmounts();

    uint256 _vestedAmount;

    for (uint256 _i; _i < _length; _i++) {
      _addBenefit(__beneficiaries[_i], _startDate, _duration, _token, _amounts[_i]);
      _vestedAmount += _amounts[_i];
    }

    totalAmountPerToken[_token] += _vestedAmount;

    IERC20(_token).safeTransferFrom(msg.sender, address(this), _vestedAmount);
  }

  /// @inheritdoc IVestingWallet
  function removeBenefit(address _token, address _beneficiary) external override onlyGovernance {
    _removeBenefit(_token, _beneficiary);
  }

  /// @inheritdoc IVestingWallet
  function removeBeneficiary(address _beneficiary) external override onlyGovernance {
    while (_tokensPerBeneficiary[_beneficiary].length() > 0) {
      _removeBenefit(_tokensPerBeneficiary[_beneficiary].at(0), _beneficiary);
    }
  }

  /// @inheritdoc IVestingWallet
  function release(address _token) external override {
    _release(_token, msg.sender);
  }

  /// @inheritdoc IVestingWallet
  function release(address _token, address _beneficiary) external override {
    _release(_token, _beneficiary);
  }

  /// @inheritdoc IVestingWallet
  function release(address[] calldata _tokens) external override {
    _release(_tokens, msg.sender);
  }

  /// @inheritdoc IVestingWallet
  function release(address[] calldata _tokens, address _beneficiary) external override {
    _release(_tokens, _beneficiary);
  }

  /// @inheritdoc IVestingWallet
  function releaseAll() external override {
    _releaseAll(msg.sender);
  }

  /// @inheritdoc IVestingWallet
  function releaseAll(address _beneficiary) external override {
    _releaseAll(_beneficiary);
  }

  /// @inheritdoc IDustCollector
  function sendDust(address _token) external override onlyGovernance {
    uint256 _amount;

    _amount = IERC20(_token).balanceOf(address(this)) - totalAmountPerToken[_token];
    IERC20(_token).safeTransfer(governance, _amount);

    emit DustSent(_token, _amount, governance);
  }

  // Internal

  function _addBenefit(
    address _beneficiary,
    uint256 _startDate,
    uint256 _duration,
    address _token,
    uint256 _amount
  ) internal {
    if (_tokensPerBeneficiary[_beneficiary].contains(_token)) {
      _release(_token, _beneficiary);
    }

    _beneficiaries.add(_beneficiary);
    _vestedTokens.add(_token);
    _tokensPerBeneficiary[_beneficiary].add(_token);

    Benefit storage _benefit = benefits[_token][_beneficiary];
    _benefit.startDate = _startDate;
    _benefit.duration = _duration;

    uint256 pendingAmount = _benefit.amount - _benefit.released;
    _benefit.amount = _amount + pendingAmount;
    _benefit.released = 0;

    emit BenefitAdded(_token, _beneficiary, _benefit.amount, _startDate, _startDate + _duration);
  }

  function _release(address _token, address _beneficiary) internal {
    Benefit storage _benefit = benefits[_token][_beneficiary];

    uint256 _releasable = _releasableSchedule(_benefit) - _benefit.released;

    if (_releasable == 0) {
      return;
    }

    _benefit.released += _releasable;
    totalAmountPerToken[_token] -= _releasable;

    if (_benefit.released == _benefit.amount) {
      _deleteBenefit(_token, _beneficiary);
    }

    IERC20(_token).safeTransfer(_beneficiary, _releasable);

    emit BenefitReleased(_token, _beneficiary, _releasable);
  }

  function _release(address[] calldata _tokens, address _beneficiary) internal {
    uint256 _length = _tokens.length;
    for (uint256 _i; _i < _length; _i++) {
      _release(_tokens[_i], _beneficiary);
    }
  }

  function _releaseAll(address _beneficiary) internal {
    address[] memory _tokens = _tokensPerBeneficiary[_beneficiary].values();
    uint256 _length = _tokens.length;
    for (uint256 _i; _i < _length; _i++) {
      _release(_tokens[_i], _beneficiary);
    }
  }

  function _removeBenefit(address _token, address _beneficiary) internal {
    _release(_token, _beneficiary);

    Benefit storage _benefit = benefits[_token][_beneficiary];

    uint256 _transferToOwner = _benefit.amount - _benefit.released;

    totalAmountPerToken[_token] -= _transferToOwner;

    if (_transferToOwner != 0) {
      IERC20(_token).safeTransfer(msg.sender, _transferToOwner);
    }

    _deleteBenefit(_token, _beneficiary);

    emit BenefitRemoved(_token, _beneficiary, _transferToOwner);
  }

  function _releasableSchedule(Benefit memory _benefit) internal view returns (uint256) {
    uint256 _timestamp = block.timestamp;
    uint256 _start = _benefit.startDate;
    uint256 _duration = _benefit.duration;
    uint256 _totalAllocation = _benefit.amount;

    if (_timestamp <= _start) {
      return 0;
    } else {
      return Math.min(_totalAllocation, (_totalAllocation * (_timestamp - _start)) / _duration);
    }
  }

  function _deleteBenefit(address _token, address _beneficiary) internal {
    delete benefits[_token][_beneficiary];

    _tokensPerBeneficiary[_beneficiary].remove(_token);

    if (_tokensPerBeneficiary[_beneficiary].length() == 0) {
      _beneficiaries.remove(_beneficiary);
    }

    if (totalAmountPerToken[_token] == 0) {
      _vestedTokens.remove(_token);
    }
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
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

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import './interfaces/IGovernable.sol';

abstract contract Governable is IGovernable {
  /// @inheritdoc IGovernable
  address public override governance;

  /// @inheritdoc IGovernable
  address public override pendingGovernance;

  constructor(address _governance) {
    if (_governance == address(0)) revert NoGovernanceZeroAddress();
    governance = _governance;
  }

  /// @inheritdoc IGovernable
  function setGovernance(address _governance) external override onlyGovernance {
    pendingGovernance = _governance;
    emit GovernanceProposal(_governance);
  }

  /// @inheritdoc IGovernable
  function acceptGovernance() external override onlyPendingGovernance {
    governance = pendingGovernance;
    delete pendingGovernance;
    emit GovernanceSet(governance);
  }

  /// @notice Functions with this modifier can only be called by governance
  modifier onlyGovernance() {
    if (msg.sender != governance) revert OnlyGovernance();
    _;
  }

  /// @notice Functions with this modifier can only be called by pendingGovernance
  modifier onlyPendingGovernance() {
    if (msg.sender != pendingGovernance) revert OnlyPendingGovernance();
    _;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import './IDustCollector.sol';

/// @title VestingWallet contract
/// @notice Handles the vesting of ERC20 tokens for multiple beneficiaries
interface IVestingWallet is IDustCollector {
  // Errors

  /// @notice Throws when the length of the amounts do not match
  error WrongLengthAmounts();

  // Events

  /// @notice Emitted when a benefit is successfully added
  event BenefitAdded(address indexed token, address indexed beneficiary, uint256 amount, uint256 startDate, uint256 releaseDate);

  /// @notice Emitted when a benefit is successfully removed
  event BenefitRemoved(address indexed token, address indexed beneficiary, uint256 removedAmount);

  /// @notice Emitted when a benefit is successfully released
  event BenefitReleased(address indexed token, address indexed beneficiary, uint256 releasedAmount);

  // Structs

  /// @notice Stores benefit information by each beneficiary and token pair
  struct Benefit {
    uint256 amount; // Amount of vested token for the inputted beneficiary
    uint256 startDate; // Timestamp at which the benefit starts to take effect
    uint256 duration; // Seconds to unlock the full benefit
    uint256 released; // The amount of vested tokens already released
  }

  // Views

  /// @notice Lists users with an ongoing benefit
  /// @return _beneficiaries List of beneficiaries
  function getBeneficiaries() external view returns (address[] memory _beneficiaries);

  /// @notice Lists all the tokens that are currently vested
  /// @return _tokens List of vested tokens
  function getTokens() external view returns (address[] memory _tokens);

  /// @notice Lists the current vested tokens for the given address
  /// @param _beneficiary Address of the beneficiary
  /// @return _tokens List of vested tokens
  function getTokensOf(address _beneficiary) external view returns (address[] memory _tokens);

  /// @notice Returns the benefit data for a given token and beneficiary
  /// @param _token Address of ERC20 token to be vested
  /// @param _beneficiary Address of the beneficiary
  /// @return amount Amount of vested token for the inputted beneficiary
  /// @return startDate Timestamp at which the benefit starts to take effect
  /// @return duration Seconds to unlock the full benefit
  /// @return released The amount of vested tokens already released
  function benefits(address _token, address _beneficiary)
    external
    view
    returns (
      uint256 amount,
      uint256 startDate,
      uint256 duration,
      uint256 released
    );

  /// @notice Returns the end date of a vesting period
  /// @param _token Address of ERC20 vested token
  /// @param _beneficiary Address of the beneficiary
  /// @return _releaseDate The timestamp at which benefit will be fully released.
  function releaseDate(address _token, address _beneficiary) external view returns (uint256 _releaseDate);

  /// @notice Returns the claimable amount of a vested token for a specific beneficiary
  /// @dev If the vesting period did not end, it returns a proportional claimable amount
  /// @dev If the vesting period is over, it returns the complete vested amount
  /// @param _token Address of ERC20 token to be vested
  /// @param _beneficiary Address of the beneficiary
  /// @return _claimableAmount The amount of the vested token the beneficiary can claim at this point in time
  function releasableAmount(address _token, address _beneficiary) external view returns (uint256 _claimableAmount);

  /// @notice Returns the total amount of the given vested token across all beneficiaries
  /// @param _token Address of ERC20 token to be vested
  /// @return _totalAmount The total amount of requested tokens
  function totalAmountPerToken(address _token) external view returns (uint256 _totalAmount);

  // Methods

  /// @notice Creates a vest for a given beneficiary.
  /// @dev It will claim all previous benefits.
  /// @param _beneficiary Address of the beneficiary
  /// @param _startDate Timestamp at which the benefit starts to take effect
  /// @param _duration Seconds to unlock the full benefit
  /// @param _token Address of ERC20 token to be vested
  /// @param _amount Amount of vested token for the inputted beneficiary
  function addBenefit(
    address _beneficiary,
    uint256 _startDate,
    uint256 _duration,
    address _token,
    uint256 _amount
  ) external;

  /// @notice Creates benefits for a group of beneficiaries
  /// @param _token Address of ERC20 token to be vested
  /// @param _beneficiaries Addresses of the beneficiaries
  /// @param _amounts Amounts of vested token for each beneficiary
  /// @param _startDate Timestamp at which the benefit starts to take effect
  /// @param _duration Seconds to unlock the full benefit
  function addBenefits(
    address _token,
    address[] memory _beneficiaries,
    uint256[] memory _amounts,
    uint256 _startDate,
    uint256 _duration
  ) external;

  /// @notice Removes a given benefit
  /// @notice Releases the claimable balance and transfers the pending benefit to governance
  /// @param _token Address of ERC20 token to be vested
  /// @param _beneficiary Address of the beneficiary
  function removeBenefit(address _token, address _beneficiary) external;

  /// @notice Removes all benefits from a given beneficiary
  /// @notice Releases the claimable balances and transfers the pending benefits to governance
  /// @param _beneficiary Address of the beneficiary
  function removeBeneficiary(address _beneficiary) external;

  /// @notice Releases a token in its correspondent amount to the function caller
  /// @param _token Address of ERC20 token to be vested
  function release(address _token) external;

  /// @notice Releases a token in its correspondent amount to a particular beneficiary
  /// @param _token Address of ERC20 token to be vested
  /// @param _beneficiary Address of the beneficiary
  function release(address _token, address _beneficiary) external;

  /// @notice Releases a list of tokens in their correspondent amounts to the function caller
  /// @param _tokens List of ERC20 token to be vested
  function release(address[] memory _tokens) external;

  /// @notice Releases a list of tokens in their correspondent amounts to a particular beneficiary
  /// @param _tokens List of ERC20 token to be vested
  /// @param _beneficiary Address of the beneficiary
  function release(address[] memory _tokens, address _beneficiary) external;

  /// @notice Releases all tokens in their correspondent amounts to the function caller
  function releaseAll() external;

  /// @notice Releases all tokens in their correspondent amounts to a particular beneficiary
  /// @param _beneficiary Address of the beneficiary
  function releaseAll(address _beneficiary) external;
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
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
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
pragma solidity >=0.8.4 <0.9.0;

/// @title Governable contract
/// @notice Manages the governance role
interface IGovernable {
  // Events

  /// @notice Emitted when pendingGovernance accepts to be governance
  /// @param _governance Address of the new governance
  event GovernanceSet(address _governance);

  /// @notice Emitted when a new governance is proposed
  /// @param _pendingGovernance Address that is proposed to be the new governance
  event GovernanceProposal(address _pendingGovernance);

  // Errors

  /// @notice Throws if the caller of the function is not governance
  error OnlyGovernance();

  /// @notice Throws if the caller of the function is not pendingGovernance
  error OnlyPendingGovernance();

  /// @notice Throws if trying to set governance to zero address
  error NoGovernanceZeroAddress();

  // Variables

  /// @notice Stores the governance address
  /// @return _governance The governance addresss
  function governance() external view returns (address _governance);

  /// @notice Stores the pendingGovernance address
  /// @return _pendingGovernance The pendingGovernance addresss
  function pendingGovernance() external view returns (address _pendingGovernance);

  // Methods

  /// @notice Proposes a new address to be governance
  /// @param _governance The address of the user proposed to be the new governance
  function setGovernance(address _governance) external;

  /// @notice Changes the governance from the current governance to the previously proposed address
  function acceptGovernance() external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

import './IBaseErrors.sol';

interface IDustCollector is IBaseErrors {
  /// @notice Emitted when dust is sent
  /// @param _to The address which wil received the funds
  /// @param _token The token that will be transferred
  /// @param _amount The amount of the token that will be transferred
  event DustSent(address _token, uint256 _amount, address _to);

  /// @notice Allows an authorized user to transfer the tokens or eth that may have been left in a contract
  /// @param _token The token that will be transferred
  function sendDust(address _token) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.4 <0.9.0;

interface IBaseErrors {
  /// @notice Throws if a variable is assigned to the zero address
  error ZeroAddress();
}