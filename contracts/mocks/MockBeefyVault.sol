// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IBeefyVault.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockBeefyVault {
    uint256 private _balance;
    uint256 private _depositResult;
    uint256 private _withdrawResult;
    address private _beefyStrategy;
    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function setDepositResult(uint256 amount) external {
        _depositResult = amount;
    }

    function setWithdrawResult(uint256 amount) external {
        _withdrawResult = amount;
    }

    function setBeefyStrategy(address strategy) external {
        _beefyStrategy = strategy;
    }

    function deposit(uint256 amount) external returns (uint256) {
        token.transferFrom(msg.sender, address(this), amount);
        _balance += amount;
        return _depositResult > 0 ? _depositResult : amount;
    }

    function withdraw(uint256 amount) external returns (uint256) {
        require(_balance >= amount, "Insufficient balance");
        _balance -= amount;
        token.transfer(msg.sender, amount);
        return _withdrawResult > 0 ? _withdrawResult : amount;
    }

    function balance() external view returns (uint256) {
        return _balance;
    }

    function strategy() external view returns (address) {
        return _beefyStrategy;
    }

    function want() external view returns (address) {
        return address(token);
    }

    function getPricePerFullShare() external pure returns (uint256) {
        return 1e18;
    }

    function totalSupply() external pure returns (uint256) {
        return 1000e18;
    }

    function balanceOf(address) external pure returns (uint256) {
        return 100e18;
    }

    function earn() external {}
} 