// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {Owned} from "@solmate/auth/Owned.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IArtGobblers} from "./IArtGobblers.sol";

/// @author Philippe Dumonet <https://github.com/philogy>
contract GooSitter is Owned {
    IArtGobblers internal constant gobblers =
        IArtGobblers(0x60bb1e2AA1c9ACAfB4d34F71585D7e959f387769);
    IERC20 internal constant goo =
        IERC20(0x600000000a36F3cD48407e35eB7C5c910dc1f7a8);
    address internal immutable manager;

    bool internal constant BUY_GOBBLER_WITH_VIRTUAL = true;

    error NotManager();

    constructor(address _manager, address _initialOwner) Owned(_initialOwner) {
        manager = _manager;
    }

    /// @dev Transfers gobblers and virtual GOO to `_recipient`.
    /// @notice Does **not** use `safeTransferFrom` so be sure double-check `_recipient` before calling.
    function withdraw(
        address _recipient,
        uint256[] calldata _gobblerIds,
        uint256 _gooAmount
    ) external onlyOwner {
        uint256 gobblerCount = _gobblerIds.length;
        for (uint256 i; i < gobblerCount; ) {
            gobblers.transferFrom(address(this), _recipient, _gobblerIds[i]);
            // prettier-ignore
            unchecked { ++i; }
        }
        if (_gooAmount == type(uint256).max)
            _gooAmount = gobblers.gooBalance(address(this));
        gobblers.removeGoo(_gooAmount);
        goo.transfer(_recipient, _gooAmount);
    }

    /// @dev Allows the `manager` to buy a gobbler on your behalf.
    /// @dev Not actually payable, but callvalue check is done more cheaply in assembly.
    function buyGobbler(uint256 _maxPrice) external payable {
        // Copy immutables locally since they're not supported in assembly.
        address manager_ = manager;
        address gobblers_ = address(gobblers);
        assembly {
            // Store `mintFromGoo(uint256,bool)` selector.
            mstore(0x00, 0xc9bddac6)
            // Prepare `mintFromGoo` parameters.
            mstore(0x20, _maxPrice)
            mstore(0x40, BUY_GOBBLER_WITH_VIRTUAL)

            // Call optimistically and do `msg.sender` auth require after.
            let success := call(gas(), gobblers_, 0, 0x1c, 0x44, 0x00, 0x00)

            // If `msg.sender != manager` sub result will be non-zero.
            let authDiff := sub(caller(), manager_)
            if or(or(authDiff, callvalue()), iszero(success)) {
                if authDiff {
                    // Revert `NotManager()`.
                    mstore(0x00, 0xc0fc8a8a)
                    revert(0x1c, 0x04)
                }
                let revSize := mul(iszero(callvalue()), returndatasize())
                returndatacopy(0x00, 0x00, revSize)
                revert(0x00, revSize)
            }

            // End here to ensure we can safely leave the free memory pointer.
            stop()
        }
    }

    /// @dev Doesn't send GOO anywhere so it's safe for anyone to be able to call.
    function consolidateGoo() external {
        gobblers.addGoo(goo.balanceOf(address(this)));
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Simple single owner authorization mixin.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Owned.sol)
abstract contract Owned {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event OwnershipTransferred(address indexed user, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            OWNERSHIP STORAGE
    //////////////////////////////////////////////////////////////*/

    address public owner;

    modifier onlyOwner() virtual {
        require(msg.sender == owner, "UNAUTHORIZED");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        owner = _owner;

        emit OwnershipTransferred(address(0), _owner);
    }

    /*//////////////////////////////////////////////////////////////
                             OWNERSHIP LOGIC
    //////////////////////////////////////////////////////////////*/

    function transferOwnership(address newOwner) public virtual onlyOwner {
        owner = newOwner;

        emit OwnershipTransferred(msg.sender, newOwner);
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

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";

/// @author Philogy <https://github.com/Philogy>
/// @notice Not full interface, certain methods missing
interface IArtGobblers is IERC721 {
    function goo() external view returns (address);

    function tokenURI(uint256 gobblerId) external view returns (string memory);

    function gooBalance(address user) external view returns (uint256);

    function removeGoo(uint256 gooAmount) external;

    function addGoo(uint256 gooAmount) external;

    function getUserEmissionMultiple(address user)
        external
        view
        returns (uint256);

    function getGobblerEmissionMultiple(uint256 gobblerId)
        external
        view
        returns (uint256);

    function mintLegendaryGobbler(uint256[] calldata gobblerIds)
        external
        returns (uint256 gobblerId);

    function mintFromGoo(uint256 maxPrice, bool useVirtualBalance)
        external
        returns (uint256 gobblerId);

    function legendaryGobblerPrice() external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
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
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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