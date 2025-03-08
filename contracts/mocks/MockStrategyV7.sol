// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IStrategyV7.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockStrategyV7 is IStrategyV7 {
    address public override vault;
    IERC20 public override want;
    address public override unirouter;
    bool public override paused;

    event Harvested();

    constructor() {
        vault = msg.sender;
        unirouter = msg.sender;
    }

    function setVault(address _vault) external {
        vault = _vault;
    }

    function setWant(address _want) external {
        want = IERC20(_want);
    }

    function beforeDeposit() external pure override {}
    function deposit() external override {}
    function withdraw(uint256) external override {}
    function balanceOf() external pure override returns (uint256) { return 100; }
    function balanceOfWant() external pure override returns (uint256) { return 100; }
    function balanceOfPool() external pure override returns (uint256) { return 100; }
    
    // Modified harvest function to actually do something
    function harvest() external override {
        require(address(want) != address(0), "Want not set");
        // Transfer some tokens to simulate rewards
        if (want.balanceOf(address(this)) > 0) {
            want.transfer(vault, want.balanceOf(address(this)));
        }
        emit Harvested();
    }
    
    function retireStrat() external override {}
    function panic() external override {}
    function pause() external override { paused = true; }
    function unpause() external override { paused = false; }
} 