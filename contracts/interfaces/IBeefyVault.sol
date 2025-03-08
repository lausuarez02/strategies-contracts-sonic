// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBeefyVault {
    function balance() external view returns (uint256);
    function available() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function deposit(uint256 _amount) external;
    function depositAll() external;
    function withdraw(uint256 _shares) external;
    function withdrawAll() external;
    function earn() external;
    function strategy() external view returns (address);
    function want() external view returns (address);
} 