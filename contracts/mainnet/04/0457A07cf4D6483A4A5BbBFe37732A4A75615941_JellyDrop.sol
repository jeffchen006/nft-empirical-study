pragma solidity 0.8.6;


import "IJellyAccessControls.sol";
import "IERC20.sol";
import "IMerkleList.sol";
import "IJellyContract.sol";
import "SafeERC20.sol";
import "BoringMath.sol";
import "Documents.sol";


/**
* @title Jelly Drop V1.4:
*
*              ,,,,
*            [email protected]@@@@@K
*           [email protected]@@@@@@@P
*            [email protected]@@@@@@"                   [email protected]@@  [email protected]@@
*             "*NNM"                     [email protected]@@  [email protected]@@
*                                        [email protected]@@  [email protected]@@
*             ,[email protected]@@g        ,,[email protected],     [email protected]@@  [email protected]@@ ,ggg          ,ggg
*            @@@@@@@@p    [email protected]@@[email protected]@W   [email protected]@@  [email protected]@@  [email protected]@g        ,@@@Y
*           [email protected]@@@@@@@@   @@@P      ]@@@  [email protected]@@  [email protected]@@   [email protected]@g      ,@@@Y
*           [email protected]@@@@@@@@  [email protected]@D,,,,,,,,]@@@ [email protected]@@  [email protected]@@   '@@@p     @@@Y
*           [email protected]@@@@@@@@  @@@@EEEEEEEEEEEE [email protected]@@  [email protected]@@    "@@@p   @@@Y
*           [email protected]@@@@@@@@  [email protected]@K             [email protected]@@  [email protected]@@     '@@@, @@@Y
*            @@@@@@@@@   %@@@,    ,[email protected]@@  [email protected]@@  [email protected]@@      ^@@@@@@Y
*            "@@@@@@@@    "[email protected]@@@@@@@E'   [email protected]@@  [email protected]@@       "*@@@Y
*             "[email protected]@@@@@        "**""       '''   '''        @@@Y
*    ,[email protected]@g    "[email protected]@@P                                     @@@Y
*   @@@@@@@@p    [email protected]@'                                    @@@Y
*   @@@@@@@@P    [email protected]                                    RNNY
*   '[email protected]@@@@@     $P
*       "[email protected]@@p"'
*
*
*/

/**
* @author ProfWobble 
* @dev
*  - Allows for a group of users to claim tokens from a list.
*  - Supports Merkle proofs using the Jelly List interface.
*  - Token claim paused on deployment (Jelly not set yet!).
*  - SetJelly() function allows tokens to be claimed when ready.
*
*/

contract JellyDrop is IJellyContract, Documents {

    using BoringMath128 for uint128;
    using SafeERC20 for OZIERC20;

    /// @notice Jelly template type and id for the pool factory.
    uint256 public constant override TEMPLATE_TYPE = 2;
    bytes32 public constant override TEMPLATE_ID = keccak256("JELLY_DROP");
    uint256 private constant MULTIPLIER_PRECISION = 1e18;
    uint256 private constant PERCENTAGE_PRECISION = 10000;
    uint256 private constant TIMESTAMP_PRECISION = 10000000000;

    /// @notice Address that manages approvals.
    IJellyAccessControls public accessControls;

    /// @notice Address that manages user list.
    address public list;

    /// @notice Reward token address.
    address public rewardsToken;

    /// @notice Current total rewards paid.
    uint256 public rewardsPaid;

    /// @notice Total tokens to be distributed.
    uint256 public totalTokens;

    struct UserInfo {
        uint128 totalAmount;
        uint128 rewardsReleased;
    }

    /// @notice Mapping from user address => rewards paid.
    mapping (address => UserInfo) public userRewards;

    struct RewardInfo {
        /// @notice Sets the token to be claimable or not (cannot claim if it set to false).
        bool tokensClaimable;
        /// @notice Epoch unix timestamp in seconds when the airdrop starts to decay
        uint48 startTimestamp;
        /// @notice Jelly streaming period
        uint32 streamDuration;
        /// @notice Jelly claim period, 0 for unlimited
        uint48 claimExpiry;
        /// @notice Reward multiplier
        uint128 multiplier;
    }
    RewardInfo public rewardInfo;

    /// @notice Whether staking has been initialised or not.
    bool private initialised;

    /// @notice JellyVault is where fees are sent.
    address private jellyVault;

    /// @notice JellyVault is where fees are sent.
    uint256 private feePercentage;

    /**
     * @notice Event emitted when a user claims rewards.
     * @param user Address of the user.
     * @param reward Reward amount.
     */
    event RewardPaid(address indexed user, uint256 reward);

    /**
     * @notice Event emitted when claimable status is updated.
     * @param status True or False.
     */
    event ClaimableStatusUpdated(bool status);

    /**
     * @notice Event emitted when claimable status is updated.
     * @param expiry Timestamp when tokens are no longer claimable.
     */
    event ClaimExpiryUpdated(uint256 expiry);

    /**
     * @notice Event emitted when rewards contract has been updated.
     * @param oldRewardsToken Address of the old reward token contract.
     * @param newRewardsToken Address of the new reward token contract.
     */
    event RewardsTokenUpdated(address indexed oldRewardsToken, address newRewardsToken);

    /**
     * @notice Event emitted when reward tokens have been added to the pool.
     * @param amount Number of tokens added.
     * @param fees Amount of fees.
     */
    event RewardsAdded(uint256 amount, uint256 fees);

    /**
     * @notice Event emitted when list contract has been updated.
     * @param oldList Address of the old list contract.
     * @param newList Address of the new list contract.
     */
    event ListUpdated(address oldList, address newList);

    /**
     * @notice Event emitted when merkle proof has been updated.
     * @param oldMerkleRoot Old merkle proof hash.
     * @param newMerkleRoot New merkle proof hash
     */
    event ProofUpdated(bytes32 oldMerkleRoot, bytes32 newMerkleRoot);


    /**
     * @notice Event emitted for Jelly admin updates.
     * @param vault Address of the new vault address.
     * @param fee New fee percentage.
     */
    event JellyUpdated(address vault, uint256 fee);

    /**
     * @notice Event emitted for when setJelly is called.
     */
    event JellySet();

    /**
     * @notice Event emitted for when tokens are recovered.
     * @param token ERC20 token address.
     * @param amount Token amount in wei.
     */
    event Recovered(address token, uint256 amount);


    constructor() {
    }
 
    //--------------------------------------------------------
    // Setters
    //--------------------------------------------------------


    /**
     * @notice Admin can set reward tokens claimable through this function.
     * @param _enabled True or False.
     */
    function setTokensClaimable(bool _enabled) external  {
        require(accessControls.hasAdminRole(msg.sender), "setTokensClaimable: Sender must be admin");
        rewardInfo.tokensClaimable = _enabled;
        emit ClaimableStatusUpdated(_enabled);
    }

    /**
     * @notice Admin can set token claim expiry through this function.
     * @param _expiry Timestamp for when tokens are no longer able to be claimed.
     */
    function setClaimExpiry(uint256 _expiry) external  {
        require(accessControls.hasAdminRole(msg.sender), "setClaimExpiry: Sender must be admin");
        require(_expiry < TIMESTAMP_PRECISION, "setClaimExpiry: enter claim expiry unix timestamp in seconds, not miliseconds");
        require((rewardInfo.startTimestamp < _expiry && _expiry > block.timestamp )|| _expiry == 0, "setClaimExpiry: claim expiry incorrect");
        rewardInfo.claimExpiry =  BoringMath.to48(_expiry);
        emit ClaimExpiryUpdated(_expiry);
    }

    /**
     * @notice Add more tokens to the JellyDrop contract.
     * @param _rewardAmount Amount of tokens to add, in wei. (18 decimal place format)
     */
    function addRewards(uint256 _rewardAmount) public {
        require(accessControls.hasAdminRole(msg.sender) || accessControls.hasOperatorRole(msg.sender), "addRewards: Sender must be admin/operator");
        OZIERC20(rewardsToken).safeTransferFrom(msg.sender, address(this), _rewardAmount);
        uint256 tokensAdded = _rewardAmount * PERCENTAGE_PRECISION  / uint256(feePercentage + PERCENTAGE_PRECISION);
        uint256 jellyFee =  _rewardAmount * uint256(feePercentage)  / uint256(feePercentage + PERCENTAGE_PRECISION);
        totalTokens += tokensAdded ;
        OZIERC20(rewardsToken).safeTransfer(jellyVault, jellyFee);
        emit RewardsAdded(_rewardAmount, jellyFee);
    }

    /**
     * @notice Jelly vault can update new vault and fee.
     * @param _vault New vault address.
     * @param _fee Fee percentage of tokens distributed.
     */
    function updateJelly(address _vault, uint256 _fee) external  {
        require(jellyVault == msg.sender); // dev: updateJelly: Sender must be JellyVault
        require(_vault != address(0)); // dev: Address must be non zero
        require(_fee < PERCENTAGE_PRECISION); // dev: feePercentage greater than 10000 (100.00%)

        jellyVault = _vault;
        feePercentage = _fee;
        emit JellyUpdated(_vault, _fee);
    }

    /**
     * @notice To initialise the JellyDrop contracts once everything is ready.
     * @param _startTimestamp Timestamp when the tokens rewards are set to begin.
     * @param _streamDuration How long the tokens will drip, in seconds.
     * @param _tokensClaimable Bool to determine if the airdrop is initially claimable.
     */
    function setJellyCustom(uint256 _startTimestamp, uint256 _streamDuration,  bool _tokensClaimable) public  {
        require(accessControls.hasAdminRole(msg.sender), "setJelly: Sender must be admin");
        require(_startTimestamp < TIMESTAMP_PRECISION, "setJelly: enter start unix timestamp in seconds, not miliseconds");
        // require(_multiplier >= 100000000, "setRewardMultiplier: Multiplier must be greater than 1e8 (10 decimals)");

        rewardInfo.tokensClaimable = _tokensClaimable;
        rewardInfo.startTimestamp = BoringMath.to48(_startTimestamp);
        rewardInfo.streamDuration = BoringMath.to32(_streamDuration);
        rewardInfo.multiplier = BoringMath.to128(MULTIPLIER_PRECISION);
        emit JellySet();
    }

    /**
     * @notice To initialise the JellyDrop contracts with default values once everything is ready.
     */
    function setJellyAirdrop() external  {
        setJellyCustom(block.timestamp, 0, false);
    }

    /**
     * @notice To initialise the JellyDrip contracts with a stream duration.
     */
    function setJellyAirdrip(uint256 _streamDuration) external  {
        setJellyCustom(block.timestamp, _streamDuration, false);
    }


    //--------------------------------------------------------
    // Getters 
    //--------------------------------------------------------

    function tokensClaimable() external view returns (bool)  {
        return rewardInfo.tokensClaimable;
    }

    function startTimestamp() external view returns (uint256)  {
        return uint256(rewardInfo.startTimestamp);
    }

    function streamDuration() external view returns (uint256)  {
        return uint256(rewardInfo.streamDuration);
    }

    function claimExpiry() external view returns (uint256)  {
        return uint256(rewardInfo.claimExpiry);
    }

    function calculateRewards(uint256 _newTotalAmount) external view returns (uint256)  {
        if (_newTotalAmount <= totalTokens) return 0;
        uint256 newTokens = _newTotalAmount - totalTokens;
        uint256 fee = newTokens * uint256(feePercentage) / PERCENTAGE_PRECISION;
        return newTokens + fee;
    }

    //--------------------------------------------------------
    // Claim
    //--------------------------------------------------------

    /**
     * @notice Claiming rewards for user.
     * @param _merkleRoot List identifier.
     * @param _index User index.
     * @param _user User address.
     * @param _amount Total amount of tokens claimable by user.
     * @param _data Bytes array to send to the list contract.
     */
    function claim(bytes32 _merkleRoot, uint256 _index, address _user, uint256 _amount, bytes32[] calldata _data ) public {
        UserInfo storage _userRewards =  userRewards[_user];
        
        require(_amount > 0, "Token amount must be greater than 0");
        require(
            _amount > uint256(_userRewards.rewardsReleased),
            "Amount must exceed tokens already claimed"
        );

        // uint256 rewardAmount = merkleAmount * rewardInfo.multiplier / MULTIPLIER_PRECISION;
        if (_amount > uint256(_userRewards.totalAmount)) {
            uint256 merkleAmount = IMerkleList(list).tokensClaimable(_merkleRoot, _index, _user, _amount, _data );
            require(merkleAmount > 0, "Incorrect merkle proof for amount.");
            _userRewards.totalAmount = BoringMath.to128(_amount);
        }

        _claimTokens(_user);
    }

    /**
     * @notice Claiming rewards for a user who has already verified a merkle proof.
     * @param _user User address.
     */
    function verifiedClaim(address _user) public {
        _claimTokens(_user);
    }

    /**
     * @notice Claiming rewards for user.
     * @param _user User address.
     */
    function _claimTokens(address _user) internal {
        UserInfo storage _userRewards =  userRewards[_user];

        require(
            rewardInfo.tokensClaimable == true,
            "Tokens cannnot be claimed yet"
        );

        uint256 payableAmount = _earnedAmount(
            uint256(_userRewards.totalAmount),
            uint256(_userRewards.rewardsReleased)
        );
        require(payableAmount > 0, "No tokens available to claim");
        /// @dev accounts for dust
        uint256 rewardBal =  IERC20(rewardsToken).balanceOf(address(this));
        require(rewardBal > 0, "Airdrop has no tokens remaining");

        if (payableAmount > rewardBal) {
            payableAmount = rewardBal;
        }

        _userRewards.rewardsReleased +=  BoringMath.to128(payableAmount);
        rewardsPaid +=  payableAmount;
        require(rewardsPaid <= totalTokens, "Amount claimed exceeds total tokens");

        OZIERC20(rewardsToken).safeTransfer(_user, payableAmount);

        emit RewardPaid(_user, payableAmount);
    }

    /**
     * @notice Calculated the amount that has already earned but hasn't been released yet.
     * @param _user Address to calculate the earned amount for
     */
    function earnedAmount(address _user) external view returns (uint256) {
        return
            _earnedAmount(
                userRewards[_user].totalAmount,
                userRewards[_user].rewardsReleased
            );
    }

    /**
     * @notice Calculates the amount that has already earned but hasn't been released yet.
     */
    function _earnedAmount(
        uint256 total,
        uint256 released

    ) internal view returns (uint256) {
        if (total <= released ) {
            return 0;
        }

        RewardInfo memory _rewardInfo = rewardInfo;

        // Rewards havent started yet
        if (
            block.timestamp <= uint256(_rewardInfo.startTimestamp) 
            || _rewardInfo.tokensClaimable == false
        ) {
            return 0;
        }

        uint256 expiry = uint256(_rewardInfo.claimExpiry);
        // Expiry set and reward claim has expired
        if (expiry > 0 && block.timestamp > expiry  ) {
            return 0;
        }

        uint256 elapsedTime = block.timestamp - uint256(_rewardInfo.startTimestamp);
        uint256 earned;
        // Reward calculation if streamDuration set
        if (elapsedTime >= uint256(_rewardInfo.streamDuration)) {
            earned = total;
        } else {
            earned = (total * elapsedTime) / uint256(_rewardInfo.streamDuration);
        }
    
        return earned - released;
    }

    //--------------------------------------------------------
    // Lists
    //--------------------------------------------------------

    /**
     * @notice Admin can change list contract through this function.
     * @param _list Address of the new list contract.
     */
    function setList(address _list) external {
        require(accessControls.hasAdminRole(msg.sender));
        require(_list != address(0)); // dev: Address must be non zero
        emit ListUpdated(list, _list);
        list = _list;
    }

    /**
     * @notice Updates Merkle Root.
     * @param _merkleRoot Merkle Root
     * @param _merkleURI Merkle URI
     */
    function updateProof(bytes32 _merkleRoot, string memory _merkleURI) public {
        require(
            accessControls.hasAdminRole(msg.sender) 
            ||  accessControls.hasOperatorRole(msg.sender),
            "updateProof: Sender must be admin/operator"
        );
        emit ProofUpdated(currentMerkleRoot(), _merkleRoot);

        IMerkleList(list).updateProof( _merkleRoot, _merkleURI);
    }

    /**
     * @notice Current Merkle Root.
     */
    function currentMerkleRoot() public view returns (bytes32) {
        return IMerkleList(list).currentMerkleRoot();
    }

    /**
     * @notice Current Merkle URI.
     */
    function currentMerkleURI() public view returns (string memory) {
        return IMerkleList(list).currentMerkleURI();
    }

    //--------------------------------------------------------
    // Admin Reclaim
    //--------------------------------------------------------

    /**
     * @notice Admin can end token distribution and reclaim tokens.
     * @notice Also allows for the recovery of incorrect ERC20 tokens sent to contract
     * @param _vault Address where the reclaimed tokens will be sent.
     */
    function adminReclaimTokens(
        address _tokenAddress,
        address _vault
    )
        external
    {
        require(
            accessControls.hasAdminRole(msg.sender),
            "recoverERC20: Sender must be admin"
        );
        require(_vault != address(0)); // dev: Address must be non zero

        uint256 tokenAmount =  IERC20(_tokenAddress).balanceOf(address(this));
        if (_tokenAddress == rewardsToken) {
            require(
                rewardInfo.claimExpiry > 0 && block.timestamp > rewardInfo.claimExpiry,
                "recoverERC20: Airdrop not yet expired"
            );
            totalTokens = rewardsPaid;
            rewardInfo.tokensClaimable = false;
        }
        OZIERC20(_tokenAddress).safeTransfer(_vault, tokenAmount);
        emit Recovered(_tokenAddress, tokenAmount);
    }


    //--------------------------------------------------------
    // Documents
    //--------------------------------------------------------

    /**
     * @notice Admin can set key value pairs for UI.
     * @param _name Document key.
     * @param _data Document value.
     */
    function setDocument(string calldata _name, string calldata _data) external {
        require(accessControls.hasAdminRole(msg.sender) );
        _setDocument( _name, _data);
    }

    function setDocuments(string[] calldata _name, string[] calldata _data) external {
        require(accessControls.hasAdminRole(msg.sender) );
        uint256 numDocs = _name.length;
        for (uint256 i = 0; i < numDocs; i++) {
            _setDocument( _name[i], _data[i]);
        }
    }

    function removeDocument(string calldata _name) external {
        require(accessControls.hasAdminRole(msg.sender));
        _removeDocument(_name);
    }


    //--------------------------------------------------------
    // Factory Init
    //--------------------------------------------------------

    /**
     * @notice Initializes main contract variables.
     * @dev Init function.
     * @param _accessControls Access controls interface.
     * @param _rewardsToken Address of the airdrop token.
     * @param _rewardAmount Total amount of tokens to distribute.
     * @param _list Address for the merkle list verifier contract.
     * @param _jellyVault The Jelly vault address.
     * @param _jellyFee Fee percentage for added tokens. To 2dp (10000 = 100.00%)
     */
    function initJellyAirdrop(
        address _accessControls,
        address _rewardsToken,
        uint256 _rewardAmount,
        address _list,
        address _jellyVault,
        uint256 _jellyFee
    ) public 
    {
        require(!initialised, "Already initialised");
        require(_list != address(0), "List address not set");
        require(_jellyVault != address(0), "jellyVault not set");
        require(_jellyFee < PERCENTAGE_PRECISION , "feePercentage greater than 10000 (100.00%)");
        require(_accessControls != address(0), "Access controls not set");

        rewardsToken = _rewardsToken;
        jellyVault = _jellyVault;
        feePercentage = _jellyFee;
        totalTokens = _rewardAmount;
        if (_rewardAmount > 0) {
            uint256 jellyFee = _rewardAmount * uint256(feePercentage) / PERCENTAGE_PRECISION;
            OZIERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), _rewardAmount + jellyFee);
            OZIERC20(_rewardsToken).safeTransfer(_jellyVault, jellyFee);
        }
        accessControls = IJellyAccessControls(_accessControls);
        list = _list;
        initialised = true;
    }

    /** 
     * @dev Used by the Jelly Factory. 
     */
    function init(bytes calldata _data) external override payable {}

    function initContract(
        bytes calldata _data
    ) public override {
        (
        address _accessControls,
        address _rewardsToken,
        uint256 _rewardAmount,
        address _list,
        address _jellyVault,
        uint256 _jellyFee
        ) = abi.decode(_data, (address, address,uint256, address,address,uint256));

        initJellyAirdrop(
                        _accessControls,
                        _rewardsToken,
                        _rewardAmount,
                        _list,
                        _jellyVault,
                        _jellyFee
                    );
    }

    /** 
     * @dev Generates init data for factory.
     * @param _accessControls Access controls interface.
     * @param _rewardsToken Address of the airdrop token.
     * @param _rewardAmount Total amount of tokens to distribute.
     * @param _list Address for the merkle list verifier contract.
     * @param _jellyVault The Jelly vault address.
     * @param _jellyFee Fee percentage for added tokens. To 2dp (10000 = 100.00%)
     */
    function getInitData(
        address _accessControls,
        address _rewardsToken,
        uint256 _rewardAmount,
        address _list,
        address _jellyVault,
        uint256 _jellyFee
    )
        external
        pure
        returns (bytes memory _data)
    {
        return abi.encode(
                        _rewardsToken,
                        _accessControls,
                        _rewardAmount,
                        _list,
                        _jellyVault,
                        _jellyFee
                        );
    }


}

pragma solidity 0.8.6;

interface IJellyAccessControls {
    function hasAdminRole(address _address) external  view returns (bool);
    function addAdminRole(address _address) external;
    function removeAdminRole(address _address) external;
    function hasMinterRole(address _address) external  view returns (bool);
    function addMinterRole(address _address) external;
    function removeMinterRole(address _address) external;
    function hasOperatorRole(address _address) external  view returns (bool);
    function addOperatorRole(address _address) external;
    function removeOperatorRole(address _address) external;
    function initAccessControls(address _admin) external ;

}

pragma solidity 0.8.6;

interface IERC20 {

    /// @notice ERC20 Functions 
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice EIP 2612
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

}

pragma solidity 0.8.6;

interface IMerkleList {
    function tokensClaimable(uint256 _index, address _account, uint256 _amount, bytes32[] calldata _merkleProof ) external view returns (bool);
    function tokensClaimable(bytes32 _merkleRoot, uint256 _index, address _account, uint256 _amount, bytes32[] calldata _merkleProof ) external view returns (uint256);
    function currentMerkleRoot() external view returns (bytes32);
    function currentMerkleURI() external view returns (string memory);
    function initMerkleList(address accessControl) external ;
    function addProof(bytes32 _merkleRoot, string memory _merkleURI) external;
    function updateProof(bytes32 _merkleRoot, string memory _merkleURI) external;
}

pragma solidity 0.8.6;

import "IMasterContract.sol";

interface IJellyContract is IMasterContract {
    /// @notice Init function that gets called from `BoringFactory.deploy`.
    /// Also kown as the constructor for cloned contracts.

    function TEMPLATE_ID() external view returns(bytes32);
    function TEMPLATE_TYPE() external view returns(uint256);
    function initContract( bytes calldata data ) external;

}

pragma solidity 0.8.6;

interface IMasterContract {
    /// @notice Init function that gets called from `BoringFactory.deploy`.
    /// Also kown as the constructor for cloned contracts.
    /// Any ETH send to `BoringFactory.deploy` ends up here.
    /// @param data Can be abi encoded arguments or anything else.
    function init(bytes calldata data) external payable;
}

pragma solidity ^0.8.0;

import "OZIERC20.sol";
import "Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        OZIERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        OZIERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        OZIERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        OZIERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        OZIERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(OZIERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface OZIERC20 {
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
}

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
        require(address(this).balance >= amount, "insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "unable to send value, recipient may have reverted");
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
        return functionCall(target, data, "low-level call failed");
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
        return functionCallWithValue(target, data, value, "low-level call with value failed");
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
        require(address(this).balance >= value, "insufficient balance for call");
        require(isContract(target), "call to non-contract");

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
        return functionStaticCall(target, data, "low-level static call failed");
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
        require(isContract(target), "static call to non-contract");

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
        return functionDelegateCall(target, data, "low-level delegate call failed");
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
        require(isContract(target), "delegate call to non-contract");

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

pragma solidity 0.8.6;

/// @notice A library for performing overflow-/underflow-safe math,
/// updated with awesomeness from of DappHub (https://github.com/dapphub/ds-math).
library BoringMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b == 0 || (c = a * b) / b == a, "BoringMath: Mul Overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b > 0, "BoringMath: Div zero");
        c = a / b;
    }

    function to224(uint256 a) internal pure returns (uint224 c) {
        require(a <= type(uint224).max, "BoringMath: uint224 Overflow");
        c = uint224(a);
    }

    function to208(uint256 a) internal pure returns (uint208 c) {
        require(a <= type(uint208).max, "BoringMath: uint128 Overflow");
        c = uint208(a);
    }

    function to128(uint256 a) internal pure returns (uint128 c) {
        require(a <= type(uint128).max, "BoringMath: uint128 Overflow");
        c = uint128(a);
    }

    function to64(uint256 a) internal pure returns (uint64 c) {
        require(a <= type(uint64).max, "BoringMath: uint64 Overflow");
        c = uint64(a);
    }

    function to48(uint256 a) internal pure returns (uint48 c) {
        require(a <= type(uint48).max);
        c = uint48(a);
    }

    function to32(uint256 a) internal pure returns (uint32 c) {
        require(a <= type(uint32).max);
        c = uint32(a);
    }

    function to16(uint256 a) internal pure returns (uint16 c) {
        require(a <= type(uint16).max);
        c = uint16(a);
    }

    function to8(uint256 a) internal pure returns (uint8 c) {
        require(a <= type(uint8).max);
        c = uint8(a);
    }

}


/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint224.
library BoringMath224 {
    function add(uint224 a, uint224 b) internal pure returns (uint224 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint224 a, uint224 b) internal pure returns (uint224 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint224.
library BoringMath208 {
    function add(uint208 a, uint208 b) internal pure returns (uint224 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint208 a, uint208 b) internal pure returns (uint224 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}


/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint128.
library BoringMath128 {
    function add(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint128 a, uint128 b) internal pure returns (uint128 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint64.
library BoringMath64 {
    function add(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint64 a, uint64 b) internal pure returns (uint64 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint48.
library BoringMath48 {
    function add(uint48 a, uint48 b) internal pure returns (uint48 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint48 a, uint48 b) internal pure returns (uint48 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint32.
library BoringMath32 {
    function add(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint32 a, uint32 b) internal pure returns (uint32 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint32.
library BoringMath16 {
    function add(uint16 a, uint16 b) internal pure returns (uint16 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint16 a, uint16 b) internal pure returns (uint16 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

/// @notice A library for performing overflow-/underflow-safe addition and subtraction on uint8.
library BoringMath8 {
    function add(uint8 a, uint8 b) internal pure returns (uint8 c) {
        require((c = a + b) >= b, "BoringMath: Add Overflow");
    }

    function sub(uint8 a, uint8 b) internal pure returns (uint8 c) {
        require((c = a - b) <= a, "BoringMath: Underflow");
    }
}

pragma solidity 0.8.6;
// pragma experimental ABIEncoderV2;


/**
 * @title Standard implementation of ERC1643 Document management
 */
contract Documents {

    struct Document {
        uint32 docIndex;    // Store the document name indexes
        uint64 lastModified; // Timestamp at which document details was last modified
        string data; // data of the document that exist off-chain
    }

    // mapping to store the documents details in the document
    mapping(string => Document) internal _documents;
    // mapping to store the document name indexes
    mapping(string => uint32) internal _docIndexes;
    // Array use to store all the document name present in the contracts
    string[] _docNames;

    // Document Events
    event DocumentRemoved(string indexed _name, string _data);
    event DocumentUpdated(string indexed _name, string _data);

    /**
     * @notice Used to attach a new document to the contract, or update the data or hash of an existing attached document
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     * @param _data Off-chain data of the document from where it is accessible to investors/advisors to read.
     */
    function _setDocument(string calldata _name, string calldata _data) internal {
        require(bytes(_name).length > 0); // dev: Zero name is not allowed
        require(bytes(_data).length > 0); // dev: Zero data is not allowed
        // Document storage document = _documents[_name];
        if (_documents[_name].lastModified == uint64(0)) {
            _docNames.push(_name);
            _documents[_name].docIndex = uint32(_docNames.length);
        }
        _documents[_name] = Document(_documents[_name].docIndex, uint64(block.timestamp), _data);
        emit DocumentUpdated(_name, _data);
    }

    /**
     * @notice Used to remove an existing document from the contract by giving the name of the document.
     * @dev Can only be executed by the owner of the contract.
     * @param _name Name of the document. It should be unique always
     */

    function _removeDocument(string calldata _name) internal {
        require(_documents[_name].lastModified != uint64(0)); // dev: Document should exist
        uint32 index = _documents[_name].docIndex - 1;
        if (index != _docNames.length - 1) {
            _docNames[index] = _docNames[_docNames.length - 1];
            _documents[_docNames[index]].docIndex = index + 1; 
        }
        _docNames.pop();
        emit DocumentRemoved(_name, _documents[_name].data);
        delete _documents[_name];
    }

    /**
     * @notice Used to return the details of a document with a known name (`string`).
     * @param _name Name of the document
     * @return string The data associated with the document.
     * @return uint256 the timestamp at which the document was last modified.
     */
    function getDocument(string calldata _name) external view returns (string memory, uint256) {
        return (
            _documents[_name].data,
            uint256(_documents[_name].lastModified)
        );
    }

    /**
     * @notice Used to retrieve a full list of documents attached to the smart contract.
     * @return string List of all documents names present in the contract.
     */
    function getAllDocuments() external view returns (string[] memory) {
        return _docNames;
    }

    /**
     * @notice Used to retrieve the total documents in the smart contract.
     * @return uint256 Count of the document names present in the contract.
     */
    function getDocumentCount() external view returns (uint256) {
        return _docNames.length;
    }

    /**
     * @notice Used to retrieve the document name from index in the smart contract.
     * @return string Name of the document name.
     */
    function getDocumentName(uint256 _index) external view returns (string memory) {
        require(_index < _docNames.length); // dev: Index out of bounds
        return _docNames[_index];
    }

}