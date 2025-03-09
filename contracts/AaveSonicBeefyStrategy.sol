// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IBeefyVaultV7.sol";
import "./interfaces/IStrategyV7.sol";
import "./interfaces/IWrappedSonic.sol";
import "./interfaces/IAavePool.sol";
import "./interfaces/IDeBridgeGate.sol";

contract AaveSonicBeefyStrategy is AccessControl, ReentrancyGuard, ILending {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    
    IBeefyVaultV7 public beefyVault;
    IStrategyV7 public beefyStrategy;
    IAavePool public immutable aavePool;
    IWrappedSonic public immutable wrappedSonic;
    IERC20 public immutable USDC;
    IERC20 public immutable ARB_USDC;  // USDC on Arbitrum
    IDeBridgeGate public immutable debridge;
    
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;
    bool public paused;

    event BridgedToArbitrum(uint256 amount);
    event BridgedBackToSonic(uint256 amount);
    event AaveDeposited(uint256 amount);
    event AaveWithdrawn(uint256 amount);
    event BeefyDeposited(uint256 amount);
    event BeefyWithdrawn(uint256 shares, uint256 amount);

    constructor(
        address _vault,
        address _aavePool,
        address _wrappedSonic,
        address _beefyVault,
        address _usdc,
        address _arbUsdc,
        address _deBridge
    ) {
        require(_beefyVault != address(0), "Zero beefy vault");
        require(_aavePool != address(0), "Zero aave pool");
        require(_deBridge != address(0), "Zero deBridge");
        require(_usdc != address(0), "Zero USDC");
        require(_arbUsdc != address(0), "Zero ARB USDC");
        
        beefyVault = IBeefyVaultV7(_beefyVault);
        beefyStrategy = IStrategyV7(beefyVault.strategy());
        aavePool = IAavePool(_aavePool);
        wrappedSonic = IWrappedSonic(_wrappedSonic);
        USDC = IERC20(_usdc);
        ARB_USDC = IERC20(_arbUsdc);
        debridge = IDeBridgeGate(_deBridge);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ROLE, _vault);
        _grantRole(STRATEGIST_ROLE, msg.sender);
    }

    function deposit(address asset, uint256 amount) external override onlyRole(VAULT_ROLE) nonReentrant {
        require(asset == address(wrappedSonic), "Invalid asset");
        require(amount > 0, "Zero amount");
        require(!paused, "Strategy is paused");
        
        // 1. First swap WSONIC to USDC on Sonic
        uint256 usdcAmount = _swapWSonicToUSDC(amount);
        require(usdcAmount > 0, "Swap failed");
        
        // 2. Bridge USDC to Arbitrum
        uint256 bridgedAmount = _bridgeToArbitrum(usdcAmount);
        emit BridgedToArbitrum(bridgedAmount);
        
        // 3. Deposit to Aave on Arbitrum (this will be executed on Arbitrum)
        IERC20(ARB_USDC).safeApprove(address(aavePool), bridgedAmount);
        aavePool.supply(address(ARB_USDC), bridgedAmount, address(this), 0);
        emit AaveDeposited(bridgedAmount);
        
        // 4. Bridge rewards back to Sonic and deposit to Beefy
        uint256 sonicAmount = _bridgeBackToSonic(bridgedAmount);
        USDC.safeApprove(address(beefyVault), sonicAmount);
        beefyVault.deposit(sonicAmount);
        emit BeefyDeposited(sonicAmount);
    }

    function withdraw(address asset, uint256 amount) external override onlyRole(VAULT_ROLE) nonReentrant {
        require(asset == address(wrappedSonic), "Invalid asset");
        require(amount > 0, "Zero amount");
        
        // Calculate amounts to withdraw from each protocol
        uint256 totalUSDC = this.getBalance(address(USDC));
        (uint256 aaveShare,,,,,) = aavePool.getUserAccountData(address(this));
        uint256 beefyShare = beefyVault.balance();
        
        // 1. Withdraw from Aave on Arbitrum
        uint256 aaveAmount = (amount * aaveShare) / totalUSDC;
        aavePool.withdraw(address(ARB_USDC), aaveAmount, address(this));
        emit AaveWithdrawn(aaveAmount);
        
        // 2. Bridge back to Sonic
        uint256 bridgedBack = _bridgeBackToSonic(aaveAmount);
        emit BridgedBackToSonic(bridgedBack);
        
        // 3. Withdraw from Beefy on Sonic
        uint256 beefyAmount = (amount * beefyShare) / totalUSDC;
        uint256 shares = (beefyAmount * beefyVault.totalSupply()) / beefyVault.balance();
        beefyVault.withdraw(shares);
        emit BeefyWithdrawn(shares, beefyAmount);
        
        // 4. Swap total USDC back to WSONIC
        uint256 totalUSDCWithdrawn = USDC.balanceOf(address(this));
        uint256 wsonicAmount = _swapUSDCToWSonic(totalUSDCWithdrawn);
        
        // Transfer WSONIC back to vault
        IERC20(address(wrappedSonic)).safeTransfer(msg.sender, wsonicAmount);
    }

    function getBalance(address asset) external view override returns (uint256) {
        require(asset == address(wrappedSonic), "Invalid asset");
        (uint256 aaveBalance,,,,,) = aavePool.getUserAccountData(address(this));
        uint256 beefyBalance = beefyVault.balance();
        return aaveBalance + beefyBalance;
    }

    function _bridgeToArbitrum(uint256 amount) internal returns (uint256) {
        USDC.safeApprove(address(debridge), amount);
        
        bytes memory permitData = "";  // Add permit data if needed
        
        IDeBridgeGate.SubmissionParams memory autoParams = IDeBridgeGate.SubmissionParams({
            executionFee: 0,
            flags: 0,
            fallbackAddress: abi.encodePacked(address(this)),
            data: ""
        });
        
        // Bridge USDC to Arbitrum
        debridge.send{value: 0}(
            address(USDC),            // Token to send
            amount,                   // Amount to bridge
            ARBITRUM_CHAIN_ID,       // Destination chain (Arbitrum)
            abi.encodePacked(address(this)),  // Receiver
            "",                      // Native token to receive
            permitData,              // Permit data
            false,                   // Use async
            0,                       // Referral code
            autoParams               // Auto params
        );
        
        return amount;  // Return bridged amount
    }

    function _bridgeBackToSonic(uint256 amount) internal returns (uint256) {
        ARB_USDC.safeApprove(address(debridge), amount);
        
        bytes memory permitData = "";  // Add permit data if needed
        
        IDeBridgeGate.SubmissionParams memory autoParams = IDeBridgeGate.SubmissionParams({
            executionFee: 0,
            flags: 0,
            fallbackAddress: abi.encodePacked(address(this)),
            data: ""
        });
        
        // Bridge back to Sonic
        debridge.send{value: 0}(
            address(ARB_USDC),       // Token to send
            amount,                  // Amount to bridge
            0,                       // Destination chain (Sonic)
            abi.encodePacked(address(this)),  // Receiver
            "",                      // Native token to receive
            permitData,              // Permit data
            false,                   // Use async
            0,                       // Referral code
            autoParams               // Auto params
        );
        
        return amount;  // Return bridged amount
    }

    function _swapWSonicToUSDC(uint256 amount) internal returns (uint256) {
        require(amount > 0, "Zero amount");
        
        IERC20(address(wrappedSonic)).safeApprove(address(debridge), amount);
        
        IDeBridgeGate.SwapDescription memory desc = IDeBridgeGate.SwapDescription({
            srcToken: address(wrappedSonic),
            dstToken: address(USDC),
            srcReceiver: address(this),
            dstReceiver: address(this),
            amount: amount,
            minReturnAmount: 0,
            guaranteedAmount: 0,
            flags: 0,
            referrer: address(0),
            permit: ""
        });

        return debridge.swap(address(this), desc, new bytes[](0));
    }

    function _swapUSDCToWSonic(uint256 amount) internal returns (uint256) {
        require(amount > 0, "Zero amount");
        
        USDC.safeApprove(address(debridge), amount);
        
        IDeBridgeGate.SwapDescription memory desc = IDeBridgeGate.SwapDescription({
            srcToken: address(USDC),
            dstToken: address(wrappedSonic),
            srcReceiver: address(this),
            dstReceiver: address(this),
            amount: amount,
            minReturnAmount: 0,
            guaranteedAmount: 0,
            flags: 0,
            referrer: address(0),
            permit: ""
        });

        return debridge.swap(address(this), desc, new bytes[](0));
    }

    // Admin functions
    function setPaused(bool _paused) external onlyRole(STRATEGIST_ROLE) {
        paused = _paused;
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Withdraw from both protocols
        aavePool.withdraw(address(ARB_USDC), type(uint256).max, address(this));
        beefyVault.withdrawAll();
        
        // Bridge back from Arbitrum if needed
        uint256 arbBalance = ARB_USDC.balanceOf(address(this));
        if (arbBalance > 0) {
            _bridgeBackToSonic(arbBalance);
        }
        
        // Transfer all tokens to admin
        uint256 usdcBalance = USDC.balanceOf(address(this));
        if (usdcBalance > 0) {
            USDC.safeTransfer(msg.sender, usdcBalance);
        }
        
        uint256 wsonicBalance = IERC20(address(wrappedSonic)).balanceOf(address(this));
        if (wsonicBalance > 0) {
            IERC20(address(wrappedSonic)).safeTransfer(msg.sender, wsonicBalance);
        }
    }
} 