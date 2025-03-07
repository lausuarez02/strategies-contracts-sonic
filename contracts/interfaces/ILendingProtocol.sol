// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILendingProtocol {
    function depositCollateral(address token, uint256 amount) external;
    function borrow(address token, uint256 amount) external;
    function repay(address token, uint256 amount) external;
    function withdrawCollateral(address token, uint256 amount) external;
} 