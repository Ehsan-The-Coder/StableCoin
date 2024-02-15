// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

library Utilis {
    function isContract(address _address) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_address)
        }
        return (size > 0);
    }

    function min(uint x, uint y) internal pure returns (uint) {
        return x <= y ? x : y;
    }
}
