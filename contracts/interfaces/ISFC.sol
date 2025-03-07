// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISFC {
    function delegate(uint256 validatorID) external payable;
    function undelegate(uint256 validatorID, uint256 wrID, uint256 amount) external;
    function withdraw(uint256 validatorID, uint256 wrID) external;
    function getStake(address delegator, uint256 validatorID) external view returns (uint256);
    function pendingRewards(address delegator, uint256 validatorID) external view returns (uint256);
    function claimRewards(uint256 validatorID) external;
    function restakeRewards(uint256 validatorID) external;
}