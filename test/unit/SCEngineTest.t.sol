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
import {MockV3Aggregator} from "../../script/deploy/mocks/src/MockV3Aggregator.sol";
import {MockMoreDebtStableCoin} from "../../script/deploy/mocks/src/MockMoreDebtStableCoin.sol";
import {MockFailedTransferFrom} from "../../script/deploy/mocks/src/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../../script/deploy/mocks/src/MockFailedTransfer.sol";
import {MockFailedMintStableCoin} from "../../script/deploy/mocks/src/MockFailedMintStableCoin.sol";

contract SCEngineTest is Test, Script {
    //NOTE we use e and a prefix many time this
    //e=expect and a=actual
    //<-----------------------------variable--------------------------->
    SCEngine scEngine;
    SCEngine mockSCEngine;
    StableCoin stableCoin;
    HelperConfig helperConfig;
    MockPriceConverter mockPriceConverter;
    MockMoreDebtStableCoin mockMoreDebtStableCoin;
    MockFailedTransferFrom mockFailedTransferFrom;
    MockFailedTransfer mockFailedTransfer;
    MockFailedMintStableCoin mockFailedMintStableCoin;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant QUANTITY_TO_DEPOSIT = 500 * PRECISION;
    uint256 private constant QUANTITY_TO_REDEEM = 200 * PRECISION;
    uint256 private constant QUANTITY_TO_MINT = 100 * PRECISION;
    uint256 private constant QUANTITY_TO_BURN = 10 * PRECISION;
    uint256 private constant QUANTITY_TO_LIQUIDATE = 10 * PRECISION;
    uint256 private constant LIQUIDATION_BONUS = 10;

    address[] s_tokens;
    address[] s_priceFeeds;
    address s_stableCoin;
    uint256 liquidaterIndex = 0;
    address liquidater;

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
    uint256 usersLength;
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

        _fundUsersAccount();
        _setValues();
    }

    //<---------------------------------------helper functions------------------------------------------>
    function _fundUsersAccount() private {
        usersLength = users.length;
        for (uint8 userIndex = 0; userIndex < usersLength; userIndex++) {
            address user = users[userIndex];
            vm.deal(user, USERS_START_BALANCE);
        }
        liquidater = users[liquidaterIndex];
    }

    function _setValues() private {
        (s_tokens, s_priceFeeds, ) = helperConfig.getActiveNetworkConfig();
        s_stableCoin = address(stableCoin);
    }

    function _burnScMultiple(uint256 quantity) private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address burner = users[userIndex];
            _burnScSingle(burner, address(scEngine), quantity);
        }
    }

    function _burnScSingle(
        address burner,
        address spender,
        uint256 quantity
    ) private {
        uint256 userBalance = scEngine.getMinterMintBalance(burner);
        uint256 userExpectedBalance = userBalance - quantity;
        uint256 userHealthFactor = scEngine.getUserHealthFactor(burner);

        uint256 contractBalance = IERC20(stableCoin).balanceOf(address(burner));
        uint256 contractExpectedBalance = contractBalance - quantity;
        uint256 expectedTotalSupply = IERC20(stableCoin).totalSupply() -
            quantity;

        vm.startPrank(burner);
        IERC20(stableCoin).approve(spender, quantity);
        scEngine.burnSc(quantity);
        vm.stopPrank();
        userHealthFactor = scEngine.getUserHealthFactor(burner);
        uint256 userActualBalance = scEngine.getMinterMintBalance(burner);
        uint256 contractActualBalance = IERC20(stableCoin).balanceOf(
            address(burner)
        );
        uint256 actualTotalSupply = IERC20(stableCoin).totalSupply();

        assert(userExpectedBalance == userActualBalance);
        assert(contractExpectedBalance == contractActualBalance);
        assert(expectedTotalSupply == actualTotalSupply);
    }

    function _redeemCollateralMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address redeemer = users[userIndex];
                address token = s_tokens[tokenIndex];

                _redeemCollateralSingle(redeemer, token, QUANTITY_TO_REDEEM);
            }
        }
    }

    function _redeemCollateralForScMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address redeemer = users[userIndex];
                address token = s_tokens[tokenIndex];

                _redeemCollateralForScSingle(
                    redeemer,
                    token,
                    QUANTITY_TO_REDEEM,
                    QUANTITY_TO_BURN
                );
            }
        }
    }

    function _redeemCollateralForScSingle(
        address redeemer,
        address token,
        uint256 quantityToRedeem,
        uint256 quantityToBurn
    ) private {
        uint256 UserCollateral = scEngine.getDepositerCollateralBalance(
            redeemer,
            token
        );
        uint256 UserExpectedCollateral = UserCollateral - quantityToRedeem;
        uint256 userBalance = IERC20(token).balanceOf(redeemer);
        uint256 userExpectedBalance = userBalance + quantityToRedeem;
        uint256 contractBalance = IERC20(token).balanceOf(address(scEngine));
        uint256 contractExpectedBalance = contractBalance - quantityToRedeem;

        vm.startPrank(redeemer);
        IERC20(stableCoin).approve(address(scEngine), quantityToBurn);
        vm.expectEmit(true, true, true, false, address(scEngine));
        emit CollateralRedeemed(redeemer, redeemer, token, quantityToRedeem);
        scEngine.redeemCollateralForSc(token, quantityToRedeem, quantityToBurn);
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

    function _redeemCollateralSingle(
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
        vm.expectEmit(true, true, true, false, address(scEngine));
        emit CollateralRedeemed(redeemer, redeemer, token, quantity);
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

    function _mintAndApproveTokens(
        address token,
        address user,
        uint256 quantity,
        address approveTo
    ) private {
        deal(token, user, quantity, false);
        IERC20(token).approve(approveTo, quantity);
    }

    function _mintScMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address minter = users[userIndex];
            _mintScSingle(minter, QUANTITY_TO_MINT);
        }
    }

    function _mintScSingle(address minter, uint256 quantity) private {
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

    function _depositCollateralMultiple() private {
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address depositer = users[userIndex];
                address token = s_tokens[tokenIndex];
                _depositCollateralSingle(depositer, token, QUANTITY_TO_DEPOSIT);
            }
        }
    }

    function _depositCollateralSingle(
        address depositer,
        address token,
        uint256 quantity
    ) private {
        uint256 userBalance = scEngine.getDepositerCollateralBalance(
            depositer,
            token
        );
        uint256 userPreviousBalance = userBalance + quantity;
        uint256 contractBalance = IERC20(token).balanceOf(address(scEngine));
        uint256 contractPreviousEBalance = contractBalance + quantity;
        vm.startPrank(depositer);
        _mintAndApproveTokens(token, depositer, quantity, address(scEngine));
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

    function testConstructorShouldRevertIfTokenIsZero() external {
        s_tokens = [address(0)];
        s_priceFeeds = [s_priceFeeds[0]];
        vm.expectRevert(SCEngine.SCEngine__ZeroAddress.selector);
        new SCEngine(s_tokens, s_priceFeeds, address(stableCoin));
    }

    function testConstructorShouldRevertIfPriceFeedIsZero() external {
        s_priceFeeds = [address(0), address(0)];
        vm.expectRevert(SCEngine.SCEngine__ZeroAddress.selector);
        new SCEngine(s_tokens, s_priceFeeds, address(stableCoin));
    }

    function testConstructorShouldRevertIfIdenticalAddress() external {
        s_priceFeeds = s_tokens;
        vm.expectRevert(SCEngine.SCEngine__IdenticalTokenAndPriceFeed.selector);
        new SCEngine(s_tokens, s_priceFeeds, address(stableCoin));
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
        _depositCollateralMultiple();
    }

    //setting this as token address MockFailedTransferFrom
    //becuase other have diferent implementations for transferFrom function
    function _setupDeploySCEngineForMockFailedTransferFrom() private {
        mockFailedTransferFrom = new MockFailedTransferFrom();
        address owner = msg.sender;
        s_tokens = [address(mockFailedTransferFrom)];
        s_priceFeeds = [s_priceFeeds[0]];
        vm.prank(owner);
        mockSCEngine = new SCEngine(
            s_tokens,
            s_priceFeeds,
            address(mockFailedTransferFrom)
        );
        mockFailedTransferFrom.transferOwnership(address(mockSCEngine));
    }

    function testShouldRevertDepositCollataralIfTransferFromReturnFalse()
        external
    {
        _setupDeploySCEngineForMockFailedTransferFrom();
        address user = users[1];
        address token = address(mockFailedTransferFrom);
        vm.startPrank(user);
        MockFailedTransferFrom(mockFailedTransferFrom).mint(
            user,
            QUANTITY_TO_DEPOSIT
        );
        MockFailedTransferFrom(mockFailedTransferFrom).approve(
            address(mockSCEngine),
            QUANTITY_TO_DEPOSIT
        );
        vm.expectRevert(SCEngine.SCEngine__TokenTransferFromFailed.selector);
        mockSCEngine.depositCollataral(token, QUANTITY_TO_DEPOSIT);
        vm.stopPrank();
    }

    ////////////////////////////
    ///////////mintSc//////////
    //////////////////////////
    //setting this as token address MockFailedTransfer
    //becuase other have diferent implementations for transfer function
    function _setupDeploySCEngineForMockFailedMintStableCoin() private {
        mockFailedMintStableCoin = new MockFailedMintStableCoin();
        address owner = msg.sender;
        vm.prank(owner);
        mockSCEngine = new SCEngine(
            s_tokens,
            s_priceFeeds,
            address(mockFailedMintStableCoin)
        );
        mockFailedMintStableCoin.transferOwnership(address(mockSCEngine));
    }

    function testShouldRevertMintSCIfMintStableCoinFailed() external {
        _setupDeploySCEngineForMockFailedMintStableCoin();
        address user = users[1];
        address token = s_tokens[0];
        vm.startPrank(user);
        _mintAndApproveTokens(
            token,
            user,
            QUANTITY_TO_DEPOSIT,
            address(mockSCEngine)
        );
        mockSCEngine.depositCollataral(token, QUANTITY_TO_DEPOSIT);
        vm.expectRevert(SCEngine.SCEngine__TokenMintFailed.selector);
        mockSCEngine.mintSc(QUANTITY_TO_MINT);
        vm.stopPrank();
    }

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
        _depositCollateralMultiple();
        _mintScMultiple();
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
                _mintAndApproveTokens(
                    token,
                    depositer,
                    QUANTITY_TO_DEPOSIT,
                    address(scEngine)
                );
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
    /////getAccountInformation//////
    ///////////////////////////////
    function _getUserTotalDepositorValueInUsd(
        address user
    ) private returns (uint256 collateralValueInUsd) {
        address token;
        address priceFeed;
        uint256 quantity;
        for (uint256 tIndex = 0; tIndex < s_tokens.length; tIndex++) {
            token = s_tokens[tIndex];
            priceFeed = s_priceFeeds[tIndex];
            //
            quantity = scEngine.getDepositerCollateralBalance(user, token);
            collateralValueInUsd += scEngine.getTotalAmount(
                priceFeed,
                quantity
            );
        }
    }

    function testGetAccountInformation() external {
        _depositCollateralMultiple();
        _mintScMultiple();
        address user;
        for (uint userIndex = 0; userIndex < usersLength; userIndex++) {
            user = users[userIndex];
            //
            uint256 expectedScMinted = scEngine.getMinterMintBalance(user);
            uint256 expectedCollateralValueInUsd = _getUserTotalDepositorValueInUsd(
                    user
                );
            //
            (
                uint256 actualTotalScMinted,
                uint256 actualCollateralValueInUsd
            ) = scEngine.getAccountInformation(user);
            //
            assert(expectedScMinted == actualTotalScMinted);
            assert(expectedCollateralValueInUsd == actualCollateralValueInUsd);
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
        _depositCollateralSingle(user, token, QUANTITY_TO_DEPOSIT);
        uint256 userHealthFactor = scEngine.getUserHealthFactor(user);
        assert(userHealthFactor == type(uint256).max);
    }

    function testUserHealthFactorWhenDepoistAndMintSc() public {
        _depositCollateralMultiple();
        _mintScMultiple();

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

    function testGetTokenAmountFromUsdShouldReturnZero()
        external
        skipForkChains
    {
        address token = s_tokens[0];
        address priceFeed = s_priceFeeds[0];
        uint expectPrice = 0;
        MockV3Aggregator(priceFeed).updateAnswer(int(expectPrice));
        uint256 actualPrice = scEngine.getTokenAmountFromUsd(
            token,
            QUANTITY_TO_DEPOSIT
        );
        assert(expectPrice == actualPrice);
    }

    function testGetTokenAmountFromUsd() public view {
        for (uint256 index = 0; index < s_tokens.length; index++) {
            address token = s_tokens[index];
            address priceFeed = s_priceFeeds[index];
            uint256 price = mockPriceConverter.getPrice(priceFeed);
            uint256 expectedPrice = ((QUANTITY_TO_DEPOSIT * PRECISION) /
                price) / PRECISION;

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

    //setting this as token address MockFailedTransferFrom
    //becuase other have diferent implementations for transferFrom function
    function _setupDeploySCEngineForBurnMockFailedTransferFrom() private {
        address owner = msg.sender;
        vm.startPrank(owner);
        mockFailedTransferFrom = new MockFailedTransferFrom();
        mockSCEngine = new SCEngine(
            s_tokens,
            s_priceFeeds,
            address(mockFailedTransferFrom)
        );
        mockFailedTransferFrom.transferOwnership(address(mockSCEngine));
        vm.stopPrank();
    }

    function testBurnShouldRevertIfTransferFromReturnFalse() external {
        _setupDeploySCEngineForBurnMockFailedTransferFrom();
        address user = users[1];
        address token = s_tokens[0];
        vm.startPrank(user);
        _mintAndApproveTokens(
            token,
            user,
            QUANTITY_TO_DEPOSIT,
            address(mockSCEngine)
        );
        mockSCEngine.depositCollataralAndMintSc(
            token,
            QUANTITY_TO_DEPOSIT,
            QUANTITY_TO_MINT
        );
        vm.expectRevert(SCEngine.SCEngine__TransferFailed.selector);
        mockSCEngine.burnSc(QUANTITY_TO_BURN);
        vm.stopPrank();
    }

    function testBurn() external {
        _depositCollateralMultiple();
        _mintScMultiple();
        _burnScMultiple(QUANTITY_TO_BURN);
    }

    ////////////////////////////
    //////RedeemCollateral/////
    ///////////////////////////
    function testRedeemCollarteralShouldRevertIfQuantityZero() external {
        uint256 tokenIndex = 0;
        address token = s_tokens[tokenIndex];

        uint256 quantity = 0;
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        scEngine.redeemCollateral(token, quantity);
    }

    //setting this as token address MockFailedTransfer
    //becuase other have diferent implementations for transfer function
    function _setupDeploySCEngineForMockTransferFailed() private {
        mockFailedTransfer = new MockFailedTransfer();
        address owner = msg.sender;
        s_tokens = [address(mockFailedTransfer)];
        s_priceFeeds = [s_priceFeeds[0]];
        vm.prank(owner);
        mockSCEngine = new SCEngine(
            s_tokens,
            s_priceFeeds,
            address(mockFailedTransfer)
        );
        mockFailedTransfer.transferOwnership(address(mockSCEngine));
    }

    function testShouldRevertRedeemCollateralIfTransferFailed() external {
        _setupDeploySCEngineForMockTransferFailed();
        address user = users[1];
        address token = address(mockFailedTransfer);
        vm.startPrank(user);
        MockFailedTransfer(mockFailedTransfer).mint(user, QUANTITY_TO_DEPOSIT);
        MockFailedTransfer(mockFailedTransfer).approve(
            address(mockSCEngine),
            QUANTITY_TO_DEPOSIT
        );
        mockSCEngine.depositCollataral(token, QUANTITY_TO_DEPOSIT);
        vm.expectRevert(SCEngine.SCEngine__TransferFailed.selector);
        mockSCEngine.redeemCollateral(token, QUANTITY_TO_DEPOSIT);
        vm.stopPrank();
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
        _depositCollateralMultiple();
        _mintScMultiple();
        uint256 quantity = QUANTITY_TO_DEPOSIT;
        for (uint256 userIndex = 0; userIndex < users.length; userIndex++) {
            address redeemer = users[userIndex];
            address token = s_tokens[0];
            vm.startPrank(redeemer);
            //this transaction is not going to be revert
            //as user have enough collateral in the reserve from the 2nd token
            scEngine.redeemCollateral(token, quantity);
            token = s_tokens[1];
            vm.expectRevert();
            //this calls must revert as token 1 collateral already redeemed and
            // this is going to break the health factor
            scEngine.redeemCollateral(token, quantity);
            vm.stopPrank();
        }
    }

    function testRedeemCollarteral() external {
        _depositCollateralMultiple();
        _mintScMultiple();
        _redeemCollateralMultiple();
    }

    //////////////////////////////
    ////redeemCollateralForSc/////
    /////////////////////////////
    function testRedeemCollateralForScShouldRevertIfValuesAreZero() external {
        address token = address(1);
        uint256 quantityOfCollateral = 0;
        uint256 quantityToBurn = 0;
        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        scEngine.redeemCollateralForSc(
            token,
            quantityOfCollateral,
            quantityToBurn
        );
    }

    function testRedeemCollateralForScShouldRevertIfNoAddressIsPassed()
        external
    {
        address token = address(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                SCEngine.SCEngine__TokenNotListed.selector,
                token
            )
        );
        scEngine.redeemCollateralForSc(
            token,
            QUANTITY_TO_REDEEM,
            QUANTITY_TO_BURN
        );
    }

    function testRedeemCollateralForScShoulNotRevert() external {
        _depositCollateralMultiple();
        _mintScMultiple();
        _redeemCollateralForScMultiple();
    }

    ////////////////////////////
    //////liquidate////////////
    ///////////////////////////

    function _setupLiquidater() private {
        uint256 quantityToDeposit = QUANTITY_TO_DEPOSIT * 10000000;
        uint256 quantityToMint = QUANTITY_TO_MINT * 1000;
        for (uint tokenIndex = 0; tokenIndex < s_tokens.length; tokenIndex++) {
            address token = s_tokens[tokenIndex];
            vm.startPrank(liquidater);
            _mintAndApproveTokens(
                token,
                liquidater,
                quantityToDeposit,
                address(scEngine)
            );
            _depositCollateralSingle(liquidater, token, quantityToDeposit);
            vm.stopPrank();
        }

        _mintScSingle(liquidater, quantityToMint);
        //approve for liquidations
        vm.prank(liquidater);
        IERC20(stableCoin).approve(address(scEngine), quantityToMint);
    }

    function _decreaseThePrice() private {
        uint256 pLength = s_priceFeeds.length;
        for (uint256 pIndex = 0; pIndex < pLength; pIndex++) {
            address priceFeed = s_priceFeeds[pIndex];
            //reduce to x times
            int256 newPrice = 909909;
            MockV3Aggregator(priceFeed).updateAnswer(newPrice);
        }
    }

    function _liquidateUsers() private {
        //skipping first as liquidater
        for (uint256 userIndex = 1; userIndex < usersLength; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address user = users[userIndex];
                address token = s_tokens[tokenIndex];
                _liquidate(token, user);
            }
        }
    }

    function _getTokenQuantity(address token) private returns (uint256) {
        uint256 tokenAmount = scEngine.getTokenAmountFromUsd(
            token,
            QUANTITY_TO_LIQUIDATE
        );
        uint256 tokenBonus = (tokenAmount * LIQUIDATION_BONUS) /
            LIQUIDATION_PRECISION;
        return (tokenAmount + tokenBonus);
    }

    function _liquidate(address token, address user) private {
        //Arrange
        uint256 tokenQuantity = _getTokenQuantity(token);
        //
        //
        uint256 userStartHealthFactor = scEngine.getUserHealthFactor(user);
        uint256 liquidaterStartHealthFactor = scEngine.getUserHealthFactor(
            liquidater
        );
        uint256 liquidaterStartTokenBalance = IERC20(token).balanceOf(
            liquidater
        );
        uint256 contractStartTokenBalance = IERC20(token).balanceOf(
            address(scEngine)
        );
        uint256 userCollateralBefore = scEngine.getDepositerCollateralBalance(
            user,
            token
        );
        uint256 userScBalanceBefore = scEngine.getMinterMintBalance(user);
        //
        //
        //ACT
        vm.startPrank(liquidater);
        vm.expectEmit(true, true, true, false, address(scEngine));
        emit CollateralRedeemed(user, liquidater, token, tokenQuantity);
        scEngine.liquidate(token, user, QUANTITY_TO_LIQUIDATE);
        vm.stopPrank();
        //
        //
        //we are not arranaging after variable
        //as they increase the limit of local variables
        //Assert
        assert(userStartHealthFactor < scEngine.getUserHealthFactor(user));
        assert(
            liquidaterStartHealthFactor >=
                scEngine.getUserHealthFactor(liquidater)
        );
        assert(
            liquidaterStartTokenBalance + tokenQuantity ==
                IERC20(token).balanceOf(liquidater)
        );
        assert(
            contractStartTokenBalance - tokenQuantity ==
                IERC20(token).balanceOf(address(scEngine))
        );
        assert(
            userCollateralBefore - tokenQuantity ==
                scEngine.getDepositerCollateralBalance(user, token)
        );
        assert(
            userScBalanceBefore - QUANTITY_TO_LIQUIDATE ==
                scEngine.getMinterMintBalance(user)
        );
    }

    function testLiquidateRevertIfZero() external {
        address user = users[1];
        uint256 debtToCover = 0;

        vm.expectRevert(SCEngine.SCEngine__ZeroValue.selector);
        vm.prank(liquidater);
        scEngine.liquidate(s_tokens[0], user, debtToCover);
    }

    function testLiquidateRevertIfHealthFactorOky() external {
        _depositCollateralMultiple();
        _mintScMultiple();
        _setupLiquidater();
        //skipping first as liquidater
        for (uint256 userIndex = 1; userIndex < usersLength; userIndex++) {
            for (
                uint256 tokenIndex = 0;
                tokenIndex < s_tokens.length;
                tokenIndex++
            ) {
                address user = users[userIndex];
                address token = s_tokens[tokenIndex];

                vm.startPrank(liquidater);
                vm.expectRevert(SCEngine.SCEngine__HealthFactorOk.selector);
                scEngine.liquidate(token, user, QUANTITY_TO_LIQUIDATE);
                vm.stopPrank();
            }
        }
    }

    function testLiquidateUserExceptFirstLocalChainOnly()
        external
        skipForkChains
    {
        _depositCollateralMultiple();
        _mintScMultiple();
        _setupLiquidater();
        _decreaseThePrice();
        _liquidateUsers();
    }

    function _setupDeploySCEngineForMockMoreDebtStableCoin() private {
        mockMoreDebtStableCoin = new MockMoreDebtStableCoin(s_priceFeeds);
        address owner = msg.sender;
        vm.prank(owner);
        mockSCEngine = new SCEngine(
            s_tokens,
            s_priceFeeds,
            address(mockMoreDebtStableCoin)
        );
        mockMoreDebtStableCoin.transferOwnership(address(mockSCEngine));
    }

    function testLiquidateUserRevertHealthFactorNotImproved()
        external
        skipForkChains
    {
        address user = users[1];
        address token = s_tokens[0];
        int256 newPrice = 909909;
        address priceFeed = s_priceFeeds[0];
        _setupDeploySCEngineForMockMoreDebtStableCoin();
        vm.startPrank(user);
        _mintAndApproveTokens(
            token,
            user,
            QUANTITY_TO_DEPOSIT,
            address(mockSCEngine)
        );
        mockSCEngine.depositCollataralAndMintSc(
            token,
            QUANTITY_TO_DEPOSIT,
            QUANTITY_TO_MINT
        );
        vm.stopPrank();
        vm.startPrank(liquidater);
        _mintAndApproveTokens(
            token,
            liquidater,
            QUANTITY_TO_DEPOSIT * 1000000000,
            address(mockSCEngine)
        );
        mockSCEngine.depositCollataralAndMintSc(
            token,
            QUANTITY_TO_DEPOSIT * 1000000000,
            QUANTITY_TO_MINT
        );

        IERC20(mockMoreDebtStableCoin).approve(
            address(mockSCEngine),
            QUANTITY_TO_MINT * 10000
        );
        vm.stopPrank();
        MockV3Aggregator(priceFeed).updateAnswer(newPrice);
        vm.startPrank(liquidater);
        vm.expectRevert(SCEngine.SCEngine__HealthFactorNotImproved.selector);
        mockSCEngine.liquidate(token, user, QUANTITY_TO_LIQUIDATE);
        vm.stopPrank();
    }
}
