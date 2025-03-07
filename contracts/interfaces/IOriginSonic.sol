// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IOriginSonic {
    function stake(uint256 amount) external;
    function getStakedAmount(address user) external view returns (uint256);
    function unstake(uint256 amount) external;
} 