// SPDX-License-Identifier: MIT

/*
                    ████████╗██╗  ██╗███████╗
                    ╚══██╔══╝██║  ██║██╔════╝
                       ██║   ███████║█████╗
                       ██║   ██╔══██║██╔══╝
                       ██║   ██║  ██║███████╗
                       ╚═╝   ╚═╝  ╚═╝╚══════╝
██╗  ██╗██╗   ██╗███╗   ███╗ █████╗ ███╗   ██╗ ██████╗ ██╗██████╗ ███████╗
██║  ██║██║   ██║████╗ ████║██╔══██╗████╗  ██║██╔═══██╗██║██╔══██╗██╔════╝
███████║██║   ██║██╔████╔██║███████║██╔██╗ ██║██║   ██║██║██║  ██║███████╗
██╔══██║██║   ██║██║╚██╔╝██║██╔══██║██║╚██╗██║██║   ██║██║██║  ██║╚════██║
██║  ██║╚██████╔╝██║ ╚═╝ ██║██║  ██║██║ ╚████║╚██████╔╝██║██████╔╝███████║
╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═════╝ ╚══════╝


The Humanoids Staking Contract

*/

pragma solidity =0.8.11;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IStakingReward.sol";

contract TheHumanoidsStaking is Ownable {
    bool public canStake;
    address public stakingRewardContract;

    IERC721 private constant _NFT_CONTRACT = IERC721(0x3a5051566b2241285BE871f650C445A88A970edd);

    struct Token {
        address owner;
        uint64 timestamp;
        uint16 index;
    }
    mapping(uint256 => Token) private _tokens;
    mapping(address => uint16[]) private _stakedTokens;

    constructor() {}

    function setStaking(bool _canStake) external onlyOwner {
        canStake = _canStake;
    }

    function setStakingRewardContract(address newStakingRewardContract) external onlyOwner {
        address oldStakingRewardContract = stakingRewardContract;
        require(newStakingRewardContract != oldStakingRewardContract, "New staking reward contract is same as old contract");
        if (oldStakingRewardContract != address(0)) {
            IStakingReward(oldStakingRewardContract).willBeReplacedByContract(newStakingRewardContract);
        }
        stakingRewardContract = newStakingRewardContract;
        if (newStakingRewardContract != address(0)) {
            IStakingReward(newStakingRewardContract).didReplaceContract(oldStakingRewardContract);
        }
    }


    function stakedTokensBalanceOf(address account) external view returns (uint256) {
        return _stakedTokens[account].length;
    }

    function stakedTokensOf(address account) external view returns (uint16[] memory) {
        return _stakedTokens[account];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address owner = _tokens[tokenId].owner;
        require(owner != address(0), "Token not staked");
        return owner;
    }

    function timestampOf(uint256 tokenId) external view returns (uint256) {
        uint256 timestamp = uint256(_tokens[tokenId].timestamp);
        require(timestamp != 0, "Token not staked");
        return timestamp;
    }


    function stake(uint16[] calldata tokenIds) external {
        require(canStake, "Staking not enabled");
        uint length = tokenIds.length;
        require(length > 0, "tokenIds array is empty");

        if (stakingRewardContract != address(0)) {
            IStakingReward(stakingRewardContract).willStakeTokens(msg.sender, tokenIds);
        }

        uint64 timestamp = uint64(block.timestamp);
        uint16[] storage stakedTokens = _stakedTokens[msg.sender];
        uint16 index = uint16(stakedTokens.length);
        unchecked {
            for (uint i=0; i<length; i++) {
                uint16 tokenId = tokenIds[i];
                _NFT_CONTRACT.transferFrom(msg.sender, address(this), tokenId);

                Token storage token = _tokens[tokenId];
                token.owner = msg.sender;
                token.timestamp = timestamp;
                token.index = index;
                index++;

                stakedTokens.push(tokenId);
            }
        }
    }

    function unstake(uint16[] calldata tokenIds) external {
        uint length = tokenIds.length;
        require(length > 0, "tokenIds array is empty");

        if (stakingRewardContract != address(0)) {
            IStakingReward(stakingRewardContract).willUnstakeTokens(msg.sender, tokenIds);
        }

        unchecked {
            uint16[] storage stakedTokens = _stakedTokens[msg.sender];

            for (uint i=0; i<length; i++) {
                uint256 tokenId = tokenIds[i];
                require(_tokens[tokenId].owner == msg.sender, "Token not staked or not owned");

                uint index = _tokens[tokenId].index;
                uint lastIndex = stakedTokens.length-1;
                if (index != lastIndex) {
                    uint16 lastTokenId = stakedTokens[lastIndex];
                    stakedTokens[index] = lastTokenId;
                    _tokens[lastTokenId].index = uint16(index);
                }

                stakedTokens.pop();

                delete _tokens[tokenId];
                _NFT_CONTRACT.transferFrom(address(this), msg.sender, tokenId);
            }
        }
    }

    function unstakeAll() external {
        uint16[] storage stakedTokens = _stakedTokens[msg.sender];
        uint length = stakedTokens.length;
        require(length > 0, "Nothing staked");

        if (stakingRewardContract != address(0)) {
            IStakingReward(stakingRewardContract).willUnstakeTokens(msg.sender, stakedTokens);
        }

        unchecked {
            for (uint i=0; i<length; i++) {
                uint256 tokenId = stakedTokens[i];
                delete _tokens[tokenId];
                _NFT_CONTRACT.transferFrom(address(this), msg.sender, tokenId);
            }
        }

        delete _stakedTokens[msg.sender];
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

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

pragma solidity ^0.8.0;

interface IStakingReward {
    function willStakeTokens(address account, uint16[] calldata tokenIds) external;
    function willUnstakeTokens(address account, uint16[] calldata tokenIds) external;

    function willBeReplacedByContract(address stakingRewardContract) external;
    function didReplaceContract(address stakingRewardContract) external;
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