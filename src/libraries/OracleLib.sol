// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import { AggregatorV3Interface } from '@chainlink/contracts/v0.8/interfaces/AggregatorV3Interface.sol';

/** 
* @title OracleLib
* @notice This library is used to check the Chainlink Oracle for stale data.
* If a price is stale, functions will revert, and render the DSCEngine unusable - this is by design.
* We want the DSCEngine to freeze if prices become stale.
*
* If the Chainlink network fails and you have funds locked in the protocol, the protocol will freeze.
*/
library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    /**
    * @notice Checks if the latest round data from the Chainlink oracle is stale.
    * @param chainLinkFeed The Chainlink AggregatorV3Interface.
    * @return roundId The round ID.
    * @return answer The latest price answer.
    * @return startedAt The timestamp of when the round started.
    * @return updatedAt The timestamp of when the round was last updated.
    * @return answeredInRound The round ID in which the answer was computed.
    */
    function staleCheckLatestRoundData(AggregatorV3Interface chainLinkFeed) public view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = chainLinkFeed.latestRoundData();
        verifyChainLinkFeedAttributes(roundId, updatedAt, answeredInRound);
        verifySecondsSinceTimeStamp(updatedAt);
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    /**
    * @notice Verifies the attributes of the Chainlink feed to ensure they are not stale.
    * @param roundId The round ID.
    * @param updatedAt The timestamp of when the round was last updated.
    * @param answeredInRound The round ID in which the answer was computed.
    */
    function verifyChainLinkFeedAttributes(uint80 roundId, uint256 updatedAt, uint80 answeredInRound) private pure {
        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }
    }

    /**
    * @notice Verifies if the timestamp since the last update exceeds the timeout.
    * @param updatedAt The timestamp of when the round was last updated.
    */
    function verifySecondsSinceTimeStamp(uint256 updatedAt) private view {
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) {
            revert OracleLib__StalePrice();
        }
    }

    /**
    * @notice Returns the timeout value.
    * @return The timeout value in seconds.
    */
    function getTimeout() public pure returns (uint256) {
        return TIMEOUT;
    }
}