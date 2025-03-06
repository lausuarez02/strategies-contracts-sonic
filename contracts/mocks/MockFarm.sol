// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockFarm {
    uint256 public rewardAmount;
    IERC20 public rewardToken;

    function setRewardAmount(uint256 amount) external {
        rewardAmount = amount;
    }

    function setRewardToken(address _rewardToken) external {
        rewardToken = IERC20(_rewardToken);
    }

    function deposit(uint256) external pure {}
    function withdraw(uint256) external pure {}
    
    function claimRewards() external {
        if (rewardAmount > 0) {
            rewardToken.transfer(msg.sender, rewardAmount);
        }
    }
} 