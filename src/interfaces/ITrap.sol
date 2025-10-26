// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ITrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata _collectOutputs) external view returns (bool, bytes memory);
}
