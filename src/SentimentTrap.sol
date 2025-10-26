// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/ITrap.sol";
import "./ChatGPTInfoStore.sol";

contract SentimentTrap is ITrap {
    // The address of the ChatGPTInfoStore contract, set as a constant.
    address private constant CHATGPT_INFO_STORE_ADDRESS = 0xC44363700f4825d894BB084B9d9f1624b2aFBc05;

    function collect() external view override returns (bytes memory) {
        ChatGPTInfoStore chatGPTInfoStore = ChatGPTInfoStore(CHATGPT_INFO_STORE_ADDRESS);
        string memory info = chatGPTInfoStore.encodedChatGPTInfo();
        return abi.encode(info);
    }

    function shouldRespond(bytes[] calldata _collectOutputs) external pure override returns (bool, bytes memory) {
        string memory collectedInfo = abi.decode(_collectOutputs[_collectOutputs.length - 1], (string));

        // On-chain parsing to check if the response contains "NEGATIVE".
        if (contains(collectedInfo, "NEGATIVE")) {
            return (true, abi.encodePacked("SentimentTrap Triggered: Found 'NEGATIVE' in response."));
        }

        return (false, "");
    }

    /// @dev Checks if a smaller string (`needle`) is present within a larger string (`haystack`).
    function contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);

        if (needleBytes.length == 0) {
            return true; // An empty string is always contained.
        }

        if (needleBytes.length > haystackBytes.length) {
            return false; // Needle cannot be larger than the haystack.
        }

        for (uint i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool isMatch = true;
            for (uint j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) {
                return true;
            }
        }
        
        return false;
    }
}
