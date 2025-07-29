# SovaBTC Yield System Makefile

.PHONY: help setup clean build test coverage gas-report format lint deploy

# Default target
help: ## Show this help message
	@echo "SovaBTC Yield System Development Commands"
	@echo "======================================="
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Setup and Installation
setup: ## Install dependencies and setup environment
	@echo "Installing Foundry dependencies..."
	forge install
	@echo "Installing Node.js dependencies..."
	npm install
	@echo "Setup complete!"

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	forge clean
	rm -rf out/ cache/

# Building
build: ## Compile contracts
	@echo "Compiling contracts..."
	forge build

# Testing
test: ## Run all tests
	@echo "Running tests..."
	forge test -vvv

test-verbose: ## Run tests with maximum verbosity
	@echo "Running tests with full verbosity..."
	forge test -vvvv

test-gas: ## Run tests with gas reporting
	@echo "Running tests with gas reporting..."
	forge test --gas-report

coverage: ## Generate test coverage report
	@echo "Generating coverage report..."
	forge coverage --report lcov
	@echo "Coverage report generated in lcov.info"

gas-report: ## Generate detailed gas usage report
	@echo "Generating gas report..."
	forge test --gas-report > gas-report.txt
	@echo "Gas report saved to gas-report.txt"

# Code Quality
format: ## Format Solidity code
	@echo "Formatting Solidity code..."
	forge fmt

lint: ## Run Solidity linter
	@echo "Running Solidity linter..."
	solhint 'src/**/*.sol' 'test/**/*.sol' 'script/**/*.sol'

# Static Analysis
analyze: ## Run static analysis with Slither
	@echo "Running static analysis..."
	slither .

# Deployment
deploy-ethereum: ## Deploy to Ethereum mainnet
	@echo "Deploying to Ethereum mainnet..."
	forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem --rpc-url $(ETHEREUM_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

deploy-base: ## Deploy to Base network
	@echo "Deploying to Base network..."
	forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem --rpc-url $(BASE_RPC_URL) --broadcast --verify --etherscan-api-key $(BASESCAN_API_KEY)

deploy-sova: ## Deploy to Sova network
	@echo "Deploying to Sova network..."
	forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem --rpc-url $(SOVA_RPC_URL) --broadcast

deploy-sepolia: ## Deploy to Sepolia testnet
	@echo "Deploying to Sepolia testnet..."
	forge script script/DeploySovaBTCYieldSystem.s.sol:DeploySovaBTCYieldSystem --rpc-url $(SEPOLIA_RPC_URL) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY)

# Development Utilities
install-deps: ## Install additional development dependencies
	@echo "Installing additional dependencies..."
	npm install --save-dev solhint slither-analyzer

node: ## Start local Anvil node for testing
	@echo "Starting local Anvil node..."
	anvil --host 0.0.0.0 --port 8545

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	forge doc --build

# Verification
verify-contracts: ## Verify deployed contracts on Etherscan
	@echo "Please use the deploy commands with --verify flag for automatic verification"

# Environment
check-env: ## Check environment configuration
	@echo "Checking environment configuration..."
	@if [ -z "$(PRIVATE_KEY)" ]; then echo "❌ PRIVATE_KEY not set"; else echo "✅ PRIVATE_KEY configured"; fi
	@if [ -z "$(ETHEREUM_RPC_URL)" ]; then echo "❌ ETHEREUM_RPC_URL not set"; else echo "✅ ETHEREUM_RPC_URL configured"; fi
	@if [ -z "$(BASE_RPC_URL)" ]; then echo "❌ BASE_RPC_URL not set"; else echo "✅ BASE_RPC_URL configured"; fi
	@if [ -z "$(SOVA_RPC_URL)" ]; then echo "❌ SOVA_RPC_URL not set"; else echo "✅ SOVA_RPC_URL configured"; fi

# Quick commands for common workflows
quick-test: format test ## Format code and run tests
full-check: format lint test coverage ## Complete code quality check
deploy-testnet: deploy-sepolia ## Deploy to testnet for testing