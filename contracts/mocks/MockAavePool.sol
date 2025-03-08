// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IAavePool.sol";

contract MockAavePool is IAavePool {
    using SafeERC20 for IERC20;
    
    mapping(address => uint256) public supplies;
    mapping(address => uint256) public borrows;
    uint256 private healthFactor = 2e18;  // Changed from constant to variable

    event Supplied(address asset, uint256 amount, address onBehalfOf);
    event Borrowed(address asset, uint256 amount, address onBehalfOf);
    event Debug(string message, address user, uint256 amount);

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        supplies[onBehalfOf] += amount;
        emit Supplied(asset, amount, onBehalfOf);
        emit Debug("Supply", onBehalfOf, supplies[onBehalfOf]);
    }
    
    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external {
        require(IERC20(asset).balanceOf(address(this)) >= amount, "Insufficient balance");
        
        // Track borrows against the strategy (msg.sender)
        borrows[msg.sender] += amount;
        
        // Transfer the tokens
        IERC20(asset).safeTransfer(msg.sender, amount);
        
        emit Borrowed(asset, amount, msg.sender);
        emit Debug("Borrow called", msg.sender, amount);
        emit Debug("Borrow amount", msg.sender, borrows[msg.sender]);
        emit Debug("Asset balance", asset, IERC20(asset).balanceOf(address(this)));
    }

    function repay(address asset, uint256 amount, uint256, address onBehalfOf) external returns (uint256) {
        // Don't check pool balance for repay, just accept the tokens
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        borrows[onBehalfOf] = borrows[onBehalfOf] >= amount ? borrows[onBehalfOf] - amount : 0;
        emit Debug("Repay", onBehalfOf, amount);
        return amount;
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        require(supplies[msg.sender] >= amount, "Insufficient supply balance");
        
        // Don't check pool balance, just transfer
        IERC20(asset).safeTransfer(to, amount);
        supplies[msg.sender] -= amount;
        emit Debug("Withdraw", msg.sender, amount);
        return amount;
    }

    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 _healthFactor
    ) {
        // Set LTV to 75% to allow borrowing up to 75% of collateral
        uint256 ltv = 7500;  // 75%
        uint256 availableBorrows = (supplies[user] * ltv) / 10000;
        
        return (
            supplies[user],
            borrows[user],
            availableBorrows,
            8500,
            ltv,
            healthFactor  // Use the variable health factor
        );
    }

    function setHealthFactor(uint256 _healthFactor) external {
        healthFactor = _healthFactor;  // Allow health factor to be changed
    }
} 