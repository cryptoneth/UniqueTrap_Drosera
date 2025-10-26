// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title ChatGPTInfoStore
/// @notice Stores encoded information from ChatGPT for on-chain analysis.
contract ChatGPTInfoStore is Ownable {
    string public encodedChatGPTInfo;

    event ChatGPTInfoUpdated(string newInfo);

    constructor() Ownable(msg.sender) {}

    /// @notice Updates the stored encoded ChatGPT information.
    /// @param _newInfo The new encoded information to store.
    function updateInfo(string calldata _newInfo) external onlyOwner {
        encodedChatGPTInfo = _newInfo;
        emit ChatGPTInfoUpdated(_newInfo);
    }
}
