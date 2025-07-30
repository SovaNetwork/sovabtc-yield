#!/bin/bash

# SovaBTC Yield System - Environment Validation Script
# This script validates all required environment variables and connections

set -e

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
    local var_name=$1
    local var_value="${!1}"
    local is_optional=${2:-false}
    
    if [ -z "$var_value" ]; then
        if [ "$is_optional" = "true" ]; then
            print_warning "Optional variable $var_name is not set"
            return 1
        else
            print_error "Required variable $var_name is not set"
            return 1
        fi
    else
        print_success "$var_name is set"
        return 0
    fi
}

# Function to check if address is valid Ethereum address
is_valid_address() {
    local address=$1
    if [[ $address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if private key is valid
is_valid_private_key() {
    local key=$1
    # Remove 0x prefix if present
    key=${key#0x}
    if [[ $key =~ ^[a-fA-F0-9]{64}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to test RPC connection
test_rpc_connection() {
    local name=$1
    local url=$2
    local is_optional=${3:-false}
    
    if [ -z "$url" ]; then
        if [ "$is_optional" = "true" ]; then
            print_warning "$name RPC URL not set (optional)"
            return 0
        else
            print_error "$name RPC URL not set"
            return 1
        fi
    fi
    
    print_status "Testing $name RPC connection..."
    
    # Test basic connectivity
    if ! curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
         --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
         "$url" | grep -q "result"; then
        print_error "$name RPC connection failed"
        return 1
    fi
    
    # Get chain ID to verify network
    local chain_id=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
                     --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
                     "$url" | jq -r '.result // empty' 2>/dev/null || echo "")
    
    if [ -n "$chain_id" ]; then
        local decimal_chain_id=$((16#${chain_id#0x}))
        print_success "$name RPC connection successful (Chain ID: $decimal_chain_id)"
    else
        print_success "$name RPC connection successful"
    fi
    
    return 0
}

# Function to validate contract address
validate_contract_address() {
    local name=$1
    local address=$2
    local rpc_url=$3
    local is_optional=${4:-false}
    
    if [ -z "$address" ]; then
        if [ "$is_optional" = "true" ]; then
            print_warning "$name address not set (optional)"
            return 0
        else
            print_error "$name address not set"
            return 1
        fi
    fi
    
    if ! is_valid_address "$address"; then
        print_error "$name has invalid address format: $address"
        return 1
    fi
    
    # Check if address has code (is a contract) if RPC URL is provided
    if [ -n "$rpc_url" ]; then
        print_status "Verifying $name contract at $address..."
        local code=$(curl -s --max-time 10 -X POST -H "Content-Type: application/json" \
                     --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getCode\",\"params\":[\"$address\",\"latest\"],\"id\":1}" \
                     "$rpc_url" | jq -r '.result // empty' 2>/dev/null || echo "")
        
        if [ "$code" = "0x" ] || [ -z "$code" ]; then
            print_warning "$name at $address may not be a contract (no code found)"
        else
            print_success "$name contract verified at $address"
        fi
    else
        print_success "$name address format is valid: $address"
    fi
    
    return 0
}

# Main validation function
main() {
    echo "=============================================="
    echo "  SovaBTC Yield System - Environment Validation"
    echo "=============================================="
    echo ""
    
    # Load environment variables if .env exists
    if [ -f .env ]; then
        print_status "Loading environment variables from .env file..."
        set -a  # Automatically export all variables
        source .env
        set +a
        print_success ".env file loaded"
    else
        print_warning ".env file not found. Using system environment variables."
    fi
    
    echo ""
    local validation_failed=false
    
    # Basic Deployment Configuration
    echo "=== Basic Deployment Configuration ==="
    
    if ! check_env_var "PRIVATE_KEY"; then
        validation_failed=true
    elif ! is_valid_private_key "$PRIVATE_KEY"; then
        print_error "PRIVATE_KEY has invalid format (should be 64 hex characters)"
        validation_failed=true
    else
        print_success "PRIVATE_KEY format is valid"
    fi
    
    if ! check_env_var "OWNER_ADDRESS"; then
        validation_failed=true
    elif ! is_valid_address "$OWNER_ADDRESS"; then
        print_error "OWNER_ADDRESS has invalid format"
        validation_failed=true
    else
        print_success "OWNER_ADDRESS format is valid"
    fi
    
    echo ""
    
    # Network RPC URLs
    echo "=== Network RPC URLs ==="
    
    if ! test_rpc_connection "Ethereum" "$ETHEREUM_RPC_URL"; then
        validation_failed=true
    fi
    
    if ! test_rpc_connection "Base" "$BASE_RPC_URL"; then
        validation_failed=true
    fi
    
    if ! test_rpc_connection "Sova Network" "$SOVA_RPC_URL"; then
        validation_failed=true
    fi
    
    # Optional testnet RPCs
    test_rpc_connection "Sepolia" "$SEPOLIA_RPC_URL" true
    test_rpc_connection "Base Sepolia" "$BASE_SEPOLIA_RPC_URL" true
    test_rpc_connection "Arbitrum Sepolia" "$ARBITRUM_SEPOLIA_RPC_URL" true
    
    echo ""
    
    # Token Addresses
    echo "=== Token Addresses ==="
    
    if ! check_env_var "SOVA_TOKEN_ADDRESS"; then
        validation_failed=true
    elif ! validate_contract_address "SOVA Token" "$SOVA_TOKEN_ADDRESS" "$ETHEREUM_RPC_URL"; then
        validation_failed=true
    fi
    
    # Optional mainnet token addresses (validate format if set)
    validate_contract_address "WBTC" "$WBTC_ADDRESS" "$ETHEREUM_RPC_URL" true
    validate_contract_address "cbBTC" "$CBBTC_ADDRESS" "$ETHEREUM_RPC_URL" true
    validate_contract_address "tBTC" "$TBTC_ADDRESS" "$ETHEREUM_RPC_URL" true
    
    echo ""
    
    # Hyperlane Configuration
    echo "=== Hyperlane Configuration ==="
    
    if ! validate_contract_address "Hyperlane Mailbox (Mainnet)" "$HYPERLANE_MAILBOX_MAINNET" "$ETHEREUM_RPC_URL"; then
        validation_failed=true
    fi
    
    if ! validate_contract_address "Hyperlane Mailbox (Base)" "$HYPERLANE_MAILBOX_BASE" "$BASE_RPC_URL"; then
        validation_failed=true
    fi
    
    if ! validate_contract_address "Hyperlane Mailbox (Sova)" "$HYPERLANE_MAILBOX_SOVA" "$SOVA_RPC_URL"; then
        validation_failed=true
    fi
    
    echo ""
    
    # API Keys
    echo "=== API Keys ==="
    
    check_env_var "ETHERSCAN_API_KEY" true
    check_env_var "BASESCAN_API_KEY" true
    
    echo ""
    
    # Deployment Settings
    echo "=== Deployment Settings ==="
    
    check_env_var "SOVA_CHAIN_ID" true || print_warning "SOVA_CHAIN_ID not set, will use default"
    check_env_var "INITIAL_OWNER" true || print_status "INITIAL_OWNER not set, will use OWNER_ADDRESS"
    check_env_var "VAULT_NAME" true || print_status "VAULT_NAME not set, will use default"
    check_env_var "VAULT_SYMBOL" true || print_status "VAULT_SYMBOL not set, will use default"
    
    echo ""
    
    # Check for required tools
    echo "=== Required Tools ==="
    
    if command -v forge >/dev/null 2>&1; then
        local forge_version=$(forge --version | head -1)
        print_success "Foundry/Forge is installed: $forge_version"
    else
        print_error "Foundry/Forge is not installed or not in PATH"
        validation_failed=true
    fi
    
    if command -v jq >/dev/null 2>&1; then
        print_success "jq is installed"
    else
        print_warning "jq is not installed (optional, but recommended for JSON processing)"
    fi
    
    if command -v curl >/dev/null 2>&1; then
        print_success "curl is installed"
    else
        print_error "curl is not installed (required for RPC testing)"
        validation_failed=true
    fi
    
    echo ""
    
    # Summary
    echo "=============================================="
    if [ "$validation_failed" = "true" ]; then
        print_error "❌ ENVIRONMENT VALIDATION FAILED"
        echo ""
        print_status "Please fix the issues above before proceeding with deployment."
        print_status "Refer to .env.example for required environment variables."
        exit 1
    else
        print_success "✅ ENVIRONMENT VALIDATION PASSED"
        echo ""
        print_status "Your environment is properly configured for deployment."
        print_status "You can now run: ./scripts/deploy-full-system.sh"
    fi
    echo "=============================================="
}

# Run main function
main "$@"