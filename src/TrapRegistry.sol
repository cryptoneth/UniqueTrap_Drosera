// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract TrapRegistry {
    address public owner;
    mapping(string => address) public contractAddresses;

    event AddressSet(string name, address newAddress);

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function setAddress(string memory _name, address _newAddress) public onlyOwner {
        contractAddresses[_name] = _newAddress;
        emit AddressSet(_name, _newAddress);
    }
}
