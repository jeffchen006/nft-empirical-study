//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT

/**
*   @title Genesis Voxmon Contract
*/

/*
██╗   ██╗ ██████╗ ██╗  ██╗███╗   ███╗ ██████╗ ███╗   ██╗
██║   ██║██╔═══██╗╚██╗██╔╝████╗ ████║██╔═══██╗████╗  ██║
██║   ██║██║   ██║ ╚███╔╝ ██╔████╔██║██║   ██║██╔██╗ ██║
╚██╗ ██╔╝██║   ██║ ██╔██╗ ██║╚██╔╝██║██║   ██║██║╚██╗██║
 ╚████╔╝ ╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║╚██████╔╝██║ ╚████║
  ╚═══╝   ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// 
contract Genesis_Voxmon is ERC721, Ownable {
    using Counters for Counters.Counter;

    /*
    *   Global Data space
    */

    // This is live supply for clarity because our re-roll mechanism causes one token to be burned
    // and a new one to be generated. So some tokens may have a higher tokenId than 10,000
    uint16 public constant MAX_SUPPLY = 10000;
    Counters.Counter private _tokensMinted;

    // count the number of rerolls so we can add to tokensMinted and get new global metadata ID during reroll 
    Counters.Counter private _tokensRerolled;
    
    uint public constant MINT_COST = 70000000 gwei; // 0.07 ether 
    uint public constant REROLL_COST = 30000000 gwei; // 0.03 ether

    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo public defaultRoyaltyInfo;

    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;
    

    // to avoid rarity sniping this will initially be a centralized domain
    // and later updated to IPFS
    string public __baseURI = "https://voxmon.io/token/";

    // this will let us differentiate that a token has been locked for 3D art visually
    string public __lockedBaseURI = "https://voxmon.io/locked/";

    // time delay for public minting
    // unix epoch time
    uint256 public startingTime;
    uint256 public artStartTime;

    mapping (uint256 => address) internal tokenIdToOwner;

    // As a reward to the early community, some members will get a number of free re-rolls 
    mapping (address => uint16) internal remainingRerolls; 

    // As a reward to the early community, some members will get free Voxmon
    mapping (address => uint16) internal remainingPreReleaseMints;

    // keep track of Voxmon which are currently undergoing transformation (staked)
    mapping (uint256 => bool) internal tokenIdToFrozenForArt;

    // since people can reroll their and we don't want to change the tokenId each time
    // we need a mapping to know what metadata to pull from the global set 
    mapping (uint256 => uint256) internal tokenIdToMetadataId;

    event artRequestedEvent(address indexed requestor, uint256 tokenId);
    event rerollEvent(address indexed requestor, uint256 tokenId, uint256 newMetadataId);
    event mintEvent(address indexed recipient, uint256 tokenId, uint256 metadataId);

    // replace these test addresses with real addresses before mint
    address[] votedWL = [
        0x12C209cFb63bcaEe0E31b76a345FB01E25026c2b,
        0x23b65a3239a08365C91f13D1ef7D339Ecd256b2F,
        0x306bA4E024B9C36b225e7eb12a26dd80A4b49e77,
        0x3Ec23503D26878F364aDD35651f81fe10450e33f,
        0x3d8c9E263C24De09C7868E1ABA151cAEe3E77219,
        0x4Ba73641d4FC515370A099D6346C295033553485,
        0x4DCA116cF962e497BecAe7d441687320b6c66118,
        0x50B0595CbA0A8a637E9C6c039b8327211721e686,
        0x5161581E963A9463AFd483AcCC710541d5bEe6D0,
        0x5A44e7863945A72c32C3C2288a955f4B5BE42F22,
        0x5CeDFAE9629fdD41AE7dD25ff64656165526262A,
        0x633e6a774F72AfBa0C06b4165EE8cbf18EA0FAe8,
        0x6bcD919c30e9FDf3e2b6bB62630e2075185C77C1,
        0x6ce3F8a0677D5F758977518f7873D60218C9d7Ef,
        0x7c4D0a5FC1AeA24d2Bd0285Dd37a352b6795b78B,
        0x82b332fdd56d480a33B4Da58D83d5E0E432f1032,
        0x83728593e7C362A995b4c51147afeCa5819bbdA1,
        0x85eCCd73B4603a960ee84c1ce5bba45e189d2612,
        0x87deEE357F9A188aEEbbd666AE11c15031A81cEc,
        0x8C8f71d182d2F92794Ea2fCbF357814d09D222C3,
        0x8e1ba6ABf60FB207A046B883B36797a9E8882F81,
        0x8fC4EC6Aff0D79aCffdC6430987fc299D34959a3,
        0x929D99600BB36DDE6385884b857C4B0F05AedE35,
        0x94f36E68b33F5542deA92a7cF66478255a769652,
        0x9680a866399A49e7E96ACdC3a4dfB8EF492eFE41,
        0xA71C24E271394989D61Ac13749683d926A6AB81d,
        0xB03BF3Ad1c850F815925767dF20c7e359cd3D033,
        0xBDF5678D32631BDC09E412F1c317786e7C6BE5f1,
        0xC23735de9dAC1116fb52745B48b8515Aa6955179,
        0xF6bD73C1bF387568e2097A813Aa1e833Ca8e7e8C,
        0xFC6dcAcA25362a7dD039932e151D21836b8CAB51,
        0xa83b5371a3562DD31Fa28f90daE7acF4453Ae126,
        0xaE416E324029AcB10367349234c13EDf44b0ddFD,
        0xc2A77cdEd0bE8366c0972552B2B9ED9036cb666E,
        0xcA7982f1A4d4439211221c3c4e2548298B3D7098,
        0xdACc8Ab430B1249F1caa672b412Ac60AfcbFDf66,
        0xe64B416c651A02f68566c7C2E38c19FaE820E105,
        0x7c4D0a5FC1AeA24d2Bd0285Dd37a352b6795b78B,
        0xBe18dECE562dC6Ec1ff5d7eda7FdA4f755964481
    ];

    address[] earlyDiscordWL = [
        0xfB28A0B0BA53Ccc3F9945af7d7645F6503199e73,
        0xFedeA86Ebec8DDE40a2ddD1d156350C62C6697E4,
        0x5d6fd8a0D36Bb7E746b19cffBC856724952D1E6e,
        0x15E7078D661CbdaC184B696AAC7F666D63490aF6,
        0xE4330Acd7bB7777440a9250C7Cf65045052a6640,
        0x6278E4FE0e4670eac88014D6326f079B4D02d73c,
        0xFAd6EACaf5e3b8eC9E21397AA3b13aDaa138Cc80,
        0x5586d438BE5920143c0f9B179835778fa81a544a,
        0xcA7982f1A4d4439211221c3c4e2548298B3D7098,
        0xdACc8Ab430B1249F1caa672b412Ac60AfcbFDf66,
        0x82b332fdd56d480a33B4Da58D83d5E0E432f1032,
        0x6bcD919c30e9FDf3e2b6bB62630e2075185C77C1,
        0x4DCA116cF962e497BecAe7d441687320b6c66118,
        0xaE416E324029AcB10367349234c13EDf44b0ddFD,
        0xc2A77cdEd0bE8366c0972552B2B9ED9036cb666E,
        0x23b65a3239a08365C91f13D1ef7D339Ecd256b2F,
        0xE6E63B3225a3D4B2B6c13F0591DE9452C23242B8,
        0xE90D7E0843410A0c4Ff24112D20e7883BF02839b,
        0x9680a866399A49e7E96ACdC3a4dfB8EF492eFE41,
        0xe64B416c651A02f68566c7C2E38c19FaE820E105,
        0x83728593e7C362A995b4c51147afeCa5819bbdA1,
        0x7b80B01E4a2b939E1E6AE0D51212b13062352Faa,
        0x50B0595CbA0A8a637E9C6c039b8327211721e686,
        0x31c979544BAfC22AFCe127FD708CD52838CFEB58,
        0xE6ff1989f68b6Fd95b3B9f966d32c9E7d96e6255,
        0x72C575aFa7878Bc25A3548E5dC9D1758DB74FD54,
        0x5C95a4c6f66964DF324Cc95418f8cC9eD6D25D7c,
        0xc96039D0f01724e9C98245ca4B65B235788Ca916,
        0x44a3CCddccae339D05200a8f4347F83A58847E52,
        0x6e65772Af2F0815b4676483f862e7C116feA195E,
        0x4eee5183e2E4b670A7b5851F04255BfD8a4dB230,
        0xa950319939098C67176FFEbE9F989aEF11a82DF4,
        0x71A0496F59C0e2Bb91E48BEDD97dC233Fe76319F,
        0x1B0767772dc52C0d4E031fF0e177cE9d32D25aDB,
        0xa9f15D180FA3A8bFD15fbe4D5C956e005AF13D90
    ];

    address[] foundingMemberWL = [
        0x4f4EE78b653f0cd2df05a1Fb9c6c2cB2B632d7AA,
        0x5CeDFAE9629fdD41AE7dD25ff64656165526262A,
        0x0b83B35F90F46d3435D492D7189e179839743770,
        0xF6bD73C1bF387568e2097A813Aa1e833Ca8e7e8C,
        0x5A44e7863945A72c32C3C2288a955f4B5BE42F22,
        0x3d8c9E263C24De09C7868E1ABA151cAEe3E77219,
        0x7c4D0a5FC1AeA24d2Bd0285Dd37a352b6795b78B,
        0xBe18dECE562dC6Ec1ff5d7eda7FdA4f755964481,
        0x2f8c1346082Edcaf1f3B9310560B3D38CA225be8
    ];

    constructor(address payable addr) ERC721("Genesis Voxmon", "VOXMN") {
        // setup freebies for people who voted on site
        for(uint i = 0; i < votedWL.length; i++) {
            remainingRerolls[votedWL[i]] = 10;
        }

        // setup freebies for people who were active in discord
        for(uint i = 0; i < earlyDiscordWL.length; i++) {
            remainingRerolls[earlyDiscordWL[i]] = 10;
            remainingPreReleaseMints[earlyDiscordWL[i]] = 1;
        }

        // setup freebies for people who were founding members
        for(uint i = 0; i < foundingMemberWL.length; i++) {
            remainingRerolls[foundingMemberWL[i]] = 25;
            remainingPreReleaseMints[foundingMemberWL[i]] = 5;
        }


        // setup starting blocknumber (mint date) 
        // Friday Feb 4th 6pm pst 
        startingTime = 1644177600;
        artStartTime = 1649228400;

        // setup royalty address
        defaultRoyaltyInfo = RoyaltyInfo(addr, 1000);
    }
    
    /*
    *   Priviledged functions
    */

    // update the baseURI of all tokens
    // initially to prevent rarity sniping all tokens metadata will come from a cnetralized domain
    // and we'll upddate this to IPFS once the mint finishes
    function setBaseURI(string calldata uri) external onlyOwner {
        __baseURI = uri;
    }

    // upcate the locked baseURI just like the other one
    function setLockedBaseURI(string calldata uri) external onlyOwner {
        __lockedBaseURI = uri;
    }

    // allow us to change the mint date for testing and incase of error 
    function setStartingTime(uint256 newStartTime) external onlyOwner {       
        startingTime = newStartTime;
    }

    // allow us to change the mint date for testing and incase of error 
    function setArtStartingTime(uint256 newArtStartTime) external onlyOwner {       
        artStartTime = newArtStartTime;
    }

    // Withdraw funds in contract
    function withdraw(uint _amount) external onlyOwner {
        // for security, can only be sent to owner (or should we allow anyone to withdraw?)
        address payable receiver = payable(owner());
        receiver.transfer(_amount);
    }

    // value / 10000 (basis points)
    function updateDefaultRoyalty(address newAddr, uint96 newPerc) external onlyOwner {
        defaultRoyaltyInfo.receiver = newAddr;
        defaultRoyaltyInfo.royaltyFraction = newPerc;
    }

    function updateRoyaltyInfoForToken(uint256 _tokenId, address _receiver, uint96 _amountBasis) external onlyOwner {
        require(_amountBasis <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(_receiver != address(0), "ERC2981: invalid parameters");

        _tokenRoyaltyInfo[_tokenId] = RoyaltyInfo(_receiver, _amountBasis);
    }

    /*
    *   Helper Functions
    */
    function _baseURI() internal view virtual override returns (string memory) {
        return __baseURI;
    }

    function _lockedBaseURI() internal view returns (string memory) {
        return __lockedBaseURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId);
    }

    // see if minting is still possible
    function _isTokenAvailable() internal view returns (bool) {
        return _tokensMinted.current() < MAX_SUPPLY;
    }

    // used for royalty fraction
    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    } 

    /*
    *   Public View Function
    */
    
    // concatenate the baseURI with the tokenId
    function tokenURI(uint256 tokenId) public view virtual override returns(string memory) {
        require(_exists(tokenId), "token does not exist");

        if (tokenIdToFrozenForArt[tokenId]) {
            string memory lockedBaseURI = _lockedBaseURI();
            return bytes(lockedBaseURI).length > 0 ? string(abi.encodePacked(lockedBaseURI, Strings.toString(tokenIdToMetadataId[tokenId]))) : "";
        }

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, Strings.toString(tokenIdToMetadataId[tokenId]))) : "";
    }

    function getTotalMinted() external view returns (uint256) {
        return _tokensMinted.current();
    }

    function getTotalRerolls() external view returns (uint256) {
        return _tokensRerolled.current();
    }

    // tokenURIs increment with both mints and rerolls
    // we use this function in our backend api to avoid trait sniping
    function getTotalTokenURIs() external view returns (uint256) {
        return _tokensRerolled.current() + _tokensMinted.current();
    }

    function tokenHasRequested3DArt(uint256 tokenId) external view returns (bool) {
        return tokenIdToFrozenForArt[tokenId];
    }

    function getRemainingRerollsForAddress(address addr) external view returns (uint16) {
        return remainingRerolls[addr];
    }

    function getRemainingPreReleaseMintsForAddress(address addr) external view returns (uint16) {
        return remainingPreReleaseMints[addr];
    }

    function getMetadataIdForTokenId(uint256 tokenId) external view returns (uint256) {
        return tokenIdToMetadataId[tokenId];
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view returns (address receiver, uint256 royaltyAmount) {
            RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

            if (royalty.receiver == address(0)) {
                royalty = defaultRoyaltyInfo;
            }

            uint256 _royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();
            return (royalty.receiver, _royaltyAmount);
    }

    /*
    *   Public Functions
    */

    // Used to request a 3D body for your voxmon
    // Freezes transfers re-rolling a voxmon
    function request3DArt(uint256 tokenId) external {
        require(block.timestamp >= artStartTime, "you cannot freeze your Voxmon yet");
        require(ownerOf(tokenId) == msg.sender, "you must own this token to request Art");
        require(tokenIdToFrozenForArt[tokenId] == false, "art has already been requested for that Voxmon");
        tokenIdToFrozenForArt[tokenId] = true;

        emit artRequestedEvent(msg.sender, tokenId);
    }

    /*
    *   Payable Functions 
    */  
    
    // Mint a Voxmon
    // Cost is 0.07 ether
    function mint(address recipient) payable public returns (uint256) {
        require(_isTokenAvailable(), "max live supply reached, to get a new Voxmon you\'ll need to reroll an old one");
        require(msg.value >= MINT_COST, "not enough ether, minting costs 0.07 ether");
        require(block.timestamp >= startingTime, "public mint hasn\'t started yet");

        _tokensMinted.increment();
        
        uint256 newTokenId = _tokensMinted.current();
        uint256 metadataId = _tokensMinted.current() + _tokensRerolled.current();
        
        _mint(recipient, newTokenId);
        tokenIdToMetadataId[newTokenId] = metadataId;

        emit mintEvent(recipient, newTokenId, metadataId);

        return newTokenId;
    }

    // Mint multiple Voxmon
    // Cost is 0.07 ether per Voxmon
    function mint(address recipient, uint256 numberToMint) payable public returns (uint256[] memory) {
        require(numberToMint > 0);
        require(numberToMint <= 10, "max 10 voxmons per transaction");
        require(msg.value >= MINT_COST * numberToMint);

        uint256[] memory tokenIdsMinted = new uint256[](numberToMint);

        for(uint i = 0; i < numberToMint; i++) {
            tokenIdsMinted[i] = mint(recipient);
        }

        return tokenIdsMinted;
    }

    // Mint a free Voxmon
    function preReleaseMint(address recipient) public returns (uint256) {
        require(remainingPreReleaseMints[msg.sender] > 0, "you have 0 remaining pre-release mints");
        remainingPreReleaseMints[msg.sender] = remainingPreReleaseMints[msg.sender] - 1;

        require(_isTokenAvailable(), "max live supply reached, to get a new Voxmon you\'ll need to reroll an old one");

        _tokensMinted.increment();
        
        uint256 newTokenId = _tokensMinted.current();
        uint256 metadataId = _tokensMinted.current() + _tokensRerolled.current();
        
        _mint(recipient, newTokenId);
        tokenIdToMetadataId[newTokenId] = metadataId;

        emit mintEvent(recipient, newTokenId, metadataId);

        return newTokenId;
    }

    // Mint multiple free Voxmon
    function preReleaseMint(address recipient, uint256 numberToMint) public returns (uint256[] memory) {
        require(remainingPreReleaseMints[msg.sender] >= numberToMint, "You don\'t have enough remaining pre-release mints");

        uint256[] memory tokenIdsMinted = new uint256[](numberToMint);

        for(uint i = 0; i < numberToMint; i++) {
            tokenIdsMinted[i] = preReleaseMint(recipient);
        }

        return tokenIdsMinted;
    }

    // Re-Roll a Voxmon
    // Cost is 0.01 ether 
    function reroll(uint256 tokenId) payable public returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "you must own this token to reroll");
        require(msg.value >= REROLL_COST, "not enough ether, rerolling costs 0.03 ether");
        require(tokenIdToFrozenForArt[tokenId] == false, "this token is frozen");
        
        _tokensRerolled.increment();
        uint256 newMetadataId = _tokensMinted.current() + _tokensRerolled.current();

        tokenIdToMetadataId[tokenId] = newMetadataId;
        
        emit rerollEvent(msg.sender, tokenId, newMetadataId);

        return newMetadataId;
    }

    // Re-Roll a Voxmon
    // Cost is 0.01 ether 
    function freeReroll(uint256 tokenId) public returns (uint256) {
        require(remainingRerolls[msg.sender] > 0, "you have 0 remaining free rerolls");
        remainingRerolls[msg.sender] = remainingRerolls[msg.sender] - 1;

        require(ownerOf(tokenId) == msg.sender, "you must own the token to reroll");
        require(tokenIdToFrozenForArt[tokenId] == false, "this token is frozen");
        
        _tokensRerolled.increment();
        uint256 newMetadataId = _tokensMinted.current() + _tokensRerolled.current();

        tokenIdToMetadataId[tokenId] = newMetadataId;
        
        emit rerollEvent(msg.sender, tokenId, newMetadataId);

        return newMetadataId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

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
        _setApprovalForAll(_msgSender(), operator, approved);
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
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
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
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

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
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

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