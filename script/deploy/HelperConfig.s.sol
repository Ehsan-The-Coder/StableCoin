// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {DeployMockV3Aggregator} from "./mocks/DeployMockV3Aggregator.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

error HelperConfig__ChainIdNotAvailable(uint256 chainId);

contract HelperConfig is Script {
    NetworkConfig activeNetworkConfig;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address[] token;
        address[] priceFeed;
        uint256 deployerKey;
    }

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getMainnetEthConfig();
        } else if (block.chainid == 31337) {
            activeNetworkConfig = getAnvilEthConfig();
        } else {
            revert HelperConfig__ChainIdNotAvailable(block.chainid);
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        // DAI
        // USDC
        address[] memory tokens = new address[](2);
        tokens[0] = 0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6;
        tokens[1] = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
        priceFeeds[1] = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

        networkConfig = NetworkConfig({
            token: tokens,
            priceFeed: priceFeeds,
            deployerKey: vm.envUint("METAMASK_PRIVATE_KEY_1")
        });
    }

    function getMainnetEthConfig()
        public
        view
        returns (NetworkConfig memory networkConfig)
    {
        // DAI
        // USDC
        address[] memory tokens = new address[](2);
        tokens[0] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        tokens[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9;
        priceFeeds[1] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

        networkConfig = NetworkConfig({
            token: tokens,
            priceFeed: priceFeeds,
            deployerKey: vm.envUint("METAMASK_PRIVATE_KEY_1")
        });
    }

    function getAnvilEthConfig()
        public
        returns (NetworkConfig memory networkConfig)
    {
        // DAI
        // USDC
        address[] memory tokens = new address[](2);
        tokens[0] = deployMockERC20();
        tokens[1] = deployMockERC20();
        address[] memory priceFeeds = new address[](2);
        priceFeeds[0] = deployMockPriceFeed();
        priceFeeds[1] = deployMockPriceFeed();

        networkConfig = NetworkConfig({
            token: tokens,
            priceFeed: priceFeeds,
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    function deployMockPriceFeed() private returns (address priceFeed) {
        DeployMockV3Aggregator deployMockV3Aggregator = new DeployMockV3Aggregator();
        priceFeed = deployMockV3Aggregator.run();
    }

    function deployMockERC20() private returns (address token) {
        vm.startBroadcast();
        ERC20Mock mockToken = new ERC20Mock();
        vm.stopBroadcast();
        return token = address(mockToken);
    }

    function getActiveNetworkConfig()
        public
        view
        returns (
            address[] memory token,
            address[] memory priceFeed,
            uint256 deployerKey
        )
    {
        token = activeNetworkConfig.token;
        priceFeed = activeNetworkConfig.priceFeed;
        deployerKey = activeNetworkConfig.deployerKey;

        return (token, priceFeed, deployerKey);
    }
}
