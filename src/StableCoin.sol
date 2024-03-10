// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Script.sol";

contract StableCoin is ERC20, ERC20Burnable, Ownable {
    //<----------------------------state variable---------------------------->
    //<----------------------------events---------------------------->
    event TokenMinted(address indexed minter, uint256 quantity);
    event TokenBurned(address indexed burner, uint256 quantity);
    //<----------------------------custom errors---------------------------->
    error StableCoin__NotZeroAddress();
    error StableCoin__NotZeroValue();
    error StableCoin__NotZeroBalance();
    error StableCoin__BurnQuantityExceedsBalance(
        uint256 quantity,
        uint256 balance
    );

    //<----------------------------modifiers---------------------------->
    modifier isZeroAddress(address _address) {
        if (_address == address(0)) {
            revert StableCoin__NotZeroAddress();
        }
        _;
    }
    modifier isZeroValue(uint256 value) {
        if (value == 0) {
            revert StableCoin__NotZeroValue();
        }
        _;
    }

    //<----------------------------functions---------------------------->
    //<----------------------------constructor---------------------------->
    constructor() ERC20("StableCoin", "SC") Ownable(msg.sender) {}

    //<----------------------------external functions---------------------------->
    //<----------------------------public functions---------------------------->
    function mint(
        address to,
        uint256 quantity
    )
        public
        onlyOwner
        isZeroAddress(to)
        isZeroValue(quantity)
        returns (bool isSuccess)
    {
        _mint(to, quantity);
        emit TokenMinted(to, quantity);
        isSuccess = true;

        return isSuccess;
    }

    function burn(
        uint256 quantity
    ) public override onlyOwner isZeroValue(quantity) {
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
