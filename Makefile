# SovaBTC Yield System - Streamlined Makefile
# Provides simple commands for development and deployment

.PHONY: help setup test coverage gas-report clean validate-env deploy-full deploy-status health-check

# Default target
help: ## Show this help message
	@echo "SovaBTC Yield System - Available Commands"
	@echo "========================================"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

#==============================================================================
# DEVELOPMENT COMMANDS
#==============================================================================

setup: ## Install dependencies and setup development environment
	@echo "Setting up development environment..."
	@forge install
	@chmod +x scripts/*.sh
	@if [ ! -f .env ]; then cp .env.streamlined .env; echo "Created .env from template"; fi
	@echo "✅ Setup complete! Please configure your .env file."

test: ## Run all tests
	@echo "Running tests..."
	@forge test -vv

coverage: ## Generate test coverage report
	@echo "Generating coverage report..."
	@forge coverage

gas-report: ## Generate gas usage report
	@echo "Generating gas report..."
	@forge test --gas-report

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	@forge clean
	@rm -rf broadcast/
	@rm -rf cache/
	@rm -rf out/

#==============================================================================
# DEPLOYMENT COMMANDS
#==============================================================================

validate-env: ## Validate environment configuration
	@echo "Validating environment configuration..."
	@./scripts/validate-env.sh

deploy-full: validate-env ## Deploy complete system across all networks
	@echo "Starting full system deployment..."
	@./scripts/deploy-full-system.sh

deploy-status: ## Check deployment status across all networks
	@echo "Checking deployment status..."
	@./scripts/deployment-status.sh

#==============================================================================
# TESTING & MONITORING COMMANDS
#==============================================================================

health-check: ## Run system health checks
	@echo "Running system health checks..."
	@./scripts/health-check.sh

comprehensive-test: ## Run end-to-end system tests
	@echo "Running comprehensive tests..."
	@./scripts/comprehensive-test.sh

#==============================================================================
# NETWORK-SPECIFIC DEPLOYMENTS (Advanced)
#==============================================================================

deploy-ethereum: validate-env ## Deploy to Ethereum mainnet only
	@echo "Deploying to Ethereum..."
	@forge script script/DeployStage1_Core.s.sol --rpc-url $$ETHEREUM_RPC_URL --broadcast --verify

deploy-base: validate-env ## Deploy to Base mainnet only
	@echo "Deploying to Base..."
	@forge script script/DeployStage1_Core.s.sol --rpc-url $$BASE_RPC_URL --broadcast --verify

deploy-sova: validate-env ## Deploy to Sova Network only
	@echo "Deploying to Sova Network..."
	@forge script script/DeployStage1_Core.s.sol --rpc-url $$SOVA_RPC_URL --broadcast --verify

#==============================================================================
# TESTNET DEPLOYMENTS
#==============================================================================

deploy-sepolia: validate-env ## Deploy to Sepolia testnet
	@echo "Deploying to Sepolia..."
	@forge script script/DeployMockTokens.s.sol --rpc-url $$SEPOLIA_RPC_URL --broadcast --verify
	@forge script script/DeployStage1_Core.s.sol --rpc-url $$SEPOLIA_RPC_URL --broadcast --verify

deploy-base-sepolia: validate-env ## Deploy to Base Sepolia testnet
	@echo "Deploying to Base Sepolia..."
	@forge script script/DeployMockTokens.s.sol --rpc-url $$BASE_SEPOLIA_RPC_URL --broadcast --verify
	@forge script script/DeployStage1_Core.s.sol --rpc-url $$BASE_SEPOLIA_RPC_URL --broadcast --verify

#==============================================================================
# UTILITY COMMANDS
#==============================================================================

format: ## Format code
	@echo "Formatting code..."
	@forge fmt

lint: ## Lint code
	@echo "Linting code..."
	@forge fmt --check

build: ## Build contracts
	@echo "Building contracts..."
	@forge build

install: ## Install forge dependencies
	@echo "Installing dependencies..."
	@forge install

update: ## Update forge dependencies
	@echo "Updating dependencies..."
	@forge update

#==============================================================================
# QUICK START GUIDE
#==============================================================================

quick-start: ## Show quick start guide
	@echo ""
	@echo "🚀 SovaBTC Yield System - Quick Start Guide"
	@echo "==========================================="
	@echo ""
	@echo "1. First-time setup:"
	@echo "   make setup"
	@echo ""
	@echo "2. Configure your environment:"
	@echo "   Edit .env file with your settings"
	@echo ""
	@echo "3. Validate configuration:"
	@echo "   make validate-env"
	@echo ""
	@echo "4. Deploy complete system:"
	@echo "   make deploy-full"
	@echo ""
	@echo "5. Check deployment status:"
	@echo "   make deploy-status"
	@echo ""
	@echo "6. Run health checks:"
	@echo "   make health-check"
	@echo ""
	@echo "For testnet deployment:"
	@echo "   make deploy-sepolia"
	@echo "   make deploy-base-sepolia"
	@echo ""
	@echo "For development:"
	@echo "   make test"
	@echo "   make coverage"
	@echo ""

#==============================================================================
# ENVIRONMENT INFORMATION
#==============================================================================

env-info: ## Show environment information
	@echo "Environment Information:"
	@echo "======================="
	@if [ -f .env ]; then \
		echo "✅ .env file exists"; \
		echo "📊 Variables set: $$(grep -c "^[^#].*=" .env 2>/dev/null || echo 0)"; \
	else \
		echo "❌ .env file not found"; \
	fi
	@echo "🔧 Forge version: $$(forge --version | head -1 2>/dev/null || echo 'Not installed')"
	@echo "📁 Current directory: $$(pwd)"
	@echo "🌐 Available networks: Ethereum, Base, Sova Network"