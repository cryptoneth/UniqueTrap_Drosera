// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title AIConsensusConfig
/// @notice Holds the configuration required for the AIConsensusTrap to compare two model predictions.
contract AIConsensusConfig {
    address public immutable primaryModel;
    address public immutable sentinelModel;
    uint256 public immutable maxDivergence;

    constructor(address _primaryModel, address _sentinelModel, uint256 _maxDivergence) {
        require(_primaryModel != address(0), "primary model is zero");
        require(_sentinelModel != address(0), "sentinel model is zero");

        primaryModel = _primaryModel;
        sentinelModel = _sentinelModel;
        maxDivergence = _maxDivergence;
    }
}
