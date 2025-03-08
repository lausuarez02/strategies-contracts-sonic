// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IOracle.sol";

contract MockOracle is IOracle {
    mapping(address => uint256) private prices;

    function setPrice(address token, uint256 price) external {
        prices[token] = price;
    }

    function getPrice(address token) external view override returns (uint256) {
        return prices[token];
    }
} 