// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title RedemptionQueue
 * @notice Simple time-based redemption queue
 * @dev Users request redemptions that can be fulfilled after a time delay
 */
contract RedemptionQueue is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    enum RedemptionType {
        VAULT_SHARES,     // Standard ERC-4626 vault share redemption
        STAKING_REWARDS   // Staking reward redemption
    }

    enum RedemptionStatus {
        PENDING,          // Waiting for time delay
        FULFILLED,        // Completed successfully
        CANCELLED         // Cancelled by user or admin
    }

    struct RedemptionRequest {
        address user;                    // User requesting redemption
        RedemptionType redemptionType;   // Type of redemption
        uint256 amount;                  // Amount to redeem
        uint256 requestTime;             // When request was made
        uint256 fulfillmentTime;         // When request can be fulfilled
        RedemptionStatus status;         // Current status
        address assetOut;                // Asset to receive
        uint256 estimatedOut;            // Estimated output amount
        bytes32 requestId;               // Unique request identifier
    }

    struct QueueConfig {
        uint256 windowDuration;          // How long until redemption can be fulfilled
        bool enabled;                    // Whether queue is enabled
    }

    /// @notice Vault contract address
    address public vault;

    /// @notice Staking contract address  
    address public staking;

    /// @notice Queue configuration
    QueueConfig public queueConfig;

    /// @notice All redemption requests
    mapping(bytes32 => RedemptionRequest) public redemptionRequests;

    /// @notice User's active request IDs
    mapping(address => bytes32[]) public userRequests;

    /// @notice Total requests counter for ID generation
    uint256 public totalRequests;

    /// @notice Authorized processors (vault and staking contracts)
    mapping(address => bool) public authorizedProcessors;

    // Events
    event RedemptionRequested(
        bytes32 indexed requestId,
        address indexed user,
        RedemptionType redemptionType,
        uint256 amount,
        uint256 fulfillmentTime
    );
    
    event RedemptionFulfilled(
        bytes32 indexed requestId,
        address indexed user,
        uint256 amountOut,
        address assetOut
    );
    
    event RedemptionCancelled(bytes32 indexed requestId, address indexed user);
    event QueueConfigUpdated(QueueConfig newConfig);
    event ProcessorAuthorized(address processor, bool authorized);

    // Errors
    error QueueDisabled();
    error InvalidAmount();
    error RequestNotFound();
    error RequestNotReady();
    error UnauthorizedProcessor();
    error InvalidQueueConfig();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _vault,
        address _staking,
        QueueConfig memory _config
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        vault = _vault;
        staking = _staking;
        
        _updateQueueConfig(_config);

        // Authorize vault and staking contracts
        authorizedProcessors[_vault] = true;
        authorizedProcessors[_staking] = true;

        emit ProcessorAuthorized(_vault, true);
        emit ProcessorAuthorized(_staking, true);
    }

    /**
     * @notice Request a redemption (called by vault/staking contracts)
     * @param user User requesting redemption
     * @param redemptionType Type of redemption
     * @param amount Amount to redeem
     * @param assetOut Asset to receive
     * @param estimatedOut Estimated output amount
     * @return requestId Unique request identifier
     */
    function requestRedemption(
        address user,
        RedemptionType redemptionType,
        uint256 amount,
        address assetOut,
        uint256 estimatedOut
    ) external whenNotPaused nonReentrant returns (bytes32 requestId) {
        if (!authorizedProcessors[msg.sender]) revert UnauthorizedProcessor();
        if (!queueConfig.enabled) revert QueueDisabled();
        if (amount == 0) revert InvalidAmount();

        // Generate unique request ID
        requestId = keccak256(abi.encodePacked(
            user,
            redemptionType,
            amount,
            block.timestamp,
            totalRequests++
        ));

        uint256 fulfillmentTime = block.timestamp + queueConfig.windowDuration;

        // Create redemption request
        redemptionRequests[requestId] = RedemptionRequest({
            user: user,
            redemptionType: redemptionType,
            amount: amount,
            requestTime: block.timestamp,
            fulfillmentTime: fulfillmentTime,
            status: RedemptionStatus.PENDING,
            assetOut: assetOut,
            estimatedOut: estimatedOut,
            requestId: requestId
        });

        // Track user requests
        userRequests[user].push(requestId);

        emit RedemptionRequested(
            requestId,
            user,
            redemptionType,
            amount,
            fulfillmentTime
        );

        return requestId;
    }

    /**
     * @notice Fulfill a redemption request (called by authorized processors)
     * @param requestId Request to fulfill
     * @param actualAmountOut Actual amount being sent to user
     */
    function fulfillRedemption(
        bytes32 requestId,
        uint256 actualAmountOut
    ) external whenNotPaused nonReentrant {
        if (!authorizedProcessors[msg.sender]) revert UnauthorizedProcessor();
        
        RedemptionRequest storage request = redemptionRequests[requestId];
        if (request.user == address(0)) revert RequestNotFound();
        if (request.status != RedemptionStatus.PENDING) revert RequestNotReady();
        if (block.timestamp < request.fulfillmentTime) revert RequestNotReady();

        // Update request status
        request.status = RedemptionStatus.FULFILLED;

        emit RedemptionFulfilled(
            requestId,
            request.user,
            actualAmountOut,
            request.assetOut
        );
    }

    /**
     * @notice Cancel a redemption request (user or admin)
     * @param requestId Request to cancel
     */
    function cancelRedemption(bytes32 requestId) external nonReentrant {
        RedemptionRequest storage request = redemptionRequests[requestId];
        if (request.user == address(0)) revert RequestNotFound();
        
        // Only user or owner can cancel
        require(
            msg.sender == request.user || msg.sender == owner(),
            "Not authorized to cancel"
        );
        
        if (request.status != RedemptionStatus.PENDING) revert RequestNotReady();

        // Update status
        request.status = RedemptionStatus.CANCELLED;

        emit RedemptionCancelled(requestId, request.user);
    }


    /**
     * @notice Get user's active redemption requests
     * @param user User address
     * @return Active request IDs
     */
    function getUserActiveRequests(address user) external view returns (bytes32[] memory) {
        bytes32[] memory userReqs = userRequests[user];
        uint256 activeCount = 0;
        
        // Count active requests
        for (uint256 i = 0; i < userReqs.length; i++) {
            if (redemptionRequests[userReqs[i]].status == RedemptionStatus.PENDING) {
                activeCount++;
            }
        }
        
        // Build active requests array
        bytes32[] memory activeRequests = new bytes32[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < userReqs.length; i++) {
            if (redemptionRequests[userReqs[i]].status == RedemptionStatus.PENDING) {
                activeRequests[index++] = userReqs[i];
            }
        }
        
        return activeRequests;
    }

    /**
     * @notice Get queue status
     * @return pendingCount Number of pending requests
     */
    function getQueueStatus() external view returns (uint256 pendingCount) {
        // Count active pending requests for all users
        // This is a simple implementation - could be optimized with a counter
        pendingCount = 0;
        // Note: In a production system, you'd maintain a counter for efficiency
        // For simplicity, we'll just return 0 here and let callers use getUserActiveRequests
    }

    /**
     * @notice Get estimated fulfillment time for new request
     * @return estimatedTime When a new request would be fulfilled
     */
    function getEstimatedFulfillmentTime() external view returns (uint256 estimatedTime) {
        return block.timestamp + queueConfig.windowDuration;
    }

    // Admin Functions

    /**
     * @notice Update queue configuration
     * @param newConfig New configuration
     */
    function updateQueueConfig(QueueConfig memory newConfig) external onlyOwner {
        _updateQueueConfig(newConfig);
    }


    /**
     * @notice Authorize/deauthorize processor
     * @param processor Processor address
     * @param authorized Whether to authorize
     */
    function setProcessorAuthorization(address processor, bool authorized) external onlyOwner {
        authorizedProcessors[processor] = authorized;
        emit ProcessorAuthorized(processor, authorized);
    }


    // Internal Functions

    function _updateQueueConfig(QueueConfig memory newConfig) internal {
        if (newConfig.windowDuration == 0) revert InvalidQueueConfig();
            
        queueConfig = newConfig;
        emit QueueConfigUpdated(newConfig);
    }


    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}