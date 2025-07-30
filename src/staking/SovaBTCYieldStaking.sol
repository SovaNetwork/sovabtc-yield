// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IRedemptionQueue} from "../redemption/IRedemptionQueue.sol";

/**
 * @title SovaBTCYieldStaking
 * @dev Dual token staking system for sovaBTCYield and SOVA tokens
 * @notice Stake sovaBTCYield to earn SOVA, then stake SOVA to earn sovaBTC rewards
 */
contract SovaBTCYieldStaking is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    struct UserStake {
        uint256 vaultTokenAmount; // Amount of sovaBTCYield staked
        uint256 sovaAmount; // Amount of SOVA staked
        uint256 sovaRewards; // Accumulated SOVA rewards
        uint256 sovaBTCRewards; // Accumulated sovaBTC rewards
        uint256 lastUpdateTime; // Last reward calculation time
        uint256 lockEndTime; // When stake unlocks
    }

    struct RewardRate {
        uint256 vaultTokenToSovaRate; // SOVA per second per vault token staked
        uint256 sovaToSovaBTCRate; // sovaBTC per second per SOVA staked
        uint256 dualStakeMultiplier; // Bonus multiplier when staking both (basis points)
    }

    /// @notice sovaBTCYield vault token
    IERC20 public vaultToken;

    /// @notice SOVA token
    IERC20 public sovaToken;

    /// @notice Reward token (sovaBTC on Sova Network, BridgedSovaBTC elsewhere)
    IERC20 public rewardToken;

    /// @notice Whether deployed on Sova Network
    bool public isSovaNetwork;

    /// @notice User stakes mapping
    mapping(address => UserStake) public userStakes;

    /// @notice Current reward rates
    RewardRate public rewardRates;

    /// @notice Total vault tokens staked
    uint256 public totalVaultTokensStaked;

    /// @notice Total SOVA tokens staked
    uint256 public totalSovaStaked;

    /// @notice Lock period multipliers (lock period => multiplier in basis points)
    mapping(uint256 => uint256) public lockMultipliers;

    /// @notice Available lock periods
    uint256[] public lockPeriods;

    /// @notice Minimum stake amounts
    uint256 public constant MIN_VAULT_TOKEN_STAKE = 1000; // 0.00001 BTC in 8 decimals
    uint256 public constant MIN_SOVA_STAKE = 1e18; // 1 SOVA

    /// @notice Maximum lock period
    uint256 public constant MAX_LOCK_PERIOD = 365 days;

    /// @notice Emergency unstake penalty (basis points)
    uint256 public emergencyUnstakePenalty;

    /// @notice Redemption queue contract
    IRedemptionQueue public redemptionQueue;

    /// @notice Whether queue redemptions are enabled for rewards
    bool public queueRedemptionsEnabled;

    // Events
    event VaultTokenStaked(address indexed user, uint256 amount, uint256 lockPeriod);
    event SovaStaked(address indexed user, uint256 amount, uint256 lockPeriod);
    event VaultTokenUnstaked(address indexed user, uint256 amount);
    event SovaUnstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 sovaRewards, uint256 sovaBTCRewards);
    event RewardRatesUpdated(uint256 vaultTokenToSovaRate, uint256 sovaToSovaBTCRate, uint256 dualStakeMultiplier);
    event EmergencyWithdraw(address indexed user, uint256 vaultTokenAmount, uint256 sovaAmount);
    event QueueRedemptionRequested(bytes32 indexed requestId, address indexed user, uint256 amount);
    event RedemptionQueueUpdated(address indexed newQueue);
    event QueueRedemptionsToggled(bool enabled);

    // Errors
    error ZeroAmount();
    error ZeroAddress();
    error InsufficientBalance();
    error StillLocked();
    error NoRewards();
    error InvalidLockPeriod();
    error InvalidRewardRate();
    error RequireVaultTokenStake();
    error RedemptionQueueNotSet();
    error QueueRedemptionsDisabled();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        address _vaultToken,
        address _sovaToken,
        address _rewardToken,
        bool _isSovaNetwork
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        if (_vaultToken == address(0) || _sovaToken == address(0) || _rewardToken == address(0)) {
            revert ZeroAddress();
        }

        vaultToken = IERC20(_vaultToken);
        sovaToken = IERC20(_sovaToken);
        rewardToken = IERC20(_rewardToken);
        isSovaNetwork = _isSovaNetwork;

        // Default reward rates (can be updated by owner)
        rewardRates = RewardRate({
            vaultTokenToSovaRate: 100, // Base rate for SOVA rewards
            sovaToSovaBTCRate: 50, // Base rate for sovaBTC rewards
            dualStakeMultiplier: 5000 // 50% bonus for dual staking
        });

        // Default lock periods and multipliers
        lockPeriods = [0, 30 days, 90 days, 180 days, 365 days];
        lockMultipliers[0] = 10000; // 1x (no lock)
        lockMultipliers[30 days] = 11000; // 1.1x
        lockMultipliers[90 days] = 12500; // 1.25x
        lockMultipliers[180 days] = 15000; // 1.5x
        lockMultipliers[365 days] = 20000; // 2x

        emergencyUnstakePenalty = 2500; // 25% penalty
    }

    /**
     * @notice Stake vault tokens to earn SOVA rewards
     * @param amount Amount of vault tokens to stake
     * @param lockPeriod Lock period in seconds
     */
    function stakeVaultTokens(uint256 amount, uint256 lockPeriod) external nonReentrant whenNotPaused {
        if (amount < MIN_VAULT_TOKEN_STAKE) revert ZeroAmount();
        if (lockMultipliers[lockPeriod] == 0) revert InvalidLockPeriod();

        _updateRewards(msg.sender);

        UserStake storage stake = userStakes[msg.sender];

        // Transfer tokens
        vaultToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update stake info
        stake.vaultTokenAmount += amount;
        totalVaultTokensStaked += amount;

        // Set lock end time (extend if longer than current)
        uint256 newLockEnd = block.timestamp + lockPeriod;
        if (newLockEnd > stake.lockEndTime) {
            stake.lockEndTime = newLockEnd;
        }

        emit VaultTokenStaked(msg.sender, amount, lockPeriod);
    }

    /**
     * @notice Stake SOVA tokens to earn sovaBTC rewards (requires vault token stake)
     * @param amount Amount of SOVA to stake
     * @param lockPeriod Lock period in seconds
     */
    function stakeSova(uint256 amount, uint256 lockPeriod) external nonReentrant whenNotPaused {
        if (amount < MIN_SOVA_STAKE) revert ZeroAmount();
        if (lockMultipliers[lockPeriod] == 0) revert InvalidLockPeriod();

        UserStake storage stake = userStakes[msg.sender];
        if (stake.vaultTokenAmount == 0) revert RequireVaultTokenStake();

        _updateRewards(msg.sender);

        // Transfer tokens
        sovaToken.safeTransferFrom(msg.sender, address(this), amount);

        // Update stake info
        stake.sovaAmount += amount;
        totalSovaStaked += amount;

        // Set lock end time (extend if longer than current)
        uint256 newLockEnd = block.timestamp + lockPeriod;
        if (newLockEnd > stake.lockEndTime) {
            stake.lockEndTime = newLockEnd;
        }

        emit SovaStaked(msg.sender, amount, lockPeriod);
    }

    /**
     * @notice Unstake vault tokens
     * @param amount Amount to unstake
     */
    function unstakeVaultTokens(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserStake storage stake = userStakes[msg.sender];
        if (stake.vaultTokenAmount < amount) revert InsufficientBalance();
        if (block.timestamp < stake.lockEndTime) revert StillLocked();

        _updateRewards(msg.sender);

        stake.vaultTokenAmount -= amount;
        totalVaultTokensStaked -= amount;

        vaultToken.safeTransfer(msg.sender, amount);

        emit VaultTokenUnstaked(msg.sender, amount);
    }

    /**
     * @notice Unstake SOVA tokens
     * @param amount Amount to unstake
     */
    function unstakeSova(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        UserStake storage stake = userStakes[msg.sender];
        if (stake.sovaAmount < amount) revert InsufficientBalance();
        if (block.timestamp < stake.lockEndTime) revert StillLocked();

        _updateRewards(msg.sender);

        stake.sovaAmount -= amount;
        totalSovaStaked -= amount;

        sovaToken.safeTransfer(msg.sender, amount);

        emit SovaUnstaked(msg.sender, amount);
    }

    /**
     * @notice Claim accumulated rewards
     */
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        UserStake storage stake = userStakes[msg.sender];

        if (stake.sovaRewards == 0 && stake.sovaBTCRewards == 0) {
            revert NoRewards();
        }

        uint256 sovaRewards = stake.sovaRewards;
        uint256 sovaBTCRewards = stake.sovaBTCRewards;

        stake.sovaRewards = 0;
        stake.sovaBTCRewards = 0;

        if (sovaRewards > 0) {
            sovaToken.safeTransfer(msg.sender, sovaRewards);
        }
        if (sovaBTCRewards > 0) {
            rewardToken.safeTransfer(msg.sender, sovaBTCRewards);
        }

        emit RewardsClaimed(msg.sender, sovaRewards, sovaBTCRewards);
    }

    /**
     * @notice Compound SOVA rewards back into SOVA stake
     */
    function compoundSovaRewards() external nonReentrant whenNotPaused {
        _updateRewards(msg.sender);

        UserStake storage stake = userStakes[msg.sender];

        if (stake.sovaRewards == 0) revert NoRewards();
        if (stake.vaultTokenAmount == 0) revert RequireVaultTokenStake();

        uint256 sovaRewards = stake.sovaRewards;
        stake.sovaRewards = 0;
        stake.sovaAmount += sovaRewards;
        totalSovaStaked += sovaRewards;
    }

    /**
     * @notice Request queued redemption of staking rewards
     * @param rewardAmount Amount of sovaBTC rewards to redeem
     * @param receiver Address to receive rewards
     * @return requestId Unique request identifier
     */
    function requestQueuedRewardRedemption(
        uint256 rewardAmount,
        address receiver
    ) external whenNotPaused nonReentrant returns (bytes32 requestId) {
        if (rewardAmount == 0) revert ZeroAmount();
        if (receiver == address(0)) revert ZeroAddress();
        if (address(redemptionQueue) == address(0)) revert RedemptionQueueNotSet();
        if (!queueRedemptionsEnabled) revert QueueRedemptionsDisabled();

        _updateRewards(msg.sender);
        UserStake storage stake = userStakes[msg.sender];

        if (stake.sovaBTCRewards < rewardAmount) revert InsufficientBalance();

        // Lock rewards (deduct from user's pending rewards)
        stake.sovaBTCRewards -= rewardAmount;

        // Request redemption through queue
        requestId = redemptionQueue.requestRedemption(
            receiver,
            IRedemptionQueue.RedemptionType.STAKING_REWARDS,
            rewardAmount,
            address(rewardToken),
            rewardAmount
        );

        emit QueueRedemptionRequested(requestId, receiver, rewardAmount);
        return requestId;
    }

    /**
     * @notice Fulfill a queued reward redemption (called by redemption queue)
     * @param requestId Request identifier
     * @param user User to receive rewards
     * @param amount Amount of rewards to send
     * @return actualAmount Actual amount sent
     */
    function fulfillQueuedRewardRedemption(
        bytes32 requestId,
        address user,
        uint256 amount
    ) external nonReentrant returns (uint256 actualAmount) {
        require(msg.sender == address(redemptionQueue), "Only redemption queue");
        
        // Check if we have enough reward tokens
        uint256 available = rewardToken.balanceOf(address(this));
        actualAmount = amount > available ? available : amount;
        
        // Transfer rewards to user
        if (actualAmount > 0) {
            rewardToken.safeTransfer(user, actualAmount);
        }
        
        // Notify queue of fulfillment
        redemptionQueue.fulfillRedemption(requestId, actualAmount);
        
        return actualAmount;
    }

    /**
     * @notice Cancel a queued reward redemption and restore rewards to user
     * @param requestId Request identifier
     * @param user User to restore rewards to
     * @param amount Amount of rewards to restore
     */
    function cancelQueuedRewardRedemption(
        bytes32 requestId,
        address user,
        uint256 amount
    ) external {
        require(msg.sender == address(redemptionQueue), "Only redemption queue");
        
        // Restore rewards to user
        UserStake storage stake = userStakes[user];
        stake.sovaBTCRewards += amount;
    }

    /**
     * @notice Emergency unstake with penalty
     */
    function emergencyUnstake() external nonReentrant {
        UserStake storage stake = userStakes[msg.sender];

        if (stake.vaultTokenAmount == 0 && stake.sovaAmount == 0) {
            revert ZeroAmount();
        }

        _updateRewards(msg.sender);

        uint256 vaultTokenAmount = stake.vaultTokenAmount;
        uint256 sovaAmount = stake.sovaAmount;

        // Apply penalty
        uint256 vaultTokenPenalty = (vaultTokenAmount * emergencyUnstakePenalty) / 10000;
        uint256 sovaPenalty = (sovaAmount * emergencyUnstakePenalty) / 10000;

        uint256 vaultTokenToReturn = vaultTokenAmount - vaultTokenPenalty;
        uint256 sovaToReturn = sovaAmount - sovaPenalty;

        // Reset stakes
        stake.vaultTokenAmount = 0;
        stake.sovaAmount = 0;
        stake.lockEndTime = 0;
        totalVaultTokensStaked -= vaultTokenAmount;
        totalSovaStaked -= sovaAmount;

        // Transfer tokens (minus penalty)
        if (vaultTokenToReturn > 0) {
            vaultToken.safeTransfer(msg.sender, vaultTokenToReturn);
        }
        if (sovaToReturn > 0) {
            sovaToken.safeTransfer(msg.sender, sovaToReturn);
        }

        emit EmergencyWithdraw(msg.sender, vaultTokenAmount, sovaAmount);
    }

    /**
     * @notice Set reward rates (owner only)
     */
    function setRewardRates(uint256 vaultTokenToSovaRate, uint256 sovaToSovaBTCRate, uint256 dualStakeMultiplier)
        external
        onlyOwner
    {
        if (dualStakeMultiplier > 50000) revert InvalidRewardRate(); // Max 500% bonus

        rewardRates.vaultTokenToSovaRate = vaultTokenToSovaRate;
        rewardRates.sovaToSovaBTCRate = sovaToSovaBTCRate;
        rewardRates.dualStakeMultiplier = dualStakeMultiplier;

        emit RewardRatesUpdated(vaultTokenToSovaRate, sovaToSovaBTCRate, dualStakeMultiplier);
    }

    /**
     * @notice Add rewards to the contract (owner only)
     */
    function addRewards(uint256 sovaAmount, uint256 sovaBTCAmount) external onlyOwner {
        if (sovaAmount > 0) {
            sovaToken.safeTransferFrom(msg.sender, address(this), sovaAmount);
        }
        if (sovaBTCAmount > 0) {
            rewardToken.safeTransferFrom(msg.sender, address(this), sovaBTCAmount);
        }
    }

    /**
     * @notice Get pending rewards for a user
     */
    function getPendingRewards(address user) external view returns (uint256 sovaRewards, uint256 sovaBTCRewards) {
        UserStake memory stake = userStakes[user];

        if (stake.lastUpdateTime == 0) {
            return (0, 0);
        }

        uint256 timeElapsed = block.timestamp - stake.lastUpdateTime;

        // Calculate base rewards
        uint256 pendingSovaRewards = stake.sovaRewards;
        uint256 pendingSovaBTCRewards = stake.sovaBTCRewards;

        if (stake.vaultTokenAmount > 0) {
            // Vault tokens staked earn SOVA
            pendingSovaRewards += (stake.vaultTokenAmount * rewardRates.vaultTokenToSovaRate * timeElapsed) / (365 days);
        }

        if (stake.sovaAmount > 0 && stake.vaultTokenAmount > 0) {
            // SOVA staked earns sovaBTC (only if also staking vault tokens)
            pendingSovaBTCRewards += (stake.sovaAmount * rewardRates.sovaToSovaBTCRate * timeElapsed) / (365 days);
        }

        // Apply dual stake bonus
        if (stake.vaultTokenAmount > 0 && stake.sovaAmount > 0) {
            pendingSovaRewards = (pendingSovaRewards * (10000 + rewardRates.dualStakeMultiplier)) / 10000;
            pendingSovaBTCRewards = (pendingSovaBTCRewards * (10000 + rewardRates.dualStakeMultiplier)) / 10000;
        }

        return (pendingSovaRewards, pendingSovaBTCRewards);
    }

    /**
     * @notice Get user stake info
     */
    function getUserStake(address user) external view returns (UserStake memory) {
        return userStakes[user];
    }

    /**
     * @notice Update rewards for a user
     */
    function _updateRewards(address user) internal {
        UserStake storage stake = userStakes[user];

        if (stake.lastUpdateTime == 0) {
            stake.lastUpdateTime = block.timestamp;
            return;
        }

        (uint256 sovaRewards, uint256 sovaBTCRewards) = this.getPendingRewards(user);
        stake.sovaRewards = sovaRewards;
        stake.sovaBTCRewards = sovaBTCRewards;
        stake.lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Set redemption queue contract
     * @param _redemptionQueue Address of redemption queue contract
     */
    function setRedemptionQueue(address _redemptionQueue) external onlyOwner {
        redemptionQueue = IRedemptionQueue(_redemptionQueue);
        emit RedemptionQueueUpdated(_redemptionQueue);
    }

    /**
     * @notice Toggle queue redemptions for rewards
     * @param enabled Whether to enable queue redemptions
     */
    function setQueueRedemptionsEnabled(bool enabled) external onlyOwner {
        queueRedemptionsEnabled = enabled;
        emit QueueRedemptionsToggled(enabled);
    }

    /**
     * @notice Get user's active reward redemption requests
     * @param user User address
     * @return Active request IDs
     */
    function getUserActiveRewardRedemptions(address user) external view returns (bytes32[] memory) {
        if (address(redemptionQueue) == address(0)) {
            return new bytes32[](0);
        }
        return redemptionQueue.getUserActiveRequests(user);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
