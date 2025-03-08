// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IWrappedNative.sol";

contract MockWrappedNative is IWrappedNative {
    function deposit() external payable {}
    
    function withdraw(uint256 amount) external {
        payable(msg.sender).transfer(amount);
    }

    receive() external payable {}
} 