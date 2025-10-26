// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract AIMockLow {
    function getPrediction() public pure returns (uint256) {
        return 50; // Low prediction
    }

    function getModelParameters() public pure returns (uint256[] memory) {
        return new uint256[](3); // Dummy parameters
    }

    function getInputData() public pure returns (string memory) {
        return "dummy_input_data"; // Dummy input data
    }
}
