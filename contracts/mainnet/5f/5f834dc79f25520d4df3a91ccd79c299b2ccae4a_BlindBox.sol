// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "./GenerativeBB.sol";
import "./NonGenerativeBB.sol";

contract BlindBox is NonGenerativeBB {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    

     struct Series1 {
        string name;
        string seriesURI;
        string boxName;
        string boxURI;
        uint256 startTime;
        uint256 endTime;
        string collection; 
    }
    struct Series2 {
        uint256 maxBoxes;
        uint256 perBoxNftMint;
        uint256 perBoxPrice;
        address bankAddress;
        uint256 baseCurrency;
        uint256[] allowedCurrencies; 
        string name;
    }
    /** 
    @dev constructor initializing blindbox
    */
    constructor() payable  {

    }

    /** 
    @dev this function is to start new series of blindbox
    @param isGenerative flag to show either newely started series is of Generative blindbox type or Non-Generative
    @notice only owner of the contract can trigger this function.
    */
    function StartSeries(
        // address[] memory addressData, // [collection, bankAddress]
        string[] memory stringsData, // [name, seriesURI, boxName, boxURI]
       uint256[] memory integerData, //[startTime, endTime, maxBoxes, perBoxNftMint, perBoxPrice, baseCurrency]
       uint256[] memory allowedCurrencies,
        bool isGenerative,  address bankAddress, uint256 royalty, bool isWhiteListed, bool _isCryptoAlowed ) onlyOwner public {
            Series1 memory series = Series1( stringsData[0], stringsData[1], stringsData[2], stringsData[3], integerData[0], integerData[1],stringsData[4]);
        if(isGenerative){
            // start generative series
            // generativeSeriesId.increment();
            generativeSeries(stringsData[4],  stringsData[0], stringsData[1], stringsData[2], stringsData[3], integerData[0], integerData[1], royalty);
           
            // emit SeriesInputValue(series,generativeSeriesId.current(), isGenerative,  royalty);
 
        } else { 
            _isWhiteListed[nonGenerativeSeriesId.current()] = isWhiteListed;
            _perBoxUserLimit[nonGenerativeSeriesId.current()] = integerData[6];
            // _isCryptoAllowed[nonGenerativeSeriesId.current()] = _isCryptoAlowed;
            nonGenerativeSeriesId.increment();
            // start non-generative series
            nonGenerativeSeries(stringsData[4], stringsData[0], stringsData[1], stringsData[2], stringsData[3], integerData[0], integerData[1], royalty);
           
        emit SeriesInputValue(series,nonGenerativeSeriesId.current(), isGenerative, royalty, isWhiteListed );
          }
       extraPsrams(integerData, bankAddress, allowedCurrencies, isGenerative, stringsData[0]);
        
    }
    function extraPsrams(uint256[] memory integerData, //[startTime, endTime, maxBoxes, perBoxNftMint, perBoxPrice, baseCurrency]
         address bankAddress,
        uint256[] memory allowedCurrencies, bool isGenerative, string memory blindName) internal {
        if(isGenerative){
      setExtraParamsGen(integerData[5], allowedCurrencies, bankAddress, integerData[4], integerData[2], integerData[3]);  

        } else {
      setExtraParams(integerData[5], allowedCurrencies, bankAddress, integerData[4], integerData[2], integerData[3]);  

        }
        Series2 memory series = Series2(integerData[2], integerData[3], integerData[4], bankAddress, integerData[5], allowedCurrencies, blindName );
        emit Series1InputValue(series,nonGenerativeSeriesId.current(), isGenerative );
    }
    // add URIs/attributes in series [handled in respective BBs]
    function updateWhiteList(uint256 seriesId, bool isWhiteListed)onlyOwner public {
      _isWhiteListed[seriesId] = isWhiteListed;
    }
    
    fallback() payable external {}
    receive() payable external {}
  event SeriesInputValue(Series1 _series, uint256 seriesId, bool isGenerative, uint256 royalty, bool whiteListOnly);
    event Series1InputValue(Series2 _series, uint256 seriesId, bool isGenerative);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IRand {
    function getRandomNumber() external returns (bytes32 requestId);
    function getRandomVal() external view returns (uint256); 

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Proxy/BlindboxStorage.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';


contract Utils is Ownable, BlindboxStorage{
     using Counters for Counters.Counter;
    using SafeMath for uint256;
   
  
  
    
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '../IERC20.sol';
import '../VRF/IRand.sol';
import '../INFT.sol';
import '../IDEX.sol';
import "../LPInterface.sol";

///////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * @title DexStorage
 * @dev Defining dex storage for the proxy contract.
 */
///////////////////////////////////////////////////////////////////////////////////////////////////

contract BlindboxStorage {
 using Counters for Counters.Counter;
    using SafeMath for uint256;

    address a;
    address b;
    address c;

    IRand vrf;
    IERC20 ALIA;
    IERC20 ETH;
    IERC20 USD;
    IERC20 MATIC;
    INFT nft;
    IDEX dex;
    address platform;
    IERC20 internal token;
    
    Counters.Counter internal _boxId;

 Counters.Counter public generativeSeriesId;

    struct Attribute {
        string name;
        string uri;
        uint256 rarity;
    }

    struct GenerativeBox {
        string name;
        string boxURI;
        uint256 series; // to track start end Time
        uint256 countNFTs;
        // uint256[] attributes;
        // uint256 attributesRarity;
        bool isOpened;
    }

    struct GenSeries {
        string name;
        string seriesURI;
        string boxName;
        string boxURI;
        uint256 startTime;
        uint256 endTime;
        uint256 maxBoxes;
        uint256 perBoxNftMint;
        uint256 price; // in ALIA
        Counters.Counter boxId; // to track series's boxId (upto minted so far)
        Counters.Counter attrType; // attribute Type IDs
        Counters.Counter attrId; // attribute's ID
        // attributeType => attributeId => Attribute
        mapping ( uint256 => mapping( uint256 => Attribute)) attributes;
        // attributes combination hash => flag
        mapping ( bytes32 => bool) blackList;
    }

    struct NFT {
        // attrType => attrId
        mapping (uint256 => uint256) attribute;
    }

    // seriesId => Series
    mapping ( uint256 => GenSeries) public genSeries;
   mapping ( uint256 => uint256) public genseriesRoyalty;
    mapping ( uint256 => uint256[]) _allowedCurrenciesGen;
    mapping ( uint256 => address) public bankAddressGen;
    mapping ( uint256 => uint256) public baseCurrencyGen;
    mapping (uint256=>string) public genCollection;
    // boxId => attributeType => attributeId => Attribute
    // mapping( uint256 => mapping ( uint256 => mapping( uint256 => Attribute))) public attributes;
    // boxId => Box
    mapping ( uint256 => GenerativeBox) public boxesGen;
    // attributes combination => flag
    // mapping ( bytes => bool) public blackList;
    // boxId => boxOpener => array of combinations to be minted
    // mapping ( uint256 => mapping ( address => bytes[] )) public nftToMint;
    // boxId => owner
    mapping ( uint256 => address ) public genBoxOwner;
    // boxId => NFT index => attrType => attribute
    mapping (uint256 => mapping( uint256 => mapping (uint256 => uint256))) public nftsToMint;
  

    Counters.Counter public nonGenerativeSeriesId;
    // mapping(address => Counters.Counter) public nonGenerativeSeriesIdByAddress;
    struct URI {
        string name;
        string uri;
        uint256 rarity;
        uint256 copies;
    }

    struct NonGenerativeBox {
        string name;
        string boxURI;
        uint256 series; // to track start end Time
        uint256 countNFTs;
        // uint256[] attributes;
        // uint256 attributesRarity;
        bool isOpened;
    }

    struct NonGenSeries {
        string collection;
        string name;
        string seriesURI;
        string boxName;
        string boxURI;
        uint256 startTime;
        uint256 endTime;
        uint256 maxBoxes;
        uint256 perBoxNftMint;
        uint256 price; 
        Counters.Counter boxId; // to track series's boxId (upto minted so far)
        Counters.Counter attrId; 
        // uriId => URI 
        mapping ( uint256 => URI) uris;
    }

    struct IDs {
        Counters.Counter attrType;
        Counters.Counter attrId;
    }

    struct CopiesData{
        
        uint256 total;
        mapping(uint256 => uint256) nftCopies;
    }
    mapping (uint256 => CopiesData) public _CopiesData;
    
    // seriesId => NonGenSeries
    mapping ( uint256 => NonGenSeries) public nonGenSeries;

   mapping ( uint256 => uint256[]) _allowedCurrencies;
   mapping ( uint256 => address) public bankAddress;
   mapping ( uint256 => uint256) public nonGenseriesRoyalty;
   mapping ( uint256 => uint256) public baseCurrency;
    // boxId => IDs
    // mapping (uint256 => IDs) boxIds;
    // boxId => attributeType => attributeId => Attribute
    // mapping( uint256 => mapping ( uint256 => mapping( uint256 => Attribute))) public attributes;
    // boxId => Box
    mapping ( uint256 => NonGenerativeBox) public boxesNonGen;
    // attributes combination => flag
    // mapping ( bytes => bool) public blackList;
    // boxId => boxOpener => array of combinations to be minted
    // mapping ( uint256 => mapping ( address => bytes[] )) public nftToMint;
    // boxId => owner
    mapping ( uint256 => address ) public nonGenBoxOwner;
    // boxId => NFT index => attrType => attribute
    // mapping (uint256 => mapping( uint256 => mapping (uint256 => uint256))) public nfts;
    mapping(string => mapping(bool => uint256[])) seriesIdsByCollection;
    uint256 deployTime;
     LPInterface LPAlia;
    LPInterface LPWETH;
    LPInterface LPMATIC;
     mapping(bytes32 => mapping(uint256 => bool)) _whitelisted;
    mapping(uint256 => bool) _isWhiteListed;
    mapping(address => mapping (uint256=>uint256)) _boxesCrytpoUser;
    mapping( string => mapping (uint256=>uint256)) _boxesNoncryptoUser;
    mapping (uint256 => uint256) _perBoxUserLimit;
    mapping (uint256 => bool) _isCryptoAllowed;
    mapping (uint256 => uint256) _registrationFee;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './GenerativeBB.sol';

contract NonGenerativeBB is GenerativeBB {
 using Counters for Counters.Counter;
    using SafeMath for uint256;
  function nonGenerativeSeries(string memory bCollection,string memory name, string memory seriesURI, string memory boxName, string memory boxURI, uint256 startTime, uint256 endTime, uint256 royalty) onlyOwner internal {
        require(startTime < endTime, "invalid series endTime");
        nonGenSeries[nonGenerativeSeriesId.current()].collection = bCollection;
        seriesIdsByCollection[bCollection][false].push(nonGenerativeSeriesId.current());
        nonGenSeries[nonGenerativeSeriesId.current()].name = name;
        nonGenSeries[nonGenerativeSeriesId.current()].seriesURI = seriesURI;
        nonGenSeries[nonGenerativeSeriesId.current()].boxName = boxName;
        nonGenSeries[nonGenerativeSeriesId.current()].boxURI = boxURI;
        nonGenSeries[nonGenerativeSeriesId.current()].startTime = startTime;
        nonGenSeries[nonGenerativeSeriesId.current()].endTime = endTime;
        nonGenseriesRoyalty[nonGenerativeSeriesId.current()] = royalty;

        emit NewNonGenSeries( nonGenerativeSeriesId.current(), name, startTime, endTime);
    }
    function setExtraParams(uint256 _baseCurrency, uint256[] memory allowedCurrecny, address _bankAddress, uint256 boxPrice, uint256 maxBoxes, uint256 perBoxNftMint) internal {
        baseCurrency[nonGenerativeSeriesId.current()] = _baseCurrency;
        _allowedCurrencies[nonGenerativeSeriesId.current()] = allowedCurrecny;
        bankAddress[nonGenerativeSeriesId.current()] = _bankAddress;
        nonGenSeries[nonGenerativeSeriesId.current()].price = boxPrice;
        nonGenSeries[nonGenerativeSeriesId.current()].maxBoxes = maxBoxes;
        nonGenSeries[nonGenerativeSeriesId.current()].perBoxNftMint = perBoxNftMint;
    }
event NewNonGenSeries(uint256 indexed seriesId, string name, uint256 startTime, uint256 endTime);
}

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP. Does not include
 * the optional functions; to access them see {ERC20Detailed}.
 */
interface LPInterface {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

   
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface INFT {
    function mintWithTokenURI(address to, string calldata tokenURI) external returns (uint256);
    function transferFrom(address owner, address to, uint256 tokenId) external;
    function mint(address to_, uint256 countNFTs_) external returns (uint256, uint256);
}

// SPDX-License-Identifier: MIT

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
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
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
     function withdraw(uint) external;
    function deposit() payable external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IDEX {
   function calculatePrice(uint256 _price, uint256 base, uint256 currencyType, uint256 tokenId, address seller, address nft_a) external view returns(uint256);
   function mintWithCollection(address collection, address to, string memory tokesnURI, uint256 royalty ) external returns(uint256);
   function createCollection(string calldata name_, string calldata symbol_) external;
   function transferCollectionOwnership(address collection, address newOwner) external;
   function mintNFT(uint256 count) external returns(uint256,uint256);
   function mintBlindbox(address collection, address to, uint256 quantity, address from, uint256 royalty, uint256 seriesId) external returns(uint256 fromIndex,uint256 toIndex);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import './Utils.sol';
/**
@title GenerativeBB 
- this contract of blindbox's type Generative. which deals with all the operations of Generative blinboxes & series
 */
contract GenerativeBB is Utils {
    
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    constructor()  {

    }

/** 
    @dev function to start new Generative Series
        @param name - name of the series
        @param seriesURI - series metadata tracking URI
        @param boxName - name of the boxes to be created in this series
        @param boxURI - blindbox's URI tracking its metadata
        @param startTime - start time of the series, (from whom its boxes will be available to get bought)
        @param endTime - end time of the series, (after whom its boxes will not be available to get bought)

    */ 
    function generativeSeries(string memory bCollection, string memory name, string memory seriesURI, string memory boxName, string memory boxURI, uint256 startTime, uint256 endTime, uint256 royalty) onlyOwner internal {
        require(startTime < endTime, "invalid series endTime");
        seriesIdsByCollection[bCollection][true].push(generativeSeriesId.current());
        genCollection[generativeSeriesId.current()] = bCollection;
        genSeries[generativeSeriesId.current()].name = name;
        genSeries[generativeSeriesId.current()].seriesURI = seriesURI;
        genSeries[generativeSeriesId.current()].boxName = boxName;
        genSeries[generativeSeriesId.current()].boxURI = boxURI;
        genSeries[generativeSeriesId.current()].startTime = startTime;
        genSeries[generativeSeriesId.current()].endTime = endTime;

        emit NewGenSeries( generativeSeriesId.current(), name, startTime, endTime);
    }
    function setExtraParamsGen(uint256 _baseCurrency, uint256[] memory allowedCurrecny, address _bankAddress, uint256 boxPrice, uint256 maxBoxes, uint256 perBoxNftMint) internal {
        baseCurrencyGen[generativeSeriesId.current()] = _baseCurrency;
        _allowedCurrenciesGen[generativeSeriesId.current()] = allowedCurrecny;
        bankAddressGen[generativeSeriesId.current()] = _bankAddress;
        genSeries[generativeSeriesId.current()].price = boxPrice;
        genSeries[generativeSeriesId.current()].maxBoxes = maxBoxes;
        genSeries[generativeSeriesId.current()].perBoxNftMint = perBoxNftMint;
    }
    /** 
    @dev utility function to mint Generative BlindBox
        @param seriesId - id of Generative Series whose box to be opened
    @notice given series should not be ended or its max boxes already minted.
    */
    function mintGenBox(uint256 seriesId) private {
        require(genSeries[seriesId].endTime >= block.timestamp, "series ended");
        require(genSeries[seriesId].maxBoxes > genSeries[seriesId].boxId.current(),"max boxes minted of this series");
        genSeries[seriesId].boxId.increment(); // incrementing boxCount minted
        _boxId.increment(); // incrementing to get boxId

        boxesGen[_boxId.current()].name = genSeries[seriesId].boxName;
        boxesGen[_boxId.current()].boxURI = genSeries[seriesId].boxURI;
        boxesGen[_boxId.current()].series = seriesId;
        boxesGen[_boxId.current()].countNFTs = genSeries[seriesId].perBoxNftMint;
       
        // uint256[] attributes;    // attributes setting in another mapping per boxId. note: series should've all attributes [Done]
        // uint256 attributesRarity; // rarity should be 100, how to ensure ? 
                                    //from available attrubets fill them in 100 index of array as per their rarity. divide all available rarites into 100
        emit BoxMintGen(_boxId.current(), seriesId);

    }
     modifier validateCurrencyTypeGen(uint256 seriesId, uint256 currencyType, bool isPayable) {
        bool isValid = false;
        uint256[] storage allowedCurrencies = _allowedCurrenciesGen[seriesId];
        for (uint256 index = 0; index < allowedCurrencies.length; index++) {
            if(allowedCurrencies[index] == currencyType){
                isValid = true;
            }
        }
        require(isValid, "123");
        require((isPayable && currencyType == 1) || currencyType < 1, "126");
        _;
    }
/** 
    @dev function to buy Generative BlindBox
        @param seriesId - id of Generative Series whose box to be bought
    @notice given series should not be ended or its max boxes already minted.
    */
    function buyGenerativeBox(uint256 seriesId, uint256 currencyType) validateCurrencyTypeGen(seriesId, currencyType, false) internal {
        require(abi.encode(genSeries[seriesId].name).length > 0,"Series doesn't exist"); 
        require(genSeries[seriesId].maxBoxes > genSeries[seriesId].boxId.current(),"boxes sold out");
        mintGenBox(seriesId);
        token = USD; // skipping this for testing purposes
        
        uint256 price = dex.calculatePrice(genSeries[seriesId].price , baseCurrencyGen[seriesId], currencyType, 0, address(this), address(this));
        // if(currencyType == 0){
            price = price / 1000000000000;
        // }
        // escrow alia
        token.transferFrom(msg.sender, bankAddressGen[seriesId], price);
        genBoxOwner[_boxId.current()] = msg.sender;

        emit BuyBoxGen(_boxId.current(), seriesId);
    }
    function buyGenBoxPayable(uint256 seriesId) validateCurrencyTypeGen(seriesId,1, true) internal {
        require(abi.encode(genSeries[seriesId].name).length > 0,"Series doesn't exist"); 
        require(genSeries[seriesId].maxBoxes > genSeries[seriesId].boxId.current(),"boxes sold out");
        uint256 before_bal = MATIC.balanceOf(address(this));
        MATIC.deposit{value : msg.value}();
        uint256 after_bal = MATIC.balanceOf(address(this));
        uint256 depositAmount = after_bal - before_bal;
        uint256 price = dex.calculatePrice(genSeries[seriesId].price , baseCurrencyGen[seriesId], 1, 0, address(this), address(this));
        require(price <= depositAmount, "NFT 108");
        chainTransfer(bankAddressGen[seriesId], 1000, price);
        if(depositAmount - price > 0) chainTransfer(msg.sender, 1000, (depositAmount - price));
        mintGenBox(seriesId);
        // transfer box to buyer
        genBoxOwner[_boxId.current()] = msg.sender;

        emit BuyBoxGen(_boxId.current(), seriesId);
    }
    function chainTransfer(address _address, uint256 percentage, uint256 price) internal {
      address payable newAddress = payable(_address);
      uint256 initialBalance;
      uint256 newBalance;
      initialBalance = address(this).balance;
      MATIC.withdraw(SafeMath.div(SafeMath.mul(price,percentage), 1000));
      newBalance = address(this).balance.sub(initialBalance);
    //   newAddress.transfer(newBalance);
    (bool success, ) = newAddress.call{value: newBalance}("");
    require(success, "Failed to send Ether");
  }
/** 
    @dev function to open Generative BlindBox
        @param boxId - id of blind box to be opened
    @notice given box should not be already opened.
    */
    function openGenBox(uint256 boxId) internal {
        require(genBoxOwner[boxId] == msg.sender, "Box not owned");
        require(!boxesGen[boxId].isOpened, "Box already opened");
        // _openGenBox(boxId);
        _openGenBoxOffchain(boxId);

        emit BoxOpenedGen(boxId);

    }
    function _openGenBoxOffchain(uint256 boxId) private {
        // uint256 sId = boxesGen[boxId].series;
        uint256 from;
        uint256 to;
        (from, to) =dex.mintNFT(boxesGen[boxId].countNFTs); // this function should be implemented in DEX contract to return (uint256, uint256) tokenIds, for reference look into Collection.sol mint func. (can be found at Collection/Collection.sol of same repo)
        boxesGen[boxId].isOpened = true;
        emit GenNFTsMinted( boxesGen[boxId].series, boxId, from, to, 0, boxesGen[boxId].countNFTs);
    }

    
    // events
    event NewGenSeries(uint256 indexed seriesId, string name, uint256 startTime, uint256 endTime);
    event BoxMintGen(uint256 boxId, uint256 seriesId);
    event AttributesAdded(uint256 indexed seriesId, uint256 indexed attrType, uint256 from, uint256 to);
    event BuyBoxGen(uint256 boxId, uint256 seriesId);
    event BoxOpenedGen(uint256 indexed boxId);
    event BlackList(uint256 indexed seriesId, bytes32 indexed combHash, bool flag);
    event NFTsMinted(uint256 indexed boxId, address owner, uint256 countNFTs);
    event GenNFTsMinted(uint256 seriesId, uint256 indexed boxId, uint256 from, uint256 to, uint256 rand, uint256 countNFTs);
    

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
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

// SPDX-License-Identifier: MIT

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

    function _setOwner(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}