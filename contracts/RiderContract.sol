// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract RiderContract {
    struct Rider {
        address riderAddress;
        bool verified;
        uint256 completedDeliveries;
    }

    mapping(address => Rider) public riders;

    event RiderRegistered(address indexed rider);
    event RiderVerified(address indexed rider);

    function registerRider() external {
        require(riders[msg.sender].riderAddress == address(0), "Rider already registered");
        riders[msg.sender] = Rider(msg.sender, false, 0);
        emit RiderRegistered(msg.sender);
    }

    function verifyRider(address _rider) external {
        require(riders[_rider].riderAddress != address(0), "Rider not registered");
        riders[_rider].verified = true;
        emit RiderVerified(_rider);
    }

    function incrementDeliveries(address _rider) external {
        require(riders[_rider].verified, "Rider not verified");
        riders[_rider].completedDeliveries++;
    }
}