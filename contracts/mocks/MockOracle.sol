// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MockOracle {
    function getPrice(address) external pure returns (uint256) {
        return 1e18; // 1:1 price ratio
    }
} 