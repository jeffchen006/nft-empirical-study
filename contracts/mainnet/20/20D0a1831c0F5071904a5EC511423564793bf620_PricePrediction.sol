// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './interfaces/AggregatorProxy.sol';
import './interfaces/ISmoltingInu.sol';
import './SmolGame.sol';

/**
 * @title PricePrediction
 * @dev Predict if price goes up or down over a time period
 */
contract PricePrediction is SmolGame {
  uint256 private constant PERCENT_DENOMENATOR = 1000;
  address private constant DEAD = address(0xdead);

  struct PredictionConfig {
    uint256 timePeriodSeconds;
    uint256 payoutPercentage;
  }
  struct Prediction {
    address priceFeedProxy;
    uint256 configTimePeriodSeconds;
    uint256 configPayoutPercentage;
    bool isLong; // true if price should go higher, otherwise price expected to go lower
    uint256 amountWagered;
    uint16 startPhaseId;
    uint80 startRoundId;
    uint16 endPhaseId; // not set until prediction is settled
    uint80 endRoundId; // not set until prediction is settled
    bool isDraw; // not set until prediction is settled
    bool isWinner; // not set until prediction is settled
  }

  uint256 public minBalancePerc = (PERCENT_DENOMENATOR * 35) / 100; // 35% user's balance
  uint256 public minWagerAbsolute;
  uint256 public maxWagerAbsolute;

  uint80 public roundIdStartOffset = 1;

  address[] public validPriceFeedProxies;
  mapping(address => bool) public isValidPriceFeedProxy;

  PredictionConfig[] public predictionOptions;

  address public smol = 0x2bf6267c4997548d8de56087E5d48bDCCb877E77;
  ISmoltingInu private smolContract = ISmoltingInu(smol);

  uint256 public totalPredictionsMade;
  uint256 public totalPredictionsWon;
  uint256 public totalPredictionsLost;
  uint256 public totalPredictionsDraw;
  uint256 public totalPredictionsAmountWon;
  uint256 public totalPredictionsAmountLost;
  // user => predictions[]
  mapping(address => Prediction[]) public predictions;
  mapping(address => uint256) public predictionsUserWon;
  mapping(address => uint256) public predictionsUserLost;
  mapping(address => uint256) public predictionsUserDraw;
  mapping(address => uint256) public predictionsAmountUserWon;
  mapping(address => uint256) public predictionsAmountUserLost;

  event Predict(
    address indexed user,
    address indexed proxy,
    uint16 startPhase,
    uint80 startRound,
    uint256 amountWager
  );
  event Settle(
    address indexed user,
    address indexed proxy,
    bool isWinner,
    bool isDraw,
    uint256 amountWon
  );

  function getAllValidPriceFeeds() external view returns (address[] memory) {
    return validPriceFeedProxies;
  }

  function getNumberUserPredictions(address _user)
    external
    view
    returns (uint256)
  {
    return predictions[_user].length;
  }

  function getLatestUserPrediction(address _user)
    external
    view
    returns (Prediction memory)
  {
    require(predictions[_user].length > 0, 'no predictions for user');
    return predictions[_user][predictions[_user].length - 1];
  }

  /**
   * Returns the latest price with returned value from a price feed proxy at 18 decimals
   * more info (proxy vs agg) here:
   * https://stackoverflow.com/questions/70377502/what-is-the-best-way-to-access-historical-price-data-from-chainlink-on-a-token-i/70389049#70389049
   *
   * https://docs.chain.link/docs/get-the-latest-price/
   */
  function getRoundInfoAndPriceUSD(address _proxy)
    public
    view
    returns (
      uint16,
      uint80,
      uint256
    )
  {
    // https://docs.chain.link/docs/reference-contracts/
    // https://github.com/pcaversaccio/chainlink-price-feed/blob/main/README.md
    AggregatorProxy priceFeed = AggregatorProxy(_proxy);
    uint16 phaseId = priceFeed.phaseId();
    uint8 decimals = priceFeed.decimals();
    (uint80 proxyRoundId, int256 price, , , ) = priceFeed.latestRoundData();
    return (phaseId, proxyRoundId, uint256(price) * (10**18 / 10**decimals));
  }

  function getPriceUSDAtRound(address _proxy, uint80 _roundId)
    public
    view
    returns (uint256)
  {
    AggregatorProxy priceFeed = AggregatorProxy(_proxy);
    uint8 decimals = priceFeed.decimals();
    (, int256 price, , , ) = priceFeed.getRoundData(_roundId);
    return uint256(price) * (10**18 / 10**decimals);
  }

  // https://docs.chain.link/docs/historical-price-data/
  function getHistoricalPriceFromAggregatorInfo(
    address _proxy,
    uint16 _phaseId,
    uint80 _aggRoundId,
    bool _requireCompletion
  )
    public
    view
    returns (
      uint80,
      uint256,
      uint256,
      uint80
    )
  {
    AggregatorProxy proxy = AggregatorProxy(_proxy);
    uint80 _proxyRoundId = _getProxyRoundId(_phaseId, _aggRoundId);
    (
      uint80 roundId,
      int256 price,
      ,
      uint256 timestamp,
      uint80 answeredInRound
    ) = proxy.getRoundData(_proxyRoundId);
    uint8 decimals = proxy.decimals();
    if (_requireCompletion) {
      require(timestamp > 0, 'Round not complete');
    }
    return (
      roundId,
      uint256(price) * (10**18 / 10**decimals),
      timestamp,
      answeredInRound
    );
  }

  // _isLong: if true, user wants price to go up, else price should go down
  function predict(
    uint256 _configIndex,
    address _priceFeedProxy,
    uint256 _amountWager,
    bool _isLong
  ) external payable {
    require(
      isValidPriceFeedProxy[_priceFeedProxy],
      'not a valid price feed to predict'
    );
    require(
      _amountWager >=
        (smolContract.balanceOf(msg.sender) * minBalancePerc) /
          PERCENT_DENOMENATOR,
      'did not wager enough of balance'
    );
    require(_amountWager >= minWagerAbsolute, 'did not wager at least minimum');
    require(
      maxWagerAbsolute == 0 || _amountWager <= maxWagerAbsolute,
      'wagering more than maximum'
    );

    address _user = msg.sender;
    if (predictions[_user].length > 0) {
      Prediction memory _openPrediction = predictions[_user][
        predictions[_user].length - 1
      ];
      require(
        _openPrediction.endRoundId > 0,
        'there is an open prediction you must settle before creating a new one'
      );
    }

    smolContract.transferFrom(msg.sender, address(this), _amountWager);
    (uint16 _phaseId, uint80 _proxyRoundId, ) = getRoundInfoAndPriceUSD(
      _priceFeedProxy
    );
    (, uint64 _aggRoundId) = getAggregatorPhaseAndRoundId(_proxyRoundId);
    uint80 _startRoundId = _getProxyRoundId(
      _phaseId,
      _aggRoundId + roundIdStartOffset
    );

    PredictionConfig memory _config = predictionOptions[_configIndex];
    require(_config.timePeriodSeconds > 0, 'invalid config provided');

    Prediction memory _newPrediction = Prediction({
      priceFeedProxy: _priceFeedProxy,
      configTimePeriodSeconds: _config.timePeriodSeconds,
      configPayoutPercentage: _config.payoutPercentage,
      isLong: _isLong,
      amountWagered: _amountWager,
      startPhaseId: _phaseId,
      startRoundId: _startRoundId,
      endPhaseId: 0,
      endRoundId: 0,
      isDraw: false,
      isWinner: false
    });
    predictions[_user].push(_newPrediction);

    totalPredictionsMade++;
    _payServiceFee();
    emit Predict(
      msg.sender,
      _priceFeedProxy,
      _phaseId,
      _startRoundId,
      _amountWager
    );
  }

  // in order to settle an open prediction, the settling executor must know the
  // user with the open prediction they are settling and the round ID that corresponds
  // to the time it should be settled.
  function settlePrediction(
    address _user,
    uint16 _answeredPhaseId,
    uint80 _answeredAggRoundId
  ) public {
    _user = _user == address(0) ? msg.sender : _user;
    require(predictions[_user].length > 0, 'no predictions created yet');
    Prediction storage _openPrediction = predictions[_user][
      predictions[_user].length - 1
    ];
    require(
      _openPrediction.priceFeedProxy != address(0),
      'no predictions created yet to settle'
    );
    require(
      _openPrediction.endRoundId == 0,
      'latest prediction already settled'
    );

    (
      ,
      uint256 priceStart,
      uint256 timestampStart,
      uint80 answeredInRoundIdStart
    ) = getHistoricalPriceFromAggregatorInfo(
        _openPrediction.priceFeedProxy,
        _openPrediction.startPhaseId,
        _openPrediction.startRoundId,
        true
      );
    require(
      answeredInRoundIdStart > 0 && timestampStart > 0,
      'start round is not fresh'
    );
    (
      uint80 roundActual,
      ,
      uint256 timestampActual,

    ) = getHistoricalPriceFromAggregatorInfo(
        _openPrediction.priceFeedProxy,
        _answeredPhaseId,
        _answeredAggRoundId,
        true
      );
    (, , uint256 timestampAfter, ) = getHistoricalPriceFromAggregatorInfo(
      _openPrediction.priceFeedProxy,
      _answeredPhaseId,
      _answeredAggRoundId + 1,
      false
    );
    require(
      roundActual > 0 && timestampActual > 0,
      'actual round not finished yet'
    );
    require(
      timestampActual <=
        timestampStart + _openPrediction.configTimePeriodSeconds,
      'actual round was completed after our time period'
    );
    require(
      timestampAfter >
        timestampStart + _openPrediction.configTimePeriodSeconds ||
        (timestampAfter == 0 &&
          block.timestamp >
          timestampStart + _openPrediction.configTimePeriodSeconds),
      'after round was completed before our time period'
    );

    uint256 settlePrice = getPriceUSDAtRound(
      _openPrediction.priceFeedProxy,
      roundActual
    );

    bool _isDraw = settlePrice == priceStart;
    bool _isWinner = false;
    if (!_isDraw) {
      _isWinner = _openPrediction.isLong
        ? settlePrice > priceStart
        : settlePrice < priceStart;
    }

    _openPrediction.endPhaseId = _answeredPhaseId;
    _openPrediction.endRoundId = roundActual;
    _openPrediction.isDraw = _isDraw;
    _openPrediction.isWinner = _isWinner;

    uint256 _finalWinAmount = _isWinner
      ? (_openPrediction.amountWagered *
        _openPrediction.configPayoutPercentage) / PERCENT_DENOMENATOR
      : 0;

    if (_isDraw || _isWinner) {
      smolContract.transfer(_user, _openPrediction.amountWagered);
      if (_finalWinAmount > 0) {
        smolContract.gameMint(_user, _finalWinAmount);
      }
    } else {
      smolContract.gameBurn(address(this), _openPrediction.amountWagered);
    }

    _updateAnalytics(
      _user,
      _isDraw,
      _isWinner,
      _openPrediction.amountWagered,
      _finalWinAmount
    );

    emit Settle(
      _user,
      _openPrediction.priceFeedProxy,
      _isWinner,
      _isDraw,
      _finalWinAmount
    );
  }

  function settlePredictionShortCircuitLoss() external {
    require(predictions[msg.sender].length > 0, 'no predictions created yet');
    Prediction storage _prediction = predictions[msg.sender][
      predictions[msg.sender].length - 1
    ];
    require(
      _prediction.priceFeedProxy != address(0),
      'no predictions created yet to settle'
    );
    require(_prediction.endRoundId == 0, 'latest prediction already settled');
    // just set the end phase and round to the start if we short circuit here
    _prediction.endPhaseId = _prediction.startPhaseId;
    _prediction.endRoundId = _prediction.startRoundId;
    smolContract.gameBurn(address(this), _prediction.amountWagered);
    _updateAnalytics(msg.sender, false, false, _prediction.amountWagered, 0);
    emit Settle(msg.sender, _prediction.priceFeedProxy, false, false, 0);
  }

  function settleMultiplePredictions(
    address[] memory _users,
    uint16[] memory _phaseIds,
    uint80[] memory _aggRoundIds
  ) external {
    require(_users.length == _phaseIds.length, 'need to be same size arrays');
    require(
      _users.length == _aggRoundIds.length,
      'need to be same size arrays'
    );
    for (uint256 i = 0; i < _users.length; i++) {
      settlePrediction(_users[i], _phaseIds[i], _aggRoundIds[i]);
    }
  }

  function _updateAnalytics(
    address _user,
    bool _isDraw,
    bool _isWinner,
    uint256 _amountWagered,
    uint256 _finalWinAmount
  ) internal {
    totalPredictionsWon += _isWinner ? 1 : 0;
    predictionsUserWon[_user] += _isWinner ? 1 : 0;
    totalPredictionsLost += !_isWinner && !_isDraw ? 1 : 0;
    predictionsUserLost[_user] += !_isWinner && !_isDraw ? 1 : 0;
    totalPredictionsDraw += _isDraw ? 1 : 0;
    predictionsUserDraw[_user] += _isDraw ? 1 : 0;
    totalPredictionsAmountWon += _isWinner ? _finalWinAmount : 0;
    predictionsAmountUserWon[_user] += _isWinner ? _finalWinAmount : 0;
    totalPredictionsAmountLost += !_isWinner && !_isDraw ? _amountWagered : 0;
    predictionsAmountUserLost[_user] += !_isWinner && !_isDraw
      ? _amountWagered
      : 0;
  }

  function _getProxyRoundId(uint16 _phaseId, uint80 _aggRoundId)
    internal
    pure
    returns (uint80)
  {
    return uint80((uint256(_phaseId) << 64) | _aggRoundId);
  }

  function getAggregatorPhaseAndRoundId(uint256 _proxyRoundId)
    public
    pure
    returns (uint16, uint64)
  {
    uint16 phaseId = uint16(_proxyRoundId >> 64);
    uint64 aggregatorRoundId = uint64(_proxyRoundId);
    return (phaseId, aggregatorRoundId);
  }

  function getAllPredictionOptions()
    external
    view
    returns (PredictionConfig[] memory)
  {
    return predictionOptions;
  }

  function setMinBalancePerc(uint256 _perc) external onlyOwner {
    require(_perc <= PERCENT_DENOMENATOR, 'cannot be more than 100%');
    minBalancePerc = _perc;
  }

  function setMinWagerAbsolute(uint256 _amount) external onlyOwner {
    minWagerAbsolute = _amount;
  }

  function setMaxWagerAbsolute(uint256 _amount) external onlyOwner {
    maxWagerAbsolute = _amount;
  }

  function addPredictionOption(uint256 _seconds, uint256 _percentage)
    external
    onlyOwner
  {
    require(_seconds > 60, 'must be longer than 60 seconds');
    require(_percentage <= PERCENT_DENOMENATOR, 'cannot be more than 100%');
    predictionOptions.push(
      PredictionConfig({
        timePeriodSeconds: _seconds,
        payoutPercentage: _percentage
      })
    );
  }

  function removePredictionOption(uint256 _index) external onlyOwner {
    predictionOptions[_index] = predictionOptions[predictionOptions.length - 1];
    predictionOptions.pop();
  }

  function updatePredictionOption(
    uint256 _index,
    uint256 _seconds,
    uint256 _percentage
  ) external onlyOwner {
    PredictionConfig storage _pred = predictionOptions[_index];
    _pred.timePeriodSeconds = _seconds;
    _pred.payoutPercentage = _percentage;
  }

  function setWagerToken(address _token) external onlyOwner {
    smol = _token;
    smolContract = ISmoltingInu(_token);
  }

  function setRoundIdStartOffset(uint80 _offset) external onlyOwner {
    require(_offset > 0, 'must be at least an offset of 1 round');
    roundIdStartOffset = _offset;
  }

  function addPriceFeed(address _proxy) external onlyOwner {
    for (uint256 i = 0; i < validPriceFeedProxies.length; i++) {
      if (validPriceFeedProxies[i] == _proxy) {
        require(false, 'price feed already in feed list');
      }
    }
    isValidPriceFeedProxy[_proxy] = true;
    validPriceFeedProxies.push(_proxy);
  }

  function removePriceFeed(address _proxy) external onlyOwner {
    for (uint256 i = 0; i < validPriceFeedProxies.length; i++) {
      if (validPriceFeedProxies[i] == _proxy) {
        delete isValidPriceFeedProxy[_proxy];
        validPriceFeedProxies[i] = validPriceFeedProxies[
          validPriceFeedProxies.length - 1
        ];
        validPriceFeedProxies.pop();
        break;
      }
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV2V3Interface.sol';

/**
 * @dev Interface for chainlink feed proxy, that contains info
 * about all aggregators for data feed
 */

interface AggregatorProxy is AggregatorV2V3Interface {
  function aggregator() external view returns (address);

  function phaseId() external view returns (uint16);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/interfaces/IERC20.sol';

/**
 * @dev SmoltingInu token interface
 */

interface ISmoltingInu is IERC20 {
  function decimals() external view returns (uint8);

  function gameMint(address _user, uint256 _amount) external;

  function gameBurn(address _user, uint256 _amount) external;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract SmolGame is Ownable {
  address payable public treasury;
  uint256 public serviceFeeWei;

  function _payServiceFee() internal {
    if (serviceFeeWei > 0) {
      require(msg.value >= serviceFeeWei, 'not able to pay service fee');
      address payable _treasury = treasury == address(0)
        ? payable(owner())
        : treasury;
      (bool success, ) = _treasury.call{ value: serviceFeeWei }('');
      require(success, 'could not pay service fee');
    }
  }

  function setTreasury(address _treasury) external onlyOwner {
    treasury = payable(_treasury);
  }

  function setServiceFeeWei(uint256 _feeWei) external onlyOwner {
    serviceFeeWei = _feeWei;
  }

  function withdrawTokens(address _tokenAddy, uint256 _amount)
    external
    onlyOwner
  {
    IERC20 _token = IERC20(_tokenAddy);
    _amount = _amount > 0 ? _amount : _token.balanceOf(address(this));
    require(_amount > 0, 'make sure there is a balance available to withdraw');
    _token.transfer(owner(), _amount);
  }

  function withdrawETH(uint256 _amountWei) external onlyOwner {
    _amountWei = _amountWei == 0 ? address(this).balance : _amountWei;
    payable(owner()).call{ value: _amountWei }('');
  }

  receive() external payable {}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AggregatorInterface.sol";
import "./AggregatorV3Interface.sol";

interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorInterface {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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