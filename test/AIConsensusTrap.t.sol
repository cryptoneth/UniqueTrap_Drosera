// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AIConsensusTrap.sol";

contract AIConsensusTrapTest is Test {
    AIConsensusTrap public trap;

    function setUp() public {
        trap = new AIConsensusTrap();
    }

    function _encodeCollectOutput(uint256 primaryPrediction, uint256 sentinelPrediction, uint256 maxDivergence)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(primaryPrediction, sentinelPrediction, maxDivergence);
    }

    function _createCollectOutputs(
        uint256[] memory primaryPredictions,
        uint256[] memory sentinelPredictions,
        uint256 maxDivergence
    ) internal pure returns (bytes[] memory) {
        require(primaryPredictions.length == sentinelPredictions.length, "prediction length mismatch");

        bytes[] memory collectOutputs = new bytes[](primaryPredictions.length);
        for (uint256 i = 0; i < primaryPredictions.length; i++) {
            collectOutputs[i] = _encodeCollectOutput(primaryPredictions[i], sentinelPredictions[i], maxDivergence);
        }
        return collectOutputs;
    }

    function testShouldRespond_WhenDivergenceWithinTolerance() public {
        uint256 maxDivergence = 10;
        uint256[] memory primaryPredictions = new uint256[](1);
        uint256[] memory sentinelPredictions = new uint256[](1);

        primaryPredictions[0] = 105;
        sentinelPredictions[0] = 100;

        bytes[] memory collectOutputs = _createCollectOutputs(primaryPredictions, sentinelPredictions, maxDivergence);

        (bool shouldRespond, bytes memory responseData) = trap.shouldRespond(collectOutputs);

        assertFalse(shouldRespond, "Trap should not respond within tolerance");
        assertEq(responseData.length, 0, "Response data should be empty within tolerance");
    }

    function testShouldRespond_WhenDivergenceExceedsTolerance() public {
        uint256 maxDivergence = 5;
        uint256[] memory primaryPredictions = new uint256[](1);
        uint256[] memory sentinelPredictions = new uint256[](1);

        primaryPredictions[0] = 120;
        sentinelPredictions[0] = 100;

        bytes[] memory collectOutputs = _createCollectOutputs(primaryPredictions, sentinelPredictions, maxDivergence);

        (bool shouldRespond, bytes memory responseData) = trap.shouldRespond(collectOutputs);

        assertTrue(shouldRespond, "Trap should respond when divergence exceeds tolerance");
        assertGt(responseData.length, 0, "Response data should contain explanation");
    }

    function testShouldRespond_EmptyCollectOutputsReverts() public {
        bytes[] memory collectOutputs = new bytes[](0);

        vm.expectRevert();
        trap.shouldRespond(collectOutputs);
    }
}
