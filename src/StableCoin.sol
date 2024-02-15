// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StableCoin is ERC20, ERC20Burnable, Ownable {
    //<----------------------------state variable---------------------------->
    //<----------------------------events---------------------------->
    //<----------------------------custom errors---------------------------->
    error StableCoin__NotZeroAddress();
    error StableCoin__NotZeroAmount();
    error StableCoin__NotZeroBalance();

    //<----------------------------modifiers---------------------------->

    //<----------------------------functions---------------------------->
    //<----------------------------constructor---------------------------->
    constructor(
        address initialOwner
    ) ERC20("StableCoin", "SC") Ownable(initialOwner) {}

    //<----------------------------external functions---------------------------->
    //<----------------------------public functions---------------------------->
    function mint(
        address to,
        uint256 amount
    ) public onlyOwner returns (bool isSuccess) {
        if (to == address(0)) {
            revert StableCoin__NotZeroAddress();
        }
        if (amount == 0) {
            revert StableCoin__NotZeroAmount();
        }
        _mint(to, amount);
        isSuccess = true;
        return isSuccess;
    }

    function burn(uint256 amount) public override onlyOwner {
        if (amount == 0) {
            revert StableCoin__NotZeroAmount();
        }
        uint256 balance = balanceOf(msg.sender);
        if (balance == 0) {
            revert StableCoin__NotZeroBalance();
        }
        super.burn(amount);
    }
    //<----------------------------external/public view/pure functions---------------------------->
    //<----------------------------private functions---------------------------->
    //<----------------------------private view/pure functions---------------------------->
}
