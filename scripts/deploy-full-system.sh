#!/bin/bash

# SovaBTC Yield System - Complete Deployment Script
# This script automates the entire multi-stage deployment process across all networks

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to check if environment variable is set
check_env_var() {
    if [ -z "${!1}" ]; then
        print_error "Environment variable $1 is not set"
        return 1
    fi
}

# Function to validate environment
validate_environment() {
    print_status "Validating deployment environment..."
    
    local required_vars=(
        "PRIVATE_KEY"
        "OWNER_ADDRESS"
        "SOVA_TOKEN_ADDRESS"
        "ETHEREUM_RPC_URL"
        "BASE_RPC_URL"
        "SOVA_RPC_URL"
        "HYPERLANE_MAILBOX_MAINNET"
        "HYPERLANE_MAILBOX_BASE"
        "HYPERLANE_MAILBOX_SOVA"
    )
    
    local missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if ! check_env_var "$var" 2>/dev/null; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        print_error "Please check your .env file and ensure all required variables are set."
        exit 1
    fi
    
    print_success "Environment validation passed"
}

# Function to test RPC connections
test_rpc_connections() {
    print_status "Testing RPC connections..."
    
    local networks=(
        "Ethereum:$ETHEREUM_RPC_URL"
        "Base:$BASE_RPC_URL"
        "Sova:$SOVA_RPC_URL"
    )
    
    for network_info in "${networks[@]}"; do
        local network=$(echo "$network_info" | cut -d: -f1)
        local rpc_url=$(echo "$network_info" | cut -d: -f2-)
        
        print_status "Testing $network connection..."
        if curl -s -X POST -H "Content-Type: application/json" \
           --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
           "$rpc_url" | grep -q "result"; then
            print_success "$network RPC connection successful"
        else
            print_error "$network RPC connection failed"
            exit 1
        fi
    done
}

# Function to deploy mock tokens for testnets
deploy_mock_tokens() {
    local network=$1
    local rpc_url=$2
    
    print_status "Deploying mock tokens on $network..."
    
    if forge script script/DeployMockTokens.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --verify 2>/dev/null; then
        print_success "Mock tokens deployed on $network"
    else
        print_warning "Mock token deployment failed on $network (may already exist)"
    fi
}

# Function to deploy Stage 1 on a network
deploy_stage1() {
    local network=$1
    local rpc_url=$2
    
    print_status "Deploying Stage 1 core contracts on $network..."
    
    if forge script script/DeployStage1_Core.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast \
        --verify; then
        print_success "Stage 1 deployment completed on $network"
        return 0
    else
        print_error "Stage 1 deployment failed on $network"
        return 1
    fi
}

# Function to deploy Stage 2 on a network
deploy_stage2() {
    local network=$1
    local rpc_url=$2
    
    print_status "Deploying Stage 2 cross-network configuration on $network..."
    
    if forge script script/DeployStage2_CrossNetwork.s.sol \
        --rpc-url "$rpc_url" \
        --broadcast; then
        print_success "Stage 2 deployment completed on $network"
        return 0
    else
        print_error "Stage 2 deployment failed on $network"
        return 1
    fi
}

# Function to wait for user confirmation
wait_for_confirmation() {
    echo ""
    read -p "Press Enter to continue or Ctrl+C to abort..."
    echo ""
}

# Function to check if deployment artifacts exist
check_stage1_artifacts() {
    local chain_ids=(1 8453)  # Ethereum, Base
    local sova_chain_id=${SOVA_CHAIN_ID:-123456}
    chain_ids+=($sova_chain_id)
    
    print_status "Checking Stage 1 deployment artifacts..."
    
    local missing_artifacts=()
    for chain_id in "${chain_ids[@]}"; do
        local artifact_file="deployments/stage1-${chain_id}.json"
        if [ ! -f "$artifact_file" ]; then
            missing_artifacts+=("$artifact_file")
        fi
    done
    
    if [ ${#missing_artifacts[@]} -ne 0 ]; then
        print_error "Missing Stage 1 deployment artifacts:"
        for artifact in "${missing_artifacts[@]}"; do
            echo "  - $artifact"
        done
        return 1
    fi
    
    print_success "All Stage 1 deployment artifacts found"
    return 0
}

# Main deployment function
main() {
    echo "=============================================="
    echo "  SovaBTC Yield System - Full Deployment"
    echo "=============================================="
    echo ""
    
    # Load environment variables
    if [ -f .env ]; then
        print_status "Loading environment variables from .env file..."
        set -a  # Automatically export all variables
        source .env
        set +a
    else
        print_error ".env file not found. Please create it from .env.example"
        exit 1
    fi
    
    # Validate environment
    validate_environment
    
    # Test RPC connections
    test_rpc_connections
    
    echo ""
    print_status "Deployment Summary:"
    echo "  - Networks: Ethereum, Base, Sova Network"
    echo "  - Owner Address: $OWNER_ADDRESS"
    echo "  - SOVA Token: $SOVA_TOKEN_ADDRESS"
    echo ""
    
    # Confirm deployment
    read -p "Do you want to proceed with the full deployment? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
    
    echo ""
    print_status "Starting deployment process..."
    
    # Create deployments directory if it doesn't exist
    mkdir -p deployments
    
    # Stage 1: Deploy core contracts on all networks
    echo ""
    echo "========== STAGE 1: CORE CONTRACTS =========="
    
    local networks=(
        "Ethereum:$ETHEREUM_RPC_URL"
        "Base:$BASE_RPC_URL"
        "Sova:$SOVA_RPC_URL"
    )
    
    local stage1_failed=()
    
    for network_info in "${networks[@]}"; do
        local network=$(echo "$network_info" | cut -d: -f1)
        local rpc_url=$(echo "$network_info" | cut -d: -f2-)
        
        echo ""
        print_status "=== Deploying to $network ==="
        
        # Deploy mock tokens for testnets
        if [[ "$rpc_url" == *"sepolia"* ]] || [[ "$rpc_url" == *"testnet"* ]]; then
            deploy_mock_tokens "$network" "$rpc_url"
        fi
        
        # Deploy Stage 1
        if ! deploy_stage1 "$network" "$rpc_url"; then
            stage1_failed+=("$network")
        fi
        
        echo ""
    done
    
    # Check for Stage 1 failures
    if [ ${#stage1_failed[@]} -ne 0 ]; then
        print_error "Stage 1 deployment failed on the following networks:"
        for network in "${stage1_failed[@]}"; do
            echo "  - $network"
        done
        print_error "Please resolve the issues and run the script again"
        exit 1
    fi
    
    print_success "Stage 1 deployment completed on all networks"
    
    # Wait before Stage 2
    echo ""
    print_status "Stage 1 completed successfully. Preparing for Stage 2..."
    print_status "Stage 2 will configure cross-network token support."
    wait_for_confirmation
    
    # Stage 2: Configure cross-network support
    echo ""
    echo "========== STAGE 2: CROSS-NETWORK CONFIGURATION =========="
    
    # Verify Stage 1 artifacts exist
    if ! check_stage1_artifacts; then
        print_error "Cannot proceed with Stage 2 without Stage 1 artifacts"
        exit 1
    fi
    
    local stage2_failed=()
    
    for network_info in "${networks[@]}"; do
        local network=$(echo "$network_info" | cut -d: -f1)
        local rpc_url=$(echo "$network_info" | cut -d: -f2-)
        
        echo ""
        print_status "=== Configuring cross-network support on $network ==="
        
        if ! deploy_stage2 "$network" "$rpc_url"; then
            stage2_failed+=("$network")
        fi
        
        echo ""
    done
    
    # Check for Stage 2 failures
    if [ ${#stage2_failed[@]} -ne 0 ]; then
        print_error "Stage 2 deployment failed on the following networks:"
        for network in "${stage2_failed[@]}"; do
            echo "  - $network"
        done
        print_error "Please resolve the issues manually"
        exit 1
    fi
    
    print_success "Stage 2 deployment completed on all networks"
    
    # Final success message
    echo ""
    echo "=============================================="
    print_success "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY! 🎉"
    echo "=============================================="
    echo ""
    print_status "Next steps:"
    echo "  1. Run health checks: ./scripts/health-check.sh"
    echo "  2. Run end-to-end tests: ./scripts/comprehensive-test.sh"
    echo "  3. Monitor system status and verify cross-chain functionality"
    echo ""
    print_status "Deployment artifacts are saved in the deployments/ directory"
    echo ""
}

# Run main function
main "$@"