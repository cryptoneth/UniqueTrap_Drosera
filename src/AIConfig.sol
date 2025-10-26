// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract AIConfig {
    address public immutable aiModelAddress;
    uint256 public immutable driftThreshold;
    uint256 public immutable windowSize;

    constructor(address _aiModelAddress, uint256 _driftThreshold, uint256 _windowSize) {
        aiModelAddress = _aiModelAddress;
        driftThreshold = _driftThreshold;
        windowSize = _windowSize;
    }
}