// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract UpdatableAIMock {
    uint256 public currentPrediction;

    constructor(uint256 _initialPrediction) {
        currentPrediction = _initialPrediction;
    }

    function getPrediction() public view returns (uint256) {
        return currentPrediction;
    }

    function setPrediction(uint256 _newPrediction) public {
        currentPrediction = _newPrediction;
    }

    // Dummy functions to match the original interface
    function getModelParameters() public pure returns (uint256[] memory) {
        return new uint256[](3);
    }

    function getInputData() public pure returns (string memory) {
        return "dummy_input_data";
    }
}
