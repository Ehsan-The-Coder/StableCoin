// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {DeploySCEngine} from "../../script/deploy/DeploySCEngine.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariants is StdInvariant, Test {
    SCEngine scEngine;
    StableCoin stableCoin;
    HelperConfig helperConfig;
    Handler handler;

    address[] s_tokens;
    address[] s_priceFeeds;

    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, stableCoin, helperConfig, ) = deploySCEngine.run();

        (s_tokens, s_priceFeeds, ) = helperConfig.getActiveNetworkConfig();
        // targetContract(address(scEngine));

        handler = new Handler(scEngine, stableCoin);
        targetContract(address(handler));
    }

    function invariant_systemMustHaveMoreCollateralThanMintedCoins()
        public
        view
    {
        uint256 totalCollateralValueInUsd = _getTotalCollateralValueInUsd();
        uint256 totalStableCoinsMinted = stableCoin.totalSupply();
        if (totalCollateralValueInUsd == 0 && totalStableCoinsMinted == 0) {
            return;
        } else {
            assert(totalCollateralValueInUsd > totalStableCoinsMinted);
        }
        if (totalStableCoinsMinted != 0) {
            console.log(
                "<------------------------------------------------------------------------------>"
            );

            console.log("totalStableCoinsMinted   ", totalStableCoinsMinted);
            console.log("totalCollateralValueInUsd", totalCollateralValueInUsd);
        }
    }

    function invariant_publicViewFunctionsShouldNeverRevert() public view {
        uint256 usdAmountInWei = 3203434;
        uint256 quantity = 9034254465;
        uint256 tLength = s_tokens.length;
        address token;
        address priceFeed;

        for (uint256 tIndex = 0; tIndex < tLength; tIndex++) {
            token = s_tokens[tIndex];
            priceFeed = s_priceFeeds[tIndex];
            scEngine.getTokenAmountFromUsd(token, usdAmountInWei);
        }

        scEngine.getUserHealthFactor(msg.sender);
        (uint256 totalScMinted, uint256 collateralValueInUsd) = scEngine
            .getAccountInformation(msg.sender);
        scEngine.calculateUserHealthFactor(totalScMinted, collateralValueInUsd);
        scEngine.getStableCoin();
        scEngine.getTokens();
        scEngine.getPriceFeed(token);
        scEngine.getPrice(priceFeed);
        scEngine.getTotalAmount(priceFeed, quantity);
        scEngine.getLiquidationThreshold();
        scEngine.getMinimumHealthFactor();
        scEngine.getPrecision();
        scEngine.getLiquidationPrecision();
        scEngine.getDepositerCollateralBalance(msg.sender, token);
        scEngine.getMinterMintBalance(msg.sender);
    }

    function _getTotalCollateralValueInUsd()
        private
        view
        returns (uint256 totalCollateralValueInUsd)
    {
        uint256 tLength = s_tokens.length;
        for (uint256 tIndex = 0; tIndex < tLength; tIndex++) {
            address token = s_tokens[tIndex];
            address priceFeed = s_priceFeeds[tIndex];

            uint256 balanceOfToken = IERC20(token).balanceOf(address(scEngine));
            uint256 balanceValueInUSD = scEngine.getTotalAmount(
                priceFeed,
                balanceOfToken
            );

            totalCollateralValueInUsd += balanceValueInUSD;
        }
    }
}
