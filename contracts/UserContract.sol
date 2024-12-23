// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract UserContract {
    struct User {
        address userAddress;
        bool verified;
    }

    mapping(address => User) public users;

    event newUserJoined(address indexed user);
    event userVerified(address indexed user);

    // Register as a user
    function newUser() external {
        require(users[msg.sender].userAddress == address(0), "user already registered");
        users[msg.sender] = User(msg.sender, false);
        emit newUserJoined(msg.sender);
    }

    // Verify user using a ZK proof
    function verifyUser(address _user) external {
        require(users[_user].userAddress != address(0), "user not registered");
       
        // integrate ZK proof verification logic here
        users[_user].verified = true;
        emit userVerified(_user);
    }
}
