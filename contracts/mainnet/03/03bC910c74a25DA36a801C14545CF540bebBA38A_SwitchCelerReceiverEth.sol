// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./SwitchEth.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageReceiverApp.sol";
import "../lib/DataTypes.sol";

contract SwitchCelerReceiverEth is SwitchEth {
    address public celerMessageBus;
    using UniversalERC20 for IERC20;

    struct CelerSwapRequest {
        bytes32 id;
        bytes32 bridge;
        address srcToken;
        address bridgeToken;
        address dstToken;
        address recipient;
        uint256 srcAmount;
        uint256 bridgeDstAmount;
        uint256 estimatedDstAmount;
        DataTypes.ParaswapUsageStatus paraswapUsageStatus;
        uint256[] dstDistribution;
        bytes dstParaswapData;
    }

    constructor(
        address _switchViewAddress,
        address _switchEventAddress,
        address _celerMessageBus,
        address _paraswapProxy,
        address _augustusSwapper
    ) SwitchEth(_switchViewAddress, _switchEventAddress, _paraswapProxy, _augustusSwapper)
        public
    {
        celerMessageBus = _celerMessageBus;
    }

    modifier onlyMessageBus() {
        require(msg.sender == celerMessageBus, "caller is not message bus");
        _;
    }

    function setCelerMessageBus(address _newCelerMessageBus) external onlyOwner {
        celerMessageBus = _newCelerMessageBus;
    }

    // handler function required by MsgReceiverApp
    function executeMessageWithTransfer(
        address, //sender
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    )
        external
        payable
        onlyMessageBus
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        CelerSwapRequest memory m = abi.decode((_message), (CelerSwapRequest));
        require(_token == m.bridgeToken, "bridged token must be the same as the first token in destination swap path");

        if (m.bridgeToken == m.dstToken) {
            IERC20(m.bridgeToken).universalTransfer(m.recipient, _amount);
            _emitCrosschainSwapDone(m, _amount, _amount, DataTypes.SwapStatus.Succeeded);
        } else {
            if (m.paraswapUsageStatus == DataTypes.ParaswapUsageStatus.OnDestChain || m.paraswapUsageStatus == DataTypes.ParaswapUsageStatus.Both) { // When case using paraswap
                if (_amount >= m.bridgeDstAmount) {
                    _callParaswap(IERC20(_token), m.bridgeDstAmount, m.dstParaswapData);
                    IERC20(_token).universalTransfer(m.recipient,  _amount - m.bridgeDstAmount);
                    _emitCrosschainSwapDone(m, m.bridgeDstAmount, m.estimatedDstAmount, DataTypes.SwapStatus.Succeeded);
                } else {
                    _executeWithDistribution(m, _amount);
                }
            } else {
                _executeWithDistribution(m, _amount);
            }
        }

        // always return true since swap failure is already handled in-place
        return IMessageReceiverApp.ExecutionStatus.Success;
    }

    // called on source chain for handling of bridge failures (bad liquidity, bad slippage, etc...)
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address // executor
    )
        external
        payable
        onlyMessageBus
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        CelerSwapRequest memory m = abi.decode((_message), (CelerSwapRequest));

        if (IERC20(_token).isETH()) {
            payable(m.recipient).transfer(_amount);
        } else {
            IERC20(_token).universalTransfer(m.recipient, _amount);
        }

        switchEvent.emitCrosschainSwapRequest(
            m.id,
            bytes32(0),
            m.bridge,
            m.recipient,
            m.srcToken,
            _token,
            m.dstToken,
            m.srcAmount,
            _amount,
            m.estimatedDstAmount,
            DataTypes.SwapStatus.Fallback
        );

        return IMessageReceiverApp.ExecutionStatus.Success;
    }

    // handler function required by MsgReceiverApp
    // called only if handleMessageWithTransfer above was reverted
    function executeMessageWithTransferFallback(
        address, // sender
        address _token, // token,
        uint256 _amount, // amount
        uint64 _srcChainId,
        bytes memory _message,
        address // executor
    )
        external
        payable
        onlyMessageBus
        returns (IMessageReceiverApp.ExecutionStatus)
    {
        CelerSwapRequest memory m = abi.decode((_message), (CelerSwapRequest));
        if (IERC20(_token).isETH()) {
            payable(m.recipient).transfer(_amount);
        } else {
            IERC20(_token).universalTransfer(m.recipient, _amount);
        }
        _emitCrosschainSwapDone(m, _amount, 0, DataTypes.SwapStatus.Fallback);
        // we can do in this app as the swap failures are already handled in executeMessageWithTransfer
        return IMessageReceiverApp.ExecutionStatus.Success;
    }

    function _swapInternalForCeler(
        uint256 amount,
        uint256 parts,
        uint256 lastNonZeroIndex,
        CelerSwapRequest memory m // callData
    )
        internal
        returns (
            DataTypes.SwapStatus status,
            uint256 returnAmount
        )
    {
        returnAmount = _swapInternalForSingleSwap(m.dstDistribution, amount, parts, lastNonZeroIndex, IERC20(m.bridgeToken), IERC20(m.dstToken));
        if (returnAmount > 0) {
            IERC20(m.dstToken).universalTransfer(m.recipient, returnAmount);
            status = DataTypes.SwapStatus.Succeeded;
            switchEvent.emitSwapped(msg.sender, address(this), IERC20(m.bridgeToken), IERC20(m.dstToken), amount, returnAmount, 0);
        } else {
            // handle swap failure, send the received token directly to recipient
            IERC20(m.bridgeToken).universalTransfer(m.recipient, amount);
            returnAmount = amount;
            status = DataTypes.SwapStatus.Fallback;
        }
    }

    function _emitCrosschainSwapDone(
        CelerSwapRequest memory m,
        uint256 srcAmount,
        uint256 dstAmount,
        DataTypes.SwapStatus status
    )
        internal
    {
        switchEvent.emitCrosschainSwapDone(m.id, m.bridge, m.recipient, m.bridgeToken, m.dstToken, srcAmount, dstAmount, status);
    }

    function _executeWithDistribution(
        CelerSwapRequest memory m,
        uint256 srcAmount
    )
        internal
        returns (
            uint256 dstAmount
        )
    {
        DataTypes.SwapStatus status = DataTypes.SwapStatus.Succeeded;
        uint256 parts = 0;
        uint256 lastNonZeroIndex = 0;
        for (uint i = 0; i < m.dstDistribution.length; i++) {
            if (m.dstDistribution[i] > 0) {
                parts += m.dstDistribution[i];
                lastNonZeroIndex = i;
            }
        }

        require(parts > 0, "invalid distribution param");
        (status, dstAmount) = _swapInternalForCeler(srcAmount, parts, lastNonZeroIndex, m);
        _emitCrosschainSwapDone(m, srcAmount, dstAmount, status);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../ISwitchView.sol";
import "../interfaces/ISwitchEvent.sol";
import "./SwitchRootEth.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SwitchEth is SwitchRootEth {
    using UniswapExchangeLib for IUniswapExchange;
    using UniversalERC20 for IERC20;
    using SafeERC20 for IERC20;

    ISwitchView public switchView;
    ISwitchEvent public switchEvent;
    address public reward;
    address public owner;
    address private paraswapProxy;
    address private augustusSwapper;
    address public tradeFeeReceiver;
    uint256 public tradeFeeRate;
    mapping (address => uint256) public partnerFeeRates;

    uint256 public constant FEE_BASE = 10000;

    event RewardSet(address reward);
    event SwitchEventSet(ISwitchEvent switchEvent);
    event OwnerSet(address owner);
    event PartnerFeeSet(address partner, uint256 feeRate);
    event TradeFeeSet(uint256 tradeFee);
    event TradeFeeReceiverSet(address tradeFeeReceiver);
    event ParaswapProxySet(address paraswapProxy);
    event AugustusSwapperSet(address augustusSwapper);
    
    constructor(
        address _switchViewAddress,
        address _switchEventAddress,
        address _paraswapProxy,
        address _augustusSwapper
    )
        public
    {
        switchView = ISwitchView(_switchViewAddress);
        switchEvent = ISwitchEvent(_switchEventAddress);
        paraswapProxy = _paraswapProxy;
        augustusSwapper = _augustusSwapper;
        reward = msg.sender;
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(
            msg.sender == owner,
            "Only owner can call this function."
        );
        _;
    }

    fallback() external payable {
        // solium-disable-next-line security/no-tx-origin
        require(msg.sender != tx.origin);
    }

    function setReward(address _reward) external onlyOwner {
        reward = _reward;
        emit RewardSet(_reward);
    }

    function setSwitchEvent(ISwitchEvent _switchEvent) external onlyOwner {
        switchEvent = _switchEvent;
        emit SwitchEventSet(_switchEvent);
    }

    function setParaswapProxy(address _paraswapProxy) external onlyOwner {
        paraswapProxy = _paraswapProxy;
	emit ParaswapProxySet(_paraswapProxy);
    }

    function setAugustusSwapper(address _augustusSwapper) external onlyOwner {
        augustusSwapper = _augustusSwapper;
	emit AugustusSwapperSet(_augustusSwapper);
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
        emit OwnerSet(_owner);
    }

    function setPartnerFeeRate(address _partner, uint256 _feeRate) external onlyOwner {
        partnerFeeRates[_partner] = _feeRate;
        emit PartnerFeeSet(_partner, _feeRate);
    }

    function setTradeFeeRate(uint256 _tradeFeeRate) external onlyOwner {
        tradeFeeRate = _tradeFeeRate;
        emit TradeFeeSet(_tradeFeeRate);
    }

    function setTradeFeeReceiver(address _tradeFeeReceiver) external onlyOwner {
        tradeFeeReceiver = _tradeFeeReceiver;
        emit TradeFeeReceiverSet(_tradeFeeReceiver);
    }

    function getTokenBalance(address token) external view onlyOwner returns(uint256 amount) {
        amount = IERC20(token).universalBalanceOf(address(this));
    }

    function transferToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).universalTransfer(owner, amount);
    }

    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts
    )
        public
        override
        view
        returns (
            uint256 returnAmount,
            uint256[] memory distribution
        )
    {
        (returnAmount, distribution) = switchView.getExpectedReturn(fromToken, destToken, amount, parts);
    }

    function swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 expectedReturn,
        uint256 minReturn,
        address recipient,
        uint256[] memory distribution
    )
        public
        payable
        returns (uint256 returnAmount)
    {
        require(expectedReturn >= minReturn, "expectedReturn must be equal or larger than minReturn");
        if (fromToken == destToken) {
            revert("it's not allowed to swap with same token");
        }

        uint256 parts = 0;
        uint256 lastNonZeroIndex = 0;
        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] > 0) {
                parts += distribution[i];
                lastNonZeroIndex = i;
            }
        }

        if (parts == 0) {
            if (fromToken.isETH()) {
                payable(msg.sender).transfer(msg.value);
                return msg.value;
            }
            return amount;
        }

        fromToken.universalTransferFrom(msg.sender, address(this), amount);
        // break function to avoid stack too deep error
        returnAmount = _swapInternalForSingleSwap(distribution, amount, parts, lastNonZeroIndex, fromToken, destToken);
        if (returnAmount > 0) {
            require(returnAmount >= minReturn, "Switch: Return amount was not enough");

            if (returnAmount > expectedReturn) {
                destToken.universalTransfer(recipient, expectedReturn);
                destToken.universalTransfer(reward, returnAmount - expectedReturn);
                switchEvent.emitSwapped(msg.sender, recipient, fromToken, destToken, amount, expectedReturn, returnAmount - expectedReturn);
            } else {
                destToken.universalTransfer(recipient, returnAmount);
                switchEvent.emitSwapped(msg.sender, recipient, fromToken, destToken, amount, returnAmount, 0);
            }
        } else {
            if (fromToken.universalBalanceOf(address(this)) > amount) {
                fromToken.universalTransfer(msg.sender, amount);
            } else {
                fromToken.universalTransfer(msg.sender, fromToken.universalBalanceOf(address(this)));
            }
        }
    }

    function swapWithParaswap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 destAmount,
        address recipient,
        bytes memory callData
    )
        public
        payable
    {
        if (fromToken == destToken) {
            revert("it's not allowed to swap with same token");
        }
        fromToken.universalTransferFrom(msg.sender, address(this), amount);
        //Check if this contract have enough token or allowance
        _callParaswap(fromToken, amount, callData);
        switchEvent.emitSwapped(msg.sender, recipient, fromToken, destToken, amount, destAmount, 0);
    }

    function getFeeInfo(
        uint256 amount,
        address partner
    )
        public
        view
        returns (
            uint256 tradeRate,
            uint256 partnerFeeRate,
            uint256 tradeFee,
            uint256 partnerFee,
            uint256 remainAmount
        )
    {
        tradeRate = tradeFeeRate;
        tradeFee = 0;
        partnerFeeRate = partnerFeeRates[partner];
        partnerFee = 0;
        if (tradeFeeRate > 0) {
            tradeFee = tradeFeeRate * amount / FEE_BASE;
        }
        if (partnerFeeRates[partner] > 0) {
            partnerFee = partnerFeeRates[partner] * amount / FEE_BASE;
        }
        remainAmount = amount - tradeFee - partnerFee;
    }

    function getTradeFee(
        uint256 amount
    )
        public
        view
        returns (
            uint256 feeRate,
            uint256 tradeFee,
            uint256 remainAmount
        )
    {
        feeRate = tradeFeeRate;
        tradeFee = 0;
        if (tradeFeeRate > 0) {
            tradeFee = tradeFeeRate * amount / FEE_BASE;
        }
        remainAmount = amount - tradeFee;
    }

    function getPartnerFee(
        uint256 amount,
        address partner
    )
        public
        view
        returns (
            uint256 feeRate,
            uint256 partnerFee,
            uint256 remainAmount
        )
    {
        feeRate = partnerFeeRates[partner];
        partnerFee = 0;
        if (partnerFeeRates[partner] > 0) {
            partnerFee = partnerFeeRates[partner] * amount / FEE_BASE;
        }
        remainAmount = amount - partnerFee;
    }

    function _swapInternalWithParaSwap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        bytes memory callData
    )
        internal
        returns (
            uint256 totalAmount
        )
    {
        if (fromToken == destToken) {
            revert("it's not allowed to swap with same token");
        }

        _callParaswap(fromToken, amount, callData);
        totalAmount = destToken.universalBalanceOf(address(this));
        switchEvent.emitSwapped(msg.sender, address(this), fromToken, destToken, amount, totalAmount, 0);
    }

    function _callParaswap(
        IERC20 fromToken,
        uint256 amount,
        bytes memory callData
    )
        internal
    {
        uint256 ethAmountToTransfert = 0;
        if (fromToken.isETH()) {
            require(address(this).balance >= amount, "ETH balance is insufficient");
            ethAmountToTransfert = amount;
        } else {
            uint256 approvedAmount = fromToken.allowance(address(this), paraswapProxy);
            if (approvedAmount < amount) {
                fromToken.safeIncreaseAllowance(paraswapProxy, amount - approvedAmount);
            }
        }

        (bool success,) = augustusSwapper.call{ value: ethAmountToTransfert }(callData);
        require(success, "Paraswap execution failed");
    }

    function _swapInternalForSingleSwap(
        uint256[] memory distribution,
        uint256 amount,
        uint256 parts,
        uint256 lastNonZeroIndex,
        IERC20 fromToken,
        IERC20 destToken
    )
        internal
        returns (
            uint256 totalAmount
        )
    {
        require(distribution.length <= DEXES_COUNT*PATHS_COUNT, "Switch: Distribution array should not exceed factories array size");

        uint256 remainingAmount = amount;
        uint256 swappedAmount = 0;
        for (uint i = 0; i < distribution.length; i++) {
            if (distribution[i] == 0) {
                continue;
            }
            uint256 swapAmount = amount * distribution[i] / parts;
            if (i == lastNonZeroIndex) {
                swapAmount = remainingAmount;
            }
            remainingAmount -= swapAmount;
            if (i % PATHS_COUNT == 0) {
                swappedAmount = _swap(fromToken, destToken, swapAmount, IUniswapFactory(factories[i/PATHS_COUNT]));
            } else {
                swappedAmount = _swapETH(fromToken, destToken, swapAmount, IUniswapFactory(factories[i/PATHS_COUNT]));
            }
            totalAmount += swappedAmount;
        }
    }

    function _getAmountAfterFee(
        IERC20 token,
        uint256 amount,
        address partner
    )
        internal
        returns (
            uint256 amountAfterFee
        )
    {
        amountAfterFee = amount;
        if (tradeFeeRate > 0) {
            token.universalTransfer(tradeFeeReceiver, tradeFeeRate * amount / FEE_BASE);
            amountAfterFee = amount - tradeFeeRate * amount / FEE_BASE;
        }
        if (partnerFeeRates[partner] > 0) {
            token.universalTransfer(partner, partnerFeeRates[partner] * amount / FEE_BASE);
            amountAfterFee = amount - partnerFeeRates[partner] * amount / FEE_BASE;
        }
    }

    // Swap helpers
    function _swapInternal(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        IUniswapFactory factory
    )
        internal
        returns (
            uint256 returnAmount
        )
    {
        if (fromToken.isETH()) {
            weth.deposit{value: amount}();
        }

        IERC20 fromTokenReal = fromToken.isETH() ? weth : fromToken;
        IERC20 toTokenReal = destToken.isETH() ? weth : destToken;
        IUniswapExchange exchange = factory.getPair(fromTokenReal, toTokenReal);
        bool needSync;
        bool needSkim;
        (returnAmount, needSync, needSkim) = exchange.getReturn(fromTokenReal, toTokenReal, amount);
        if (needSync) {
            exchange.sync();
        } else if (needSkim) {
            exchange.skim(0xBdB82D89731De719CAe1171C1Fa999E8c13ce77A);
        }

        fromTokenReal.universalTransfer(address(exchange), amount);
        if (uint160(address(fromTokenReal)) < uint160(address(toTokenReal))) {
            exchange.swap(0, returnAmount, address(this), "");
        } else {
            exchange.swap(returnAmount, 0, address(this), "");
        }

        if (destToken.isETH()) {
            weth.withdraw(weth.balanceOf(address(this)));
        }
    }

    function _swapOverMid(
        IERC20 fromToken,
        IERC20 midToken,
        IERC20 destToken,
        uint256 amount,
        IUniswapFactory factory
    )
        internal
        returns (
            uint256 returnAmount
        )
    {
        returnAmount = _swapInternal(
            midToken,
            destToken,
            _swapInternal(
                fromToken,
                midToken,
                amount,
                factory
            ),
            factory
        );
    }

    function _swap(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        IUniswapFactory factory
    )
        internal
        returns (
            uint256 returnAmount
        )
    {
        returnAmount = _swapInternal(
            fromToken,
            destToken,
            amount,
            factory
        );
    }

    function _swapETH(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        IUniswapFactory factory
    )
        internal
        returns (
            uint256 returnAmount
        )
    {
        returnAmount = _swapOverMid(
            fromToken,
            weth,
            destToken,
            amount,
            factory
        );
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IMessageReceiverApp {
    enum ExecutionStatus {
        Fail, // execution failed, finalized
        Success, // execution succeeded, finalized
        Retry // execution rejected, can retry later
    }

    /**
     * @notice Called by MessageBus (MessageBusReceiver) if the process is originated from MessageBus (MessageBusSender)'s
     *         sendMessageWithTransfer it is only called when the tokens are checked to be arrived at this contract's address.
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     *        the contract that implements this contract can safely assume that the tokens will arrive before this
     *        function is called.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Only called by MessageBus (MessageBusReceiver) if
     *         1. executeMessageWithTransfer reverts, or
     *         2. executeMessageWithTransfer returns ExecutionStatus.Fail
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     *        the contract that implements this contract can safely assume that the tokens will arrive before this
     *        function is called.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus (MessageBusReceiver) to process refund of the original transfer from this contract
     * @param _token The token address of the original transfer
     * @param _amount The amount of the original transfer
     * @param _message The same message associated with the original transfer
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus (MessageBusReceiver)
     * @param _sender The address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;
/**
 * @title DataTypes
 * @dev Definition of shared types
 */
library DataTypes {
    /// @notice Type for representing a swapping status type
    enum SwapStatus {
        Null,
        Succeeded,
        Failed,
        Fallback
    }

    /// @notice Type for representing a swapping status type
    enum ParaswapUsageStatus {
        None,
        OnSrcChain,
        OnDestChain,
        Both
    }

    /// @notice Swap params
    struct SwapInfo {
        address srcToken;
        address dstToken;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "./interfaces/IUniswapFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract ISwitchView {

    struct ReturnArgs {
        IERC20 fromToken;
        IERC20 destToken;
        uint256 amount;
        uint256 parts;
    }

    struct CalculateArgs {
        IERC20 fromToken;
        IERC20 destToken;
        IUniswapFactory factory;
        uint256 amount;
        uint256 parts;
    }

    function getExpectedReturn(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts
    )
        public
        virtual
        view
        returns (
            uint256 returnAmount,
            uint256[] memory distribution
        );
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../lib/DataTypes.sol";

interface ISwitchEvent {
    function emitSwapped(
        address from,
        address recipient,
        IERC20 fromToken,
        IERC20 destToken,
        uint256 fromAmount,
        uint256 destAmount,
        uint256 reward
    ) external;

    function emitParaswapSwapped(
        address from,
        IERC20 fromToken,
        uint256 fromAmount
    ) external;

    function emitCrosschainSwapRequest(
        bytes32 id,
        bytes32 bridgeTransferId,
        bytes32 bridge, // bridge slug
        address from, // user address
        address fromToken, // source token on sending chain
        address bridgeToken, // bridge token on sending chain
        address destToken, // dest token on receiving chain
        uint256 fromAmount, // source token amount on sending chain
        uint256 bridgeAmount, // swapped amount on sending chain
        uint256 dstAmount, // estimated amount of dest token on receiving chain
        DataTypes.SwapStatus status
    ) external;

    function emitCrosschainSwapDone(
        bytes32 id,
        bytes32 bridge,
        address from, // user address
        address bridgeToken, // source token on receiving chain
        address destToken, // dest token on receiving chain
        uint256 bridgeAmount, // bridge token amount on receiving chain
        uint256 destAmount, //dest token amount on receiving chain
        DataTypes.SwapStatus status
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../ISwitchView.sol";
import "../IWETH.sol";
import "../lib/DisableFlags.sol";
import "../lib/UniversalERC20.sol";
import "../interfaces/IUniswapFactory.sol";
import "../lib/UniswapExchangeLib.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract SwitchRootEth is ISwitchView {
    using DisableFlags for uint256;
    using UniversalERC20 for IERC20;
    using UniversalERC20 for IWETH;
    using UniswapExchangeLib for IUniswapExchange;

    uint256 constant internal DEXES_COUNT = 3;
    uint256 constant internal PATHS_COUNT = 2;
    uint256 constant internal PATHS_SPLIT = 2;
    address constant internal ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    address constant internal ZERO_ADDRESS = address(0);

    IWETH constant internal weth = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    IUniswapFactory[DEXES_COUNT] public factories = [
        IUniswapFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f), // uniswap,
        IUniswapFactory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac), // sushiswap,
        IUniswapFactory(0x115934131916C8b277DD010Ee02de363c09d037c) // shibaswap
    ];

    int256 internal constant VERY_NEGATIVE_VALUE = -1e72;

    function _findBestDistribution(
        uint256 s,                // parts
        int256[][] memory amounts // exchangesReturns
    )
        internal
        pure
        returns (
            int256 returnAmount,
            uint256[] memory distribution
        )
    {
        uint256 n = amounts.length;

        int256[][] memory answer = new int256[][](n); // int[n][s+1]
        uint256[][] memory parent = new uint256[][](n); // int[n][s+1]

        for (uint i = 0; i < n; i++) {
            answer[i] = new int256[](s + 1);
            parent[i] = new uint256[](s + 1);
        }

        for (uint j = 0; j <= s; j++) {
            answer[0][j] = amounts[0][j];
            for (uint i = 1; i < n; i++) {
                answer[i][j] = -1e72;
            }
            parent[0][j] = 0;
        }

        for (uint i = 1; i < n; i++) {
            for (uint j = 0; j <= s; j++) {
                answer[i][j] = answer[i - 1][j];
                parent[i][j] = j;

                for (uint k = 1; k <= j; k++) {
                    if (answer[i - 1][j - k] + amounts[i][k] > answer[i][j]) {
                        answer[i][j] = answer[i - 1][j - k] + amounts[i][k];
                        parent[i][j] = j - k;
                    }
                }
            }
        }

        distribution = new uint256[](DEXES_COUNT*PATHS_COUNT*PATHS_SPLIT);

        uint256 partsLeft = s;
        unchecked {
            for (uint curExchange = n - 1; partsLeft > 0; curExchange--) {
                distribution[curExchange] = partsLeft - parent[curExchange][partsLeft];
                partsLeft = parent[curExchange][partsLeft];
            }
        }

        returnAmount = (answer[n - 1][s] == VERY_NEGATIVE_VALUE) ? int256(0) : answer[n - 1][s];
    }


    function _linearInterpolation(
        uint256 value,
        uint256 parts
    )
        internal
        pure
        returns (uint256[] memory rets)
    {
        rets = new uint256[](parts);
        for (uint i = 0; i < parts; i++) {
            rets[i] = value * (i + 1) / parts;
        }
    }

    function _tokensEqual(
        IERC20 tokenA,
        IERC20 tokenB
    )
        internal
        pure
        returns (bool)
    {
        return ((tokenA.isETH() && tokenB.isETH()) || tokenA == tokenB);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswapExchange.sol";

interface IUniswapFactory {
    function getPair(IERC20 tokenA, IERC20 tokenB) external view returns (IUniswapExchange pair);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface IUniswapExchange {
    function getReserves() external view returns(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract IWETH is IERC20 {
    function deposit() external virtual payable;
    function withdraw(uint256 amount) virtual external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

library DisableFlags {
    function check(
        uint256 flags,
        uint256 flag
    )
        internal
        pure
        returns (bool)
    {
        return (flags & flag) != 0;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UniversalERC20 {

    using SafeERC20 for IERC20;

    address private constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);
    address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    function universalTransfer(
        IERC20 token,
        address to,
        uint256 amount
    )
        internal
        returns (bool)
    {
        if (amount == 0) {
            return true;
        }
        if (isETH(token)) {
            payable(to).transfer(amount);
            return true;
        } else {
            token.safeTransfer(to, amount);
            return true;
        }
    }

    function universalTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        if (isETH(token)) {
            require(from == msg.sender && msg.value >= amount, "Wrong useage of ETH.universalTransferFrom()");
            if (to != address(this)) {
                payable(to).transfer(amount);
            }
            // commented following lines for passing celer fee properly.
//            if (msg.value > amount) {
//                payable(msg.sender).transfer(msg.value - amount);
//            }
        } else {
            token.safeTransferFrom(from, to, amount);
        }
    }

    function universalTransferFromSenderToThis(
        IERC20 token,
        uint256 amount
    )
        internal
    {
        if (amount == 0) {
            return;
        }

        if (isETH(token)) {
            if (msg.value > amount) {
                // Return remainder if exist
                payable(msg.sender).transfer(msg.value - amount);
            }
        } else {
            token.safeTransferFrom(msg.sender, address(this), amount);
        }
    }

    function universalApprove(
        IERC20 token,
        address to,
        uint256 amount
    )
        internal
    {
        if (!isETH(token)) {
            if (amount == 0) {
                token.safeApprove(to, 0);
                return;
            }

            uint256 allowance = token.allowance(address(this), to);
            if (allowance < amount) {
                if (allowance > 0) {
                    token.safeApprove(to, 0);
                }
                token.safeApprove(to, amount);
            }
        }
    }

    function universalBalanceOf(IERC20 token, address who) internal view returns (uint256) {
        if (isETH(token)) {
            return who.balance;
        } else {
            return token.balanceOf(who);
        }
    }

    function isETH(IERC20 token) internal pure returns(bool) {
        return (address(token) == address(ZERO_ADDRESS) || address(token) == address(ETH_ADDRESS));
    }

    // function notExist(IERC20 token) internal pure returns(bool) {
    //     return (address(token) == address(-1));
    // }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "../interfaces/IUniswapExchange.sol";
import "./Math.sol";
import "./UniversalERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library UniswapExchangeLib {
    using Math for uint256;
    using UniversalERC20 for IERC20;

    function getReturn(
        IUniswapExchange exchange,
        IERC20 fromToken,
        IERC20 destToken,
        uint amountIn
    )
        internal
        view
        returns (uint256 result, bool needSync, bool needSkim)
    {
        uint256 reserveIn = fromToken.universalBalanceOf(address(exchange));
        uint256 reserveOut = destToken.universalBalanceOf(address(exchange));
        (uint112 reserve0, uint112 reserve1,) = exchange.getReserves();
        if (fromToken > destToken) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }
        needSync = (reserveIn < reserve0 || reserveOut < reserve1);
        needSkim = !needSync && (reserveIn > reserve0 || reserveOut > reserve1);

        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * Math.min(reserveOut, reserve1);
        uint256 denominator = Math.min(reserveIn, reserve0) * 1000 + amountInWithFee;
        result = (denominator == 0) ? 0 : numerator / denominator;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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
pragma solidity >=0.8.9;

library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}