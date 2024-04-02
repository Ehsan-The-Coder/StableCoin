//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Script, console} from "forge-std/Script.sol";
import {SCEngine} from "../../src/SCEngine.sol";
import {StableCoin} from "../../src/StableCoin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DeploySCEngine} from "../../script/deploy/DeploySCEngine.s.sol";
import {HelperConfig} from "../../script/deploy/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StableCoinTest is Test, Script {
    //NOTE we use e and a prefix many time this
    //e=expect and a=actual
    //<-----------------------------variable--------------------------->
    StableCoin stableCoin;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant QUANTITY_TO_MINT = 100 * PRECISION;
    uint256 private constant QUANTITY_TO_BURN = 10 * PRECISION;
    //
    //
    //
    // TEST Variable
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
    address owner;

    //<---------------------------------------setUp------------------------------------------>
    function setUp() external {
        DeploySCEngine deploySCEngine = new DeploySCEngine();
        (, stableCoin, , ) = deploySCEngine.run();

        _fundUsersAccount();

        owner = StableCoin(stableCoin).owner();
    }

    //<---------------------------------------helper functions------------------------------------------>
    function _fundUsersAccount() private {
        usersLength = users.length;
        for (uint8 userIndex = 0; userIndex < usersLength; userIndex++) {
            address user = users[userIndex];
            vm.deal(user, USERS_START_BALANCE);
        }
    }

    //<---------------------------------------test------------------------------------------>

    ////////////////////////////
    ///////////mint////////////
    //////////////////////////
    function testMintRevertIfZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(StableCoin.StableCoin__NotZeroAddress.selector);
        stableCoin.mint(address(0), QUANTITY_TO_MINT);
    }

    function testMintRevertIfZeroValue() public {
        uint256 userIndex = 0;
        address user = users[userIndex];

        vm.prank(owner);
        vm.expectRevert(StableCoin.StableCoin__NotZeroValue.selector);
        stableCoin.mint(user, 0);
    }

    function testMintRevertIfNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        stableCoin.mint(msg.sender, QUANTITY_TO_MINT);
    }

    function testMintReturnSuccess() public {
        uint256 userIndex = 0;
        address user = users[userIndex];
        bool isSuccess;

        vm.prank(owner);
        isSuccess = stableCoin.mint(user, QUANTITY_TO_MINT);

        assert(isSuccess == true);
    }

    function testMint() public {
        uint256 userIndex = 0;
        address user = users[userIndex];
        uint256 userExpectedBalance = stableCoin.balanceOf(user) +
            QUANTITY_TO_MINT;
        bool isSuccess;

        vm.prank(owner);
        isSuccess = stableCoin.mint(user, QUANTITY_TO_MINT);

        uint256 userActualBalance = stableCoin.balanceOf(user);
        assert(userExpectedBalance == userActualBalance);
        assert(isSuccess);
    }

    ////////////////////////////
    ///////////burn////////////
    //////////////////////////

    function testBurnRevertIfZeroValue() public {
        uint256 userIndex = 0;
        address user = users[userIndex];

        vm.prank(owner);
        vm.expectRevert(StableCoin.StableCoin__NotZeroValue.selector);
        stableCoin.burn(0);
    }

    function testBurnRevertIfNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                address(this)
            )
        );
        stableCoin.burn(QUANTITY_TO_MINT);
    }

    function testBurnRevertIfBurnQuantityExceedsBalance() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                StableCoin.StableCoin__BurnQuantityExceedsBalance.selector,
                QUANTITY_TO_MINT,
                0
            )
        );
        stableCoin.burn(QUANTITY_TO_MINT);
    }

    function testBurn() public {
        vm.prank(owner);
        stableCoin.mint(owner, QUANTITY_TO_MINT);

        uint256 userExpectedBalance = stableCoin.balanceOf(owner) -
            QUANTITY_TO_BURN;
        vm.prank(owner);
        stableCoin.burn(QUANTITY_TO_BURN);

        uint256 userActualBalance = stableCoin.balanceOf(owner);
        assert(userExpectedBalance == userActualBalance);
    }
}
