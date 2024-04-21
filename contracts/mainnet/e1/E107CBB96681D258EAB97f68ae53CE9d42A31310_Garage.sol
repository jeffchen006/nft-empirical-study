// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IDUST.sol";
import "./interfaces/ISweepersToken.sol";

contract Garage is Ownable, ReentrancyGuard {

    IDust private DustInterface;
    ISweepersToken private SweepersInterface;
    uint256 public dailyDust;
    uint80 public minimumStakeTime; // unix timestamp in seconds

    mapping(uint16 => bool) public StakedAndLocked; // whether or not NFT ID is staked
    mapping(uint16 => stakedNFT) public StakedNFTInfo; // tok ID to struct
    mapping(uint16 => uint8) public NFTMultiplier;
    mapping(uint8 => uint16) public multiplier;

    struct stakedNFT {
        uint16 id;
        uint80 stakedTimestamp;
        uint80 lastClaimTimestamp;
    }

     // @param minStakeTime is block timestamp in seconds
    constructor(uint80 _minStakeTime, address _dust, address _sweepers) {
        minimumStakeTime = _minStakeTime;
        dailyDust = 10*10**18;
        DustInterface = IDust(_dust);
        SweepersInterface = ISweepersToken(_sweepers);

        multiplier[0] = 15000;
        multiplier[1] = 10000;
        multiplier[2] = 10000;
        multiplier[3] = 35000;
        multiplier[4] = 20000;
        multiplier[5] = 10000;
        multiplier[6] = 10000;
        multiplier[7] = 10000;
        multiplier[8] = 10000;
        multiplier[9] = 10000;
        multiplier[10] = 10000;
        multiplier[11] = 25000;
        multiplier[12] = 10000;
        multiplier[13] = 10000;
    }

    event SweepersStaked(address indexed staker, uint16[] stakedIDs);
    event SweepersUnstaked(address indexed unstaker, uint16[] stakedIDs);
    event DustClaimed(address indexed claimer, uint256 amount);

    function setDailyDust(uint256 _dailyDust) external onlyOwner {
        dailyDust = _dailyDust;
    }
    
    function setMultipliers(
        uint16 dusty,
        uint16 bathroom,
        uint16 garage,
        uint16 vault) external onlyOwner {

            multiplier[0] = bathroom;
            multiplier[3] = dusty;
            multiplier[4] = garage;
            multiplier[11] = vault;
    }

    function setSingleMultiplier(uint8 _index, uint16 _mult) external onlyOwner {
        multiplier[_index] = _mult;
    }

    function stakeAndLock(uint16[] calldata _ids) external nonReentrant {
        uint16 length = uint16(_ids.length);
        for (uint16 i = 0; i < length; i++) {
            require(!StakedAndLocked[_ids[i]], 
            "Already Staked");
            require(msg.sender == SweepersInterface.ownerOf(_ids[i]), "Not owner of Sweeper");
            StakedAndLocked[_ids[i]] = true;
            StakedNFTInfo[_ids[i]].id = _ids[i];
            StakedNFTInfo[_ids[i]].stakedTimestamp = uint80(block.timestamp);
            StakedNFTInfo[_ids[i]].lastClaimTimestamp = uint80(block.timestamp);
            NFTMultiplier[_ids[i]] = SweepersInterface.stakeAndLock(_ids[i]);
        }
        emit SweepersStaked(msg.sender, _ids);
    }

    function claimDust(uint16[] calldata _ids) external nonReentrant {
        uint16 length = uint16(_ids.length);
        uint256 owed;
        for (uint16 i = 0; i < length; i++) {
            require(StakedAndLocked[_ids[i]], 
            "NFT is not staked");
            require(msg.sender == SweepersInterface.ownerOf(_ids[i]), "Not owner of Sweeper");
            owed += ((((block.timestamp - StakedNFTInfo[_ids[i]].lastClaimTimestamp) * dailyDust) 
            / 86400) * multiplier[NFTMultiplier[_ids[i]]]) / 10000;
            StakedNFTInfo[_ids[i]].lastClaimTimestamp = uint80(block.timestamp);
        }
        DustInterface.mint(msg.sender, owed);
        emit DustClaimed(msg.sender, owed);
    }

    function getUnclaimedDust(uint16[] calldata _ids) external view returns (uint256 owed, uint256[] memory dustPerNFTList) {
        uint16 length = uint16(_ids.length);
        uint256 tokenDustValue; // amount owed for each individual token in the calldata array
        dustPerNFTList = new uint256[](length); 
        for (uint16 i = 0; i < length; i++) {
            require(StakedAndLocked[_ids[i]], 
            "NFT is not staked");

            tokenDustValue = ((((block.timestamp - StakedNFTInfo[_ids[i]].lastClaimTimestamp) * dailyDust) 
            / 86400) * multiplier[NFTMultiplier[_ids[i]]]) / 10000;

            owed += tokenDustValue;

            dustPerNFTList[i] = tokenDustValue;
        }
        return (owed, dustPerNFTList);
    }

    function isNFTStaked(uint16 _id) external view returns (bool) {
        return StakedAndLocked[_id];
    }

    function unstake(uint16[] calldata _ids) external nonReentrant {
        uint16 length = uint16(_ids.length);
        uint256 owed;
        for (uint16 i = 0; i < length; i++) {
            require(StakedAndLocked[_ids[i]], 
            "NFT is not staked");
            require(msg.sender == SweepersInterface.ownerOf(_ids[i]), "Not owner of Sweeper");
            require(block.timestamp - StakedNFTInfo[_ids[i]].stakedTimestamp >= minimumStakeTime, 
            "Must wait min stake time");
            owed += ((((block.timestamp - StakedNFTInfo[_ids[i]].lastClaimTimestamp) * dailyDust) 
            / 86400) * multiplier[NFTMultiplier[_ids[i]]]) / 10000;
            SweepersInterface.unstakeAndUnlock(_ids[i]);
            delete StakedNFTInfo[_ids[i]];
            StakedAndLocked[_ids[i]] = false;
        }
        DustInterface.mint(msg.sender, owed);
        emit DustClaimed(msg.sender, owed);
        emit SweepersUnstaked(msg.sender, _ids);
    }
}

// SPDX-License-Identifier: MIT

/// @title Interface for SweepersToken



pragma solidity ^0.8.6;



interface ISweepersToken {
    
    function stakeAndLock(uint256 tokenId) external returns (uint8);

    function unstakeAndUnlock(uint256 tokenId) external;

    function setGarage(address _garage, bool _flag) external;

    function ownerOf(uint256 tokenId) external view returns (address);
    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IDust {

    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;  
    function burnFrom(address _from, uint256 _amount) external;
    function balanceOf(address owner) external view returns (uint);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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