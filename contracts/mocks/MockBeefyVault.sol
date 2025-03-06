// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IBeefyVaultV7.sol";

contract MockBeefyVault is IBeefyVaultV7 {
    IERC20 public override want;
    mapping(address => uint256) public override balanceOf;
    uint256 public override totalSupply;
    address public override strategy;

    constructor(address _want, address _strategy) {
        want = IERC20(_want);
        strategy = _strategy;
    }

    function deposit(uint256 _amount) external override {
        want.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] += _amount;
        totalSupply += _amount;
    }

    function withdraw(uint256 _shares) external override {
        require(balanceOf[msg.sender] >= _shares, "Insufficient balance");
        balanceOf[msg.sender] -= _shares;
        totalSupply -= _shares;
        want.transfer(msg.sender, _shares);
    }

    function balance() external view override returns (uint256) {
        return want.balanceOf(address(this));
    }

    function available() external view override returns (uint256) {
        return want.balanceOf(address(this));
    }

    function getPricePerFullShare() external pure override returns (uint256) {
        return 1e18;
    }

    function depositAll() external override {
        uint256 wantBalance = want.balanceOf(msg.sender);
        this.deposit(wantBalance);
    }

    function withdrawAll() external override {
        uint256 userBalance = balanceOf[msg.sender];
        this.withdraw(userBalance);
    }

    function earn() external override {}
} 