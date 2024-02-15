// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//<----------------------------import statements---------------------------->
import {Utilis} from "./Libraries/Utilis.sol";

contract DSCEngine {
    //<----------------------------type declarations---------------------------->

    //<----------------------------state variable---------------------------->
    mapping(address token => address priceFeed) private s_tokenPriceFeed;
    address[] private s_token;
    address private immutable i_stableCoin;

    //<----------------------------events---------------------------->
    //<----------------------------custom errors---------------------------->
    error DSCEngine__LengthOfConstructorValuesNotEqual(
        uint256 tokenLength,
        uint256 priceFeedLength
    );
    error DSCEngine__ZeroAddress();
    error DSCEngine__IdenticalTokenAndPriceFeed();

    //<----------------------------modifiers---------------------------->
    modifier notEqualLength(uint256 lengthA, uint256 lengthB) {
        if (lengthA != lengthB) {
            revert DSCEngine__LengthOfConstructorValuesNotEqual(
                lengthA,
                lengthB
            );
        }
        _;
    }

    //<----------------------------functions---------------------------->
    //<----------------------------constructor---------------------------->
    constructor(
        address[] memory token,
        address[] memory priceFeed,
        address stableCoin
    ) notEqualLength(token.length, priceFeed.length) {
        for (uint256 index = 0; index < token.length; index++) {
            address _token = token[index];
            address _priceFeed = priceFeed[index];

            _revertZeroAddress(_token);
            _revertZeroAddress(_priceFeed);
            _reverIdenticalAddress(_token, _priceFeed);

            s_tokenPriceFeed[_token] = _priceFeed;
        }

        _revertZeroAddress(stableCoin);
        i_stableCoin = stableCoin;
    }

    //<----------------------------external functions---------------------------->

    //<----------------------------public functions---------------------------->
    function DepositColletralForAndMint() public {}

    //<----------------------------external/public view/pure functions---------------------------->
    //<----------------------------private functions---------------------------->
    //<----------------------------private view/pure functions---------------------------->
    function _revertZeroAddress(address _address) private pure {
        if (_address == address(0)) {
            revert DSCEngine__ZeroAddress();
        }
    }

    function _reverIdenticalAddress(
        address _addressA,
        address _addressB
    ) private pure {
        if (_addressA == _addressB) {
            revert DSCEngine__IdenticalTokenAndPriceFeed();
        }
    }
}
