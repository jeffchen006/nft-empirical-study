/**
 *Submitted for verification at Etherscan.io on 2022-10-21
*/

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

interface IERC20 {
    
    function totalSupply() external view returns (uint256);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function getOwner() external view returns (address);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address _owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom( address sender, address recipient, uint256 amount) external returns (bool);
   
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Context {
    
    constructor()  {}

    function _msgSender() internal view returns (address ) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; 
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor()  {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), 'Ownable: caller is not the owner');
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), 'Ownable: new owner is the zero address');
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ReentrancyGuard {

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Pausable is Context {
    
    event Paused(address account);

    event Unpaused(address account);

    bool private _paused;

    constructor () {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

contract CollarStake is Ownable, ReentrancyGuard, Pausable {

    IERC20 public CollarToken;
    uint256 public stakeDays = 365;
    uint256 public stakeLimit;
    uint256 public coolDownTime = 10 * 86400;
    uint256 public currentPool;

    struct UserInfo {
        address staker;
        uint256 poolID;
        uint256 stakeID;
        uint256 stakeAmount;
        uint256 stakeTime;
        uint256 unstakeTime;
        uint256 withdrawTime;
        uint256 stakingDays;
        uint256 APY_percentage;
        uint256 lastClaim;
        uint256 rewardEndTime;
        uint256 rewardAmount;
        bool claimed;
    }

    struct poolInfo {
        uint256 poolID;
        IERC20 stakeToken;
        uint256 APYpercentage;
        uint256 poolStakeID;
        uint256 totalStakedToken;
        bool UnActive;
    }
    
    struct userID{
        uint256[] stakeIDs;
    }

    mapping(uint256 => mapping(uint256 => UserInfo)) internal userDetails;
    mapping(address => mapping(uint256 => userID)) internal userIDs;
    mapping(uint256 => poolInfo) internal poolDetails;

    event emergencySafe(address indexed receiver, address tokenAddressss, uint256 TokenAmount);
    event CreatePool(address indexed creator,uint256 poolID, address stakeToken,uint256 APYPercentage);
    event stakeing(address indexed staker, uint256 stakeID, uint256 stakeAmount, uint256 stakeTime);
    event unstakeing(address indexed staker, uint256 stakeID, uint256 stakeAmount, uint256 UnstakeTime);
    event setAPYPercentage(address indexed owner,uint256 poolID, uint256 newPercentage);
    event withdrawTokens(address indexed staker, uint256 withdrawToken, uint256 withdrawTime);
    event RewardClaimed(address indexed staker,uint256 stakeID, uint256 rewardAmount, uint256 claimTime);
    event adminDeposits(address indexed owner, uint256 RewardDepositamount);
    event UpdatePoolStatus(address indexed owner,uint256 poolID,bool status);

    constructor ( uint256 _maxTokenStake, address _CollarAddress) {
        stakeLimit = _maxTokenStake;
        CollarToken = IERC20(_CollarAddress);
    }

    function viewUserDetails(uint256 _poolID, uint256 _stakeID) external view returns(UserInfo memory){
        return userDetails[_poolID][_stakeID];
    }

    function veiwPools(uint256 _poolID) external view returns(poolInfo memory){
        return poolDetails[_poolID];
    }

    function userStakeIDs(address _account, uint256 _poolID) external view returns(uint256[] memory stakeIDs){
        return userIDs[_account][_poolID].stakeIDs;
    }

    function updateMaxTokenStake(uint256 _maxTokenStake) external onlyOwner  {
        stakeLimit = _maxTokenStake;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unPause() external onlyOwner {
        _unpause();
    }

    function updatePoolAPYpercentage(uint256 _poolID, uint256 _APYpercentage) external onlyOwner  {
        poolInfo storage pool = poolDetails[_poolID];
        pool.APYpercentage = _APYpercentage;

        emit setAPYPercentage(msg.sender, _poolID, _APYpercentage);
    }

    function updateCoolDownTime(uint256 _coolDownTime ) external onlyOwner  {
        coolDownTime = _coolDownTime;
    }

    function updateCollarToken(address _CollarToken) external onlyOwner  {
        require(_CollarToken != address(0x0),"Collar is not a zero address");
        CollarToken = IERC20(_CollarToken);
    }

    function poolCreation(address _stakeToken, uint256 _APYPercentage) external onlyOwner  {
        currentPool++;
        poolInfo storage pool = poolDetails[currentPool];
        pool.stakeToken = IERC20(_stakeToken);
        pool.APYpercentage = _APYPercentage;
        pool.poolID = currentPool;

        emit CreatePool(msg.sender, currentPool, _stakeToken, _APYPercentage);
    }

    function poolStatus(uint256 poolID, bool status) external onlyOwner  {
        poolInfo storage pool = poolDetails[poolID];
        require(pool.poolID > 0,"Pool Not found");
        pool.UnActive  = status;

        emit UpdatePoolStatus(msg.sender, poolID, status);
    }

    function stake(uint256 _poolID,uint256 _tokenAmount, uint256 _stakeDays) external nonReentrant whenNotPaused {
        require( _tokenAmount > 0 && _tokenAmount < stakeLimit,"incorrect token amount");
        poolInfo storage pool = poolDetails[_poolID];
        require(!pool.UnActive,"pool is not active");
        pool.poolStakeID++;
        UserInfo storage user = userDetails[_poolID][pool.poolStakeID];
        user.staker = msg.sender;
        user.stakeID = pool.poolStakeID;
        user.poolID = _poolID;
        user.stakeAmount = _tokenAmount;
        user.stakeTime = block.timestamp;
        user.lastClaim = block.timestamp;
        user.rewardEndTime = (block.timestamp + (_stakeDays * (86400)));
        user.APY_percentage = pool.APYpercentage;
        user.stakingDays = _stakeDays;
        pool.totalStakedToken = pool.totalStakedToken + (_tokenAmount);
        userIDs[msg.sender][_poolID].stakeIDs.push(pool.poolStakeID);

        (pool.stakeToken).transferFrom(msg.sender, address(this), _tokenAmount);
        emit stakeing(msg.sender, pool.poolStakeID, _tokenAmount, block.timestamp);
    }

    function unstake(uint256 _poolID,uint256 _stakeID) external nonReentrant whenNotPaused {
        UserInfo storage user = userDetails[_poolID][_stakeID];
        require(user.stakeTime > 0 , "Invalid stake ID");
        require(user.rewardEndTime <= block.timestamp,"");
        require(user.unstakeTime == 0, "user already claim this ID");
        require(user.staker == msg.sender," invalid user ID");
        claimReward( _poolID,_stakeID);
        user.unstakeTime = block.timestamp;
       
        
        emit unstakeing(msg.sender, _stakeID, user.stakeAmount, block.timestamp);
    }

    function withdraw(uint256 _poolID,uint256 _stakeID) external whenNotPaused {
        UserInfo storage user = userDetails[_poolID][_stakeID];
        poolInfo storage pool = poolDetails[_poolID];
        require(user.staker == msg.sender," invalid user ID");
        require(user.unstakeTime != 0,"User not unstake the tokens");
        require(user.unstakeTime + (coolDownTime) < block.timestamp, "Withdraw time not reached" );
        require(user.withdrawTime == 0, "This ID already withdrawed");
        user.withdrawTime = block.timestamp;
        user.claimed = true;
         pool.totalStakedToken = pool.totalStakedToken - (user.stakeAmount);
        (pool.stakeToken).transfer(msg.sender, user.stakeAmount);
       
        emit withdrawTokens(msg.sender, user.stakeAmount, user.withdrawTime);
    }

    function claimReward(uint256 _poolID,uint256 _stakeID) public whenNotPaused {
        UserInfo storage user = userDetails[_poolID][_stakeID];
        require(user.staker == msg.sender," invalid user ID");
        uint256 rewardAmount = pendingReward(_poolID,_stakeID);
        if(block.timestamp > user.rewardEndTime){
            user.lastClaim = user.rewardEndTime;
        } else{   user.lastClaim = block.timestamp; }
        user.rewardAmount += rewardAmount;
        CollarToken.transfer(msg.sender, rewardAmount); 

        emit RewardClaimed(msg.sender,_stakeID, rewardAmount, user.lastClaim);
    }

    function pendingReward(uint256 _poolID, uint256 _stakeID) public view returns(uint256 Reward) {
        UserInfo storage user = userDetails[_poolID][_stakeID];
        require(user.unstakeTime == 0, "ID unstaked");
        uint256[3] memory localVar;
        if(user.lastClaim < user.rewardEndTime){
            localVar[2] = block.timestamp;
            if(block.timestamp > user.rewardEndTime){ localVar[2] = user.rewardEndTime; }
            
            localVar[0] = (localVar[2]) - (user.lastClaim);
            localVar[1] = (user.APY_percentage) * (1e16) / (stakeDays);
            Reward = user.stakeAmount * (localVar[0]) * (localVar[1]) / (100) / (1e16) / (86400);
        } else {
            Reward = 0;
        }
    }

    function adminDeposit(uint256 _tokenAmount) external onlyOwner {
        CollarToken.transferFrom(msg.sender, address(this), _tokenAmount);

        emit adminDeposits(msg.sender, _tokenAmount);
    }
}