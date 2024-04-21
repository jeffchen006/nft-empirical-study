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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
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
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/INFT.sol";
import "../interfaces/IMarketplace.sol";
import "../interfaces/ISaleToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Marketplace is Ownable, IMarketplace, ReentrancyGuard {
    event KangaPOSAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event NFTSTypeForSaleDataUpdated(
        string membershipType,
        uint256 quantity,
        bool isEnabled,
        uint256 price,
        uint256 validity
    );

    event NFTSold(
        address indexed to,
        uint256 nftId,
        string membershipType,
        uint256 membershipTypeSerialId,
        uint256 price
    );

    event BETokenBought(address indexed to, uint256 tokenAmount, uint256 exchangedTokenAmount);

    struct NFTTypeSaleData {
        uint256 quantity;
        bool isEnabled;
        uint256 price;
        uint256 validity;
    }

    mapping(string => NFTTypeSaleData) public nftsSaleDataByType;

    uint256 private constant _INITIAL_BE_PRICE = 1 ether;
    uint256 public constant MARKETPLACE_SALE_UNLOCK_TIME = 1670922000;

    INFT private _nftContract;
    ISaleToken private _tokenContract;
    IERC20 private _usdtContract;
    address private _kangaPOS;

    modifier marketplaceSaleGuard() {
        require(block.timestamp >= MARKETPLACE_SALE_UNLOCK_TIME, "Marketplace: The sale is not unlocked yet");
        _;
    }

    constructor(
        address beTokenAddress,
        address nftContract,
        address usdtTokenAddress
    ) {
        _nftContract = INFT(nftContract);
        _tokenContract = ISaleToken(beTokenAddress);
        _usdtContract = IERC20(usdtTokenAddress);
    }

    function renounceOwnership() public view override onlyOwner {
        revert("Token: ownership renounce not allowed");
    }

    function setKangaPOSAddress(address kangaPOS) external onlyOwner {
        address previousAddress = _kangaPOS;

        _kangaPOS = kangaPOS;

        emit KangaPOSAddressUpdated(previousAddress, kangaPOS);
    }

    function remainingTokenSupply() external view returns (uint256) {
        return _tokenContract.balanceOf(address(this));
    }

    function buyToken(uint256 amount) external nonReentrant marketplaceSaleGuard {
        require(_tokenContract.balanceOf(address(this)) >= amount, "Marketplace: Not enough token supply for the sale");

        address caller = _msgSender();
        uint256 exchangedAmount = _beTokensPriceInUSDT(amount);

        _usdtContract.transferFrom(caller, owner(), exchangedAmount);
        _tokenContract.transfer(caller, amount);

        emit BETokenBought(caller, amount, exchangedAmount);
    }

    function upsertNFTSaleTypeData(
        string memory membershipType,
        uint256 quantity,
        bool isEnabled,
        uint256 price,
        uint256 validity
    ) external onlyOwner {
        require(validity == 0 || validity >= 1 hours, "Marketplace: NFT validity should be at least 1 hour");

        nftsSaleDataByType[membershipType] = NFTTypeSaleData({
            quantity: quantity,
            isEnabled: isEnabled,
            price: price,
            validity: validity
        });

        emit NFTSTypeForSaleDataUpdated(membershipType, quantity, isEnabled, price, validity);
    }

    function _remainingNFTSupplyByType(string memory membershipType) internal view returns (uint256) {
        uint256 soldNfts = _nftContract.soldNftsByDataType(membershipType);
        uint256 nftSupply = nftsSaleDataByType[membershipType].quantity;

        if (nftSupply >= soldNfts) {
            return nftSupply - soldNfts;
        } else {
            return 0;
        }
    }

    function remainingNFTSupplyByType(string memory membershipType) external view returns (uint256) {
        if (nftsSaleDataByType[membershipType].isEnabled) {
            return _remainingNFTSupplyByType(membershipType);
        } else {
            return 0;
        }
    }

    function _beTokenPrice() internal view returns (uint256) {
        uint256 currentRound = _tokenContract.currentRound();

        if (currentRound <= 1) {
            return _INITIAL_BE_PRICE;
        }

        return (_INITIAL_BE_PRICE * (105**(currentRound - 1))) / (100**(currentRound - 1));
    }

    function _beTokensPriceInUSDT(uint256 amount) internal view returns (uint256) {
        return SafeMath.div(SafeMath.mul(amount, _beTokenPrice()), 1 ether);
    }

    function beTokensPriceInUSDT(uint256 amount) external view returns (uint256) {
        return _beTokensPriceInUSDT(amount);
    }

    function buyNFT(string memory membershipType) external nonReentrant marketplaceSaleGuard {
        require(_kangaPOS != address(0), "Marketplace: kangaPOS has to be set before lunching the NFT sale");
        require(
            nftsSaleDataByType[membershipType].isEnabled,
            "Marketplace: specified membership type NFT is not for sale"
        );
        require(
            _remainingNFTSupplyByType(membershipType) > 0,
            "Marketplace: no NFT supply for specified membership type"
        );

        address caller = _msgSender();
        NFTTypeSaleData memory dataType = nftsSaleDataByType[membershipType];

        uint256 nftPrice = dataType.price;
        uint256 burnableAmount = SafeMath.div(SafeMath.mul(nftPrice, 19), 20);
        uint256 posReward = nftPrice - burnableAmount;

        /**
         * First burn the 95% of the amount and transfer rest to contract address
         */
        _tokenContract.burnFrom(caller, burnableAmount);

        /**
         * Transfer reward with allowance to kangaPOS
         */
        _tokenContract.transferFrom(caller, _kangaPOS, posReward);

        /**
         * Mint a NFT to an address and store the change
         */
        (uint256 nftId, uint256 membershipTypeSerialId) = _nftContract.mintNFT(
            caller,
            membershipType,
            dataType.validity
        );

        emit NFTSold(caller, nftId, membershipType, membershipTypeSerialId, nftPrice);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IMarketplace {
    function buyToken(uint256 amount) external;

    function buyNFT(string memory membershipType) external;

    function setKangaPOSAddress(address kangaPOSAddress) external;

    function upsertNFTSaleTypeData(
        string memory membershipType,
        uint256 quantity,
        bool isEnabled,
        uint256 price,
        uint256 validity
    ) external;

    function remainingTokenSupply() external view returns (uint256);

    function remainingNFTSupplyByType(string memory membershipType) external view returns (uint256);

    function beTokensPriceInUSDT(uint256 amount) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface INFT {
    function mintNFT(
        address to,
        string memory membershipType,
        uint256 validity
    ) external returns (uint256, uint256);

    function soldNftsByDataType(string memory membershipType) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISaleToken is IERC20 {
    function currentRound() external view returns (uint256);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function burnFrom(address account, uint256 amount) external;
}