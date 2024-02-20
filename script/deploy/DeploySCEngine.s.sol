// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {Script} from "forge-std/Script.sol";
import {DeployMockPriceConverter} from "./mocks/DeployMockPriceConverter.s.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {MockPriceConverter} from "./mocks/src/MockPriceConverter.sol";

contract DeploySCEngine is Script {
    address[] token;
    address[] priceFeed;

    uint256 deployerKey;

    function run() external returns (SCEngine, StableCoin, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (token, priceFeed, deployerKey) = helperConfig.getActiveNetworkConfig();
        //
        //get MockPriceConverter address
        DeployMockPriceConverter deployMockPriceConverter = new DeployMockPriceConverter();
        MockPriceConverter mockPriceConverter = deployMockPriceConverter.run();
        //
        //
        //deploy stable coin and pass address to engine
        vm.startBroadcast();
        StableCoin stableCoin = new StableCoin();
        SCEngine scEngine = new SCEngine(token, priceFeed, address(stableCoin));
        stableCoin.transferOwnership(address(scEngine));
        vm.stopBroadcast();
        //
        //
        //
        return (scEngine, stableCoin, helperConfig);
    }
}
