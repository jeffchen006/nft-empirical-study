// SPDX-License-Identifier: MIT
// Kovan
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceConsumerV3 {
  AggregatorV3Interface internal priceFeed;

  // initializes an interface object named priceFeed that uses AggregatorV3Interface and connects specifically to a proxy aggregator contract deployed at 0x9326BFA02ADD2366b30bacB125260Af641031331 on Kovan testnet
  constructor() {
    priceFeed = AggregatorV3Interface(0x9326BFA02ADD2366b30bacB125260Af641031331);
  }

  function getLatestPrice() public view returns (int256) {
    (, int256 price, , , ) = priceFeed.latestRoundData();
    return price;
  }
}

// (
//   /*uint80 roundID*/,
//   int price,
//   /*uint startedAt*/,
//   /*uint timeStamp*/,
//   /*uint80 answeredInRound*/
// ) = priceFeed.latestRoundData();

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