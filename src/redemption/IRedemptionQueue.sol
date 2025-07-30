// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IRedemptionQueue {
    enum RedemptionType {
        VAULT_SHARES,
        STAKING_REWARDS
    }

    function requestRedemption(
        address user,
        RedemptionType redemptionType,
        uint256 amount,
        address assetOut,
        uint256 estimatedOut
    ) external returns (bytes32 requestId);

    function fulfillRedemption(
        bytes32 requestId,
        uint256 actualAmountOut
    ) external;

    function cancelRedemption(bytes32 requestId) external;

    function getUserActiveRequests(address user) external view returns (bytes32[] memory);

    function getQueueStatus() external view returns (uint256 pendingCount);

    function getEstimatedFulfillmentTime() external view returns (uint256);
}