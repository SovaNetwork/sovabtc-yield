# SovaBTC Yield System Integration Guide

This guide provides comprehensive instructions for integrating the SovaBTC Yield System into your DeFi application or protocol.

## Table of Contents

- [Quick Start](#quick-start)
- [ERC-4626 Integration](#erc-4626-integration)
- [Cross-Chain Integration](#cross-chain-integration)
- [DeFi Composability Examples](#defi-composability-examples)
- [Security Considerations](#security-considerations)
- [Network Deployment Addresses](#network-deployment-addresses)

## Quick Start

The SovaBTC Yield System is built around ERC-4626 standard compliance, making it compatible with most DeFi protocols.

### Basic Integration

```solidity
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YourDeFiProtocol {
    IERC4626 public immutable sovaBTCVault;
    IERC20 public immutable sovaBTCYield;
    
    constructor(address _vault) {
        sovaBTCVault = IERC4626(_vault);
        sovaBTCYield = IERC20(_vault); // Vault token is also ERC-20
    }
    
    function depositToVault(uint256 assets) external {
        // Transfer assets from user
        IERC20(sovaBTCVault.asset()).transferFrom(msg.sender, address(this), assets);
        
        // Deposit to vault and receive shares
        uint256 shares = sovaBTCVault.deposit(assets, msg.sender);
    }
}
```

## ERC-4626 Integration

### Standard ERC-4626 Functions

The SovaBTCYieldVault implements all standard ERC-4626 functions:

```solidity
interface ISovaBTCYieldVault is IERC4626 {
    // Standard ERC-4626 functions
    function asset() external view returns (address); // Underlying Bitcoin asset
    function totalAssets() external view returns (uint256); // Total assets under management
    function convertToShares(uint256 assets) external view returns (uint256); // Asset to share conversion
    function convertToAssets(uint256 shares) external view returns (uint256); // Share to asset conversion
    
    // Deposit/Withdrawal functions
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    
    // Preview functions for gas estimation
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
}
```

### Multi-Asset Deposits

The vault supports multiple Bitcoin variants on each network:

```solidity
contract MultiAssetIntegration {
    function depositDifferentBitcoinAssets(
        address vault,
        address wbtc,
        address cbbtc,
        uint256 wbtcAmount,
        uint256 cbbtcAmount
    ) external {
        ISovaBTCYieldVault vaultContract = ISovaBTCYieldVault(vault);
        
        // Deposit WBTC (8 decimals)
        IERC20(wbtc).approve(vault, wbtcAmount);
        vaultContract.depositAsset(wbtc, wbtcAmount, msg.sender);
        
        // Deposit cbBTC (8 decimals) 
        IERC20(cbbtc).approve(vault, cbbtcAmount);
        vaultContract.depositAsset(cbbtc, cbbtcAmount, msg.sender);
    }
}
```

### Yield Tracking

```solidity
contract YieldTracker {
    function getCurrentYield(address vault, address user) external view returns (uint256) {
        ISovaBTCYieldVault vaultContract = ISovaBTCYieldVault(vault);
        
        uint256 userShares = IERC20(vault).balanceOf(user);
        uint256 currentAssetValue = vaultContract.convertToAssets(userShares);
        
        // Compare to historical deposits to calculate yield
        return currentAssetValue; // Simplified example
    }
    
    function getExchangeRate(address vault) external view returns (uint256) {
        return ISovaBTCYieldVault(vault).getCurrentExchangeRate();
    }
}
```

## Cross-Chain Integration

### Bridge Integration

```solidity
interface IBridgedSovaBTC {
    function bridgeToSova(address recipient, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract CrossChainYieldAggregator {
    mapping(uint256 => address) public chainVaults; // chainId => vault address
    mapping(uint256 => address) public chainBridges; // chainId => bridge address
    
    function bridgeAndDeposit(uint256 targetChainId, uint256 amount) external {
        address bridge = chainBridges[block.chainid];
        require(bridge != address(0), "Bridge not supported");
        
        // Bridge tokens to Sova Network
        IBridgedSovaBTC(bridge).bridgeToSova(msg.sender, amount);
        
        // Note: Actual deposit would happen on Sova Network after bridge completion
    }
}
```

### Network-Aware Deployment

```solidity
library NetworkDetection {
    uint256 public constant ETHEREUM_MAINNET = 1;
    uint256 public constant BASE_MAINNET = 8453;
    uint256 public constant SOVA_NETWORK = 123456; // Example chain ID
    
    function getRewardToken(uint256 chainId) internal pure returns (address) {
        if (chainId == SOVA_NETWORK) {
            return NATIVE_SOVABTC; // Native sovaBTC on Sova Network
        } else {
            return BRIDGED_SOVABTC; // BridgedSovaBTC on external chains
        }
    }
}
```

## DeFi Composability Examples

### 1. Automated Market Maker Integration

```solidity
// Example: Create sovaBTCYield/WETH pool on Uniswap V3
contract UniswapV3Integration {
    IUniswapV3Factory public constant factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    
    function createSovaBTCYieldPool(
        address sovaBTCYield,
        address weth,
        uint24 fee
    ) external returns (address pool) {
        pool = factory.createPool(sovaBTCYield, weth, fee);
        
        // Initialize pool with starting price
        IUniswapV3Pool(pool).initialize(encodePriceSqrt(1, 1)); // 1:1 example
    }
    
    function addLiquidity(
        address pool,
        uint256 sovaBTCYieldAmount,
        uint256 wethAmount
    ) external {
        // Implementation for adding liquidity to pool
        // ... liquidity provision logic
    }
}
```

### 2. Lending Protocol Integration

```solidity
// Example: Use sovaBTCYield as collateral in lending protocols
contract CompoundIntegration {
    ICToken public cSovaBTCYield; // Compound cToken for sovaBTCYield
    
    function supplySovaBTCYieldAsCollateral(uint256 amount) external {
        address sovaBTCYield = address(cSovaBTCYield.underlying());
        
        // Transfer sovaBTCYield tokens
        IERC20(sovaBTCYield).transferFrom(msg.sender, address(this), amount);
        
        // Approve and supply to Compound
        IERC20(sovaBTCYield).approve(address(cSovaBTCYield), amount);
        require(cSovaBTCYield.mint(amount) == 0, "Supply failed");
    }
    
    function borrowAgainstSovaBTCYield(address cTokenToBorrow, uint256 amount) external {
        require(ICToken(cTokenToBorrow).borrow(amount) == 0, "Borrow failed");
    }
}
```

### 3. Yield Aggregator Integration

```solidity
contract YieldFarmIntegration {
    address public sovaBTCVault;
    address public stakingContract;
    
    function maxYieldStrategy(uint256 amount) external {
        // 1. Deposit to vault for yield
        uint256 shares = ISovaBTCYieldVault(sovaBTCVault).deposit(amount, address(this));
        
        // 2. Stake vault tokens for additional SOVA rewards
        IERC20(sovaBTCVault).approve(stakingContract, shares);
        ISovaBTCYieldStaking(stakingContract).stakeVaultTokens(shares, 30 days);
        
        // 3. Compound SOVA rewards for maximum yield
        ISovaBTCYieldStaking(stakingContract).compoundSovaRewards();
    }
}
```

### 4. Flash Loan Integration

```solidity
contract FlashLoanArbitrage {
    function executeArbitrage(uint256 flashAmount) external {
        // 1. Take flash loan
        // 2. Use sovaBTCYield for arbitrage opportunities
        // 3. Repay flash loan with profit
        
        address vault = getSovaBTCVault();
        uint256 shares = ISovaBTCYieldVault(vault).deposit(flashAmount, address(this));
        
        // Execute arbitrage strategy
        // ...
        
        // Withdraw and repay
        ISovaBTCYieldVault(vault).redeem(shares, address(this), address(this));
    }
}
```

## Security Considerations

### 1. Slippage Protection

```solidity
contract SlippageProtection {
    function depositWithSlippageProtection(
        address vault,
        uint256 assets,
        uint256 minShares
    ) external {
        uint256 shares = ISovaBTCYieldVault(vault).deposit(assets, msg.sender);
        require(shares >= minShares, "Slippage too high");
    }
}
```

### 2. Emergency Pause Handling

```solidity
contract EmergencyHandling {
    function safeDopsit(address vault, uint256 amount) external {
        require(!IPausable(vault).paused(), "Vault is paused");
        ISovaBTCYieldVault(vault).deposit(amount, msg.sender);
    }
}
```

### 3. Access Control Integration

```solidity
contract RoleBasedAccess {
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    
    function adminDeposit(address vault, uint256 amount) external {
        require(hasRole(VAULT_MANAGER_ROLE, msg.sender), "Not authorized");
        ISovaBTCYieldVault(vault).deposit(amount, msg.sender);
    }
}
```

## Network Deployment Addresses

### Mainnet Deployments (Example)

```solidity
contract NetworkAddresses {
    // Ethereum Mainnet
    address public constant ETHEREUM_VAULT = 0x...; // SovaBTCYieldVault
    address public constant ETHEREUM_BRIDGE = 0x...; // BridgedSovaBTC
    address public constant ETHEREUM_STAKING = 0x...; // SovaBTCYieldStaking
    
    // Base Mainnet  
    address public constant BASE_VAULT = 0x...; // SovaBTCYieldVault
    address public constant BASE_BRIDGE = 0x...; // BridgedSovaBTC
    address public constant BASE_STAKING = 0x...; // SovaBTCYieldStaking
    
    // Sova Network
    address public constant SOVA_VAULT = 0x...; // SovaBTCYieldVault
    address public constant SOVA_STAKING = 0x...; // SovaBTCYieldStaking
    // Note: No bridge contract on Sova Network (native sovaBTC used)
}
```

### Testnet Deployments

See [testnet deployment guide](./testnet-deployment.md) for current testnet addresses.

## Advanced Integration Patterns

### 1. Multi-Network Yield Optimization

```solidity
contract MultiNetworkOptimizer {
    struct NetworkInfo {
        address vault;
        address bridge;
        uint256 currentAPY;
        uint256 bridgeCost;
    }
    
    mapping(uint256 => NetworkInfo) public networks;
    
    function optimizeAcrossNetworks(uint256 amount) external {
        // Calculate optimal network based on APY and bridge costs
        uint256 bestNetwork = findBestNetwork(amount);
        
        if (bestNetwork != block.chainid) {
            // Bridge to optimal network
            bridgeToNetwork(bestNetwork, amount);
        } else {
            // Deposit on current network
            depositLocally(amount);
        }
    }
}
```

### 2. Liquidation Protection

```solidity
contract LiquidationProtection {
    function protectedBorrow(
        address vault,
        uint256 collateralAmount,
        uint256 borrowAmount,
        uint256 liquidationThreshold
    ) external {
        // Deposit collateral
        uint256 shares = ISovaBTCYieldVault(vault).deposit(collateralAmount, address(this));
        
        // Monitor collateral ratio
        require(calculateCollateralRatio(shares, borrowAmount) > liquidationThreshold, "Unsafe ratio");
        
        // Execute borrow
        // ...
    }
}
```

## Testing Integration

### Local Testing Setup

```javascript
// Example Hardhat test
describe("SovaBTC Integration", function() {
    let vault, token, user;
    
    beforeEach(async function() {
        // Deploy contracts
        vault = await deploySovaBTCVault();
        token = await deployMockWBTC();
        [user] = await ethers.getSigners();
    });
    
    it("Should integrate with ERC-4626 vault", async function() {
        const amount = ethers.utils.parseEther("1");
        
        // Approve and deposit
        await token.approve(vault.address, amount);
        const shares = await vault.deposit(amount, user.address);
        
        expect(shares).to.be.gt(0);
    });
});
```

## Support and Resources

- **GitHub Repository**: https://github.com/SovaNetwork/sovabtc-yield
- **Technical Documentation**: [TECHNICAL_SPEC.md](../TECHNICAL_SPEC.md)
- **Deployment Guide**: [deployment.md](./deployment.md)
- **Discord Support**: https://discord.gg/sova

## Security Audits

Before integrating in production:
1. Review all smart contract code
2. Conduct thorough testing on testnets
3. Consider professional security audits
4. Implement monitoring and alerting
5. Have emergency procedures ready

This integration guide provides the foundation for building on top of the SovaBTC Yield System. For specific use cases or custom integrations, please reach out to the Sova Network team.