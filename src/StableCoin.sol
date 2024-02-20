// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract StableCoin is ERC20, ERC20Burnable, Ownable {
    //<----------------------------state variable---------------------------->
    //<----------------------------events---------------------------->
    event TokenMinted(address indexed minter, uint256 quantity);
    event TokenBurned(address indexed burner, uint256 quantity);
    //<----------------------------custom errors---------------------------->
    error StableCoin__NotZeroAddress();
    error StableCoin__NotZeroQuantity();
    error StableCoin__NotZeroBalance();
    error StableCoin__BurnQuantityExceedsBalance(
        uint256 quantity,
        uint256 balance
    );

    //<----------------------------modifiers---------------------------->

    //<----------------------------functions---------------------------->
    //<----------------------------constructor---------------------------->
    constructor() ERC20("StableCoin", "SC") Ownable(msg.sender) {}

    //<----------------------------external functions---------------------------->
    //<----------------------------public functions---------------------------->
    function mint(
        address to,
        uint256 quantity
    ) public onlyOwner returns (bool isSuccess) {
        if (to == address(0)) {
            revert StableCoin__NotZeroAddress();
        }
        if (quantity == 0) {
            revert StableCoin__NotZeroQuantity();
        }
        _mint(to, quantity);
        emit TokenMinted(to, quantity);
        isSuccess = true;

        return isSuccess;
    }

    function burn(uint256 quantity) public override onlyOwner {
        if (quantity == 0) {
            revert StableCoin__NotZeroQuantity();
        }
        uint256 balance = balanceOf(msg.sender);
        if (balance < quantity) {
            revert StableCoin__BurnQuantityExceedsBalance(quantity, balance);
        }
        super.burn(quantity);

        emit TokenBurned(msg.sender, quantity);
    }
    //<----------------------------external/public view/pure functions---------------------------->
    //<----------------------------internal functions---------------------------->
    //<----------------------------internal view/pure functions---------------------------->
    //<----------------------------private functions---------------------------->
    //<----------------------------private view/pure functions---------------------------->
}
