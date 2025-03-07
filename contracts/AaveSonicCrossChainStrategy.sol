// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IDebridgeGateway.sol";
import "./interfaces/ISonicFarm.sol";
import "./interfaces/IAaveLendingPool.sol";

abstract contract AaveSonicCrossChainStrategy is ILending, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    IERC20 public immutable asset;
    IAaveLendingPool public immutable aaveLendingPool;
    IDebridgeGateway public immutable deBridge;
    ISonicFarm public immutable sonicFarm;
    
    uint256 public totalBorrowed;
    uint256 public totalSupplied;
    uint256 public destinationChainId;
    
    event Supplied(uint256 amount);
    event Borrowed(uint256 amount);
    event BridgedToSonic(uint256 amount);
    event FarmedInSonic(uint256 amount);
    event WithdrawnFromSonic(uint256 amount);
    event RepaidToAave(uint256 amount);

    constructor(
        address _vault,
        address _asset,
        address _aaveLendingPool,
        address _deBridge,
        address _sonicFarm,
        uint256 _destinationChainId
    ) {
        require(_vault != address(0), "Invalid vault");
        require(_asset != address(0), "Invalid asset");
        require(_aaveLendingPool != address(0), "Invalid Aave pool");
        require(_deBridge != address(0), "Invalid deBridge");
        require(_sonicFarm != address(0), "Invalid Sonic farm");
        
        asset = IERC20(_asset);
        aaveLendingPool = IAaveLendingPool(_aaveLendingPool);
        deBridge = IDebridgeGateway(_deBridge);
        sonicFarm = ISonicFarm(_sonicFarm);
        destinationChainId = _destinationChainId;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ROLE, _vault);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    // Implement ILending interface
    function deposit(address _asset, uint256 amount) external override onlyRole(VAULT_ROLE) {
        require(_asset == address(asset), "Invalid asset");
        require(amount > 0, "Zero amount");

        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.approve(address(aaveLendingPool), amount);
        aaveLendingPool.supply(address(asset), amount, address(this), 0);
        totalSupplied += amount;
        emit Supplied(amount);
    }

    function withdraw(address _asset, uint256 amount) external override onlyRole(VAULT_ROLE) {
        require(_asset == address(asset), "Invalid asset");
        require(amount > 0, "Zero amount");
        require(amount <= totalSupplied, "Insufficient balance");

        aaveLendingPool.withdraw(address(asset), amount, msg.sender);
        totalSupplied -= amount;
        emit WithdrawnFromSonic(amount);
    }

    // Strategy-specific functions
    function borrowAndBridge(uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount <= totalSupplied * 75 / 100, "Exceeds borrow limit"); // 75% LTV limit
        
        aaveLendingPool.borrow(address(asset), amount, 2, 0, address(this));
        asset.approve(address(deBridge), amount);
        deBridge.send(address(asset), amount, destinationChainId, address(this), "");
        totalBorrowed += amount;
        
        emit Borrowed(amount);
        emit BridgedToSonic(amount);
    }

    function farmInSonic(uint256 amount) external onlyRole(MANAGER_ROLE) {
        asset.approve(address(sonicFarm), amount);
        sonicFarm.deposit(amount);
        emit FarmedInSonic(amount);
    }

    function withdrawAndRepay(uint256 amount) external onlyRole(MANAGER_ROLE) {
        require(amount <= totalBorrowed, "Exceeds borrowed amount");
        
        sonicFarm.withdraw(amount);
        aaveLendingPool.repay(address(asset), amount, 2, address(this));
        totalBorrowed -= amount;
        
        emit WithdrawnFromSonic(amount);
        emit RepaidToAave(amount);
    }

    function getTotalAssets() external view returns (uint256) {
        return totalSupplied - totalBorrowed;
    }

    function setDestinationChainId(uint256 _destinationChainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        destinationChainId = _destinationChainId;
    }
}