// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IBeefyVault.sol";
import "./interfaces/IAavePool.sol";
import "./interfaces/IDebridgeGateway.sol";
import "./interfaces/IWrappedNative.sol";
import "./interfaces/IOracle.sol";

contract AaveSonicBeefyStrategy is IStrategy, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    address public immutable override vault;
    IERC20 public immutable want;
    IAavePool public immutable aavePool;
    IDebridgeGateway public immutable deBridge;
    IBeefyVault public immutable beefyVault;
    IWrappedNative public immutable wrappedNative;
    
    uint256 public totalSupplied;
    uint256 public totalBorrowed;
    uint256 public constant MAX_BPS = 10000; // 100%
    uint256 public borrowRatioBps = 7500; // 75% default borrow ratio
    uint256 public destinationChainId;
    
    // Token mapping across chains
    struct TokenInfo {
        address sourceToken;      // Token on source chain
        address destToken;        // Token on destination chain
        uint256 minAmount;       // Minimum amount to bridge
        uint256 maxAmount;       // Maximum amount to bridge
    }

    IOracle public immutable priceOracle;
    mapping(uint256 => TokenInfo) public chainTokens;  // chainId => TokenInfo
    
    event Supplied(uint256 amount);
    event Borrowed(uint256 amount);
    event BridgedToDestination(
        uint256 amount, 
        uint256 chainId, 
        uint256 sourcePrice,
        address destToken
    );
    event Deposited(uint256 amount);
    event Withdrawn(uint256 amount);
    event Repaid(uint256 amount);
    event BorrowRatioUpdated(uint256 newRatio);

    constructor(
        address _vault,
        address _want,
        address _aavePool,
        address _deBridge,
        address _beefyVault,
        address _wrappedNative,
        address _priceOracle,
        uint256 _destinationChainId,
        address _destToken
    ) {
        require(_vault != address(0), "Invalid vault");
        require(_want != address(0), "Invalid want token");
        require(_aavePool != address(0), "Invalid Aave pool");
        require(_deBridge != address(0), "Invalid deBridge");
        require(_beefyVault != address(0), "Invalid Beefy vault");
        
        vault = _vault;
        want = IERC20(_want);
        aavePool = IAavePool(_aavePool);
        deBridge = IDebridgeGateway(_deBridge);
        beefyVault = IBeefyVault(_beefyVault);
        wrappedNative = IWrappedNative(_wrappedNative);
        destinationChainId = _destinationChainId;
        priceOracle = IOracle(_priceOracle);
        chainTokens[_destinationChainId] = TokenInfo({
            sourceToken: _want,
            destToken: _destToken,
            minAmount: 1e18,      // 1 token minimum
            maxAmount: 1000e18    // 1000 tokens maximum
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_ROLE, _vault);
        _grantRole(MANAGER_ROLE, msg.sender);
    }

    function beforeDeposit() external view override {
        checkHealthFactor();
    }

    function getTokenPrice(address token) public view returns (uint256) {
        return priceOracle.getPrice(token);
    }

    function deposit() external override onlyRole(VAULT_ROLE) {
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal > 0) {
            // First supply to Aave
            want.safeApprove(address(aavePool), wantBal);
            aavePool.supply(address(want), wantBal, address(this), 0);
            totalSupplied += wantBal;
            emit Supplied(wantBal);

            // Then borrow based on ratio
            uint256 borrowAmount = (wantBal * borrowRatioBps) / MAX_BPS;
            require(borrowAmount >= chainTokens[destinationChainId].minAmount, "Amount too low");
            require(borrowAmount <= chainTokens[destinationChainId].maxAmount, "Amount too high");

            // Get price before bridging
            uint256 sourcePrice = getTokenPrice(address(want));
            
            // Bridge with token info
            want.safeApprove(address(deBridge), borrowAmount);
            deBridge.send(
                address(want),
                borrowAmount,
                destinationChainId,
                address(this),
                abi.encode(sourcePrice, chainTokens[destinationChainId].destToken)
            );
            
            emit BridgedToDestination(
                borrowAmount, 
                destinationChainId, 
                sourcePrice,
                chainTokens[destinationChainId].destToken
            );

            // Finally deposit bridged amount to Beefy on destination chain
            // Note: This will happen on the destination chain after bridge
            emit Deposited(borrowAmount);

            totalBorrowed += borrowAmount;
        }
    }

    function withdraw(uint256 _amount) external override onlyRole(VAULT_ROLE) {
        require(_amount > 0, "Zero amount");
        
        // First withdraw from Beefy on destination chain and bridge back
        uint256 borrowedToRepay = (_amount * totalBorrowed) / totalSupplied;
        if (borrowedToRepay > 0) {
            // Note: This assumes funds have been bridged back
            
            // Repay Aave
            want.safeApprove(address(aavePool), borrowedToRepay);
            aavePool.repay(address(want), borrowedToRepay, 2, address(this));
            totalBorrowed -= borrowedToRepay;
            emit Repaid(borrowedToRepay);
        }

        // Then withdraw from Aave
        aavePool.withdraw(address(want), _amount, vault);
        totalSupplied -= _amount;
        emit Withdrawn(_amount);
    }

    function balanceOf() external view override returns (uint256) {
        return totalSupplied - totalBorrowed + 
               want.balanceOf(address(this));
        // Note: Beefy balance is on destination chain
    }

    function retireStrat() external override {
        require(msg.sender == vault, "!vault");
        
        // This assumes all funds have been bridged back from destination chain
        
        // Repay all Aave debt
        if (totalBorrowed > 0) {
            want.safeApprove(address(aavePool), totalBorrowed);
            aavePool.repay(address(want), totalBorrowed, 2, address(this));
        }

        // Withdraw all from Aave
        if (totalSupplied > 0) {
            aavePool.withdraw(address(want), totalSupplied, vault);
        }

        // Transfer any remaining balance
        uint256 wantBal = want.balanceOf(address(this));
        if (wantBal > 0) {
            want.safeTransfer(vault, wantBal);
        }
    }

    function checkHealthFactor() public view {
        (,,,,, uint256 healthFactor) = aavePool.getUserAccountData(address(this));
        require(healthFactor >= 1e18, "Unhealthy position");
    }

    function setBorrowRatio(uint256 _newRatio) external onlyRole(MANAGER_ROLE) {
        require(_newRatio <= MAX_BPS, "Invalid ratio");
        borrowRatioBps = _newRatio;
        emit BorrowRatioUpdated(_newRatio);
    }

    function setDestinationChainId(uint256 _chainId) external onlyRole(MANAGER_ROLE) {
        destinationChainId = _chainId;
    }

    function setTokenInfo(
        uint256 chainId,
        address sourceToken,
        address destToken,
        uint256 minAmount,
        uint256 maxAmount
    ) external onlyRole(MANAGER_ROLE) {
        chainTokens[chainId] = TokenInfo({
            sourceToken: sourceToken,
            destToken: destToken,
            minAmount: minAmount,
            maxAmount: maxAmount
        });
    }

    receive() external payable {
        require(
            msg.sender == address(wrappedNative) || 
            msg.sender == address(beefyVault),
            "Invalid sender"
        );
    }
} 