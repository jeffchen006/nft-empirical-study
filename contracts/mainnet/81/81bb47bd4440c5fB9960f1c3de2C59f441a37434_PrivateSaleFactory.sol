// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "./interfaces/IPrivateSale.sol";

contract PrivateSaleFactory is Ownable {
    address public receiverAddress;
    address public devAddress;
    uint256 public devFee;

    address public implementation;

    mapping(string => IPrivateSale) public getPrivateSale;
    IPrivateSale[] public privateSales;

    event SaleCreated(
        IPrivateSale indexed privateSale,
        string indexed name,
        uint256 maxSupply,
        uint256 minAmount
    );
    event ImplementationSet(address indexed implementation);
    event ReceiverSet(address indexed receiver);
    event DevSet(address indexed devAddress);
    event DevFeeSet(uint256 devFee);
    event AddedToSale(string indexed name, address[] users);
    event RemovedFromSale(string indexed name, address[] users);
    event UserValidatedForSale(string indexed name, address[] users);

    constructor(address _receiverAddress, address _implementation) {
        require(_receiverAddress != address(0), "Factory: Receiver is 0");
        require(_implementation != address(0), "Factory: Implementation is 0");
        receiverAddress = _receiverAddress;
        devAddress = _msgSender();
        implementation = _implementation;

        devFee = 1_500;
        emit ReceiverSet(_receiverAddress);
        emit DevSet(_msgSender());
        emit DevFeeSet(devFee);
    }

    function lenPrivateSales() external view returns (uint256) {
        return privateSales.length;
    }

    function createPrivateSale(
        string calldata name,
        uint256 price,
        uint256 maxSupply,
        uint256 minAmount
    ) external onlyOwner returns (IPrivateSale) {
        require(
            getPrivateSale[name] == IPrivateSale(address(0)),
            "Factory: Sale already exists"
        );
        require(price > 0, "PrivateSale: Bad price");
        require(maxSupply > minAmount, "PrivateSale: Bad amounts");

        IPrivateSale privateSale = IPrivateSale(Clones.clone(implementation));

        getPrivateSale[name] = privateSale;
        privateSales.push(privateSale);

        IPrivateSale(privateSale).initialize(name, price, maxSupply, minAmount);

        emit SaleCreated(privateSale, name, maxSupply, minAmount);

        return privateSale;
    }

    function addToWhitelist(string calldata name, address[] calldata addresses)
        external
        onlyOwner
    {
        getPrivateSale[name].addToWhitelist(addresses);
        emit AddedToSale(name, addresses);
    }

    function removeFromWhitelist(
        string calldata name,
        address[] calldata addresses
    ) external onlyOwner {
        getPrivateSale[name].removeFromWhitelist(addresses);
        emit RemovedFromSale(name, addresses);
    }

    function validateUsers(string calldata name, address[] calldata addresses)
        external
        onlyOwner
    {
        getPrivateSale[name].validateUsers(addresses);
        emit UserValidatedForSale(name, addresses);
    }

    function claim(string calldata name) external onlyOwner {
        getPrivateSale[name].claim();
    }

    function endSale(string calldata name) external onlyOwner {
        getPrivateSale[name].endSale();
    }

    function setImplementation(address _implementation) external onlyOwner {
        require(_implementation != address(0), "Factory: implementation is 0");
        implementation = _implementation;
        emit ImplementationSet(_implementation);
    }

    function setReceiverAddress(address _receiverAddress) external onlyOwner {
        require(_receiverAddress != address(0), "Factory: Receiver is 0");
        receiverAddress = _receiverAddress;
        emit ReceiverSet(_receiverAddress);
    }

    function setDevAddress(address _devAddress) external onlyOwner {
        require(_devAddress != address(0), "Factory: Dev is 0");
        devAddress = _devAddress;
        emit DevSet(_devAddress);
    }

    function setDevFee(uint256 _devFee) external onlyOwner {
        require(_devFee <= 10_000, "Factory: Dev fee too big");
        require(_devFee >= 1_000, "Factory: Dev fee too low");
        devFee = _devFee;
        emit DevFeeSet(_devFee);
    }

    function emergencyWithdraw(string calldata name) external onlyOwner {
        getPrivateSale[name].emergencyWithdraw();
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
// OpenZeppelin Contracts v4.4.1 (proxy/Clones.sol)

pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPrivateSale {
    struct UserInfo {
        bool isWhitelisted;
        uint248 amount;
        uint248 amountBought;
        bool isComplient;
    }

    function factory() external view returns (address);

    function name() external view returns (string memory);

    function maxSupply() external view returns (uint256);

    function amountSold() external view returns (uint256);

    function minAmount() external view returns (uint256);

    function price() external view returns (uint256);

    function claimableAmount() external view returns (uint256);

    function isOver() external view returns (bool);

    function userInfo(address user) external view returns (UserInfo memory);

    function initialize(
        string calldata name,
        uint256 price,
        uint256 maxSupply,
        uint256 minAmount
    ) external;

    function participate() external payable;

    function addToWhitelist(address[] calldata addresses) external;

    function removeFromWhitelist(address[] calldata addresses) external;

    function validateUsers(address[] calldata addresses) external;

    function claim() external;

    function endSale() external;

    function emergencyWithdraw() external;
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