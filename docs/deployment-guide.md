# Deployment Guide

> **Last Updated:** July 30, 2025

This guide provides step-by-step instructions for deploying the SovaBTC Yield System across all supported networks with maximum automation and minimal manual steps.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Deployment Process](#deployment-process)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)
- [Advanced Options](#advanced-options)

## Quick Start

For the fastest deployment experience, follow these steps:

```bash
# 1. Setup environment
make setup

# 2. Configure your .env file
# Edit .env with your private key, RPC URLs, and other settings

# 3. Validate configuration
make validate-env

# 4. Deploy complete system
make deploy-full

# 5. Check deployment status
make deploy-status

# 6. Run health checks
make health-check
```

## Prerequisites

### Required Tools

- **Foundry** - Latest version from [getfoundry.sh](https://getfoundry.sh/)
- **Git** - For repository management
- **curl** - For RPC testing (usually pre-installed)
- **jq** - For JSON processing (optional but recommended)

### Required Accounts & Services

1. **Deployment Account**
   - Ethereum address with sufficient ETH for gas fees
   - Private key for automated deployment
   - Recommended: Use a dedicated deployment account

2. **RPC Endpoints**
   - Ethereum mainnet RPC (Infura, Alchemy, etc.)
   - Base mainnet RPC
   - Sova Network RPC
   - Optional: Testnet RPCs for testing

3. **API Keys** (Optional)
   - Etherscan API key for contract verification
   - Basescan API key for contract verification

### Network Requirements

| Network | Gas Requirements | Notes |
|---------|------------------|-------|
| **Ethereum** | ~0.1 ETH | Higher gas costs |
| **Base** | ~0.01 ETH | Lower gas costs |
| **Sova Network** | Minimal | Native network |

## Environment Setup

### 1. Clone and Setup Repository

```bash
git clone https://github.com/SovaNetwork/sovabtc-yield.git
cd sovabtc-yield
make setup
```

### 2. Configure Environment Variables

The setup creates a `.env` file from the streamlined template. Edit it with your values:

```bash
# Core settings (Required)
PRIVATE_KEY=your_64_character_private_key_without_0x
OWNER_ADDRESS=0x1234567890123456789012345678901234567890
SOVA_TOKEN_ADDRESS=0x1234567890123456789012345678901234567890

# Network RPCs (Required)
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/your-project-id
BASE_RPC_URL=https://mainnet.base.org
SOVA_RPC_URL=https://rpc.sova.network

# Hyperlane Mailboxes (Required)
HYPERLANE_MAILBOX_MAINNET=0x2971b9Aec44507318302683a62f9ba6d99e3f4af
HYPERLANE_MAILBOX_BASE=0x2971b9Aec44507318302683a62f9ba6d99e3f4af
HYPERLANE_MAILBOX_SOVA=0x2971b9Aec44507318302683a62f9ba6d99e3f4af

# Optional: API keys for verification
ETHERSCAN_API_KEY=your_etherscan_api_key
BASESCAN_API_KEY=your_basescan_api_key
```

### 3. Validate Configuration

Before deployment, validate your environment:

```bash
make validate-env
```

This script checks:
- ✅ All required environment variables are set
- ✅ Private key and addresses have correct format
- ✅ RPC connections are working
- ✅ Contract addresses are valid
- ✅ Required tools are installed

## Deployment Process

### Automated Full Deployment (Recommended)

The streamlined deployment process handles everything automatically:

```bash
make deploy-full
```

This single command will:

1. **Validate Environment** - Pre-flight checks
2. **Test RPC Connections** - Verify network connectivity
3. **Deploy Stage 1** - Core contracts on all networks
4. **Deploy Stage 2** - Cross-network configuration
5. **Generate Artifacts** - Save deployment information
6. **Verify Contracts** - Automatic verification on block explorers

### Manual Step-by-Step Process

If you prefer more control, you can deploy manually:

#### Stage 1: Core Contracts

Deploy core contracts on each network:

```bash
# Deploy to all networks
make deploy-ethereum
make deploy-base
make deploy-sova

# Or deploy to individual networks
forge script script/DeployStage1_Core.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast --verify
```

#### Stage 2: Cross-Network Configuration

After all Stage 1 deployments are complete:

```bash
# Deploy Stage 2 on all networks
forge script script/DeployStage2_CrossNetwork.s.sol --rpc-url $ETHEREUM_RPC_URL --broadcast
forge script script/DeployStage2_CrossNetwork.s.sol --rpc-url $BASE_RPC_URL --broadcast
forge script script/DeployStage2_CrossNetwork.s.sol --rpc-url $SOVA_RPC_URL --broadcast
```

### Testnet Deployment

For testing, deploy to testnets first:

```bash
# Deploy to Sepolia
make deploy-sepolia

# Deploy to Base Sepolia
make deploy-base-sepolia

# Check testnet status
make deploy-status
```

## Verification & Testing

### 1. Check Deployment Status

Monitor deployment progress:

```bash
make deploy-status
```

This shows:
- ✅ Contract deployment status on each network
- 📊 Cross-chain connectivity status
- 📈 Deployment completion percentage
- 🔧 Recommended next actions

### 2. Run Health Checks

Verify system functionality:

```bash
make health-check
```

Health checks verify:
- Contract functionality
- Cross-chain messaging
- Token approvals and transfers
- Staking and redemption systems

### 3. End-to-End Testing

Run comprehensive tests:

```bash
make comprehensive-test
```

This executes:
- Multi-asset deposits
- Cross-chain bridging
- Staking scenarios
- Redemption processes

## Troubleshooting

### Common Issues

#### 1. Environment Validation Failures

**Issue**: `validate-env` script fails
```bash
[ERROR] Required variable PRIVATE_KEY is not set
```

**Solution**: 
- Ensure `.env` file exists and is properly configured
- Check that all required variables are set
- Verify private key format (64 hex characters, no 0x prefix)

#### 2. RPC Connection Failures

**Issue**: RPC connection tests fail
```bash
[ERROR] Ethereum RPC connection failed
```

**Solution**:
- Verify RPC URL is correct and accessible
- Check API key limits and quotas
- Try alternative RPC providers
- Test connection manually: `curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $ETHEREUM_RPC_URL`

#### 3. Deployment Failures

**Issue**: Contract deployment fails
```bash
[ERROR] Stage 1 deployment failed on Ethereum
```

**Solution**:
- Check gas fees and account balance
- Verify contract compilation: `forge build`
- Review error messages in forge output
- Ensure all dependencies are installed: `forge install`

#### 4. Cross-Network Configuration Issues

**Issue**: Stage 2 fails with missing artifacts
```bash
[ERROR] Cannot proceed with Stage 2 without Stage 1 artifacts
```

**Solution**:
- Ensure Stage 1 completed successfully on all networks
- Check `deployments/` directory for artifact files
- Re-run Stage 1 if artifacts are missing
- Verify artifact file permissions

### Recovery Procedures

#### Partial Deployment Recovery

If deployment fails partway through:

1. Check status: `make deploy-status`
2. Identify failed networks
3. Re-run deployment for specific networks:
   ```bash
   make deploy-ethereum  # For Ethereum only
   make deploy-base      # For Base only
   make deploy-sova      # For Sova only
   ```

#### Contract Verification Issues

If contract verification fails:

```bash
# Manual verification
forge verify-contract --chain-id 1 --num-of-optimizations 200 --compiler-version v0.8.27 CONTRACT_ADDRESS src/CONTRACT.sol:CONTRACT_NAME --etherscan-api-key $ETHERSCAN_API_KEY
```

#### Clean Restart

For a complete restart:

```bash
make clean
rm -rf deployments/
make deploy-full
```

## Advanced Options

### Network-Specific Deployment

Deploy to individual networks:

```bash
# Mainnet deployments
make deploy-ethereum
make deploy-base
make deploy-sova

# Testnet deployments
make deploy-sepolia
make deploy-base-sepolia
```

### Custom Configuration

Override default settings by modifying environment variables:

```bash
# Custom vault configuration
VAULT_NAME="Custom Bitcoin Yield Vault"
VAULT_SYMBOL="customBTCY"
INITIAL_OWNER=0x...

# Custom network settings
SOVA_CHAIN_ID=123456
```

### Development Mode

For development and testing:

```bash
# Run tests
make test
make coverage

# Development tools
make format
make lint
make build
```

### CI/CD Integration

For automated deployments in CI/CD:

```bash
# Environment validation in CI
make validate-env

# Automated deployment
make deploy-full

# Post-deployment verification
make health-check
```

## Deployment Artifacts

After successful deployment, artifacts are saved in `deployments/`:

```
deployments/
├── stage1-1.json        # Ethereum deployment
├── stage1-8453.json     # Base deployment  
├── stage1-123456.json   # Sova Network deployment
└── ...
```

Each artifact contains:
- Contract addresses
- Deployment block numbers
- Transaction hashes
- Network configuration
- Deployment timestamp

## Security Considerations

### Deployment Security

1. **Private Key Management**
   - Use dedicated deployment accounts
   - Never commit private keys to version control
   - Consider hardware wallets for production
   - Implement proper key rotation

2. **Network Security**
   - Verify RPC endpoint authenticity
   - Use secure connections (HTTPS)
   - Monitor for deployment anomalies
   - Validate all contract addresses

3. **Post-Deployment Security**
   - Transfer ownership to multi-sig wallets
   - Implement proper access controls
   - Set up monitoring and alerting
   - Plan incident response procedures

### Verification Checklist

After deployment, verify:

- [ ] All contracts deployed successfully
- [ ] Contract verification completed on block explorers
- [ ] Cross-chain messaging configured correctly
- [ ] Token approvals and permissions set properly
- [ ] Owner addresses configured correctly
- [ ] Emergency controls functional
- [ ] Monitoring systems active

## Support

For deployment issues:

1. **Check Documentation**: Review this guide and system architecture docs
2. **Run Diagnostics**: Use `make deploy-status` and `make health-check`
3. **Review Logs**: Check deployment artifacts and forge output
4. **Community Support**: Discord community for assistance
5. **Issue Reporting**: GitHub issues for bugs and feature requests

---

**Next Steps**: After successful deployment, see the [Integration Guide](./integration.md) for connecting your applications to the deployed system.