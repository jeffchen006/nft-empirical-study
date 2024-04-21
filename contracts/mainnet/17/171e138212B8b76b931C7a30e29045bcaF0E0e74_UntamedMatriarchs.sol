// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/************************
 * @author: squeebo_nft *
 ************************/

import "./Blimpie/Delegated.sol";
import "./Blimpie/ERC721EnumerableLite.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

interface IERC721Proxy{
  function balanceOf( address owner ) external view returns ( uint );
  function ownerOf( uint tokenId ) external view returns ( address owner );
  function walletOfOwner( address owner ) external view returns ( uint[] calldata );
}

interface GFInterface {
  function groupBalances(uint id, address owner) external view returns (uint);
}

contract UntamedMatriarchs is Delegated, ERC721EnumerableLite {
  using Strings for uint;

  uint public MAX_ORDER  = 20;
  uint public MAX_SUPPLY = 7000;
  address public GF_CONTRACT = 0x8744C9F3C2DCA15b306fEFCB1175Ecb22Ecbe01F;
  address public UE_CONTRACT = 0x613E5136a22206837D12eF7A85f7de2825De1334;
  address public UC_CONTRACT = 0x7870cc63b6B1AF0AED0D6Dd7c1eFB39300b773eB;

  uint public basePrice = 0.030 ether;
  uint public discPrice = 0.035 ether;
  uint public fullPrice = 0.040 ether;
  
  bool public isPaidsaleActive;
  bool public isWhitelistActive;
  bool public isUntamedActive;

  mapping( uint => bool ) public isUsedUE;
  mapping( uint => bool ) public isUsedUC;
  mapping( address => uint ) public wlClaim;

  string private _tokenURIPrefix = '';
  string private _tokenURISuffix = '';

  constructor()
    Delegated()
    ERC721B( "Untamed Matriarchs", "UM", 0 ){
  }

  //external
  fallback() external payable {}
  receive() external payable {}

  function tokenURI(uint tokenId) external view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
    return string(abi.encodePacked(_tokenURIPrefix, tokenId.toString(), _tokenURISuffix));
  }

  /**
   * (1) Phase 1: Public Sale
   **/
  function mint( uint quantity ) external payable{
    require( isPaidsaleActive,                 "Paid sale is not active" );
    require( quantity <= MAX_ORDER,            "Order too big"           );

    uint supply = totalSupply();
    require( supply + quantity <= MAX_SUPPLY,  "Order exceeds supply"    );

    uint grapes;
    uint elephants = _countElephants( msg.sender );
    if( elephants < 10 ){
      grapes = _countGrapes( msg.sender );
    }

    uint price = fullPrice;
    if( elephants >= 10 || grapes >= 5 )
      price = basePrice;
    else if( elephants > 0 || grapes > 0 )
      price = discPrice;

    require( msg.value >= price * quantity, "Ether sent is not correct" );
    for(uint i; i < quantity; ++i){
      _safeMint( msg.sender, supply++, "" );
    }
  }

  /**
   * (2) Phase 2: Whitelist Claim
   **/
  function whitelistClaim( uint quantity ) external {
    require( isWhitelistActive,         "Free claims are not active" );
    require( quantity <= wlClaim[ msg.sender ], "Whitelist expended" );

    uint supply = totalSupply();
    require( supply + quantity <= MAX_SUPPLY,  "Order exceeds supply" );

    wlClaim[ msg.sender ] -= quantity;
    for(uint i; i < quantity; ++i){
      _safeMint( msg.sender, supply++, "" );
    }
  }

  /**
   * (3) Phase 3: Untamed Claim
   **/
  function untamedClaim( uint quantity, uint[] calldata ueTokens, uint[] calldata ucTokens ) external{
    require( isUntamedActive,                 "Presale is not active" );
    require( quantity <= ueTokens.length / 2, "Not enough Elephants (A)" );
    require( quantity <= ucTokens.length,     "Not enough Companions (A)" );

    uint supply = totalSupply();
    require( supply + quantity <= MAX_SUPPLY,   "Order exceeds supply" );
    _requireUeIntersection( ueTokens, quantity * 2 );
    _requireUcIntersection( ucTokens, quantity );

    for(uint i; i < quantity; ++i){
      _safeMint( msg.sender, supply++, "" );
    }
  }

  //delegated
  function mintTo(address[] calldata recipient, uint[] calldata quantity) external payable onlyDelegates {
    require(quantity.length == recipient.length, "Must provide equal quantities and recipients" );

    uint totalQuantity;
    for(uint i; i < quantity.length; ++i){
      totalQuantity += quantity[i];
    }
    uint supply = totalSupply();
    require( totalQuantity + supply <= MAX_SUPPLY, "Mint/order exceeds supply" );

    for(uint i; i < recipient.length; ++i){
      for(uint j; j < quantity[i]; ++j){
        _safeMint( recipient[i], supply++, "" );
      }
    }
  }
  
  function setActive( bool paidsaleActive, bool whitelistActive, bool untamedActive ) external onlyDelegates{
    require( isPaidsaleActive != paidsaleActive ||
      isWhitelistActive != whitelistActive ||
      isUntamedActive != untamedActive, "New values match old" );
    isPaidsaleActive  = paidsaleActive;
    isWhitelistActive = whitelistActive;
    isUntamedActive   = untamedActive;
  }

  function setBaseURI(string calldata newBaseURI, string calldata newSuffix) external onlyDelegates{
    _tokenURIPrefix = newBaseURI;
    _tokenURISuffix = newSuffix;
  }

  function setContracts( address gfAddress, address ueAddress, address ucAddress ) external onlyDelegates {
    require( GF_CONTRACT != gfAddress ||
      UE_CONTRACT != ueAddress ||
      UC_CONTRACT != ucAddress, "New values match old" );
    GF_CONTRACT = gfAddress;
    UE_CONTRACT = ueAddress;
    UC_CONTRACT = ucAddress;
  }

  function setMax(uint maxOrder, uint maxSupply) external onlyOwner{
    require( MAX_ORDER  != maxOrder ||
      MAX_SUPPLY != maxSupply,   "New value matches old" );
    require(maxSupply >= totalSupply(), "Specified supply is lower than current balance" );

    MAX_ORDER  = maxOrder;
    MAX_SUPPLY = maxSupply;
  }

  function setPrices( uint basePrice_, uint discPrice_, uint fullPrice_ ) external onlyDelegates {
    require( basePrice != basePrice_ ||
      discPrice != discPrice_ ||
      fullPrice != fullPrice_, "New values match old" );
    basePrice = basePrice_;
    discPrice = discPrice_;
    fullPrice = fullPrice_;
  }

  function setWhitelist( address[] calldata wallets, uint[] calldata quantities ) external onlyDelegates {
    require(wallets.length > 0, "Must provide at least 1 wallet");
    require(wallets.length == quantities.length, "Must provide equal wallets and quantities");
    for( uint i; i < wallets.length; ++i ){
      wlClaim[ wallets[i] ] = quantities[ i ];
    }
  }


  //onlyOwner
  function withdraw() external {
    require(address(this).balance >= 0, "No funds available");
    Address.sendValue(payable(owner()), address(this).balance);
  }


  //private
  function _countElephants( address account ) private view returns( uint ){
    return IERC721Proxy( UE_CONTRACT ).balanceOf( account );
  }

  function _countGrapes( address account ) private view returns( uint ){
    return GFInterface( GF_CONTRACT ).groupBalances( 1, account );
  }

  function _requireUcIntersection(uint[] memory needles, uint needed) private {
    uint needle;
    IERC721Proxy ucProxy = IERC721Proxy( UC_CONTRACT );
    uint[] memory ucWallet = ucProxy.walletOfOwner( msg.sender );
    for(uint i; i < needles.length; ++i ){
      needle = needles[i];
      if( isUsedUC[ needle ] )
        continue;

      bool found;
      for(uint j; j < ucWallet.length; ++j ){
        if( isUsedUC[ ucWallet[j] ] )
          continue;


        if( needle == ucWallet[j] ){
          found = true;
          isUsedUC[ needle ] = true;
          if( --needed == 0 )
            return;
          else
            break;
        }
      }


      if( !found && needle < 7500 ){
        try ucProxy.ownerOf( needle ) returns( address ){}
        catch{
          isUsedUC[ needle ] = true;
          if( --needed == 0 )
            return;
        }
      }
    }

    revert( "Not enough Companions (B)" );
  }

  function _requireUeIntersection(uint[] memory needles, uint needed) private {
    uint needle;
    uint[] memory ucWallet = IERC721Proxy( UE_CONTRACT ).walletOfOwner( msg.sender );
    for(uint i; i < needles.length; ++i ){
      needle = needles[i];
      if( isUsedUE[ needle ] )
        continue;

      for(uint j; j < ucWallet.length; ++j ){
        if( isUsedUE[ ucWallet[j] ] )
          continue;


        if( needle == ucWallet[j] ){
          isUsedUE[ needle ] = true;
          if( --needed == 0 )
            return;
          else
            break;
        }
      }
    }

    revert( "Not enough Elephants (B)" );
  }
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

interface IBatch {
  function isOwnerOf( address account, uint[] calldata tokenIds ) external view returns( bool );
  function transferBatch( address from, address to, uint[] calldata tokenIds, bytes calldata data ) external;
  function walletOfOwner( address account ) external view returns( uint[] memory );
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/****************************************
 * @author: squeebo_nft                 *
 ****************************************
 *   Blimpie-ERC721 provides low-gas    *
 *           mints + transfers          *
 ****************************************/

import "./ERC721B.sol";
import "./IBatch.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

abstract contract ERC721EnumerableLite is ERC721B, IBatch, IERC721Enumerable {
    function isOwnerOf( address account, uint[] calldata tokenIds ) external view virtual override returns( bool ){
        for(uint i; i < tokenIds.length; ++i ){
            if( _owners[ tokenIds[i] ] != account )
                return false;
        }

        return true;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721B) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenOfOwnerByIndex(address owner, uint index) public view override returns (uint tokenId) {
        uint count;
        for( uint i; i < _owners.length; ++i ){
            if( owner == _owners[i] ){
                if( count == index )
                    return i;
                else
                    ++count;
            }
        }

        require(false, "ERC721Enumerable: owner index out of bounds");
    }

    function tokenByIndex(uint index) external view virtual override returns (uint) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return index;
    }

    function totalSupply() public view virtual override( ERC721B, IERC721Enumerable ) returns (uint) {
        return _owners.length - _offset;
    }

    function transferBatch( address from, address to, uint[] calldata tokenIds, bytes calldata data ) external override{
        for(uint i; i < tokenIds.length; ++i ){
            safeTransferFrom( from, to, tokenIds[i], data );
        }
    }

    function walletOfOwner( address account ) external view override returns( uint[] memory ){
        uint quantity = balanceOf( account );
        uint[] memory wallet = new uint[]( quantity );
        for( uint i; i < quantity; ++i ){
            wallet[i] = tokenOfOwnerByIndex( account, i );
        }
        return wallet;
    }
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/****************************************
 * @author: squeebo_nft                 *
 * @team:   GoldenX                     *
 ****************************************
 *   Blimpie-ERC721 provides low-gas    *
 *           mints + transfers          *
 ****************************************/

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

abstract contract ERC721B is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;

    string private _name;
    string private _symbol;

    uint internal _offset;
    address[] internal _owners;

    mapping(uint => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    constructor(string memory name_, string memory symbol_, uint offset) {
        _name = name_;
        _symbol = symbol_;
        _offset = offset;
        for(uint i; i < _offset; ++i ){
            _owners.push(address(0));
        }
    }

    //public
    function balanceOf(address owner) public view virtual override returns (uint) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        uint count;
        for( uint i; i < _owners.length; ++i ){
          if( owner == _owners[i] )
            ++count;
        }
        return count;
    }

    function name() external view virtual override returns (string memory) {
        return _name;
    }

    function ownerOf(uint tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    function totalSupply() public view virtual returns (uint) {
        return _owners.length - _offset;
    }


    function approve(address to, uint tokenId) external virtual override {
        address owner = ERC721B.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function getApproved(uint tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function setApprovalForAll(address operator, bool approved) external virtual override {
        require(operator != _msgSender(), "ERC721: approve to caller");
        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId
    ) external virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }


    //internal
    function _approve(address to, uint tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721B.ownerOf(tokenId), to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual {}

    function _burn(uint tokenId) internal virtual {
        address owner = ERC721B.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);
        _owners[tokenId] = address(0);

        emit Transfer(owner, address(0), tokenId);
    }

    function _checkOnERC721Received(
        address from,
        address to,
        uint tokenId,
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

    function _exists(uint tokenId) internal view virtual returns (bool) {
        return tokenId < _owners.length && _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721B.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _mint(address to, uint tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);
        _owners.push(to);

        emit Transfer(address(0), to, tokenId);
    }

    function _next() internal view virtual returns( uint ){
        return _owners.length;
    }

    function _safeMint(address to, uint tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    function _safeMint(
        address to,
        uint tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    function _safeTransfer(
        address from,
        address to,
        uint tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _transfer(
        address from,
        address to,
        uint tokenId
    ) internal virtual {
        require(ERC721B.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }
}

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/***********************
* @author: squeebo_nft *
************************/

import "@openzeppelin/contracts/access/Ownable.sol";

contract Delegated is Ownable{
  mapping(address => bool) internal _delegates;

  constructor(){
    _delegates[owner()] = true;
  }

  modifier onlyDelegates {
    require(_delegates[msg.sender], "Invalid delegate" );
    _;
  }

  //onlyOwner
  function isDelegate( address addr ) external view onlyOwner returns ( bool ){
    return _delegates[addr];
  }

  function setDelegate( address addr, bool isDelegate_ ) external onlyOwner{
    _delegates[addr] = isDelegate_;
  }

  function transferOwnership(address newOwner) public virtual override onlyOwner {
    _delegates[newOwner] = true;
    super.transferOwnership( newOwner );
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