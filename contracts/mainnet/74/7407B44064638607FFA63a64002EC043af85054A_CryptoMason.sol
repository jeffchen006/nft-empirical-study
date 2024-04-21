//SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721A.sol";

contract CryptoMason is ERC721A, Ownable {
    string private baseTokenURI;

    uint256 public publicSalePrice;

    uint256 private totalNFTs;

    mapping(address => uint256) mintedNFTs;

    mapping(address => uint256) public NFTtracker;

    bool public isMintActive;
    bool public isStakeActive;

    mapping(address => address[]) public adrToAllRefs;
    mapping(address => address) public adrToParentRef;

    mapping(address => uint256) adrToCycle;

    uint256 internal refLevel1Percent;

    uint256 public NFTLimitPublic;

    uint256 public maxNFTs;

    event BaseURIChanged(string baseURI);

    event PublicSaleMint(address mintTo, uint256 tokensCount);

    event Received();

    address founderAddress;

    mapping(address => bool) registeredUsers;

    mapping(address => claim[]) claimInfo;
    mapping(address => uint256) public adrToClaimAmount;
    mapping(address => uint256) public adrToUsedClaimAmount;
    mapping(address => uint256[]) adrToIdsArray;
    mapping(address => uint256[]) adrToStakes;

    mapping(address => uint256) moneyFromAllRefs;
    mapping(address => refs[]) adrToRefsInfo;

    uint256 allMoneyForUsers;

    struct refs {
        address ref;
        uint256 money;
        uint256 date;
    }

    bool rewardAvailable;

    struct claim {
        address user;
        uint256 nftAmount;
        uint256 nftStartAmount;
        uint256[] nftIds;
        uint256 startTime;
        uint256 lockTime;
        uint256 percent;
        uint256 floor;
        uint256 rewardAmount;
        uint256 alreadyGiven;
        uint256 allowTime;
    }

    mapping(address => bool) isAdmin;
    address[] admins;

    constructor(
        string memory baseURI,
        address _founderAddress,
        uint256 maxNFT
    ) ERC721A("CryptoMason", "MASON", 100, 9999) {
        baseTokenURI = baseURI;

        founderAddress = _founderAddress;

        NFTLimitPublic = 4;

        maxNFTs = maxNFT;
        publicSalePrice = 74000000000000000;

        refLevel1Percent = 20;

        registeredUsers[founderAddress] = true;
        adrToParentRef[founderAddress] = _founderAddress;
    }

    function setPrices(uint256 _newPublicSalePrice) public onlyOwner {
        publicSalePrice = _newPublicSalePrice;
    }

    function setNFTLimits(uint256 _newLimitPublic) public onlyOwner {
        NFTLimitPublic = _newLimitPublic;
    }

    function setNFTHardcap(uint256 _newMax) public onlyOwner {
        maxNFTs = _newMax;
    }

    function registerInSystem(address referal) external {
        require(
            registeredUsers[referal] == true,
            "referal address is not registered"
        );
        require(referal != msg.sender, "You cannot be referal of yourself");
        registeredUsers[msg.sender] = true;
        adrToParentRef[msg.sender] = referal;
        adrToAllRefs[referal].push(msg.sender);
        adrToRefsInfo[adrToParentRef[msg.sender]].push(refs(msg.sender, 0, 0));
    }

    function freeMint() external {
        require(registeredUsers[msg.sender], "Not registered in system");
        require(totalNFTs + 1 <= maxNFTs, "Exceeded max NFTs amount");

        require(isMintActive, "mint is paused");

        require(
            adrToCycle[msg.sender] > 9,
            "Not enough nfts minted with your referal"
        );

        totalNFTs += 1;

        mintedNFTs[msg.sender] += 1;

        NFTtracker[msg.sender] += 1;

        adrToCycle[msg.sender] -= 10;

        _safeMint(msg.sender, 1, true, "");
    }

    function PublicMint(uint256 quantity) external payable {
        require(registeredUsers[msg.sender], "Not registered in system");
        require(totalNFTs + quantity <= maxNFTs, "Exceeded max NFTs amount");
        require(isMintActive, "mint is paused");

        require(
            NFTtracker[msg.sender] + quantity <= NFTLimitPublic,
            "Minting would exceed wallet limit"
        );
        require(quantity > 0, "Quantity has to be more than 0");

        require(
            msg.value >= publicSalePrice * quantity,
            "Fund amount is incorrect"
        );

        _safeMint(msg.sender, quantity, true, "");

        totalNFTs += quantity;

        NFTtracker[msg.sender] += quantity;
        mintedNFTs[msg.sender] += quantity;

        uint256 money = msg.value;

        address par = adrToParentRef[msg.sender];

        uint256 mon = (refLevel1Percent * money) / 100;

        _widthdraw(par, mon);
        moneyFromAllRefs[par] += mon;

        bool found;
        uint256 place;
        for (uint256 i; i < adrToRefsInfo[par].length; i++) {
            if (adrToRefsInfo[par][i].ref == msg.sender) {
                found = true;
                place = i;
                break;
            }
        }
        if (found) {
            adrToRefsInfo[par][place].money += mon;
            adrToRefsInfo[par][place].date = block.timestamp;
        } else {
            adrToRefsInfo[par].push(refs(msg.sender, mon, block.timestamp));
        }

        money -= mon;

        _widthdraw(founderAddress, money);
        adrToCycle[par] += quantity;
    }

    function Airdrop(uint256 quantity, address wallet)
        external
        payable
        onlyOwner
    {
        require(totalNFTs + quantity <= maxNFTs, "Exceeded max NFTs amount");

        require(quantity <= 150, "Exceeded max transaction amount");

        _safeMint(wallet, quantity, true, "");

        totalNFTs += quantity;

        NFTtracker[wallet] += quantity;
    }

    function allowUser(
        uint256[] memory tokenIds,
        uint256 floor,
        uint256 time,
        uint256 perc,
        address user1
    ) external {
        require(
            msg.sender == owner() || isAdmin[msg.sender],
            "Not enough rights"
        );
        require(registeredUsers[user1], "Not registered in system");

        for (uint256 i; i < tokenIds.length; i++) {
            require(
                this.ownerOf(tokenIds[i]) == user1,
                "This user is not owner of the nft"
            );
        }

        uint256 divide = 1 days * 100;

        uint256 myReward = (floor * tokenIds.length * perc * time * 60) /
            divide;

        if (adrToClaimAmount[user1] == adrToUsedClaimAmount[user1]) {
            adrToClaimAmount[user1]++;

            claimInfo[user1].push(
                claim(
                    user1,
                    tokenIds.length,
                    tokenIds.length,
                    tokenIds,
                    0,
                    time * 60,
                    perc,
                    floor,
                    myReward,
                    0,
                    block.timestamp
                )
            );
            allMoneyForUsers += myReward;
        } else {
            claimInfo[user1][claimInfo[user1].length - 1] = claim(
                user1,
                tokenIds.length,
                tokenIds.length,
                tokenIds,
                0,
                time * 60,
                perc,
                floor,
                myReward,
                0,
                block.timestamp
            );
        }
    }

    function stake() external {
        require(registeredUsers[msg.sender], "Not registered in system");
        require(isStakeActive, "Stake is paused");

        require(
            adrToUsedClaimAmount[msg.sender] < adrToClaimAmount[msg.sender],
            "Don't have stakes"
        );
        require(
            claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]].nftAmount >
                0,
            "Do not have stakes at all"
        );
        require(
            block.timestamp <=
                claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]]
                    .allowTime +
                    1 hours,
            "Stake deadline is over"
        );

        adrToStakes[msg.sender].push(adrToClaimAmount[msg.sender]);

        for (
            uint256 i;
            i <
            claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]]
                .nftIds
                .length;
            i++
        ) {
            require(
                ownerOf(
                    claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]]
                        .nftIds[i]
                ) == msg.sender,
                "This user is not owner of the nft"
            );

            safeTransferFrom(
                msg.sender,
                address(this),
                claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]].nftIds[
                    i
                ]
            );
            adrToIdsArray[msg.sender].push(
                claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]].nftIds[
                    i
                ]
            );
        }
        claimInfo[msg.sender][adrToUsedClaimAmount[msg.sender]]
            .startTime = block.timestamp;
        adrToUsedClaimAmount[msg.sender]++;
    }

    function checkReferals(address user, uint256 startPoint)
        external
        view
        returns (refs[] memory referalInfo)
    {
        uint256 amount = 8;

        require(startPoint % 8 == 0, "startPoint must be 0, 8, 16 ... etc.");
        require(startPoint < adrToRefsInfo[user].length, "startPoint too big");

        uint256 count;
        bool a;

        if (adrToRefsInfo[user].length < startPoint + amount) {
            uint256 newStartPoint = startPoint - (startPoint % 8);
            refs[] memory adrArray = new refs[](
                adrToRefsInfo[user].length - newStartPoint
            );
            for (
                uint256 i = newStartPoint;
                i < adrToRefsInfo[user].length;
                i++
            ) {
                if (adrToRefsInfo[user][i].ref != address(0)) {
                    adrArray[count] = adrToRefsInfo[user][i];
                    count++;
                }
            }
            return adrArray;
        } else {
            refs[] memory adrArray = new refs[](amount);
            for (uint256 i = startPoint; i < startPoint + amount; i++) {
                if (adrToRefsInfo[user][i].ref != address(0)) {
                    adrArray[count] = adrToRefsInfo[user][i];
                    count++;
                    a = true;
                }
            }

            return adrArray;
        }
    }

    function checkUserStakings(address user)
        external
        view
        returns (
            uint256 totalRewards,
            uint256 _totalNFTs,
            uint256[] memory stakeNumbers,
            uint256[] memory stakeNotZero
        )
    {
        uint256 len = adrToStakes[user].length;
        uint256[] memory array = new uint256[](len);

        for (uint256 i; i < adrToStakes[user].length; i++) {
            if (checkMyRewards(user, adrToStakes[user][i]) != 0) {
                array[i] = adrToStakes[user][i];
            }
        }

        return (
            checkMyAllRewards(user),
            adrToIdsArray[user].length,
            adrToStakes[user],
            array
        );
    }

    function checkGeneralRefInfo(address user)
        external
        view
        returns (uint256 totalMoney, uint256 refAmount)
    {
        return (moneyFromAllRefs[user], adrToRefsInfo[user].length);
    }

    function checkClaimInfo(address user, uint256 claimNumber)
        external
        view
        returns (
            uint256[] memory tokenIds,
            uint256 floor,
            uint256 percent,
            uint256 startTime,
            uint256 timeAvailable
        )
    {
        return (
            claimInfo[user][claimNumber - 1].nftIds,
            claimInfo[user][claimNumber - 1].floor,
            claimInfo[user][claimNumber - 1].percent,
            claimInfo[user][claimNumber - 1].startTime,
            claimInfo[user][claimNumber - 1].startTime +
                claimInfo[user][claimNumber - 1].lockTime
        );
    }

    function batchUnstakeNFTs(uint256[] memory nfts) external {
        for (uint256 i; i < nfts.length; i++) {
            unStakeNFTs(nfts[i]);
            uint256 index = 0;
            for (
                uint256 l;
                l < claimInfo[msg.sender][nfts[i] - 1].nftIds.length;
                l++
            ) {
                for (uint256 j; j < adrToIdsArray[msg.sender].length; j++) {
                    if (
                        adrToIdsArray[msg.sender][j] ==
                        claimInfo[msg.sender][nfts[i] - 1].nftIds[l]
                    ) {
                        index = j;
                    }
                }
                removeNFTs(msg.sender, index);
            }
        }
    }

    function unStakeNFTs(uint256 numberClaim) internal {
        require(numberClaim != 0, "Not correct number");
        numberClaim -= 1;
        require(registeredUsers[msg.sender], "Not registered in system");
        require(
            claimInfo[msg.sender][numberClaim].startTime +
                claimInfo[msg.sender][numberClaim].lockTime <
                block.timestamp,
            "Wait for ending of your deadline"
        );

        for (
            uint256 i;
            i < claimInfo[msg.sender][numberClaim].nftIds.length;
            i++
        ) {
            this.safeTransferFrom(
                address(this),
                msg.sender,
                claimInfo[msg.sender][numberClaim].nftIds[i]
            );
        }

        claimInfo[msg.sender][numberClaim].nftAmount == 0;
        if (claimInfo[msg.sender][numberClaim].rewardAmount == 0) {
            uint256 index = 0;
            for (uint256 j; j < adrToStakes[msg.sender].length; j++) {
                if (adrToStakes[msg.sender][j] == numberClaim) {
                    index = j;
                }
            }
            removeStakes(msg.sender, index);
        }
    }

    function addAdmin(address user) external onlyOwner {
        require(!isAdmin[user], "Already admin");
        isAdmin[user] = true;
        admins.push(user);
    }

    function deleteAdmin(address user) external onlyOwner {
        require(isAdmin[user], "Not admin");
        for (uint256 i; i < admins.length; i++) {
            if (admins[i] == user) {
                removeAdmin(i);
            }
        }
    }

    function removeAdmin(uint256 index) internal returns (address[] memory) {
        for (uint256 i = index; i < admins.length - 1; i++) {
            admins[i] = admins[i + 1];
        }
        delete admins[admins.length - 1];
        admins.pop();
        return admins;
    }

    function removeNFTs(address user, uint256 index)
        internal
        returns (uint256[] memory)
    {
        for (uint256 i = index; i < adrToIdsArray[user].length - 1; i++) {
            adrToIdsArray[user][i] = adrToIdsArray[user][i + 1];
        }
        delete adrToIdsArray[user][adrToIdsArray[user].length - 1];
        adrToIdsArray[user].pop();
        return adrToIdsArray[user];
    }

    function removeStakes(address user, uint256 index)
        internal
        returns (uint256[] memory)
    {
        for (uint256 i = index; i < adrToStakes[user].length - 1; i++) {
            adrToStakes[user][i] = adrToStakes[user][i + 1];
        }
        delete adrToStakes[user][adrToStakes[user].length - 1];
        adrToStakes[user].pop();
        return adrToStakes[user];
    }

    function checkAllAdmins()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return admins;
    }

    function setRewardAmount() external payable onlyOwner {
        rewardAvailable = true;
    }

    function getRewardsAndNFTs(uint256[] memory numberClaim) external {
        for (uint256 i; i < numberClaim.length; i++) {
            getRewards(numberClaim[i]);
            unStakeNFTs(numberClaim[i]);
        }
    }

    function batchRewards(uint256[] memory stakeNumbers) external {
        for (uint256 i; i < stakeNumbers.length; i++) {
            getRewards(stakeNumbers[i]);
        }
    }

    function getRewards(uint256 numberClaim) internal {
        require(numberClaim != 0, "Not correct number");
        numberClaim -= 1;
        require(registeredUsers[msg.sender], "Not registered in system");

        require(rewardAvailable, "Admin didn't set rewardSumm yet");

        require(
            adrToUsedClaimAmount[msg.sender] <= adrToClaimAmount[msg.sender],
            "Don't have stakes"
        );
        require(
            claimInfo[msg.sender][numberClaim].startTime > 0,
            "Stake at first"
        );
        require(
            claimInfo[msg.sender][numberClaim].rewardAmount > 0,
            "Dont have rewards"
        );

        uint256 nows = block.timestamp;
        uint256 myReward;
        bool a;

        if (
            claimInfo[msg.sender][numberClaim].startTime +
                claimInfo[msg.sender][numberClaim].lockTime <
            nows
        ) {
            myReward = claimInfo[msg.sender][numberClaim].rewardAmount;
            claimInfo[msg.sender][numberClaim].rewardAmount -= myReward;
            a = true;
        } else {
            uint256 divide = 1 days * 100;

            myReward =
                (claimInfo[msg.sender][numberClaim].floor *
                    claimInfo[msg.sender][numberClaim].nftStartAmount *
                    claimInfo[msg.sender][numberClaim].percent *
                    (block.timestamp -
                        claimInfo[msg.sender][numberClaim].startTime)) /
                divide -
                claimInfo[msg.sender][numberClaim].alreadyGiven;

            claimInfo[msg.sender][numberClaim].rewardAmount -= myReward;
        }
        claimInfo[msg.sender][numberClaim].alreadyGiven += myReward;

        allMoneyForUsers -= myReward;

        (bool success, ) = payable(msg.sender).call{value: myReward}("");

        require(success, "Transfer failed");
        if (a) {
            claimInfo[msg.sender][numberClaim].rewardAmount = 0;
        }
    }

    function changeStakePauseStatus() external onlyOwner {
        isStakeActive = !isStakeActive;
    }

    function changeMintPauseStatus() external onlyOwner {
        isMintActive = !isMintActive;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function checkMyRewards(address user, uint256 numberClaim)
        public
        view
        returns (uint256)
    {
        require(numberClaim != 0, "Not correct number");
        numberClaim -= 1;
        require(registeredUsers[user], "Not registered in system");
        uint256 nows = block.timestamp;
        uint256 myReward;
        if (numberClaim + 1 <= adrToUsedClaimAmount[user]) {
            if (
                claimInfo[user][numberClaim].startTime +
                    claimInfo[user][numberClaim].lockTime <
                nows
            ) {
                myReward = claimInfo[user][numberClaim].rewardAmount;
            } else {
                uint256 divide = 1 days * 100;

                myReward =
                    (claimInfo[user][numberClaim].floor *
                        claimInfo[user][numberClaim].nftStartAmount *
                        claimInfo[user][numberClaim].percent *
                        (block.timestamp -
                            claimInfo[user][numberClaim].startTime)) /
                    divide -
                    claimInfo[user][numberClaim].alreadyGiven;
            }
            return myReward;
        } else {
            return 0;
        }
    }

    function checkMyAllRewards(address user) public view returns (uint256) {
        uint256 sum;
        for (uint256 i; i < adrToStakes[user].length; i++) {
            sum += checkMyRewards(user, adrToStakes[user][i]);
        }
        return sum;
    }

    function userNFTIds(address _owner) public view returns (uint256[] memory) {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokenIds;
    }

    function checkReferalPercents() external view returns (uint256 level1) {
        return (refLevel1Percent);
    }

    function checkAllMoneyForAllUsers() external view returns (uint256) {
        return allMoneyForUsers;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        string memory _tokenURI = super.tokenURI(tokenId);

        return string(abi.encodePacked(_tokenURI, ".json"));
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;

        emit BaseURIChanged(baseURI);
    }

    function isRegistered(address user) external view returns (bool) {
        return registeredUsers[user];
    }

    function isMinted(address user) external view returns (bool) {
        if (mintedNFTs[user] > 0) {
            return true;
        }
        return false;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;

        require(balance > 0, "Insufficent balance");

        _widthdraw(founderAddress, balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");

        require(success, "Failed to widthdraw Ether");
    }

    function changeFounderAddress(address adr) external onlyOwner {
        founderAddress = adr;
    }

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        _operator;
        _from;
        _tokenId;
        _data;
        emit Received();
        return 0x150b7a02;
    }
}

//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract ERC721A is
    Context,
    ERC165,
    IERC721,
    IERC721Metadata,
    IERC721Enumerable
{
    using Address for address;
    using Strings for uint256;

    struct TokenOwnership {
        address addr;
        uint64 startTimestamp;
    }

    struct AddressData {
        uint128 balance;
        uint128 numberMinted;
    }

    mapping(uint256 => bool) burned;
    uint256 burnedCount;

    uint256 private currentIndex;

    uint256 public immutable collectionSize;
    uint256 public maxBatchSize;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned. See ownershipOf implementation for details.
    mapping(uint256 => TokenOwnership) private _ownerships;

    // Mapping owner address to address data
    mapping(address => AddressData) private _addressData;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev
     * maxBatchSize refers to how much a minter can mint at a time.
     * collectionSize_ refers to how many tokens are in the collection.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 maxBatchSize_,
        uint256 collectionSize_
    ) {
        require(
            collectionSize_ > 0,
            "ERC721A: collection must have a nonzero supply"
        );
        require(maxBatchSize_ > 0, "ERC721A: max batch size must be nonzero");
        _name = name_;
        _symbol = symbol_;
        maxBatchSize = maxBatchSize_;
        collectionSize = collectionSize_;
        currentIndex = _startTokenId();
    }

    /**
     * To change the starting tokenId, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalMinted() - burnedCount;
    }

    function currentTokenId() public view returns (uint256) {
        return _totalMinted();
    }

    function getNextTokenId() public view returns (uint256) {
        return SafeMath.add(_totalMinted(), 1);
    }

    /**
     * Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view returns (uint256) {
        unchecked {
            return currentIndex - _startTokenId();
        }
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index)
        public
        view
        override
        returns (uint256)
    {
        require(index < totalSupply(), "ERC721A: global index out of bounds");
        return index;
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     * This read function is O(collectionSize). If calling from a separate contract, be sure to test gas first.
     * It may also degrade with extremely large collection sizes (e.g >> 10000), test for your use case.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        override
        returns (uint256)
    {
        require(index < balanceOf(owner), "ERC721A: owner index out of bounds");
        uint256 numMintedSoFar = totalSupply();
        uint256 tokenIdsIdx = 0;
        address currOwnershipAddr = address(0);
        for (uint256 i = 0; i < numMintedSoFar; i++) {
            TokenOwnership memory ownership = _ownerships[i];
            if (ownership.addr != address(0)) {
                currOwnershipAddr = ownership.addr;
            }
            if (currOwnershipAddr == owner) {
                if (tokenIdsIdx == index) {
                    return i;
                }
                tokenIdsIdx++;
            }
        }
        revert("ERC721A: unable to get token of owner by index");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(
            owner != address(0),
            "ERC721A: balance query for the zero address"
        );
        return uint256(_addressData[owner].balance);
    }

    function _numberMinted(address owner) internal view returns (uint256) {
        require(
            owner != address(0),
            "ERC721A: number minted query for the zero address"
        );
        return uint256(_addressData[owner].numberMinted);
    }

    function ownershipOf(uint256 tokenId)
        internal
        view
        returns (TokenOwnership memory)
    {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr && curr < currentIndex) {
                TokenOwnership memory ownership = _ownerships[curr];
                if (true) {
                    return ownership;
                }

                // Invariant:
                // There will always be an ownership that has an address and is not burned
                // before an ownership that does not have an address and is not burned.
                // Hence, curr will not underflow.
                while (true) {
                    curr--;
                    ownership = _ownerships[curr];
                    if (ownership.addr != address(0)) {
                        return ownership;
                    }
                }
            }
        }

        revert("ERC721A: unable to determine the owner of token");
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return ownershipOf(tokenId).addr;
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
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, tokenId.toString()))
                : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the baseURI and the tokenId. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public override {
        address owner = ERC721A.ownerOf(tokenId);
        require(to != owner, "ERC721A: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721A: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId, owner);
    }

    function batchApprove(address to, uint256[] memory tokenIds) public {
        for (uint256 i; i < tokenIds.length; i++) {
            address owner = ERC721A.ownerOf(tokenIds[i]);
            require(to != owner, "ERC721A: approval to current owner");

            require(
                _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
                "ERC721A: approve caller is not owner nor approved for all"
            );

            _approve(to, tokenIds[i], owner);
        }
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId)
        public
        view
        override
        returns (address)
    {
        require(
            _exists(tokenId),
            "ERC721A: approved query for nonexistent token"
        );

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        require(operator != _msgSender(), "ERC721A: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function _burn(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId), "it's not owner");
        setApprovalForAll(address(this), true);
        transferFrom(ownerOf(tokenId), address(0), tokenId);
        burnedCount++;
        burned[tokenId] = true;
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //require(_tokenApprovals[tokenId] == _msgSender(), "Not approved for this address");
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
    ) public override {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, _data),
            "ERC721A: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Returns whether tokenId exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (_mint),
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _startTokenId() <= tokenId && tokenId < currentIndex;
    }

    function _safeMint(
        address to,
        uint256 quantity,
        bool isAdminMint
    ) internal {
        _safeMint(to, quantity, isAdminMint, "");
    }

    /**
     * @dev Mints quantity tokens and transfers them to to.
     *
     * Requirements:
     *
     * - there must be quantity tokens remaining unminted in the total collection.
     * - to cannot be the zero address.
     * - quantity cannot be larger than the max batch size.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bool isAdminMint,
        bytes memory _data
    ) internal {
        uint256 startTokenId = currentIndex;
        require(to != address(0), "ERC721A: mint to the zero address");
        // We know if the first token in the batch doesn't exist, the other ones don't as well, because of serial ordering.
        require(!_exists(startTokenId), "ERC721A: token already minted");
        require(quantity <= maxBatchSize, "ERC721A: quantity to mint too high");

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        AddressData memory addressData = _addressData[to];
        _addressData[to] = AddressData(
            addressData.balance + uint128(quantity),
            addressData.numberMinted + (isAdminMint ? 0 : uint128(quantity))
        );

        uint256 updatedIndex = startTokenId;

        for (uint256 i = 0; i < quantity; i++) {
            _ownerships[updatedIndex] = TokenOwnership(
                to,
                uint64(block.timestamp)
            );
            emit Transfer(address(0), to, updatedIndex);
            require(
                _checkOnERC721Received(address(0), to, updatedIndex, _data),
                "ERC721A: transfer to non ERC721Receiver implementer"
            );

            updatedIndex++;
        }

        currentIndex = updatedIndex;
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Transfers tokenId from from to to.
     *
     * Requirements:
     *
     * - to cannot be the zero address.
     * - tokenId token must be owned by from.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) private {
        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            getApproved(tokenId) == _msgSender() ||
            isApprovedForAll(prevOwnership.addr, _msgSender()));

        require(
            isApprovedOrOwner,
            "ERC721A: transfer caller is not owner nor approved"
        );

        require(
            prevOwnership.addr == from,
            "ERC721A: transfer from incorrect owner"
        );
        //require(to != address(0), "ERC721A: transfer to the zero address");

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId, prevOwnership.addr);

        _addressData[from].balance -= 1;
        _addressData[to].balance += 1;
        _ownerships[tokenId] = TokenOwnership(to, uint64(block.timestamp));

        // If the ownership slot of tokenId+1 is not explicitly set, that means the transfer initiator owns it.
        // Set the slot of tokenId+1 explicitly in storage to maintain correctness for ownerOf(tokenId+1) calls.
        uint256 nextTokenId = tokenId + 1;
        if (_ownerships[nextTokenId].addr == address(0)) {
            if (_exists(nextTokenId)) {
                _ownerships[nextTokenId] = TokenOwnership(
                    prevOwnership.addr,
                    prevOwnership.startTimestamp
                );
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Approve to to operate on tokenId
     *
     * Emits a {Approval} event.
     */
    function _approve(
        address to,
        uint256 tokenId,
        address owner
    ) private {
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    uint256 public nextOwnerToExplicitlySet = 0;

    /**
     * @dev Explicitly set owners to eliminate loops in future calls of ownerOf().
     */
    function _setOwnersExplicit(uint256 quantity) internal {
        uint256 oldNextOwnerToSet = nextOwnerToExplicitlySet;
        require(quantity > 0, "quantity must be nonzero");
        if (currentIndex == _startTokenId()) revert("No Tokens Minted Yet");

        uint256 endIndex = oldNextOwnerToSet + quantity - 1;
        if (endIndex > collectionSize - 1) {
            endIndex = collectionSize - 1;
        }
        // We know if the last one in the group exists, all in the group exist, due to serial ordering.
        require(_exists(endIndex), "not enough minted yet for this cleanup");
        for (uint256 i = oldNextOwnerToSet; i <= endIndex; i++) {
            if (_ownerships[i].addr == address(0)) {
                TokenOwnership memory ownership = ownershipOf(i);
                _ownerships[i] = TokenOwnership(
                    ownership.addr,
                    ownership.startTimestamp
                );
            }
        }
        nextOwnerToExplicitlySet = endIndex + 1;
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
            try
                IERC721Receiver(to).onERC721Received(
                    _msgSender(),
                    from,
                    tokenId,
                    _data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721A: transfer to non ERC721Receiver implementer"
                    );
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
     * @dev Hook that is called before a set of serially-ordered token ids are about to be transferred. This includes minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - When from and to are both non-zero, from's tokenId will be
     * transferred to to.
     * - When from is zero, tokenId will be minted for to.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token ids have been transferred. This includes
     * minting.
     *
     * startTokenId - the first token id to be transferred
     * quantity - the amount to be transferred
     *
     * Calling conditions:
     *
     * - when from and to are both non-zero.
     * - from and to are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

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

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
                /// @solidity memory-safe-assembly
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

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
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
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