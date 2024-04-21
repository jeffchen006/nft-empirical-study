/**
 *Submitted for verification at Etherscan.io on 2022-12-14
*/

// Sources flattened with hardhat v2.12.4 https://hardhat.org

// File @openzeppelin/contracts/token/ERC721/[email protected]

// 
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

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
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File contracts/dualRoles/wrap/IWrapNFT.sol

// 

pragma solidity ^0.8.0;

interface IWrapNFT is IERC721Receiver {
    event Stake(address msgSender, address nftAddress, uint256 tokenId);

    event Redeem(address msgSender, address nftAddress, uint256 tokenId);

    function originalAddress() external view returns (address);

    function stake(uint256 tokenId) external returns (uint256);

    function redeem(uint256 tokenId) external;
}


// File @openzeppelin/contracts/utils/introspection/[email protected]

// 
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


// File contracts/v2/IDoNFTV2.sol

// 
pragma solidity ^0.8.0;

interface IDoNFTV2 {
    enum DoNFTModelType {
        ERC4907Model, // 0
        WrapModel // 1
    }

    struct DoNftInfoV2 {
        uint256 originalNftId;
        address originalNftAddress;
        uint40 startTime; 
        uint40 endTime;  
        uint16 nonce;  
    }

    event MetadataUpdate(uint256 tokenId);


    function getModelType() external view returns (DoNFTModelType);

    function mintVNft(address oNftAddress,uint256 originalNftId) external returns (uint256);

    function mint(  
        uint256 tokenId,
        address to,
        address user,
        uint40 endTime
    ) external returns (uint256 tid);

    function setMaxDuration(uint40 v) external;

    function getMaxDuration() external view returns (uint40);

    function getDoNftInfo(uint256 tokenId)
        external
        view
        returns (
            uint256 originalNftId,
            address originalNftAddress,
            uint16 nonce,
            uint40 startTime,
            uint40 endTime
        );

    function getOriginalNftId(uint256 tokenId) external view returns (uint256);

    function getOriginalNftAddress(uint256 tokenId) external view returns (address);

    function getNonce(uint256 tokenId) external view returns (uint16);

    function getStartTime(uint256 tokenId) external view returns (uint40);

    function getEndTime(uint256 tokenId) external view returns (uint40);

    function getVNftId(address originalNftAddress, uint256 originalNftId) external view returns (uint256);

    function getUser(address originalNftAddress, uint256 originalNftId) external view returns (address);

    function isVNft(uint256 tokenId) external view returns (bool);

    function isValidNow(uint256 tokenId) external view returns (bool);

    function checkIn(address to, uint256 tokenId) external;

    function exists(uint256 tokenId) external view returns (bool);

    function couldRedeem(uint256 tokenId) external view returns (bool);

    function redeem(uint256 tokenId) external;
}


// File contracts/v2/IMarketV2.sol

// 
pragma solidity >=0.6.6 <0.9.0;

interface IMarketV2 {
    enum OrderType {
        Public, // 0
        Private // 1
    }

    struct Lending {  
        address lender; 
        uint40 maxEndTime; 
        uint16 nonce; 
        uint40 minDuration; 
        OrderType orderType; 
        address paymentToken; 
        address privateOrderRenter; 
        uint96 pricePerDay;
    }

    struct RoyaltyInfo {
        address royaltyAdmin;
        address beneficiary;
        uint32 royaltyFee;
    }

    event CreateLendOrderV2(   
        address lender, 
        uint40 maxEndTime, 
        OrderType orderType, 
        address erc4907NftAddress,
        uint96 pricePerDay, 
        uint256 erc4907NftId, 
        address doNftAddress,
        uint40 minDuration, 
        uint256 doNftId, 
        address paymentToken, 
        address privateOrderRenter
    );

    event CancelLendOrder(address lender, address nftAddress, uint256 nftId);
   
    event FulfillOrderV2(  
        address renter,  
        uint40 startTime, 
        address lender, 
        uint40 endTime,  
        address erc4907NftAddress,  
        uint256 erc4907NftId, 
        address doNftAddress, 
        uint256 doNftId,
        uint256 newId,
        address paymentToken,
        uint96 pricePerDay
    );

    event Paused(address account);
    event Unpaused(address account);

    event RoyaltyAdminChanged(address operator, address erc4907NftAddress, address royaltyAdmin);
    event RoyaltyBeneficiaryChanged(address operator, address erc4907NftAddress, address beneficiary);
    event RoyaltyFeeChanged(address operator, address erc4907NftAddress, uint32 royaltyFee);

    function createLendOrder( 
        address doNftAddress,
        uint40 maxEndTime, 
        OrderType orderType, 
        uint256 doNftId, 
        address paymentToken, 
        uint96 pricePerDay,  
        address privateOrderRenter, 
        uint40 minDuration 
    ) external;




    function mintAndCreateLendOrder(
        address erc4907NftAddress, 
        uint96 pricePerDay, 
        address doNftAddress, 
        uint40 maxEndTime, 
        uint256 erc4907NftId, 
        address paymentToken,
        uint40 minDuration,
        OrderType orderType,  
        address privateOrderRenter
    ) external;

    function cancelLendOrder(address nftAddress, uint256 nftId) external;

    function getLendOrder(address nftAddress, uint256 nftId)
        external
        view
        returns (Lending memory);

    function fulfillOrderNow(
        address doNftAddress, 
        uint40 duration, 
        uint256 doNftId,  
        address user,  
        address paymentToken, 
        uint96 pricePerDay 
    ) external payable;

    function setMarketFee(uint256 fee) external;

    function getMarketFee() external view returns (uint256);

    function setMarketBeneficiary(address payable beneficiary) external;

    function claimMarketFee(address[] calldata paymentTokens) external;

    function setRoyaltyAdmin(address erc4907NftAddress, address royaltyAdmin) external;
      
    function getRoyaltyAdmin(address erc4907NftAddress) external view returns(address);

    function setRoyaltyBeneficiary(address erc4907NftAddress, address  beneficiary) external; 

    function getRoyaltyBeneficiary(address erc4907NftAddress) external view returns (address);

    function balanceOfRoyalty(address erc4907NftAddress, address paymentToken) external view returns (uint256);

    function setRoyaltyFee(address erc4907NftAddress, uint32 royaltyFee) external;

    function getRoyaltyFee(address erc4907NftAddress) external view returns (uint32);

    function claimRoyalty(address erc4907NftAddress, address[] calldata paymentTokens) external;

    function isLendOrderValid(address nftAddress, uint256 nftId) external view returns (bool);

    function setPause(bool v) external;
}


// File @openzeppelin/contracts/token/ERC721/[email protected]

// 
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

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


// File @openzeppelin/contracts/token/ERC721/extensions/[email protected]

// 
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

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


// File contracts/v2/MiddleWareV2.sol

// 
pragma solidity ^0.8.0;





interface IDoNFT2 is IDoNFTV2, IERC721 {}

contract MiddleWareV2 {
    struct DoNftMarketInfo {
        uint256 originalNftId;
        address orderPaymentToken;
        uint96 orderPricePerDay;         
        address owner;
        uint40 endTime;
        uint32 orderFee; //   ratio = fee / 1e5 , orderFee = 1000 means 1%
        address user;
        uint32 orderCreateTime;
        uint32 orderMinDuration;
        uint32 orderMaxEndTime;
        address orderPrivateRenter;
        uint40 startTime;
        address originalNftAddress;
        uint8 orderType; // 0: Public, 1: Private, 2: Event_Private
        bool orderIsValid; 
        bool isVNft;
    }


    function getNftOwnerAndUser(
        address originalNftAddr,
        uint256 orginalNftId,
        address doNftAddr
    ) public view returns (address owner, address user) {
        IDoNFTV2 doNft = IDoNFTV2(doNftAddr);
        IERC721Metadata oNft = IERC721Metadata(originalNftAddr);

        try oNft.ownerOf(orginalNftId) returns (address ownerAddr) {
            owner = ownerAddr;
        } catch {}

        try doNft.getUser(originalNftAddr,orginalNftId) returns (address userAddr) {
            user = userAddr;
        } catch {}
    }

    function getDoNftMarketInfo(
        address doNftAddr,
        uint256 doNftId,
        address marketAddr
    ) public view returns (DoNftMarketInfo memory doNftInfo) {
        IDoNFT2 doNft = IDoNFT2(doNftAddr);
        IMarketV2 market = IMarketV2(marketAddr);

        doNftInfo.orderFee = uint32(market.getMarketFee()) ;

        if (doNft.exists(doNftId)) {
            (
            doNftInfo.originalNftId,
            doNftInfo.originalNftAddress,
            ,
            doNftInfo.startTime,
            doNftInfo.endTime

            ) = doNft.getDoNftInfo(doNftId);
            
            doNftInfo.orderFee += market.getRoyaltyFee(doNftInfo.originalNftAddress);
            doNftInfo.owner = doNft.ownerOf(doNftId);
          
            doNftInfo.user = doNft.getUser(doNftInfo.originalNftAddress, doNftInfo.originalNftId);
            doNftInfo.orderIsValid = market.isLendOrderValid(doNftAddr, doNftId);
            doNftInfo.isVNft = doNft.isVNft(doNftId);
            if (doNftInfo.orderIsValid) {
                IMarketV2.Lending memory order = market.getLendOrder(
                    doNftAddr,
                    doNftId
                );
                
                if (
                    order.orderType == IMarketV2.OrderType.Private 
                ) {
                    doNftInfo.orderPrivateRenter = order.privateOrderRenter;
                }
                doNftInfo.orderType = uint8(order.orderType);
                doNftInfo.orderMinDuration = uint32(order.minDuration);
                doNftInfo.orderMaxEndTime = uint32(order.maxEndTime);
                doNftInfo.orderPricePerDay = uint96(order.pricePerDay);
                doNftInfo.orderPaymentToken = order.paymentToken;                
            }

            if(doNft.getModelType() == IDoNFTV2.DoNFTModelType.WrapModel) {
                    address wrapNftAddress = doNftInfo.originalNftAddress;
                    doNftInfo.originalNftAddress =  IWrapNFT(wrapNftAddress).originalAddress();
            }
        }
    }
}