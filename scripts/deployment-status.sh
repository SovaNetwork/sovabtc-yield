#!/bin/bash

# SovaBTC Yield System - Deployment Status Checker
# This script checks the deployment status across all networks

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}$1${NC}"
}

# Function to check if contract exists at address
check_contract() {
    local name=$1
    local address=$2
    local rpc_url=$3
    
    if [ -z "$address" ] || [ "$address" = "0x0000000000000000000000000000000000000000" ]; then
        echo "❌ Not deployed"
        return 1
    fi
    
    # Check if address has code
    local code=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
                 --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$address\",\"latest\"],\"id\":1}" \
                 "$rpc_url" | jq -r '.result // empty' 2>/dev/null || echo "")
    
    if [ "$code" = "0x" ] || [ -z "$code" ]; then
        echo "❌ No code at address"
        return 1
    else
        echo "✅ Deployed at $address"
        return 0
    fi
}

# Function to get deployment info from artifact
get_deployment_info() {
    local chain_id=$1
    local artifact_file="deployments/stage1-${chain_id}.json"
    
    if [ ! -f "$artifact_file" ]; then
        echo "❌ Artifact not found"
        return 1
    fi
    
    echo "📄 Artifact: $artifact_file"
    
    # Parse deployment info
    local network=$(jq -r '.network // "Unknown"' "$artifact_file" 2>/dev/null || echo "Unknown")
    local block_number=$(jq -r '.blockNumber // "Unknown"' "$artifact_file" 2>/dev/null || echo "Unknown")
    local timestamp=$(jq -r '.timestamp // "Unknown"' "$artifact_file" 2>/dev/null || echo "Unknown")
    
    echo "📡 Network: $network"
    echo "🧱 Block: $block_number"
    
    if [ "$timestamp" != "Unknown" ] && [ "$timestamp" != "null" ]; then
        local deploy_date=$(date -d "@$timestamp" 2>/dev/null || echo "Unknown")
        echo "📅 Deployed: $deploy_date"
    fi
    
    return 0
}

# Function to check network deployment status
check_network_deployment() {
    local network_name=$1
    local chain_id=$2
    local rpc_url=$3
    
    print_header "=== $network_name (Chain ID: $chain_id) ==="
    echo ""
    
    # Check if deployment artifact exists
    local artifact_file="deployments/stage1-${chain_id}.json"
    
    if [ ! -f "$artifact_file" ]; then
        print_error "Stage 1 deployment artifact not found"
        echo "❌ Stage 1: Not deployed"
        echo "❌ Stage 2: Not configured"
        echo ""
        return 1
    fi
    
    # Get deployment info
    print_status "Stage 1 Deployment Status:"
    get_deployment_info "$chain_id"
    echo ""
    
    # Check contract deployments
    print_status "Contract Status:"
    
    # Parse contract addresses from artifact
    local vault_address=$(jq -r '.contracts.yieldVault // empty' "$artifact_file" 2>/dev/null)
    local staking_address=$(jq -r '.contracts.yieldStaking // empty' "$artifact_file" 2>/dev/null)
    local queue_address=$(jq -r '.contracts.redemptionQueue // empty' "$artifact_file" 2>/dev/null)
    local bridged_address=$(jq -r '.contracts.bridgedSovaBTC // empty' "$artifact_file" 2>/dev/null)
    
    echo -n "🏦 SovaBTCYieldVault: "
    check_contract "Vault" "$vault_address" "$rpc_url"
    
    echo -n "🥩 SovaBTCYieldStaking: "
    check_contract "Staking" "$staking_address" "$rpc_url"
    
    echo -n "🔄 RedemptionQueue: "
    check_contract "Queue" "$queue_address" "$rpc_url"
    
    if [ -n "$bridged_address" ]; then
        echo -n "🌉 BridgedSovaBTC: "
        check_contract "Bridge" "$bridged_address" "$rpc_url"
    else
        echo "🌉 BridgedSovaBTC: ⚡ Native sovaBTC (Sova Network)"
    fi
    
    echo ""
    
    # Check Stage 2 status (cross-network configuration)
    print_status "Stage 2 Cross-Network Status:"
    
    # Try to determine if Stage 2 has been run
    # This is a heuristic - we check if the vault has multiple supported assets
    if [ -n "$vault_address" ] && [ -n "$rpc_url" ]; then
        print_status "Checking supported assets count..."
        
        # This would require a more complex check - for now just indicate if artifact suggests Stage 2
        local stage2_file="deployments/stage2-${chain_id}.json"
        if [ -f "$stage2_file" ]; then
            echo "✅ Stage 2 configuration completed"
        else
            echo "❓ Stage 2 status unknown (check manually)"
        fi
    else
        echo "❌ Cannot check Stage 2 status (Stage 1 incomplete)"
    fi
    
    echo ""
    return 0
}

# Function to check cross-chain connectivity
check_cross_chain_status() {
    print_header "=== Cross-Chain Connectivity Status ==="
    echo ""
    
    print_status "Hyperlane Integration:"
    
    # Check if we have BridgedSovaBTC on external networks
    local ethereum_artifact="deployments/stage1-1.json"
    local base_artifact="deployments/stage1-8453.json"
    
    local eth_bridge=""
    local base_bridge=""
    
    if [ -f "$ethereum_artifact" ]; then
        eth_bridge=$(jq -r '.contracts.bridgedSovaBTC // empty' "$ethereum_artifact" 2>/dev/null)
    fi
    
    if [ -f "$base_artifact" ]; then
        base_bridge=$(jq -r '.contracts.bridgedSovaBTC // empty' "$base_artifact" 2>/dev/null)
    fi
    
    echo -n "🔗 Ethereum ↔ Sova: "
    if [ -n "$eth_bridge" ]; then
        echo "✅ Bridge deployed"
    else
        echo "❌ Bridge not deployed"
    fi
    
    echo -n "🔗 Base ↔ Sova: "
    if [ -n "$base_bridge" ]; then
        echo "✅ Bridge deployed"
    else
        echo "❌ Bridge not deployed"
    fi
    
    echo -n "🔗 Cross-Network Assets: "
    if [ -n "$eth_bridge" ] && [ -n "$base_bridge" ]; then
        echo "✅ Ready for Stage 2 configuration"
    else
        echo "❌ Incomplete deployment"
    fi
    
    echo ""
}

# Function to show deployment summary
show_deployment_summary() {
    print_header "=== Deployment Summary ==="
    echo ""
    
    local total_networks=0
    local deployed_networks=0
    
    # Check main networks
    local networks=(
        "Ethereum:1:$ETHEREUM_RPC_URL"
        "Base:8453:$BASE_RPC_URL"
        "Sova:${SOVA_CHAIN_ID:-123456}:$SOVA_RPC_URL"
    )
    
    for network_info in "${networks[@]}"; do
        local network=$(echo "$network_info" | cut -d: -f1)
        local chain_id=$(echo "$network_info" | cut -d: -f2)
        local rpc_url=$(echo "$network_info" | cut -d: -f3-)
        
        total_networks=$((total_networks + 1))
        
        if [ -f "deployments/stage1-${chain_id}.json" ]; then
            deployed_networks=$((deployed_networks + 1))
        fi
    done
    
    echo "📊 Networks: $deployed_networks/$total_networks deployed"
    
    # Calculate deployment percentage
    local percentage=$((deployed_networks * 100 / total_networks))
    
    if [ $percentage -eq 100 ]; then
        echo "🎉 Status: Complete deployment"
        echo "✅ Ready for Stage 2 cross-network configuration"
    elif [ $percentage -gt 0 ]; then
        echo "⚠️  Status: Partial deployment ($percentage%)"
        echo "🔧 Next: Complete remaining network deployments"
    else
        echo "❌ Status: No deployments found"
        echo "🚀 Next: Run Stage 1 deployment"
    fi
    
    echo ""
    
    # Show recommended actions
    print_status "Recommended Actions:"
    
    if [ $percentage -eq 100 ]; then
        echo "  1. Run Stage 2: ./scripts/deploy-full-system.sh (Stage 2 only)"
        echo "  2. Run health checks: ./scripts/health-check.sh"
        echo "  3. Test cross-chain functionality"
    elif [ $percentage -gt 0 ]; then
        echo "  1. Complete Stage 1 on remaining networks"
        echo "  2. Run full deployment: ./scripts/deploy-full-system.sh"
    else
        echo "  1. Validate environment: ./scripts/validate-env.sh"
        echo "  2. Run full deployment: ./scripts/deploy-full-system.sh"
    fi
    
    echo ""
}

# Main function
main() {
    echo "=============================================="
    echo "  SovaBTC Yield System - Deployment Status"
    echo "=============================================="
    echo ""
    
    # Load environment variables if .env exists
    if [ -f .env ]; then
        print_status "Loading environment variables from .env file..."
        set -a  # Automatically export all variables
        source .env
        set +a
    fi
    
    # Check if deployments directory exists
    if [ ! -d "deployments" ]; then
        print_error "Deployments directory not found"
        print_status "No deployments have been made yet."
        echo ""
        print_status "To start deployment:"
        echo "  1. ./scripts/validate-env.sh"
        echo "  2. ./scripts/deploy-full-system.sh"
        exit 0
    fi
    
    # Check each network
    local networks=(
        "Ethereum:1:$ETHEREUM_RPC_URL"
        "Base:8453:$BASE_RPC_URL"
        "Sova Network:${SOVA_CHAIN_ID:-123456}:$SOVA_RPC_URL"
    )
    
    for network_info in "${networks[@]}"; do
        local network=$(echo "$network_info" | cut -d: -f1)
        local chain_id=$(echo "$network_info" | cut -d: -f2)
        local rpc_url=$(echo "$network_info" | cut -d: -f3-)
        
        check_network_deployment "$network" "$chain_id" "$rpc_url"
    done
    
    # Check cross-chain status
    check_cross_chain_status
    
    # Show summary
    show_deployment_summary
    
    echo "=============================================="
    print_status "Status check complete!"
    print_status "For detailed logs, check the deployments/ directory"
    echo "=============================================="
}

# Run main function
main "$@"