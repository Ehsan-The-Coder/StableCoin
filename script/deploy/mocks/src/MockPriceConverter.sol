// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MockPriceConverter {
    //<----------------------------state variable---------------------------->
    uint64 private constant TOTAL_DECIMALS = 18;
    uint256 private constant BASE_VALUE = 10;
    uint256 private constant PRECISION = 1e18;

    //<----------------------------custom errors---------------------------->
    error MockPriceConverter__RevertedThePriceFeed(
        address priceFeed,
        bytes reason
    );
    error MockPriceConverter__TotalAmountIsZero(address priceFeed);

    //<----------------------------functions---------------------------->
    /**
     * @param priceFeed passing the price feed address
     * @return price of specific token with 18 decimals
     * @notice through error if the price feed contract is not availabe on Chainlink
     */
    function getPrice(address priceFeed) internal view returns (uint256 price) {
        //https://docs.chain.link/data-feeds/using-data-feeds
        //catching the error if the address passed is not valid
        try AggregatorV3Interface(priceFeed).latestRoundData() returns (
            uint80 /*roundID*/,
            int256 answer,
            uint256 /*startedAt*/,
            uint256 /*timeStamp*/,
            uint80 /*answeredInRound*/
        ) {
            //different price feed have different decimals
            //so making them same to 18 decimals
            uint64 additionalFeedPrecision = TOTAL_DECIMALS -
                AggregatorV3Interface(priceFeed).decimals();
            if (additionalFeedPrecision > 0) {
                price = uint256(answer) * BASE_VALUE ** additionalFeedPrecision;
            } else {
                price = uint256(answer);
            }
        } catch (bytes memory reason) {
            revert MockPriceConverter__RevertedThePriceFeed(priceFeed, reason);
        }
        return price;
    }

    /**
     *
     * @param quantity value/amount you want to convert
     * @param priceFeed address of the chain
     * @return totalAmount
     */
    function getTotalAmount(
        address priceFeed,
        uint256 quantity
    ) internal view returns (uint256 totalAmount) {
        uint256 price = getPrice(priceFeed);
        if (price > 0) {
            totalAmount = ((price * quantity) / PRECISION);
        }
        if (totalAmount == 0) {
            revert MockPriceConverter__TotalAmountIsZero(priceFeed);
        }
    }
}
