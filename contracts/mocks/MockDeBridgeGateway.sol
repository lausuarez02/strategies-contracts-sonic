// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IDebridgeGateway.sol";

contract MockDeBridgeGateway is IDebridgeGateway {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public bridgedAmounts;

    function send(
        address token,
        uint256 amount,
        uint256 chainIdTo,
        address receiver,
        bytes memory data
    ) external {
        // Just track the bridged amount, don't actually transfer
        bridgedAmounts[msg.sender] = amount;
    }

    function getBridgedAmount(address user) external view returns (uint256) {
        return bridgedAmounts[user];
    }
} 