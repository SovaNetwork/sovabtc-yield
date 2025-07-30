// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";

import "../src/mocks/MockWBTC.sol";
import "../src/mocks/MockCBBTC.sol";
import "../src/mocks/MockTBTC.sol";
import "../src/mocks/MockSOVA.sol";

/**
 * @title Deploy Mock Tokens for Testnet
 * @notice Deploys mock versions of WBTC, cbBTC, tBTC, and SOVA for testing
 * @dev Only for testnet deployments - do not use on mainnet
 */
contract DeployMockTokens is Script {
    struct MockTokens {
        address wbtc;
        address cbbtc;
        address tbtc;
        address sova;
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYING MOCK TOKENS ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);

        // Ensure this is not mainnet
        require(
            block.chainid != 1 && block.chainid != 8453,
            "Do not deploy mock tokens on mainnet!"
        );

        vm.startBroadcast(deployerPrivateKey);

        MockTokens memory tokens = deployMockTokens();

        vm.stopBroadcast();

        logMockTokenDeployment(tokens);
        saveMockTokenDeployment(tokens);
    }

    function deployMockTokens() internal returns (MockTokens memory) {
        console.log("Deploying mock tokens...");

        // Deploy Mock WBTC (8 decimals)
        MockWBTC wbtc = new MockWBTC("Mock Wrapped Bitcoin", "WBTC", 8);
        console.log("Mock WBTC deployed at:", address(wbtc));

        // Deploy Mock cbBTC (8 decimals)
        MockCBBTC cbbtc = new MockCBBTC("Mock Coinbase Wrapped Bitcoin", "cbBTC", 8);
        console.log("Mock cbBTC deployed at:", address(cbbtc));

        // Deploy Mock tBTC (18 decimals)
        MockTBTC tbtc = new MockTBTC("Mock Threshold Bitcoin", "tBTC", 18);
        console.log("Mock tBTC deployed at:", address(tbtc));

        // Deploy Mock SOVA (18 decimals)
        MockSOVA sova = new MockSOVA("Mock Sova Token", "SOVA", 18);
        console.log("Mock SOVA deployed at:", address(sova));

        return MockTokens({
            wbtc: address(wbtc),
            cbbtc: address(cbbtc),
            tbtc: address(tbtc),
            sova: address(sova)
        });
    }

    function logMockTokenDeployment(MockTokens memory tokens) internal view {
        console.log("\n=== MOCK TOKEN DEPLOYMENT COMPLETE ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        
        console.log("\nMock Token Addresses:");
        console.log("WBTC:", tokens.wbtc);
        console.log("cbBTC:", tokens.cbbtc);
        console.log("tBTC:", tokens.tbtc);
        console.log("SOVA:", tokens.sova);
        
        console.log("\nAdd these to your .env.testnet file:");
        console.log(string.concat("MOCK_WBTC_", getNetworkSuffix(), "=", vm.toString(tokens.wbtc)));
        console.log(string.concat("MOCK_CBBTC_", getNetworkSuffix(), "=", vm.toString(tokens.cbbtc)));
        console.log(string.concat("MOCK_TBTC_", getNetworkSuffix(), "=", vm.toString(tokens.tbtc)));
        console.log(string.concat("MOCK_SOVA_", getNetworkSuffix(), "=", vm.toString(tokens.sova)));
        console.log("==========================================\n");
    }

    function saveMockTokenDeployment(MockTokens memory tokens) internal {
        string memory networkSuffix = getNetworkSuffix();
        
        string memory deploymentJson = string.concat(
            "{\n",
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "network": "', networkSuffix, '",\n',
            '  "blockNumber": ', vm.toString(block.number), ',\n',
            '  "timestamp": "', vm.toString(block.timestamp), '",\n',
            '  "tokens": {\n',
            '    "wbtc": "', vm.toString(tokens.wbtc), '",\n',
            '    "cbbtc": "', vm.toString(tokens.cbbtc), '",\n',
            '    "tbtc": "', vm.toString(tokens.tbtc), '",\n',
            '    "sova": "', vm.toString(tokens.sova), '"\n',
            '  }\n',
            '}'
        );

        string memory filename = string.concat("deployments/mock-tokens-", vm.toString(block.chainid), ".json");
        vm.writeFile(filename, deploymentJson);
        console.log("Mock token deployment saved to:", filename);
    }

    function getNetworkSuffix() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        
        if (chainId == 11155111) {
            return "SEPOLIA";
        } else if (chainId == 84532) {
            return "BASE_SEPOLIA";
        } else if (chainId == 421614) {
            return "ARBITRUM_SEPOLIA";
        } else {
            return string.concat("CHAIN_", vm.toString(chainId));
        }
    }

    /**
     * @dev Helper function to mint tokens to an address for testing
     * @param token Token contract address
     * @param to Address to mint to
     * @param amount Amount to mint (in token's native decimals)
     */
    function mintTokens(address token, address to, uint256 amount) external {
        require(msg.sender == vm.envAddress("OWNER_ADDRESS"), "Only owner");
        
        uint256 chainId = block.chainid;
        require(chainId != 1 && chainId != 8453, "Not for mainnet");
        
        if (MockWBTC(token).owner() == msg.sender) {
            MockWBTC(token).mint(to, amount);
        } else if (MockCBBTC(token).owner() == msg.sender) {
            MockCBBTC(token).mint(to, amount);
        } else if (MockTBTC(token).owner() == msg.sender) {
            MockTBTC(token).mint(to, amount);
        } else if (MockSOVA(token).owner() == msg.sender) {
            MockSOVA(token).mint(to, amount);
        } else {
            revert("Invalid token or not owner");
        }
        
        console.log("Minted", amount, "tokens to", to);
    }
}