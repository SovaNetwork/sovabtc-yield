# SovaBTC Yield System

A comprehensive Bitcoin yield generation platform built for multi-chain deployment across Ethereum, Base, and Sova Network. The system enables users to deposit various Bitcoin variants (WBTC, cbBTC, tBTC, native sovaBTC) into ERC-4626 compliant yield vaults and earn Bitcoin-denominated yields through professionally managed investment strategies.

## 📋 Table of Contents

- [🚀 Overview](#-overview)
- [🏗️ System Components](#️-system-components)
- [📚 Detailed Documentation](#-detailed-documentation)
- [🌐 Network Deployment](#-network-deployment)
- [🛠️ Development Setup](#️-development-setup)
- [🧪 Testing](#-testing)
- [🔒 Security & Risk Management](#-security--risk-management)
- [📊 Usage Examples](#-usage-examples)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [🔗 Links](#-links)

## 🚀 Overview

The SovaBTC Yield System consists of four core components that work together to provide a seamless Bitcoin yield experience:

- **🏦 SovaBTCYieldVault**: ERC-4626 compliant vault accepting multiple Bitcoin variants
- **🔗 BridgedSovaBTC**: Cross-chain sovaBTC token via Hyperlane protocol  
- **🥩 SovaBTCYieldStaking**: Dual token staking system with symbiotic rewards
- **🔄 RedemptionQueue**: Configurable queue system for managing redemptions

### Key Features

- **Multi-Asset Support**: Accept WBTC, cbBTC, tBTC, and native sovaBTC
- **Professional Yield Generation**: Admin-managed investment strategies
- **Cross-Chain Distribution**: Native sovaBTC on Sova, bridged tokens elsewhere
- **Dual Token Staking**: Symbiotic staking rewards (sovaBTCYield → SOVA → sovaBTC)
- **Queue-Based Redemptions**: Configurable redemption windows for liquidity management
- **Network-Aware Deployment**: Optimized for each target network
- **Enterprise Security**: Role-based access control, pausability, upgradeability

## 🏗️ System Components

### Core Architecture

The system employs a hub-and-spoke model with four main contracts working together:

1. **SovaBTCYieldVault**: Multi-asset Bitcoin yield vault with ERC-4626 compliance
2. **BridgedSovaBTC**: Cross-chain sovaBTC token using Hyperlane's burn-and-mint bridge
3. **SovaBTCYieldStaking**: Dual token staking system with lock periods and multipliers
4. **RedemptionQueue**: Configurable queue system with 24hr windows and daily volume limits

For detailed system architecture and data flows, see **[📖 System Architecture Documentation](./docs/system-architecture.md)**

## 📚 Detailed Documentation

The system documentation has been organized into focused topic pages for better maintainability and understanding:

### Core System Documentation

- **[📖 System Architecture](./docs/system-architecture.md)** - Comprehensive architecture overview with diagrams, core contracts, and data flows
- **[🔗 Multi-Asset Support](./docs/multi-asset-support.md)** - Details on decimal normalization, cross-network assets, and network configurations
- **[🥩 Rewards & Staking System](./docs/rewards-staking.md)** - Dual token staking mechanics, lock periods, and reward calculations  
- **[🔄 Redemption System](./docs/redemption-system.md)** - Queue-based redemption architecture and liquidity management
- **[🧩 Token Composability](./docs/composability.md)** - DeFi integration patterns and yield optimization strategies

### Additional Resources

- **[🚀 Deployment Orchestration](./docs/deployment-orchestration.md)** - Multi-stage deployment guide and network configuration
- **[🔧 Integration Guide](./docs/integration.md)** - How to integrate with your dApp or protocol
- **[🔒 Security Audit](./docs/security.md)** - Security considerations and audit results

## 🌐 Network Deployment

### Supported Networks

| Network | Primary Asset | Additional Assets | Reward Token | Deployment Status |
|---------|--------------|------------------|--------------|-------------------|
| **Ethereum** | WBTC | cbBTC, tBTC, BTCB | Bridged SovaBTC | ✅ Ready |
| **Base** | cbBTC | tBTC, WBTC (bridged) | Bridged SovaBTC | ✅ Ready |
| **Sova Network** | Native sovaBTC | WBTC, cbBTC (bridged) | Native sovaBTC | ✅ Ready |

### Network-Aware Configuration

The deployment script automatically configures contracts based on the target network:

```bash
# Deploy to Ethereum Mainnet
forge script script/DeployStage1_Core.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify

# Deploy to Base
forge script script/DeployStage1_Core.s.sol --rpc-url $BASE_RPC_URL --broadcast --verify

# Deploy to Sova Network  
forge script script/DeployStage1_Core.s.sol --rpc-url $SOVA_RPC_URL --broadcast --verify
```

## 🛠️ Development Setup

### Prerequisites

- [Foundry](https://getfoundry.sh/) (latest version)
- Node.js 16+ and npm
- Git

### Installation

```bash
git clone https://github.com/SovaNetwork/sovabtc-yield.git
cd sovabtc-yield
make setup
```

### Environment Configuration

1. Copy environment template:
```bash
cp .env.example .env
```

2. Configure your `.env` file:
```bash
# Deployment Configuration
PRIVATE_KEY=your_private_key_here
OWNER_ADDRESS=0x...

# Network RPC URLs
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/your-key
BASE_RPC_URL=https://mainnet.base.org
SOVA_RPC_URL=https://rpc.sova.network

# Token Addresses
SOVA_TOKEN_ADDRESS=0x...

# Hyperlane Mailbox Addresses
HYPERLANE_MAILBOX_MAINNET=0x...
HYPERLANE_MAILBOX_BASE=0x...
```

## 🧪 Testing

### Comprehensive Test Suite

The project includes **92 tests** with excellent coverage:

- **SovaBTCYieldVault**: 95%+ coverage
- **SovaBTCYieldStaking**: 84%+ coverage  
- **BridgedSovaBTC**: 86%+ coverage

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
forge test --match-contract SovaBTCYieldSystemTest
forge test --match-contract SovaBTCYieldStakingTest

# Generate detailed coverage report
make coverage

# Run tests with gas reporting
make gas-report
```

### Testnet Deployment

The system includes comprehensive testnet deployment tools with Hyperlane CLI integration:

```bash
# Install Hyperlane CLI
npm install -g @hyperlane-xyz/cli

# Setup testnet environment
cp .env.example .env.testnet
# Edit .env.testnet with your testnet configuration

# Deploy to Sepolia
make deploy-sepolia

# Deploy to Base Sepolia  
make deploy-base-sepolia

# Run comprehensive E2E test
./scripts/comprehensive-test.sh

# Monitor system health
./scripts/health-check.sh
```

**Supported Testnets**: Sepolia (Ethereum), Base Sepolia, Arbitrum Sepolia

📖 **Full Guide**: See [Testnet Deployment Guide](docs/testnet-deployment.md) for detailed instructions.

## 🔒 Security & Risk Management

### Access Control Architecture

**Role-Based Permissions:**
- **SovaBTCYieldVault**: Owner-only functions for asset management and yield distribution
- **BridgedSovaBTC**: Multi-role system (ADMIN, BRIDGE, VAULT, UPGRADER roles)
- **SovaBTCYieldStaking**: Owner-controlled reward rates and funding

### Emergency Controls

- **Pausability**: All contracts can be paused in emergencies
- **Emergency Unstaking**: Users can exit stakes with penalty if needed
- **Upgrade Controls**: UUPS proxy pattern with admin controls

### Security Features

- **Reentrancy Protection**: All external interactions protected
- **Input Validation**: Comprehensive zero-address and zero-amount checks
- **Decimal Normalization**: Prevents precision loss and overflow attacks
- **Cross-Chain Security**: Hyperlane's cryptographic message validation

## 📊 Usage Examples

### For Users

**Deposit Bitcoin Variants:**
```solidity
// Approve and deposit WBTC
IERC20(wbtc).approve(vaultAddress, amount);
uint256 shares = vault.depositAsset(wbtc, amount, msg.sender);
```

**Stake for Rewards:**
```solidity
// 1. Stake vault tokens to earn SOVA
vault.approve(stakingAddress, shares);
staking.stakeVaultTokens(shares, lockPeriod);

// 2. Stake SOVA to earn sovaBTC (requires vault tokens staked)
sova.approve(stakingAddress, sovaAmount);
staking.stakeSova(sovaAmount, lockPeriod);

// 3. Claim rewards
staking.claimRewards();
```

### For Admins

**Manage Yield Generation:**
```solidity
// Withdraw assets for investment strategies
vault.adminWithdraw(asset, amount, destination);

// Add generated yield back to vault
sovaBTC.approve(vaultAddress, yieldAmount);
vault.addYield(yieldAmount);
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`make test`)
4. Ensure code formatting (`make format`)
5. Commit changes (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- [Sova Network](https://sova.network)
- [Documentation](https://docs.sova.network)
- [Discord Community](https://discord.gg/sova)
- [Twitter](https://twitter.com/SovaNetwork)

---

**Built with ❤️ by the Sova Network team**
