// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/Script.sol";

/**
 * @title StableCoin (SC)Engine
 * @author Muhammad Ehsan orginal patrick alphac
 *
 * The Stablecoin (SC) system is a fintech innovation that combines technology and finance to create a stablecoin with unique features, setting it apart from other cryptocurrencies.
 * It's Exogenously Collateralized, using external assets as collateral to ensure its value is stable and tied to real-world collateral values.
 * Dollar Pegged, it maintains a 1:1 value with the US dollar, offering a stable and predictable currency.
 * Algorithmically Stable, it uses sophisticated algorithms to manage supply and demand, ensuring stability in volatile markets.
 * It's like MakerDAO but more simpler.
 *
 * Requires "overcollateralization" to ensure the value of all collateral is always greater than the dollar-backed value of all minted SC, maintaining system security and stability.
 *
 * The `SCEngine` contract manages minting, redeeming, and collateral operations, designed to be minimalistic and focus on essential functionalities for SC stability and security.
 * The `StableCoin` contract creates and manages SC tokens, ensuring minting and burning as needed to maintain supply and demand.
 * Together, `SCEngine` and `StableCoin` form the core of the Decentralized Stablecoin system, providing a secure, stable cryptocurrency backed by real-world assets and pegged to the US dollar.
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg at all times.
 */

contract StableCoin is ERC20, ERC20Burnable, Ownable {
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
    }
}
