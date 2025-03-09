// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ISFC {
    struct Validator {
        uint256 status;
        uint256 deactivatedTime;
        uint256 deactivatedEpoch;
        uint256 receivedStake;
        uint256 createdEpoch;
        uint256 createdTime;
        address auth;
        address[] delegators;
        bool isActive;
    }

    function getValidatorCount() external view returns (uint256);
    function getValidator(uint256 validatorId) external view returns (Validator memory);
    function delegate(uint256 toValidatorId) external payable;
    function undelegate(uint256 toValidatorId, uint256 wrID, uint256 amount) external;
    function withdraw(uint256 validatorId, uint256 wrID) external;
    function getStake(address delegator, uint256 validatorId) external view returns (uint256);
    function pendingRewards(address delegator, uint256 validatorId) external view returns (uint256);
    function claimRewards(uint256 validatorId) external;
    function restakeRewards(uint256 validatorId) external;
}