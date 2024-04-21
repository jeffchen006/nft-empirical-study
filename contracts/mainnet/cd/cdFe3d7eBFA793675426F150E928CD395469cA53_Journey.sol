// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../shared/interfaces/RealmsToken.sol";
import "../shared/interfaces/LordsToken.sol";

contract Journey is ERC721Holder, Ownable, ReentrancyGuard, Pausable {
    // -------- EVENTS -------- //
    event StakeRealms(uint256[] tokenIds, address player);
    event UnStakeRealms(uint256[] tokenIds, address player);

    // -------- MAPPINGS -------- //
    mapping(address => uint256) public epochClaimed;
    mapping(uint256 => address) public ownership;
    mapping(address => mapping(uint256 => uint256)) public realmsStaked;

    // -------- PUBLIC ---------- //
    LordsToken public lordsToken;
    RealmsToken public realmsToken;
    address public bridge;
    uint256 public lordsPerRealm;
    uint256 public genesis;
    uint256 public epoch;
    uint256 public finalAge;
    uint256 public halvingAge;
    uint256 public halvingAmount;
    uint256 public gracePeriod;

    uint256 public epochLengh = 3600;

    constructor(
        uint256 _lordsPerRealm,
        uint256 _epoch,
        uint256 _halvingAge,
        uint256 _halvingAmount,
        address _realmsAddress,
        address _lordsToken
    ) {
        lordsPerRealm = _lordsPerRealm;
        epoch = _epoch;
        halvingAge = _halvingAge;
        halvingAmount = _halvingAmount;
        lordsToken = LordsToken(_lordsToken);
        realmsToken = RealmsToken(_realmsAddress);
    }

    // -------- EXTERNALS -------- //

    function setGracePeriod(uint256 _gracePeriod) external onlyOwner {
        gracePeriod = _gracePeriod;
    }

    function setGenesis(uint256 _time) external onlyOwner {
        genesis = _time;
    }

    function lordsIssuance(uint256 _new) external onlyOwner {
        lordsPerRealm = _new;
    }

    function updateRealmsAddress(address _newRealms) external onlyOwner {
        realmsToken = RealmsToken(_newRealms);
    }

    function updateLordsAddress(address _newLords) external onlyOwner {
        lordsToken = LordsToken(_newLords);
    }

    function updateEpochLength(uint256 _newEpoch) external onlyOwner {
        epoch = _newEpoch;
    }

    function setBridge(address _newBridge) external onlyOwner {
        bridge = _newBridge;
    }

    function setHalvingAmount(uint256 _halvingAmount) external onlyOwner {
        halvingAmount = _halvingAmount;
    }

    function setHalvingAge(uint256 _halvingAge) external onlyOwner {
        halvingAge = _halvingAge;
    }

    function setFinalAge(uint256 _finalAge) external onlyOwner {
        finalAge = _finalAge;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Boards the Ship (Stakes). Sets ownership of Token to Staker. Transfers NFT to Contract. Set's epoch date, Set's number of Realms staked in the Epoch.
     * @param _tokenIds Ids of Realms
     */
    function boardShip(uint256[] memory _tokenIds)
        external
        whenNotPaused
        nonReentrant
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                realmsToken.ownerOf(_tokenIds[i]) == msg.sender,
                "NOT_OWNER"
            );
            ownership[_tokenIds[i]] = msg.sender;

            realmsToken.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIds[i]
            );
        }

        if (getNumberRealms(msg.sender) == 0) {
            epochClaimed[msg.sender] = _epochNum();
        }

        realmsStaked[msg.sender][_epochNum()] += uint256(_tokenIds.length);

        emit StakeRealms(_tokenIds, msg.sender);
    }

    /**
     * @notice Exits the Ship
     * @param _tokenIds Ids of Realms
     */
    function exitShip(uint256[] memory _tokenIds)
        external
        whenNotPaused
        nonReentrant
    {
        _exitShip(_tokenIds);
    }

    /**
     * @notice Claims all available Lords for Owner.
     */
    function claimLords() external whenNotPaused nonReentrant {
        _claimLords();
    }

    // -------- INTERNALS -------- //

    /**
     * @notice Set's epoch = epoch * 1 hour.
     */
    function _epochNum() internal view returns (uint256) {
        if (finalAge != 0) {
            return finalAge;
        } else if (block.timestamp - genesis < gracePeriod) {
            return 0;
        } else if ((block.timestamp - genesis) / (epoch * epochLengh) == 0) {
            return 1;
        } else {
            return (block.timestamp - genesis) / (epoch * epochLengh) + 1;
        }
    }

    /**
     * @notice Exits Ship, and transfers all Realms back to owner. Claims any lords available.
     * @param _tokenIds Ids of Realms
     */
    function _exitShip(uint256[] memory _tokenIds) internal {
        (uint256 lords, ) = lordsAvailable(msg.sender);

        if (lords != 0) {
            _claimLords();
        }

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(ownership[_tokenIds[i]] == msg.sender, "NOT_OWNER");

            ownership[_tokenIds[i]] = address(0);

            realmsToken.safeTransferFrom(
                address(this),
                msg.sender,
                _tokenIds[i]
            );
        }

        // Remove last in first
        if (_epochNum() == 0) {
            realmsStaked[msg.sender][_epochNum()] -= _tokenIds.length;
        } else {
            uint256 realmsInPrevious = realmsStaked[msg.sender][
                _epochNum() - 1
            ];
            uint256 realmsInCurrent = realmsStaked[msg.sender][_epochNum()];

            if (realmsInPrevious > _tokenIds.length) {
                realmsStaked[msg.sender][_epochNum() - 1] -= _tokenIds.length;
            } else if (realmsInCurrent == _tokenIds.length) {
                realmsStaked[msg.sender][_epochNum()] -= _tokenIds.length;
            } else if (realmsInPrevious <= _tokenIds.length) {
                // remove oldest first
                uint256 oldestFirst = (_tokenIds.length - realmsInPrevious);

                realmsStaked[msg.sender][_epochNum() - 1] -= (_tokenIds.length -
                    oldestFirst);

                realmsStaked[msg.sender][_epochNum()] -= oldestFirst;
            }
        }

        emit UnStakeRealms(_tokenIds, msg.sender);
    }

    function _claimLords() internal {
        require(_epochNum() > 1, "GENESIS_epochNum");

        (uint256 lords, uint256 totalRealms) = lordsAvailable(msg.sender);

        // set totalRealms staked in latest epoch - 1 so loop doesn't have to iterate again
        realmsStaked[msg.sender][_epochNum() - 1] = totalRealms;

        // set epoch claimed to current - 1
        epochClaimed[msg.sender] = _epochNum() - 1;

        require(lords > 0, "NOTHING_TO_CLAIM");

        lordsToken.approve(address(this), lords);

        lordsToken.transferFrom(address(this), msg.sender, lords);
    }

    // -------- GETTERS -------- //

    /**
     * @notice Lords available for the player
     */
    function lordsAvailable(address _player)
        public
        view
        returns (uint256 lords, uint256 totalRealms)
    {
        uint256 preHalvingRealms;
        uint256 postHalvingRealms;

        for (uint256 i = epochClaimed[_player]; i < _epochNum(); i++) {
            totalRealms += realmsStaked[_player][i];
        }

        if (epochClaimed[_player] <= halvingAge && _epochNum() <= halvingAge) {
            for (uint256 i = epochClaimed[_player]; i < _epochNum(); i++) {
                preHalvingRealms +=
                    realmsStaked[_player][i] *
                    ((_epochNum() - 1) - i);
            }
        } else if (
            _epochNum() >= halvingAge && epochClaimed[_player] < halvingAge
        ) {
            for (uint256 i = epochClaimed[_player]; i < halvingAge; i++) {
                preHalvingRealms +=
                    realmsStaked[_player][i] *
                    ((halvingAge) - i);
            }
        }

        if (_epochNum() > halvingAge && epochClaimed[_player] >= halvingAge) {
            for (uint256 i = epochClaimed[_player]; i < _epochNum(); i++) {
                postHalvingRealms +=
                    realmsStaked[_player][i] *
                    ((_epochNum() - 1) - i);
            }
        } else if (
            _epochNum() > halvingAge && epochClaimed[_player] < halvingAge
        ) {
            uint256 total;

            for (uint256 i = epochClaimed[_player]; i < _epochNum(); i++) {
                total += realmsStaked[_player][i] * ((_epochNum() - 1) - i);

                if (i < halvingAge) {
                    total -= realmsStaked[_player][i] * ((halvingAge) - i);
                }
            }

            postHalvingRealms = total;
        }

        if (_epochNum() > 1) {
            lords =
                (lordsPerRealm * preHalvingRealms) +
                (halvingAmount * postHalvingRealms);
        } else {
            lords = 0;
        }
    }

    /**
     * @notice Withdraw all Lords
     */
    function withdrawAllLords(address _destination) public onlyOwner {
        uint256 balance = lordsToken.balanceOf(address(this));
        lordsToken.approve(address(this), balance);
        lordsToken.transferFrom(address(this), _destination, balance);
    }

    function getEpoch() public view returns (uint256) {
        return _epochNum();
    }

    function getTimeUntilEpoch() public view returns (uint256) {
        return
            (epoch * epochLengh * (getEpoch())) - (block.timestamp - genesis);
    }

    function getNumberRealms(address _player) public view returns (uint256) {
        uint256 totalRealms;

        if (_epochNum() >= 1) {
            for (uint256 i = epochClaimed[_player]; i <= _epochNum(); i++) {
                totalRealms += realmsStaked[_player][i];
            }
            return totalRealms;
        } else {
            return realmsStaked[_player][0];
        }
    }

    // -------- MODIFIERS -------- //
    modifier onlyBridge() {
        require(msg.sender == bridge, "NOT_THE_BRIDGE");
        _;
    }

    // -------- BRIDGE FUNCTIONS -------- //
    /**
     * @notice Called only by future Bridge contract to withdraw the Realms
     * @param _tokenIds Ids of Realms
     */
    function bridgeWithdraw(address _player, uint256[] memory _tokenIds)
        public
        onlyBridge
    {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            ownership[_tokenIds[i]] = address(0);
            realmsToken.safeTransferFrom(address(this), _player, _tokenIds[i]);
        }
        emit UnStakeRealms(_tokenIds, _player);
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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (security/ReentrancyGuard.sol)

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

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface RealmsToken is IERC721Enumerable {

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface LordsToken is IERC20 {}

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
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
// OpenZeppelin Contracts v4.4.0 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (utils/introspection/IERC165.sol)

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
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

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