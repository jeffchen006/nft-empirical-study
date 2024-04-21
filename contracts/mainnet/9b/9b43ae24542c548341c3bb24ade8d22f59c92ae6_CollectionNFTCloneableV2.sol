/**
 *Submitted for verification at Etherscan.io on 2022-07-20
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

/*
 * TITLE: CollectionNFTCloneableV2
 *
 * AUTHOR: Dex Labs & Cooki.eth
 *
 * NOTES: This contract is a cloneable template for Hashes Collections.
 *        It is an ERC-721 contract which is preconfigured to work within
 *        the Hashes ecosystem. Creation logic has been moved to an initialization
 *        function so it works with the cloneable factory pattern. 
 *        
 *        Cooki.eth has modified the initialization function and internal logic 
 *        from the V1 contract to allow for on-chain construction of the 
 *        "TokenURI" metadata. This allows for purely on-chain NFT collections
 *        without the need for external dependencies.
 *
 */


//*********
//Libraries
//*********

library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }
}

library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

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
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
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

//**********
//Interfaces
//**********

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

interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

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

interface IOwnable {
    function renounceOwnership() external;

    function transferOwnership(address newOwner) external;

    function owner() external view returns (address);
}

interface IHashes is IERC721Enumerable {
    function deactivateTokens(
        address _owner,
        uint256 _proposalId,
        bytes memory _signature
    ) external returns (uint256);

    function deactivated(uint256 _tokenId) external view returns (bool);

    function activationFee() external view returns (uint256);

    function verify(
        uint256 _tokenId,
        address _minter,
        string memory _phrase
    ) external view returns (bool);

    function getHash(uint256 _tokenId) external view returns (bytes32);

    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
}

interface IERC2981Royalties {
    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _value - the sale price of the NFT asset specified by _tokenId
    /// @return _receiver - address of who should be sent the royalty payment
    /// @return _royaltyAmount - the royalty payment amount for value sale price
    function royaltyInfo(uint256 _tokenId, uint256 _value)
        external
        view
        returns (address _receiver, uint256 _royaltyAmount);
}

interface ICollectionNFTMintFeePredicate {
    function getTokenMintFee(uint256 _tokenId, uint256 _hashesTokenId) external view returns (uint256);
}

interface ICollectionNFTEligibilityPredicate {
    function isTokenEligibleToMint(uint256 _tokenId, uint256 _hashesTokenId) external view returns (bool);
}

interface ICollectionNFTTokenURIPredicate {
    function getTokenURI(uint256 _tokenId, uint256 _hashesTokenId, bytes32 _hashesHash) external view returns (string memory);
}

interface ICollectionNFTCloneableV2 {
    function mint(uint256 _hashesTokenId) external payable;

    function burn(uint256 _tokenId) external;

    function completeSignatureBlock() external;

    //function setTokenURI(string memory _baseTokenURI) external;

    function setRoyaltyBps(uint16 _royaltyBps) external;

    function transferCreator(address _creatorAddress) external;

    function setSignatureBlockAddress(address _signatureBlockAddress) external;

    function withdraw() external;
}

interface ICollectionCloneable {
    function initialize(
        IHashes _hashesToken,
        address _factoryMaintainerAddress,
        address _createCollectionCaller,
        bytes memory _initializationData
    ) external;
}

interface ICollection {
    function verifyEcosystemSettings(bytes memory _settings) external pure returns (bool);
}

interface ICollectionFactory {
    function addImplementationAddress(
        bytes32 _hashedEcosystemName,
        address _implementationAddress,
        bool cloneable
    ) external;

    function createCollection(address _implementationAddress, bytes memory _initializationData) external;

    function setFactoryMaintainerAddress(address _factoryMaintainerAddress) external;

    function removeImplementationAddresses(
        bytes32[] memory _hashedEcosystemNames,
        address[] memory _implementationAddresses,
        uint256[] memory _indexes
    ) external;

    function removeCollection(
        address _implementationAddress,
        address _collectionAddress,
        uint256 _index
    ) external;

    function createEcosystemSettings(string memory _ecosystemName, bytes memory _settings) external;

    function updateEcosystemSettings(bytes32 _hashedEcosystemName, bytes memory _settings) external;

    function getEcosystemSettings(bytes32 _hashedEcosystemName, uint64 _blockNumber)
        external
        view
        returns (bytes memory);

    function getEcosystems() external view returns (bytes32[] memory);

    function getEcosystems(uint256 _start, uint256 _end) external view returns (bytes32[] memory);

    function getCollections(address _implementationAddress) external view returns (address[] memory);

    function getCollections(
        address _implementationAddress,
        uint256 _start,
        uint256 _end
    ) external view returns (address[] memory);

    function getImplementationAddresses(bytes32 _hashedEcosystemName) external view returns (address[] memory);

    function getImplementationAddresses(
        bytes32 _hashedEcosystemName,
        uint256 _start,
        uint256 _end
    ) external view returns (address[] memory);
}

//******************************
//Abstract/Preliminary Contracts
//******************************

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

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

abstract contract OwnableCloneable is Context {
    bool ownableInitialized;
    address private _owner;

    modifier ownershipInitialized() {
        require(ownableInitialized, "OwnableCloneable: hasn't been initialized yet.");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the initialize caller as the initial owner.
     */
    function initializeOwnership(address initialOwner) public virtual {
        require(!ownableInitialized, "OwnableCloneable: already initialized.");
        ownableInitialized = true;
        _setOwner(initialOwner);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual ownershipInitialized returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "OwnableCloneable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual ownershipInitialized onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual ownershipInitialized onlyOwner {
        require(newOwner != address(0), "OwnableCloneable: new owner is the zero address");
        _setOwner(newOwner);
    }

    // This is set to internal so overriden versions of renounce/transfer ownership
    // can also be carried out by DAO address.
    function _setOwner(address newOwner) internal ownershipInitialized {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

//************************
//CollectionNFTCloneableV2
//************************

contract CollectionNFTCloneableV2 is
    ICollection,
    ICollectionCloneable,
    ICollectionNFTCloneableV2,
    OwnableCloneable,
    ERC721Enumerable,
    IERC2981Royalties,
    ReentrancyGuard
{
    using SafeMath for uint16;
    using SafeMath for uint64;
    using SafeMath for uint128;
    using SafeMath for uint256;

    bool _initialized;

    /// @notice A structure for storing a token ID in a map.
    struct TokenIdEntry {
        bool exists;
        uint128 tokenId;
    }

    /// @notice A structure for storing the relationship between Collection Id, Hashes Id, and the Hashes hash used in mint
    //This allows the draw function to work, even after original minter has transfered NFT
    struct idToHash {
        bool exists;
        uint256 hashesId;
        bytes32 hashesHash;
    }

    /// @notice A structure for decoding and storing data from the factory initializer
    struct InitializerSettings {
        string tokenName;
        string tokenSymbol;
        ICollectionNFTTokenURIPredicate TokenURIPredicateContract;
        uint256 cap;
        ICollectionNFTEligibilityPredicate mintEligibilityPredicateContract;
        ICollectionNFTMintFeePredicate mintFeePredicateContract;
        uint16 royaltyBps;
        address signatureBlockAddress;
    }

    /// @notice nonce Monotonically-increasing number (token ID).
    uint256 public nonce;

    /// @notice cap The supply cap for this token. Set to 0 for unlimited.
    uint256 public cap;

    /// @notice tokenName The name of the ERC-721 token.
    string private tokenName;

    /// @notice tokenSymbol The symbol of the ERC-721 token.
    string private tokenSymbol;

    /// @notice creatorAddress The address of the collection creator.
    address public creatorAddress;

    /// @notice signatureBlockAddress An optional address which (when set) will cause all tokens to be
    ///         minted from this address and then immediately transfered to the mint message sender.
    address public signatureBlockAddress;

    // Interface for contract which contains a function isTokenEligibleToMint(tokenId, hashesTokenId)
    // used for determining mint eligibility for a Hashes token.
    ICollectionNFTEligibilityPredicate public mintEligibilityPredicateContract;

    // Interface for contract which contains a function getTokenMintFee(tokenId, hashesTokenId)
    // used for determining the mint fee for a Hashes token.
    ICollectionNFTMintFeePredicate public mintFeePredicateContract;

    // Interface for contract which contains a function getTokenURI(tokenId, uint256 _hashesTokenId)
    // Used for determining the token URI for this token.
    ICollectionNFTTokenURIPredicate public TokenURIPredicateContract;

    /// @notice hashesIdToCollectionTokenIdMapping Mapping of Hashes ID to collection token ID.
    mapping(uint256 => TokenIdEntry) public hashesIdToCollectionTokenIdMapping;

    //And the inverse
    /// @notice tokenCollectionIdToHashesIdMapping Mapping of collection token ID to Hashes ID.
    mapping(uint256 => idToHash) public tokenCollectionIdToHashesIdMapping;

    /// @notice royaltyBps The sales royalty amount (in hundredths of a percent).
    uint16 public royaltyBps;

    uint16 private _hashesDAOMintFeePercent;

    uint16 private _hashesDAORoyaltyFeePercent;

    uint16 private _maximumCollectionRoyaltyPercent;

    /// @notice isSignatureBlockCompleted Whether the signature block address has interacted with this
    ///         contract to verify their support of this contract and establish provenance.
    bool public isSignatureBlockCompleted;

    IHashes hashesToken;

    /// @notice CollectionInitialized Emitted when a Collection is initialized.
    event CollectionInitialized(
        string tokenName,
        string tokenSymbol,
        address TokenURIPredicateAddress,
        uint256 cap,
        address mintEligibilityPredicateAddress,
        address mintFeePredicateAddress,
        uint16 royaltyBps,
        address signatureBlockAddress,
        uint64 indexed initializationBlock
    );

    /// @notice Minted Emitted when a Hashes Collection is minted.
    event Minted(address indexed minter, uint256 indexed tokenId, uint256 indexed hashesTokenId);

    /// @notice Withdraw Emitted when a withdraw event is triggered.
    event Withdraw(uint256 indexed creatorAmount, uint256 indexed hashesDAOAmount);

    /// @notice CreatorTransferred Emitted when the creator address is transferred.
    event CreatorTransferred(address indexed previousCreator, address indexed newCreator);

    /// @notice RoyaltyBpsSet Emitted when the royalty bps is set.
    event RoyaltyBpsSet(uint16 royaltyBps);

    /// @notice Burned Emitted when a token is burned.
    event Burned(address indexed burner, uint256 indexed tokenId);

    /// @notice SignatureBlockCompleted Emitted when the signature block is completed.
    event SignatureBlockCompleted(address indexed signatureBlockAddress);

    /// @notice SignatureBlockAddressSet Emitted when the signature block address is set.
    event SignatureBlockAddressSet(address indexed signatureBlockAddress);

    modifier initialized() {
        require(_initialized, "CollectionNFTCloneableV2: hasn't been initialized yet.");
        _;
    }

    modifier onlyOwnerOrHashesDAO() {
        require(
            _msgSender() == owner() || _msgSender() == IOwnable(address(hashesToken)).owner(),
            "CollectionNFTCloneableV2: must be contract owner or HashesDAO"
        );
        _;
    }

    modifier onlyCreator() {
        require(_msgSender() == creatorAddress, "CollectionNFTCloneableV2: must be contract creator");
        _;
    }

    /**
     * @notice Constructor for the cloneable Hashes Collection contract. The ERC-721 token
     *         name and symbol aren't used since they are provided in the initialize function.
     */
    constructor() ERC721("TOKEN_NAME_PLACEHOLDER", "TOKEN_SYMBOL_PLACEHOLDER") {}

    receive() external payable {}

    /**
     * @notice This function is used by the Factory to verify the format of ecosystem settings
     * @param _settings ABI encoded ecosystem settings data. This expected encoding for
     *        ecosystem name 'NFT_v1' is the following:
     *
     *        'uint16' hashesDAOMintFeePercent - The percentage of mint fees owable to HashesDAO.
     *        'uint16' hashesDAORoyaltyFeePercent - The percentage of royalties owable to HashesDAO. This will
     *                 be the percentage of the royalties percent set by the creator.
     *        'uint16' maximumCollectionRoyaltyPercent - The highest allowable royalty percentage
     *                 settable by creators for cloned instances of this contract.
     * @return The boolean result of the validation.
     */
    function verifyEcosystemSettings(bytes memory _settings) external pure override returns (bool) {
        (
            uint16 _settingsHashesDAOMintFeePercent,
            uint16 _settingsHashesDAORoyaltyFeePercent,
            uint16 _settingsMaximumCollectionRoyaltyPercent
        ) = abi.decode(_settings, (uint16, uint16, uint16));

        return
            _settingsHashesDAOMintFeePercent <= 10000 &&
            _settingsHashesDAORoyaltyFeePercent <= 10000 &&
            _settingsMaximumCollectionRoyaltyPercent <= 10000;
    }

    /**
     * @notice This function initializes a cloneable implementation contract.
     * @param _hashesToken The Hashes NFT contract address.
     * @param _factoryMaintainerAddress The address of the current factory maintainer
     *        which will be the Owner role of this collection.
     * @param _createCollectionCaller The address which has called createCollection on the factory.
     *        This will be the Creator role of this collection.
     * @param _initializationData ABI encoded initialization data. This expected encoding is a struct
     *        with the following properties:
     *
     *        'string' tokenName - The name of the resulting ERC-721 token.
     *        'string' tokenSymbol - The symbol of the resulting ERC-721 token.
     *        'address' TokenURIPredicateContract - The address of a contract which contains a
     *                  function getTokenURI(uint256 _tokenId, uint256 _hashesTokenId, bytes32 _hashesHash) used to
     *                  draw/define the chosen Hashes token URI. Contracts
     *                  which define this logic should implement the interface ICollectionNFTTokenURIPredicate.
     *        'uint256' cap - The maximum token supply of the resulting ERC-721 token. Set 0 for no limit.
     *        'address' mintEligibilityPredicateContract - The address of a contract which contains a
     *                  function isTokenEligibleToMint(uint256 tokenId, uint256 hashesTokenId) used to
     *                  determine whether the chosen Hashes token ID is eligible for minting. Contracts
     *                  which define this logic should implement the interface ICollectionNFTEligibilityPredicate.
     *        'address' mintFeePredicateContract - The address of a contract which contains a function
     *                  getTokenMintFee(tokenId, hashesTokenId) used to determine the mint fee for the
     *                  chosen Hashes token ID. Contracts which define this logic should implement the
     *                  interface ICollectionNFTMintFeePredicate.
     *        'uint16' royaltyBps - The sales royalty that should be collected. A percentage of this
     *                 will be allocated for the HashesDAO to withdraw.
     *        'address' signatureBlockAddress - An optional address which can be used to establish
     *                  creator provenance. When set, the specified address (could be the artist for example)
     *                  can call completeSignatureBlock to establish provenance and sign off on the contract
     *                  values. To skip using this mechanism, set the value of this field to the 0x0 address.
     */
    function initialize(
        IHashes _hashesToken,
        address _factoryMaintainerAddress,
        address _createCollectionCaller,
        bytes memory _initializationData
    ) external override {
        require(!_initialized, "CollectionNFTCloneableV2: already inititialized.");

        initializeOwnership(_factoryMaintainerAddress);
        creatorAddress = _createCollectionCaller;

        // Use this struct workaround to get around Stack Too Deep issues
        InitializerSettings memory _initializerSettings;
        (_initializerSettings) = abi.decode(_initializationData, (InitializerSettings));
        tokenName = _initializerSettings.tokenName;
        tokenSymbol = _initializerSettings.tokenSymbol;
        TokenURIPredicateContract = _initializerSettings.TokenURIPredicateContract;
        cap = _initializerSettings.cap;
        mintEligibilityPredicateContract = _initializerSettings.mintEligibilityPredicateContract;
        mintFeePredicateContract = _initializerSettings.mintFeePredicateContract;
        royaltyBps = _initializerSettings.royaltyBps;
        signatureBlockAddress = _initializerSettings.signatureBlockAddress;

        uint64 _initializationBlock = safe64(block.number, "CollectionNFTCloneableV2: exceeds 64 bits.");
        bytes memory settingsBytes = ICollectionFactory(_msgSender()).getEcosystemSettings(
            keccak256(abi.encodePacked("NFT_v1")),
            _initializationBlock
        );

        (_hashesDAOMintFeePercent, _hashesDAORoyaltyFeePercent, _maximumCollectionRoyaltyPercent) = abi.decode(
            settingsBytes,
            (uint16, uint16, uint16)
        );

        require(
            royaltyBps <= _maximumCollectionRoyaltyPercent,
            "CollectionNFTCloneableV2: royalty percentage must be less than or equal to maximum allowed setting"
        );

        _initialized = true;

        hashesToken = _hashesToken;

        emit CollectionInitialized(
            tokenName,
            tokenSymbol,
            address(TokenURIPredicateContract),
            cap,
            address(mintEligibilityPredicateContract),
            address(mintFeePredicateContract),
            royaltyBps,
            signatureBlockAddress,
            _initializationBlock
        );
    }

    //This function draws the URI from the TokenURIPredicateContract
    function draw(uint256 tokenId) public view returns (string memory) {

        //The mapping must exist
        require(
            tokenCollectionIdToHashesIdMapping[tokenId].exists,
            "CollectionNFTCloneableV2: Invalid Token Id"
        );

        //Pulls the token URI from the predicate contract
        return TokenURIPredicateContract.getTokenURI(tokenId, tokenCollectionIdToHashesIdMapping[tokenId].hashesId, tokenCollectionIdToHashesIdMapping[tokenId].hashesHash);
    } 

    /**
     * @notice The function used to mint instances of this Hashes Collection ERC-721 token.
     *         Minting requires passing in a specific Hashes token id which is owned by the minter.
     *         Each Hashes token id may only be used to mint once towards a specific collection.
     *         The minting eligibility and fee structure are determined per Hashes token id
     *         by the Hashes Collection owner through predicate functions. The Hashes DAO will receive
     *         a minting fee percentage of each mint, unless a DAO hash was used to mint.
     * @param _hashesTokenId The Hashes token Id being used to mint.
     */
    function mint(uint256 _hashesTokenId) external payable override initialized nonReentrant {
        require(cap == 0 || nonce < cap, "CollectionNFTCloneableV2: supply cap has been reached");
        require(
            _msgSender() == hashesToken.ownerOf(_hashesTokenId),
            "CollectionNFTCloneableV2: must be owner of supplied hashes token ID to mint"
        );
        require(
            !hashesIdToCollectionTokenIdMapping[_hashesTokenId].exists,
            "CollectionNFTCloneableV2: supplied token ID has already been used to mint with this collection"
        );

        // get mint eligibility through static call
        bool isHashesTokenIdEligibleToMint = mintEligibilityPredicateContract.isTokenEligibleToMint(
            nonce,
            _hashesTokenId
        );
        require(isHashesTokenIdEligibleToMint, "CollectionNFTCloneableV2: supplied token ID is ineligible to mint");

        // get mint fee through static call
        uint256 currentMintFee = mintFeePredicateContract.getTokenMintFee(nonce, _hashesTokenId);
        require(msg.value >= currentMintFee, "CollectionNFTCloneableV2: must pass sufficient mint fee.");

        hashesIdToCollectionTokenIdMapping[_hashesTokenId] = TokenIdEntry({
            exists: true,
            tokenId: safe128(nonce, "CollectionNFTCloneableV2: exceeds 128 bits.")
        });

        uint256 feeForHashesDAO = (currentMintFee.mul(_hashesDAOMintFeePercent)) / 10000;
        uint256 authorFee = currentMintFee.sub(feeForHashesDAO);

        uint256 mintFeePaid;
        if (authorFee > 0) {
            // If the minting fee is non-zero
            mintFeePaid = mintFeePaid.add(authorFee);

            (bool sent, ) = creatorAddress.call{ value: authorFee }("");
            require(sent, "CollectionNFTCloneableV2: failed to send ETH to creator address");
        }

        // Only apply the minting tax for non-DAO hashes (tokenID >= 1000 or deactivated DAO tokens)
        if (feeForHashesDAO > 0 && (_hashesTokenId >= 1000 || hashesToken.deactivated(_hashesTokenId))) {
            // If the hashes DAO minting fee is non-zero

            // Send minting tax to HashesDAO
            (bool sent, ) = IOwnable(address(hashesToken)).owner().call{ value: feeForHashesDAO }("");
            require(sent, "CollectionNFTCloneableV2: failed to send ETH to HashesDAO");

            mintFeePaid = mintFeePaid.add(feeForHashesDAO);
        }

        if (msg.value > mintFeePaid) {
            // If minter passed ETH value greater than the minting
            // fee paid/computed above

            // Refund the remaining ether balance to the sender. Since there are no
            // other payable functions, this remainder will always be the senders.
            (bool sent, ) = _msgSender().call{ value: msg.value.sub(mintFeePaid) }("");
            require(sent, "CollectionNFTCloneableV2: failed to refund ETH.");
        }

        // get hashes hash through static call
        // I tried to pull this data from the URI predicate contracts I made but I couldn't figure out how, so here we are...
        bytes32 _hashesHash = hashesToken.getHash(_hashesTokenId);

        // map collection NFT id to the minting hashes id
        // this is important for the draw function
        tokenCollectionIdToHashesIdMapping[nonce] = idToHash({
            exists: true,
            hashesId: _hashesTokenId,
            hashesHash: _hashesHash
        });

        _safeMint(_msgSender(), nonce++);

        emit Minted(_msgSender(), nonce - 1, _hashesTokenId);
    }

    /**
     * @notice The function allows the token owner or approved address to burn the token.
     * @param _tokenId The token Id to be burned.
     */
    function burn(uint256 _tokenId) external override initialized {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "CollectionNFTCloneableV2: caller is not owner nor approved."
        );
        _burn(_tokenId);

        emit Burned(_msgSender(), _tokenId);
    }

    /**
     * @notice The signatureBlockAddress can call this function to establish provenance and effectively
     *         sign off on the contract. Can be useful in cases where the creator address is different
     *         from the artist address.
     */
    function completeSignatureBlock() external override initialized {
        require(!isSignatureBlockCompleted, "CollectionNFTCloneableV2: signature block has already been completed");
        require(
            signatureBlockAddress != address(0),
            "CollectionNFTCloneableV2: signature block address has not been set."
        );
        require(
            _msgSender() == signatureBlockAddress,
            "CollectionNFTCloneableV2: only signature block address can complete signature block"
        );
        isSignatureBlockCompleted = true;

        emit SignatureBlockCompleted(signatureBlockAddress);
    }

    /// @inheritdoc IERC2981Royalties
    function royaltyInfo(uint256, uint256 value)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        // Send royalties to this contract address. Note: this will only work for
        // marketplaces which implement the ERC2981 royalty standard. Off-chain
        // configuration may be required for certain marketplaces.
        return (address(this), (value.mul(royaltyBps)).div(10000));
    }

    /**
     * @notice The function used to renounce contract ownership. This can be performed
     *         by either the Owner or HashesDAO. This departs slightly from the traditional
     *         implementation where only the Owner has this permission. HashesDAO may
     *         need to perform this actions in the case of the factory maintainer changing,
     *         getting lost, or being taken over by a bad actor.
     */
    function renounceOwnership() public override ownershipInitialized onlyOwnerOrHashesDAO {
        _setOwner(address(0));
    }

    /**
     * @notice The function used to transfer contract ownership. This can be performed by
     *         either the owner or HashesDAO. This departs slightly from the traditional
     *         implementation where only the Owner has this permission. HashesDAO may
     *         need to perform this actions in the case of the factory maintainer changing,
     *         getting lost, or being taken over by a bad actor.
     * @param newOwner The new owner address.
     */
    function transferOwnership(address newOwner) public override ownershipInitialized onlyOwnerOrHashesDAO {
        require(newOwner != address(0), "CollectionNFTCloneableV2: new owner is the zero address");
        _setOwner(newOwner);
    }

    /**
     * @notice The function used to set the sales royalty bps. Only collection creator may call.
     * @param _royaltyBps The sales royalty percent in hundredths of a percent.
     */
    function setRoyaltyBps(uint16 _royaltyBps) external override initialized onlyCreator {
        require(
            _royaltyBps <= _maximumCollectionRoyaltyPercent,
            "CollectionNFTCloneableV2: royalty percentage must be less than or equal to maximum allowed setting"
        );
        royaltyBps = _royaltyBps;
        emit RoyaltyBpsSet(_royaltyBps);
    }

    /**
     * @notice The function used to transfer the creator address. Only collection creator may call.
     *         This is especially important since this concerns withdrawl permissions.
     * @param _creatorAddress The new creator address.
     */
    function transferCreator(address _creatorAddress) external override initialized onlyCreator {
        address oldCreator = creatorAddress;
        creatorAddress = _creatorAddress;
        emit CreatorTransferred(oldCreator, _creatorAddress);
    }

    function setSignatureBlockAddress(address _signatureBlockAddress) external override initialized onlyCreator {
        require(!isSignatureBlockCompleted, "CollectionNFTCloneableV2: signature block has already been completed");
        signatureBlockAddress = _signatureBlockAddress;
        emit SignatureBlockAddressSet(_signatureBlockAddress);
    }

    /**
     * @notice The function used to withdraw funds to the Collection creator and HashesDAO addresses.
     *         The balance of the contract is equal to the royalties and gifts owed to the creator and HashesDAO.
     */
    function withdraw() external override initialized {
        // The contract balance is equal to the royalties or gifts which need to be allocated
        // to both the creator and HashesDAO.
        uint256 _contractBalance = address(this).balance;

        // The amount owed to the DAO will be the total royalties times the royalty
        // fee percent value (in bps).
        uint256 _daoRoyaltiesOwed = (_contractBalance.mul(_hashesDAORoyaltyFeePercent)).div(10000);

        // The amount owed to the creator will then be the total balance of the contract minus the DAO
        // royalties owed.
        uint256 _creatorRoyaltiesOwed = _contractBalance.sub(_daoRoyaltiesOwed);

        if (_creatorRoyaltiesOwed > 0) {
            (bool sent, ) = creatorAddress.call{ value: _creatorRoyaltiesOwed }("");
            require(sent, "CollectionNFTCloneableV2: failed to send ETH to creator address");
        }

        if (_daoRoyaltiesOwed > 0) {
            (bool sent, ) = IOwnable(address(hashesToken)).owner().call{ value: _daoRoyaltiesOwed }("");
            require(sent, "CollectionNFTCloneableV2: failed to send ETH to HashesDAO");
        }

        emit Withdraw(_creatorRoyaltiesOwed, _daoRoyaltiesOwed);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable) returns (bool) {
        return interfaceId == type(IERC2981Royalties).interfaceId || ERC721Enumerable.supportsInterface(interfaceId);
    }

    /**
     * @notice The function used to get the Hashes Collection token URI.
     * @param _tokenId The Hashes Collection token Id.
     */
    function tokenURI(uint256 _tokenId) public view override initialized returns (string memory) {
        // Ensure that the token ID is valid and that the hash isn't empty.
        require(_tokenId < nonce, "CollectionNFTCloneableV2: Can't provide a token URI for a non-existent collection.");

        return draw(_tokenId);
    }

    /**
     * @notice The function used to get the name of the Hashes Collection token
     */
    function name() public view override initialized returns (string memory) {
        return tokenName;
    }

    /**
     * @notice The function used to get the symbol of the Hashes Collection token
     */
    function symbol() public view override initialized returns (string memory) {
        return tokenSymbol;
    }

    function safe64(uint256 n, string memory errorMessage) internal pure returns (uint64) {
        require(n < 2**64, errorMessage);
        return uint64(n);
    }

    function safe128(uint256 n, string memory errorMessage) internal pure returns (uint128) {
        require(n < 2**128, errorMessage);
        return uint128(n);
    }
}