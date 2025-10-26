// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/ITrap.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./AIMock.sol";
import "./AIConfig.sol";
import "./TrapRegistry.sol"; // Import the new registry contract

contract AIDriftTrap is ITrap {
    // IMPORTANT: This address must be updated with the deployed TrapRegistry contract address.
    TrapRegistry public constant TRAP_REGISTRY = TrapRegistry(0x0d4870DF260D132862bA6Ec512aDe3648f92D093);

    function collect() external view override returns (bytes memory) {
        // Ask the registry for the *current* AIConfig address
        address currentConfigAddress = TRAP_REGISTRY.contractAddresses("AIConfig");
        require(currentConfigAddress != address(0), "AIConfig address not set in registry");
        AIConfig currentConfig = AIConfig(currentConfigAddress);

        AIMock aiModel = AIMock(currentConfig.aiModelAddress());
        uint256 prediction = aiModel.getPrediction();
        uint256 driftThreshold = currentConfig.driftThreshold();
        return abi.encode(prediction, driftThreshold);
    }

    function shouldRespond(bytes[] calldata _collectOutputs) external pure override returns (bool, bytes memory) {
        (uint256 latestPrediction, uint256 driftThreshold) = abi.decode(_collectOutputs[_collectOutputs.length - 1], (uint256, uint256));

        // Simplified drift detection: if latest prediction exceeds a direct threshold
        // The more complex, windowed analysis will be handled by the off-chain Drosera operator.
        if (latestPrediction > driftThreshold) {
            return (true, abi.encodePacked("Drift detected: Latest prediction ", Strings.toString(latestPrediction), " exceeds direct threshold ", Strings.toString(driftThreshold)));
        }

        return (false, "");
    }
}
