// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ITrap.sol";
import "./TrapRegistry.sol";
import "./AIConsensusConfig.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @notice Minimal interface for any model that exposes a `getPrediction()` view.
interface IPredictionModel {
    function getPrediction() external view returns (uint256);
}

/// @title AIConsensusTrap
/// @notice Detects when two AI model predictions diverge beyond an allowed tolerance.
contract AIConsensusTrap is ITrap {
    /// @dev This should be updated to the deployed TrapRegistry address on the target network.
    TrapRegistry public constant TRAP_REGISTRY = TrapRegistry(0x0d4870DF260D132862bA6Ec512aDe3648f92D093);

    function collect() external view override returns (bytes memory) {
        address configAddress = TRAP_REGISTRY.contractAddresses("AIConsensusConfig");
        require(configAddress != address(0), "AIConsensusConfig missing");

        AIConsensusConfig config = AIConsensusConfig(configAddress);
        IPredictionModel primaryModel = IPredictionModel(config.primaryModel());
        IPredictionModel sentinelModel = IPredictionModel(config.sentinelModel());

        uint256 primaryPrediction = primaryModel.getPrediction();
        uint256 sentinelPrediction = sentinelModel.getPrediction();
        uint256 maxDivergence = config.maxDivergence();

        return abi.encode(primaryPrediction, sentinelPrediction, maxDivergence);
    }

    function shouldRespond(bytes[] calldata _collectOutputs) external pure override returns (bool, bytes memory) {
        (uint256 primaryPrediction, uint256 sentinelPrediction, uint256 maxDivergence) =
            abi.decode(_collectOutputs[_collectOutputs.length - 1], (uint256, uint256, uint256));

        uint256 divergence = primaryPrediction >= sentinelPrediction
            ? primaryPrediction - sentinelPrediction
            : sentinelPrediction - primaryPrediction;

        if (divergence > maxDivergence) {
            return (
                true,
                abi.encodePacked(
                    "Consensus Trap Triggered: divergence ",
                    Strings.toString(divergence),
                    " exceeds max ",
                    Strings.toString(maxDivergence),
                    " (primary=",
                    Strings.toString(primaryPrediction),
                    ", sentinel=",
                    Strings.toString(sentinelPrediction),
                    ")"
                )
            );
        }

        return (false, "");
    }
}
