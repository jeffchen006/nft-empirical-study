// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/INFT.sol";
import "../interfaces/ITOPIA.sol";
import "../interfaces/IHUB.sol";
import "../interfaces/IRandomizer.sol";

contract MoonForceHQ is Ownable, ReentrancyGuard {

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
        uint80 stakedAt;
    }

    // struct to store a stake's token, owner, and earning values
    struct StakeAlpha {
        uint16 tokenId;
        uint80 value;
        address owner;
        uint80 stakedAt;
    }

    struct Migration {
        uint16 generalTokenId;
        address generalOwner;
        uint80 value;
        uint80 migrationTime;
    }

    mapping(uint16 => uint8) public weaponType;

    mapping(uint16 => uint8) public genesisType;

    uint256 private numCadetsStaked;
    // number of Alien staked
    uint256 private numAlienStaked;
    // number of General staked
    uint256 private numGeneralStaked;
    // number of Alpha staked
    uint256 private numAlphasStaked;

    uint256 public PERIOD = 1 days;

    event TokenStaked(address indexed owner, uint256 indexed tokenId, uint8 tokenType, uint256 timeStamp);
    event CadetClaimed(uint256 indexed tokenId, bool indexed unstaked, uint256 earned);
    event CadetUnStaked(address indexed owner, uint256 indexed tokenId, uint256 blockNum, uint256 timeStamp);
    event AlienClaimed(uint256 indexed tokenId, bool indexed unstaked, uint256 earned);
    event AlienUnStaked(address indexed owner, uint256 indexed tokenId, uint256 blockNum, uint256 timeStamp);
    event GeneralClaimed(uint256 indexed tokenId, bool indexed unstaked, uint256 earned);
    event GeneralUnStaked(address indexed owner, uint256 indexed tokenId, uint256 blockNum, uint256 timeStamp);
    event WeaponChanged(address indexed owner, uint256 tokenId, uint8 upgrade);
    event AlphaStaked(address indexed owner, uint256 indexed tokenId, uint256 value);
    event AlphaClaimed(uint256 indexed tokenId, bool indexed unstaked, uint256 earned);
    event AlphaUnstaked(address indexed owner, uint256 indexed tokenId, uint256 blockNum, uint256 timeStamp);
    event GeneralMigrated(address indexed owner, uint16 id, bool returning);
    event GenesisStolen (uint16 indexed tokenId, address victim, address thief, uint8 nftType, uint256 timeStamp);

    // reference to the NFT contract
    INFT public lfGenesis;

    INFT public lfAlpha;

    IHUB public HUB;

    // reference to Randomizer
    IRandomizer public randomizer;
    address payable vrf;
    address payable dev;

    mapping(uint16 => Migration) public WastelandGenerals; // for vets sent to wastelands
    mapping(uint16 => bool) public IsInWastelands; // if vet token ID is in the wastelands

    // maps Cadet tokenId to stake
    mapping(uint256 => Stake) private cadet;

    // maps Alpha tokenId to stakeAlpha
    mapping(uint256 => StakeAlpha) private alpha;

    // maps Alien tokenId to stake
    mapping(uint256 => Stake) private alien;
    // maps General tokenId to stake
    mapping(uint256 => Stake) private general;

    mapping(address => uint256) ownerBalanceStaked;

    mapping(uint16 => bool) public IsInPlatoon;

    mapping(address => bool) public HasPlatoon;

    // any rewards distributed when no Aliens are staked
    uint256 private unaccountedAlienRewards;
    // amount of $TOPIA due for each alien staked
    uint256 private TOPIAPerAlien;
    // any rewards distributed when no Generals are staked
    uint256 private unaccountedGeneralRewards;
    // amount of $TOPIA due for each General staked
    uint256 private TOPIAPerGeneral;

    // for staked tier 3 nfts
    uint256 public WASTELAND_BONUS = 100 * 10**18;

    // Cadets earn 20 $TOPIA per day
    uint256 public DAILY_CADET_RATE = 5 * 10**18;

    // Cadets earn 35 $TOPIA per day
    uint256 public DAILY_ALPHA_RATE = 10 * 10**18;

    // rolling price
    uint256 public UPGRADE_COST = 40 * 10**18;

    // Generals take a 3% tax on all $TOPIA claimed
    uint256 public GENERAL_TAX_RATE_1 = 300;

    // Generals take a 10% tax on all $TOPIA from upgrades
    uint256 public GENERAL_TAX_RATE_2 = 1000;

    // tx cost for getting random numbers
    uint256 public SEED_COST = .0005 ether;

    // tx cost
    uint256 public DEV_FEE = .0018 ether;

    // amount of $TOPIA earned so far
    uint256 public totalTOPIAEarned;
    // the last time $TOPIA can be earned
    uint80 public claimEndTime = 1669662000;

    uint8 public minimumForPlatoon;

    mapping(address => uint16) public GroupLength;

    /**
     */
    constructor(uint8 _minimumForPlatoon) {
        dev = payable(msg.sender);
        minimumForPlatoon = _minimumForPlatoon;
    }

    /** CRITICAL TO SETUP */

    modifier requireContractsSet() {
        require(address(lfGenesis) != address(0) && address(randomizer) != address(0) && address(HUB) != address(0), "Contracts not set");
        _;
    }

    function setContracts(address _lfGenesis, address _lfAlpha, address _HUB, address payable _rand) external onlyOwner {
        lfGenesis = INFT(_lfGenesis);
        lfAlpha = INFT(_lfAlpha);
        randomizer = IRandomizer(_rand);
        HUB = IHUB(_HUB);
        vrf = _rand;
    }

    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }

    modifier notContract() {
        require(!_isContract(msg.sender), "no contract");
        require(msg.sender == tx.origin, "no proxy");
        _;
    }

    // mass update the nftType mapping
    function setBatchNFTType(uint16[] calldata tokenIds, uint8[] calldata _types) external onlyOwner {
        require(tokenIds.length == _types.length , "wrong array length");
        for (uint16 i = 0; i < tokenIds.length;) {
            require(_types[i] != 0 , "Invalid nft type");
            genesisType[tokenIds[i]] = _types[i];
            unchecked{ i++; }
        }
    }

    function setMinimumForPlatoon(uint8 _min) external onlyOwner {
        minimumForPlatoon = _min;
    }

    function setWastelandsBonus(uint256 _bonus) external onlyOwner {
        WASTELAND_BONUS = _bonus;
    }


    /** STAKING */

    /**
     * adds Aliens and Cadet
     * @param account the address of the staker
   * @param tokenIds the IDs of the Aliens and Cadet to stake
   */
    function addManyToStakingPool(address account, uint16[] calldata tokenIds) external payable nonReentrant notContract() {
        require(msg.value == DEV_FEE, "need more eth");
        uint8[] memory tokenTypes = new uint8[](tokenIds.length);
        for (uint i = 0; i < tokenIds.length;) {
            require(lfGenesis.ownerOf(tokenIds[i]) == msg.sender, "not owner");

            if (genesisType[tokenIds[i]] == 1) {
                tokenTypes[i] = 4;
                _addCadetToStakingPool(account, tokenIds[i]);
            } else if (genesisType[tokenIds[i]] == 2) {
                tokenTypes[i] = 5;
                _addAlienToStakingPool(account, tokenIds[i]);
            } else if (genesisType[tokenIds[i]] == 3) {
                tokenTypes[i] = 6;
                _addGeneralToStakingPool(account, tokenIds[i]);
            } else if (genesisType[tokenIds[i]] == 0) {
                revert("Invalid Token Id");
            }
            unchecked{ i++; }
        }
        HUB.receieveManyGenesis(msg.sender, tokenIds, tokenTypes, 2);
        dev.transfer(DEV_FEE);
    }

    /**
     * adds a single Alien to the Armory
     * @param account the address of the staker
   * @param tokenId the ID of the Alien/General to add to the Staking Pool
   */
    function _addAlienToStakingPool(address account, uint16 tokenId) internal {
        alien[tokenId] = Stake({
        owner : account,
        tokenId : tokenId,
        value : uint80(TOPIAPerAlien),
        stakedAt : uint80(block.timestamp)
        });
        numAlienStaked += 1;
        emit TokenStaked(account, tokenId, 2, block.timestamp);
    }


    /**
     * adds a single General to the Armory
     * @param account the address of the staker
   * @param tokenId the ID of the Alien/General to add to the Staking Pool
   */
    function _addGeneralToStakingPool(address account, uint16 tokenId) internal {
        general[tokenId] = Stake({
        owner : account,
        tokenId : tokenId,
        value : uint80(TOPIAPerGeneral),
        stakedAt : uint80(block.timestamp)
        });
        numGeneralStaked += 1;
        emit TokenStaked(account, tokenId, 3, block.timestamp);
    }


    /**
     * adds a single Cadet to the armory
     * @param account the address of the staker
   * @param tokenId the ID of the Cadet to add to the Staking Pool
   */
    function _addCadetToStakingPool(address account, uint16 tokenId) internal {
        cadet[tokenId] = Stake({
        owner : account,
        tokenId : tokenId,
        value : uint80(block.timestamp),
        stakedAt : uint80(block.timestamp)
        });
        numCadetsStaked += 1;
        emit TokenStaked(account, tokenId, 1, block.timestamp);
    }

    /** CLAIMING / UNSTAKING */

    /**
     * realize $TOPIA earnings and optionally unstake tokens from the Armory / Yield
     * to unstake a Cadet it will require it has 2 days worth of $TOPIA unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
    function claimManyGenesis(uint16[] calldata tokenIds, uint8 _type, bool unstake) external payable nonReentrant notContract() {
        require(tx.origin == msg.sender, "Only EOA");
        uint256 numWords;
        if(_type == 1) {
            numWords = tokenIds.length;
            require(msg.value == DEV_FEE + (SEED_COST * numWords), "need more eth");
        } else {
            require(msg.value == DEV_FEE, "need more eth");
        }
        
        uint256[] memory seed;
        if(_type == 1) {
            uint256 remainingWords = randomizer.getRemainingWords();
            require(remainingWords >= numWords, "try again soon.");
            seed = randomizer.getRandomWords(numWords);
        }
        uint256 owed = 0;
        for (uint i = 0; i < tokenIds.length;) {
            require(!IsInPlatoon[tokenIds[i]]);
            if (genesisType[tokenIds[i]] == 1) {
                require(_type == 1, 'wrong type for call');
                owed += _claimCadetFromPool(tokenIds[i], unstake, seed[i]);
            } else if (genesisType[tokenIds[i]] == 2) {
                require(_type == 2, 'wrong type for call');
                owed += _claimAlienFromPool(tokenIds[i], unstake);
            } else if (genesisType[tokenIds[i]] == 3) {
                require(_type == 3, 'wrong type for call');
                owed += _claimGeneralFromPool(tokenIds[i], unstake);
            } else if (genesisType[tokenIds[i]] == 0) {
                revert("Invalid Token Id");
            }
            unchecked{ i++; }
        }
        uint256 vrfAmount = msg.value - DEV_FEE;
        if(vrfAmount > 0) { vrf.transfer(vrfAmount); }
        dev.transfer(DEV_FEE);

        if (owed == 0) { return; }

        totalTOPIAEarned += owed;
        HUB.pay(msg.sender, owed);
    }

    function getTXCost(uint16[] calldata tokenIds, uint8 _type) external view returns (uint256 txCost) {
        if(_type == 1) {
            txCost = DEV_FEE + (SEED_COST * tokenIds.length);
        } else {
            txCost = DEV_FEE;
        }
    }


    /**
     * realize $TOPIA earnings for a single Cadet and optionally unstake it
     * if not unstaking, lose x% chance * y% percent of accumulated $TOPIA to the staked Aliens based on it's upgrade
     * if unstaking, there is a % chanc of losing Cadet NFT
     * @param tokenId the ID of the Cadet to claim earnings from
   * @param unstake whether or not to unstake the Cadet
   * @return owed - the amount of $TOPIA earned
   */
    function _claimCadetFromPool(uint16 tokenId, bool unstake, uint256 seed) internal returns (uint256 owed) {       
        require(cadet[tokenId].owner == msg.sender, "not owner");
        if(block.timestamp <= claimEndTime) {
            owed = (block.timestamp - cadet[tokenId].value) * DAILY_CADET_RATE / PERIOD;
        } else if (cadet[tokenId].value < claimEndTime) {
            owed = (claimEndTime - cadet[tokenId].value) * DAILY_CADET_RATE / PERIOD;
        } else {
            owed = 0;
        }
        uint256 generalTax = owed * GENERAL_TAX_RATE_1 / 10000;
        _payGeneralTax(generalTax);
        owed = owed - generalTax;

        uint256 seedChance = seed >> 16;
        uint8 cadetUpgrade = weaponType[tokenId];
        bool stolen = false;
        address thief;
        if (unstake) {
            // Chance to lose cadet:
            // Unarmed: 30%
            // Sword: 20%
            // Pistol: 10%
            // Sniper: 5%
            if (cadetUpgrade == 0) {
                if ((seed & 0xFFFF) % 100 < 50) {
                    thief = HUB.stealGenesis(tokenId, seed, 2, 4, msg.sender);
                    stolen = true;
                } else {
                    // lose accumulated tokens 50% chance and 60 percent of all token
                    if ((seedChance & 0xFFFF) % 100 < 50) {
                        _payAlienTax(owed * 60 / 100);
                        owed = owed * 40 / 100;
                    }
                }
            } else if (cadetUpgrade == 1) {
                if ((seed & 0xFFFF) % 100 < 40) {
                    thief = HUB.stealGenesis(tokenId, seed, 2, 4, msg.sender);
                    stolen = true;
                } else {
                    // lose accumulated tokens 80% chance and 25 percent of all token
                    if ((seedChance & 0xFFFF) % 100 < 80) {
                        _payAlienTax(owed * 25 / 100);
                        owed = owed * 75 / 100;
                    }
                }
            } else if (cadetUpgrade == 2) {
                if ((seed & 0xFFFF) % 100 < 25) {
                    thief = HUB.stealGenesis(tokenId, seed, 2, 4, msg.sender);
                    stolen = true;
                } else {
                    // lose accumulated tokens 25% chance and 40 percent of all token
                    if ((seedChance & 0xFFFF) % 100 < 25) {
                        _payAlienTax(owed * 40 / 100);
                        owed = owed * 60 / 100;
                    }
                }
            } else if (cadetUpgrade == 3) {
                if ((seed & 0xFFFF) % 100 < 15) {
                    thief = HUB.stealGenesis(tokenId, seed, 2, 4, msg.sender);
                    stolen = true;
                } else {
                    // lose accumulated tokens 20% chance and 25 percent of all token
                    if ((seedChance & 0xFFFF) % 100 < 20) {
                        _payAlienTax(owed * 25 / 100);
                        owed = owed * 75 / 100;
                    }
                }
            }

            delete cadet[tokenId];
            numCadetsStaked -= 1;
            if (stolen) {
                weaponType[tokenId] = 0;
                emit GenesisStolen (tokenId, msg.sender, thief, 1, block.timestamp);
            } else {
                // Always transfer last to guard against reentrance
                HUB.returnGenesisToOwner(msg.sender, tokenId, 4, 2);
            }
            emit CadetUnStaked(msg.sender, tokenId, block.number, block.timestamp);
        } else {// Claiming
            if (cadetUpgrade == 0) {
                // lose accumulated tokens 50% chance and 60 percent of all token
                if ((seedChance & 0xFFFF) % 100 < 50) {
                    _payAlienTax(owed * 60 / 100);
                    owed = owed * 40 / 100;
                }
            } else if (cadetUpgrade == 1) {
                // lose accumulated tokens 80% chance and 25 percent of all token
                if ((seedChance & 0xFFFF) % 100 < 80) {
                    _payAlienTax(owed * 25 / 100);
                    owed = owed * 75 / 100;
                }
            } else if (cadetUpgrade == 2) {
                // lose accumulated tokens 25% chance and 40 percent of all token
                if ((seedChance & 0xFFFF) % 100 < 25) {
                    _payAlienTax(owed * 40 / 100);
                    owed = owed * 60 / 100;
                }
            } else if (cadetUpgrade == 3) {
                // lose accumulated tokens 20% chance and 25 percent of all token
                if ((seedChance & 0xFFFF) % 100 < 20) {
                    _payAlienTax(owed * 25 / 100);
                    owed = owed * 75 / 100;
                }
            }
            cadet[tokenId].value = uint80(block.timestamp);
            // reset stake
        }
        emit CadetClaimed(tokenId, unstake, owed);
    }

    /**
     * realize $TOPIA earnings for a single Alien and optionally unstake it
     * Aliens earn $TOPIA
     * @param tokenId the ID of the Alien to claim earnings from
   * @param unstake whether or not to unstake the Alien
   */
    function _claimAlienFromPool(uint16 tokenId, bool unstake) internal returns (uint256 owed) {
        require(alien[tokenId].owner == msg.sender, "not owner");
        owed = TOPIAPerAlien - alien[tokenId].value;
        if (unstake) {
            delete alien[tokenId];
            numAlienStaked -= 1;
            // Always remove last to guard against reentrance
            HUB.returnGenesisToOwner(msg.sender, tokenId, 5, 2);
            emit AlienUnStaked(msg.sender, tokenId, block.number, block.timestamp);
        } else {
            alien[tokenId].value = uint80(TOPIAPerAlien);
            // reset stake

        }
        emit AlienClaimed(tokenId, unstake, owed);
    }

    /**
     * realize $TOPIA earnings for a General Alien and optionally unstake it
     * Aliens earn $TOPIA
     * @param tokenId the ID of the Alien to claim earnings from
   * @param unstake whether or not to unstake the General Alien
   */
    function _claimGeneralFromPool(uint16 tokenId, bool unstake) internal returns (uint256 owed) {
        require(general[tokenId].owner == msg.sender, "not owner");
        owed = TOPIAPerGeneral - general[tokenId].value;
        if (unstake) {
            delete general[tokenId];
            numGeneralStaked -= 1;
            // Always remove last to guard against reentrance
            HUB.returnGenesisToOwner(msg.sender, tokenId, 6, 2);
            // Send back General
            emit GeneralUnStaked(msg.sender, tokenId, block.number, block.timestamp);
        } else {
            general[tokenId].value = uint80(TOPIAPerGeneral);
            // reset stake

        }
        emit GeneralClaimed(tokenId, unstake, owed);
    }

    /*
  * implement cadet upgrade
  */
  function upgradeWeapon(uint16 tokenId) external payable nonReentrant notContract() returns(uint8) {      
    require(genesisType[tokenId] == 1, "not cadet");
    require(msg.value == DEV_FEE + SEED_COST, "need more eth");

    HUB.burnFrom(msg.sender, UPGRADE_COST);
    _payGeneralTax(UPGRADE_COST * GENERAL_TAX_RATE_2 / 10000);
    uint256 remainingWords = randomizer.getRemainingWords();
    require(remainingWords >= 1, "try again soon.");
    uint256[] memory seed = randomizer.getRandomWords(1);
    uint8 upgrade;

    /*
    * Odds to Upgrade:
    * Unarmed: Default
    * Sword: 70%
    * Pistol: 20%
    * Sniper: 10%
    */
    if ((seed[0] & 0xFFFF) % 100 < 10) {
      upgrade = 3;
    } else if((seed[0] & 0xFFFF) % 100 < 30) {
      upgrade = 2;
    } else {
      upgrade = 1;
    }
    weaponType[tokenId] = upgrade;

    uint256 vrfAmount = msg.value - DEV_FEE;
    if(vrfAmount > 0) { vrf.transfer(vrfAmount); }
    dev.transfer(DEV_FEE);

    emit WeaponChanged(msg.sender, tokenId, upgrade);
    return upgrade;
  }

    /** ACCOUNTING */

    /**
     * add $TOPIA to claimable pot for the Yield
     * @param amount $TOPIA to add to the pot
   */
    function _payAlienTax(uint256 amount) internal {
        if (numAlienStaked == 0) {// if there's no staked aliens
            unaccountedAlienRewards += amount;
            // keep track of $TOPIA due to aliens
            return;
        }
        // makes sure to include any unaccounted $GP
        TOPIAPerAlien += (amount + unaccountedAlienRewards) / numAlienStaked;
        unaccountedAlienRewards = 0;
    }

    /**
     * add $TOPIA to claimable pot for the General Yield
     * @param amount $TOPIA to add to the pot
   */
    function _payGeneralTax(uint256 amount) internal {
        if (numGeneralStaked == 0) {// if there's no staked generals
            unaccountedGeneralRewards += amount;
            // keep track of $TOPIA due to generals
            return;
        }
        // makes sure to include any unaccounted $GP
        TOPIAPerGeneral += (amount + unaccountedGeneralRewards) / numGeneralStaked;
        unaccountedGeneralRewards = 0;
    }

    /** ALPHA FUNCTIONS */

    /**
     * adds Aliens and Cadet
     * @param account the address of the staker
   * @param tokenIds the IDs of the Aliens and Cadet to stake
   */
    function addManyAlphaToStakingPool(address account, uint16[] calldata tokenIds) external payable nonReentrant notContract() {
        require(msg.value == DEV_FEE, "need more eth");
        for (uint i = 0; i < tokenIds.length;) {
            require(lfAlpha.ownerOf(tokenIds[i]) == msg.sender, "not owner");
            HUB.receiveAlpha(msg.sender, tokenIds[i], 2);

            alpha[tokenIds[i]] = StakeAlpha({
            owner : account,
            tokenId : uint16(tokenIds[i]),
            value : uint80(block.timestamp),
            stakedAt : uint80(block.timestamp)
            });
            numAlphasStaked += 1;
            emit AlphaStaked(account, tokenIds[i], block.timestamp);
            unchecked{ i++; }
        }
        dev.transfer(DEV_FEE);
    }

    /**
     * realize $TOPIA earnings and optionally unstake Alpha tokens
     * @param tokenIds the IDs of the tokens to claim earnings from
   * @param unstake whether or not to unstake ALL of the tokens listed in tokenIds
   */
    function claimManyAlphas(uint16[] calldata tokenIds, bool unstake) external payable nonReentrant notContract() {
        require(msg.value == DEV_FEE, "need more eth");
        uint256 owed = 0;
        for (uint i = 0; i < tokenIds.length;) { 
            require(alpha[tokenIds[i]].owner == msg.sender, "not owner");

            if(block.timestamp <= claimEndTime) {
                owed += (block.timestamp - alpha[tokenIds[i]].value) * DAILY_ALPHA_RATE / PERIOD;
            } else if (alpha[tokenIds[i]].value < claimEndTime) {
                owed += (claimEndTime - alpha[tokenIds[i]].value) * DAILY_ALPHA_RATE / PERIOD;
            } else {
                owed += 0;
            }

            if (unstake) {
                delete alpha[tokenIds[i]];
                numAlphasStaked -= 1;
                HUB.returnAlphaToOwner(msg.sender, tokenIds[i], 2);
            } else {
                alpha[tokenIds[i]].value = uint80(block.timestamp);
            }
            emit AlphaClaimed(tokenIds[i], unstake, owed);
            unchecked{ i++; }
        }
        if (owed == 0) {
            return;
        }
        HUB.pay(msg.sender, owed);
        totalTOPIAEarned += owed;
        dev.transfer(DEV_FEE);
    }

    function isOwner(uint16 tokenId, address owner) external view returns (bool validOwner) {
        if (genesisType[tokenId] == 1) {
            return cadet[tokenId].owner == owner;
        } else if (genesisType[tokenId] == 2) {
            return alien[tokenId].owner == owner;
        } else if (genesisType[tokenId] == 3) {
            return general[tokenId].owner == owner;
        }
    }

    /** READ ONLY */

    function getUnclaimedAlpha(uint16 tokenId) external view returns (uint256) {
        if(alpha[tokenId].value > 0) {
            if(block.timestamp <= claimEndTime) {
                return (block.timestamp - alpha[tokenId].value) * DAILY_ALPHA_RATE / PERIOD;
            } else if (alpha[tokenId].value < claimEndTime) {
                return (claimEndTime - alpha[tokenId].value) * DAILY_ALPHA_RATE / PERIOD;
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }

    function getUnclaimedGenesis(uint16 tokenId) external view returns (uint256 owed) {
        owed = 0;
        if (genesisType[tokenId] == 1 && cadet[tokenId].value > 0) {
            if(block.timestamp <= claimEndTime) {
                return (block.timestamp - cadet[tokenId].value) * DAILY_CADET_RATE / PERIOD;
            } else if (cadet[tokenId].value < claimEndTime) {
                return (claimEndTime - cadet[tokenId].value) * DAILY_CADET_RATE / PERIOD;
            } else {
                return 0;
            }
        } else if (genesisType[tokenId] == 2 && alien[tokenId].owner != address(0)) {
            return TOPIAPerAlien - alien[tokenId].value;
        } else if (genesisType[tokenId] == 3) {
            if(IsInWastelands[tokenId]) {
                return WastelandGenerals[tokenId].value;
            } else if (general[tokenId].owner != address(0)) {
                return TOPIAPerGeneral - general[tokenId].value;
            }
        }
        return owed;
    }

    function updateDailyCadetRate(uint256 _rate) external onlyOwner {
        DAILY_CADET_RATE = _rate;
    }

    function updateDailyAlphaRate(uint256 _rate) external onlyOwner {
        DAILY_ALPHA_RATE = _rate;
    }
    
    function updateGeneralTaxRate1(uint16 _rate) external onlyOwner {
        GENERAL_TAX_RATE_1 = _rate;
    }

    function updateGeneralTaxRate2(uint16 _rate) external onlyOwner {
        GENERAL_TAX_RATE_2 = _rate;
    }

    function updateCadetUpgradeCost(uint256 _cost) external onlyOwner {
        UPGRADE_COST = _cost;
    }

    function updateSeedCost(uint256 _cost) external onlyOwner {
        SEED_COST = _cost;
    }

    function updateDevCost(uint256 _cost) external onlyOwner {
        DEV_FEE = _cost;
    }
    function updateDev(address payable _dev) external onlyOwner {
        dev = _dev;
    }

    function closeSeasonEearnings(uint80 _timestamp) external onlyOwner {
        claimEndTime = _timestamp;
    }

    function createPlatoon(uint16[] calldata _tokenIds) external payable nonReentrant notContract() {
        require(!HasPlatoon[msg.sender] , "You already have a platoon");
        require(msg.value == DEV_FEE, "need more eth");
        uint16 length = uint16(_tokenIds.length);
        require(length >= minimumForPlatoon , "Not enough cadets");
        for (uint16 i = 0; i < length;) {
            require(lfGenesis.ownerOf(_tokenIds[i]) == msg.sender , "not owner");
            require(genesisType[_tokenIds[i]] == 1 , "only cadets");
            require(!IsInPlatoon[_tokenIds[i]], "NFT can only be in 1 platoon");
            require(weaponType[_tokenIds[i]] == 2 || weaponType[_tokenIds[i]] == 3 , "cadet must have sniper or pistol");
            cadet[_tokenIds[i]] = Stake({
            owner : msg.sender,
            tokenId : _tokenIds[i],
            value : uint80(block.timestamp),
            stakedAt : uint80(block.timestamp)
            });
     
            emit TokenStaked(msg.sender, _tokenIds[i], 1, block.timestamp);
            IsInPlatoon[_tokenIds[i]] = true;
            unchecked{ i++; }
        }
        GroupLength[msg.sender] = length;
        numCadetsStaked += length;
        HUB.createGroup(_tokenIds, msg.sender, 2);
        HasPlatoon[msg.sender] = true;
        dev.transfer(DEV_FEE);
    }

    function addToPlatoon(uint16 _id) external payable nonReentrant notContract() {
        require(HasPlatoon[msg.sender], "Must have Platoon!");
        require(msg.value == DEV_FEE, "need more eth");
        require(lfGenesis.ownerOf(_id) == msg.sender, "not owner");
        require(genesisType[_id] == 1 , "not cadet");
        require(!IsInPlatoon[_id], "NFT can only be in 1 platoon");
        require(weaponType[_id] == 2 || weaponType[_id] == 3 , "cadet must have sniper or pistol");
        cadet[_id] = Stake({
            owner : msg.sender,
            tokenId : _id,
            value : uint80(block.timestamp),
            stakedAt : uint80(block.timestamp)
            });
     
        emit TokenStaked(msg.sender, _id, 1, block.timestamp);
        IsInPlatoon[_id] = true;
        numCadetsStaked++;
        GroupLength[msg.sender]++;
        HUB.addToGroup(_id, msg.sender, 2);
        dev.transfer(DEV_FEE);
    }

    function claimPlatoon(uint16[] calldata tokenIds, bool unstake) external payable notContract() {
        require(HasPlatoon[msg.sender] , "Must own Platoon");
        uint256 numWords = tokenIds.length;
        require(msg.value == DEV_FEE + (SEED_COST * numWords), "need more eth");
        uint256[] memory seed;
        uint8 theftModifier; // for NFT stealing
        uint8 claimModifier; // for TOPIA stealing
        if (numWords <= 10) {
            claimModifier = 5 * uint8(numWords);
        } else {claimModifier = 50;}
        
        if(unstake) { 
            if (numWords <= 10) {
                theftModifier = uint8(numWords);
            } else {theftModifier = 10;}
            require(GroupLength[msg.sender] == numWords);
        }

        uint256 remainingWords = randomizer.getRemainingWords();
        require(remainingWords >= numWords, "try again soon.");
        seed = randomizer.getRandomWords(numWords);
        
        uint256 owed = 0;
        for (uint i = 0; i < tokenIds.length;) {
            require(genesisType[tokenIds[i]] == 1 , "Must be cadets");
            require(IsInPlatoon[tokenIds[i]] , "NFT must be in Platoon");
            require(cadet[tokenIds[i]].owner == msg.sender, "!= owner");
            uint256 thisOwed;
   
            if(block.timestamp <= claimEndTime) {
                thisOwed = (block.timestamp - cadet[tokenIds[i]].value) * DAILY_CADET_RATE / PERIOD;
            } else if (cadet[tokenIds[i]].value < claimEndTime) {
                thisOwed = (claimEndTime - cadet[tokenIds[i]].value) * DAILY_CADET_RATE / PERIOD;
            } else {
                thisOwed = 0;
            }

            uint256 seedChance = seed[i] >> 16;
            if (unstake) {
                if ((seed[i] & 0xFFFF) % 100 < (10 - theftModifier) && HUB.alphaCount(2) > 0) {
                    address thief = HUB.stealGenesis(tokenIds[i], seed[i], 2, 4, msg.sender);
                    emit GenesisStolen(tokenIds[i], msg.sender, thief, 1, block.timestamp);
                } else {
                    // lose accumulated tokens 50% chance and 60 percent of all token
                    if ((seedChance & 0xFFFF) % 100 < (50 - claimModifier)) {
                        _payAlienTax(thisOwed * 25 / 100);
                        thisOwed = thisOwed * 75 / 100;
                    }
                    HUB.returnGenesisToOwner(msg.sender, tokenIds[i], 4, 2);
                }
                delete cadet[tokenIds[i]];
                IsInPlatoon[tokenIds[i]] = false;
                emit CadetUnStaked(msg.sender, tokenIds[i], block.number, block.timestamp);

            } else {// Claiming
                // lose accumulated tokens 50% chance and 25 percent of all token
                if ((seedChance & 0xFFFF) % 100 < (50 - claimModifier)) {
                    _payAlienTax(thisOwed * 25 / 100);
                    thisOwed = thisOwed * 75 / 100;
                }
                cadet[tokenIds[i]].value = uint80(block.timestamp);
                // reset stake
            }
            emit CadetClaimed(tokenIds[i], unstake, owed);
            owed += thisOwed;
            unchecked{ i++; }
        }
        if (unstake) {
            HasPlatoon[msg.sender] = false;
            numCadetsStaked -= numWords;
            HUB.unstakeGroup(msg.sender, 2);
            GroupLength[msg.sender] = 0;
        }
        
        uint256 vrfAmount = msg.value - DEV_FEE;
        if (vrfAmount > 0) { vrf.transfer(vrfAmount); }
        dev.transfer(DEV_FEE);

        if (owed == 0) { return; }
        totalTOPIAEarned += owed;
        HUB.pay(msg.sender, owed);
    }

    function sendGeneralToWastelands(uint16[] calldata _ids) external payable notContract() {
        uint256 numWords = _ids.length;
        require(msg.value == DEV_FEE + (SEED_COST * numWords), "need more eth");
        require(randomizer.getRemainingWords() >= numWords, "try again soon.");
        uint256[] memory seed = randomizer.getRandomWords(numWords);

        for (uint16 i = 0; i < numWords;) {
            require(lfGenesis.ownerOf(_ids[i]) == msg.sender, "not owner");
            require(genesisType[_ids[i]] == 3, "not a General");
            require(!IsInWastelands[_ids[i]] , "already in wastes");

            if (HUB.alienCount() > 0 && (seed[i]) % 100 < 25) { // stolen
                address thief = HUB.stealMigratingGenesis(_ids[i], seed[i], 2, msg.sender, false);
                emit GenesisStolen (_ids[i], msg.sender, thief, 3, block.timestamp);
            } else {
                HUB.migrate(_ids[i], msg.sender, 2, false);
                WastelandGenerals[_ids[i]].generalTokenId = _ids[i];
                WastelandGenerals[_ids[i]].generalOwner = msg.sender;
                WastelandGenerals[_ids[i]].value = uint80(WASTELAND_BONUS);
                WastelandGenerals[_ids[i]].migrationTime = uint80(block.timestamp);
                IsInWastelands[_ids[i]] = true;
                emit GeneralMigrated(msg.sender, _ids[i], false);
            }
            unchecked { i++; }
        }
        uint256 vrfAmount = msg.value - DEV_FEE;
        if (vrfAmount > 0) { vrf.transfer(vrfAmount); }
        dev.transfer(DEV_FEE);
    }

    function claimManyWastelands(uint16[] calldata _ids, bool unstake) external payable notContract() {
        uint256 numWords = _ids.length;
        uint256[] memory seed;

        if(unstake) { 
            require(msg.value == DEV_FEE + (SEED_COST * numWords), "need more eth");
            require(randomizer.getRemainingWords() >= numWords, "try again soon.");
            seed = randomizer.getRandomWords(numWords);
        } else {
            require(msg.value == DEV_FEE, "need more eth");
        }
        
        uint256 owed = 0;

        for (uint16 i = 0; i < numWords;) {
            require(IsInWastelands[_ids[i]] , "not in wastes");
            require(msg.sender == WastelandGenerals[_ids[i]].generalOwner , "not owner");
            
            owed += WastelandGenerals[_ids[i]].value;

            if (unstake) {
                if (HUB.alienCount() > 0 && (seed[i]) % 100 < 25) { // stolen
                    address thief = HUB.stealMigratingGenesis(_ids[i], seed[i], 2, msg.sender, true);
                    emit GenesisStolen(_ids[i], msg.sender, thief, 3, block.timestamp);
                } else {
                    HUB.migrate(_ids[i], msg.sender, 2, true);
                    emit GeneralMigrated(msg.sender, _ids[i], true);
                }
                IsInWastelands[_ids[i]] = false;
                delete WastelandGenerals[_ids[i]];
            } else {
                WastelandGenerals[_ids[i]].value = uint80(0); // reset value
            }
            emit GeneralClaimed(_ids[i], unstake, owed);
            unchecked { i++; }
        }
        uint256 vrfAmount = msg.value - DEV_FEE;
        if (vrfAmount > 0) { vrf.transfer(vrfAmount); }
        dev.transfer(DEV_FEE);
        if (owed == 0) { return; }
        totalTOPIAEarned += owed;
        HUB.pay(msg.sender, owed);
    }
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IRandomizer {
    function requestRandomWords() external returns (uint256);
    function requestManyRandomWords(uint256 numWords) external returns (uint256);
    function getRandomWords(uint256 number) external returns (uint256[] memory);
    function getRemainingWords() external view returns (uint256);
}

// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IHUB {
    function balanceOf(address owner) external view returns (uint256);
    function pay(address _to, uint256 _amount) external;
    function burnFrom(address _to, uint256 _amount) external;
    // *** STEAL
    function stealGenesis(uint16 _id, uint256 seed, uint8 _gameId, uint8 identifier, address _victim) external returns (address thief);
    function stealMigratingGenesis(uint16 _id, uint256 seed, uint8 _gameId, address _victim, bool returningFromWastelands) external returns (address thief);
    function migrate(uint16 _id, address _originalOwner, uint8 _gameId,  bool returningFromWastelands) external;
    // *** RETURN AND RECEIVE
    function returnGenesisToOwner(address _returnee, uint16 _id, uint8 identifier, uint8 _gameIdentifier) external;
    function receieveManyGenesis(address _originalOwner, uint16[] memory _ids, uint8[] memory identifiers, uint8 _gameIdentifier) external;
    function returnAlphaToOwner(address _returnee, uint16 _id, uint8 _gameIdentifier) external;
    function receiveAlpha(address _originalOwner, uint16 _id, uint8 _gameIdentifier) external;
    function returnRatToOwner(address _returnee, uint16 _id) external;
    function receiveRat(address _originalOwner, uint16 _id) external;
    // *** BULLRUN
    function getRunnerOwner(uint16 _id) external view returns (address);
    function getMatadorOwner(uint16 _id) external view returns (address);
    function getBullOwner(uint16 _id) external view returns (address);
    function bullCount() external view returns (uint16);
    function matadorCount() external view returns (uint16);
    function runnerCount() external view returns (uint16);
    // *** MOONFORCE
    function getCadetOwner(uint16 _id) external view returns (address); 
    function getAlienOwner(uint16 _id) external view returns (address);
    function getGeneralOwner(uint16 _id) external view returns (address);
    function cadetCount() external view returns (uint16); 
    function alienCount() external view returns (uint16); 
    function generalCount() external view returns (uint16);
    // *** DOGE WORLD
    function getCatOwner(uint16 _id) external view returns (address);
    function getDogOwner(uint16 _id) external view returns (address);
    function getVetOwner(uint16 _id) external view returns (address);
    function catCount() external view returns (uint16);
    function dogCount() external view returns (uint16);
    function vetCount() external view returns (uint16);
    // *** PYE MARKET
    function getBakerOwner(uint16 _id) external view returns (address);
    function getFoodieOwner(uint16 _id) external view returns (address);
    function getShopOwnerOwner(uint16 _id) external view returns (address);
    function bakerCount() external view returns (uint16);
    function foodieCount() external view returns (uint16);
    function shopOwnerCount() external view returns (uint16);
    // *** ALPHAS AND RATS
    function alphaCount(uint8 _gameIdentifier) external view returns (uint16);
    function ratCount() external view returns (uint16);
    // *** NFT GROUP FUNCTION
    function createGroup(uint16[] calldata _ids, address _creator, uint8 _gameIdentifier) external;
    function addToGroup(uint16 _id, address _creator, uint8 _gameIdentifier) external;
    function unstakeGroup(address _creator, uint8 _gameIdentifier) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface ITopia {

    function burn(uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;  
    function burnFrom(address _from, uint256 _amount) external;
    function decimals() external pure returns (uint8);
    function balanceOf(address owner) external view returns (uint);
    function updateOriginAccess() external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);
}

// SPDX-License-Identifier: MIT LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface INFT is IERC721Enumerable {
    
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