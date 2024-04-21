// SPDX-License-Identifier: MIT

pragma solidity >0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract GasMovr is Ownable, Pausable {
    /* 
        Variables
    */
    mapping(uint256 => ChainData) public chainConfig;
    mapping(bytes32 => bool) public processedHashes;
    mapping(address => bool) public senders;

    struct ChainData {
        uint256 chainId;
        bool isEnabled;
    }

    /* 
        Events
    */
    event Deposit(
        address indexed destinationReceiver,
        uint256 amount,
        uint256 indexed destinationChainId
    );

    event Withdrawal(address indexed receiver, uint256 amount);

    event Donation(address sender, uint256 amount);

    event Send(address receiver, uint256 amount, bytes32 srcChainTxHash);

    event GrantSender(address sender);
    event RevokeSender(address sender);

    modifier onlySender() {
        require(senders[msg.sender], "Sender role required");
        _;
    }

    constructor() {
        _grantSenderRole(msg.sender);
    }

    receive() external payable {
        emit Donation(msg.sender, msg.value);
    }

    function depositNativeToken(uint256 destinationChainId, address _to)
        public
        payable
        whenNotPaused
    {
        require(
            chainConfig[destinationChainId].isEnabled,
            "Chain is currently disabled"
        );

        emit Deposit(_to, msg.value, destinationChainId);
    }

    function withdrawBalance(address _to, uint256 _amount) public onlyOwner {
        _withdrawBalance(_to, _amount);
    }

    function withdrawFullBalance(address _to) public onlyOwner {
        _withdrawBalance(_to, address(this).balance);
    }

    function _withdrawBalance(address _to, uint256 _amount) private {
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");

        emit Withdrawal(_to, _amount);
    }

    function setIsEnabled(uint256 chainId, bool _isEnabled)
        public
        onlyOwner
        returns (bool)
    {
        chainConfig[chainId].isEnabled = _isEnabled;
        return chainConfig[chainId].isEnabled;
    }

    function setPause() public onlyOwner returns (bool) {
        _pause();
        return paused();
    }

    function setUnPause() public onlyOwner returns (bool) {
        _unpause();
        return paused();
    }

    function addRoutes(ChainData[] calldata _routes) external onlyOwner {
        for (uint256 i = 0; i < _routes.length; i++) {
            chainConfig[_routes[i].chainId] = _routes[i];
        }
    }

    function getChainData(uint256 chainId)
        public
        view
        returns (ChainData memory)
    {
        return (chainConfig[chainId]);
    }

    function batchSendNativeToken(
        address payable[] memory receivers,
        uint256[] memory amounts,
        bytes32[] memory srcChainTxHashes,
        uint256 perUserGasAmount,
        uint256 maxLimit
    ) public onlySender {
        require(
            receivers.length == amounts.length &&
                receivers.length == srcChainTxHashes.length,
            "Input length mismatch"
        );
        uint256 gasPrice;
        assembly {
            gasPrice := gasprice()
        }

        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 _gasFees = amounts[i] > maxLimit
                ? (amounts[i] - maxLimit + (gasPrice * perUserGasAmount))
                : gasPrice * perUserGasAmount;
            _sendNativeToken(
                receivers[i],
                amounts[i],
                srcChainTxHashes[i],
                _gasFees
            );
        }
    }

    function sendNativeToken(
        address payable receiver,
        uint256 amount,
        bytes32 srcChainTxHash,
        uint256 perUserGasAmount,
        uint256 maxLimit
    ) public onlySender {
        uint256 gasPrice;
        assembly {
            gasPrice := gasprice()
        }
        uint256 _gasFees = amount > maxLimit
            ? (amount - maxLimit + (gasPrice * perUserGasAmount))
            : gasPrice * perUserGasAmount;

        _sendNativeToken(receiver, amount, srcChainTxHash, _gasFees);
    }

    function _sendNativeToken(
        address payable receiver,
        uint256 amount,
        bytes32 srcChainTxHash,
        uint256 gasFees
    ) private {
        if (processedHashes[srcChainTxHash]) return;
        processedHashes[srcChainTxHash] = true;

        uint256 sendAmount = amount - gasFees;

        emit Send(receiver, sendAmount, srcChainTxHash);

        (bool success, ) = receiver.call{value: sendAmount, gas: 5000}("");
        require(success, "Failed to send Ether");
    }

    function grantSenderRole(address sender) public onlyOwner {
        _grantSenderRole(sender);
    }

    function revokeSenderRole(address sender) public onlyOwner {
        _revokeSenderRole(sender);
    }

    function _grantSenderRole(address sender) private {
        senders[sender] = true;
        emit GrantSender(sender);
    }

    function _revokeSenderRole(address sender) private {
        senders[sender] = false;
        emit RevokeSender(sender);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.0 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/Context.sol)

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