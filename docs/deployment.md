# SovaBTC Yield System Deployment Guide

This guide provides step-by-step instructions for deploying the SovaBTC Yield System across supported networks.

## Prerequisites

### Development Environment
- [Foundry](https://getfoundry.sh/) (latest version)
- Node.js 16+ and npm
- Git

### Network Access
- RPC endpoints for target networks
- Private key with sufficient ETH/native tokens for gas
- API keys for contract verification (Etherscan, Basescan)

### Hyperlane Requirements
- Hyperlane Mailbox contract addresses for each network
- Configured Hyperlane domain IDs
- Hyperlane relayer network coverage

## Setup

### 1. Clone and Install
```bash
git clone https://github.com/SovaNetwork/sovabtc-yield.git
cd sovabtc-yield
make setup
```

### 2. Environment Configuration
```bash
cp .env.example .env
# Edit .env with your configuration
```

Required environment variables:
```bash
# Deployment Configuration
PRIVATE_KEY=your_private_key_here
OWNER_ADDRESS=0x...

# Network RPC URLs
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/your-key
BASE_RPC_URL=https://mainnet.base.org
SOVA_RPC_URL=https://rpc.sova.network

# API Keys
ETHERSCAN_API_KEY=your_etherscan_api_key
BASESCAN_API_KEY=your_basescan_api_key

# Hyperlane Configuration
HYPERLANE_MAILBOX_MAINNET=0x...
HYPERLANE_MAILBOX_BASE=0x...
HYPERLANE_MAILBOX_SOVA=0x...

# Token Configuration
SOVA_TOKEN_ADDRESS=0x...
```

### 3. Pre-Deployment Verification
```bash
# Check environment
make check-env

# Run tests
make test

# Verify compilation
make build
```

## Network-Specific Deployments

### Ethereum Mainnet

**Supported Assets**: WBTC, cbBTC, tBTC
**Reward Token**: BridgedSovaBTC

```bash
# Deploy to Ethereum mainnet
make deploy-ethereum

# Or manually:
forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $ETHEREUM_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY
```

**Post-Deployment Configuration**:
```bash
# Add supported assets
cast send <VAULT_ADDRESS> "addSupportedAsset(address,string)" \
    0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 "Wrapped Bitcoin" \
    --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL

# Grant vault role to staking contract
cast send <BRIDGED_SOVABTC_ADDRESS> "grantVaultRole(address)" <VAULT_ADDRESS> \
    --private-key $PRIVATE_KEY --rpc-url $ETHEREUM_RPC_URL
```

### Base Network

**Supported Assets**: cbBTC, tBTC
**Reward Token**: BridgedSovaBTC

```bash
# Deploy to Base network
make deploy-base

# Or manually:
forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $BASE_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY
```

**Post-Deployment Configuration**:
```bash
# Add cbBTC as supported asset
cast send <VAULT_ADDRESS> "addSupportedAsset(address,string)" \
    0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf "Coinbase Wrapped Bitcoin" \
    --private-key $PRIVATE_KEY --rpc-url $BASE_RPC_URL
```

### Sova Network

**Supported Assets**: Native sovaBTC
**Reward Token**: Native sovaBTC

```bash
# Deploy to Sova network
make deploy-sova

# Or manually:
forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $SOVA_RPC_URL \
    --broadcast
```

**Note**: On Sova Network, BridgedSovaBTC is not deployed as the native sovaBTC token is used directly.

## Deployment Script Details

The deployment script (`DeploySovaBTCYieldSystem.s.sol`) automatically:

1. **Detects Network**: Determines if deploying on Sova Network or external chain
2. **Deploys Contracts**: In correct order with proper initialization
3. **Configures Roles**: Sets up access control permissions
4. **Saves Artifacts**: Records deployment addresses and configuration

### Deployment Output

After successful deployment, artifacts are saved to `deployments/yield-system-{chainId}.json`:

```json
{
  "chainId": 1,
  "network": "ethereum",
  "isSovaNetwork": false,
  "blockNumber": 12345678,
  "deployer": "0x...",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "contracts": {
    "bridgedSovaBTC": {
      "address": "0x...",
      "implementation": "0x...",
      "proxy": "ERC1967Proxy"
    },
    "yieldVault": {
      "address": "0x...",
      "implementation": "0x...",
      "proxy": "ERC1967Proxy"
    },
    "yieldStaking": {
      "address": "0x...",
      "implementation": "0x...",
      "proxy": "ERC1967Proxy"
    }
  },
  "configuration": {
    "vaultName": "SovaBTC Yield Vault",
    "vaultSymbol": "sovaBTCYield",
    "hyperlaneMailbox": "0x...",
    "sovaTokenAddress": "0x..."
  }
}
```

## Post-Deployment Verification

### 1. Contract Verification
```bash
# Verify on Etherscan (done automatically with --verify flag)
# Manual verification if needed:
forge verify-contract <CONTRACT_ADDRESS> src/vault/SovaBTCYieldVault.sol:SovaBTCYieldVault \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id 1
```

### 2. Functional Testing
```bash
# Test deposit functionality
cast send <VAULT_ADDRESS> "depositAsset(address,uint256,address)" \
    <ASSET_ADDRESS> <AMOUNT> <RECEIVER> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Test staking functionality
cast send <STAKING_ADDRESS> "stakeVaultTokens(uint256,uint256)" \
    <AMOUNT> <LOCK_PERIOD> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 3. Cross-Chain Testing
```bash
# Test bridging (on non-Sova networks)
cast send <BRIDGED_SOVABTC_ADDRESS> "bridgeToSova(address,uint256)" \
    <RECIPIENT> <AMOUNT> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## Configuration Management

### 1. Asset Management
```bash
# Add supported asset
cast send <VAULT_ADDRESS> "addSupportedAsset(address,string)" \
    <TOKEN_ADDRESS> <TOKEN_NAME> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Remove supported asset
cast send <VAULT_ADDRESS> "removeSupportedAsset(address)" \
    <TOKEN_ADDRESS> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 2. Staking Configuration
```bash
# Set reward rates (vaultToSova, sovaToSovaBTC, dualBonus)
cast send <STAKING_ADDRESS> "setRewardRates(uint256,uint256,uint256)" \
    1000000000000000 500000000000000 12000 \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Add reward tokens
cast send <STAKING_ADDRESS> "addRewards(uint256,uint256)" \
    <SOVA_AMOUNT> <SOVABTC_AMOUNT> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

### 3. Hyperlane Configuration
```bash
# Update Hyperlane mailbox (if needed)
cast send <BRIDGED_SOVABTC_ADDRESS> "setHyperlaneMailbox(address)" \
    <NEW_MAILBOX_ADDRESS> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## Security Considerations

### 1. Multi-Signature Setup

For production deployments, use multi-signature wallets:

```bash
# Deploy with multi-sig as owner
OWNER_ADDRESS=0x... # Multi-sig address
forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $RPC_URL --broadcast
```

### 2. Access Control Verification

```bash
# Verify owner
cast call <CONTRACT_ADDRESS> "owner()" --rpc-url $RPC_URL

# Verify roles
cast call <BRIDGED_SOVABTC_ADDRESS> "hasRole(bytes32,address)" \
    $(cast keccak "VAULT_ROLE") <VAULT_ADDRESS> --rpc-url $RPC_URL
```

### 3. Emergency Procedures

```bash
# Pause contracts in emergency
cast send <CONTRACT_ADDRESS> "pause()" \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Unpause after issue resolution
cast send <CONTRACT_ADDRESS> "unpause()" \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

## Monitoring and Maintenance

### 1. Event Monitoring

Monitor critical events:
- `AssetAdded` / `AssetRemoved` on SovaBTCYieldVault
- `BridgeTransfer` / `BridgeReceive` on BridgedSovaBTC
- `VaultTokensStaked` / `SovaStaked` on SovaBTCYieldStaking

### 2. Health Checks

```bash
# Check vault total assets
cast call <VAULT_ADDRESS> "totalAssets()" --rpc-url $RPC_URL

# Check staking pool balances
cast call <STAKING_ADDRESS> "totalSovaBTCStaked()" --rpc-url $RPC_URL
cast call <STAKING_ADDRESS> "totalSovaStaked()" --rpc-url $RPC_URL

# Check cross-chain balance consistency
cast call <BRIDGED_SOVABTC_ADDRESS> "totalSupply()" --rpc-url $RPC_URL
```

### 3. Upgrade Procedures

```bash
# Upgrade contract implementation
forge script script/UpgradeContracts.s.sol:UpgradeContracts \
    --rpc-url $RPC_URL --broadcast
```

## Troubleshooting

### Common Issues

1. **Deployment Fails**: Check gas limits and network connectivity
2. **Verification Fails**: Ensure correct compiler version and settings
3. **Role Errors**: Verify access control permissions are properly set
4. **Cross-Chain Issues**: Check Hyperlane mailbox addresses and domain IDs

### Getting Help

- GitHub Issues: https://github.com/SovaNetwork/sovabtc-yield/issues
- Discord: https://discord.gg/sova
- Documentation: https://docs.sova.network

## Network-Specific Notes

### Ethereum Mainnet
- Higher gas costs - optimize deployment timing
- Thorough testing on testnets first
- Consider gas price fluctuations

### Base Network
- Lower gas costs than Ethereum
- Fast finality and confirmation times
- cbBTC is primary asset

### Sova Network
- Native sovaBTC integration
- No BridgedSovaBTC deployment needed
- Custom precompile interactions

This deployment guide ensures successful deployment and configuration of the SovaBTC Yield System across all supported networks.