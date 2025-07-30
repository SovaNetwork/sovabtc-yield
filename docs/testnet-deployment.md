# SovaBTC Yield System Testnet Deployment Guide

This guide provides comprehensive instructions for deploying and testing the SovaBTC Yield System on various testnets, including Hyperlane CLI integration for cross-chain functionality.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Hyperlane Integration](#hyperlane-integration)
- [Testnet Deployments](#testnet-deployments)
- [Cross-Chain Testing](#cross-chain-testing)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Development Tools
```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Node.js and npm
# Required for Hyperlane CLI
node --version  # >= 16.0.0
npm --version

# Install Hyperlane CLI
npm install -g @hyperlane-xyz/cli
# or locally: npm install @hyperlane-xyz/cli
```

### Testnet Tokens
Obtain testnet tokens from faucets:
- **Sepolia ETH**: https://sepolia-faucet.pk910.de/
- **Base Sepolia ETH**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Arbitrum Sepolia ETH**: https://faucet.quicknode.com/arbitrum/sepolia

### API Keys
- **Etherscan API**: https://etherscan.io/apis
- **Basescan API**: https://basescan.org/apis
- **Arbiscan API**: https://arbiscan.io/apis

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/SovaNetwork/sovabtc-yield.git
cd sovabtc-yield
make setup
```

### 2. Configure Environment
```bash
cp .env.example .env.testnet
```

Edit `.env.testnet` with testnet configuration:
```bash
# Deployment Configuration
PRIVATE_KEY=your_testnet_private_key_here
OWNER_ADDRESS=0x... # Your deployer address

# Testnet RPC URLs
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-key
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc

# API Keys for Verification
ETHERSCAN_API_KEY=your_etherscan_api_key
BASESCAN_API_KEY=your_basescan_api_key
ARBISCAN_API_KEY=your_arbiscan_api_key

# Hyperlane Configuration (Testnet)
HYPERLANE_MAILBOX_SEPOLIA=0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766
HYPERLANE_MAILBOX_BASE_SEPOLIA=0xfFAEF09B3cd11D9b20d1a19bECCA54EEC2884766
HYPERLANE_MAILBOX_ARBITRUM_SEPOLIA=0xfFAEF09B3cd11D9b20d1a19bECCA54EEC2884766

# Mock Token Addresses (Deploy these first)
MOCK_WBTC_SEPOLIA=0x...
MOCK_CBBTC_BASE_SEPOLIA=0x...
MOCK_TBTC_ARBITRUM_SEPOLIA=0x...

# Mock SOVA Token (Deploy this first)
SOVA_TOKEN_SEPOLIA=0x...
SOVA_TOKEN_BASE_SEPOLIA=0x...
SOVA_TOKEN_ARBITRUM_SEPOLIA=0x...
```

### 3. Pre-Deployment Setup
```bash
# Load testnet environment
source .env.testnet

# Verify setup
make test
make build

# Check balances
cast balance $OWNER_ADDRESS --rpc-url $SEPOLIA_RPC_URL
cast balance $OWNER_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL
```

## Hyperlane Integration

### 1. Install and Configure Hyperlane CLI
```bash
# Set deployer private key for Hyperlane
export HYP_KEY=$PRIVATE_KEY

# Initialize Hyperlane configuration
hyperlane config init
```

### 2. Configure Chain Metadata
Create custom chain configurations if testing on custom networks:

```bash
# Create chain config directory
mkdir -p ~/.hyperlane/chains/custom-testnet

# Create metadata.yaml
cat > ~/.hyperlane/chains/custom-testnet/metadata.yaml << EOF
chainId: 1337
domainId: 1337
name: custom-testnet
protocol: ethereum
rpcUrls:
  - http: http://localhost:8545
nativeToken:
  name: Ether
  symbol: ETH
  decimals: 18
blocks:
  confirmations: 1
  estimateBlockTime: 12
EOF
```

### 3. Deploy Hyperlane Core Contracts (Optional)
If testing on networks without existing Hyperlane infrastructure:

```bash
# Deploy core Hyperlane contracts
hyperlane core deploy --chain custom-testnet

# Initialize ISM (Interchain Security Module)
hyperlane core init --chain custom-testnet
```

### 4. Configure Warp Routes
For cross-chain token transfers:

```bash
# Create warp route configuration
hyperlane warp init

# Deploy warp route contracts
hyperlane warp deploy --config ./warp-route-config.yaml
```

## Testnet Deployments

### Sepolia (Ethereum Testnet)

#### 1. Deploy Mock Assets
```bash
# Deploy mock WBTC for testing
forge create src/mocks/MockWBTC.sol:MockWBTC \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "Wrapped Bitcoin" "WBTC" 8

# Deploy mock SOVA token
forge create src/mocks/MockSOVA.sol:MockSOVA \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "Sova Token" "SOVA" 18
```

#### 2. Deploy SovaBTC Yield System
```bash
# Deploy to Sepolia
CHAIN_ID=11155111 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ETHERSCAN_API_KEY

# Or use make command
make deploy-sepolia
```

#### 3. Post-Deployment Configuration
```bash
# Add mock WBTC as supported asset
cast send $VAULT_ADDRESS "addSupportedAsset(address,string)" \
    $MOCK_WBTC_SEPOLIA "Mock Wrapped Bitcoin" \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# Grant vault role to staking contract
cast send $BRIDGED_SOVABTC_ADDRESS "grantVaultRole(address)" $VAULT_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# Set initial reward rates (1% APY for vault->SOVA, 0.5% for SOVA->sovaBTC)
cast send $STAKING_ADDRESS "setRewardRates(uint256,uint256,uint256)" \
    317097919 158548959 12000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

### Base Sepolia

#### 1. Deploy Mock Assets
```bash
# Deploy mock cbBTC
forge create src/mocks/MockCBBTC.sol:MockCBBTC \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "Coinbase Wrapped Bitcoin" "cbBTC" 8

# Deploy mock SOVA token
forge create src/mocks/MockSOVA.sol:MockSOVA \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "Sova Token" "SOVA" 18
```

#### 2. Deploy System
```bash
# Deploy to Base Sepolia
CHAIN_ID=84532 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $BASE_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY

# Or use make command
make deploy-base-sepolia
```

### Arbitrum Sepolia

#### 1. Deploy Mock Assets
```bash
# Deploy mock tBTC
forge create src/mocks/MockTBTC.sol:MockTBTC \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args "Threshold Bitcoin" "tBTC" 18
```

#### 2. Deploy System
```bash
# Deploy to Arbitrum Sepolia
CHAIN_ID=421614 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
    --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    --etherscan-api-key $ARBISCAN_API_KEY
```

## Cross-Chain Testing

### 1. Setup Cross-Chain Messaging

#### Using Hyperlane CLI
```bash
# Send test message from Sepolia to Base Sepolia
hyperlane send message \
    --origin sepolia \
    --destination basesepolia \
    --key $PRIVATE_KEY \
    --recipient $BRIDGED_SOVABTC_BASE_SEPOLIA \
    --body "0x1234"
```

#### Manual Cross-Chain Transfer
```bash
# Bridge sovaBTC from Sepolia to Sova Network (hub-and-spoke model)
cast send $BRIDGED_SOVABTC_SEPOLIA "bridgeToSova(address,uint256)" \
    $OWNER_ADDRESS 1000000000000000000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# Note: Balance check would require Sova Network RPC access
# On Sova Network, native sovaBTC balance would increase
```

### 2. End-to-End Testing Flow

#### Complete User Journey Test
```bash
#!/bin/bash
# comprehensive-test.sh

set -e

echo "🚀 Starting SovaBTC Yield System E2E Test"

# 1. Mint test tokens
echo "📦 Minting test tokens..."
cast send $MOCK_WBTC_SEPOLIA "mint(address,uint256)" $OWNER_ADDRESS 10000000000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 2. Approve vault
echo "✅ Approving vault..."
cast send $MOCK_WBTC_SEPOLIA "approve(address,uint256)" $VAULT_ADDRESS 10000000000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 3. Deposit into vault
echo "💰 Depositing into vault..."
cast send $VAULT_ADDRESS "depositAsset(address,uint256,address)" \
    $MOCK_WBTC_SEPOLIA 5000000000 $OWNER_ADDRESS \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 4. Check vault shares
VAULT_SHARES=$(cast call $VAULT_ADDRESS "balanceOf(address)" $OWNER_ADDRESS --rpc-url $SEPOLIA_RPC_URL)
echo "📊 Vault shares received: $VAULT_SHARES"

# 5. Stake vault tokens
echo "🔒 Staking vault tokens..."
cast send $VAULT_ADDRESS "approve(address,uint256)" $STAKING_ADDRESS $VAULT_SHARES \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

cast send $STAKING_ADDRESS "stakeVaultTokens(uint256,uint256)" \
    $VAULT_SHARES 2592000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 6. Check staking position
STAKING_BALANCE=$(cast call $STAKING_ADDRESS "stakedBalance(address)" $OWNER_ADDRESS --rpc-url $SEPOLIA_RPC_URL)
echo "🏦 Staking balance: $STAKING_BALANCE"

# 7. Bridge sovaBTC to Sova Network
echo "🌉 Bridging to Sova Network..."
cast send $BRIDGED_SOVABTC_SEPOLIA "bridgeToSova(address,uint256)" \
    $OWNER_ADDRESS 1000000000000000000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL

# 8. Wait for cross-chain message delivery
echo "⏳ Waiting for Hyperlane message delivery to Sova Network..."
sleep 30

echo "✅ Bridge message sent to Sova Network"
echo "💡 Note: Hub-and-spoke bridge model - all external chains bridge to/from Sova Network"

echo "✨ E2E test completed successfully!"
```

### 3. Performance Testing

#### Load Testing Script
```bash
#!/bin/bash
# load-test.sh

echo "🔥 Starting load test..."

# Deploy multiple test transactions in parallel
for i in {1..10}; do
    (
        echo "Transaction $i starting..."
        cast send $VAULT_ADDRESS "depositAsset(address,uint256,address)" \
            $MOCK_WBTC_SEPOLIA 100000000 $OWNER_ADDRESS \
            --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
        echo "Transaction $i completed"
    ) &
done

wait
echo "📊 Load test completed"
```

### 4. Monitoring and Analytics

#### Real-time Monitoring
```bash
# Monitor vault events
cast logs --address $VAULT_ADDRESS \
    --from-block latest \
    --rpc-url $SEPOLIA_RPC_URL

# Monitor cross-chain transfers
cast logs --address $BRIDGED_SOVABTC_SEPOLIA \
    --from-block latest \
    --rpc-url $SEPOLIA_RPC_URL

# Check system health
./scripts/health-check.sh
```

#### Health Check Script
```bash
#!/bin/bash
# scripts/health-check.sh

echo "🏥 SovaBTC Yield System Health Check"

# Check vault total assets
TOTAL_ASSETS=$(cast call $VAULT_ADDRESS "totalAssets()" --rpc-url $SEPOLIA_RPC_URL)
echo "💰 Vault Total Assets: $TOTAL_ASSETS"

# Check total supply of vault shares
TOTAL_SHARES=$(cast call $VAULT_ADDRESS "totalSupply()" --rpc-url $SEPOLIA_RPC_URL)
echo "📊 Total Vault Shares: $TOTAL_SHARES"

# Check staking pools
TOTAL_STAKED=$(cast call $STAKING_ADDRESS "totalSovaBTCStaked()" --rpc-url $SEPOLIA_RPC_URL)
echo "🔒 Total Staked: $TOTAL_STAKED"

# Check bridged token supply on current network
BRIDGED_SUPPLY=$(cast call $BRIDGED_SOVABTC_ADDRESS "totalSupply()" --rpc-url $RPC_URL)
echo "🌉 Bridged sovaBTC Supply on $NETWORK: $BRIDGED_SUPPLY"
echo "💡 Note: Each network's bridged supply represents tokens bridged from Sova Network"

# Check if contracts are paused
VAULT_PAUSED=$(cast call $VAULT_ADDRESS "paused()" --rpc-url $SEPOLIA_RPC_URL)
STAKING_PAUSED=$(cast call $STAKING_ADDRESS "paused()" --rpc-url $SEPOLIA_RPC_URL)
echo "⏸️  Paused Status - Vault: $VAULT_PAUSED, Staking: $STAKING_PAUSED"
```

## Hyperlane Validator Setup (Optional)

For comprehensive testing, you can run your own Hyperlane validators:

### 1. Validator Configuration
```bash
# Create validator config
mkdir -p ~/.hyperlane/validator
cat > ~/.hyperlane/validator/config.json << EOF
{
  "chains": {
    "sepolia": {
      "rpc": "$SEPOLIA_RPC_URL",
      "mailbox": "$HYPERLANE_MAILBOX_SEPOLIA"
    },
    "basesepolia": {
      "rpc": "$BASE_SEPOLIA_RPC_URL", 
      "mailbox": "$HYPERLANE_MAILBOX_BASE_SEPOLIA"
    }
  },
  "validator": {
    "originChain": "sepolia",
    "signers": {
      "sepolia": {
        "type": "privateKey",
        "privateKey": "$PRIVATE_KEY"
      }
    }
  }
}
EOF
```

### 2. Run Validator
```bash
# Run Hyperlane validator
hyperlane validator --config ~/.hyperlane/validator/config.json
```

### 3. Run Relayer
```bash
# Run Hyperlane relayer for message delivery
hyperlane relayer --config ~/.hyperlane/relayer/config.json
```

## Testing Utilities

### Make Commands
Add these to your `Makefile`:

```makefile
# Testnet deployment commands
deploy-sepolia:
	CHAIN_ID=11155111 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
		--rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-base-sepolia:
	CHAIN_ID=84532 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
		--rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY)

deploy-arbitrum-sepolia:
	CHAIN_ID=421614 forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --verify --etherscan-api-key $(ARBISCAN_API_KEY)

# Testing commands
test-e2e:
	./scripts/comprehensive-test.sh

test-load:
	./scripts/load-test.sh

health-check:
	./scripts/health-check.sh

# Hyperlane commands
hyperlane-init:
	hyperlane config init

hyperlane-deploy:
	hyperlane core deploy --chain custom-testnet

hyperlane-send:
	hyperlane send message --origin sepolia --destination basesepolia --key $(PRIVATE_KEY)
```

## Troubleshooting

### Common Issues

#### 1. Deployment Failures
```bash
# Check gas price and limits
cast gas-price --rpc-url $SEPOLIA_RPC_URL

# Retry with higher gas limit
forge script script/Deploy.s.sol --gas-limit 5000000
```

#### 2. Cross-Chain Message Delays
```bash
# Check Hyperlane relayer status
hyperlane status --origin sepolia --destination basesepolia

# Manual message delivery (if needed)
hyperlane deliver --origin sepolia --destination basesepolia --message-id 0x...
```

#### 3. Contract Verification Issues
```bash
# Manual verification
forge verify-contract $CONTRACT_ADDRESS \
    src/vault/SovaBTCYieldVault.sol:SovaBTCYieldVault \
    --chain-id 11155111 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor()" )
```

#### 4. Token Balance Issues
```bash
# Check token balances
cast call $MOCK_WBTC_SEPOLIA "balanceOf(address)" $OWNER_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Mint more tokens if needed
cast send $MOCK_WBTC_SEPOLIA "mint(address,uint256)" $OWNER_ADDRESS 10000000000 \
    --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL
```

### Debug Commands

```bash
# Enable verbose logging
export RUST_LOG=debug

# Test contract calls locally
forge test --fork-url $SEPOLIA_RPC_URL -vvv

# Decode transaction data
cast 4byte-decode 0x...

# Simulate transactions
cast call $CONTRACT_ADDRESS "function()" --rpc-url $SEPOLIA_RPC_URL
```

## Network-Specific Testnet Information

### Sepolia
- **Chain ID**: 11155111
- **Gas Token**: ETH
- **Faucet**: https://sepolia-faucet.pk910.de/
- **Explorer**: https://sepolia.etherscan.io/
- **Hyperlane Mailbox**: 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766

### Base Sepolia  
- **Chain ID**: 84532
- **Gas Token**: ETH
- **Faucet**: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet
- **Explorer**: https://sepolia.basescan.org/
- **Hyperlane Mailbox**: 0xfFAEF09B3cd11D9b20d1a19bECCA54EEC2884766

### Arbitrum Sepolia
- **Chain ID**: 421614
- **Gas Token**: ETH  
- **Faucet**: https://faucet.quicknode.com/arbitrum/sepolia
- **Explorer**: https://sepolia.arbiscan.io/
- **Hyperlane Mailbox**: 0xfFAEF09B3cd11D9b20d1a19bECCA54EEC2884766

## Resources

- **SovaBTC Yield GitHub**: https://github.com/SovaNetwork/sovabtc-yield
- **Hyperlane Documentation**: https://docs.hyperlane.xyz/
- **Hyperlane CLI**: https://docs.hyperlane.xyz/docs/reference/cli
- **Foundry Book**: https://book.getfoundry.sh/
- **Discord Support**: https://discord.gg/sova

This guide provides everything needed to deploy and test the SovaBTC Yield System on testnets with full cross-chain functionality using Hyperlane CLI.