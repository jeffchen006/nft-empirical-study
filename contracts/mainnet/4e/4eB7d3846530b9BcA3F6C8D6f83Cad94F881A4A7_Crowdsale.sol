// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

import "../library/TransferHelper.sol";
import "../Interface/IERC20.sol";
import "../library/Ownable.sol";
import "../Metadata.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Crowdsale is ReentrancyGuard, Ownable, Metadata {
    using SafeMath for uint256;

    ///@notice TokenAddress available for purchase in this Crowdsale
    IERC20 public token;

    uint256 public tokenRemainingForSale;

    mapping(address => bool) public validInputToken;

    //@notice the amount of token investor will recieve against 1 inputToken
    mapping(address => uint256) public inputTokenRate;

    IERC20[] private inputToken;

    /// @notice start of vesting period as a timestamp
    uint256 public vestingStart;

    /// @notice start of crowdsale as a timestamp
    uint256 public crowdsaleStartTime;

    /// @notice end of crowdsale as a timestamp
    uint256 public crowdsaleEndTime;

    /// @notice end of vesting period as a timestamp
    uint256 public vestingEnd;

    /// @notice Number of Tokens Allocated for crowdsale
    uint256 public crowdsaleTokenAllocated;

    /// @notice cliff duration in seconds
    uint256 public cliffDuration;

    uint256 public maxUserAllocation;

    /// @notice amount vested for a investor.
    mapping(address => uint256) public vestedAmount;

    /// @notice cumulative total of tokens drawn down (and transferred from the deposit account) per investor
    mapping(address => uint256) public totalDrawn;

    /// @notice last drawn down time (seconds) per investor
    mapping(address => uint256) public lastDrawnAt;

    /// @notice whitelisted address those can participate in crowdsale
    mapping(address => bool) public whitelistedAddress;

    bool public whitelistingEnabled;

    bool public initialized;

    /**
     * Event for Tokens purchase logging
     * @param investor who invested & got the tokens
     * @param investedAmount of inputToken paid for purchase
     * @param tokenPurchased amount
     * @param inputToken address used to invest
     * @param tokenRemaining amount of token still remaining for sale in crowdsale
     */
    event TokenPurchase(
        address indexed investor,
        uint256 investedAmount,
        uint256 indexed tokenPurchased,
        IERC20 indexed inputToken,
        uint256 tokenRemaining
    );

    /// @notice event emitted when a successful drawn down of vesting tokens is made
    event DrawDown(
        address indexed _investor,
        uint256 _amount,
        uint256 indexed drawnTime
    );

    /// @notice event emitted when crowdsale is ended manually
    event CrowdsaleEndedManually(uint256 indexed crowdsaleEndedManuallyAt);

    /// @notice event emitted when the crowdsale raised funds are withdrawn by the owner
    event FundsWithdrawn(
        address indexed beneficiary,
        IERC20 indexed _token,
        uint256 amount
    );

    /// @notice event emitted when the owner whitelist a user
    event Whitelisted(address[] user);

    /// @notice event emitted when the owner updates max token allocation per user
    event MaxAllocationUpdated(uint256 indexed newAllocation);

    event URLUpdated(string _tokenUrl);

    event TokenRateUpdated(address inputToken, uint256 rate);

    event WhitelistingEnabled();

    constructor() {
        initialized = true;
    }

    /**
     * @notice Initializes the Crowdsale contract. This is called only once upon Crowdsale creation.
     */
    function init(bytes memory _encodedData) external {
        require(initialized == false, "Contract already initialized");
        IERC20[] memory inputTokens;
        bytes memory _crowdsaleTimings;
        bytes memory _whitelist;
        uint256[] memory _rate;
        string memory tokenURL;
        (
            token,
            crowdsaleTokenAllocated,
            inputTokens,
            _rate,
            _crowdsaleTimings
        ) = abi.decode(
            _encodedData,
            (IERC20, uint256, IERC20[], uint256[], bytes)
        );

        (, , , , , _whitelist, owner, tokenURL) = abi.decode(
            _encodedData,
            (
                IERC20,
                uint256,
                IERC20[],
                uint256[],
                bytes,
                bytes,
                address,
                string
            )
        );

        TransferHelper.safeTransferFrom(
            address(token),
            msg.sender,
            address(this),
            crowdsaleTokenAllocated
        );

        updateMeta(address(token), address(0), tokenURL);
        for (uint256 i = 0; i < inputTokens.length; i++) {
            inputToken.push(inputTokens[i]);
            validInputToken[address(inputTokens[i])] = true;
            inputTokenRate[address(inputTokens[i])] = _rate[i];
            updateMeta(address(inputTokens[i]), address(0), "");
        }
        (
            crowdsaleStartTime,
            crowdsaleEndTime,
            vestingStart,
            vestingEnd,
            cliffDuration
        ) = abi.decode(
            _crowdsaleTimings,
            (uint128, uint128, uint128, uint128, uint128)
        );

        tokenRemainingForSale = crowdsaleTokenAllocated;
        address[] memory _whitelistedAddress;
        (whitelistingEnabled, _whitelistedAddress) = abi.decode(
            _whitelist,
            (bool, address[])
        );
        if (_whitelistedAddress.length > 0 && whitelistingEnabled) {
            whitelistUsers(_whitelistedAddress);
        }

        initialized = true;
    }

    modifier isCrowdsaleOver() {
        require(
            _getNow() >= crowdsaleEndTime && crowdsaleEndTime != 0,
            "Crowdsale Not Ended Yet"
        );
        _;
    }

    function updateTokenURL(address tokenAddress, string memory _url)
        external
        onlyOwner
    {
        updateMetaURL(tokenAddress, _url);
        emit URLUpdated(_url);
    }

    function updateInputTokenRate(address _inputToken, uint256 _rate)
        external
        onlyOwner
    {
        require(
            _getNow() < crowdsaleStartTime,
            "Cannot update token rate after crowdsale is started"
        );

        inputTokenRate[_inputToken] = _rate;

        emit TokenRateUpdated(_inputToken, _rate);
    }

    function purchaseToken(IERC20 _inputToken, uint256 _inputTokenAmount)
        external
    {
        if (whitelistingEnabled) {
            require(whitelistedAddress[msg.sender], "User is not whitelisted");
        }
        require(_getNow() >= crowdsaleStartTime, "Crowdsale isnt started yet");
        require(
            validInputToken[address(_inputToken)],
            "Unsupported Input token"
        );
        if (crowdsaleEndTime != 0) {
            require(_getNow() < crowdsaleEndTime, "Crowdsale Ended");
        }

        uint8 inputTokenDecimals = _inputToken.decimals();
        uint256 tokenPurchased = inputTokenDecimals >= 18
            ? _inputTokenAmount.mul(inputTokenRate[address(_inputToken)]).mul(
                10**(inputTokenDecimals - 18)
            )
            : _inputTokenAmount.mul(inputTokenRate[address(_inputToken)]).mul(
                10**(18 - inputTokenDecimals)
            );

        uint8 tokenDecimal = token.decimals();
        tokenPurchased = tokenDecimal >= 36
            ? tokenPurchased.mul(10**(tokenDecimal - 36))
            : tokenPurchased.div(10**(36 - tokenDecimal));

        if (maxUserAllocation != 0)
            require(
                vestedAmount[msg.sender].add(tokenPurchased) <=
                    maxUserAllocation,
                "User Exceeds personal hardcap"
            );

        require(
            tokenPurchased <= tokenRemainingForSale,
            "Exceeding purchase amount"
        );

        TransferHelper.safeTransferFrom(
            address(_inputToken),
            msg.sender,
            address(this),
            _inputTokenAmount
        );

        tokenRemainingForSale = tokenRemainingForSale.sub(tokenPurchased);
        _updateVestingSchedule(msg.sender, tokenPurchased);

        emit TokenPurchase(
            msg.sender,
            _inputTokenAmount,
            tokenPurchased,
            _inputToken,
            tokenRemainingForSale
        );
    }

    function _updateVestingSchedule(address _investor, uint256 _amount)
        internal
    {
        require(_investor != address(0), "Beneficiary cannot be empty");
        require(_amount > 0, "Amount cannot be empty");

        vestedAmount[_investor] = vestedAmount[_investor].add(_amount);
    }

    /**
     * @notice Vesting schedule and associated data for an investor
     * @return _amount
     * @return _totalDrawn
     * @return _lastDrawnAt
     * @return _remainingBalance
     * @return _availableForDrawDown
     */
    function vestingScheduleForBeneficiary(address _investor)
        external
        view
        returns (
            uint256 _amount,
            uint256 _totalDrawn,
            uint256 _lastDrawnAt,
            uint256 _remainingBalance,
            uint256 _availableForDrawDown
        )
    {
        return (
            vestedAmount[_investor],
            totalDrawn[_investor],
            lastDrawnAt[_investor],
            vestedAmount[_investor].sub(totalDrawn[_investor]),
            _availableDrawDownAmount(_investor)
        );
    }

    /**
     * @notice Draw down amount currently available (based on the block timestamp)
     * @param _investor beneficiary of the vested tokens
     * @return _amount tokens due from vesting schedule
     */
    function availableDrawDownAmount(address _investor)
        external
        view
        returns (uint256 _amount)
    {
        return _availableDrawDownAmount(_investor);
    }

    function _availableDrawDownAmount(address _investor)
        internal
        view
        returns (uint256 _amount)
    {
        // Cliff Period
        if (_getNow() <= vestingStart.add(cliffDuration) || vestingStart == 0) {
            // the cliff period has not ended, no tokens to draw down
            return 0;
        }

        // Schedule complete
        if (_getNow() > vestingEnd) {
            return vestedAmount[_investor].sub(totalDrawn[_investor]);
        }

        // Schedule is active

        // Work out when the last invocation was
        uint256 timeLastDrawnOrStart = lastDrawnAt[_investor] == 0
            ? vestingStart
            : lastDrawnAt[_investor];

        // Find out how much time has past since last invocation
        uint256 timePassedSinceLastInvocation = _getNow().sub(
            timeLastDrawnOrStart
        );

        // Work out how many due tokens - time passed * rate per second
        uint256 drawDownRate = (vestedAmount[_investor].mul(1e18)).div(
            vestingEnd.sub(vestingStart)
        );
        uint256 amount = (timePassedSinceLastInvocation.mul(drawDownRate)).div(
            1e18
        );

        return amount;
    }

    /**
     * @notice Draws down any vested tokens due
     * @dev Must be called directly by the investor assigned the tokens in the schedule
     */
    function drawDown() external isCrowdsaleOver nonReentrant {
        _drawDown(msg.sender);
    }

    function _drawDown(address _investor) internal {
        require(
            vestedAmount[_investor] > 0,
            "There is no schedule currently in flight"
        );

        uint256 amount = _availableDrawDownAmount(_investor);
        require(amount > 0, "No allowance left to withdraw");

        // Update last drawn to now
        lastDrawnAt[_investor] = _getNow();

        // Increase total drawn amount
        totalDrawn[_investor] = totalDrawn[_investor].add(amount);

        // Safety measure - this should never trigger
        require(
            totalDrawn[_investor] <= vestedAmount[_investor],
            "Safety Mechanism - Drawn exceeded Amount Vested"
        );

        // Issue tokens to investor
        TransferHelper.safeTransfer(address(token), _investor, amount);

        emit DrawDown(_investor, amount, _getNow());
    }

    function _getNow() internal view returns (uint256) {
        return block.timestamp;
    }

    function getContractTokenBalance(IERC20 _token)
        public
        view
        returns (uint256)
    {
        return _token.balanceOf(address(this));
    }

    /**
     * @notice Balance remaining in vesting schedule
     * @param _investor beneficiary of the vested tokens
     * @return _remainingBalance tokens still due (and currently locked) from vesting schedule
     */
    function remainingBalance(address _investor)
        external
        view
        returns (uint256)
    {
        return vestedAmount[_investor].sub(totalDrawn[_investor]);
    }

    function endCrowdsale(
        uint256 _vestingStartTime,
        uint256 _vestingEndTime,
        uint256 _cliffDurationInSecs
    ) external onlyOwner {
        require(
            crowdsaleEndTime == 0,
            "Crowdsale would end automatically after endTime"
        );
        crowdsaleEndTime = _getNow();
        require(
            _vestingStartTime >= crowdsaleEndTime,
            "Start time should >= Crowdsale EndTime"
        );
        require(
            _vestingEndTime > _vestingStartTime.add(_cliffDurationInSecs),
            "End Time should after the cliffPeriod"
        );

        vestingStart = _vestingStartTime;
        vestingEnd = _vestingEndTime;
        cliffDuration = _cliffDurationInSecs;
        if (tokenRemainingForSale != 0) {
            withdrawFunds(token, tokenRemainingForSale); //when crowdsaleEnds withdraw unsold tokens to the owner
        }
        emit CrowdsaleEndedManually(crowdsaleEndTime);
    }

    function withdrawFunds(IERC20 _token, uint256 amount)
        public
        isCrowdsaleOver
        onlyOwner
    {
        require(
            getContractTokenBalance(_token) >= amount,
            "the contract doesnt have tokens"
        );

        TransferHelper.safeTransfer(address(_token), msg.sender, amount);

        emit FundsWithdrawn(msg.sender, _token, amount);
    }

    /**
     * @dev Enable Whitelisting such that only particular user can participate in crowdsale
     * Can only be called by the current owner.
     */
    function enableWhitelisting() external onlyOwner {
        whitelistingEnabled = true;
        emit WhitelistingEnabled();
    }

    /**
     * @dev Whitelist user address list, such that user can participate in crowdsale
     * Can only be called by the current owner.
     */
    function whitelistUsers(address[] memory users) public onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            require(whitelistingEnabled, "Whitelisting is not enabled");
            whitelistedAddress[users[i]] = true;
        }
        emit Whitelisted(users);
    }

    /**
     * @dev Update the token allocation a user can purchase
     * Can only be called by the current owner.
     */
    function updateMaxUserAllocation(uint256 _maxUserAllocation)
        external
        onlyOwner
    {
        maxUserAllocation = _maxUserAllocation;
        emit MaxAllocationUpdated(_maxUserAllocation);
    }

    function getValidInputTokens() external view returns (IERC20[] memory) {
        return inputToken;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

// helper methods for interacting with ERC20 tokens that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ETH transfer failed');
    }

}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint8);

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

// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/Context.sol";
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
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor () internal {
        address msgSender = _msgSender();
        owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner == _msgSender(), "Ownable: caller is not the owner");
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
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.7.6;

contract Metadata {
    struct TokenMetadata {
        address routerAddress;
        string imageUrl;
        bool isAdded;
    }

    mapping(address => TokenMetadata) public tokenMeta;

    function updateMeta(
        address _tokenAddress,
        address _routerAddress,
        string memory _imageUrl
    ) internal {
        if (_tokenAddress != address(0)) {
            tokenMeta[_tokenAddress] = TokenMetadata({
                routerAddress: _routerAddress,
                imageUrl: _imageUrl,
                isAdded: true
            });
        }
    }

    function updateMetaURL(address _tokenAddress, string memory _imageUrl)
        internal
    {
        TokenMetadata storage meta = tokenMeta[_tokenAddress];
        require(meta.isAdded, "Invalid token address");

        meta.imageUrl = _imageUrl;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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

    constructor () internal {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
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

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}