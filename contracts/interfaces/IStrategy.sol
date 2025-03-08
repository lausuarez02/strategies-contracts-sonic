// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IStrategy {
    function vault() external view returns (address);
    function beforeDeposit() external;
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
    function retireStrat() external;
} 