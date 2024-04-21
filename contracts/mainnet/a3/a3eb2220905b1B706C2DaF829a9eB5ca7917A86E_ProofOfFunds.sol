// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

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
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface ILilFarmBoy {
   enum Phase {
      TEAM,
      FARMER,
      EARLY,
      WHITELIST,
      PUBLIC
   }

   struct Mint {
      uint256 price;
      uint256 maxSupply;
      uint256 maxWallet;
      uint256 totalMinted;
      uint256 phaseEnd;
      bytes32 merkleRoot;
   }

   struct Nft {
      uint256 maxSupply;
      uint256 burned;
      address treasury;
      bool sale;
      string baseUri;
   }

   struct User {
      mapping(Phase => uint256) mintCount;
      uint256 farmerPhaseAllocation;
      bool farmerPhaseMinted;
      bool earlyPhaseMinted;
      uint256 totalBurned;
   }

   function mint(address _user, uint256 _qty, bytes32[] memory _proof) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

interface IProofOfFunds {
  enum Roles {
    TEAM,
    PRODUCT,
    COMMUNITY,
    OPERATIONS
  }

  enum TransactionType {
    SIGNER,
    WITHDRAW
  }

  struct Token {
    address contractAddress;
    uint256 balance;
  }

  struct System {
    uint256 noOfSigners;
    uint256 twTransaction; // total withdraw transactions
    uint256 tsTransaction; // total signer transactions
    uint256 timeToSign;
    address[] registeredSigners;
    string[] registeredToken;
  }

  struct Signers {
    address walletAddress;
    bool allowed;
    string name;
    string kyc;
  }

  struct WithdrawTransaction {
    mapping(bool => address[]) signList;
    mapping(address => bool) hasSigned;
    uint256 amount;
    uint256 timeCreated;
    string token;
    Roles receiver;
    bool active;
  }

  struct SignerTransaction {
    mapping(bool => address[]) signList;
    mapping(address => bool) hasSigned;
    address signerAddress;
    string name;
    string kyc;
    uint256 timeCreated;
    bool active;
  }

  function depositFund(string memory _token, uint256 _amount, string memory _reason) external;
  function depositNativeFund(string memory _reaason) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import './interface/IProofOfFunds.sol';
import '../main-collection/interface/ILilFarmBoy.sol';

contract ProofOfFunds is IProofOfFunds, OwnableUpgradeable {
  System public pof;

  mapping(Roles => address) public roleAddress;
  mapping(string => Token) public tokenData;
  mapping(address => Signers) public signerData;
  mapping(uint256 => WithdrawTransaction) public withdrawTransaction;
  mapping(uint256 => SignerTransaction) public signerTransaction;

  /**
   * Events
   */
  // Funds events
  event fundsDeposited(
    address indexed depositor,
    string indexed token,
    uint256 amount,
    string indexed reason
  );
  event fundsRequested(
    address indexed requestor,
    string indexed name,
    Roles receiver,
    uint256 amount,
    string indexed reason
  );
  event fundsWithdrawn(Roles indexed receiver, uint256 amount);
  event fundRequestSigned(address indexed signer, bool isApproved);
  event fundRequestCancelled(uint256 transactionID);

  //Signer events
  event signerRequested(
    uint256 transactionID,
    address signer,
    string name,
    string kyc
  );
  event signerAdded(address signer, string name, string kyc);
  event signerRequestSigned(address signer, bool isApproved);
  event signerRequestCancelled(uint256 transactionID);

  /**
   * Modifiers
   */

  modifier onlyRegisteredSigner() {
    require(signerData[msg.sender].allowed, 'PoF :: Invalid signer');
    _;
  }

  modifier onlyAcceptedTransaction(TransactionType _transaction) {
    uint256 withdrawID = pof.twTransaction;
    uint256 signerID = pof.tsTransaction;

    if (_transaction == TransactionType.WITHDRAW) {
      require(
        withdrawTransaction[withdrawID].signList[true].length >
          (pof.noOfSigners -
            withdrawTransaction[withdrawID].signList[true].length),
        'PoF :: Not enough signers that accepted'
      );
    } else {
      require(
        signerTransaction[signerID].signList[true].length >
          (pof.noOfSigners - signerTransaction[signerID].signList[true].length),
        'PoF :: Not enough signers that accepted'
      );
    }
    _;
  }

  modifier onlyDeclinedTransaction(TransactionType _transaction) {
    uint256 withdrawID = pof.twTransaction;
    uint256 signerID = pof.tsTransaction;

    if (_transaction == TransactionType.WITHDRAW) {
      require(
        withdrawTransaction[withdrawID].signList[false].length >
          (pof.noOfSigners -
            withdrawTransaction[withdrawID].signList[false].length) ||
          block.timestamp >
          (withdrawTransaction[withdrawID].timeCreated + pof.timeToSign),
        'POF :: Not enough signers that declined'
      );
    } else {
      require(
        signerTransaction[signerID].signList[false].length >
          (pof.noOfSigners -
            signerTransaction[signerID].signList[false].length) ||
          block.timestamp >
          (signerTransaction[signerID].timeCreated + pof.timeToSign),
        'POF :: Not enough signers that declined'
      );
    }

    _;
  }

  modifier onlyOneVote(TransactionType _transaction, uint256 _transactionID) {
    if (_transaction == TransactionType.WITHDRAW) {
      require(
        !withdrawTransaction[_transactionID].hasSigned[msg.sender],
        'PoF :: You already signed.'
      );
    } else {
      require(
        !signerTransaction[_transactionID].hasSigned[msg.sender],
        'PoF :: You already signed.'
      );
    }
    _;
  }

  /**
   * Initialize
   */
  function initialize(
    address[] memory _signers,
    string[] memory _name,
    string[] memory _kyc,
    uint256 _timeToSign
  ) external initializer {
    __Ownable_init();

    for (uint256 index = 0; index < _signers.length; index++) {
      signerData[_signers[index]].walletAddress = _signers[index];
      signerData[_signers[index]].allowed = true;
      signerData[_signers[index]].name = _name[index];
      signerData[_signers[index]].kyc = _kyc[index];
      pof.registeredSigners.push(_signers[index]);

      pof.noOfSigners++;
    }

    pof.timeToSign = _timeToSign;
  }

  /**
   * Signer
   */

  function requestAddSigner(
    address _signerAddress,
    string memory _name,
    string memory _kyc
  ) external onlyRegisteredSigner {
    require(
      !signerTransaction[pof.tsTransaction].active,
      'PoF :: There is still a pending transaction'
    );

    pof.tsTransaction++;
    uint256 signerID = pof.tsTransaction;

    signerTransaction[signerID].signerAddress = _signerAddress;
    signerTransaction[signerID].name = _name;
    signerTransaction[signerID].kyc = _kyc;
    signerTransaction[signerID].timeCreated = block.timestamp;
    signerTransaction[signerID].active = true;

    emit signerRequested(signerID, _signerAddress, _name, _kyc);
  }

  function signSignerRequest(
    uint256 _transactionID,
    bool _isApprove
  )
    external
    onlyRegisteredSigner
    onlyOneVote(TransactionType.SIGNER, _transactionID)
  {
    require(
      signerTransaction[_transactionID].active,
      'PoF :: Transaction is not active'
    );

    signerTransaction[_transactionID].signList[_isApprove].push(msg.sender);
    signerTransaction[_transactionID].hasSigned[msg.sender] = true;

    emit signerRequestSigned(msg.sender, false);
  }

  function processSignerRequest(
    uint256 _transactionID
  ) external onlyRegisteredSigner {
    SignerTransaction storage signer = signerTransaction[_transactionID];

    if (checkSignerDecision(_transactionID)) {
      signerData[signer.signerAddress].walletAddress = signer.signerAddress;
      signerData[signer.signerAddress].name = signer.name;
      signerData[signer.signerAddress].kyc = signer.kyc;
      signerData[signer.signerAddress].allowed = true;
    } else {
      signerTransaction[_transactionID].active = false;
    }
  }

  /**
   * Deposit
   */

  function depositNativeFund(string memory _reason) external payable {
    tokenData['eth'].balance += msg.value;
    emit fundsDeposited(msg.sender, 'eth', msg.value, _reason);
  }

  function depositFund(
    string memory _token,
    uint256 _amount,
    string memory _reason
  ) external {
    IERC20Upgradeable token = IERC20Upgradeable(
      tokenData[_token].contractAddress
    );
    token.transferFrom(msg.sender, address(this), _amount);
    emit fundsDeposited(msg.sender, _token, _amount, _reason);
  }

  /**
   * Withdraw
   */

  function requestFundWithdraw(
    string memory _token,
    uint256 _amount,
    Roles _receiver,
    string memory _reason
  ) external onlyRegisteredSigner {
    require(
      !withdrawTransaction[pof.twTransaction].active,
      'PoF :: There is still a pending transaction'
    );
    pof.twTransaction++;

    uint256 transactionID = pof.twTransaction;
    withdrawTransaction[transactionID].amount = _amount;
    withdrawTransaction[transactionID].timeCreated = block.timestamp;
    withdrawTransaction[transactionID].token = _token;
    withdrawTransaction[transactionID].receiver = _receiver;
    withdrawTransaction[transactionID].active = true;

    emit fundsRequested(
      msg.sender,
      signerData[msg.sender].name,
      _receiver,
      _amount,
      _reason
    );
  }

  function signFundRequest(
    uint256 _transactionID,
    bool _isApprove
  ) external onlyRegisteredSigner {
    require(
      withdrawTransaction[_transactionID].active,
      'PoF :: Transaction is not active'
    );

    withdrawTransaction[_transactionID].signList[_isApprove].push(msg.sender);
    withdrawTransaction[_transactionID].hasSigned[msg.sender] = true;

    emit fundRequestSigned(msg.sender, _isApprove);
  }

  function processFundRequest(
    uint256 _transactionID
  ) external onlyRegisteredSigner {
    WithdrawTransaction storage transaction = withdrawTransaction[
      _transactionID
    ];

    if (
      keccak256(abi.encodePacked(transaction.token)) ==
      keccak256(abi.encodePacked('eth'))
    ) {
      payable(roleAddress[transaction.receiver]).transfer(transaction.amount);
      withdrawTransaction[_transactionID].active = false;
      tokenData[transaction.token].balance -= transaction.amount;
      emit fundsWithdrawn(transaction.receiver, transaction.amount);

      return;
    }

    IERC20Upgradeable token = IERC20Upgradeable(
      tokenData[transaction.token].contractAddress
    );
    token.transfer(roleAddress[transaction.receiver], transaction.amount);
    withdrawTransaction[_transactionID].active = false;

    emit fundsWithdrawn(transaction.receiver, transaction.amount);
  }

  /**
   * View Functions
   */

  function checkSignerDecision(
    uint256 _transactionID
  ) public view returns (bool) {
    if (
      signerTransaction[_transactionID].signList[false].length >
      (pof.noOfSigners -
        signerTransaction[_transactionID].signList[false].length) ||
      block.timestamp >
      (signerTransaction[_transactionID].timeCreated + pof.timeToSign)
    ) {
      return false;
    } else if (
      signerTransaction[_transactionID].signList[true].length >
      (pof.noOfSigners -
        signerTransaction[_transactionID].signList[true].length)
    ) {
      return true;
    }

    revert('PoF :: No decision yet');
  }

  function checkWithdrawDecision(
    uint256 _transactionID
  ) public view returns (bool) {
    if (
      withdrawTransaction[_transactionID].signList[false].length >
      (pof.noOfSigners -
        withdrawTransaction[_transactionID].signList[false].length) ||
      block.timestamp >
      (withdrawTransaction[_transactionID].timeCreated + pof.timeToSign)
    ) {
      return false;
    } else if (
      withdrawTransaction[_transactionID].signList[true].length >
      (pof.noOfSigners -
        withdrawTransaction[_transactionID].signList[true].length)
    ) {
      return true;
    }

    revert('PoF :: No decision yet');
  }

  /**
   * Setter Function
   */

  function setTokenAddress(
    string memory _token,
    address _address
  ) external onlyOwner {
    tokenData[_token].contractAddress = _address;
  }

  function setRoleAddress(Roles _role, address _address) external onlyOwner {
    roleAddress[_role] = _address;
  }

  /**
   * fallback
   */

  receive() external payable {
    tokenData['eth'].balance += msg.value;
  }
}