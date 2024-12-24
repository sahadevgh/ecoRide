// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserContract {
    struct User {
        address userAddress;
        bool verified;
        bool isJoined;
    }

    // store user data
    mapping(address => User) public users;

    event newUserJoined(address indexed user);
    event userVerified(address indexed user);

    // Join as a new user
    function joinPlatform() external {
        require(!users[msg.sender].isJoined, "user already joined");
        users[msg.sender] = User(msg.sender, false, true);
        emit newUserJoined(msg.sender);
    }

    // Verify user using a ZK proof
    function verifyUserWithZk(address _user) external {
        require(users[_user].isJoined, "user not available");
        require(!users[_user].verified, "user already verified");
       
        // integrate ZK proof verification logic here
        users[_user].verified = true;
        emit userVerified(_user);
    }

    // Check if an address is a registered user
    function isVerifiedUser(address _address) external view returns (bool) {
        return users[_address].verified;
    }
}
