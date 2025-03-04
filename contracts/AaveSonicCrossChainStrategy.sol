// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IAaveLendingPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external;
    function withdraw(address asset, uint256 amount, address to) external;
}

interface IDebridgeGateway {
    function send(address token, uint256 amount, uint256 dstChainId, address receiver, bytes calldata autoParams) external payable returns (bytes32);
    function claim(bytes32 debridgeId, bytes calldata signatures, bytes calldata reserveProof) external;
}

interface ISonicFarm {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimRewards() external;
}

contract AaveSonicCrossChainStrategy is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

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
        address _asset,
        address _aaveLendingPool,
        address _deBridge,
        address _sonicFarm,
        uint256 _destinationChainId
    ) {
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
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function supplyToAave(uint256 amount) external nonReentrant onlyRole(MANAGER_ROLE) {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.approve(address(aaveLendingPool), amount);
        aaveLendingPool.supply(address(asset), amount, address(this), 0);
        totalSupplied += amount;
        emit Supplied(amount);
    }

    function borrowAndBridge(uint256 amount) external nonReentrant onlyRole(MANAGER_ROLE) {
        aaveLendingPool.borrow(address(asset), amount, 2, 0, address(this));
        asset.approve(address(deBridge), amount);
        deBridge.send(address(asset), amount, destinationChainId, address(this), "");
        totalBorrowed += amount;
        emit Borrowed(amount);
        emit BridgedToSonic(amount);
    }

    function farmInSonic(uint256 amount) external nonReentrant onlyRole(MANAGER_ROLE) {
        asset.approve(address(sonicFarm), amount);
        sonicFarm.deposit(amount);
        emit FarmedInSonic(amount);
    }

    function withdrawAndRepay(uint256 amount) external nonReentrant onlyRole(MANAGER_ROLE) {
        sonicFarm.withdraw(amount);
        // Bridge back to source chain would go here
        aaveLendingPool.repay(address(asset), amount, 2, address(this));
        totalBorrowed -= amount;
        emit WithdrawnFromSonic(amount);
        emit RepaidToAave(amount);
    }

    function setDestinationChainId(uint256 _destinationChainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        destinationChainId = _destinationChainId;
    }
} 