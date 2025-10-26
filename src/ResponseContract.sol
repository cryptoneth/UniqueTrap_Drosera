// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract ResponseContract {
    address public owner;
    address public droseraAddress;
    string public lastMessage;
    bytes public lastBytesMessage; // Added for bytes response

    event DriftDetected(string message, uint256 timestamp);
    event BytesDriftDetected(bytes message, uint256 timestamp); // Added for bytes
    event DroseraAddressSet(address indexed newDroseraAddress);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyDrosera() {
        require(msg.sender == droseraAddress, "Caller is not the Drosera address");
        _;
    }

    function setDroseraAddress(address _newDroseraAddress) public onlyOwner {
        droseraAddress = _newDroseraAddress;
        emit DroseraAddressSet(_newDroseraAddress);
    }

    function handleDrift(string memory _message) public onlyDrosera {
        lastMessage = _message;
        emit DriftDetected(_message, block.timestamp);
    }

    function respond(bytes memory _message) public onlyDrosera {
        lastBytesMessage = _message;
        emit BytesDriftDetected(_message, block.timestamp);
    }
}
