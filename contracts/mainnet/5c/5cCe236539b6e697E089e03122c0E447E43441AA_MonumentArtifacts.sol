// SPDX-License-Identifier: ISC
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/NFT.sol";
import "./utils/Taxes.sol";
import "./Splits.sol";
import "./SplitsFactory.sol";

/// @title MonumentArtifacts Contract
/// @author [email protected]
/// @notice This contract shall be the prime Monument NFT contract consisting of all the Artifacts in the Metaverse.
contract MonumentArtifacts is NFT, Taxes, ReentrancyGuard {
  address public splitsFactoryContractAddress;

  /// @notice Constructor function for the MonumentArtifacts Contract
  /// @dev Constructor function for the MonumentArtifacts ERC721 Contract
  /// @param name_ Name of the Monument artifact Collection
  /// @param symbol_ Symbol for the Monument
  /// @param _permissionManagementContractAddress Address of the PermissionManagement Contract that manages Permissions.
  /// @param _splitsFactoryContractAddress Address of the SplitsFactory Contract that manages Splits Proxies.
  constructor(
    string memory name_, 
    string memory symbol_,
    address _permissionManagementContractAddress,
    address _splitsFactoryContractAddress,
    string memory contractURI_
  )
  NFT(name_, symbol_, _permissionManagementContractAddress, contractURI_)
  Taxes(_permissionManagementContractAddress)
  payable
  {
    // Build Genesis Artifact and Zero Token
    _mintArtifact("https://monument.app/artifacts/0.json", 1, 1, block.timestamp);
    splitsFactoryContractAddress = _splitsFactoryContractAddress;
  }




  // token IDs counter
  using Counters for Counters.Counter;
  Counters.Counter public totalArtifacts;
  Counters.Counter public totalTokensMinted;




  // Artifacts
  struct Artifact {
    uint256 id;
    string metadata;
    uint256 totalSupply;
    uint256 initialSupply;
    uint256 currentSupply;
    uint256 blockTimestamp;
    uint256 artifactTimestamp;
    address author;
  }
  Artifact[] public artifacts;

  // Artifact Methods
  mapping(address => uint256[]) public getArtifactIDsByAuthor;

  function getArtifactAuthor(uint256 artifactId) public view virtual returns (address author) {
    return artifacts[artifactId].author;
  }

  function getArtifactSupply(uint256 artifactId) 
    public
    view
    virtual
    returns (
      uint256 totalSupply,
      uint256 currentSupply,
      uint256 initialSupply
    ) {
    return (
      artifacts[artifactId].totalSupply,
      artifacts[artifactId].currentSupply,
      artifacts[artifactId].initialSupply
    );
  }

  // Track Artifact Tokens
  mapping(uint256 => uint256[]) public getTokenIDsByArtifactID;
  mapping(uint256 => uint256) public getArtifactIDByTokenID;
  mapping(address => uint256[]) public getTokenIDsByAuthor;
  mapping(uint256 => address) public getAuthorByTokenID;

  // Artifact Metadata Mapping
  mapping(string => bool) public artifactMetadataExists;
  mapping(string => uint256) public getArtifactIDByMetadata;

  // Store Royalty Permyriad for Artifacts
  mapping(uint256 => uint256) public getRoyaltyPermyriadByArtifactID;

  // Artifact Fork Data
  mapping(uint256 => uint256[]) public getForksOfArtifact;
  mapping(uint256 => uint256) public getArtifactForkedFrom;

  // Mentions (for on-chain tagging)
  mapping(uint256 => address[]) public getMentionsByArtifactID;
  mapping(address => uint256[]) public getArtifactsMentionedInByAddress;




  // Used to Split Royalty
  // See EIP-2981 for more information: https://eips.ethereum.org/EIPS/eip-2981
  struct RoyaltyInfo {
    address receiver;
    uint256 percent; // it's actually a permyriad (parts per ten thousand)
  }
  mapping(uint256 => RoyaltyInfo) public getRoyaltyInfoByArtifactId;

  /// @notice returns royalties info for the given Token ID
  /// @dev can be used by other contracts to get royaltyInfo
  /// @param _tokenID Token ID of which royaltyInfo is to be fetched
  /// @param _salePrice Desired Sale Price of the token to run calculations on
  function royaltyInfo(uint256 _tokenID, uint256 _salePrice)
  	external
  	view
  	returns (address receiver, uint256 royaltyAmount)
  {
    RoyaltyInfo memory rInfo = getRoyaltyInfoByArtifactId[getArtifactIDByTokenID[_tokenID]];
	if (rInfo.receiver == address(0)) return (address(0), 0);
	uint256 amount = _salePrice * rInfo.percent / 10000;
	return (payable(rInfo.receiver), amount);
  }

  /// @notice returns royalties info for the given Artifact ID
  /// @dev can be used by other contracts to get royaltyInfo
  /// @param _artifactID Token ID of which royaltyInfo is to be fetched
  /// @param _salePrice Desired Sale Price of the token to run calculations on
  function royaltyInfoByArtifactId(uint256 _artifactID, uint256 _salePrice)
  	external
  	view
  	returns (address receiver, uint256 royaltyAmount)
  {
    RoyaltyInfo memory rInfo = getRoyaltyInfoByArtifactId[_artifactID];
	if (rInfo.receiver == address(0)) return (address(0), 0);
	uint256 amount = _salePrice * rInfo.percent / 10000;
	return (payable(rInfo.receiver), amount);
  }




  // Events
  event ArtifactMinted (
    uint256 indexed id,
    string metadata,
    uint256 totalSupply,
    uint256 initialSupply,
    address indexed author,
    uint256 paidAmount,
    uint256 timestamp
  );
  event EditionsMinted (
    uint256 indexed artifactId,
    uint256 editions,
    address indexed mintedTo,
    address indexed mintedBy,
    uint256 timestamp
  );
  event EditionsAirdropped (
    uint256 indexed artifactId,
    uint256 editions,
    address[] mintedTo,
    address indexed mintedby,
    uint256 timestamp
  );




  // Modifiers
  modifier editionChecks(uint256 artifactID, uint256 editions) {
    // check if artifact is valid
    require(artifacts[artifactID].blockTimestamp > 0, "Invalid artifactID");

    // only moderators or artifact owners should be able to mint edtions.
    require(
        permissionManagement.moderators(msg.sender) ||
        artifacts[artifactID].author == msg.sender,
        "unauthorized call"
    );

    // only allow minting editions such that currentSupply shouldn't exceed totalSupply
    require(
        editions + artifacts[artifactID].currentSupply <= artifacts[artifactID].totalSupply, 
        "totalSupply exhausted"
    );

    _;
  }




  // Public Functions

  /// @notice Creates an Artifact on a Monument
  /// @param metadata IPFS / Arweave / Custom URL
  /// @param totalSupply A non-zero value of NFTs to mint for this Artifact
  /// @param initialSupply Should pre-mint all the editions?
  /// @param mentions Array of addresses to Mention in the Artifact
  /// @param forkOf Artifact ID of the Artifact you want to create a Fork of. 0 for nothing.
  /// @param artifactTimestamp Date the Artifact corelates to.
  /// @param royaltyPermyriad Permyriad of Royalty tagged people wish to collectively collect on NFT sale in the market
  /// @param splitBeneficiaries An array of Beneficiaries to Split Royalties among
  /// @param permyriadsCorrespondingToSplitBeneficiaries An array specifying how much portion of the total royalty each split beneficiary gets
  function mintArtifact(
      string memory metadata,
      uint256 totalSupply,
      uint256 initialSupply,
      address[] memory mentions,
      uint256 forkOf,
      uint256 artifactTimestamp,
      uint256 royaltyPermyriad,
      address[] memory splitBeneficiaries,
      uint256[] memory permyriadsCorrespondingToSplitBeneficiaries
    )
    external
    payable
    nonReentrant
    returns (uint256 _artifactID)
  {
    // royaltyPermyriad should be 0-10000 only
    require(royaltyPermyriad >= 0 && royaltyPermyriad <= 10000, "Invalid Royalty Permyriad value");

    // splitBeneficiaries & permyriadsCorrespondingToSplitBeneficiaries Array length should be equal
    uint256 splitBeneficiariesLength = splitBeneficiaries.length;
    require(splitBeneficiariesLength == permyriadsCorrespondingToSplitBeneficiaries.length, "Invalid Beneficiary Data");

    // sum of permyriadsCorrespondingToSplitBeneficiaries must be 10k
    uint256 _totalPermyriad;
    for (uint256 i = 0; i < splitBeneficiariesLength; i++) {
      require(splitBeneficiaries[i] != address(0));
      require(permyriadsCorrespondingToSplitBeneficiaries[i] > 0);
      require(permyriadsCorrespondingToSplitBeneficiaries[i] <= 10000);
      _totalPermyriad += permyriadsCorrespondingToSplitBeneficiaries[i];
    }
    require(_totalPermyriad == 10000, "Total Permyriad must be 10000");

    // metadata must not be empty
    require(bytes(metadata).length > 0, "Empty Metadata");

    // make sure another artifact with the same metadata does not exist
    require(artifactMetadataExists[metadata] != true, "Artifact already minted");

    // forkOf must be a valid Artifact ID
    require(artifacts[forkOf].blockTimestamp > 0, "Invalid forkOf Artifact");

    // totalSupply cant be 0
    require(totalSupply != 0, "Supply must be non-zero");

    // initialSupply must be lesser than or equal to the totalSupply
    require(initialSupply <= totalSupply, "invalid initialSupply");

    // charge taxes (if any)
    _chargeArtifactTax();

	uint256 artifactID = _mintArtifact(metadata, totalSupply, initialSupply, artifactTimestamp);
	getRoyaltyPermyriadByArtifactID[artifactID] = royaltyPermyriad;

    if (royaltyPermyriad == 0) {
      getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(address(0), 0);
    } else {
      // Mint a new Splits contract
      address splitsProxyAddress = SplitsFactory(payable(splitsFactoryContractAddress)).createProxy(splitBeneficiaries, permyriadsCorrespondingToSplitBeneficiaries);

      // Populate royalties map for new Artifact ID
      getRoyaltyInfoByArtifactId[artifactID] = RoyaltyInfo(splitsProxyAddress, royaltyPermyriad);
    }

    // Mentions
    getMentionsByArtifactID[artifactID] = mentions;
    uint256 mentionsLength = mentions.length;
    for (uint256 i = 0; i < mentionsLength; i++) {
      getArtifactsMentionedInByAddress[mentions[i]].push(artifactID);
    }

    // Attach Forks
    getForksOfArtifact[forkOf].push(artifactID);
    getArtifactForkedFrom[artifactID] = forkOf;

    return artifactID;
  }


  /// @notice Airdrops editions of an Artifact to many addresses
  /// @param artifactID ID of the Artifact whose editions to mint
  /// @param addresses Specify the addresses where all the new minted tokens should go
  function airdropEditions(
      uint256 artifactID,
      address[] memory addresses
    )
    external
    payable
    nonReentrant
    editionChecks(artifactID, addresses.length)
    returns (
      uint256 _artifactID,
      address[] memory _addresses
    )
  {
    // airdrop them all
    for (uint256 i = 0; i < addresses.length; i++) {
        _mintTokens(artifactID, 1, addresses[i]);
    }

    // emit event
    emit EditionsAirdropped(artifactID, addresses.length, _addresses, msg.sender, block.timestamp);

    return (artifactID, addresses);
  }


  /// @notice Mints editions of an Artifact
  /// @param artifactID ID of the Artifact whose editions to mint
  /// @param editions Number of editions to mint for the Artifact
  /// @param mintTo Specify the address where all the new minted tokens should go
  function mintEditions(
      uint256 artifactID,
      uint256 editions,
      address mintTo
    )
    external
    payable
    nonReentrant
    editionChecks(artifactID, editions)
    returns (
      uint256 _artifactID,
      uint256 _editions,
      address _mintedTo
    )
  {
    // mint the edtions
    _mintTokens(artifactID, editions, mintTo);

    // emit event
    emit EditionsMinted(artifactID, editions, mintTo, msg.sender, block.timestamp);

    return (artifactID, editions, mintTo);
  }




  // Functions for Internal Use

  /// @dev Builds an Artifact with no checks. For internal use only.
  function _mintArtifact(
    string memory metadata,
    uint256 totalSupply,
    uint256 initialSupply,
    uint256 artifactTimestamp
  )
    internal
    returns (uint256 _artifactID)
  {
    uint256 newId = totalArtifacts.current();
    totalArtifacts.increment();

    artifacts.push(
      Artifact(
        newId,
        metadata,
        totalSupply,
        initialSupply,
        0, // current supply will initially be zero, it'll increase live as this function mints
        block.timestamp,
        artifactTimestamp,
        msg.sender
      )
    );
    artifactMetadataExists[metadata] = true;
    getArtifactIDByMetadata[metadata] = newId;
    getArtifactIDsByAuthor[msg.sender].push(newId);

    // Mint tokens
    _mintTokens(newId, initialSupply, msg.sender);

    // Emit Event
    emit ArtifactMinted (
      newId,
      metadata,
      totalSupply,
      initialSupply,
      msg.sender,
      msg.value,
      block.timestamp
    );

    return newId;
  }


  /// @dev Mints multiple tokens with no checks. For internal use only.
  function _mintTokens(
    uint256 artifactID,
    uint256 amount,
    address mintTo
  )
    internal
    returns (
      uint256 _artifactID,
      uint256 _amount,
      address _mintedTo
    )
  {
    // Mint tokens
    for (uint256 i = 0; i < amount; i++) {
      uint256 newTokenId = totalTokensMinted.current();
      totalTokensMinted.increment();

      _safeMint(mintTo, newTokenId);
      _setTokenURI(newTokenId, artifacts[artifactID].metadata);
      
      getTokenIDsByArtifactID[artifactID].push(newTokenId);
      getArtifactIDByTokenID[newTokenId] = artifactID;

      getTokenIDsByAuthor[artifacts[artifactID].author].push(newTokenId);
      getAuthorByTokenID[newTokenId] = artifacts[artifactID].author;

      artifacts[artifactID].currentSupply = artifacts[artifactID].currentSupply + 1;
    }

    return (artifactID, amount, mintTo);
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

// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "./AdminOps.sol";
import "./ERC721/extensions/ERC721Enumerable.sol";
import "../PermissionManagement.sol";
import "./Payable.sol";

/// @title NFT Contract
/// @author [email protected]
/// @notice An ERC721 Inheritable Contract with many features (like, ERC721Enumerable, accepting payments, admin ability to transfer tokens, etc.)
abstract contract NFT is AdminOps, ERC721Enumerable, Payable {
  constructor (
    string memory name_, 
    string memory symbol_,
    address _permissionManagementContractAddress,
    string memory contractURI_
  )
  ERC721(name_, symbol_)
  AdminOps(_permissionManagementContractAddress)
  Payable(_permissionManagementContractAddress)
  {
    _contractURI = contractURI_;
  }

  string public baseURI = ""; //-> could have been "https://monument.app/artifacts/"

  function _baseURI() internal view virtual override(ERC721) returns (string memory) {
    return baseURI;
  }

  function changeBaseURI(string memory baseURI_) public returns (string memory) {
    permissionManagement.adminOnlyMethod(msg.sender);
    baseURI = baseURI_;
    return baseURI;
  }

  string _contractURI = "";

  function contractURI() public view returns (string memory) {
    return _contractURI;
  }

  function changeContractURI(string memory contractURI_) public returns (string memory) {
    permissionManagement.adminOnlyMethod(msg.sender);
    _contractURI = contractURI_;
    return contractURI_;
  }

  function exists(uint256 tokenId) public view returns (bool) {
    return _exists(tokenId);
  }

  /* Extend AdminOps.sol */
  function godlySetTokenURI(uint256 _tokenId, string memory _tokenURI) 
    public
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _setTokenURI(_tokenId, _tokenURI);
    return _tokenId;
  }

  /* Overridings */
  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  mapping(uint256 => string) private _tokenURIs;

  /// @notice Fetch URL of the Token
  /// @dev From OpenZepplin
  /// @param tokenId ID of the Token whose URI to fetch
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
      require(_exists(tokenId), "URI query for nonexistent token");

      string memory _tokenURI = _tokenURIs[tokenId];
      string memory base = _baseURI();

      // If there is no base URI, return the token URI.
      if (bytes(base).length == 0) {
          return _tokenURI;
      }
      
      // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
      if (bytes(_tokenURI).length > 0) {
          return string(abi.encodePacked(base, _tokenURI));
      }

      return super.tokenURI(tokenId);
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
      require(_exists(tokenId), "URI set of nonexistent token");
      _tokenURIs[tokenId] = _tokenURI;
  }

  function _burn(uint256 tokenId) internal virtual override {
      super._burn(tokenId);

      if (bytes(_tokenURIs[tokenId]).length != 0) {
          delete _tokenURIs[tokenId];
      }
  }
}

// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "../PermissionManagement.sol";

/// @title Taxes Contract
/// @author [email protected]
/// @notice In Monument.app context, this contract allows the Beneficiary to collect taxes everytime a Monument or an Artifact is minted.
abstract contract Taxes {
  PermissionManagement private permissionManagement;

  constructor (
    address _permissionManagementContractAddress
  ) {
    permissionManagement = PermissionManagement(_permissionManagementContractAddress);
  }

  event TaxesChanged (
    uint256 newTaxOnMintingAnArtifact,
    address indexed actionedBy
  );

  uint256 public taxOnMintingAnArtifact; // `26 * (10 ** 13)` was around $1 in Oct 2021

  /// @notice To set new taxes for Building and Minting
  /// @param _onMintingArtifact Tax in wei, for minting an Artifact.
  function setTaxes(uint256 _onMintingArtifact)
    external
    returns (uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);

    taxOnMintingAnArtifact = _onMintingArtifact;

    emit TaxesChanged (
      _onMintingArtifact,
      msg.sender
    );

    return _onMintingArtifact;
  }

  /// @notice Taxes are sent to the Beneficiary
  function _chargeArtifactTax()
    internal
    returns (bool)
  {
    require(
      msg.value >= taxOnMintingAnArtifact || 
      permissionManagement.moderators(msg.sender), // moderators dont pay taxes
      "Insufficient amount sent"
    );

    if (msg.value >= taxOnMintingAnArtifact) {
      (bool success, ) = permissionManagement.beneficiary().call{value: taxOnMintingAnArtifact}("");
      require(success, "Transfer to Beneficiary failed");
    }
    
    return true;
  }
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title The Splits Implementation Contract
/// @author [email protected] & [email protected]
/// @notice This contract shall be deployed everytime a user mints an artifact. This contract will manage the split sharing of royalty fee that it receives.
contract Splits is Initializable, ReentrancyGuardUpgradeable {
    mapping(address => uint256) public royalties;

    address[] public splitters;
    uint256[] public permyriads;

    constructor () {
        //
    }

    /// @notice Constructor function for the Splits Contract Instances
    /// @dev Takes in the array of Splitters and Permyriads, fills the storage, to set the Split rules accordingly.
    /// @param _splitters An array of addresses that shall be entitled to some permyriad share of the total royalty supplied to the contract, from the market, preferrably.
    /// @param _permyriads An array of numbers that represent permyriads, all its elements must add up to a total of 10000, and must be in order of splitters supplied during construction of the contract.
    function initialize(
        address[] memory _splitters,
        uint256[] memory _permyriads
    )
        public 
        payable
        initializer
    {
        require(_splitters.length == _permyriads.length);

        uint256 _totalPermyriad;

        uint256 splittersLength = _splitters.length;

        for (uint256 i = 0; i < splittersLength; i++) {
            require(_splitters[i] != address(0));
            require(_permyriads[i] > 0);
            require(_permyriads[i] <= 10000);
            _totalPermyriad += _permyriads[i];
        }

        require(_totalPermyriad == 10000, "Total permyriad must be 10000");

        for (uint256 i = 0; i < splittersLength; i++) {
            royalties[_splitters[i]] = _permyriads[i];
        }

        splitters = _splitters;
        permyriads = _permyriads;
    }

    /// @notice Get Balance of the Split Contract
    function getBalance() external view returns(uint256) {
        return address(this).balance;
    }

    // Events
    event ReceivedFunds(
        address indexed by,
        uint256 fundsInwei,
        uint256 timestamp
    );
    event SentSplit(
        address indexed from,
        address indexed to,
        uint256 fundsInwei,
        uint256 timestamp
    );
    event Withdrew (
        address indexed actionedBy,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Allow this contract to split funds everytime it receives it
    fallback() external virtual payable {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
        distributeFunds();
    }

    /// @notice Allow this contract to split funds everytime it receives it
    receive() external virtual payable {
        emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
        distributeFunds();
    }

    /// @notice if x = 100, & y = 1000 & scale = 10000, that should return 1% of 1000 that is 10.
    /// @dev Calculates x parts per scale for y, read this for more info: https://ethereum.stackexchange.com/a/79736
    /// @param x Parts per Scale
    /// @param y Number to calculate on
    /// @param scale Scale on which to make the calculations
    function mulScale (uint256 x, uint256 y, uint128 scale)
    internal
    pure 
    returns (uint256) {
        uint256 a = x / scale;
        uint256 b = x % scale;
        uint256 c = y / scale;
        uint256 d = y % scale;

        return a * c * scale + a * d + b * c + b * d / scale;
    }

    /// @notice This is a payable function that distributes whatever amount it gets, to all the addresses in the splitters array, according to their royalty permyriad share set in royalties mapping.
    function distributeFunds() public nonReentrant payable {
        uint256 balance = msg.value;

        require(balance > 0, "zero balance");

        emit ReceivedFunds (msg.sender, balance, block.timestamp);

        uint256 splittersLength = splitters.length;
        for (uint256 i = 0; i < splittersLength; i++) {
            uint256 value = mulScale(permyriads[i], balance, 10000);

            (bool success, ) = payable(splitters[i]).call{value: value}("");
            require(success, "Transfer failed");

            emit SentSplit (msg.sender, splitters[i], value, block.timestamp);
        }
    }

    /// @notice Takes in an address and returns how much permyriad share of the total royalty the address was originally entitled to.
    /// @param _address Address whose royalty precentage share information to fetch.
    /// @return uint256 - Permyriad Royalty the address was originally entitled to.
    function royaltySplitInfo(address _address) external view returns (uint256) {
        uint256 royaltyPermyriad = royalties[_address];
        return royaltyPermyriad;
    }
}

// SPDX-License-Identifier: ISC
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./PermissionManagement.sol";
import "./utils/Payable.sol";
import "./Splits.sol";

/// @title The Splits Factory Contract Instance
/// @author [email protected]
/// @notice This is the Minimal Splits Proxy Factory Contract
contract SplitsFactory is Payable, ReentrancyGuard {
    address public splitsContractAddress;
    address[] public allProxies;

    event NewProxy (address indexed contractAddress, address indexed createdBy, uint256 timestamp);

    constructor (
        address _splitsContractAddress, 
        address _permissionManagementContractAddress
    ) 
    Payable(_permissionManagementContractAddress) 
    {
        splitsContractAddress = _splitsContractAddress;
    }

    function _clone() internal returns (address result) {
        bytes20 targetBytes = bytes20(splitsContractAddress);

        //-> learn more: https://coinsbench.com/minimal-proxy-contracts-eip-1167-9417abf973e3 & https://medium.com/coinmonks/diving-into-smart-contracts-minimal-proxy-eip-1167-3c4e7f1a41b8
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }

        require(result != address(0), "ERC1167: clone failed");
    }

    function createProxy(
        address[] memory _splitters,
        uint256[] memory _permyriads
    ) external nonReentrant returns (address result) {
        address proxy = _clone();
        allProxies.push(proxy);
        Splits(payable(proxy)).initialize(_splitters, _permyriads);
        emit NewProxy (proxy, msg.sender, block.timestamp);
        return proxy;
    }

    function changeSplitsContractAddress(address _splitsContractAddress) 
        external
        nonReentrant
        returns(address)
    {
        permissionManagement.adminOnlyMethod(msg.sender);
        splitsContractAddress = _splitsContractAddress;
        return _splitsContractAddress;
    }
}

// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "./ERC721/ERC721.sol";
import "../PermissionManagement.sol";

/// @title Admin Operations Contract
/// @author [email protected]
/// @notice An ERC721 Inheritable contract that provides Admins the ability to have ultimate permissions over all the Tokens of this contract
/// @dev Monument Market Contract will use `marketTransfer` function to be able to transfer tokens without explicit approval.
abstract contract AdminOps is ERC721 {
  PermissionManagement private permissionManagement;

  constructor (
    address _permissionManagementContractAddress
  ) {
    permissionManagement = PermissionManagement(_permissionManagementContractAddress);
  }

  // all functions below this give permissions to the admins to have complete access to tokens in the project
  // its use is heavily discouraged in a decentralised ecosystem
  // it's recommended that all admins except the market contract give up their admin perms later down the road, or maybe delegate those powers to another transparent contract to ensure trust.

  // function intended to be used, only by the market contract  
  function marketTransfer(address _from, address _to, uint256 _tokenId) 
    public 
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _transfer(_from, _to, _tokenId);
    return _tokenId;
  }

  function godlyMint(address _to, uint256 _tokenId) 
    public
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _safeMint(_to, _tokenId);
    return _tokenId;
  }

  function godlyBurn(uint256 _tokenId) 
    public
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _burn(_tokenId);
    return _tokenId;
  }

  function godlyApprove(address _to, uint256 _tokenId) 
    public
    returns(uint256)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _approve(_to, _tokenId);
    return _tokenId;
  }

  function godlyApproveForAll(address _owner, address _operator, bool _shouldApprove) 
    public
    returns(address)
  {
    permissionManagement.adminOnlyMethod(msg.sender);
    _setApprovalForAll(_owner, _operator, _shouldApprove);
    return _owner;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    // /**
    //  * @dev See {IERC165-supportsInterface}.
    //  */
    // function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
    //     return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    // }

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

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

/**
 * Author: Kumar Abhirup (kumareth)
 * Version: 2.0.0
 * Compiles best with: 0.8.4

 * Many contracts have ownerOnly functions, 
 * but I believe it's safer to have multiple owner addresses
 * to fallback to, in case you lose one.

 * You can inherit this PermissionManagement contract
 * to let multiple people do admin operations on your contract effectively.

 * You can add & remove admins and moderators.
 * You can transfer ownership (basically you can change the founder).
 * You can change the beneficiary (the prime payable wallet) as well.

 * Use modifiers like "founderOnly", "adminOnly", "moderatorOnly"
 * in your contract to put the permissions to use.
 */

/// @title PermissionManagement Contract
/// @author [email protected]
/// @notice Like Openzepplin Ownable, but with many Admins and Moderators.
/// @dev Like Openzepplin Ownable, but with many Admins and Moderators.
/// In Monument.app context, It's recommended that all the admins except the Market Contract give up their admin perms later down the road, or maybe delegate those powers to another transparent contract to ensure trust.
contract PermissionManagement {
  address public founder = msg.sender;
  address payable public beneficiary = payable(msg.sender);

  mapping(address => bool) public admins;
  mapping(address => bool) public moderators;

  enum RoleChange { 
    MADE_FOUNDER, 
    MADE_BENEFICIARY, 
    PROMOTED_TO_ADMIN, 
    PROMOTED_TO_MODERATOR, 
    DEMOTED_TO_MODERATOR, 
    KICKED_FROM_TEAM
  }

  event PermissionsModified(address _address, RoleChange _roleChange);

  constructor (
    address[] memory _admins, 
    address[] memory _moderators
  ) {
    // require more admins for safety and backup
    uint256 adminsLength = _admins.length;
    require(adminsLength > 0, "no admin addresses");

    // make founder the admin and moderator
    admins[founder] = true;
    moderators[founder] = true;
    emit PermissionsModified(founder, RoleChange.MADE_FOUNDER);

    // give admin privileges, and also make admins moderators.
    for (uint256 i = 0; i < adminsLength; i++) {
      admins[_admins[i]] = true;
      moderators[_admins[i]] = true;
      emit PermissionsModified(_admins[i], RoleChange.PROMOTED_TO_ADMIN);
    }

    // give moderator privileges
    uint256 moderatorsLength = _moderators.length;
    for (uint256 i = 0; i < moderatorsLength; i++) {
      moderators[_moderators[i]] = true;
      emit PermissionsModified(_moderators[i], RoleChange.PROMOTED_TO_MODERATOR);
    }
  }

  modifier founderOnly() {
    require(
      msg.sender == founder,
      "not a founder."
    );
    _;
  }

  modifier adminOnly() {
    require(
      admins[msg.sender] == true,
      "not an admin"
    );
    _;
  }

  modifier moderatorOnly() {
    require(
      moderators[msg.sender] == true,
      "not a moderator"
    );
    _;
  }

  modifier addressMustNotBeFounder(address _address) {
    require(
      _address != founder,
      "address is founder"
    );
    _;
  }

  modifier addressMustNotBeAdmin(address _address) {
    require(
      admins[_address] != true,
      "address is admin"
    );
    _;
  }

  modifier addressMustNotBeModerator(address _address) {
    require(
      moderators[_address] != true,
      "address is moderator"
    );
    _;
  }

  modifier addressMustNotBeBeneficiary(address _address) {
    require(
      _address != beneficiary,
      "address is beneficiary"
    );
    _;
  }

  function founderOnlyMethod(address _address) external view {
    require(
      _address == founder,
      "not a founder."
    );
  }

  function adminOnlyMethod(address _address) external view {
    require(
      admins[_address] == true,
      "not an admin"
    );
  }

  function moderatorOnlyMethod(address _address) external view {
    require(
      moderators[_address] == true,
      "not a moderator"
    );
  }

  function addressMustNotBeFounderMethod(address _address) external view {
    require(
      _address != founder,
      "address is founder"
    );
  }

  function addressMustNotBeAdminMethod(address _address) external view {
    require(
      admins[_address] != true,
      "address is admin"
    );
  }

  function addressMustNotBeModeratorMethod(address _address) external view {
    require(
      moderators[_address] != true,
      "address is moderator"
    );
  }

  function addressMustNotBeBeneficiaryMethod(address _address) external view {
    require(
      _address != beneficiary,
      "address is beneficiary"
    );
  }

  function transferFoundership(address payable _founder) 
    external 
    founderOnly
    addressMustNotBeFounder(_founder)
    returns(address)
  {
    require(_founder != msg.sender, "not yourself");
    
    founder = _founder;
    admins[_founder] = true;
    moderators[_founder] = true;

    emit PermissionsModified(_founder, RoleChange.MADE_FOUNDER);

    return founder;
  }

  function changeBeneficiary(address payable _beneficiary) 
    external
    adminOnly
    returns(address)
  {
    require(_beneficiary != msg.sender, "not yourself");
    
    beneficiary = _beneficiary;
    emit PermissionsModified(_beneficiary, RoleChange.MADE_BENEFICIARY);

    return beneficiary;
  }

  function addAdmin(address _admin) 
    external 
    adminOnly
    returns(address) 
  {
    admins[_admin] = true;
    moderators[_admin] = true;
    emit PermissionsModified(_admin, RoleChange.PROMOTED_TO_ADMIN);
    return _admin;
  }

  function removeAdmin(address _admin) 
    external 
    adminOnly
    addressMustNotBeFounder(_admin)
    returns(address) 
  {
    require(_admin != msg.sender, "not yourself");
    delete admins[_admin];
    emit PermissionsModified(_admin, RoleChange.DEMOTED_TO_MODERATOR);
    return _admin;
  }

  function addModerator(address _moderator) 
    external 
    adminOnly
    returns(address) 
  {
    moderators[_moderator] = true;
    emit PermissionsModified(_moderator, RoleChange.PROMOTED_TO_MODERATOR);
    return _moderator;
  }

  function removeModerator(address _moderator) 
    external 
    adminOnly
    addressMustNotBeFounder(_moderator)
    addressMustNotBeAdmin(_moderator)
    returns(address) 
  {
    require(_moderator != msg.sender, "not yourself");
    delete moderators[_moderator];
    emit PermissionsModified(_moderator, RoleChange.KICKED_FROM_TEAM);
    return _moderator;
  }
}

// SPDX-License-Identifier: ISC
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC721/IERC721.sol";
import "../PermissionManagement.sol";

/// @title Payable Contract
/// @author [email protected]
/// @notice If this abstract contract is inherited, the Contract becomes payable, it also allows Admins to manage Assets owned by the Contract.
abstract contract Payable {
  PermissionManagement internal permissionManagement;

  constructor (
    address _permissionManagementContractAddress
  ) {
    permissionManagement = PermissionManagement(_permissionManagementContractAddress);
  }

  event ReceivedFunds(
    address indexed by,
    uint256 fundsInwei,
    uint256 timestamp
  );

  event SentToBeneficiary(
    address indexed actionCalledBy,
    address indexed beneficiary,
    uint256 fundsInwei,
    uint256 timestamp
  );

  event ERC20SentToBeneficiary(
    address indexed actionCalledBy,
    address indexed beneficiary,
    address indexed erc20Token,
    uint256 tokenAmount,
    uint256 timestamp
  );

  event ERC721SentToBeneficiary(
    address indexed actionCalledBy,
    address indexed beneficiary,
    address indexed erc721ContractAddress,
    uint256 tokenId,
    uint256 timestamp
  );

  function getBalance() public view returns(uint256) {
    return address(this).balance;
  }

  /// @notice To pay the contract
  function fund() external payable {
    emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
  }

  fallback() external virtual payable {
    emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
  }

  receive() external virtual payable {
    emit ReceivedFunds(msg.sender, msg.value, block.timestamp);
  }

  /// So the Admins can maintain control over all the Funds the Contract might own in future
  /// @notice Sends Wei the Contract might own, to the Beneficiary
  /// @param _amountInWei Amount in Wei you think the Contract has, that you want to send to the Beneficiary
  function sendToBeneficiary(uint256 _amountInWei) external returns(uint256) {
    permissionManagement.adminOnlyMethod(msg.sender);

    (bool success, ) = payable(permissionManagement.beneficiary()).call{value: _amountInWei}("");
    require(success, "Transfer to Beneficiary failed.");
    
    emit SentToBeneficiary(msg.sender, permissionManagement.beneficiary(), _amountInWei, block.timestamp);
    return _amountInWei;
  }

  /// So the Admins can maintain control over all the ERC20 Tokens the Contract might own in future
  /// @notice Sends ERC20 tokens the Contract might own, to the Beneficiary
  /// @param _erc20address Address of the ERC20 Contract
  /// @param _tokenAmount Amount of Tokens you wish to send to the Beneficiary.
  function sendERC20ToBeneficiary(address _erc20address, uint256 _tokenAmount) external returns(address, uint256) {
    permissionManagement.adminOnlyMethod(msg.sender);

    IERC20 erc20Token;
    erc20Token = IERC20(_erc20address);

    erc20Token.transfer(permissionManagement.beneficiary(), _tokenAmount);

    emit ERC20SentToBeneficiary(msg.sender, permissionManagement.beneficiary(), _erc20address, _tokenAmount, block.timestamp);

    return (_erc20address, _tokenAmount);
  }

  /// So the Admins can maintain control over all the ERC721 Tokens the Contract might own in future.
  /// @notice Sends ERC721 tokens the Contract might own, to the Beneficiary
  /// @param _erc721address Address of the ERC721 Contract
  /// @param _tokenId ID of the Token you wish to send to the Beneficiary.
  function sendERC721ToBeneficiary(address _erc721address, uint256 _tokenId) external returns(address, uint256) {
    permissionManagement.adminOnlyMethod(msg.sender);

    IERC721 erc721Token;
    erc721Token = IERC721(_erc721address);

    erc721Token.safeTransferFrom(address(this), permissionManagement.beneficiary(), _tokenId);

    emit ERC721SentToBeneficiary(msg.sender, permissionManagement.beneficiary(), _erc721address, _tokenId, block.timestamp);

    return (_erc721address, _tokenId);
  }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "./utils/Address.sol";
import "./utils/Context.sol";
import "./utils/Strings.sol";
import "./utils/introspection/ERC165.sol";

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

        // _operatorApprovals[_msgSender()][operator] = approved;
        // emit ApprovalForAll(_msgSender(), operator, approved);

        _setApprovalForAll(_msgSender(), operator, approved);
    }

    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
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

import "./utils/introspection/IERC165.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
     */
    modifier initializer() {
        bool isTopLevelCall = _setInitializedVersion(1);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     */
    modifier reinitializer(uint8 version) {
        bool isTopLevelCall = _setInitializedVersion(version);
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(version);
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     */
    function _disableInitializers() internal virtual {
        _setInitializedVersion(type(uint8).max);
    }

    function _setInitializedVersion(uint8 version) private returns (bool) {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, and for the lowest level
        // of initializers, because in other contexts the contract may have been reentered.
        if (_initializing) {
            require(
                version == 1 && !AddressUpgradeable.isContract(address(this)),
                "Initializable: contract is already initialized"
            );
            return false;
        } else {
            require(_initialized < version, "Initializable: contract is already initialized");
            _initialized = version;
            return true;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
// OpenZeppelin Contracts v4.4.1 (proxy/Clones.sol)

pragma solidity ^0.8.0;

/**
 * @dev https://eips.ethereum.org/EIPS/eip-1167[EIP 1167] is a standard for
 * deploying minimal proxy contracts, also known as "clones".
 *
 * > To simply and cheaply clone contract functionality in an immutable way, this standard specifies
 * > a minimal bytecode implementation that delegates all calls to a known, fixed address.
 *
 * The library includes functions to deploy a proxy using either `create` (traditional deployment) or `create2`
 * (salted deterministic deployment). It also includes functions to predict the addresses of clones deployed using the
 * deterministic method.
 *
 * _Available since v3.4._
 */
library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt) internal returns (address instance) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(add(ptr, 0x28), 0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000)
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}