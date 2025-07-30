// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import "../src/vault/SovaBTCYieldVault.sol";
import "../src/staking/SovaBTCYieldStaking.sol";
import "../src/bridges/BridgedSovaBTC.sol";
import "../src/redemption/RedemptionQueue.sol";

/**
 * @title Stage 1: Core System Deployment
 * @notice Deploys core contracts with minimal dependencies
 * @dev This stage deploys:
 *      1. BridgedSovaBTC (if not Sova Network)
 *      2. Basic vault with primary asset only
 *      3. Staking contract
 *      4. Redemption queue
 */
contract DeployStage1_Core is Script {
    struct Stage1Config {
        address owner;
        address sovaToken;
        address hyperlaneMailbox;
        uint256 chainId;
        bool isSovaNetwork;
        address primaryAsset;
        string primaryAssetName;
        string networkName;
    }

    struct Stage1Contracts {
        address rewardToken; // BridgedSovaBTC or native sovaBTC
        address yieldVault;
        address yieldStaking;
        address redemptionQueue;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STAGE 1: CORE SYSTEM DEPLOYMENT ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        Stage1Config memory config = getStage1Config();
        Stage1Contracts memory contracts = deployStage1Contracts(config);
        configureStage1Contracts(config, contracts);

        vm.stopBroadcast();

        logStage1Deployment(contracts, config);
        saveStage1Deployment(contracts, config);
        
        console.log("\\n Stage 1 deployment complete!");
        console.log("Next: Deploy Stage 1 on all target networks, then run Stage 2");
    }

    function getStage1Config() internal view returns (Stage1Config memory) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            return Stage1Config({
                owner: vm.envAddress("OWNER_ADDRESS"),
                sovaToken: vm.envAddress("SOVA_TOKEN_ADDRESS"),
                hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_MAINNET"),
                chainId: chainId,
                isSovaNetwork: false,
                primaryAsset: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
                primaryAssetName: "Wrapped Bitcoin",
                networkName: "Ethereum"
            });
        } else if (chainId == 8453) {
            return Stage1Config({
                owner: vm.envAddress("OWNER_ADDRESS"),
                sovaToken: vm.envAddress("SOVA_TOKEN_ADDRESS"),
                hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_BASE"),
                chainId: chainId,
                isSovaNetwork: false,
                primaryAsset: 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf, // cbBTC
                primaryAssetName: "Coinbase Wrapped BTC",
                networkName: "Base"
            });
        } else if (chainId == vm.envUint("SOVA_CHAIN_ID")) {
            return Stage1Config({
                owner: vm.envAddress("OWNER_ADDRESS"),
                sovaToken: vm.envAddress("SOVA_TOKEN_ADDRESS"),
                hyperlaneMailbox: vm.envAddress("HYPERLANE_MAILBOX_SOVA"),
                chainId: chainId,
                isSovaNetwork: true,
                primaryAsset: 0x2100000000000000000000000000000000000020, // Native sovaBTC
                primaryAssetName: "Sova Bitcoin",
                networkName: "Sova"
            });
        } else if (chainId == 11155111) {
            // Sepolia - use mock tokens
            return Stage1Config({
                owner: vm.envAddress("OWNER_ADDRESS"),
                sovaToken: vm.envOr("MOCK_SOVA_SEPOLIA", address(0)),
                hyperlaneMailbox: vm.envOr("HYPERLANE_MAILBOX_SEPOLIA", 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766),
                chainId: chainId,
                isSovaNetwork: false,
                primaryAsset: vm.envOr("MOCK_WBTC_SEPOLIA", address(0)),
                primaryAssetName: "Mock Wrapped Bitcoin",
                networkName: "Sepolia"
            });
        } else if (chainId == 84532) {
            // Base Sepolia - use mock tokens
            return Stage1Config({
                owner: vm.envAddress("OWNER_ADDRESS"),
                sovaToken: vm.envOr("MOCK_SOVA_BASE_SEPOLIA", address(0)),
                hyperlaneMailbox: vm.envOr("HYPERLANE_MAILBOX_BASE_SEPOLIA", 0xfFAEF09B3cd11D9b20d1a19bECca54EEC2884766),
                chainId: chainId,
                isSovaNetwork: false,
                primaryAsset: vm.envOr("MOCK_CBBTC_BASE_SEPOLIA", address(0)),
                primaryAssetName: "Mock Coinbase Wrapped BTC",
                networkName: "Base Sepolia"
            });
        } else {
            revert("Unsupported chain for Stage 1 deployment");
        }
    }

    function deployStage1Contracts(Stage1Config memory config) internal returns (Stage1Contracts memory) {
        address rewardToken;

        if (config.isSovaNetwork) {
            // On Sova Network, use native sovaBTC
            rewardToken = config.primaryAsset;
            console.log("Using native sovaBTC at:", rewardToken);
        } else {
            // Deploy BridgedSovaBTC for other networks
            console.log("Deploying BridgedSovaBTC...");

            BridgedSovaBTC bridgedImpl = new BridgedSovaBTC();
            bytes memory bridgedInitData = abi.encodeCall(
                BridgedSovaBTC.initialize, 
                (config.owner, config.hyperlaneMailbox, address(0))
            );
            ERC1967Proxy bridgedProxy = new ERC1967Proxy(address(bridgedImpl), bridgedInitData);
            rewardToken = address(bridgedProxy);
            
            console.log("BridgedSovaBTC deployed at:", rewardToken);
        }

        // Deploy Yield Vault (with primary asset only for now)
        console.log("Deploying SovaBTC Yield Vault...");
        SovaBTCYieldVault vaultImpl = new SovaBTCYieldVault();
        bytes memory vaultInitData = abi.encodeCall(
            SovaBTCYieldVault.initialize,
            (
                config.primaryAsset,
                rewardToken,
                config.isSovaNetwork,
                config.owner,
                string.concat("SovaBTC Yield Vault (", config.networkName, ")"),
                "sovaBTCYield"
            )
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        console.log("Vault deployed at:", address(vaultProxy));

        // Deploy Yield Staking
        console.log("Deploying SovaBTC Yield Staking...");
        SovaBTCYieldStaking stakingImpl = new SovaBTCYieldStaking();
        bytes memory stakingInitData = abi.encodeCall(
            SovaBTCYieldStaking.initialize,
            (config.owner, address(vaultProxy), config.sovaToken, rewardToken, config.isSovaNetwork)
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        console.log("Staking deployed at:", address(stakingProxy));

        // Deploy Redemption Queue
        console.log("Deploying Redemption Queue...");
        RedemptionQueue queueImpl = new RedemptionQueue();
        
        RedemptionQueue.QueueConfig memory queueConfig = RedemptionQueue.QueueConfig({
            windowDuration: 24 hours,
            enabled: true
        });
        
        bytes memory queueInitData = abi.encodeCall(
            RedemptionQueue.initialize,
            (address(vaultProxy), address(stakingProxy), queueConfig)
        );
        ERC1967Proxy queueProxy = new ERC1967Proxy(address(queueImpl), queueInitData);
        console.log("Redemption Queue deployed at:", address(queueProxy));

        return Stage1Contracts({
            rewardToken: rewardToken,
            yieldVault: address(vaultProxy),
            yieldStaking: address(stakingProxy),
            redemptionQueue: address(queueProxy)
        });
    }

    function configureStage1Contracts(Stage1Config memory config, Stage1Contracts memory contracts) internal {
        console.log("Configuring Stage 1 contracts...");

        SovaBTCYieldVault vault = SovaBTCYieldVault(contracts.yieldVault);
        SovaBTCYieldStaking staking = SovaBTCYieldStaking(contracts.yieldStaking);

        // Configure redemption queue
        vault.setRedemptionQueue(contracts.redemptionQueue);
        vault.setQueueRedemptionsEnabled(true);
        staking.setRedemptionQueue(contracts.redemptionQueue);
        staking.setQueueRedemptionsEnabled(true);

        // Grant vault role to the vault contract on BridgedSovaBTC (if applicable)
        if (!config.isSovaNetwork) {
            BridgedSovaBTC(contracts.rewardToken).grantVaultRole(contracts.yieldVault);
            console.log("Granted vault role to yield vault");
        }

        console.log("Stage 1 configuration complete!");
    }

    function logStage1Deployment(Stage1Contracts memory contracts, Stage1Config memory config) internal view {
        console.log("\n=== STAGE 1 DEPLOYMENT COMPLETE ===");
        console.log("Network:", config.networkName);
        console.log("Chain ID:", config.chainId);
        console.log("Is Sova Network:", config.isSovaNetwork);
        console.log("Block number:", block.number);
        
        console.log("\nStage 1 Contracts:");
        if (!config.isSovaNetwork) {
            console.log("BridgedSovaBTC:", contracts.rewardToken);
        }
        console.log("SovaBTC Yield Vault:", contracts.yieldVault);
        console.log("SovaBTC Yield Staking:", contracts.yieldStaking);
        console.log("Redemption Queue:", contracts.redemptionQueue);
        console.log("=====================================\n");
    }

    function saveStage1Deployment(Stage1Contracts memory contracts, Stage1Config memory config) internal {
        string memory deploymentJson = string.concat(
            "{\n",
            '  "stage": 1,\n',
            '  "chainId": ', vm.toString(config.chainId), ',\n',
            '  "network": "', config.networkName, '",\n',
            '  "isSovaNetwork": ', config.isSovaNetwork ? "true" : "false", ',\n',
            '  "blockNumber": ', vm.toString(block.number), ',\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "contracts": {\n'
        );

        if (!config.isSovaNetwork) {
            deploymentJson = string.concat(
                deploymentJson,
                '    "bridgedSovaBTC": "', vm.toString(contracts.rewardToken), '",\n'
            );
        }

        deploymentJson = string.concat(
            deploymentJson,
            '    "yieldVault": "', vm.toString(contracts.yieldVault), '",\n',
            '    "yieldStaking": "', vm.toString(contracts.yieldStaking), '",\n',
            '    "redemptionQueue": "', vm.toString(contracts.redemptionQueue), '"\n',
            '  }\n',
            '}'
        );

        string memory filename = string.concat("deployments/stage1-", vm.toString(config.chainId), ".json");
        vm.writeFile(filename, deploymentJson);
        console.log("Stage 1 deployment saved to:", filename);
    }
}