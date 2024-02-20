//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {DeploySCEngine} from "../../script/deploy/DeploySCEngine.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract SCEngineTest is Test, Script {
    //NOTE we use e and a prefix many time this
    //e=expect and a=actual
    //<-----------------------------variable--------------------------->
    SCEngine scEngine;
    StableCoin stableCoin;
    HelperConfig helperConfig;
    //
    //
    //
    // TEST Variable
    uint256 deployerKey;
    uint256 USERS_START_BALANCE = 10 ether;
    uint256 private constant OWNER_INDEX = 0;
    address[10] public players = [
        address(1),
        address(2),
        address(3),
        address(4),
        address(5),
        address(6),
        address(7),
        address(8),
        address(9),
        address(10)
    ];

    //<-----------------------------event--------------------------->

    //<---------------------------------------modifier------------------------------------------>

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    //<---------------------------------------setUp------------------------------------------>
    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (scEngine, stableCoin, helperConfig) = deploySCEngine.run();

        fundUsersAccount();
    }

    //<---------------------------------------helper functions------------------------------------------>
    function fundUsersAccount() private {
        uint256 playersLength = players.length;
        for (
            uint8 playerIndex = 0;
            playerIndex < playersLength;
            playerIndex++
        ) {
            address player = players[playerIndex];
            vm.deal(player, USERS_START_BALANCE);
        }
    }

    //<---------------------------------------test------------------------------------------>
    ////////////////////////////
    ///////Constructor/////////
    //////////////////////////
    function testConstructorShouldRevertIfNoAddressIsPassed() external {
        address[] memory _tokens;
        address[] memory _priceFeed;
        address _stableCoin;
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        SCEngine _SCEngine = new SCEngine(_tokens, _priceFeed, _stableCoin);
    }

    function testConstructorShouldRevertIfDifferentSizeAddressPassed()
        external
    {
        address[] memory _tokens;
        address[] memory _priceFeeds;
        address _stableCoin;
        (_tokens, , ) = helperConfig.getActiveNetworkConfig();
        //token has values but pricefeed lengt is zero

        vm.expectRevert(
            abi.encodeWithSelector(
                SCEngine.SCEngine__LengthOfConstructorValuesNotEqual.selector,
                _tokens.length,
                _priceFeeds.length
            )
        );
        SCEngine _SCEngine = new SCEngine(_tokens, _priceFeeds, _stableCoin);
    }

    function testConstructorShouldRevertIfStableCoinAddressZero() external {
        address[] memory _tokens;
        address[] memory _priceFeeds;
        address _stableCoin = address(0);
        (_tokens, _priceFeeds, ) = helperConfig.getActiveNetworkConfig();

        vm.expectRevert(SCEngine.SCEngine__ZeroAddress.selector);
        SCEngine _SCEngine = new SCEngine(_tokens, _priceFeeds, _stableCoin);
    }

    function testConstructorIsStableCoinSetProperly() external {
        assert(address(stableCoin) == scEngine.getStableCoin());
    }

    function testConstructorIsTokenAndPriceFeedSetProperly() external {
        address[] memory eTokens;
        address[] memory ePriceFeeds;
        (eTokens, ePriceFeeds, ) = helperConfig.getActiveNetworkConfig();
        address[] memory aTokens = scEngine.getTokens();
        console.log(aTokens.length);
        for (uint256 index = 0; index < eTokens.length; index++) {
            assert(eTokens[index] == aTokens[index]);
            assert(ePriceFeeds[index] == scEngine.getPriceFeed(aTokens[index]));
        }
        assert(aTokens.length == eTokens.length);
    }

    ////////////////////////////
    ///////Constant////////////
    //////////////////////////

    ///////////////////////////
    //////enterRaffle/////////
    //////////////////////////
    ////////////////////////////
    //fallbacek and receive////
    //////////////////////////

    ////////////////////////////
    //////checkUpkeep//////////
    //////////////////////////

    ////////////////////////////
    //////performUpkeep////////
    //////////////////////////

    ////////////////////////////
    /////fulfillRandomWords////
    //////////////////////////
}
