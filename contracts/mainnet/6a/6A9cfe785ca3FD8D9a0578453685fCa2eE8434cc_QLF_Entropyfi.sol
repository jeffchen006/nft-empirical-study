// SPDX-License-Identifier: MIT

/**
 * @author          Yisi Liu
 * @contact         [email protected]
 * @author_time     01/06/2021
**/

pragma solidity >= 0.8.0;

import "./IQLF.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract QLF_Entropyfi is IQLF, Ownable {
    uint256 start_time;
    mapping(address => bool) public whitelist_list;

    constructor (uint256 _start_time) {
        start_time = _start_time;
    }

    function get_start_time() public view returns (uint256) {
        return start_time;
    }

    function set_start_time(uint256 _start_time) public onlyOwner {
        start_time = _start_time;
    }

    function isQualified(address account)
        public view
        returns (
            bool qualified
        )
    {
        if (start_time > block.timestamp) {
            return false; 
        }
        if (!whitelist_list[account]) {
            return false; 
        }
        return true;  
        
    }

    function ifQualified(address account, bytes32[] memory data)
        public
        view
        override
        returns (
            bool qualified,
            string memory errorMsg
        )
    {
        if (start_time > block.timestamp) {
            return (false, "not started"); 
        }
        if (!whitelist_list[account]) {
            return (false, "not whitelisted"); 
        }
        return (true, "");
    } 

    function add_white_list(address[] memory addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            whitelist_list[addrs[i]] = true;
        }
    }

    function remove_white_list(address[] memory addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            whitelist_list[addrs[i]] = false;
        }
    }

    function logQualified(address account, bytes32[] memory data)
        public
        override
        returns (
            bool qualified,
            string memory errorMsg
        )
    {
        if (start_time > block.timestamp) {
            return (false, "not started"); 
        }
        if (!whitelist_list[account]) {
            return (false, "not whitelisted"); 
        }
        emit Qualification(account, true, block.number, block.timestamp);
        return (true, "");
    } 

    function supportsInterface(bytes4 interfaceId) external override pure returns (bool) {
        return interfaceId == this.supportsInterface.selector || 
            interfaceId == (this.ifQualified.selector ^ this.logQualified.selector) ||
            interfaceId == this.get_start_time.selector;
    }
}

// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
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
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT

/**
 * @author          Yisi Liu
 * @contact         [email protected]
 * @author_time     01/06/2021
**/

pragma solidity >= 0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

abstract
contract IQLF is IERC165 {
    /**
     * @dev Check if the given address is qualified, implemented on demand.
     *
     * Requirements:
     *
     * - `account` account to be checked
     * - `data`  data to prove if a user is qualified.
     *           For instance, it can be a MerkelProof to prove if a user is in a whitelist
     *
     * Return:
     *
     * - `bool` whether the account is qualified for ITO
     * - `string` if not qualified, it contains the error message(reason)
     */
    function ifQualified (address account, bytes32[] memory data) virtual external view returns (bool, string memory);

    /**
     * @dev Logs if the given address is qualified, implemented on demand.
     */
    function logQualified (address account, bytes32[] memory data) virtual external returns (bool, string memory);

    /**
     * @dev Ensure that custom contract implements `ifQualified` amd `logQualified` correctly.
     */
    function supportsInterface(bytes4 interfaceId) virtual external override pure returns (bool) {
        return interfaceId == this.supportsInterface.selector || 
            interfaceId == (this.ifQualified.selector ^ this.logQualified.selector);
    }

    /**
     * @dev Emit when `logQualified` is called to decide if the given `address`
     * is `qualified` according to the preset rule by the contract creator and 
     * the current block `number` and the current block `timestamp`.
     */
    event Qualification(address indexed account, bool qualified, uint256 blockNumber, uint256 timestamp);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

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