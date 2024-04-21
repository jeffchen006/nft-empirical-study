// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import {Errors} from "../libraries/helpers/Errors.sol";
import {TransferHelper} from "../libraries/helpers/TransferHelper.sol";
import {SettingStorage} from "../libraries/proxy/SettingStorage.sol";
import {OwnableUpgradeable} from "../libraries/openzeppelin/upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "../libraries/openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Burnable} from "../libraries/openzeppelin/token/ERC20/IERC20Burnable.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {ISettings} from "../interfaces/ISettings.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IStaking} from "../interfaces/IStaking.sol";
import {IExchange} from "../interfaces/IExchange.sol";
import {IGovernor} from "../interfaces/IGovernor.sol";
import {Strings} from "../libraries/openzeppelin/utils/Strings.sol";
import {DataTypes} from "../libraries/types/DataTypes.sol";

contract TokenVaultTreasury is SettingStorage, OwnableUpgradeable {
    //
    IERC20[] public rewardTokens;
    mapping(IERC20 => bool) public isRewardToken;
    mapping(IERC20 => uint256) public poolBalances;

    address public vaultToken;

    uint256 public createdAt;
    uint256 public epochTotal;
    uint256 public epochNum;
    uint256 public epochDuration;

    bool public isEnded;

    bool public stakingPoolEnabled;
    /// @notice  gap for reserve, minus 1 if use
    uint256[10] public __gapUint256;
    /// @notice  gap for reserve, minus 1 if use
    uint256[5] public __gapAddress;

    event Shared(
        IERC20 _token,
        uint256 poolSharedAmt,
        uint256 incomeSharedAmt,
        uint256 incomePoolAmt
    );
    event End(uint256 epochNumber);

    constructor(address _settings) SettingStorage(_settings) {}

    function initialize(
        address _vaultToken,
        uint256 _epochDuration,
        uint256 _epochTotal
    ) public initializer {
        __Ownable_init();
        // init data
        require(_vaultToken != address(0), "no zero address");
        vaultToken = _vaultToken;
        createdAt = block.timestamp;
        epochDuration = _epochDuration;
        epochNum = 0;
        epochTotal = epochNum + _epochTotal;
    }

    modifier onlyGovernor() {
        require(
            address(_getGovernor()) == _msgSender(),
            Errors.VAULT_NOT_GOVERNOR
        );
        _;
    }

    function stakingInitialize(uint256 _epochTotal) external onlyOwner {
        require(!stakingPoolEnabled, Errors.VAULT_TREASURY_STAKING_ENABLED);
        require(
            epochNum < epochTotal || _epochTotal > 0,
            Errors.VAULT_TREASURY_EPOCH_INVALID
        );
        epochNum = _getEpochNumer();
        if (epochTotal == 0 || epochNum >= epochTotal) {
            epochTotal = epochNum + _epochTotal;
        }
        // flag enble staking
        stakingPoolEnabled = true;
    }

    function rewardTokensLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function addRewardToken(address _addr) external onlyOwner {
        IERC20 _rewardToken = IERC20(_addr);
        require(
            !isRewardToken[_rewardToken] && address(_rewardToken) != address(0),
            Errors.VAULT_REWARD_TOKEN_INVALID
        );
        require(rewardTokens.length < 25, Errors.VAULT_REWARD_TOKEN_INVALID);
        rewardTokens.push(_rewardToken);
        isRewardToken[_rewardToken] = true;
        poolBalances[_rewardToken] = 0;
    }

    modifier validRewardToken(IERC20 _rewardToken) {
        require(isRewardToken[_rewardToken], Errors.VAULT_REWARD_TOKEN_INVALID);
        _;
    }

    function _getEpochNumer() private view returns (uint256) {
        return (block.timestamp - createdAt) / epochDuration;
    }

    function _isStaking() private view returns (bool) {
        return stakingPoolEnabled;
    }

    /**
     * get realtime treasury balance base on current epoch
     */
    function getPoolBalanceToken(IERC20 _token)
        public
        view
        validRewardToken(_token)
        returns (uint256)
    {
        uint256 poolBalance;
        uint256 _epochNum = _getEpochNumer();
        (poolBalance, ) = getPoolSharedToken(_token, _epochNum);
        return poolBalance;
    }

    function getBalanceVeToken() public view returns (uint256) {
        return _getStaking().balanceOf(address(this));
    }

    /**
     * get realtime treasury balance and share balance (balane will be share to staking contract) base on current epoch
     */
    function getPoolSharedToken(IERC20 _token, uint256 _epochNow)
        internal
        view
        returns (uint256 poolBalance, uint256 poolSharedAmt)
    {
        poolBalance = poolBalances[_token];
        if (_isStaking()) {
            if (poolBalance > 0) {
                if (_epochNow > epochTotal) {
                    poolSharedAmt = poolBalance;
                } else {
                    if (_epochNow > epochNum) {
                        poolSharedAmt =
                            (poolBalance * (_epochNow - epochNum)) /
                            (epochTotal - epochNum);
                    }
                }
                poolBalance -= poolSharedAmt;
            }
        } else {
            poolBalance = (_token.balanceOf(address(this)) +
                IExchange(IVault(vaultToken).exchange())
                    .getNewShareExchangeFeeRewardToken(address(_token)));
        }
        return (poolBalance, poolSharedAmt);
    }

    /**
     * get realtime income balance, this balance is income for trading fee, 70% will be shrare to admin, 30% will be share staking, if not staking will store treasury balance
     */
    function getIncomeSharedToken(IERC20 _token, bool _exchange)
        internal
        view
        returns (uint256 incomeSharedAmt, uint256 incomePoolAmt)
    {
        uint256 _tokenBalance = _token.balanceOf(address(this));
        if (_exchange) {
            _tokenBalance += IExchange(IVault(vaultToken).exchange())
                .getNewShareExchangeFeeRewardToken(address(_token));
        }
        if (_tokenBalance > 0) {
            uint256 poolBalance = poolBalances[_token];
            if (_tokenBalance > poolBalance) {
                uint256 incomeBalance = (_tokenBalance - poolBalance);
                if (_isStaking()) {
                    incomeSharedAmt = incomeBalance;
                } else {
                    incomePoolAmt = incomeBalance;
                }
            }
        }
        return (incomeSharedAmt, incomePoolAmt);
    }

    /**
     * get realtime for pool balance and imcome balance
     */
    function getNewSharedToken(IERC20 _token)
        external
        view
        returns (
            uint256 poolSharedAmt,
            uint256 incomeSharedAmt,
            uint256 incomePoolAmt
        )
    {
        uint256 _epochNum = _getEpochNumer();
        return _getNewSharedToken(_token, _epochNum, true);
    }

    /**
     * get realtime for pool balance and imcome balance
     */
    function _getNewSharedToken(
        IERC20 _token,
        uint256 _epochNum,
        bool _exchange
    )
        internal
        view
        returns (
            uint256 poolSharedAmt,
            uint256 incomeSharedAmt,
            uint256 incomePoolAmt
        )
    {
        {
            uint256 _poolSharedAmt;
            (, _poolSharedAmt) = getPoolSharedToken(_token, _epochNum);
            poolSharedAmt = _poolSharedAmt;
        }
        {
            uint256 _incomeSharedAmt;
            uint256 _incomePoolAmt;
            (_incomeSharedAmt, _incomePoolAmt) = getIncomeSharedToken(
                _token,
                _exchange
            );
            incomeSharedAmt = _incomeSharedAmt;
            incomePoolAmt = _incomePoolAmt;
        }
        return (poolSharedAmt, incomeSharedAmt, incomePoolAmt);
    }

    /**
     * for staking contract call for get reward
     */
    function shareTreasuryRewardToken() external {
        _shareTreasuryRewardToken();
    }

    function _shareTreasuryRewardToken() internal {
        // exchange share
        IExchange(IVault(vaultToken).exchange()).shareExchangeFeeRewardToken();
        //
        uint256 _epochNum = _getEpochNumer();
        uint256 _len = rewardTokens.length;
        for (uint256 i; i < _len; i++) {
            IERC20 _token = rewardTokens[i];
            uint256 poolSharedAmt;
            uint256 incomeSharedAmt;
            uint256 incomePoolAmt;
            (
                poolSharedAmt,
                incomeSharedAmt,
                incomePoolAmt
            ) = _getNewSharedToken(_token, _epochNum, false);
            if (poolSharedAmt > 0) {
                TransferHelper.safeTransfer(
                    _token,
                    IVault(vaultToken).staking(),
                    poolSharedAmt
                );
                poolBalances[_token] -= poolSharedAmt;
            }
            if (incomeSharedAmt > 0) {
                TransferHelper.safeTransfer(
                    _token,
                    IVault(vaultToken).staking(),
                    incomeSharedAmt
                );
            }
            if (incomePoolAmt > 0) {
                poolBalances[_token] += incomePoolAmt;
            }
            emit Shared(_token, poolSharedAmt, incomeSharedAmt, incomePoolAmt);
        }
        epochNum = _epochNum;
    }

    /**
     * for vault contract call start aution or redeem, share lastest reward, and burn treasury balance, transfer weth to vault address
     */
    function end() external onlyOwner {
        require(!isEnded, "no end");
        // share reward
        _shareTreasuryRewardToken();
        // withdraw and burn token
        IStaking _staking = _getStaking();
        IVault _vault = _getVault();
        uint256 stkBalance = _staking.balanceOf(address(this));
        if (stkBalance > 0) {
            _staking.redeemFToken(stkBalance);
        }
        _vault.burn(_vault.balanceOf(address(this)));
        // transfer reward to vault
        uint256 _len = rewardTokens.length;
        for (uint256 i; i < _len; i++) {
            IERC20 _token = rewardTokens[i];
            uint256 _balane = _token.balanceOf(address(this));
            if (_balane > 0) {
                TransferHelper.safeTransfer(
                    _token,
                    address(vaultToken),
                    _balane
                );
            }
            poolBalances[_token] = 0;
        }
        // update end
        isEnded = true;
        emit End(epochNum);
    }

    function _getVault() internal view returns (IVault) {
        return IVault(vaultToken);
    }

    function _getStaking() internal view returns (IStaking) {
        return IStaking(_getVault().staking());
    }

    function _getGovernor() internal view returns (IGovernor) {
        return IGovernor(_getVault().government());
    }

    function initializeGovernorToken() external onlyOwner {
        IStaking _staking = _getStaking();
        IVault _vault = _getVault();
        if (_vault.nftGovernor() != address(0)) {
            require(_staking.balanceOf(address(this)) == 0, "bad balance");
            uint256 veBalance = ((_vault.totalSupply() *
                ISettings(settings).votingMinTokenPercent()) / 10000);
            _vault.approve(address(_staking), veBalance);
            _staking.convertFTokenToVeToken(veBalance);
            // delegate for goverment
            _getStaking().delegate(address(this));
        }
    }

    function createNftGovernorVoteFor(uint256 proposalId) external {
        require(_getVault().nftGovernor() != address(0), "bad nft governor");
        require(_getStaking().balanceOf(address(this)) > 0, "bad balance");
        // calldata for castVote
        bytes memory _castVotedata = abi.encodeWithSignature(
            "castVote(uint256,uint8)",
            proposalId,
            1
        );
        // calldata for proposalTargetCall
        bytes memory _targetCalldata = abi.encodeWithSignature(
            "proposalTargetCall(address,uint256,bytes)",
            _getVault().nftGovernor(),
            0,
            _castVotedata
        );
        // params for propose
        address[] memory targets = new address[](1);
        targets[0] = address(_getVault());
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = _targetCalldata;
        // governor propose
        _getGovernor().propose(
            targets,
            values,
            calldatas,
            string(
                abi.encodePacked(
                    "This Sub-DAO proposal was created to allow participants to vote For (Yes) on the original proposal #",
                    Strings.toString(proposalId)
                )
            )
        );
    }

    event ProposalERC20Spend(IERC20 token, address recipient, uint256 amount);

    function proposalERC20Spend(
        IERC20 _token,
        address _recipient,
        uint256 _amount
    ) external onlyGovernor {
        // share reward before spend
        _shareTreasuryRewardToken();
        // transfer
        TransferHelper.safeTransfer(_token, _recipient, _amount);
        // update pool balance after spend
        poolBalances[_token] = _token.balanceOf(address(this));
        // emit event
        emit ProposalERC20Spend(_token, _recipient, _amount);
    }
}

// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.0;

import {IERC20} from "../openzeppelin/token/ERC20/IERC20.sol";

library DataTypes {
    struct TokenVaultInitializeParams {
        address curator;
        address[] listTokens;
        uint256[] ids;
        uint256 listPrice;
        uint256 exitLength;
        string name;
        string symbol;
        uint256 supply;
        uint256 treasuryBalance;
    }

    struct StakingInfo {
        address staker;
        uint256 poolId;
        uint256 amount;
        uint256 createdTime;
        //sharedPerTokens by rewardToken
        mapping(IERC20 => uint256) sharedPerTokens;
    }

    struct PoolInfo {
        uint256 ratio;
        uint256 duration;
    }

    struct RewardInfo {
        uint256 currentBalance;
        //sharedPerTokens by pool
        mapping(uint256 => uint256) sharedPerTokensByPool;
    }

    struct EstimateWithdrawAmountParams {
        uint256 withdrawAmount;
        address withdrawToken;
        uint256 stakingAmount;
        address stakingToken;
        uint256 poolId;
        uint256 infoSharedPerToken;
        uint256 sharedPerToken1;
        uint256 sharedPerToken2;
    }

    struct EstimateNewSharedRewardAmount {
        uint256 newRewardAmt;
        uint256 poolBalance1;
        uint256 ratio1;
        uint256 poolBalance2;
        uint256 ratio2;
    }

    struct GetSharedPerTokenParams {
        IERC20 token;
        uint256 currentRewardBalance;
        address stakingToken;
        uint256 sharedPerToken1;
        uint256 sharedPerToken2;
        uint256 poolBalance1;
        uint256 ratio1;
        uint256 poolBalance2;
        uint256 ratio2;
        uint256 totalUserFToken;
    }

    // vault param

    struct VaultGetBeforeTokenTransferUserPriceParams {
        uint256 votingTokens;
        uint256 exitTotal;
        uint256 fromPrice;
        uint256 toPrice;
        uint256 amount;
    }

    struct VaultGetUpdateUserPrice {
        address settings;
        uint256 votingTokens;
        uint256 exitTotal;
        uint256 exitPrice;
        uint256 newPrice;
        uint256 oldPrice;
        uint256 weight;
    }

    struct VaultProposalETHTransferParams {
        address msgSender;
        address government;
        address recipient;
        uint256 amount;
    }

    struct VaultProposalTargetCallParams {
        bool isAdmin;
        address msgSender;
        address vaultToken;
        address government;
        address treasury;
        address staking;
        address exchange;
        address target;
        uint256 value;
        bytes data;
        uint256 nonce;
    }

    struct VaultProposalTargetCallValidParams {
        address msgSender;
        address vaultToken;
        address government;
        address treasury;
        address staking;
        address exchange;
        address target;
        bytes data;
    }
}

pragma solidity ^0.8.0;

/**
 * @title SettingStorage
 * @author 0xkongamoto
 */
contract SettingStorage {
    // address of logic contract
    address public immutable settings;

    // ======== Constructor =========

    constructor(address _settings) {
        require(_settings != address(0), "no zero address");
        settings = _settings;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant alphabet = "0123456789abcdef";

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
            buffer[i] = alphabet[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

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
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
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
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
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
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../introspection/IERC165.sol";

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
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Burnable is IERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) external;
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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "./../openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "./../openzeppelin/token/ERC721/IERC721.sol";
import {IWETH} from "./../../interfaces/IWETH.sol";

library TransferHelper {
    // for ERC20
    function balanceOf(address token, address addr)
        internal
        view
        returns (uint256)
    {
        return IERC20(token).balanceOf(addr);
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)'))) -> 0xa9059cbb
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransfer: transfer failed"
        );
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)'))) -> 0x23b872dd
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TransferHelper::safeTransferFrom: transfer failed"
        );
    }

    // for ETH or WETH transfer
    function safeTransferETH(address to, uint256 value) internal {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = address(to).call{value: value, gas: 30000}("");
        require(success, "TransferHelper: Sending ETH failed");
    }

    function balanceOfETH(address addr) internal view returns (uint256) {
        return addr.balance;
    }

    function safeTransferETHOrWETH(
        address weth,
        address to,
        uint256 value
    ) internal {
        // Here increase the gas limit a reasonable amount above the default, and try
        // to send ETH to the recipient.
        // NOTE: This might allow the recipient to attempt a limited reentrancy attack.
        (bool success, ) = address(to).call{value: value, gas: 30000}("");
        if (!success) {
            // can claim ETH via the WETH contract (similar to escrow).
            IWETH(weth).deposit{value: value}();
            safeTransfer(IERC20(weth), to, value);
            // At this point, the recipient can unwrap WETH.
        }
    }

    function swapAndTransferWETH(
        address weth,
        address to,
        uint256 value
    ) internal {
        // can claim ETH via the WETH contract (similar to escrow).
        IWETH(weth).deposit{value: value}();
        safeTransfer(IERC20(weth), to, value);
    }

    // Will attempt to transfer ETH, but will transfer WETH instead if it fails.
    function swapETH2WETH(address weth, uint256 value) internal {
        if (value > 0) {
            IWETH(weth).deposit{value: value}();
        }
    }

    function swapWETH2ETH(address weth, uint256 value) internal {
        if (value > 0) {
            IWETH(weth).withdraw(value);
        }
    }

    // Will attempt to transfer ETH, but will transfer WETH instead if it fails.
    function sendWETH2ETH(
        address weth,
        address to,
        uint256 value
    ) internal {
        if (value > 0) {
            IWETH(weth).withdraw(value);
            safeTransferETHOrWETH(weth, to, value);
        }
    }
}

pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Bend
 * @notice Defines the error messages emitted by the different contracts of the Bend protocol
 */
library Errors {
    //common errors
    // string public constant CALLER_NOT_OWNER = "100"; // 'The caller must be owner'
    string public constant ZERO_ADDRESS = "101"; // 'zero address'

    //vault errors
    string public constant VAULT_ = "200";
    string public constant VAULT_TREASURY_INVALID = "201";
    string public constant VAULT_SUPPLY_INVALID = "202";
    string public constant VAULT_STATE_INVALID = "203";
    string public constant VAULT_BID_PRICE_TOO_LOW = "204";
    string public constant VAULT_BALANCE_INVALID = "205";
    string public constant VAULT_REQ_VALUE_INVALID = "206";
    string public constant VAULT_AUCTION_END = "207";
    string public constant VAULT_AUCTION_LIVE = "208";
    string public constant VAULT_NOT_GOVERNOR = "209";
    string public constant VAULT_STAKING_INVALID = "210";
    string public constant VAULT_STAKING_LENGTH_INVALID = "211";
    string public constant VAULT_TOKEN_INVALID = "212";
    string public constant VAULT_PRICE_TOO_HIGHT = "213";
    string public constant VAULT_PRICE_TOO_LOW = "214";
    string public constant VAULT_PRICE_INVALID = "215";
    string public constant VAULT_STAKING_NEED_MORE_THAN_ZERO = "216";
    string public constant VAULT_STAKING_TRANSFER_FAILED = "217";
    string public constant VAULT_STAKING_INVALID_BALANCE = "218";
    string public constant VAULT_STAKING_INVALID_POOL_ID = "219";
    string public constant VAULT_WITHDRAW_TRANSFER_FAILED = "220";
    string public constant VAULT_TREASURY_TRANSFER_FAILED = "221";
    string public constant VAULT_TREASURY_EPOCH_INVALID = "222";
    string public constant VAULT_REWARD_TOKEN_INVALID = "223";
    string public constant VAULT_REWARD_TOKEN_MAX = "224";
    string public constant VAULT_BID_PRICE_ZERO = "225";
    string public constant VAULT_ZERO_AMOUNT = "226";
    string public constant VAULT_TRANSFER_ETH_FAILED = "227";
    string public constant VAULT_INVALID_PARAMS = "228";
    string public constant VAULT_TREASURY_STAKING_ENABLED = "229";
    string public constant VAULT_NOT_TARGET_CALL = "230";
    string public constant VAULT_PROPOSAL_NOT_AGAINST = "231";
    string public constant VAULT_AFTER_TARGET_CALL_FAILED = "232";
    string public constant VAULT_NOT_VOTERS = "233";
    string public constant VAULT_INVALID_SIGNER = "234";
    string public constant VAULT_INVALID_TIMESTAMP = "235";
    string public constant VAULT_TREASURY_BALANCE_INVALID = "236";
    string public constant VAULT_CHANGING_BALANCE_INVALID = "237";
    string public constant VAULT_NOT_STAKING = "238";

    //treasury errors
    // string public constant TREASURY_ = "300";

    //staking errors
    // string public constant STAKING_ = "400";

    //exchange errors
    // string public constant EXCHANGE_ = "500";

    //exchange errors
    // string public constant GOVERNOR_ = "600";
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IWETH {

    function deposit() external payable;

    function withdraw(uint) external;

    function approve(address, uint) external returns(bool);

    function transfer(address, uint) external returns(bool);

    function transferFrom(address, address, uint) external returns(bool);

    function balanceOf(address) external view returns(uint);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20Burnable} from "../libraries/openzeppelin/token/ERC20/IERC20Burnable.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IVault is IERC20Burnable {
    //

    function listTokens(uint256 _index) external view returns (address);

    function listIds(uint256 _index) external view returns (uint256);

    function listTokensLength() external view returns (uint256);

    function nftGovernor() external view returns (address);

    function curator() external view returns (address);

    function treasury() external view returns (address);

    function staking() external view returns (address);

    function government() external view returns (address);

    function bnft() external view returns (address);

    function exchange() external view returns (address);

    function decimals() external view returns (uint256);

    function initializeGovernorToken() external;

    function permitTransferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "../libraries/openzeppelin/upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IStaking is IERC20Upgradeable {
    //
    function delegate(address delegatee) external;

    function getStakingTotal() external view returns (uint256);

    function changingBalance() external view returns (uint256);

    function addRewardToken(address _addr) external;

    function deposit(uint256 amount, uint256 poolId) external;

    function withdraw(uint256 sId, uint256 amount) external;

    function convertFTokenToVeToken(uint256 amount) external;

    function redeemFToken(uint256 amount) external;
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISettings {
    // interface
    function weth() external view returns (address);

    function minBidIncrease() external view returns (uint256);

    function minVotePercentage() external view returns (uint256);

    function maxExitFactor() external view returns (uint256);

    function minExitFactor() external view returns (uint256);

    function feeReceiver() external view returns (address payable);

    function feePercentage() external view returns (uint256);

    function exitFeeForCuratorPercentage() external view returns (uint256);

    function exitFeeForPlatformPercentage() external view returns (uint256);

    function presaleFeePercentage() external view returns (uint256);

    function reduceStep() external view returns (uint256);

    function auctionLength() external view returns (uint256);

    function auctionExtendLength() external view returns (uint256);

    function votingQuorumPercent() external view returns (uint256);

    function votingMinTokenPercent() external view returns (uint256);

    function votingDelayBlock() external view returns (uint256);

    function votingPeriodBlock() external view returns (uint256);

    function term1Duration() external view returns (uint256);

    function term2Duration() external view returns (uint256);

    function epochDuration() external view returns (uint256);

    function nftOracle() external view returns (address);

    function flashLoanAdmin() external view returns (address);

    function bnftURI() external view returns (string memory);

    function vaultTpl() external view returns (address);

    function stakingTpl() external view returns (address);

    function treasuryTpl() external view returns (address);

    function governmentTpl() external view returns (address);

    function exchangeTpl() external view returns (address);

    function bnftTpl() external view returns (address);

    function getGovernorSetting(address[] memory nftAddrslist)
        external
        view
        returns (
            address,
            address,
            uint256,
            uint256
        );
     function checkGovernorSetting(address[] memory nftAddrslist)
        external
        view
        returns (
          bool
        );
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGovernor {
    // interface
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) external;
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure virtual returns (uint256);

    function isAgainstVote(uint256 proposalId) external view returns (bool);
    function castVote(uint256 proposalId, uint8 support) external virtual returns (uint256 balance);
}

pragma solidity ^0.8.0;

interface IExchange {
    //
    function shareExchangeFeeRewardToken() external;

    function getNewShareExchangeFeeRewardToken(address token)
        external
        view
        returns (uint256);

    function addRewardToken(address _addr) external;
}