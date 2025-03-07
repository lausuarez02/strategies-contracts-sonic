// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDebridgeGateway {
    function send(address token, uint256 amount, uint256 chainIdTo, address receiver, bytes memory data) external;
} 