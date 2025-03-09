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
import "./interfaces/ISFC.sol";
import "./interfaces/IBeefyVaultV7.sol";
import "./interfaces/IStrategyV7.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IOriginSonic.sol";
import "./interfaces/ILendingProtocol.sol";
import "./interfaces/IDeBridgeGate.sol";

contract SonicBeefyFarmStrategy is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant STRATEGIST_ROLE = keccak256("STRATEGIST_ROLE");
    
    IBeefyVaultV7 public beefyVault;
    IStrategyV7 public beefyStrategy;
    ISFC public immutable sfc;
    IWrappedSonic public immutable wrappedSonic;
    IERC20 public immutable USDC;
    IDeBridgeGate public immutable debridge;
    
    uint256 public defaultValidatorId;
    uint256 public nextWithdrawId;
    uint256 public pendingWithdrawals;
    bool public paused;

    struct WithdrawRequest {
        uint256 validatorId;
        uint256 undelegatedAmount;
        uint256 timestamp;
    }
    
    mapping(uint256 => WithdrawRequest) public withdrawals;
    
    event Staked(uint256 indexed validatorId, uint256 amount);
    event Unstaked(uint256 indexed validatorId, uint256 wrID, uint256 amount);
    event Withdrawn(uint256 indexed wrID, uint256 validatorId, uint256 amount);
    event RewardsClaimed(uint256 indexed validatorId, uint256 amount);
    event RewardsRestaked(uint256 indexed validatorId, uint256 amount);
    event StrategyUpdated(address newStrategy);
    event Harvested(uint256 amount);
    event EmergencyWithdrawn(uint256 amount);
    event BeefyDeposited(uint256 amount);
    event BeefyWithdrawn(uint256 shares, uint256 amount);
    event BeefyEarned();
    event StrategyHarvested();

    modifier onlyVault() {
        require(hasRole(VAULT_ROLE, msg.sender), "Not vault");
        _;
    }

    modifier onlyStrategist() {
        require(hasRole(STRATEGIST_ROLE, msg.sender), "Not strategist");
        _;
    }

    constructor(
        address _vault,
        address _sfc,
        address _wrappedSonic,
        uint256 _defaultValidatorId,
        address _beefyVault,
        address _usdc,
        address _deBridge
    ) {
        require(_beefyVault != address(0), "Zero beefy vault");
        require(_deBridge != address(0), "Zero deBridge");
        require(_usdc != address(0), "Zero USDC");
        
        beefyVault = IBeefyVaultV7(_beefyVault);
        beefyStrategy = IStrategyV7(beefyVault.strategy());
        
        sfc = ISFC(_sfc);
        wrappedSonic = IWrappedSonic(_wrappedSonic);
        defaultValidatorId = _defaultValidatorId;
        USDC = IERC20(_usdc);
        debridge = IDeBridgeGate(_deBridge);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ROLE, _vault);
        _grantRole(STRATEGIST_ROLE, msg.sender);
    }

    function stake(uint256 amount) external onlyVault nonReentrant {
        require(amount > 0, "Zero amount");
        
        // Unwrap wSonic to Sonic
        IERC20(address(wrappedSonic)).safeTransferFrom(msg.sender, address(this), amount);
        wrappedSonic.withdraw(amount);
        
        // Delegate to validator
        sfc.delegate{value: amount}(defaultValidatorId);
        
        emit Staked(defaultValidatorId, amount);
    }

    function unstake(uint256 amount) external onlyVault nonReentrant returns (uint256 withdrawId) {
        require(amount > 0, "Zero amount");
        uint256 stakedAmount = sfc.getStake(address(this), defaultValidatorId);
        require(stakedAmount >= amount, "Insufficient stake");

        withdrawId = nextWithdrawId++;
        
        withdrawals[withdrawId] = WithdrawRequest({
            validatorId: defaultValidatorId,
            undelegatedAmount: amount,
            timestamp: block.timestamp
        });
        
        pendingWithdrawals += amount;
        
        sfc.undelegate(defaultValidatorId, withdrawId, amount);
        
        emit Unstaked(defaultValidatorId, withdrawId, amount);
    }

    function withdrawFromSFC(uint256 withdrawId) external onlyVault nonReentrant {
        require(withdrawId < nextWithdrawId, "Invalid withdrawId");
        WithdrawRequest storage request = withdrawals[withdrawId];
        require(request.undelegatedAmount > 0, "Already withdrawn");
        
        uint256 amountBefore = address(this).balance;
        sfc.withdraw(request.validatorId, withdrawId);
        uint256 withdrawnAmount = address(this).balance - amountBefore;
        
        pendingWithdrawals -= request.undelegatedAmount;
        request.undelegatedAmount = 0;
        
        // Wrap Sonic to wSonic and send to vault
        wrappedSonic.deposit{value: withdrawnAmount}();
        IERC20(address(wrappedSonic)).safeTransfer(msg.sender, withdrawnAmount);
        
        emit Withdrawn(withdrawId, request.validatorId, withdrawnAmount);
    }

    function claimRewards(bool restake) external onlyVault nonReentrant {
        uint256 rewardsBefore = address(this).balance;
        
        if (restake) {
            sfc.restakeRewards(defaultValidatorId);
            uint256 rewards = sfc.pendingRewards(address(this), defaultValidatorId);
            emit RewardsRestaked(defaultValidatorId, rewards);
        } else {
            sfc.claimRewards(defaultValidatorId);
            uint256 rewardsAmount = address(this).balance - rewardsBefore;
            
            if (rewardsAmount > 0) {
                wrappedSonic.deposit{value: rewardsAmount}();
                IERC20(address(wrappedSonic)).safeTransfer(msg.sender, rewardsAmount);
                emit RewardsClaimed(defaultValidatorId, rewardsAmount);
            }
        }
    }

    function getTotalStaked() external view returns (uint256) {
        return sfc.getStake(address(this), defaultValidatorId);
    }

    function getPendingRewards() external view returns (uint256) {
        return sfc.pendingRewards(address(this), defaultValidatorId);
    }

    function _swapWSonicToUSDC(uint256 amount) internal returns (uint256) {
        require(amount > 0, "Zero amount");
        
        // Approve OpenOcean to spend WSONIC
        IERC20(address(wrappedSonic)).safeApprove(address(debridge), amount);
        
        // Prepare swap data
        IDeBridgeGate.SwapDescription memory desc = IDeBridgeGate.SwapDescription({
            srcToken: address(wrappedSonic),
            dstToken: address(USDC),
            srcReceiver: address(this),
            dstReceiver: address(this),
            amount: amount,
            minReturnAmount: 0, // Add slippage protection
            guaranteedAmount: 0,
            flags: 0,
            referrer: address(0),
            permit: ""
        });

        // Execute swap through OpenOcean
        return debridge.swap(address(this), desc, new bytes[](0));
    }
    
    function earn() external onlyRole(STRATEGIST_ROLE) nonReentrant {
        require(!paused, "Strategy is paused");
        beefyVault.earn();
        emit BeefyEarned();
    }

    function harvest() external onlyRole(STRATEGIST_ROLE) nonReentrant {
        require(!paused, "Strategy is paused");
        beefyStrategy.harvest();
        emit StrategyHarvested();
    }

    function getPricePerFullShare() external view returns (uint256) {
        return beefyVault.getPricePerFullShare();
    }

    function beefyBalance() external view returns (uint256) {
        return beefyVault.balance();
    }

    function beefyBalanceOf() external view returns (uint256) {
        return beefyVault.balanceOf(address(this));
    }

    function pause() external onlyRole(STRATEGIST_ROLE) {
        paused = true;
        beefyStrategy.pause();
    }

    function unpause() external onlyRole(STRATEGIST_ROLE) {
        paused = false;
        beefyStrategy.unpause();
    }

    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        beefyVault.withdrawAll();
        uint256 balance = IERC20(address(wrappedSonic)).balanceOf(address(this));
        if (balance > 0) {
            IERC20(address(wrappedSonic)).safeTransfer(msg.sender, balance);
            emit EmergencyWithdrawn(balance);
        }
    }

    function totalAssets() public view returns (uint256) {
        return 
            beefyVault.balance() + 
            IERC20(address(wrappedSonic)).balanceOf(address(this)) +
            pendingWithdrawals;
    }

    receive() external payable {
        require(
            msg.sender == address(sfc) || 
            msg.sender == address(wrappedSonic) ||
            msg.sender == address(beefyVault),
            "Invalid sender"
        );
    }

    // Add ILending interface implementation
    function deposit(address asset, uint256 amount) external onlyVault nonReentrant {
        require(asset == address(wrappedSonic), "Invalid asset");
        require(amount > 0, "Zero amount");
        require(!paused, "Strategy is paused");
        
        // Swap WSONIC to USDC.e locally
        uint256 usdcAmount = _swapWSonicToUSDC(amount);
        require(usdcAmount > 0, "Swap failed");
        
        // Get initial balance for actual deposit amount calculation
        uint256 balanceBefore = beefyVault.balance();
        
        // Approve and deposit USDC.e
        USDC.safeApprove(address(beefyVault), usdcAmount);
        beefyVault.deposit(usdcAmount);
        
        // Calculate actual deposited amount
        uint256 actualDeposit = beefyVault.balance() - balanceBefore;
        emit BeefyDeposited(actualDeposit);
    }

    function withdraw(address asset, uint256 amount) external onlyVault nonReentrant {
        require(asset == address(wrappedSonic), "Invalid asset");
        require(amount > 0, "Zero amount");
        
        // Calculate shares to withdraw based on amount
        uint256 shares = (amount * beefyVault.totalSupply()) / beefyVault.balance();
        
        uint256 usdcBefore = USDC.balanceOf(address(this));
        beefyVault.withdraw(shares);
        uint256 usdcAmount = USDC.balanceOf(address(this)) - usdcBefore;
        
        // Swap USDC back to WSONIC
        USDC.safeApprove(address(debridge), usdcAmount);
        
        IDeBridgeGate.SwapDescription memory swapDesc = IDeBridgeGate.SwapDescription({
            srcToken: address(USDC),
            dstToken: address(wrappedSonic),
            srcReceiver: address(this),
            dstReceiver: address(this),
            amount: usdcAmount,
            minReturnAmount: 0,
            guaranteedAmount: 0,
            flags: 0,
            referrer: address(0),
            permit: ""
        });
        
        uint256 wsonicAmount = debridge.swap(address(this), swapDesc, new bytes[](0));
        
        // Transfer WSONIC back to vault
        IERC20(address(wrappedSonic)).safeTransfer(msg.sender, wsonicAmount);
        
        emit BeefyWithdrawn(shares, wsonicAmount);
    }

    // Add this function to implement ILending interface
    function getBalance(address asset) external view returns (uint256) {
        require(asset == address(wrappedSonic), "Invalid asset");
        return beefyVault.balance();
    }
}
