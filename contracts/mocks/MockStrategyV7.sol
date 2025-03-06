// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IStrategyV7.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStrategyV7 is IStrategyV7 {
    address public override vault;
    IERC20 public override want;
    address public override unirouter;
    bool public override paused;

    function beforeDeposit() external pure override {}
    function deposit() external pure override {}
    function withdraw(uint256) external pure override {}
    function balanceOf() external pure override returns (uint256) { return 0; }
    function balanceOfWant() external pure override returns (uint256) { return 0; }
    function balanceOfPool() external pure override returns (uint256) { return 0; }
    function harvest() external pure override {}
    function retireStrat() external pure override {}
    function panic() external pure override {}
    function pause() external override { paused = true; }
    function unpause() external override { paused = false; }
} 