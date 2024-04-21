// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 *
 *  NNNNNNNN        NNNNNNNNFFFFFFFFFFFFFFFFFFFFFFTTTTTTTTTTTTTTTTTTTTTTTFFFFFFFFFFFFFFFFFFFFFFlllllll                                                   iiii                    
 *  N:::::::N       N::::::NF::::::::::::::::::::FT:::::::::::::::::::::TF::::::::::::::::::::Fl:::::l                                                  i::::i                   
 *  N::::::::N      N::::::NF::::::::::::::::::::FT:::::::::::::::::::::TF::::::::::::::::::::Fl:::::l                                                   iiii                    
 *  N:::::::::N     N::::::NFF::::::FFFFFFFFF::::FT:::::TT:::::::TT:::::TFF::::::FFFFFFFFF::::Fl:::::l                                                                           
 *  N::::::::::N    N::::::N  F:::::F       FFFFFFTTTTTT  T:::::T  TTTTTT  F:::::F       FFFFFF l::::l     eeeeeeeeeeee    xxxxxxx      xxxxxxx        iiiiiii nnnn  nnnnnnnn    
 *  N:::::::::::N   N::::::N  F:::::F                     T:::::T          F:::::F              l::::l   ee::::::::::::ee   x:::::x    x:::::x         i:::::i n:::nn::::::::nn  
 *  N:::::::N::::N  N::::::N  F::::::FFFFFFFFFF           T:::::T          F::::::FFFFFFFFFF    l::::l  e::::::eeeee:::::ee  x:::::x  x:::::x           i::::i n::::::::::::::nn 
 *  N::::::N N::::N N::::::N  F:::::::::::::::F           T:::::T          F:::::::::::::::F    l::::l e::::::e     e:::::e   x:::::xx:::::x            i::::i nn:::::::::::::::n
 *  N::::::N  N::::N:::::::N  F:::::::::::::::F           T:::::T          F:::::::::::::::F    l::::l e:::::::eeeee::::::e    x::::::::::x             i::::i   n:::::nnnn:::::n
 *  N::::::N   N:::::::::::N  F::::::FFFFFFFFFF           T:::::T          F::::::FFFFFFFFFF    l::::l e:::::::::::::::::e      x::::::::x              i::::i   n::::n    n::::n
 *  N::::::N    N::::::::::N  F:::::F                     T:::::T          F:::::F              l::::l e::::::eeeeeeeeeee       x::::::::x              i::::i   n::::n    n::::n
 *  N::::::N     N:::::::::N  F:::::F                     T:::::T          F:::::F              l::::l e:::::::e               x::::::::::x             i::::i   n::::n    n::::n
 *  N::::::N      N::::::::NFF:::::::FF                 TT:::::::TT      FF:::::::FF           l::::::le::::::::e             x:::::xx:::::x           i::::::i  n::::n    n::::n
 *  N::::::N       N:::::::NF::::::::FF                 T:::::::::T      F::::::::FF           l::::::l e::::::::eeeeeeee    x:::::x  x:::::x   ...... i::::::i  n::::n    n::::n
 *  N::::::N        N::::::NF::::::::FF                 T:::::::::T      F::::::::FF           l::::::l  ee:::::::::::::e   x:::::x    x:::::x  .::::. i::::::i  n::::n    n::::n
 *  NNNNNNNN         NNNNNNNFFFFFFFFFFF                 TTTTTTTTTTT      FFFFFFFFFFF           llllllll    eeeeeeeeeeeeee  xxxxxxx      xxxxxxx ...... iiiiiiii  nnnnnn    nnnnnn
 *  
 */

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTFlex is ERC721, ReentrancyGuard, Ownable {
  
    struct TokenNFTDetail {
        address externalContractAddress;        
        uint256 externalTokenId;
        bool isERC1155;
    }

    // Max supply for the tokens
    uint256 constant public MAX_SUPPLY = 1064;

    // Types of tokens available 
    uint256 constant TYPE_BRONZE = 1;
    uint256 constant TYPE_SILVER = 2;
    uint256 constant TYPE_GOLD = 3;
    uint256 constant TYPE_PLATINUM = 4;

    uint256 private _currentSupply; // Count of minted tokens
    mapping(uint256 => uint256) private _typePrice; // Stores price for block type
    mapping(uint256 => TokenNFTDetail) public _tokenNFTDetail; // Stores configuration for a specific token
    mapping(address => mapping(uint256 => bool)) private _blockedNFTTokens; // Stores blocked tokens to prevent inappropriate NFT's on the board
    bool internal _preSaleMinted; // Prevents public mint until Flex has minted giveaway spaces

    /**
     * @dev ConfigureBlock event. 
     *
     * Used to store dynamic content specific for the 
     * block
     */
    event ConfigureBlock (
        uint256 indexed tokenId,
        string data
    );

    /**
     * @dev ConfigureSidebar event. 
     *
     * Used to store dynamic content specific for the 
     * block sidebar
     */
    event ConfigureSidebar (
        uint256 indexed tokenId,
        string data
    );

    /**
     * @dev Require msg.sender to own the token for given id
     *
     * @param id_ uint256 token id to be checked
     */
    modifier flexOwnerOnly(uint256 id_) {
        require(ownerOf(id_) == _msgSender(), "ONLY_OWNERS_ALLOWED");
        _;
    }

    /**
     * @dev Constructor
     *
     * @param name_ token name
     * @param symbol_ token symbol
     * @param name_ token name
     * @param bronze_ bronze token price
     * @param silver_ silver token price
     * @param gold_ gold token price
     * @param platinum_ platinum token price
     */
    constructor(
        string memory name_, 
        string memory symbol_,
        uint256 bronze_, 
        uint256 silver_, 
        uint256 gold_, 
        uint256 platinum_
    ) ERC721(name_, symbol_) {
        _typePrice[TYPE_BRONZE] = bronze_;
        _typePrice[TYPE_SILVER] = silver_;
        _typePrice[TYPE_GOLD] = gold_;
        _typePrice[TYPE_PLATINUM] = platinum_;    
    }

    /**
     * @dev to receive eth
     */
    receive() external payable {}

    /**
     * @dev flexOwnerOnly function to configure a token sidebar dynamic data
     *
     * @param nftFlexTokenId uint256 flex token id
     * @param data string dynamic data to be stored in an event
     */
    function configureSidebar(
        uint256 nftFlexTokenId, 
        string calldata data
    ) 
        external 
        flexOwnerOnly(nftFlexTokenId) 
    {
        emit ConfigureSidebar(nftFlexTokenId, data);
    }

    /**
     * @dev Returns the token data for all 1064 tokens, token id = index + 1
     *
     * @return exists bool[] indicates if the token has been minted
     * @return initialised bool[] indicates if the token has been assigned a token
     * @return addressOwnsNFT bool[] indicates if the owner of the token still owns the configured NFT
     * @return nftBlocked bool[] indicates if NFTFlex.in have blocked the configured NFT
     * @return url string metadata[] url for the token
     * @return flexOwner address[] token id owner
     */
    function getAllTokenData() 
        external 
        view 
        returns 
        (   
            bool[] memory exists, 
            bool[] memory initialised, 
            bool[] memory addressOwnsNFT, 
            bool[] memory nftBlocked, 
            string[] memory url, 
            address[] memory flexOwner
        ) 
    {
        exists = new bool[](MAX_SUPPLY);
        initialised = new bool[](MAX_SUPPLY);
        addressOwnsNFT = new bool[](MAX_SUPPLY);
        nftBlocked = new bool[](MAX_SUPPLY);
        url = new string[](MAX_SUPPLY);
        flexOwner = new address[](MAX_SUPPLY);
        for(uint i = 0; i < MAX_SUPPLY; i++) {
            (
                bool exist, 
                bool init, 
                bool addOwnsNFT, 
                bool blocked, 
                string memory tokenUrl, 
                address ownedBy
            ) = getTokenData(i+1);
            exists[i] = exist;
            initialised[i] = init;
            addressOwnsNFT[i] = addOwnsNFT;
            nftBlocked[i] = blocked;
            url[i] = tokenUrl;
            flexOwner[i] = ownedBy;
        }
    }

    /**
     * @dev flexOwnerOnly function to block any external token deemed inappropriate
     *
     * @param nftTokenId uint256 flex token id
     */
    function blockExternalNFT(uint256 nftTokenId) onlyOwner external {
        _blockedNFTTokens[_tokenNFTDetail[nftTokenId].externalContractAddress][_tokenNFTDetail[nftTokenId].externalTokenId] = true;
    }

    /**
     * @dev Returns the price list for the available token types
     *
     * @return bronze price for the bronze token type
     * @return silver price for the silver token type
     * @return gold price for the gold token type
     * @return platinum price for the platinum token type
     */
    function getPriceList() 
        external 
        view 
        returns (
            uint256 bronze, 
            uint256 silver, 
            uint256 gold, 
            uint256 platinum
        ) 
    {
        bronze = _typePrice[TYPE_BRONZE];
        silver = _typePrice[TYPE_SILVER];
        gold = _typePrice[TYPE_GOLD];
        platinum = _typePrice[TYPE_PLATINUM];    
    }

    /**
     * @dev Public mint function, single token per tx
     *      This function can only be called after the ownerMint
     *
     * @param tokenId uint256 token id to mint
     */
    function mint(uint tokenId) external payable nonReentrant {
        require(_preSaleMinted, "No presale");
        require(MAX_SUPPLY >= tokenId, "Token id out of range");
        (,uint price )= getTokenTypeAndPriceById(tokenId);
        require(msg.value >= price, "Sent eth incorrect");
        _safeMint(msg.sender, tokenId);
        _currentSupply = _currentSupply + 1;
    }

    /**
     * @dev Owner only function to pre sale mint tokens without the need for eth
     *      This function must be called before the public mint can take place
     *
     * @param tokenIds uint256[] token ids to mint
     */
    function ownerMint(uint[] memory tokenIds) external onlyOwner {
        require(!_preSaleMinted, "Already Minted");
        
        for(uint i = 0; i < tokenIds.length; i++) {            
            _safeMint(_msgSender(), tokenIds[i]);
            _currentSupply = _currentSupply + 1;
        }
        _preSaleMinted = true;
    }

    /**
     * @dev flexOwnerOnly to configure an NFT flex space
     *
     * @param nftContractAddress address external NFT contract address
     * @param externalTokenId uint256 token id of the external contract address
     * @param nftFlexTokenId uint256 flex token id
     * @param isERC1155 bool is ERC1155 if false default ERC721
     * @param data string dynamic data to be stored in an event
     */
    function setNFTTokenDetail(
        address nftContractAddress, 
        uint256 externalTokenId, 
        uint256 nftFlexTokenId, 
        bool isERC1155, 
        string calldata data
    ) 
        external 
        flexOwnerOnly(nftFlexTokenId) 
    {
        require(
            ownsNFT(_msgSender(), nftContractAddress, externalTokenId, isERC1155),
            "SENDER_NOT_OWN_EXTERNAL_TOKEN"
        );
        require(
            !_blockedNFTTokens[nftContractAddress][externalTokenId], 
            "BLOCKED_NFT"
        );
        require(
            !(
                _tokenNFTDetail[nftFlexTokenId].externalContractAddress == nftContractAddress 
                && _tokenNFTDetail[nftFlexTokenId].externalTokenId == externalTokenId
            ), 
            "SAME_TOKEN"
        );
        _tokenNFTDetail[nftFlexTokenId].externalContractAddress = nftContractAddress;
        _tokenNFTDetail[nftFlexTokenId].externalTokenId = externalTokenId;
        _tokenNFTDetail[nftFlexTokenId].isERC1155 = isERC1155;

        // if this fails NFTFlex.in will not support the contract
        isERC1155 
                ? IERC1155MetadataURI(nftContractAddress).uri(externalTokenId)
                : IERC721Metadata(nftContractAddress).tokenURI(externalTokenId);

        emit ConfigureBlock(nftFlexTokenId, data);
    }

    /**
     * @dev Sets a new price for a given token price
     *
     * @param ethVal new price
     * @param tokenType token type for the new price
     */
    function setPrice(uint256 ethVal, uint256 tokenType) external onlyOwner {
        _typePrice[tokenType] = ethVal;
    }

    /**
     * @dev onlyOwner function to override user submitted content
     *
     * @param nftFlexTokenId uint256 flex token id
     */
    function setSidebarData(uint256 nftFlexTokenId) onlyOwner external {
        emit ConfigureSidebar(nftFlexTokenId, "");
    }

    /**
     * @dev Returns the current total supply
     */
    function totalSupply() external view returns (uint256) {
        return _currentSupply;
    }

    /**
     * @dev flexOwnerOnly function to reverse a block on an external NFT
     *
     * @param nftContractAddress address external contract address
     * @param tokenId uint256 external token id
     */
    function unblockExternalNFT(address nftContractAddress, uint256 tokenId) onlyOwner external {
        _blockedNFTTokens[nftContractAddress][tokenId] = false;
    }
    
    /**
     * @dev withdraws the eth from the contract to the treasury
     *
     * @param treasury_ treasury address for the eth to be sent to
     */
    function withdraw(address treasury_) external onlyOwner nonReentrant {
		payable(treasury_).transfer(address(this).balance);
	}

    /**
     * @dev Returns the token data for supplied token id
     *
     * @param nftTokenId uint256 token id to lookup
     *
     * @return exists bool indicates if the token has been minted
     * @return initialised bool indicates if the token has been assigned a token
     * @return addressOwnsNFT bool indicates if the owner of the token still owns the configured NFT
     * @return nftBlocked bool indicates if NFTFlex.in have blocked the configured NFT
     * @return url string metadata url for the token
     * @return flexOwner address token id owner
     */
    function getTokenData(
        uint256 nftTokenId
    ) 
        public 
        view 
        returns (
            bool exists, 
            bool initialised, 
            bool addressOwnsNFT, 
            bool nftBlocked, 
            string memory url, 
            address flexOwner
        ) 
    {
        exists = _exists(nftTokenId);
        initialised = exists && _tokenNFTDetail[nftTokenId].externalContractAddress != address(0);
        if(exists && initialised) {
            addressOwnsNFT = ownsNFT(
                ownerOf(nftTokenId), 
                _tokenNFTDetail[nftTokenId].externalContractAddress, _tokenNFTDetail[nftTokenId].externalTokenId, 
                _tokenNFTDetail[nftTokenId].isERC1155
            );
            nftBlocked = _blockedNFTTokens[_tokenNFTDetail[nftTokenId].externalContractAddress]
                                [_tokenNFTDetail[nftTokenId].externalTokenId];            
            if(addressOwnsNFT && !nftBlocked) {
                url = _tokenNFTDetail[nftTokenId].isERC1155 
                    ? IERC1155MetadataURI(_tokenNFTDetail[nftTokenId].externalContractAddress).uri(_tokenNFTDetail[nftTokenId].externalTokenId)
                    : IERC721Metadata(_tokenNFTDetail[nftTokenId].externalContractAddress).tokenURI(_tokenNFTDetail[nftTokenId].externalTokenId);
            } else {
                initialised = false;
            }
            
        }
        if(exists) {
            flexOwner = ownerOf(nftTokenId);
        }
    }
    
    /**
     * @dev Returns a token type for a token id
     *
     * @param tokenId uint256 token id lookup
     */
    function getTokenTypeAndPriceById(uint tokenId) public view returns(uint tokenType, uint price) {
        if( tokenId == 1 || tokenId == 134 || tokenId == 267 || tokenId == 400 ||
            tokenId == 533 || tokenId == 666 || tokenId == 799 || tokenId == 932 ) {
            tokenType = TYPE_PLATINUM;
            price = _typePrice[TYPE_PLATINUM];
        }

        if ((tokenId >= 981 && tokenId <= 1064) || (tokenId >= 848 && tokenId <= 931) || 
            (tokenId >= 715 && tokenId <= 798) || (tokenId >= 582 && tokenId <= 665) || 
            (tokenId >= 449 && tokenId <= 532) || (tokenId >= 316 && tokenId <= 399) || 
            (tokenId >= 183 && tokenId <= 266) || (tokenId >= 50 && tokenId <= 133) ) {
            tokenType = TYPE_BRONZE;
            price = _typePrice[TYPE_BRONZE];
        }

        if ((tokenId >= 945 && tokenId <= 980) || (tokenId >= 812 && tokenId <= 847) || 
            (tokenId >= 679 && tokenId <= 714) || (tokenId >= 546 && tokenId <= 581) || 
            (tokenId >= 413 && tokenId <= 448) || (tokenId >= 280 && tokenId <= 315) || 
            (tokenId >= 147 && tokenId <= 182) || (tokenId >= 14 && tokenId <= 49) ) {
            tokenType = TYPE_SILVER;
            price = _typePrice[TYPE_SILVER];
        }

        if ((tokenId >= 933 && tokenId <= 944) || (tokenId >= 800 && tokenId <= 811) || 
            (tokenId >= 667 && tokenId <= 678) || (tokenId >= 534 && tokenId <= 545) || 
            (tokenId >= 401 && tokenId <= 412) || (tokenId >= 268 && tokenId <= 279) || 
            (tokenId >= 135 && tokenId <= 146) || (tokenId >= 2 && tokenId <= 13) ) {            
            tokenType = TYPE_GOLD;
            price = _typePrice[TYPE_GOLD];
        }
        
        //failed to find 
        require(price != 0, "unknown token id");
    }

    /**
     * @dev checks if an address us an owner of a specific token
     *
     * @param ownerAddress address address to query the ownership
     * @param nftContractAddress address external contract address
     * @param nftTokenId uint256 external token id
     * @param isERC1155 bool is ERC1155 if false default ERC721
     */
    function ownsNFT(
        address ownerAddress, 
        address nftContractAddress, 
        uint256 nftTokenId, 
        bool isERC1155
    ) 
        public 
        view 
        returns (
            bool
        ) 
    {
        return isERC1155 
            ? IERC1155(nftContractAddress).balanceOf(ownerAddress, nftTokenId) > 0
            : IERC721(nftContractAddress).ownerOf(nftTokenId) == ownerAddress;
    }

    /**
     * @dev Override ERC721._baseURI() to return our metadata URL
     *
     * @return string metadata URL
     */
    function _baseURI() internal override view virtual returns (string memory) {
        return "ipfs://Qmenc8AWUN7DHzyU5Z6wMxc5p2PKCUmP3WeFGNgj5Ukktv/";
    }    

    /**
     * @dev _beforeTokenTransfer hook to reset flex token data
     * 
     * @param from address current owner address
     * @param to address new owner address
     * @param tokenId uint256 token id
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // On transfer clear down the previous owners details
        delete _tokenNFTDetail[tokenId];
        emit ConfigureSidebar(tokenId, "");
        emit ConfigureBlock(tokenId, "");
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
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
 * @dev Collection of functions related to the address type
 */
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
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

// SPDX-License-Identifier: MIT

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

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
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

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

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