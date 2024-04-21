// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IVLandDAO {

    function snapshot() external returns (uint256);

    function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);

}

contract PoolDistributor is Ownable {

    IVLandDAO immutable public vLand;
    uint256 public lastDistribution;

    struct DistributionData {
        uint256 snapshotId;
        uint256 amount;
    }

    mapping(uint256 => DistributionData) public distributions;
    mapping(address => uint256) public distributed;
    mapping(address => bool) public managers;

    constructor(address vLand_) {
        vLand = IVLandDAO(vLand_);
    }

    modifier onlyManager() {
        require(managers[msg.sender], "Distributor: caller is not a manager");
        _;
    }

    function addManager(address manager_) external onlyOwner {
        require(manager_ != address(0), "Distributor: manager address can not be null");
        managers[manager_] = true;
    }

    function snapshot() public onlyManager returns (uint256) {
        return vLand.snapshot();
    }

    function receiveFee(uint256 snapshotId) external payable onlyManager {
        lastDistribution++;
        distributions[lastDistribution] = DistributionData(snapshotId, msg.value);
    }

    function claimableAmount(address account) public view returns (uint256) {
        uint256 accountLastDistributed = distributed[account];
        uint256 claimable;
        for (uint256 i = accountLastDistributed + 1; i <= lastDistribution; i++) {
            DistributionData memory distributionData = distributions[i];
            uint256 snapshotId = distributionData.snapshotId;
            uint256 balance = vLand.balanceOfAt(account, snapshotId);
            if (balance > 0) {
                uint256 totalSupply = vLand.totalSupplyAt(snapshotId);
                claimable += (distributionData.amount * balance) / totalSupply;
            }
        }
        return claimable;
    }

    function claim() external {
        uint256 claimable = claimableAmount(msg.sender);
        require(claimable > 0, "Distributor: nothing to claim");
        distributed[msg.sender] = lastDistribution;
        (bool success,) = payable(msg.sender).call{value : claimable}("");
        require(success, "Distributor: unsuccessful payment");
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