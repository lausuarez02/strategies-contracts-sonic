// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ILending.sol";

interface IOriginSonic {
    function stake(uint256 amount) external;
    function getStakedAmount(address user) external view returns (uint256);
    function unstake(uint256 amount) external;
}

interface ILendingProtocol {
    function depositCollateral(address token, uint256 amount) external;
    function borrow(address token, uint256 amount) external;
    function repay(address token, uint256 amount) external;
    function withdrawCollateral(address token, uint256 amount) external;
}

interface IFarm {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimRewards() external;
}

interface IBeefyVault {
    function deposit(uint256 amount) external;
    function withdraw(uint256 shares) external;
}

interface IOracle {
    function getPrice(address token) external view returns (uint256);
}

contract SonicBeefyFarmStrategy is ILending, AccessControl {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    address public immutable rewardToken;
    mapping(address => uint256) public sonicDeposits;
    address public vault;
    IOriginSonic public originSonic;
    IFarm public farm;
    IBeefyVault public beefyVault;
    IOracle public oracle;
    uint256 public lastRewardTimestamp;
    uint256 public historicalRewards;

    event Deposited(address indexed asset, uint256 amount);
    event Withdrawn(address indexed asset, uint256 amount);
    event Staked(uint256 amount);
    event Unstaked(uint256 amount);
    event RewardsReinvested(uint256 amount);
    event StrategyExited(uint256 amount);
    event SonicStaked(uint256 amount);

    constructor(
        address _originSonic, 
        address _vault,
        address _farm,
        address _beefyVault,
        address _rewardToken
    ) {
        require(_originSonic != address(0), "SonicStrategy: zero sonic address");
        require(_vault != address(0), "SonicStrategy: zero vault address");
        require(_farm != address(0), "SonicStrategy: zero farm address");
        require(_beefyVault != address(0), "SonicStrategy: zero beefy address");
        
        originSonic = IOriginSonic(_originSonic);
        farm = IFarm(_farm);
        beefyVault = IBeefyVault(_beefyVault);
        vault = _vault;
        rewardToken = _rewardToken;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ROLE, _vault);
    }

    modifier onlyVault() {
        require(hasRole(VAULT_ROLE, msg.sender), "SonicStrategy: only vault");
        _;
    }

    // ILending interface implementation
    function deposit(address asset, uint256 amount) external override onlyVault {
        require(amount > 0, "SonicStrategy: zero amount");
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        sonicDeposits[asset] += amount;
        emit Deposited(asset, amount);
    }

    function withdraw(address asset, uint256 amount) external override onlyVault {
        require(amount > 0, "SonicStrategy: zero amount");
        require(amount <= sonicDeposits[asset], "SonicStrategy: insufficient balance");
        IERC20(asset).safeTransfer(vault, amount);
        sonicDeposits[asset] -= amount;
        emit Withdrawn(asset, amount);
    }

    function getBalance(address asset) external view override returns (uint256) {
        return sonicDeposits[asset];
    }

    // Sonic-specific functionality
    function claimAndReinvest() external onlyVault {
        uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
        
        farm.claimRewards();
        
        uint256 rewardAmount = IERC20(rewardToken).balanceOf(address(this)) - balanceBefore;
        uint256 rewardValue = (rewardAmount * oracle.getPrice(rewardToken)) / 1e18;
        
        // Update historical data
        historicalRewards += rewardValue;
        lastRewardTimestamp = block.timestamp;

        // Reinvest logic
        if (rewardAmount > 0) {
            IERC20(rewardToken).approve(address(originSonic), 0); // Reset allowance
            IERC20(rewardToken).approve(address(originSonic), rewardAmount);
            originSonic.stake(rewardAmount);
            farm.deposit(rewardAmount);
            beefyVault.deposit(rewardAmount);
        }

        emit RewardsReinvested(rewardAmount);
    }

    function exitStrategy(uint256 amount) external onlyVault {
        require(amount > 0, "SonicStrategy: zero amount");
        beefyVault.withdraw(amount);
        farm.withdraw(amount);
        originSonic.unstake(amount);
        emit StrategyExited(amount);
    }

    function stakeSonic(uint256 amount) external onlyVault {
        require(amount > 0, "SonicStrategy: zero amount");
        originSonic.stake(amount);
        farm.deposit(amount);
        beefyVault.deposit(amount);
        emit SonicStaked(amount);
    }

    // View function for APY calculation
    function getAPY() external view returns (uint256) {
        uint256 totalValue = getTotalValue();
        if (totalValue == 0) return 0;

        uint256 timeDelta = block.timestamp - lastRewardTimestamp;
        if (timeDelta == 0) return 0;

        // Calculate annualized returns
        // (historicalRewards * 365 days) / (timeDelta * totalValue)
        return (historicalRewards * 365 days * 1e18) / (timeDelta * totalValue);
    }

    function getTotalValue() public view returns (uint256) {
        uint256 totalStaked = originSonic.getStakedAmount(address(this));
        return (totalStaked * oracle.getPrice(address(rewardToken))) / 1e18;
    }
}
