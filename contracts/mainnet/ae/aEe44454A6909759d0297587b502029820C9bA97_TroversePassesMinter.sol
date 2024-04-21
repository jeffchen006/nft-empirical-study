// contracs/TroversePassesMinter.sol
// SPDX-License-Identifier: MIT

// ████████╗██████╗  ██████╗ ██╗   ██╗███████╗██████╗ ███████╗███████╗    
// ╚══██╔══╝██╔══██╗██╔═══██╗██║   ██║██╔════╝██╔══██╗██╔════╝██╔════╝    
//    ██║   ██████╔╝██║   ██║██║   ██║█████╗  ██████╔╝███████╗█████╗      
//    ██║   ██╔══██╗██║   ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██╔══╝      
//    ██║   ██║  ██║╚██████╔╝ ╚████╔╝ ███████╗██║  ██║███████║███████╗    
//    ╚═╝   ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝    

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IMultiToken is IERC1155 {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
    function totalSupply(uint256 id) external returns (uint256);
}

interface IYieldToken is IERC20 {
    function burn(address _from, uint256 _amount) external;
}


contract TroversePassesMinter is Ownable {
    mapping(uint256 => NFT) public NFTInfo;

    struct NFT {
        bool mintsAllowed;
        bool mintsByTokenAllowed;
        bool whitelistsAllowed;
        bool whitelistsByTokenAllowed;
        uint128 mintPrice;
        uint128 whitelistPrice;
        uint256 maxSupply;
    }

    mapping(uint256 => mapping(address => uint256)) public whitelist;

    IMultiToken public multiToken;
    IYieldToken public yieldToken;
    bool public burnYieldToken;

    event MultiTokenChanged(address _multiToken);
    event YieldTokenChanged(address _yieldToken, bool _burnYieldToken);


    constructor() { }
    
    
    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function setMultiToken(address _multiToken) external onlyOwner {
        require(_multiToken != address(0), "Bad MultiToken address");
        multiToken = IMultiToken(_multiToken);

        emit MultiTokenChanged(_multiToken);
    }

    function setYieldToken(address _yieldToken, bool _burnYieldToken) external onlyOwner {
        require(_yieldToken != address(0), "Bad YieldToken address");

        yieldToken = IYieldToken(_yieldToken);
        burnYieldToken = _burnYieldToken;

        emit YieldTokenChanged(_yieldToken, _burnYieldToken);
    }

    function getMintPrice(uint256 id) external view returns (uint128) {
        return NFTInfo[id].mintPrice;
    }

    function getWhitelistPrice(uint256 id) external view returns (uint128) {
        return NFTInfo[id].whitelistPrice;
    }

    function setNFTInfos(
        uint256[] memory ids,
        bool[] memory mintsAllowed,
        bool[] memory mintsByTokenAllowed,
        bool[] memory whitelistsAllowed,
        bool[] memory whitelistsByTokenAllowed,
        uint128[] memory mintPrices,
        uint128[] memory whitelistPrices,
        uint256[] memory maxSupply
    ) external onlyOwner {
        for (uint256 i; i < ids.length; i++) {
            NFTInfo[ids[i]] = NFT(mintsAllowed[i], mintsByTokenAllowed[i], whitelistsAllowed[i], whitelistsByTokenAllowed[i], mintPrices[i], whitelistPrices[i], maxSupply[i]);
        }
    }

    function setNFTInfo(
        uint256 id,
        bool mintsAllowed,
        bool mintsByTokenAllowed,
        bool whitelistsAllowed,
        bool whitelistsByTokenAllowed,
        uint128 mintPrice,
        uint128 whitelistPrice,
        uint256 maxSupply
    ) external onlyOwner {
        NFTInfo[id] = NFT(mintsAllowed, mintsByTokenAllowed, whitelistsAllowed, whitelistsByTokenAllowed, mintPrice, whitelistPrice, maxSupply);
    }

    function updateWhitelist(uint256 id, address[] calldata addresses, uint256 limit) external onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            whitelist[id][addresses[i]] = limit;
        }
    }

    function Airdrop(uint256 id, uint256 amount, address[] calldata accounts) external onlyOwner {
        NFT storage nft = NFTInfo[id];
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + (amount * accounts.length) <= nft.maxSupply, "Token max supply reached");
        
        for (uint256 i; i < accounts.length; i++) {
            multiToken.mint(accounts[i], id, amount, bytes(""));
        }
    }

    function MintForByToken(uint256 id, uint256 amount, address account, uint256 totalCost) external onlyOwner {
        NFT storage nft = NFTInfo[id];
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + amount <= nft.maxSupply, "Token max supply reached");

        if (totalCost > 0) {
            if (burnYieldToken) {
                yieldToken.burn(account, totalCost);
            } else {
                yieldToken.transferFrom(account, address(this), totalCost);
            }
        }
        
        multiToken.mint(account, id, amount, bytes(""));
    }

    function Mint(uint256 id, uint256 amount) external payable callerIsUser {
        NFT storage nft = NFTInfo[id];
        require(nft.mintsAllowed && nft.mintPrice > 0, "Mints are not allowed yet");
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + amount <= nft.maxSupply, "Token max supply reached");

        uint256 totalPrice = amount * nft.mintPrice;
        refundIfOver(totalPrice);

        multiToken.mint(_msgSender(), id, amount, bytes(""));
    }

    function MintByToken(uint256 id, uint256 amount) external callerIsUser {
        NFT storage nft = NFTInfo[id];
        require(nft.mintsByTokenAllowed && nft.mintPrice > 0, "Mints are not allowed yet");
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + amount <= nft.maxSupply, "Token max supply reached");

        uint256 totalPrice = amount * nft.mintPrice;

        if (burnYieldToken) {
            yieldToken.burn(_msgSender(), totalPrice);
        } else {
            yieldToken.transferFrom(_msgSender(), address(this), totalPrice);
        }

        multiToken.mint(_msgSender(), id, amount, bytes(""));
    }

    function Claim(uint256 id, uint256 amount) external payable callerIsUser {
        NFT storage nft = NFTInfo[id];
        require(nft.whitelistsAllowed, "Whitelists are not allowed yet");
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + amount <= nft.maxSupply, "Token max supply reached");
        require(whitelist[id][_msgSender()] >= amount, "Can't claim this much");

        if (nft.whitelistPrice > 0) {
            uint256 totalPrice = amount * nft.whitelistPrice;
            refundIfOver(totalPrice);
        }

        multiToken.mint(_msgSender(), id, amount, bytes(""));
        whitelist[id][_msgSender()] -= amount;
    }

    function ClaimByToken(uint256 id, uint256 amount) external callerIsUser {
        NFT storage nft = NFTInfo[id];
        require(nft.whitelistsByTokenAllowed, "Whitelists are not allowed yet");
        require(nft.maxSupply > 0 , "Token doesn't exist");
        require(multiToken.totalSupply(id) + amount <= nft.maxSupply, "Token max supply reached");
        require(whitelist[id][_msgSender()] >= amount, "Can't claim this much");

        if (nft.whitelistPrice > 0) {
            uint256 totalPrice = amount * nft.whitelistPrice;
            
            if (burnYieldToken) {
                yieldToken.burn(_msgSender(), totalPrice);
            } else {
                yieldToken.transferFrom(_msgSender(), address(this), totalPrice);
            }
        }

        multiToken.mint(_msgSender(), id, amount, bytes(""));
        whitelist[id][_msgSender()] -= amount;
    }

    function refundIfOver(uint256 price) private {
        require(msg.value >= price, "Insufficient funds");

        if (msg.value > price) {
            payable(msg.sender).transfer(msg.value - price);
        }
    }

    function withdrawAll(address to) external onlyOwner {
        require(payable(to).send(address(this).balance), "Transfer failed");
    }

    function withdrawToken(address tokenContract, address to, uint256 amount) external onlyOwner {
        IERC20(tokenContract).transfer(to, amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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