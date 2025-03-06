// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBeefyVaultV7 {
    function want() external view returns (IERC20);
    function balance() external view returns (uint256);
    function available() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function depositAll() external;
    function deposit(uint256 _amount) external;
    function withdrawAll() external;
    function withdraw(uint256 _shares) external;
    function earn() external;
    function strategy() external view returns (address);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
} 