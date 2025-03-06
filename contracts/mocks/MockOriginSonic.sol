// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MockOriginSonic {
    mapping(address => uint256) public stakedAmount;

    function stake(uint256 amount) external {
        stakedAmount[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        require(stakedAmount[msg.sender] >= amount, "Insufficient balance");
        stakedAmount[msg.sender] -= amount;
    }

    function getStakedAmount(address user) external view returns (uint256) {
        return stakedAmount[user];
    }
} 