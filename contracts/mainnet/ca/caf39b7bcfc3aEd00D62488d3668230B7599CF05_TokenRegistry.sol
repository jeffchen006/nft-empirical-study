// SPDX-License-Identifier: LGPL-3.0-or-later
pragma solidity 0.7.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ITokenRegistry.sol";

/**
 * @title Contract for managing maximum allowed funds to be escrowed.
 * The purpose is to limit the total funds locked in escrow in the initial stages of the protocol.
 */

contract TokenRegistry is Ownable, ITokenRegistry {
    uint256 private ethLimit;
    mapping(address => uint256) private tokenLimits;
    mapping(address => address) private tokenWrappers;

    event LogETHLimitChanged(uint256 _newLimit, address indexed _triggeredBy);
    event LogTokenLimitChanged(uint256 _newLimit, address indexed _triggeredBy);
    event LogTokenWrapperChanged(address indexed _newWrapperAddress, address indexed _triggeredBy);

    modifier notZeroAddress(address _tokenAddress) {
        require(_tokenAddress != address(0), "INVALID_TOKEN_ADDRESS");
        _;
    }

    constructor() {
        ethLimit = 1 ether;
        emit LogETHLimitChanged(ethLimit, msg.sender);
    }

    /**
     * @notice Set new limit for ETH. It's used while seller tries to create a voucher. The limit is determined by a voucher set. Voucher price * quantity, seller deposit * quantity, buyer deposit * qty must be below the limit.
     * @param _newLimit New limit which will be set.
     */
    function setETHLimit(uint256 _newLimit) external override onlyOwner {
        ethLimit = _newLimit;
        emit LogETHLimitChanged(_newLimit, msg.sender);
    }

    /**
     * @notice Set new limit for a token. It's used while seller tries to create a voucher. The limit is determined by a voucher set. Voucher price * quantity, seller deposit * quantity, buyer deposit * qty must be below the limit.
     * @param _tokenAddress Address of the token which will be updated.
     * @param _newLimit New limit which will be set. It must comply to the decimals of the token, so the limit is set in the correct decimals.
     */
    function setTokenLimit(address _tokenAddress, uint256 _newLimit)
        external
        override
        onlyOwner
        notZeroAddress(_tokenAddress)
    {
        tokenLimits[_tokenAddress] = _newLimit;
        emit LogTokenLimitChanged(_newLimit, msg.sender);
    }

    // // // // // // // //
    // GETTERS
    // // // // // // // //

    /**
     * @notice Get the maximum allowed ETH limit to set as price of voucher, buyer deposit or seller deposit.
     */
    function getETHLimit() external view override returns (uint256) {
        return ethLimit;
    }

    /**
     * @notice Get the maximum allowed token limit for the specified Token.
     * @param _tokenAddress Address of the token which will be update.
     */
    function getTokenLimit(address _tokenAddress)
        external
        view
        override
        returns (uint256)
    {
        return tokenLimits[_tokenAddress];
    }

     /**
     * @notice Set the address of the wrapper contract for the token. The wrapper is used to, for instance, allow the Boson Protocol functions that use permit functionality to work in a uniform way.
     * @param _tokenAddress Address of the token for which the wrapper is being set
     * @param _wrapperAddress Address of the token wrapper contract
     */
    function setTokenWrapperAddress(address _tokenAddress, address _wrapperAddress) 
        external
        override
        onlyOwner
        notZeroAddress(_tokenAddress)
    {
        tokenWrappers[_tokenAddress] = _wrapperAddress;
        emit LogTokenWrapperChanged(_wrapperAddress, msg.sender);
    }

    /**
     * @notice Get the address of the token wrapper contract for the specified token
     * @param _tokenAddress Address of the token which will be updated.
     * @return Address of the token wrapper contract
     */
    function getTokenWrapperAddress(address _tokenAddress) 
        external
        view 
        override
        returns (address)
    {
        return tokenWrappers[_tokenAddress];
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: LGPL-3.0-or-later

pragma solidity 0.7.6;

interface ITokenRegistry {
    /**
     * @notice Set new limit for a token. It's used while seller tries to create a voucher. The limit is determined by a voucher set. Voucher price * quantity, seller deposit * quantity, buyer deposit * qty must be below the limit.
     * @param _tokenAddress Address of the token which will be updated.
     * @param _newLimit New limit which will be set. It must comply to the decimals of the token, so the limit is set in the correct decimals.
     */
    function setTokenLimit(address _tokenAddress, uint256 _newLimit) external;

    /**
     * @notice Get the maximum allowed token limit for the specified Token.
     * @param _tokenAddress Address of the token which will be update.
     * @return The max limit for this token
     */
    function getTokenLimit(address _tokenAddress)
        external
        view
        returns (uint256);

    /**
     * @notice Set new limit for ETH. It's used while seller tries to create a voucher. The limit is determined by a voucher set. Voucher price * quantity, seller deposit * quantity, buyer deposit * qty must be below the limit.
     * @param _newLimit New limit which will be set.
     */
    function setETHLimit(uint256 _newLimit) external;

    /**
     * @notice Get the maximum allowed ETH limit to set as price of voucher, buyer deposit or seller deposit.
     * @return The max ETH limit
     */
    function getETHLimit() external view returns (uint256);

    /**
     * @notice Set the address of the wrapper contract for the token. The wrapper is used to, for instance, allow the Boson Protocol functions that use permit functionality to work in a uniform way.
     * @param _tokenAddress Address of the token which will be updated.
     * @param _wrapperAddress Address of the wrapper contract
     */
    function setTokenWrapperAddress(
        address _tokenAddress,
        address _wrapperAddress
    ) external;

    /**
     * @notice Get the address of the token wrapper contract for the specified token
     * @param _tokenAddress Address of the token which will be updated.
     * @return Address of the token wrapper contract
     */
    function getTokenWrapperAddress(address _tokenAddress)
        external
        view
        returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}