// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISonicStakingStrategy {
    function stake(uint256 amount) external;
    function unstake(uint256 amount) external;
    function getStakedBalance(address account) external view returns (uint256);
    function getRewards() external;
} 