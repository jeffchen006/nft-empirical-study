// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/****************************************
 * @author: tos_nft                 *
 * @team:   TheOtherSide                *
 ****************************************
 *   TOS-ERC721 provides low-gas    *
 *           mints + transfers          *
 ****************************************/

import './Delegated.sol';
import './ERC721EnumerableT.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TheOtherSide is ERC721EnumerableT, Delegated, ReentrancyGuard {
  using Strings for uint;

  /**
    * @dev Data structure of Moon
    */
  struct Moon {
    address owner;
    bool celestialType;
  }

  /**
     *    @notice Keep track of each user and their info
     */
    struct Staker {
        mapping(address => uint256[]) stakedTokens;
        mapping(address => uint256) timeStaked;
        uint256 amountStaked;
    }
    
    // @notice mapping of a staker to its current properties
    mapping(address => Staker) public stakers;

    // Mapping from token ID to owner address
    mapping(uint256 => address) public originalStakeOwner;

     // @notice event emitted when a user has staked a token
    event Staked(address owner, uint256 tokenId);

    // @notice event emitted when a user has unstaked a token
    event Unstaked(address owner, uint256 tokenId);

  bool public revealed = false;
  string public notRevealedUri = "ipfs://QmXZGWhQp3CQc3svnDhUuf4yTtoQBuqumHeC33jmEG69Dd/hidden.json";

  uint public MAX_SUPPLY   = 8888;
  uint public PRICE        = 0.15 ether;
  uint public MAX_QTY = 2;
  
  Moon[] public moons;

  bool public isWhitelistActive = false;
  bool public isMintActive = false;

  mapping(address => uint) public accessList;

  bool public isStakeActive   = false;

  mapping(address => uint) private _balances;
  string private _tokenURIPrefix;
  string private _tokenURISuffix =  ".json";

  constructor()
    ERC721T("The Other Side", "TOS"){
  }

/**
  * @dev Returns the number of tokens in ``owners``'s account.
  */
  function balanceOf(address account) public view override returns (uint) {
    require(account != address(0), "MOON: balance query for the zero address");
    return _balances[account];
  }

/**
  * @dev Returns the bool of tokens if``owner``'s account contains the tokenIds.
  */
  function isOwnerOf( address account, uint[] calldata tokenIds ) external view override returns( bool ){
    for(uint i; i < tokenIds.length; ++i ){
      if( moons[ tokenIds[i] ].owner != account )
        return false;
    }

    return true;
  }

/**
  * @dev Returns the owner of the `tokenId` token.
  *
  */
  function ownerOf( uint tokenId ) public override view returns( address owner_ ){
    address owner = moons[tokenId].owner;
    require(owner != address(0), "MOON: query for nonexistent token");
    return owner;
  }

/**
  * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
  * Use along with {totalSupply} to enumerate all tokens.
  */
  function tokenByIndex(uint index) external view override returns (uint) {
    require(index < totalSupply(), "MOON: global index out of bounds");
    return index;
  }

/**
  * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
  * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
  */
  function tokenOfOwnerByIndex(address owner, uint index) public view override returns (uint tokenId) {
    uint count;
    for( uint i; i < moons.length; ++i ){
      if( owner == moons[i].owner ){
        if( count == index )
          return i;
        else
          ++count;
      }
    }

    revert("ERC721Enumerable: owner index out of bounds");
  }

 /**
  * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
  */
  function tokenURI(uint tokenId) external view override returns (string memory) {
    require(_exists(tokenId), "MOON: URI query for nonexistent token");

    if(revealed == false) {
        return notRevealedUri;
    }
    return string(abi.encodePacked(_tokenURIPrefix, tokenId.toString(), _tokenURISuffix));
  }

/**
  * @dev Returns the total amount of tokens stored by the contract.
  */
  function totalSupply() public view override returns( uint totalSupply_ ){
    return moons.length;
  }

/**
  * @dev Returns the list of tokenIds stored by the owner's account.
  */
  function walletOfOwner( address account ) external view override returns( uint[] memory ){
    uint quantity = balanceOf( account );
    uint[] memory wallet = new uint[]( quantity );
    for( uint i; i < quantity; ++i ){
        wallet[i] = tokenOfOwnerByIndex( account, i );
    }
    return wallet;
  }

/**
  * @dev Owner sets the Staking contract address.
  */
  function setRevealState(bool reveal_) external onlyDelegates {
      revealed = reveal_;
  }

  /**
  * @dev Owner sets the Staking contract address.
  */
  function setUnrevealURI(string calldata notRevealUri_) external onlyDelegates {
      notRevealedUri = notRevealUri_;
  }

 /**
  * @dev mints token based on the number of qty specified.
  */
  function mint( uint quantity ) external payable nonReentrant {
    require(isMintActive == true,"MOON: Minting needs to be enabled.");
    require( msg.value >= PRICE * quantity, "MOON: Ether sent is not correct" );

    //If whitelist is active, people in WL can mint 
    //based on the allowable qty limit set by owner/delegates.
    if( isWhitelistActive ){
      require( accessList[ msg.sender ] >= quantity, "MOON: Account is less than the qty limit");
      accessList[ msg.sender ] -= quantity;
    } else { 
      //For public, MAX_QTY limit will be applied. 
      //MAX_QTY is determined by the owner/delegates
      require(quantity <= MAX_QTY, "MOON:Quantity must be less than or equal MAX_QTY");
    }

    uint supply = totalSupply();
    require( supply + quantity <= MAX_SUPPLY, "MOON: Mint/order exceeds supply" );
    for(uint i; i < quantity; ++i){
      _mint( msg.sender, supply++ );
    }
  }

/**
  * @dev Returns the balance amount of the Contract address.
  */
  function getBalanceofContract() external view returns (uint256) {
    return address(this).balance;
  }

/**
  * @dev Withdraws an amount from the contract balance.
  */
  function withdraw(uint256 amount_) public onlyOwner {
    require(address(this).balance >= amount_, "Address: insufficient balance");

    // This will payout the owner 100% of the contract balance.
    // Do not remove this otherwise you will not be able to withdraw the funds.
    // =============================================================================
    (bool os, ) = payable(owner()).call{value: amount_}("");
    require(os);
    // =============================================================================
  }


  /**
  * @dev Allows team to mint the token without restriction.
  */
  function team_mint(uint[] calldata quantity, address[] calldata recipient) external onlyDelegates{
    require(quantity.length == recipient.length, "MOON: Must provide equal quantities and recipients" );

    uint totalQuantity;
    uint supply = totalSupply();
    for(uint i; i < quantity.length; ++i){
      totalQuantity += quantity[i];
    }
    require( supply + totalQuantity < MAX_SUPPLY, "MOON: Mint/order exceeds supply" );

    for(uint i; i < recipient.length; ++i){
      for(uint j; j < quantity[i]; ++j){
        uint tokenId = supply++;
        _mint( recipient[i], tokenId);
      }
    }
  }

/**
  * @dev Owner/Delegate sets the Whitelist active flag.
  */
  function setWhitelistAddress(address[] calldata accounts, uint allowed) external onlyDelegates{
    for(uint i; i < accounts.length; ++i){
      accessList[ accounts[i] ] = allowed;
    }
  }

/**
  * @dev Owner/Delegate sets the Minting flag.
  */
  function setMintingActive(bool mintActive_) external onlyDelegates {
    require( isMintActive != mintActive_ , "MOON: New value matches old" );
    isMintActive = mintActive_;
  }

/**
  * @dev Owner/Delegate sets the Whitelist active flag.
  */
  function setWhitelistActive(bool isWhitelistActive_) external onlyDelegates{
    require( isWhitelistActive != isWhitelistActive_ , "MOON: New value matches old" );
    isWhitelistActive = isWhitelistActive_;
  }

/**
  * @dev Owner/Delegates sets the BaseURI of IPFS.
  */
  function setBaseURI(string calldata prefix, string calldata suffix) external onlyDelegates{
    _tokenURIPrefix = prefix;
    _tokenURISuffix = suffix;
  }

/**
  * @dev Owner/Delegate sets the Max supply of the token.
  */
  function setMaxSupply(uint maxSupply) external onlyDelegates{
    require( MAX_SUPPLY != maxSupply, "MOON: New value matches old" );
    require( maxSupply >= totalSupply(), "MOON: Specified supply is lower than current balance" );
    MAX_SUPPLY = maxSupply;
  }

/**
  * @dev Owner/Delegate sets the Max. qty 
  */
  function setMaxQty(uint maxQty) external onlyDelegates{
    require( MAX_QTY != maxQty, "MOON: New value matches old" );
    MAX_QTY = maxQty;
  }

/**
  * @dev Owner/Delegate sets the minting price.
  */
  function setPrice(uint price) external onlyDelegates{
    require( PRICE != price, "MOON: New value matches old" );
    PRICE = price;
  }

/**
  * @dev increment and decrement balances based on address from and  to.
  */
  function _beforeTokenTransfer(address from, address to) internal {
    if( from != address(0) )
      --_balances[ from ];

    if( to != address(0) )
      ++_balances[ to ];
  }

/**
  * @dev returns bool if the tokenId exist.
  */
  function _exists(uint tokenId) internal view override returns (bool) {
    return tokenId < moons.length && moons[tokenId].owner != address(0);
  }

/**
  * @dev mints token based address and tokenId
  */
  function _mint(address to, uint tokenId) internal {
    _beforeTokenTransfer(address(0), to);
    moons.push(Moon(to,false));
    emit Transfer(address(0), to, tokenId);
  }

/**
    * @dev update the moon type.
    */
  function updateMoontype(bool moonType, uint[] calldata tokenIds ) external onlyDelegates {
        //update logic to update the MoonType
        for(uint i=0; i < tokenIds.length; i++) {
            require(_exists(tokenIds[i]), "MOON: TokenId not exist");
            moons[tokenIds[i]].celestialType = moonType;
        }
  }

/**
  * @dev returns the moontypes based on the tokenIds.
  */
  function getMoonType(uint[] calldata tokenIds) external view returns(bool[] memory moonTypes) {
      // return moontype true/false
      bool[] memory _moonTypes = new bool[](tokenIds.length);
      for(uint i; i < tokenIds.length; i++) {
        _moonTypes[i] = moons[tokenIds[i]].celestialType;
      }
      return _moonTypes;
  }

/**
  * @dev transfer tokenId to other address.
  */
  function _transfer(address from, address to, uint tokenId) internal override {
    require(moons[tokenId].owner == from, "MOON: transfer of token that is not owned");

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);
    _beforeTokenTransfer(from, to);

    moons[tokenId].owner = to;
    emit Transfer(from, to, tokenId);
  }

  /**
    * @dev Get the tokens staked by a user
    */
    function getStakedTokens(address _user) public view returns (uint256[] memory tokenIds) {
        Staker storage staker = stakers[_user];
        return staker.stakedTokens[_user]; 
    }

/**
  * @dev Stake the NFT based on array of tokenIds
  */
    function stake( uint[] calldata tokenIds ) external {
        require( isStakeActive, "MOON: Staking is not active" );
        
        Moon storage moon;
        //Check if TokenIds exist and the moon owner is the msge sender
        for( uint i; i < tokenIds.length; ++i ){
            require( _exists(tokenIds[i]), "MOON: Query for nonexistent token" );
            moon = moons[ tokenIds[i] ];
            require(moon.owner == msg.sender, "MOON: Staking token that is not owned");

            _stake(msg.sender, tokenIds[i]);
        }
    }

    /**
    * @dev For internal access to stake the NFT based tokenId
    */
    function _stake( address _user, uint256 _tokenId ) internal {

        Staker storage staker = stakers[_user];

        staker.amountStaked += 1;
        staker.timeStaked[_user] = block.timestamp;
        staker.stakedTokens[_user].push(_tokenId);

        originalStakeOwner[_tokenId] = msg.sender;

        _transfer(_user,address(this), _tokenId);
      
        emit Staked(_user, _tokenId);

        
    }

/**
  * @dev Unstake the token based on array of tokenIds
  */
    function unStake( uint[] calldata tokenIds ) external {
        require( isStakeActive, "MOON: Staking is not active" );
        //Check if TokenIds exist
        for( uint i; i < tokenIds.length; ++i ){
            require( originalStakeOwner[tokenIds[i]] == msg.sender, 
            "MOON._unstake: Sender must have staked tokenID");
            _unstake(msg.sender,tokenIds[i]);        
        }
    }

    /**
    * @dev For internal access to unstake the NFT based tokenId
    */
    function _unstake( address _user, uint256 _tokenId) internal {

        Staker storage staker = stakers[_user];

        _removeElement(_user, _tokenId);

        delete originalStakeOwner[_tokenId];
        staker.timeStaked[_user] = block.timestamp;
        staker.amountStaked -= 1;

        if(staker.amountStaked == 0) {
            delete stakers[_user];
        }

        _transfer(address(this),_user, _tokenId);
        
        emit Unstaked(_user, _tokenId);
        
    }

  /**
    * @dev Owner/Delegate sets the Whitelist active flag.
    */
    function setStakeActive( bool isActive_ ) external onlyDelegates {
      require( isStakeActive != isActive_ , "MOON: New value matches old" );
      isStakeActive = isActive_;
    }

    /**
    *   @notice remove given elements from array
    *   @dev usable only if _array contains unique elements only
     */
    function _removeElement(address _user, uint256 _element) internal {
        Staker storage staker = stakers[_user];
        for (uint256 i; i<staker.stakedTokens[_user].length; i++) {
            if (staker.stakedTokens[_user][i] == _element) {
                staker.stakedTokens[_user][i] = staker.stakedTokens[_user][staker.stakedTokens[_user].length - 1];
                staker.stakedTokens[_user].pop();
                break;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

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

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

/****************************************
 * @author: squeebo_nft                 *
 ****************************************
 *   Blimpie-ERC721 provides low-gas    *
 *           mints + transfers          *
 ****************************************/

import "./ERC721T.sol";
import "./IERC721Batch.sol";
import "./IERC721Enumerable.sol";

abstract contract ERC721EnumerableT is ERC721T, IERC721Batch, IERC721Enumerable {
    function balanceOf( address owner ) public view virtual override( IERC721, ERC721T ) returns( uint );

    function isOwnerOf( address account, uint[] calldata tokenIds ) external view virtual override returns( bool );

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721T) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenOfOwnerByIndex(address owner, uint index) public view virtual override returns( uint tokenId );

    function tokenByIndex(uint index) external view virtual override returns (uint) {
        require(index < totalSupply(), "ERC721Enumerable: global index out of bounds");
        return index;
    }

    function totalSupply() public view virtual override returns( uint );

    function transferBatch( address from, address to, uint[] calldata tokenIds, bytes calldata data ) external override{
        for(uint i; i < tokenIds.length; ++i ){
            safeTransferFrom( from, to, tokenIds[i], data );
        }
    }

    function walletOfOwner( address account ) external view virtual override returns( uint[] memory ){
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

/***********************
* @author: squeebo_nft *
************************/

import "./Ownable.sol";

contract Delegated is Ownable {
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

import "./IERC721.sol";

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

// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

interface IERC721Batch {
  function isOwnerOf( address account, uint[] calldata tokenIds ) external view returns( bool );
  function transferBatch( address from, address to, uint[] calldata tokenIds, bytes calldata data ) external;
  function walletOfOwner( address account ) external view returns( uint[] memory );
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

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./IERC721Metadata.sol";
import "./Address.sol";
import "./Context.sol";
import "./ERC165.sol";

abstract contract ERC721T is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;

    string private _name;
    string private _symbol;

    mapping(uint => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    //public
    function balanceOf(address owner) public view virtual override returns( uint );

    function name() external view virtual override returns (string memory) {
        return _name;
    }

    function ownerOf(uint tokenId) public view virtual override returns (address);

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    /*
    function totalSupply() public view virtual returns (uint) {
        return _owners.length - (_offset + _burned);
    }
    */


    function approve(address to, uint tokenId) external virtual override {
        address owner = ownerOf(tokenId);
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
        emit Approval(ownerOf(tokenId), to, tokenId);
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

    function _exists(uint tokenId) internal view virtual returns (bool);

    function _isApprovedOrOwner(address spender, uint tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
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

    function _transfer(address from, address to, uint tokenId) internal virtual;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Context.sol";

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

import "./ERC165.sol";

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

import "./IERC721.sol";

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