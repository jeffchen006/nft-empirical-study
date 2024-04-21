// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IGuildAsset is IERC721 {
    function getTotalVolume(uint16 _guildType) external view returns (uint256);
    function isValidGuildStock(uint256 _guildTokenId) external view;
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function getGuildType(uint256 _guildTokenId) external view returns (uint16);
    function getShareRateWithDecimal(uint256 _guildTokenId) external view returns (uint256, uint256);
}

contract CSPLGuildPoolV2 is Ownable, Pausable, ReentrancyGuard {

  IGuildAsset public guildAsset;

  // mapping(guildType => totalAmount)
  mapping(uint16 => uint256) private guildTypeToTotalAmount;
  // mapping(guildTokenId => withdrawnAmount)
  mapping(uint256 => uint256) private guildStockToWithdrawnAmount;
  // mapping(allowedAddresses => bool)
  mapping(address => bool) private allowedAddresses;

  event EthAddedToPool(
    uint16 indexed guildType,
    address txSender,
    address indexed purchaseBy,
    uint256 value,
    uint256 at
  );

  event WithdrawEther(
    uint256 indexed guildTokenId,
    address indexed owner,
    uint256 value,
    uint256 at
  );

  event AllowedAddressSet(
    address allowedAddress,
    bool allowedStatus
  );

  constructor(address _guildAssetAddress) {
    setGuildAssetAddress(_guildAssetAddress);
  }

  function setGuildAssetAddress(address _guildAssetAddress) public onlyOwner() {
    guildAsset = IGuildAsset(_guildAssetAddress);
  }

  // getter setter
  function getAllowedAddress(address _address) public view returns (bool) {
    return allowedAddresses[_address];
  }

  function setAllowedAddress(address _address, bool desired) external onlyOwner() {
    allowedAddresses[_address] = desired;
  }

  function getGuildStockWithdrawnAmount(uint256 _guildTokenId) public view returns (uint256) {
    return guildStockToWithdrawnAmount[_guildTokenId];
  }

  function getGuildTypeToTotalAmount(uint16 _guildType) public view returns (uint256) {
    return guildTypeToTotalAmount[_guildType];
  }

  // poolに追加 execute from buySPL
  function addEthToGuildPool(uint16 _guildType, address _purchaseBy) external payable whenNotPaused() nonReentrant() {
    require(guildAsset.getTotalVolume(_guildType) > 0);
    require(allowedAddresses[msg.sender]);
    guildTypeToTotalAmount[_guildType] += msg.value;

    emit EthAddedToPool(
      _guildType,
      msg.sender,
      _purchaseBy,
      msg.value,
      block.timestamp
    );
  }

  function withdrawMyAllRewards() external whenNotPaused() nonReentrant() {
    uint256 withdrawValue;
    uint256 balance = guildAsset.balanceOf(msg.sender);

    for (uint256 i=balance; i > 0; i--) {
      uint256 guildStock = guildAsset.tokenOfOwnerByIndex(msg.sender, i-1);
      uint256 tmpAmount = getGuildStockWithdrawableBalance(guildStock);
      withdrawValue += tmpAmount;
      guildStockToWithdrawnAmount[guildStock] += tmpAmount;

      emit WithdrawEther(
        guildStock,
        msg.sender,
        tmpAmount,
        block.timestamp
      );
    }

    require(withdrawValue > 0, "no withdrawable balances left");

    payable(msg.sender).transfer(withdrawValue);
  }

  function withdrawMyReward(uint256 _guildTokenId) external whenNotPaused() nonReentrant() {
    require(guildAsset.ownerOf(_guildTokenId) == msg.sender);
    uint256 withdrawableAmount = getGuildStockWithdrawableBalance(_guildTokenId);
    require(withdrawableAmount > 0);

    guildStockToWithdrawnAmount[_guildTokenId] += withdrawableAmount;
    payable(msg.sender).transfer(withdrawableAmount);

    emit WithdrawEther(
      _guildTokenId,
      msg.sender,
      withdrawableAmount,
      block.timestamp
    );
  }

  function withdrawMyRewards(uint[] calldata _guildTokenId) external whenNotPaused() nonReentrant() {
    uint256 withdrawValue;

    for (uint8 i = 0; i < _guildTokenId.length; i++) {
        require(guildAsset.ownerOf(_guildTokenId[i]) == msg.sender);
        uint256 tmpAmount = getGuildStockWithdrawableBalance(_guildTokenId[i]);

        guildStockToWithdrawnAmount[_guildTokenId[i]] += tmpAmount;

        emit WithdrawEther(
            _guildTokenId[i],
            msg.sender,
            tmpAmount,
            block.timestamp
        );
        withdrawValue += tmpAmount;
    }

    require(withdrawValue > 0, "no withdrawable balances left");

    payable(msg.sender).transfer(withdrawValue);
  }

  // ギルドトークンごとの引き出し可能な量
  // 全体の総和×割合-これまで引き出した量
  function getGuildStockWithdrawableBalance(uint256 _guildTokenId) public view returns (uint256) {
    guildAsset.isValidGuildStock(_guildTokenId);

    uint16 _guildType = guildAsset.getGuildType(_guildTokenId);
    (uint256 shareRate, uint256 decimal) = guildAsset.getShareRateWithDecimal(_guildTokenId);
    uint256 maxAmount = guildTypeToTotalAmount[_guildType] * shareRate / decimal;
    return maxAmount - guildStockToWithdrawnAmount[_guildTokenId];
  }

  function getWithdrawableBalance(address _ownerAddress) public view returns (uint256) {
    uint256 balance = guildAsset.balanceOf(_ownerAddress);
    uint256 withdrawableAmount;

    for (uint256 i=balance; i > 0; i--) {
      uint256 guildTokenId = guildAsset.tokenOfOwnerByIndex(_ownerAddress, i-1);
      withdrawableAmount += getGuildStockWithdrawableBalance(guildTokenId);
    }

    return withdrawableAmount;
  }

  function getGuildStockWithdrawableBalances(uint[] calldata _guildTokenId) public view returns (uint256) {
    uint256 withdrawableAmount;

    for (uint8 i = 0; i < _guildTokenId.length; i++) {
      withdrawableAmount += getGuildStockWithdrawableBalance(_guildTokenId[i]);
    }

    return withdrawableAmount;
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
     * by making the `nonReentrant` function external, and make it call a
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