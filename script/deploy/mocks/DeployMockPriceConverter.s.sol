// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {MockPriceConverter} from "./src/MockPriceConverter.sol";

contract DeployMockPriceConverter is Script {
    function run() external returns (MockPriceConverter) {
        vm.startBroadcast();
        MockPriceConverter mockPriceConverter = new MockPriceConverter();
        vm.stopBroadcast();
        return mockPriceConverter;
    }
}
