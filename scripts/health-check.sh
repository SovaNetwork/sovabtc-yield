#!/bin/bash
# health-check.sh - System health monitoring script

set -e

# Load environment variables
if [ -f .env.testnet ]; then
    source .env.testnet
else
    echo "❌ .env.testnet file not found"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🏥 SovaBTC Yield System Health Check${NC}"
echo "===================================="

# Function to check if address is set
check_address() {
    local var_name=$1
    local address=${!var_name}
    if [[ -z "$address" || "$address" == "0x" ]]; then
        echo -e "${RED}❌ $var_name not set${NC}"
        return 1
    fi
    return 0
}

# Check required addresses
required_addresses=("VAULT_ADDRESS" "STAKING_ADDRESS" "BRIDGED_SOVABTC_ADDRESS")
for addr in "${required_addresses[@]}"; do
    if ! check_address "$addr"; then
        echo -e "${YELLOW}⚠️  Some contract addresses not set. Skipping detailed checks.${NC}"
        exit 1
    fi
done

echo -e "${GREEN}✅ All contract addresses configured${NC}"

# Network selection
RPC_URL=""
if [[ -n "$SEPOLIA_RPC_URL" ]]; then
    RPC_URL="$SEPOLIA_RPC_URL"
    NETWORK="Sepolia"
elif [[ -n "$BASE_SEPOLIA_RPC_URL" ]]; then
    RPC_URL="$BASE_SEPOLIA_RPC_URL"
    NETWORK="Base Sepolia"
else
    echo -e "${RED}❌ No RPC URL configured${NC}"
    exit 1
fi

echo -e "${BLUE}🌐 Network: $NETWORK${NC}"
echo -e "${BLUE}🔗 RPC: $RPC_URL${NC}"

# Function to safely call contract
safe_call() {
    local address=$1
    local signature=$2
    local description=$3
    
    result=$(cast call "$address" "$signature" --rpc-url "$RPC_URL" 2>/dev/null || echo "ERROR")
    if [[ "$result" == "ERROR" ]]; then
        echo -e "${RED}❌ $description: Call failed${NC}"
        return 1
    else
        echo -e "${GREEN}✅ $description: $result${NC}"
        return 0
    fi
}

# Function to format large numbers
format_number() {
    local num=$1
    local decimals=${2:-18}
    
    if [[ "$num" =~ ^[0-9]+$ ]]; then
        if [[ $decimals -eq 18 ]]; then
            cast from-ether "$num" 2>/dev/null || echo "$num"
        elif [[ $decimals -eq 8 ]]; then
            echo "scale=8; $num / 10^8" | bc -l 2>/dev/null || echo "$num"
        else
            echo "scale=2; $num / 10^$decimals" | bc -l 2>/dev/null || echo "$num"
        fi
    else
        echo "$num"
    fi
}

echo -e "\n${BLUE}💰 Vault Health${NC}"
echo "---------------"

# Vault total assets
if TOTAL_ASSETS=$(cast call "$VAULT_ADDRESS" "totalAssets()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Total Assets: $(format_number $TOTAL_ASSETS 8) BTC${NC}"
else
    echo -e "${RED}❌ Total Assets: Call failed${NC}"
fi

# Vault total supply
if TOTAL_SUPPLY=$(cast call "$VAULT_ADDRESS" "totalSupply()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Total Supply: $(format_number $TOTAL_SUPPLY 18) shares${NC}"
else
    echo -e "${RED}❌ Total Supply: Call failed${NC}"
fi

# Exchange rate
if EXCHANGE_RATE=$(cast call "$VAULT_ADDRESS" "getExchangeRate()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Exchange Rate: $(format_number $EXCHANGE_RATE 18)${NC}"
else
    echo -e "${RED}❌ Exchange Rate: Call failed${NC}"
fi

# Vault paused status
if VAULT_PAUSED=$(cast call "$VAULT_ADDRESS" "paused()" --rpc-url "$RPC_URL" 2>/dev/null); then
    if [[ "$VAULT_PAUSED" == "false" ]]; then
        echo -e "${GREEN}✅ Vault Status: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  Vault Status: Paused${NC}"
    fi
else
    echo -e "${RED}❌ Vault Status: Call failed${NC}"
fi

echo -e "\n${BLUE}🔒 Staking Health${NC}"
echo "----------------"

# Total staked amounts
if TOTAL_SOVABTC_STAKED=$(cast call "$STAKING_ADDRESS" "totalSovaBTCStaked()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Total sovaBTC Staked: $(format_number $TOTAL_SOVABTC_STAKED 18)${NC}"
else
    echo -e "${RED}❌ Total sovaBTC Staked: Call failed${NC}"
fi

if TOTAL_SOVA_STAKED=$(cast call "$STAKING_ADDRESS" "totalSovaStaked()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Total SOVA Staked: $(format_number $TOTAL_SOVA_STAKED 18)${NC}"
else
    echo -e "${RED}❌ Total SOVA Staked: Call failed${NC}"
fi

# Staking paused status
if STAKING_PAUSED=$(cast call "$STAKING_ADDRESS" "paused()" --rpc-url "$RPC_URL" 2>/dev/null); then
    if [[ "$STAKING_PAUSED" == "false" ]]; then
        echo -e "${GREEN}✅ Staking Status: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  Staking Status: Paused${NC}"
    fi
else
    echo -e "${RED}❌ Staking Status: Call failed${NC}"
fi

echo -e "\n${BLUE}🌉 Bridge Health${NC}"
echo "---------------"

# Bridge total supply
if BRIDGE_TOTAL_SUPPLY=$(cast call "$BRIDGED_SOVABTC_ADDRESS" "totalSupply()" --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Bridged Supply: $(format_number $BRIDGE_TOTAL_SUPPLY 18) sovaBTC${NC}"
else
    echo -e "${RED}❌ Bridged Supply: Call failed${NC}"
fi

# Bridge paused status
if BRIDGE_PAUSED=$(cast call "$BRIDGED_SOVABTC_ADDRESS" "paused()" --rpc-url "$RPC_URL" 2>/dev/null); then
    if [[ "$BRIDGE_PAUSED" == "false" ]]; then
        echo -e "${GREEN}✅ Bridge Status: Active${NC}"
    else
        echo -e "${YELLOW}⚠️  Bridge Status: Paused${NC}"
    fi
else
    echo -e "${RED}❌ Bridge Status: Call failed${NC}"
fi

# Check cross-chain consistency if multiple networks configured
if [[ -n "$BASE_SEPOLIA_RPC_URL" && -n "$BRIDGED_SOVABTC_BASE_SEPOLIA" ]]; then
    echo -e "\n${BLUE}🔄 Cross-Chain Consistency${NC}"
    echo "-------------------------"
    
    if BASE_SUPPLY=$(cast call "$BRIDGED_SOVABTC_BASE_SEPOLIA" "totalSupply()" --rpc-url "$BASE_SEPOLIA_RPC_URL" 2>/dev/null); then
        echo -e "${GREEN}✅ Base Sepolia Supply: $(format_number $BASE_SUPPLY 18) sovaBTC${NC}"
        
        # Compare supplies (they should be roughly equal)
        if [[ -n "$BRIDGE_TOTAL_SUPPLY" && "$BRIDGE_TOTAL_SUPPLY" != "ERROR" ]]; then
            SEPOLIA_NUM=$(echo "$BRIDGE_TOTAL_SUPPLY" | tr -d ' ')
            BASE_NUM=$(echo "$BASE_SUPPLY" | tr -d ' ')
            
            if [[ "$SEPOLIA_NUM" == "$BASE_NUM" ]]; then
                echo -e "${GREEN}✅ Cross-chain supply consistent${NC}"
            else
                echo -e "${YELLOW}⚠️  Cross-chain supply mismatch: Sepolia=$SEPOLIA_NUM, Base=$BASE_NUM${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Base Sepolia Supply: Call failed${NC}"
    fi
fi

echo -e "\n${BLUE}⛽ Gas and Performance${NC}"
echo "--------------------"

# Check current gas price
if GAS_PRICE=$(cast gas-price --rpc-url "$RPC_URL" 2>/dev/null); then
    GAS_GWEI=$(cast from-wei "$GAS_PRICE" gwei)
    echo -e "${GREEN}✅ Current Gas Price: $GAS_GWEI gwei${NC}"
else
    echo -e "${RED}❌ Gas Price: Call failed${NC}"
fi

# Check latest block
if BLOCK_NUMBER=$(cast block-number --rpc-url "$RPC_URL" 2>/dev/null); then
    echo -e "${GREEN}✅ Latest Block: $BLOCK_NUMBER${NC}"
else
    echo -e "${RED}❌ Latest Block: Call failed${NC}"
fi

echo -e "\n${BLUE}👤 Account Status${NC}"
echo "----------------"

if [[ -n "$OWNER_ADDRESS" ]]; then
    # Check ETH balance
    if ETH_BALANCE=$(cast balance "$OWNER_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null); then
        ETH_FORMATTED=$(cast from-wei "$ETH_BALANCE")
        echo -e "${GREEN}✅ ETH Balance: $ETH_FORMATTED ETH${NC}"
        
        # Warn if balance is low
        if (( $(echo "$ETH_FORMATTED < 0.01" | bc -l) )); then
            echo -e "${YELLOW}⚠️  Low ETH balance for gas fees${NC}"
        fi
    else
        echo -e "${RED}❌ ETH Balance: Call failed${NC}"
    fi
    
    # Check vault shares
    if VAULT_BALANCE=$(cast call "$VAULT_ADDRESS" "balanceOf(address)" "$OWNER_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null); then
        echo -e "${GREEN}✅ Vault Shares: $(format_number $VAULT_BALANCE 18)${NC}"
    else
        echo -e "${RED}❌ Vault Shares: Call failed${NC}"
    fi
    
    # Check staking balance
    if STAKING_BALANCE=$(cast call "$STAKING_ADDRESS" "stakedBalance(address)" "$OWNER_ADDRESS" --rpc-url "$RPC_URL" 2>/dev/null); then
        echo -e "${GREEN}✅ Staked Balance: $(format_number $STAKING_BALANCE 18)${NC}"
    else
        echo -e "${RED}❌ Staked Balance: Call failed${NC}"
    fi
fi

# Overall health summary
echo -e "\n${BLUE}📋 Health Summary${NC}"
echo "----------------"

HEALTH_SCORE=0
TOTAL_CHECKS=0

# Count successful checks (this is a simplified approach)
if [[ "$VAULT_PAUSED" == "false" ]]; then ((HEALTH_SCORE++)); fi
if [[ "$STAKING_PAUSED" == "false" ]]; then ((HEALTH_SCORE++)); fi
if [[ "$BRIDGE_PAUSED" == "false" ]]; then ((HEALTH_SCORE++)); fi
TOTAL_CHECKS=3

if [[ -n "$TOTAL_ASSETS" && "$TOTAL_ASSETS" != "ERROR" ]]; then ((HEALTH_SCORE++)); fi
if [[ -n "$TOTAL_SUPPLY" && "$TOTAL_SUPPLY" != "ERROR" ]]; then ((HEALTH_SCORE++)); fi
if [[ -n "$BRIDGE_TOTAL_SUPPLY" && "$BRIDGE_TOTAL_SUPPLY" != "ERROR" ]]; then ((HEALTH_SCORE++)); fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 3))

HEALTH_PERCENTAGE=$(( (HEALTH_SCORE * 100) / TOTAL_CHECKS ))

if [[ $HEALTH_PERCENTAGE -ge 90 ]]; then
    echo -e "${GREEN}🟢 System Health: $HEALTH_PERCENTAGE% - Excellent${NC}"
elif [[ $HEALTH_PERCENTAGE -ge 70 ]]; then
    echo -e "${YELLOW}🟡 System Health: $HEALTH_PERCENTAGE% - Good${NC}"
else
    echo -e "${RED}🔴 System Health: $HEALTH_PERCENTAGE% - Needs Attention${NC}"
fi

echo -e "\n${BLUE}🕐 Last Updated: $(date)${NC}"