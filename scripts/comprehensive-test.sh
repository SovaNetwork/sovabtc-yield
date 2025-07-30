#!/bin/bash
# comprehensive-test.sh - End-to-end testing script for SovaBTC Yield System

set -e

# Load environment variables
if [ -f .env.testnet ]; then
    source .env.testnet
else
    echo "❌ .env.testnet file not found. Please create it first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting SovaBTC Yield System E2E Test${NC}"
echo "=========================================="

# Check if required environment variables are set
required_vars=("PRIVATE_KEY" "OWNER_ADDRESS" "SEPOLIA_RPC_URL")
for var in "${required_vars[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo -e "${RED}❌ Environment variable $var is not set${NC}"
        exit 1
    fi
done

# Contract addresses (should be set after deployment)
if [[ -z "$VAULT_ADDRESS" || -z "$STAKING_ADDRESS" || -z "$BRIDGED_SOVABTC_ADDRESS" || -z "$MOCK_WBTC_SEPOLIA" ]]; then
    echo -e "${YELLOW}⚠️  Contract addresses not set. Please deploy contracts first and update .env.testnet${NC}"
    echo "Required variables: VAULT_ADDRESS, STAKING_ADDRESS, BRIDGED_SOVABTC_ADDRESS, MOCK_WBTC_SEPOLIA"
    exit 1
fi

echo -e "${GREEN}✅ Environment check passed${NC}"

# Function to check transaction receipt
check_tx() {
    local tx_hash=$1
    local description=$2
    echo -e "${YELLOW}⏳ Waiting for transaction: $description${NC}"
    cast receipt "$tx_hash" --rpc-url "$SEPOLIA_RPC_URL" > /dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $description completed${NC}"
    else
        echo -e "${RED}❌ $description failed${NC}"
        exit 1
    fi
}

# Step 1: Check initial balances
echo -e "\n${BLUE}📊 Step 1: Checking initial balances${NC}"
echo "----------------------------------------"

ETH_BALANCE=$(cast balance "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
WBTC_BALANCE=$(cast call "$MOCK_WBTC_SEPOLIA" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
VAULT_SHARES=$(cast call "$VAULT_ADDRESS" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")

echo "ETH Balance: $(cast from-wei $ETH_BALANCE) ETH"
echo "WBTC Balance: $((WBTC_BALANCE / 10**8)) WBTC"
echo "Vault Shares: $(cast from-ether $VAULT_SHARES)"

# Step 2: Mint test tokens if needed
echo -e "\n${BLUE}📦 Step 2: Ensuring sufficient test tokens${NC}"
echo "--------------------------------------------"

if [ "$WBTC_BALANCE" -lt 1000000000 ]; then # Less than 10 WBTC
    echo "Minting test WBTC..."
    TX_HASH=$(cast send "$MOCK_WBTC_SEPOLIA" "mint(address,uint256)" "$OWNER_ADDRESS" 10000000000 \
        --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
    check_tx "$TX_HASH" "WBTC minting"
else
    echo -e "${GREEN}✅ Sufficient WBTC balance${NC}"
fi

# Step 3: Approve vault for WBTC spending
echo -e "\n${BLUE}✅ Step 3: Approving vault for WBTC spending${NC}"
echo "---------------------------------------------"

ALLOWANCE=$(cast call "$MOCK_WBTC_SEPOLIA" "allowance(address,address)" "$OWNER_ADDRESS" "$VAULT_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
if [ "$ALLOWANCE" -lt 5000000000 ]; then # Less than 50 WBTC
    TX_HASH=$(cast send "$MOCK_WBTC_SEPOLIA" "approve(address,uint256)" "$VAULT_ADDRESS" 10000000000 \
        --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
    check_tx "$TX_HASH" "WBTC approval"
else
    echo -e "${GREEN}✅ Sufficient WBTC allowance${NC}"
fi

# Step 4: Deposit into vault
echo -e "\n${BLUE}💰 Step 4: Depositing WBTC into vault${NC}"
echo "--------------------------------------"

DEPOSIT_AMOUNT=5000000000 # 50 WBTC
TX_HASH=$(cast send "$VAULT_ADDRESS" "depositAsset(address,uint256,address)" \
    "$MOCK_WBTC_SEPOLIA" "$DEPOSIT_AMOUNT" "$OWNER_ADDRESS" \
    --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
check_tx "$TX_HASH" "WBTC deposit"

# Check new vault shares
NEW_VAULT_SHARES=$(cast call "$VAULT_ADDRESS" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
SHARES_RECEIVED=$((NEW_VAULT_SHARES - VAULT_SHARES))
echo -e "${GREEN}📊 Vault shares received: $(cast from-ether $SHARES_RECEIVED)${NC}"

# Step 5: Check vault state
echo -e "\n${BLUE}🏦 Step 5: Checking vault state${NC}"
echo "---------------------------------"

TOTAL_ASSETS=$(cast call "$VAULT_ADDRESS" "totalAssets()" --rpc-url "$SEPOLIA_RPC_URL")
TOTAL_SUPPLY=$(cast call "$VAULT_ADDRESS" "totalSupply()" --rpc-url "$SEPOLIA_RPC_URL")
EXCHANGE_RATE=$(cast call "$VAULT_ADDRESS" "getExchangeRate()" --rpc-url "$SEPOLIA_RPC_URL")

echo "Total Assets: $((TOTAL_ASSETS / 10**8)) WBTC equivalent"
echo "Total Supply: $(cast from-ether $TOTAL_SUPPLY) shares"
echo "Exchange Rate: $(cast from-ether $EXCHANGE_RATE)"

# Step 6: Approve staking contract for vault shares
echo -e "\n${BLUE}🔐 Step 6: Approving staking contract${NC}"
echo "------------------------------------"

STAKING_ALLOWANCE=$(cast call "$VAULT_ADDRESS" "allowance(address,address)" "$OWNER_ADDRESS" "$STAKING_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
STAKE_AMOUNT=$((SHARES_RECEIVED / 2)) # Stake half of received shares

if [ "$STAKING_ALLOWANCE" -lt "$STAKE_AMOUNT" ]; then
    TX_HASH=$(cast send "$VAULT_ADDRESS" "approve(address,uint256)" "$STAKING_ADDRESS" "$SHARES_RECEIVED" \
        --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
    check_tx "$TX_HASH" "Vault shares approval for staking"
else
    echo -e "${GREEN}✅ Sufficient staking allowance${NC}"
fi

# Step 7: Stake vault tokens
echo -e "\n${BLUE}🔒 Step 7: Staking vault tokens${NC}"
echo "--------------------------------"

LOCK_PERIOD=2592000 # 30 days
TX_HASH=$(cast send "$STAKING_ADDRESS" "stakeVaultTokens(uint256,uint256)" \
    "$STAKE_AMOUNT" "$LOCK_PERIOD" \
    --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
check_tx "$TX_HASH" "Vault token staking"

# Step 8: Check staking position
echo -e "\n${BLUE}🏦 Step 8: Checking staking position${NC}"
echo "------------------------------------"

STAKING_BALANCE=$(cast call "$STAKING_ADDRESS" "stakedBalance(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
STAKING_INFO=$(cast call "$STAKING_ADDRESS" "getStakingInfo(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
PENDING_REWARDS=$(cast call "$STAKING_ADDRESS" "calculateRewards(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")

echo "Staking Balance: $(cast from-ether $STAKING_BALANCE) vault tokens"
echo "Pending Rewards: $(cast from-ether $PENDING_REWARDS) SOVA"

# Step 9: Test redemption (small amount)
echo -e "\n${BLUE}💸 Step 9: Testing redemption${NC}"
echo "------------------------------"

REDEEM_AMOUNT=$((NEW_VAULT_SHARES / 10)) # Redeem 10% of shares
if [ "$REDEEM_AMOUNT" -gt 0 ]; then
    TX_HASH=$(cast send "$VAULT_ADDRESS" "redeem(uint256,address,address)" \
        "$REDEEM_AMOUNT" "$OWNER_ADDRESS" "$OWNER_ADDRESS" \
        --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
    check_tx "$TX_HASH" "Vault redemption"
    
    # Check WBTC balance after redemption
    FINAL_WBTC_BALANCE=$(cast call "$MOCK_WBTC_SEPOLIA" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
    WBTC_RECEIVED=$((FINAL_WBTC_BALANCE - (WBTC_BALANCE - DEPOSIT_AMOUNT)))
    echo -e "${GREEN}📊 WBTC received from redemption: $((WBTC_RECEIVED / 10**6)) mWBTC${NC}"
fi

# Step 10: Cross-chain testing to Sova Network
echo -e "\n${BLUE}🌉 Step 10: Testing cross-chain bridge to Sova Network${NC}"
echo "--------------------------------------------------------"

# Check if we have sovaBTC balance to bridge
SOVABTC_BALANCE=$(cast call "$BRIDGED_SOVABTC_ADDRESS" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")

if [ "$SOVABTC_BALANCE" -gt 1000000000000000000 ]; then # More than 1 sovaBTC
    BRIDGE_AMOUNT=1000000000000000000 # 1 sovaBTC
    echo -e "${BLUE}Bridging $((BRIDGE_AMOUNT / 10**18)) sovaBTC from Sepolia to Sova Network${NC}"
    
    TX_HASH=$(cast send "$BRIDGED_SOVABTC_ADDRESS" "bridgeToSova(address,uint256)" \
        "$OWNER_ADDRESS" "$BRIDGE_AMOUNT" \
        --private-key "$PRIVATE_KEY" --rpc-url "$SEPOLIA_RPC_URL")
    check_tx "$TX_HASH" "Cross-chain bridge to Sova Network"
    
    echo -e "${YELLOW}⏳ Waiting 30 seconds for Hyperlane message delivery...${NC}"
    sleep 30
    
    echo -e "${GREEN}✅ Bridge message sent to Sova Network${NC}"
    echo -e "${BLUE}💡 Note: Bridge uses hub-and-spoke model with Sova Network as hub${NC}"
else
    echo -e "${YELLOW}⚠️  Insufficient sovaBTC balance for bridging test${NC}"
    echo -e "${BLUE}💡 Bridge architecture: External chains ↔ Sova Network (hub)${NC}"
fi

# Step 11: Final system health check
echo -e "\n${BLUE}🏥 Step 11: Final system health check${NC}"
echo "-------------------------------------"

VAULT_PAUSED=$(cast call "$VAULT_ADDRESS" "paused()" --rpc-url "$SEPOLIA_RPC_URL")
STAKING_PAUSED=$(cast call "$STAKING_ADDRESS" "paused()" --rpc-url "$SEPOLIA_RPC_URL")
BRIDGE_PAUSED=$(cast call "$BRIDGED_SOVABTC_ADDRESS" "paused()" --rpc-url "$SEPOLIA_RPC_URL")

echo "Vault Paused: $VAULT_PAUSED"
echo "Staking Paused: $STAKING_PAUSED"
echo "Bridge Paused: $BRIDGE_PAUSED"

# Final balances
FINAL_ETH_BALANCE=$(cast balance "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
FINAL_WBTC_BALANCE=$(cast call "$MOCK_WBTC_SEPOLIA" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
FINAL_VAULT_SHARES=$(cast call "$VAULT_ADDRESS" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")
FINAL_STAKING_BALANCE=$(cast call "$STAKING_ADDRESS" "stakedBalance(address)" "$OWNER_ADDRESS" --rpc-url "$SEPOLIA_RPC_URL")

echo -e "\n${BLUE}📊 Final Balances${NC}"
echo "----------------"
echo "ETH: $(cast from-wei $FINAL_ETH_BALANCE) ETH"
echo "WBTC: $((FINAL_WBTC_BALANCE / 10**8)) WBTC"
echo "Vault Shares: $(cast from-ether $FINAL_VAULT_SHARES)"
echo "Staked Tokens: $(cast from-ether $FINAL_STAKING_BALANCE)"

# Calculate gas used
GAS_USED=$((ETH_BALANCE - FINAL_ETH_BALANCE))
echo "Gas Used: $(cast from-wei $GAS_USED) ETH"

echo -e "\n${GREEN}✨ E2E test completed successfully!${NC}"
echo -e "${GREEN}🎉 All systems functional and ready for testing${NC}"