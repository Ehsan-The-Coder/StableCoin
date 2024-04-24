// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {DeploySCEngine} from "../../script/deploy/DeploySCEngine.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import {StdInvariant} from "forge-std/StdInvariant.sol";

contract Handler is Test {
    SCEngine scEngine;
    StableCoin stableCoin;
    uint256 MAX_DEPOSIT_QUANTITY = type(uint96).max;
    address[] msgSenders;

    constructor(SCEngine _scEngine, StableCoin _stableCoin) {
        scEngine = _scEngine;
        stableCoin = _stableCoin;
    }

    function depositCollataral(
        uint256 collateralSeed,
        uint256 collateralQuantity
    ) public {
        collateralQuantity = bound(collateralQuantity, 1, MAX_DEPOSIT_QUANTITY);
        address collateralAddress = _getCollateralAddressFromSeed(
            collateralSeed
        );
        address msgSender = msg.sender;
        msgSenders.push(msgSender);
        //
        vm.startPrank(msgSender);
        _mintAndApproveTokens(
            collateralAddress,
            msg.sender,
            collateralQuantity,
            address(scEngine)
        );
        scEngine.depositCollataral(collateralAddress, collateralQuantity);
        vm.stopPrank();
    }

    function redeemCollateral(
        uint256 collateralSeed,
        uint256 collateralQuantity
    ) public {
        address msgSender = _getUserFromSeed(collateralSeed);
        address collateralAddress = _getCollateralAddressFromSeed(
            collateralSeed
        );

        (uint256 totalScMinted, uint256 collateralValueInUsd) = scEngine
            .getAccountInformation(msgSender);

        int256 ramainingValueInUSD = (int256(collateralValueInUsd) / 2) -
            int256(totalScMinted);
        if (ramainingValueInUSD < 1) {
            return;
        }

        uint256 maxTokenToRedeem = scEngine.getTokenAmountFromUsd(
            collateralAddress,
            uint256(ramainingValueInUSD)
        );
        uint256 userBalance = scEngine.getDepositerCollateralBalance(
            msgSender,
            collateralAddress
        );
        if (userBalance == 0) {
            return;
        }
        if (maxTokenToRedeem > userBalance) {
            maxTokenToRedeem = userBalance;
        }
        if (maxTokenToRedeem < 105) {
            return;
        } else {
            maxTokenToRedeem -= 100;
        }
        collateralQuantity = bound(collateralQuantity, 1, maxTokenToRedeem);
        vm.startPrank(msgSender);

        scEngine.redeemCollateral(collateralAddress, collateralQuantity);
        vm.stopPrank();
    }

    function mintSC(uint256 seed, uint256 quantity) public {
        address msgSender = _getUserFromSeed(seed);
        (uint256 totalScMinted, uint256 collateralValueInUsd) = scEngine
            .getAccountInformation(msgSender);

        int256 maxScToMint = (int256(collateralValueInUsd) / 2) -
            int256(totalScMinted);
        if (maxScToMint < 2) {
            return;
        }
        quantity = bound(quantity, 1, uint256(maxScToMint));
        vm.startPrank(msgSender);
        scEngine.mintSc(quantity);
        vm.stopPrank();
    }

    function burnSc(uint256 seed, uint256 quantity) public {
        address msgSender = _getUserFromSeed(seed);
        uint256 userBalance = scEngine.getMinterMintBalance(msgSender);
        if (userBalance < 2) {
            return;
        }
        quantity = bound(quantity, 1, userBalance);
        vm.startPrank(msgSender);
        IERC20(stableCoin).approve(address(scEngine), quantity);
        scEngine.burnSc(quantity);
        vm.stopPrank();
    }

    //<----------------------------------------------Helper Functions----------------------------------------->
    function _mintAndApproveTokens(
        address token,
        address user,
        uint256 quantity,
        address approveTo
    ) private {
        deal(token, user, quantity, true);
        IERC20(token).approve(approveTo, quantity);
    }

    function _getCollateralAddressFromSeed(
        uint256 collateralSeed
    ) private view returns (address token) {
        address[] memory tokens = scEngine.getTokens();
        uint256 tokenIndex = collateralSeed % tokens.length;
        token = tokens[tokenIndex];
    }

    function _getUserFromSeed(
        uint256 userSeed
    ) private view returns (address msgSender) {
        if (msgSenders.length == 0) {
            msgSender = address(1);
        } else {
            uint256 userIndex = userSeed % msgSenders.length;
            msgSender = msgSenders[userIndex];
        }
    }
}
