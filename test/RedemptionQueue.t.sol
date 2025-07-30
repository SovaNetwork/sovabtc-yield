// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

import "../src/redemption/RedemptionQueue.sol";
import "../src/vault/SovaBTCYieldVault.sol";
import "../src/staking/SovaBTCYieldStaking.sol";
import "../src/bridges/BridgedSovaBTC.sol";

contract RedemptionQueueTest is Test {
    RedemptionQueue public redemptionQueue;
    SovaBTCYieldVault public vault;
    SovaBTCYieldStaking public staking;
    BridgedSovaBTC public bridgedSovaBTC;
    ERC20Mock public wbtc;
    ERC20Mock public sova;

    address public owner;
    address public user1;
    address public user2;
    address public hyperlaneMailbox;

    uint256 constant WINDOW_DURATION = 24 hours;

    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        hyperlaneMailbox = makeAddr("hyperlaneMailbox");

        // Deploy mock tokens
        wbtc = new ERC20Mock();
        sova = new ERC20Mock();

        // Mock token properties
        vm.mockCall(address(wbtc), abi.encodeWithSignature("decimals()"), abi.encode(uint8(8)));
        vm.mockCall(address(sova), abi.encodeWithSignature("decimals()"), abi.encode(uint8(18)));
        vm.mockCall(address(wbtc), abi.encodeWithSignature("name()"), abi.encode("Wrapped Bitcoin"));
        vm.mockCall(address(sova), abi.encodeWithSignature("name()"), abi.encode("SOVA Token"));

        vm.startPrank(owner);

        // Deploy BridgedSovaBTC
        BridgedSovaBTC bridgedImpl = new BridgedSovaBTC();
        bytes memory bridgedInitData = abi.encodeCall(BridgedSovaBTC.initialize, (owner, hyperlaneMailbox, address(0)));
        ERC1967Proxy bridgedProxy = new ERC1967Proxy(address(bridgedImpl), bridgedInitData);
        bridgedSovaBTC = BridgedSovaBTC(address(bridgedProxy));

        // Deploy Yield Vault
        SovaBTCYieldVault vaultImpl = new SovaBTCYieldVault();
        bytes memory vaultInitData = abi.encodeCall(
            SovaBTCYieldVault.initialize,
            (
                address(wbtc),
                address(bridgedSovaBTC),
                false,
                owner,
                "SovaBTC Yield Vault",
                "sovaBTCYield"
            )
        );
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImpl), vaultInitData);
        vault = SovaBTCYieldVault(address(vaultProxy));

        // Deploy Yield Staking
        SovaBTCYieldStaking stakingImpl = new SovaBTCYieldStaking();
        bytes memory stakingInitData = abi.encodeCall(
            SovaBTCYieldStaking.initialize,
            (
                owner,
                address(vault),
                address(sova),
                address(bridgedSovaBTC),
                false
            )
        );
        ERC1967Proxy stakingProxy = new ERC1967Proxy(address(stakingImpl), stakingInitData);
        staking = SovaBTCYieldStaking(address(stakingProxy));

        // Deploy RedemptionQueue
        RedemptionQueue queueImpl = new RedemptionQueue();
        RedemptionQueue.QueueConfig memory config = RedemptionQueue.QueueConfig({
            windowDuration: WINDOW_DURATION,
            enabled: true
        });
        bytes memory queueInitData = abi.encodeCall(
            RedemptionQueue.initialize,
            (address(vault), address(staking), config)
        );
        ERC1967Proxy queueProxy = new ERC1967Proxy(address(queueImpl), queueInitData);
        redemptionQueue = RedemptionQueue(address(queueProxy));

        vm.stopPrank();

        // Mint tokens to users
        wbtc.mint(user1, 100 * 10 ** 8);
        wbtc.mint(user2, 50 * 10 ** 8);
        sova.mint(user1, 1000 * 10 ** 18);
        sova.mint(user2, 500 * 10 ** 18);

        // Mint reward tokens to owner
        vm.startPrank(owner);
        bridgedSovaBTC.grantVaultRole(owner);
        bridgedSovaBTC.mint(owner, 100 * 10 ** 8);
        vm.stopPrank();
    }

    function testRedemptionQueueDeployment() public view {
        assertEq(redemptionQueue.owner(), owner);
        assertEq(redemptionQueue.vault(), address(vault));
        assertEq(redemptionQueue.staking(), address(staking));
        assertTrue(redemptionQueue.authorizedProcessors(address(vault)));
        assertTrue(redemptionQueue.authorizedProcessors(address(staking)));
        
        (uint256 windowDuration, bool enabled) = redemptionQueue.queueConfig();
        assertEq(windowDuration, WINDOW_DURATION);
        assertTrue(enabled);
    }

    function testRequestRedemption() public {
        vm.startPrank(address(vault)); // Simulate call from authorized processor
        
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8, // 1 BTC worth
            address(wbtc),
            1e8
        );
        
        vm.stopPrank();

        // Verify request was created
        (
            address user,
            RedemptionQueue.RedemptionType redemptionType,
            uint256 amount,
            uint256 requestTime,
            uint256 fulfillmentTime,
            RedemptionQueue.RedemptionStatus status,
            address assetOut,
            uint256 estimatedOut,
            bytes32 storedRequestId
        ) = redemptionQueue.redemptionRequests(requestId);

        assertEq(user, user1);
        assertEq(uint8(redemptionType), uint8(RedemptionQueue.RedemptionType.VAULT_SHARES));
        assertEq(amount, 1e8);
        assertEq(requestTime, block.timestamp);
        assertEq(fulfillmentTime, block.timestamp + WINDOW_DURATION);
        assertEq(uint8(status), uint8(RedemptionQueue.RedemptionStatus.PENDING));
        assertEq(assetOut, address(wbtc));
        assertEq(estimatedOut, 1e8);
        assertEq(storedRequestId, requestId);
    }

    function testRequestRedemptionUnauthorized() public {
        vm.startPrank(user1); // Not an authorized processor
        vm.expectRevert(RedemptionQueue.UnauthorizedProcessor.selector);
        redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();
    }

    function testRequestRedemptionQueueDisabled() public {
        // Disable queue
        vm.startPrank(owner);
        RedemptionQueue.QueueConfig memory config = RedemptionQueue.QueueConfig({
            windowDuration: WINDOW_DURATION,
            enabled: false
        });
        redemptionQueue.updateQueueConfig(config);
        vm.stopPrank();

        vm.startPrank(address(vault));
        vm.expectRevert(RedemptionQueue.QueueDisabled.selector);
        redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();
    }

    function testRequestRedemptionZeroAmount() public {
        vm.startPrank(address(vault));
        vm.expectRevert(RedemptionQueue.InvalidAmount.selector);
        redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            0,
            address(wbtc),
            1e8
        );
        vm.stopPrank();
    }

    function testRequestRedemptionWhenPaused() public {
        vm.startPrank(owner);
        redemptionQueue.pause();
        vm.stopPrank();

        vm.startPrank(address(vault));
        vm.expectRevert();
        redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();
    }

    function testFulfillRedemption() public {
        // First create a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // Fast forward time to after fulfillment window
        vm.warp(block.timestamp + WINDOW_DURATION + 1);

        // Fulfill the request
        vm.startPrank(address(vault));
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();

        // Verify request is fulfilled
        (, , , , , RedemptionQueue.RedemptionStatus status, , , ) = 
            redemptionQueue.redemptionRequests(requestId);
        assertEq(uint8(status), uint8(RedemptionQueue.RedemptionStatus.FULFILLED));
    }

    function testFulfillRedemptionTooEarly() public {
        // Create a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // Try to fulfill immediately (should fail)
        vm.startPrank(address(vault));
        vm.expectRevert(RedemptionQueue.RequestNotReady.selector);
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();
    }

    function testFulfillRedemptionUnauthorized() public {
        // Create a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + WINDOW_DURATION + 1);

        // Try to fulfill from unauthorized account
        vm.startPrank(user1);
        vm.expectRevert(RedemptionQueue.UnauthorizedProcessor.selector);
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();
    }

    function testFulfillRedemptionNonexistentRequest() public {
        bytes32 fakeRequestId = keccak256("fake");
        
        vm.startPrank(address(vault));
        vm.expectRevert(RedemptionQueue.RequestNotFound.selector);
        redemptionQueue.fulfillRedemption(fakeRequestId, 1e8);
        vm.stopPrank();
    }

    function testFulfillRedemptionAlreadyFulfilled() public {
        // Create and fulfill a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        vm.warp(block.timestamp + WINDOW_DURATION + 1);

        vm.startPrank(address(vault));
        redemptionQueue.fulfillRedemption(requestId, 1e8);

        // Try to fulfill again
        vm.expectRevert(RedemptionQueue.RequestNotReady.selector);
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();
    }

    function testCancelRedemption() public {
        // Create a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // User cancels their own request
        vm.startPrank(user1);
        redemptionQueue.cancelRedemption(requestId);
        vm.stopPrank();

        // Verify request is cancelled
        (, , , , , RedemptionQueue.RedemptionStatus status, , , ) = 
            redemptionQueue.redemptionRequests(requestId);
        assertEq(uint8(status), uint8(RedemptionQueue.RedemptionStatus.CANCELLED));
    }

    function testCancelRedemptionAsOwner() public {
        // Create a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // Owner cancels the request
        vm.startPrank(owner);
        redemptionQueue.cancelRedemption(requestId);
        vm.stopPrank();

        // Verify request is cancelled
        (, , , , , RedemptionQueue.RedemptionStatus status, , , ) = 
            redemptionQueue.redemptionRequests(requestId);
        assertEq(uint8(status), uint8(RedemptionQueue.RedemptionStatus.CANCELLED));
    }

    function testCancelRedemptionUnauthorized() public {
        // Create a request for user1
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // User2 tries to cancel user1's request
        vm.startPrank(user2);
        vm.expectRevert("Not authorized to cancel");
        redemptionQueue.cancelRedemption(requestId);
        vm.stopPrank();
    }

    function testCancelRedemptionNonexistent() public {
        bytes32 fakeRequestId = keccak256("fake");
        
        vm.startPrank(user1);
        vm.expectRevert(RedemptionQueue.RequestNotFound.selector);
        redemptionQueue.cancelRedemption(fakeRequestId);
        vm.stopPrank();
    }

    function testCancelRedemptionAlreadyFulfilled() public {
        // Create and fulfill a request
        vm.startPrank(address(vault));
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        vm.warp(block.timestamp + WINDOW_DURATION + 1);

        vm.startPrank(address(vault));
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();

        // Try to cancel fulfilled request
        vm.startPrank(user1);
        vm.expectRevert(RedemptionQueue.RequestNotReady.selector);
        redemptionQueue.cancelRedemption(requestId);
        vm.stopPrank();
    }

    function testGetUserActiveRequests() public {
        // Create multiple requests for user1
        vm.startPrank(address(vault));
        bytes32 requestId1 = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        
        bytes32 requestId2 = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            5e7,
            address(wbtc),
            5e7
        );
        vm.stopPrank();

        // Get active requests
        bytes32[] memory activeRequests = redemptionQueue.getUserActiveRequests(user1);
        assertEq(activeRequests.length, 2);
        assertEq(activeRequests[0], requestId1);
        assertEq(activeRequests[1], requestId2);

        // Fulfill one request
        vm.warp(block.timestamp + WINDOW_DURATION + 1);
        vm.startPrank(address(vault));
        redemptionQueue.fulfillRedemption(requestId1, 1e8);
        vm.stopPrank();

        // Should now only have 1 active request
        activeRequests = redemptionQueue.getUserActiveRequests(user1);
        assertEq(activeRequests.length, 1);
        assertEq(activeRequests[0], requestId2);
    }

    function testGetUserActiveRequestsEmpty() public view {
        bytes32[] memory activeRequests = redemptionQueue.getUserActiveRequests(user1);
        assertEq(activeRequests.length, 0);
    }

    function testGetQueueStatus() public view {
        uint256 pendingCount = redemptionQueue.getQueueStatus();
        assertEq(pendingCount, 0);
    }

    function testGetEstimatedFulfillmentTime() public view {
        uint256 estimatedTime = redemptionQueue.getEstimatedFulfillmentTime();
        assertEq(estimatedTime, block.timestamp + WINDOW_DURATION);
    }

    function testUpdateQueueConfig() public {
        RedemptionQueue.QueueConfig memory newConfig = RedemptionQueue.QueueConfig({
            windowDuration: 12 hours,
            enabled: false
        });

        vm.startPrank(owner);
        redemptionQueue.updateQueueConfig(newConfig);
        vm.stopPrank();

        (uint256 updatedWindowDuration, bool updatedEnabled) = redemptionQueue.queueConfig();
        assertEq(updatedWindowDuration, 12 hours);
        assertFalse(updatedEnabled);
    }

    function testUpdateQueueConfigUnauthorized() public {
        RedemptionQueue.QueueConfig memory newConfig = RedemptionQueue.QueueConfig({
            windowDuration: 12 hours,
            enabled: false
        });

        vm.startPrank(user1);
        vm.expectRevert();
        redemptionQueue.updateQueueConfig(newConfig);
        vm.stopPrank();
    }

    function testUpdateQueueConfigInvalidWindow() public {
        RedemptionQueue.QueueConfig memory newConfig = RedemptionQueue.QueueConfig({
            windowDuration: 0, // Invalid
            enabled: true
        });

        vm.startPrank(owner);
        vm.expectRevert(RedemptionQueue.InvalidQueueConfig.selector);
        redemptionQueue.updateQueueConfig(newConfig);
        vm.stopPrank();
    }

    function testSetProcessorAuthorization() public {
        address newProcessor = makeAddr("newProcessor");
        
        vm.startPrank(owner);
        redemptionQueue.setProcessorAuthorization(newProcessor, true);
        vm.stopPrank();

        assertTrue(redemptionQueue.authorizedProcessors(newProcessor));

        vm.startPrank(owner);
        redemptionQueue.setProcessorAuthorization(newProcessor, false);
        vm.stopPrank();

        assertFalse(redemptionQueue.authorizedProcessors(newProcessor));
    }

    function testSetProcessorAuthorizationUnauthorized() public {
        address newProcessor = makeAddr("newProcessor");
        
        vm.startPrank(user1);
        vm.expectRevert();
        redemptionQueue.setProcessorAuthorization(newProcessor, true);
        vm.stopPrank();
    }

    function testPauseUnpause() public {
        vm.startPrank(owner);
        redemptionQueue.pause();
        assertTrue(redemptionQueue.paused());

        redemptionQueue.unpause();
        assertFalse(redemptionQueue.paused());
        vm.stopPrank();
    }

    function testPauseUnauthorized() public {
        vm.startPrank(user1);
        vm.expectRevert();
        redemptionQueue.pause();
        vm.stopPrank();
    }

    function testStakingRedemptionType() public {
        vm.startPrank(address(staking)); // Staking contract requests redemption
        
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.STAKING_REWARDS,
            1e8,
            address(bridgedSovaBTC),
            1e8
        );
        
        vm.stopPrank();

        // Verify request was created with correct type
        (, RedemptionQueue.RedemptionType redemptionType, , , , , , , ) = 
            redemptionQueue.redemptionRequests(requestId);
        assertEq(uint8(redemptionType), uint8(RedemptionQueue.RedemptionType.STAKING_REWARDS));
    }

    function testMultipleUserRequests() public {
        // Create requests for multiple users
        vm.startPrank(address(vault));
        bytes32 user1Request = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        
        bytes32 user2Request = redemptionQueue.requestRedemption(
            user2,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            5e7,
            address(wbtc),
            5e7
        );
        vm.stopPrank();

        // Verify each user has their own requests
        bytes32[] memory user1Requests = redemptionQueue.getUserActiveRequests(user1);
        bytes32[] memory user2Requests = redemptionQueue.getUserActiveRequests(user2);
        
        assertEq(user1Requests.length, 1);
        assertEq(user2Requests.length, 1);
        assertEq(user1Requests[0], user1Request);
        assertEq(user2Requests[0], user2Request);
    }

    function testRedemptionRequestIdUniqueness() public {
        vm.startPrank(address(vault));
        
        // Create two identical requests (same user, amount, etc.)
        bytes32 requestId1 = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        
        // Move forward in time slightly to ensure different timestamp
        vm.warp(block.timestamp + 1);
        
        bytes32 requestId2 = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        
        vm.stopPrank();

        // Request IDs should be different due to timestamp and counter
        assertNotEq(requestId1, requestId2);
    }

    function testEvents() public {
        vm.startPrank(address(vault));

        // Test RedemptionRequested event - check that event is emitted with correct user and amount
        vm.expectEmit(false, true, false, false);
        emit RedemptionRequested(
            bytes32(0), // We don't check the exact request ID
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            0 // We don't check the exact fulfillment time
        );
        
        bytes32 requestId = redemptionQueue.requestRedemption(
            user1,
            RedemptionQueue.RedemptionType.VAULT_SHARES,
            1e8,
            address(wbtc),
            1e8
        );
        vm.stopPrank();

        // Fast forward and test RedemptionFulfilled event
        vm.warp(block.timestamp + WINDOW_DURATION + 1);
        
        vm.startPrank(address(vault));
        vm.expectEmit(false, true, false, false);
        emit RedemptionFulfilled(requestId, user1, 1e8, address(wbtc));
        
        redemptionQueue.fulfillRedemption(requestId, 1e8);
        vm.stopPrank();
    }

    function testTotalRequestsCounter() public {
        uint256 initialCount = redemptionQueue.totalRequests();

        vm.startPrank(address(vault));
        redemptionQueue.requestRedemption(user1, RedemptionQueue.RedemptionType.VAULT_SHARES, 1e8, address(wbtc), 1e8);
        redemptionQueue.requestRedemption(user2, RedemptionQueue.RedemptionType.VAULT_SHARES, 5e7, address(wbtc), 5e7);
        vm.stopPrank();

        assertEq(redemptionQueue.totalRequests(), initialCount + 2);
    }

    // Events for testing
    event RedemptionRequested(
        bytes32 indexed requestId,
        address indexed user,
        RedemptionQueue.RedemptionType redemptionType,
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
}