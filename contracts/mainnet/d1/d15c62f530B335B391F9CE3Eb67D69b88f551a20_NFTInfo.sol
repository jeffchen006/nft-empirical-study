//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

/****************************************************************************************************************
 *                                     Rug Redemption Wrapper Contract                                           *
 *                                               LordLabz                                                        *
 *   Designed: JoeSoap8308 (Dev of the Wrapped Companions - https://opensea.io/collection/wrappedcompanion-1)    *
 *                                 Modified: Dustin Turska | KronicLabz LLC                                      *
 *                                          https://kroniclabz.com                                               *
 *                                      https://twitter.com/KronicLabz                                           *
 *                               Securtiy contact: [email protected]                                  *
 ****************************************************************************************************************/
/*
-NFT data store to hold the following
- Wrapped Status of Holder
- Blocked NFT's (Ability to block founders/NFT's)
- Stats
*/

//Interface to NFT contract which is the wrapper
interface wrapper {
    function getArtApproval(uint256 _tokennumber, address _wallet)
        external
        view
        returns (bool);

    function ownerOf(uint256 tokenId) external view returns (address);

    function setStringArtPaths(
        uint256 _pathno,
        string memory _path,
        uint256 _tokenid,
        address _holder
    ) external;
}

//Interface to Rugged NFT
interface ruggedNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract NFTInfo {
    //Arrays///
    uint256[] private blockednfts; //Array to handle a blocked nfts
    //Std Variables///
    address public wrapperaddress; //Address of Wrapper Contract
    address public ruggedproject; //Address of the Rugged Project
    address public Owner;
    address public upgradecontract; //Additional contract which will be allowed to manage the TOKEN URI's
    uint256 private numwraps;
    uint256 public numholders;
    uint256 public numblocked;
    ///////Important Mappings///////
    mapping(address => bool) internal wrapped; //Whether a holder has wrapped
    mapping(address => bool) internal holder; //Whether they are a holder
    mapping(uint256 => bool) internal blocked; //blocking due to mapping
    mapping(uint256 => uint256) internal artenabled; //Dynamic mapping of art path selection
    mapping(address => bool) internal blockedaddresses; //Additional addresses to blacklist
    ///////Array for holders////////
    address[] internal holderaddresses; //array to store the holders
    ////////////////////////////////

    modifier onlyOwner() {
        require(msg.sender == Owner);
        _;
    }

    constructor() public {
        Owner = msg.sender; //Owner of Contract
    }

    ///Configure the important addresses for the contract
    function configNBAddresses(uint256 option, address _address)
        external
        onlyOwner
    {
        if (option == 1) {
            wrapperaddress = _address;
        }
        if (option == 2) {
            ruggedproject = _address;
        }
        if (option == 3) {
            upgradecontract = _address;
        }
    }

    //Users to upgrade the TOKEN at a global level i.e Default URI
    //The options are the following for _pathtype:
    // 1) 0 =  Default URI for all tokens
    // 2) 1 = Art Path 1 -> Customizable for all tokens
    // 3) 2 = Art Path 1 -> Customizable for all tokens
    // 4) 3 = Specifies custom art for a single token
    // 5) 4 = Sets token back to default URI (negates option 3)
    function setARTinWrapper(
        uint256 _pathtype,
        string memory _path,
        uint256 _tokenid,
        address _holder
    ) public {
        require(
            msg.sender == Owner || msg.sender == upgradecontract,
            "Not Auth(U)"
        );
        wrapper(wrapperaddress).setStringArtPaths(
            _pathtype,
            _path,
            _tokenid,
            _holder
        );
    }

    //Obtain Art status for Token
    function getArtStatus(uint256 _tokenid) public view returns (uint256) {
        uint256 temp;
        temp = artenabled[_tokenid];
        return temp;
    }

    //This is slightly different from the above as this is used to set the ONLY the PATH for a token and not the Custom one (4)
    //This is used when the token needs to be running a different path or reset back.
    function setArtPath(
        uint256 _tokennumber,
        address _holder,
        uint256 _pathno
    ) external {
        bool temp;
        string memory dummy = ""; //dummy string to pass in
        require(
            msg.sender == Owner || msg.sender == upgradecontract,
            "Not Auth!"
        );
        temp = wrapper(wrapperaddress).getArtApproval(_tokennumber, _holder); //requires the users approval to adjust the path!
        require(temp == true, "Owner not approved!");
        if (_pathno == 0) {
            setARTinWrapper(4, dummy, _tokennumber, _holder); //Resets to default URI
            artenabled[_tokennumber] = 0;
        }
        if (_pathno == 1) {
            setARTinWrapper(4, dummy, _tokennumber, _holder); //Art path 1
            artenabled[_tokennumber] = 1;
        }
        if (_pathno == 2) {
            setARTinWrapper(4, dummy, _tokennumber, _holder); //Art path 2
            artenabled[_tokennumber] = 2;
        }
    }

    //Function to Verify whether an NFT is blocked
    function isBlockedNFT(uint256 _tokenID)
        external
        view
        returns (bool, uint256)
    {
        bool temp;
        address tempaddress;
        temp = blocked[_tokenID]; //Is the block at Token Level?
        if (temp == false) // If not at token level,lets verify at address level
        {
            tempaddress = ownerOfToken(_tokenID);
            temp = blockedaddresses[tempaddress]; // returns Bool dependant on block at address level
        }

        return (temp, 0);
    }

    //Function to return whether they are a holder or not
    function isHolder(address _address) external view returns (bool) {
        bool temp;
        if (holder[_address] == true) {
            temp = true;
        }
        return temp;
    }

    //Manage the user status i.e wrap=holder, unwarp=not a holder
    function manageHolderAddresses(bool status, address _holder) external {
        require(
            msg.sender == wrapperaddress || msg.sender == Owner,
            "Not Oracle/Owner!"
        );
        if (status == true) {
            //Add user to array!
            (bool _isholder, ) = isHolderInArray(_holder);
            if (!_isholder) holderaddresses.push(_holder);
        }
        if (status == false) {
            (bool _isholder, uint256 s) = isHolderInArray(_holder);
            if (_isholder) {
                holderaddresses[s] = holderaddresses[
                    holderaddresses.length - 1
                ];
                holderaddresses.pop();
            }
            holder[_holder] = status;
        }
    }

    /////To keep track of holders for future use
    function manageNumHolders(uint256 _option) external {
        require(
            msg.sender == wrapperaddress || msg.sender == Owner,
            "Not Oracle/Owner!"
        );
        if (_option == 1) //remove holder
        {
            numholders -= numholders - 1;
        }
        if (_option == 2) //add holder
        {
            numholders += 1;
        }
    }

    /////Returns whether the user is stored in the array////////
    function isHolderInArray(address _wallet)
        public
        view
        returns (bool, uint256)
    {
        for (uint256 s = 0; s < holderaddresses.length; s += 1) {
            if (_wallet == holderaddresses[s]) return (true, s);
        }
        return (false, 0);
    }

    /////////////////////////

    ///Function to manage addresses
    function manageBlockedNFT(
        int256 option,
        uint256 _tokenID,
        address _wallet,
        uint256 _numNFT,
        bool _onoroff
    ) external onlyOwner {
        address temp;
        if (option == 1) // Add NFT to block list
        {
            blocked[_tokenID] = true;
            numblocked += 1;
        }
        if (option == 2) //Remove from mapping
        {
            bool _isblocked = blocked[_tokenID];
            if (_isblocked) {
                blocked[_tokenID] = false;
                if (numblocked > 0) {
                    numblocked -= 1;
                }
            }
        }
        if (
            option == 3
        ) //Iterate through entire colletion and add. Added as a nice to have, but an iteration through an enite collection is expensive
        {
            for (uint256 s = 0; s < _numNFT; s += 1) {
                if (s > 0) {
                    temp = ownerOfToken(s);

                    if (temp == _wallet) {
                        blocked[s] = true;
                        numblocked += 1;
                    }
                }
            }
        }
        if (option == 4) {
            //setup blocking of addresses
            blockedaddresses[_wallet] = _onoroff;
        }
    }

    //Set the status of a user if they have wrapped!
    function setUserStatus(address _wrapper, bool _haswrapped) external {
        require(
            msg.sender == Owner || msg.sender == wrapperaddress,
            "Not Auth(WS)"
        );
        wrapped[_wrapper] = _haswrapped;
        numwraps += 1; //track number of wraps
    }

    //Returns whether a user has wrapped before..
    function getWrappedStatus(address _migrator) external view returns (bool) {
        bool temp;
        if (wrapped[_migrator] == true) {
            temp = true;
        }
        return temp;
    }

    //Returns stats based off
    // 1) numholders based off the number of wrappers
    // 2) The length of the array with addresss of wrappers
    // 3) The number of current blockedNFT's
    function getNumHolders(uint256 _feed) external view returns (uint256) {
        uint256 temp;
        if (_feed == 1) {
            temp = numholders;
        }
        if (_feed == 2) {
            temp = holderaddresses.length;
        }
        if (_feed == 3) {
            temp = blockednfts.length;
        }
        return temp;
    }

    ///Returns the holder address given an Index
    function getHolderAddress(uint256 _index)
        external
        view
        returns (address payable)
    {
        address temp;
        address payable temp2;
        temp = holderaddresses[_index];
        temp2 = payable(temp);
        return temp2;
    }

    //Returns OwnerOf the original Rugged NFT itself
    //Saves having to add an additional ABI in a webpage/contract to verify
    function ownerOfToken(uint256 _tid) public view returns (address) {
        address temp;
        temp = ruggedNFT(ruggedproject).ownerOf(_tid);
        return temp;
    }
}