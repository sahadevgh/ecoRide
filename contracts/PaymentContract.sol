// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface userContract {
    function isVerifiedUser(address _address) external view returns (bool);
    
}

contract PaymentContract is ReentrancyGuard {
    mapping(uint256 => uint256) public escrow;
    address public admin;
    address public userContractAddress;

    event PaymentDeposited(uint256 indexed orderId, uint256 amount);
    event PaymentReleased(uint256 indexed orderId, address indexed recipient);
    event PaymentRefunded(uint256 indexed orderId, address indexed recipient);
    
    constructor(address _userContractAddress) {
        userContractAddress = _userContractAddress;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not authorized");
        _;
    }

    modifier onlyVerifiedUser() {
        userContract userContractInstance = userContract(userContractAddress);
        require(userContractInstance.isVerifiedUser(msg.sender), "User is not verified");
        _;
    }

    // Deposit payment into escrow
    function depositOrderPayment(uint256 _orderId) external payable onlyVerifiedUser nonReentrant {
        require(msg.value > 0, "Payment must be greater than zero");
        escrow[_orderId] += msg.value;
        emit PaymentDeposited(_orderId, msg.value);
    }

    // Release payment to the rider
    function releasePayment(uint256 _orderId, address _rider) external nonReentrant {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");
        require(_rider != address(0), "Invalid rider address");

        escrow[_orderId] = 0;
        payable(_rider).transfer(amount);
        emit PaymentReleased(_orderId, _rider);
    }

    // Refund payment to the user
    function refundPayment(uint256 _orderId, address _user) external nonReentrant {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");
        require(_user != address(0), "Invalid user address");

        escrow[_orderId] = 0;
        payable(_user).transfer(amount);
        emit PaymentRefunded(_orderId, _user);
    }

    // Update admin address (only admin can do this)
    function updateAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        admin = newAdmin;
    }
}
