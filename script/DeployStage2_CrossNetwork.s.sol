// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import "../src/vault/SovaBTCYieldVault.sol";
import "../src/bridges/BridgedSovaBTC.sol";

/**
 * @title Stage 2: Cross-Network Configuration
 * @notice Configures cross-network token support after all Stage 1 deployments
 * @dev This stage:
 *      1. Reads all Stage 1 deployment addresses
 *      2. Adds BridgedSovaBTC tokens from other networks as supported assets
 *      3. Configures cross-network recognition
 */
contract DeployStage2_CrossNetwork is Script {
    using stdJson for string;

    struct NetworkDeployment {
        uint256 chainId;
        string network;
        bool isSovaNetwork;
        address bridgedSovaBTC;
        address yieldVault;
        address yieldStaking;
        address redemptionQueue;
    }

    struct CrossNetworkConfig {
        uint256 currentChainId;
        NetworkDeployment currentNetwork;
        NetworkDeployment[] otherNetworks;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== STAGE 2: CROSS-NETWORK CONFIGURATION ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        vm.startBroadcast(deployerPrivateKey);

        CrossNetworkConfig memory config = loadCrossNetworkConfig();
        configureCrossNetworkSupport(config);

        vm.stopBroadcast();

        console.log("\\n Stage 2 configuration complete for chain", block.chainid);
        console.log("Run Stage 2 on all networks to complete cross-network setup");
    }

    function loadCrossNetworkConfig() internal view returns (CrossNetworkConfig memory) {
        uint256 currentChainId = block.chainid;
        
        // Load current network deployment
        NetworkDeployment memory currentNetwork = loadNetworkDeployment(currentChainId);
        
        // Load other network deployments
        uint256[] memory otherChainIds = getOtherChainIds(currentChainId);
        NetworkDeployment[] memory otherNetworks = new NetworkDeployment[](otherChainIds.length);
        
        for (uint256 i = 0; i < otherChainIds.length; i++) {
            otherNetworks[i] = loadNetworkDeployment(otherChainIds[i]);
        }
        
        return CrossNetworkConfig({
            currentChainId: currentChainId,
            currentNetwork: currentNetwork,
            otherNetworks: otherNetworks
        });
    }

    function loadNetworkDeployment(uint256 chainId) internal view returns (NetworkDeployment memory) {
        string memory filename = string.concat("deployments/stage1-", vm.toString(chainId), ".json");
        
        try vm.readFile(filename) returns (string memory json) {
            return NetworkDeployment({
                chainId: chainId,
                network: json.readString(".network"),
                isSovaNetwork: json.readBool(".isSovaNetwork"),
                bridgedSovaBTC: json.keyExists(".contracts.bridgedSovaBTC") 
                    ? json.readAddress(".contracts.bridgedSovaBTC") 
                    : address(0),
                yieldVault: json.readAddress(".contracts.yieldVault"),
                yieldStaking: json.readAddress(".contracts.yieldStaking"),
                redemptionQueue: json.readAddress(".contracts.redemptionQueue")
            });
        } catch {
            revert(string.concat("Failed to load deployment for chain ", vm.toString(chainId), ". Run Stage 1 first."));
        }
    }

    function getOtherChainIds(uint256 currentChainId) internal pure returns (uint256[] memory) {
        // Define all supported chain IDs
        uint256[] memory allChains = new uint256[](5);
        allChains[0] = 1;      // Ethereum
        allChains[1] = 8453;   // Base
        allChains[2] = 11155111; // Sepolia
        allChains[3] = 84532;  // Base Sepolia
        // allChains[4] = SOVA_CHAIN_ID; // Sova Network (from env)
        
        // For now, hardcode Sova chain ID as example
        allChains[4] = 123456; // Replace with actual Sova chain ID
        
        // Count other chains
        uint256 count = 0;
        for (uint256 i = 0; i < allChains.length; i++) {
            if (allChains[i] != currentChainId) {
                count++;
            }
        }
        
        // Build array of other chain IDs
        uint256[] memory otherChains = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allChains.length; i++) {
            if (allChains[i] != currentChainId) {
                otherChains[index] = allChains[i];
                index++;
            }
        }
        
        return otherChains;
    }

    function configureCrossNetworkSupport(CrossNetworkConfig memory config) internal {
        console.log("Configuring cross-network token support...");
        
        SovaBTCYieldVault vault = SovaBTCYieldVault(config.currentNetwork.yieldVault);
        
        // Add BridgedSovaBTC tokens from other networks as supported assets
        uint256 addedTokens = 0;
        
        for (uint256 i = 0; i < config.otherNetworks.length; i++) {
            NetworkDeployment memory otherNetwork = config.otherNetworks[i];
            
            // Skip if other network is Sova Network (no BridgedSovaBTC there)
            if (otherNetwork.isSovaNetwork) {
                console.log("Skipping Sova Network (native sovaBTC)");
                continue;
            }
            
            // Skip if current network is Sova Network (different configuration needed)
            if (config.currentNetwork.isSovaNetwork) {
                console.log("Current network is Sova Network - different configuration needed");
                continue;
            }
            
            // Add the other network's BridgedSovaBTC as a supported asset
            if (otherNetwork.bridgedSovaBTC != address(0)) {
                try vault.addSupportedAsset(
                    otherNetwork.bridgedSovaBTC,
                    string.concat("BridgedSovaBTC from ", otherNetwork.network)
                ) {
                    console.log("Added", otherNetwork.network, "BridgedSovaBTC as supported asset:", otherNetwork.bridgedSovaBTC);
                    addedTokens++;
                } catch {
                    console.log("Warning: Could not add", otherNetwork.network, "BridgedSovaBTC (may already exist)");
                }
            }
        }
        
        console.log("Cross-network configuration complete. Added", addedTokens, "cross-network tokens.");
        
        // Log current supported assets
        logSupportedAssets(vault);
    }

    function logSupportedAssets(SovaBTCYieldVault vault) internal view {
        console.log("\nCurrently supported assets:");
        
        try vault.getSupportedAssets() returns (address[] memory assets) {
            for (uint256 i = 0; i < assets.length; i++) {
                console.log("-", assets[i]);
            }
        } catch {
            console.log("Could not retrieve supported assets list");
        }
    }

    /**
     * @dev Helper function for manual cross-network configuration
     * @param targetVault Vault to configure
     * @param tokenAddress Token address to add
     * @param tokenName Human-readable token name
     */
    function addCrossNetworkToken(
        address targetVault,
        address tokenAddress,
        string memory tokenName
    ) external {
        require(msg.sender == vm.envAddress("OWNER_ADDRESS"), "Only owner");
        
        SovaBTCYieldVault vault = SovaBTCYieldVault(targetVault);
        vault.addSupportedAsset(tokenAddress, tokenName);
        
        console.log("Manually added cross-network token:", tokenName, "at", tokenAddress);
    }

    /**
     * @dev Emergency function to configure Sova Network vault
     * @dev Sova Network vault should accept BridgedSovaBTC from all other networks
     */
    function configureSovaNetworkVault() external {
        require(msg.sender == vm.envAddress("OWNER_ADDRESS"), "Only owner");
        
        uint256 currentChainId = block.chainid;
        NetworkDeployment memory currentNetwork = loadNetworkDeployment(currentChainId);
        
        require(currentNetwork.isSovaNetwork, "This function is only for Sova Network");
        
        SovaBTCYieldVault vault = SovaBTCYieldVault(currentNetwork.yieldVault);
        
        // Get all external networks
        uint256[] memory otherChainIds = getOtherChainIds(currentChainId);
        
        for (uint256 i = 0; i < otherChainIds.length; i++) {
            NetworkDeployment memory otherNetwork = loadNetworkDeployment(otherChainIds[i]);
            
            if (!otherNetwork.isSovaNetwork && otherNetwork.bridgedSovaBTC != address(0)) {
                try vault.addSupportedAsset(
                    otherNetwork.bridgedSovaBTC,
                    string.concat("BridgedSovaBTC from ", otherNetwork.network)
                ) {
                    console.log("Added", otherNetwork.network, "BridgedSovaBTC to Sova vault");
                } catch {
                    console.log("Warning: Could not add", otherNetwork.network, "BridgedSovaBTC to Sova vault");
                }
            }
        }
        
        console.log("Sova Network vault configuration complete");
    }
}