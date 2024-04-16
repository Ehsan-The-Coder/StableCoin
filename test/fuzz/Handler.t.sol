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
}
