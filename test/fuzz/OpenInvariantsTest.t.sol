// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// import {Test} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {SCEngine} from "../../src/SCEngine.sol";
// import {StableCoin} from "../../src/StableCoin.sol";
// import {DeploySCEngine} from "../../script/deploy/DeploySCEngine.s.sol";
// import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract OpenInvariantsTest is StdInvariant, Test {
//     SCEngine scEngine;
//     StableCoin stableCoin;
//     HelperConfig helperConfig;

//     address[] s_tokens;
//     address[] s_priceFeeds;

//     function setUp() external {
//         DeploySCEngine deploySCEngine = new DeploySCEngine();
//         (scEngine, stableCoin, helperConfig, ) = deploySCEngine.run();

//         (s_tokens, s_priceFeeds, ) = helperConfig.getActiveNetworkConfig();
//         targetContract(address(scEngine));
//     }

//     function invariant_systemMustHaveMoreCollateralThanMintedCoins()
//         public
//         view
//     {
//         uint256 totalCollateralValueInUsd = _getTotalCollateralValueInUsd();
//         uint256 totalStableCoinsMinted = stableCoin.totalSupply();
//         if (totalCollateralValueInUsd == 0 && totalStableCoinsMinted == 0) {
//             return;
//         } else {
//             assert(totalCollateralValueInUsd > totalStableCoinsMinted);
//         }
//     }

//     function _getTotalCollateralValueInUsd()
//         private
//         view
//         returns (uint256 totalCollateralValueInUsd)
//     {
//         uint256 tLength = s_tokens.length;
//         for (uint256 tIndex = 0; tIndex < tLength; tIndex++) {
//             address token = s_tokens[tIndex];
//             address priceFeed = s_priceFeeds[tIndex];

//             uint256 balanceOfToken = IERC20(token).balanceOf(address(scEngine));
//             uint256 balanceValueInUSD = scEngine.getTotalAmount(
//                 priceFeed,
//                 balanceOfToken
//             );

//             totalCollateralValueInUsd += balanceValueInUSD;
//         }
//     }
// }
