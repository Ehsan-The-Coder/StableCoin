// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "./src/MockV3Aggregator.sol";

contract DeployMockV3Aggregator is Script {
    uint8 private constant DECIMALS = 8;
    int256 private constant INITIAL_ANSWER = 999766070000000000;

    function run() external returns (address priceFeed) {
        vm.startBroadcast();
        priceFeed = address(new MockV3Aggregator(DECIMALS, INITIAL_ANSWER));
        vm.stopBroadcast();
    }
}
