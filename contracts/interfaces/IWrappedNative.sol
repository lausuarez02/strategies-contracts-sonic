// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IWrappedNative {
    function deposit() external payable;
    function withdraw(uint256) external;
} 