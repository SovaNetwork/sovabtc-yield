// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title MockSOVA
 * @notice Mock SOVA token for testnet deployments
 * @dev Implements standard ERC20 with 18 decimals like real SOVA
 */
contract MockSOVA is ERC20Upgradeable, OwnableUpgradeable {
    uint8 private constant DECIMALS = 18;

    constructor(string memory name, string memory symbol, uint8) {
        initialize(name, symbol);
    }

    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        
        // Mint initial supply to deployer for testing
        _mint(msg.sender, 1000000 * 10**DECIMALS); // 1M SOVA
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /**
     * @notice Mint tokens for testing purposes
     * @param to Address to mint tokens to
     * @param amount Amount to mint (in smallest unit)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burn tokens from caller
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /**
     * @notice Faucet function for easy testnet token acquisition
     * @dev Allows anyone to mint up to 1000 SOVA per call
     */
    function faucet() external {
        require(balanceOf(msg.sender) < 10000 * 10**DECIMALS, "Already has enough tokens");
        _mint(msg.sender, 1000 * 10**DECIMALS); // 1000 SOVA
    }
}