// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AIDriftTrap.sol";
import "../src/AIConfig.sol"; // Import AIConfig for context
import "../src/AIMock.sol"; // Import AIMock for context

contract AIDriftTrapTest is Test {
    AIDriftTrap public aiDriftTrap;

    function setUp() public {
        // AIDriftTrap is stateless and reads config from AIConfig.
        // For testing shouldRespond, we will directly construct the _collectOutputs array.
        aiDriftTrap = new AIDriftTrap();
    }

    // Helper function to create a bytes array for a single prediction, driftThreshold, and windowSize
    function _encodeCollectOutput(uint256 prediction, uint256 driftThreshold) internal pure returns (bytes memory) {
        return abi.encode(prediction, driftThreshold);
    }

    // Helper function to create a _collectOutputs array for testing shouldRespond
    function _createCollectOutputs(uint256[] memory predictions, uint256 driftThreshold) internal pure returns (bytes[] memory) {
        bytes[] memory collectOutputs = new bytes[](predictions.length);
        for (uint256 i = 0; i < predictions.length; i++) {
            collectOutputs[i] = _encodeCollectOutput(predictions[i], driftThreshold);
        }
        return collectOutputs;
    }

    function testShouldRespond_NoDrift_BelowThreshold() public {
        uint256 driftThreshold = 100;
        uint256[] memory predictions = new uint256[](1);
        predictions[0] = 99; // Latest prediction is below threshold

        bytes[] memory collectOutputs = _createCollectOutputs(predictions, driftThreshold);

        (bool shouldRespond, bytes memory responseData) = aiDriftTrap.shouldRespond(collectOutputs);

        assertEq(shouldRespond, false, "Should not respond when latest prediction is below threshold");
        assertEq(responseData.length, 0, "Response data should be empty");
    }

    function testShouldRespond_Drift_AboveThreshold() public {
        uint256 driftThreshold = 100;
        uint256[] memory predictions = new uint256[](1);
        predictions[0] = 101; // Latest prediction is above threshold

        bytes[] memory collectOutputs = _createCollectOutputs(predictions, driftThreshold);

        (bool shouldRespond, bytes memory responseData) = aiDriftTrap.shouldRespond(collectOutputs);

        assertEq(shouldRespond, true, "Should respond when latest prediction is above threshold");
        assertGt(responseData.length, 0, "Response data should not be empty");
    }

    function testShouldRespond_EdgeCase_AtThreshold() public {
        uint256 driftThreshold = 100;
        uint256[] memory predictions = new uint256[](1);
        predictions[0] = 100; // Latest prediction is exactly at threshold

        bytes[] memory collectOutputs = _createCollectOutputs(predictions, driftThreshold);

        (bool shouldRespond, bytes memory responseData) = aiDriftTrap.shouldRespond(collectOutputs);

        assertEq(shouldRespond, false, "Should not respond when latest prediction is exactly at threshold");
        assertEq(responseData.length, 0, "Response data should be empty");
    }

    function testShouldRespond_EmptyCollectOutputs() public {
        bytes[] memory collectOutputs = new bytes[](0);

        vm.expectRevert(); // Expect revert because of accessing _collectOutputs[_collectOutputs.length - 1]
        aiDriftTrap.shouldRespond(collectOutputs);
    }
}