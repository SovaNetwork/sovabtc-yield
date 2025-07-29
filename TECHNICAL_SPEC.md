# SovaBTC Yield System Technical Specification

## Overview

The SovaBTC Yield System is a comprehensive DeFi platform designed for multi-chain Bitcoin yield generation. Built with ERC-4626 compliance and Hyperlane cross-chain integration, the system enables users to deposit various Bitcoin variants and earn professionally managed yield through investment strategies.

## Architecture Overview

### Core Components

1. **SovaBTCYieldVault**: ERC-4626 compliant vault for multi-asset Bitcoin deposits
2. **BridgedSovaBTC**: Cross-chain sovaBTC token using Hyperlane burn-and-mint bridge
3. **SovaBTCYieldStaking**: Dual token staking system with symbiotic rewards

### Network Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ethereum      │    │      Base       │    │  Sova Network   │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ YieldVault  │ │    │ │ YieldVault  │ │    │ │ YieldVault  │ │
│ │ (WBTC)      │ │    │ │ (cbBTC)     │ │    │ │ (sovaBTC)   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │BridgedSovaBTC│◄────┼─┤BridgedSovaBTC│◄────┼─┤Native sovaBTC│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ YieldStaking│ │    │ │ YieldStaking│ │    │ │ YieldStaking│ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                        ┌─────────────────┐
                        │  Hyperlane      │
                        │  Network        │
                        └─────────────────┘
```

## Contract Specifications

### 1. SovaBTCYieldVault

**Purpose**: Multi-asset Bitcoin yield generation vault with ERC-4626 compliance

**Key Features**:
- ERC-4626 standard implementation with multi-asset support
- Decimal normalization for 6, 8, and 18 decimal tokens
- Dynamic exchange rate tracking yield accumulation
- Admin-controlled asset withdrawal for investment strategies
- Network-aware reward token integration

**Storage Layout**:
```solidity
contract SovaBTCYieldVault {
    bool public isSovaNetwork;                    // Network identification
    IERC20 public rewardToken;                    // sovaBTC or BridgedSovaBTC
    mapping(address => bool) public supportedAssets; // Supported deposit tokens
    address[] public supportedAssetsList;         // Enumerable asset list
    uint256 public assetsUnderManagement;         // Assets withdrawn for strategies
    uint256 public exchangeRate;                  // Yield accumulation rate
    uint256 public constant EXCHANGE_RATE_PRECISION = 1e18;
}
```

**Critical Functions**:

```solidity
// Multi-asset deposit with decimal normalization
function depositAsset(address asset, uint256 amount, address receiver) 
    external returns (uint256 shares);

// Standard ERC-4626 redemption (underlying assets)
function redeem(uint256 shares, address receiver, address owner) 
    external returns (uint256 assets);

// Redeem vault shares for sovaBTC rewards (yield distribution)
function redeemForRewards(uint256 shares, address receiver) 
    external returns (uint256 rewardAmount);

// Admin functions
function addSupportedAsset(address asset, string memory name) external onlyOwner;
function adminWithdraw(address asset, uint256 amount, address destination) external onlyOwner;
function addYield(uint256 rewardAmount) external onlyOwner;
```

**Exchange Rate Mechanism**:
```solidity
// Exchange rate calculation
exchangeRate = (totalAssets() + yieldAdded) * EXCHANGE_RATE_PRECISION / totalSupply()

// Reward redemption calculation  
rewardAmount = shares * exchangeRate / EXCHANGE_RATE_PRECISION
```

### 2. BridgedSovaBTC

**Purpose**: Canonical cross-chain sovaBTC token using Hyperlane burn-and-mint bridge

**Key Features**:
- ERC-20 with 8 decimals (matching native sovaBTC precision)
- Hyperlane integration for secure cross-chain messaging
- Role-based access control (BRIDGE_ROLE, VAULT_ROLE, ADMIN_ROLE)
- Burn-and-mint bridge model for total supply consistency

**Storage Layout**:
```solidity
contract BridgedSovaBTC {
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant VAULT_ROLE = keccak256("VAULT_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    address public constant SOVA_NETWORK_SOVABTC = 0x2100000000000000000000000000000000000020;
    address public hyperlaneMailbox;
    uint32 public constant SOVA_DOMAIN = 0; // TBD: Actual Sova domain ID
}
```

**Hyperlane Integration**:

```solidity
// Outbound bridging (to Sova Network)
function bridgeToSova(address recipient, uint256 amount) external {
    _burn(msg.sender, amount);                           // Remove from supply
    bytes memory message = abi.encode(recipient, amount); // Encode message
    IHyperlaneMailbox(hyperlaneMailbox).dispatch(
        SOVA_DOMAIN,
        addressToBytes32(SOVA_NETWORK_SOVABTC),
        message
    );
}

// Inbound message handling (from other chains)
function handle(uint32 origin, bytes32 sender, bytes calldata body) external {
    require(msg.sender == hyperlaneMailbox, "Invalid mailbox");
    (address recipient, uint256 amount) = abi.decode(body, (address, uint256));
    _mint(recipient, amount);                            // Add to supply
}
```

**Security Model**:
- **Caller Validation**: Only Hyperlane Mailbox can call `handle()`
- **Role-Based Minting**: BRIDGE_ROLE for cross-chain, VAULT_ROLE for yield
- **Message Integrity**: Hyperlane's cryptographic validation
- **Domain Isolation**: Hardcoded domain IDs prevent confusion

### 3. SovaBTCYieldStaking

**Purpose**: Dual token staking system with symbiotic reward structure

**Key Features**:
- Two-tier staking: sovaBTCYield → SOVA → sovaBTC
- Lock periods with reward multipliers (1.0x to 2.0x)
- Dual staking bonus (+20% for holding both tokens)
- Emergency unstaking with penalties

**Storage Layout**:
```solidity
contract SovaBTCYieldStaking {
    IERC20 public vaultToken;                    // sovaBTCYield token
    IERC20 public sovaToken;                     // SOVA token
    IERC20 public rewardToken;                   // sovaBTC/BridgedSovaBTC
    bool public isSovaNetwork;                   // Network identification
    
    struct UserStake {
        uint256 vaultTokenAmount;                // Staked vault tokens
        uint256 sovaAmount;                      // Staked SOVA tokens
        uint256 vaultTokenStakeTime;             // Vault token stake timestamp
        uint256 sovaStakeTime;                   // SOVA stake timestamp
        uint256 lockEndTime;                     // Lock expiration timestamp
        uint256 lastRewardUpdate;                // Last reward calculation time
        uint256 accumulatedSovaRewards;          // Pending SOVA rewards
        uint256 accumulatedSovaBTCRewards;       // Pending sovaBTC rewards
    }
    
    mapping(address => UserStake) public userStakes;
}
```

**Staking Mechanics**:

```solidity
// Lock period multipliers
mapping(uint256 => uint256) public lockMultipliers = {
    0:          1000,  // 1.0x (no lock)
    30 days:    1100,  // 1.1x (+10%)
    90 days:    1250,  // 1.25x (+25%)
    180 days:   1500,  // 1.5x (+50%)
    365 days:   2000   // 2.0x (+100%)
};

// Reward calculation
function calculateRewards(address user) public view returns (uint256 sovaRewards, uint256 sovaBTCRewards) {
    UserStake memory stake = userStakes[user];
    uint256 timeStaked = block.timestamp - stake.lastRewardUpdate;
    
    // SOVA rewards from vault tokens
    sovaRewards = stake.vaultTokenAmount * vaultToSovaRate * timeStaked * lockMultiplier;
    
    // Apply dual staking bonus if both tokens staked
    if (stake.vaultTokenAmount > 0 && stake.sovaAmount > 0) {
        sovaRewards = sovaRewards * dualStakeMultiplier / 10000;
    }
    
    // sovaBTC rewards from SOVA tokens (requires vault tokens staked)
    if (stake.vaultTokenAmount > 0) {
        sovaBTCRewards = stake.sovaAmount * sovaToSovaBTCRate * timeStaked * lockMultiplier;
    }
}
```

## Network-Specific Configurations

### Ethereum Mainnet
- **Primary Asset**: WBTC (0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)
- **Reward Token**: BridgedSovaBTC
- **Hyperlane Mailbox**: TBD
- **Domain ID**: 1

### Base Network
- **Primary Asset**: cbBTC (0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf)
- **Reward Token**: BridgedSovaBTC
- **Hyperlane Mailbox**: TBD
- **Domain ID**: 8453

### Sova Network
- **Primary Asset**: Native sovaBTC (0x2100000000000000000000000000000000000020)
- **Reward Token**: Native sovaBTC
- **Hyperlane Mailbox**: TBD
- **Domain ID**: TBD

## Deployment Process

### 1. Network Detection
```solidity
function issovaNetwork() internal view returns (bool) {
    // Check for native sovaBTC precompile address
    return IERC20(0x2100000000000000000000000000000000000020).totalSupply() > 0;
}
```

### 2. Contract Deployment Order
1. **BridgedSovaBTC** (if not Sova Network)
2. **SovaBTCYieldVault** with network-appropriate reward token
3. **SovaBTCYieldStaking** with network-appropriate configuration
4. **Role Configuration** and asset setup

### 3. Post-Deployment Configuration
- Grant VAULT_ROLE to yield vault on BridgedSovaBTC
- Add supported assets to vault (network-specific)
- Configure staking reward rates
- Set up Hyperlane mailbox addresses

## Security Considerations

### Access Control
- **Multi-signature recommended** for all admin functions
- **Role-based permissions** for cross-chain and yield operations
- **Upgrade controls** via UUPS proxy pattern

### Cross-Chain Security
- **Hyperlane validation** ensures message integrity
- **Domain isolation** prevents cross-chain confusion
- **Burn-and-mint consistency** maintains total supply invariants

### Economic Security
- **Exchange rate manipulation** protected by admin-controlled yield addition
- **Reward pool management** ensures sustainable token distribution
- **Emergency controls** allow pause/unpause during incidents

### Emergency Procedures
1. **Pause Contracts**: Immediate halt of all operations
2. **Emergency Unstaking**: User exit with penalties
3. **Asset Recovery**: Admin withdrawal for security
4. **Upgrade Path**: UUPS proxy upgrades with timelock

## Integration Points

### DeFi Composability
- **ERC-4626 Compliance**: Standard vault interface for integrations
- **ERC-20 Tokens**: All tokens follow standard interfaces
- **Multi-Asset Support**: Flexible asset composition

### Cross-Chain Interoperability
- **Hyperlane Protocol**: Battle-tested cross-chain messaging
- **Canonical Tokens**: Consistent sovaBTC representation
- **Network Agnostic**: Deploy on any EVM-compatible chain

### External Dependencies
- **OpenZeppelin Contracts**: Security-audited base implementations
- **Hyperlane Infrastructure**: Cross-chain message delivery
- **Network RPC Endpoints**: For multi-chain deployment

## Testing Strategy

### Unit Tests
- Individual contract function testing
- Edge case and boundary condition testing
- Access control and permission testing

### Integration Tests
- Cross-contract interaction testing
- Multi-asset deposit and withdrawal flows
- Staking and reward distribution testing

### Cross-Chain Tests
- Hyperlane message flow testing
- Bridge token consistency testing
- Network-specific configuration testing

### Security Tests
- Reentrancy attack prevention
- Access control bypass attempts
- Economic attack vector testing

## Future Enhancements

### Planned Features
1. **Automated Yield Strategies**: Integration with DeFi protocols
2. **Governance System**: Community-controlled parameter updates
3. **Additional Networks**: Expansion to other EVM chains
4. **Advanced Staking**: NFT-based position management

### Scalability Considerations
- **Layer 2 Deployment**: Polygon, Arbitrum, Optimism support
- **Gas Optimization**: Batch operations and efficient storage
- **Cross-Chain Efficiency**: Hyperlane optimization

This technical specification provides the foundational architecture for the SovaBTC Yield System, ensuring security, scalability, and multi-chain compatibility.