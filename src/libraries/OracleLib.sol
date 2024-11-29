//SDPX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__PriceFeedTimeout();
    uint256 public constant TIMEOUT = 3 hours;

    function stalechecklatestrounddata(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint80, int256, uint256, uint256, uint80) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        if (block.timestamp - timeStamp > TIMEOUT) {
            revert OracleLib__PriceFeedTimeout();
        }

        return (roundID, price, startedAt, timeStamp, answeredInRound);
    }
}
