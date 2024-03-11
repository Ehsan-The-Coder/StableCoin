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
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockPriceConverter} from "../../script/deploy/mocks/src/MockPriceConverter.sol";

contract SCEngineTest is Test, Script {
    //NOTE we use e and a prefix many time this
    //e=expect and a=actual
    //<-----------------------------variable--------------------------->
    SCEngine scEngine;
    StableCoin stableCoin;
    HelperConfig helperConfig;
    MockPriceConverter mockPriceConverter;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant QUANTITY_TO_DEPOSIT = 500 * PRECISION;
    uint256 private constant QUANTITY_TO_REDEEM = 200 * PRECISION;
    uint256 private constant QUANTITY_TO_MINT = 100 * PRECISION;
    uint256 private constant QUANTITY_TO_BURN = 10 * PRECISION;

    address[] s_tokens;
    address[] s_priceFeeds;
    address s_stableCoin;
    mapping(address token => address priceFeed) s_tokenPriceFeed;

    //
    //
    //
    // TEST Variable
    uint256 deployerKey;
    uint256 USERS_START_BALANCE = 10 ether;
    uint256 private constant OWNER_INDEX = 0;
    address[10] public users = [
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
    event CollataralDeposited(
        address indexed depositer,
        address indexed tokenCollateralAddress,
        uint256 quantity
    );
    event CollateralRedeemed(
        address indexed from,
        address indexed to,
        address indexed tokenCollateralAddress,
        uint256 amountCollateral
    );
    //<---------------------------------------modifier------------------------------------------>

    modifier skipForkChains() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
    modifier skipLocalChains() {
        if (block.chainid == 31337) {
            return;
        }
        _;
    }

    //<---------------------------------------setUp------------------------------------------>
    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (
            scEngine,
            stableCoin,
            helperConfig,
            mockPriceConverter
        ) = deploySCEngine.run();

        fundUsersAccount();
        setValues();
    }

    //<---------------------------------------helper functions------------------------------------------>
    function fundUsersAccount() private {
        uint256 usersLength = users.length;
        for (uint8 userIndex = 0; userIndex < usersLength; userIndex++) {
            address user = users[userIndex];
            vm.deal(user, USERS_START_BALANCE);
        }
    }

    function setValues() private {
        (s_tokens, s_priceFeeds, ) = helperConfig.getActiveNetworkConfig();
        s_stableCoin = address(stableCoin);
    }

    function burnScMultiple(uint256 quantity) private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address burner = users[userIndex];
            burnScSingle(burner, address(scEngine), quantity);
        }
    }

    function burnScSingle(
        address burner,
        address spender,
        uint256 quantity
    ) private {
        uint256 userBalance = scEngine.getMinterMintBalance(burner);
        uint256 userExpectedBalance = userBalance - quantity;

        uint256 contractBalance = IERC20(stableCoin).balanceOf(address(burner));
        uint256 contractExpectedBalance = contractBalance - quantity;

        vm.startPrank(burner);
        IERC20(stableCoin).approve(spender, quantity);
        scEngine.burnSc(quantity);
        vm.stopPrank();

        uint256 userActualBalance = scEngine.getMinterMintBalance(burner);
        uint256 contractActualBalance = IERC20(stableCoin).balanceOf(
            address(burner)
        );
        assert(userExpectedBalance == userActualBalance);
        assert(contractExpectedBalance == contractActualBalance);
    }

    function redeemCollateralMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address redeemer = users[userIndex];
                address token = s_tokens[tokenIndex];

                redeemCollateralSingle(redeemer, token, QUANTITY_TO_REDEEM);
            }
        }
    }

    function redeemCollateralSingle(
        address redeemer,
        address token,
        uint256 quantity
    ) private {
        uint256 UserCollateral = scEngine.getDepositerCollateralBalance(
            redeemer,
            token
        );
        uint256 UserExpectedCollateral = UserCollateral - quantity;
        uint256 userBalance = IERC20(token).balanceOf(redeemer);
        uint256 userExpectedBalance = userBalance + quantity;
        uint256 contractBalance = IERC20(token).balanceOf(address(scEngine));
        uint256 contractExpectedBalance = contractBalance - quantity;

        vm.startPrank(redeemer);
        scEngine.redeemCollateral(token, quantity);
        vm.stopPrank();

        uint256 UserActualCollateral = scEngine.getDepositerCollateralBalance(
            redeemer,
            token
        );
        uint256 userActualBalance = IERC20(token).balanceOf(redeemer);
        uint256 contractActualBalance = IERC20(token).balanceOf(
            address(scEngine)
        );

        assert(UserExpectedCollateral == UserActualCollateral);
        assert(userExpectedBalance == userActualBalance);
        assert(contractExpectedBalance == contractActualBalance);
    }

    function mintAndApproveTokens(
        address token,
        address to,
        uint256 quantity
    ) private {
        deal(token, to, quantity, false);
        IERC20(token).approve(address(scEngine), quantity);
    }

    function mintScMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address minter = users[userIndex];
            mintScSingle(minter);
        }
    }

    function mintScSingle(address minter) private {
        uint256 quantity = QUANTITY_TO_MINT;
        uint256 userBalance = scEngine.getMinterMintBalance(minter);
        uint256 userExpectedBalance = userBalance + quantity;

        uint256 contractBalance = IERC20(stableCoin).balanceOf(address(minter));
        uint256 contractExpectedBalance = contractBalance + quantity;

        vm.prank(minter);
        scEngine.mintSc(quantity);

        uint256 userActualBalance = scEngine.getMinterMintBalance(minter);
        uint256 contractActualBalance = IERC20(stableCoin).balanceOf(
            address(minter)
        );
        assert(userExpectedBalance == userActualBalance);
        assert(contractExpectedBalance == contractActualBalance);
    }

    function depositCollateralMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address depositer = users[userIndex];
                address token = s_tokens[tokenIndex];
                depositCollateralSingle(depositer, token);
            }
        }
    }

    function depositCollateralSingle(address depositer, address token) private {
        uint256 quantity = QUANTITY_TO_DEPOSIT;
        uint256 userBalance = scEngine.getDepositerCollateralBalance(
            depositer,
            token
        );
        uint256 userPreviousBalance = userBalance + quantity;
        uint256 contractBalance = IERC20(token).balanceOf(address(scEngine));
        uint256 contractPreviousEBalance = contractBalance + quantity;
        vm.startPrank(depositer);
        mintAndApproveTokens(token, depositer, quantity);
        //test event
        vm.expectEmit(true, true, false, false, address(scEngine));
        emit CollataralDeposited(depositer, token, quantity);
        scEngine.depositCollataral(token, quantity);
        vm.stopPrank();

        uint256 userNewBalance = scEngine.getDepositerCollateralBalance(
            depositer,
            token
        );
        uint256 contractNewBalance = IERC20(token).balanceOf(address(scEngine));
        assert(userNewBalance == userPreviousBalance);
        assert(contractNewBalance == contractPreviousEBalance);
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
        new SCEngine(_tokens, _priceFeed, _stableCoin);
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
        new SCEngine(_tokens, _priceFeeds, _stableCoin);
    }

    function testConstructorShouldRevertIfStableCoinAddressZero() external {
        address _stableCoin = address(0);

        vm.expectRevert(SCEngine.SCEngine__ZeroAddress.selector);
        new SCEngine(s_tokens, s_priceFeeds, _stableCoin);
    }

    function testConstructorIsStableCoinSetProperly() external view {
        assert(s_stableCoin == scEngine.getStableCoin());
    }

    function testConstructorIsTokenAndPriceFeedSetProperly() external view {
        address[] memory aTokens = scEngine.getTokens();
        for (uint256 index = 0; index < s_tokens.length; index++) {
            assert(s_tokens[index] == aTokens[index]);
            assert(
                s_priceFeeds[index] == scEngine.getPriceFeed(aTokens[index])
            );
        }
        assert(s_tokens.length == aTokens.length);
    }

    ////////////////////////////
    ///////Constant////////////
    //////////////////////////

    function testConstant() external view {
        assert(LIQUIDATION_THRESHOLD == scEngine.getLiquidationThreshold());
        assert(LIQUIDATION_PRECISION == scEngine.getLiquidationPrecision());
        assert(MIN_HEALTH_FACTOR == scEngine.getMinimumHealthFactor());
        assert(PRECISION == scEngine.getPrecision());
    }

    ////////////////////////////////
    //////depositCollataral////////
    ///////////////////////////////
    function testShouldRevertDepositCollataralIfTokenNotListed() external {
        address _token = address(scEngine);
        //this is the SCEngine address not the token address
        vm.expectRevert(
            abi.encodeWithSelector(
                SCEngine.SCEngine__TokenNotListed.selector,
                _token
            )
        );
        scEngine.depositCollataral(_token, QUANTITY_TO_DEPOSIT);
    }

    function testShouldRevertDepositCollataralIfQuantityIsZero() external {
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        scEngine.depositCollataral(s_tokens[0], 0);
    }

    function testShouldRevertDepositCollataralIfTransferFromFailed() external {
        vm.expectRevert();
        scEngine.depositCollataral(s_tokens[0], QUANTITY_TO_DEPOSIT);
    }

    function testDepositCollataral() external {
        depositCollateralMultiple();
    }

    ////////////////////////////
    ///////////mintSc//////////
    //////////////////////////
    function testShouldRevertMintScIfHealthFactorIsBroken() public {
        uint256 quantity = QUANTITY_TO_DEPOSIT;
        address user = users[0];
        uint256 expectedUserHealthFactor = 0;
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                SCEngine.SCEngine__BreaksHealthFactor.selector,
                expectedUserHealthFactor
            )
        );
        scEngine.mintSc(quantity);
    }

    function testMintSc() public {
        depositCollateralMultiple();
        mintScMultiple();
    }

    //////////////////////////////////////////////////
    ///////////Deposit Collateral And MintSc//////////
    /////////////////////////////////////////////////
    function testDepositAndMint() external {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address depositer = users[userIndex];
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address token = s_tokens[tokenIndex];
                vm.startPrank(depositer);
                mintAndApproveTokens(token, depositer, QUANTITY_TO_DEPOSIT);
                scEngine.depositCollataralAndMintSc(
                    token,
                    QUANTITY_TO_DEPOSIT,
                    QUANTITY_TO_MINT
                );
                vm.stopPrank();
            }
        }
    }

    ////////////////////////////////
    /////////HealthFactor//////////
    ///////////////////////////////
    function testUserHealthFactorWhenNoDepoistAndMintSc() public view {
        address user = users[0];
        uint256 userHealthFactor = scEngine.getUserHealthFactor(user);
        assert(userHealthFactor == type(uint256).max);
    }

    function testUserHealthFactorWhenNoMintSc() public {
        address user = users[0];
        address token = s_tokens[0];
        depositCollateralSingle(user, token);
        uint256 userHealthFactor = scEngine.getUserHealthFactor(user);
        assert(userHealthFactor == type(uint256).max);
    }

    function testUserHealthFactorWhenDepoistAndMintSc() public {
        depositCollateralMultiple();
        mintScMultiple();

        uint256 usersLength = users.length;
        for (uint8 userIndex = 0; userIndex < usersLength; userIndex++) {
            address user = users[userIndex];
            (uint256 totalScMinted, uint256 collateralValueInUsd) = scEngine
                .getAccountInformation(user);
            uint256 expectedUserHealthFactor = scEngine
                .calculateUserHealthFactor(totalScMinted, collateralValueInUsd);
            uint256 actualUserHealthFactor = scEngine.getUserHealthFactor(user);

            assert(expectedUserHealthFactor == actualUserHealthFactor);
        }
    }

    ////////////////////////////
    //////Price////////////////
    //////////////////////////
    function testGetPrice() public view {
        for (uint256 index = 0; index < s_priceFeeds.length; index++) {
            address priceFeed = s_priceFeeds[index];
            uint256 expectedPrice = mockPriceConverter.getPrice(priceFeed);
            uint256 actualPrice = scEngine.getPrice(priceFeed);
            assert(expectedPrice == actualPrice);
        }
    }

    function testGetTotalAmount() public view {
        uint256 quantity = QUANTITY_TO_DEPOSIT;
        for (uint256 index = 0; index < s_priceFeeds.length; index++) {
            address priceFeed = s_priceFeeds[index];
            uint256 expectedPrice = mockPriceConverter.getTotalAmount(
                priceFeed,
                quantity
            );
            uint256 actualPrice = scEngine.getTotalAmount(priceFeed, quantity);
            assert(expectedPrice == actualPrice);
        }
    }

    function testGetTokenAmountFromUsd() public view {
        for (uint256 index = 0; index < s_tokens.length; index++) {
            address token = s_tokens[index];
            address priceFeed = s_priceFeeds[index];
            uint256 price = mockPriceConverter.getPrice(priceFeed);
            uint256 expectedPrice = (QUANTITY_TO_DEPOSIT *
                scEngine.getPrecision()) / price;

            uint256 actualPrice = scEngine.getTokenAmountFromUsd(
                token,
                QUANTITY_TO_DEPOSIT
            );

            assert(expectedPrice == actualPrice);
        }
    }

    ////////////////////////////
    ///////Burn////////////////
    //////////////////////////
    function revertIfBurnQuantityIsZero() public {
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        scEngine.burnSc(0);
    }

    function revertIfTransferFromFailed() public {
        vm.expectRevert();
        scEngine.burnSc(QUANTITY_TO_BURN);
    }

    function testBurn() external {
        depositCollateralMultiple();
        mintScMultiple();
        burnScMultiple(QUANTITY_TO_BURN);
    }

    ////////////////////////////
    ///RedeemCollateralForSc///
    ///////////////////////////
    function testRedeemCollarteralShouldRevertIfQuantityZero() external {
        uint256 tokenIndex = 0;
        address token = s_tokens[tokenIndex];

        uint256 quantity = 0;
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        scEngine.redeemCollateral(token, quantity);
    }

    function testRedeemCollarteralShouldRevertIfTokenNotExisted() external {
        address token = address(0);

        uint256 quantity = QUANTITY_TO_REDEEM;
        vm.expectRevert(
            abi.encodeWithSelector(
                SCEngine.SCEngine__TokenNotListed.selector,
                token
            )
        );
        scEngine.redeemCollateral(token, quantity);
    }

    function testRedeemCollarteralShouldRevertIfBreaksHealthFactor() external {
        depositCollateralMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        mintScMultiple();
        //expect revert as redeeming same amount of token we deposit but we already minted StableCoin
        uint256 quantity = QUANTITY_TO_DEPOSIT;
        uint256 tokenIndex = 0;
        address token = s_tokens[tokenIndex];

        vm.expectRevert();
        vm.prank(address(1));
        scEngine.redeemCollateral(token, quantity);
    }

    function testRedeemCollarteral() external {
        depositCollateralMultiple();
        mintScMultiple();
        redeemCollateralMultiple();
    }
}
