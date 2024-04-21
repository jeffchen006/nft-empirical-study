//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IPaperHands.sol";
import "./interfaces/IDiamondHandsPass.sol";

// import "hardhat/console.sol";

contract PaperHandsStaking is Initializable, OwnableUpgradeable, IERC721ReceiverUpgradeable {
    address public paperHandsContract;
    address public diamondHandsPassContract;
    uint256 public lockDuration;
    uint256 public passiveEmission;
    uint256 public activeEmission;
    uint256 public lockEmission;

    mapping(address => bool) private admins;

    struct LastUpdate {
        uint256 passive;
        uint256 active;
        uint256 lock;
    }

    struct Reward {
        uint256 passive;
        uint256 active;
        uint256 lock;
    }

    // nft staking startTime
    uint256 public startTime;

    // user => timestamp
    mapping(address => LastUpdate) public lastUpdates;

    // user => rewards
    mapping(address => Reward) public rewards;

    // user => tokenIds
    mapping(address => uint256[]) public stakedActiveTokens;
    mapping(address => uint256[]) public stakedLockTokens;
    mapping(uint256 => uint256) public stakedLockTokensTimestamps;

    uint256 public timestamp1155;
    uint256 private constant INTERVAL = 86400;

    event Stake(
        address indexed user,
        uint256[] indexed tokenIDs,
        bool indexed locked
    );
    event Withdraw(
        address indexed user,
        uint256[] indexed tokenIDs,
        bool indexed locked
    );

    function initialize(address _paperHandsContract, uint256 _startTime) public initializer {
        __Ownable_init();
        paperHandsContract = _paperHandsContract;
        startTime = _startTime;
        lockDuration = 86400 * 56;
        passiveEmission = 100 ether;
        activeEmission = 200 ether;
        lockEmission = 888 ether;
    }

    modifier multiAdmin() {
        require(admins[msg.sender] == true, "NOT_ADMIN");
        _;
    }

    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0), "INVALID_ADDRESS");
        admins[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(admins[_admin] == true, "ADMIN_NOT_SET");
        admins[_admin] = false;
    }

    function setTimestamp1155(uint256 _timestamp1155) external onlyOwner {
        timestamp1155 = _timestamp1155;
    }

    function setAddress1155(address _address1155) external onlyOwner {
        diamondHandsPassContract = _address1155;
    }

    function setPassiveEmission(uint256 _passiveEmission) external onlyOwner {
        passiveEmission = _passiveEmission;
    }

    function setActiveEmission(uint256 _activeEmission) external onlyOwner {
        activeEmission = _activeEmission;
    }

    function setLockEmission(uint256 _lockEmission) external onlyOwner {
        lockEmission = _lockEmission;
    }

    function viewPassivePendingReward(address _user)
        external
        view
        returns (uint256)
    {
        return _getPassivePendingReward(_user);
    }

    function viewActivePendingReward(address _user)
        external
        view
        returns (uint256)
    {
        return _getActivePendingReward(_user);
    }

    function viewLockPendingReward(address _user)
        external
        view
        returns (uint256)
    {
        return _getLockPendingReward(_user);
    }

    function viewAllPendingReward(address _user)
        external
        view
        returns (uint256)
    {
        return
            _getPassivePendingReward(_user) +
            _getActivePendingReward(_user) +
            _getLockPendingReward(_user);
    }

    function viewAllRewards(address _user) external view returns (uint256) {
        Reward memory _rewards = rewards[_user];
        return _rewards.passive + _rewards.active + _rewards.lock;
    }

    function viewActiveTokens(address _user) external view returns (uint256[] memory activeTokens) {
        uint256 activeArrLength = stakedActiveTokens[_user].length;
        activeTokens = new uint256[](activeArrLength);
        for (uint256 i; i < activeArrLength; i++) {
            activeTokens[i] = stakedActiveTokens[_user][i];
        }
    }

    function viewLockTokens(address _user) external view returns (uint256[] memory lockTokens) {
        uint256 lockArrLength = stakedLockTokens[_user].length;
        lockTokens = new uint256[](lockArrLength);
        for (uint256 i; i < lockArrLength; i++) {
            lockTokens[i] = stakedLockTokens[_user][i];
        }
    }

    function stakeActive(address owner, uint256[] memory tokenIds) external {
        rewards[owner].active += _getActivePendingReward(owner);
        lastUpdates[owner].active = block.timestamp;
        for (uint256 i; i < tokenIds.length; i++) {
            stakedActiveTokens[owner].push(tokenIds[i]);
        }
        IPaperHands(paperHandsContract).batchSafeTransferFrom(
            owner,
            address(this),
            tokenIds,
            ""
        );
        emit Stake(owner, tokenIds, false);
    }

    function withdrawActive() external {
        rewards[msg.sender].active += _getActivePendingReward(msg.sender);
        lastUpdates[msg.sender].active = block.timestamp;
        uint256 arrLen = stakedActiveTokens[msg.sender]
            .length;
        require(arrLen > 0, "NO_ACTIVE_STAKE");
        uint256[] memory tokenIds = new uint256[](arrLen);
        tokenIds = stakedActiveTokens[msg.sender];
        IPaperHands(paperHandsContract).batchSafeTransferFrom(
            address(this),
            msg.sender,
            tokenIds,
            ""
        );
        delete stakedActiveTokens[msg.sender];
        emit Withdraw(msg.sender, tokenIds, false);
    }

    function stakeLock(address owner, uint256[] memory tokenIds) external {
        rewards[owner].lock += _getLockPendingReward(owner);
        lastUpdates[owner].lock = block.timestamp;
        for (uint256 i; i < tokenIds.length; i++) {
            stakedLockTokens[owner].push(tokenIds[i]);
            stakedLockTokensTimestamps[tokenIds[i]] =
                ((block.timestamp + lockDuration) / 86400) *
                86400;
        }
        IPaperHands(paperHandsContract).batchSafeTransferFrom(
            owner,
            address(this),
            tokenIds,
            ""
        );
        if (block.timestamp <= timestamp1155) {
            uint256 quantity = tokenIds.length / 2;
            if (quantity > 0) {
            IDiamondHandsPass(diamondHandsPassContract).mint(owner,quantity);
            }
        }
        emit Stake(owner, tokenIds, true);
    }

    function withdrawLock() external {
        rewards[msg.sender].lock += _getLockPendingReward(msg.sender);
        lastUpdates[msg.sender].lock = block.timestamp;
        uint256[] storage _stakelockTokens = stakedLockTokens[msg.sender];
        uint256 unlockArrLength;
        uint256 lockArrLength;
        for (uint256 i; i < _stakelockTokens.length; i++) {
            block.timestamp < stakedLockTokensTimestamps[_stakelockTokens[i]]
                ? lockArrLength = lockArrLength + 1
                : unlockArrLength = unlockArrLength + 1;
        }
        require(unlockArrLength > 0, "NO_UNLOCKED");
        if (lockArrLength == 0) {
            IPaperHands(paperHandsContract).batchSafeTransferFrom(
                address(this),
                msg.sender,
                _stakelockTokens,
                ""
            );
            emit Withdraw(msg.sender, _stakelockTokens, true);
            delete stakedLockTokens[msg.sender];
        } else {
            uint256[] memory unlockedTokens = new uint256[](unlockArrLength);
            uint256[] memory lockedTokens = new uint256[](lockArrLength);
            uint256 unlockArrLengthConst = unlockArrLength;
            uint256 lockArrLengthConst = lockArrLength;
            for (uint256 i; i < _stakelockTokens.length; i++) {
                if (
                    block.timestamp <
                    stakedLockTokensTimestamps[_stakelockTokens[i]]
                ) {
                    lockedTokens[lockArrLengthConst - lockArrLength] = (
                        _stakelockTokens[i]
                    );
                    lockArrLength = lockArrLength - 1;
                } else {
                    unlockedTokens[unlockArrLengthConst - unlockArrLength] = (
                        _stakelockTokens[i]
                    );
                    unlockArrLength = unlockArrLength - 1;
                }
            }
            stakedLockTokens[msg.sender] = lockedTokens;
            IPaperHands(paperHandsContract).batchSafeTransferFrom(
                address(this),
                msg.sender,
                unlockedTokens,
                ""
            );
            emit Withdraw(msg.sender, unlockedTokens, true);
        }
    }

    function setStartTime(uint256 _timestamp) external onlyOwner {
        if (_timestamp == 0) {
            startTime = block.timestamp;
        } else {
            startTime = _timestamp;
        }
    }

    function _getPassivePendingReward(address _user)
        internal
        view
        returns (uint256)
    {
        if (_user == address(this)) {
            return 0;
        }
        return
            (IPaperHands(paperHandsContract).balanceOf(_user) *
                passiveEmission *
                (block.timestamp -
                    (
                        lastUpdates[_user].passive >= startTime
                            ? lastUpdates[_user].passive
                            : startTime
                    ))) / INTERVAL;
    }

    function _getActivePendingReward(address _user)
        internal
        view
        returns (uint256)
    {
        return
            (stakedActiveTokens[_user].length *
                activeEmission *
                (block.timestamp -
                    (
                        lastUpdates[_user].active >= startTime
                            ? lastUpdates[_user].active
                            : startTime
                    ))) / INTERVAL;
    }

    function _getLockPendingReward(address _user)
        internal
        view
        returns (uint256)
    {
        return
            (stakedLockTokens[_user].length *
                lockEmission *
                (block.timestamp -
                    (
                        lastUpdates[_user].lock >= startTime
                            ? lastUpdates[_user].lock
                            : startTime
                    ))) / INTERVAL;
    }

    function transferRewards(address _from, address _to) external multiAdmin {
        if (_from != address(0) && _from != address(this)) {
            rewards[_from].passive += _getPassivePendingReward(_from);
            lastUpdates[_from].passive = block.timestamp;
        }

        if (_to != address(0) && _to != address(this)) {
            rewards[_to].passive += _getPassivePendingReward(_to);
            lastUpdates[_to].passive = block.timestamp;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
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
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
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
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

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

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPaperHands {

    function balanceOf(address) external view returns (uint256);

    function batchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds
    ) external;
    function batchSafeTransferFrom(
        address _from,
        address _to,
        uint256[] memory _tokenIds,
        bytes memory _data
    ) external;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IDiamondHandsPass {
    function mint(address recipient, uint256 tokenId) external;
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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