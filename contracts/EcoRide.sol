// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

contract EcoRide {
    // Token for rewards (to be replaced by an ERC20 token)
    address public owner;

    constructor() {
        owner = msg.sender; // Contract deployer is the owner
    }

    // Structs
    struct Rider {
        address riderAddress;
        bool verified;
        uint256 completedDeliveries;
        uint256 balance;
    }

    struct Delivery {
        address customer;
        address rider;
        uint256 fee;
        bool completed;
        bool paid;
    }

    // Mappings
    mapping(address => Rider) public riders;
    mapping(uint256 => Delivery) public deliveries;
    uint256 public deliveryCounter;

    // Events
    event RiderRegistered(address indexed rider);
    event DeliveryRequested(uint256 indexed deliveryId, address indexed customer, uint256 fee);
    event DeliveryAccepted(uint256 indexed deliveryId, address indexed rider);
    event DeliveryCompleted(uint256 indexed deliveryId);
    event PaymentReleased(uint256 indexed deliveryId, address indexed rider);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    modifier onlyCustomer(uint256 deliveryId) {
        require(deliveries[deliveryId].customer == msg.sender, "Only the customer can perform this action");
        _;
    }

    modifier onlyRider(uint256 deliveryId) {
        require(deliveries[deliveryId].rider == msg.sender, "Only the assigned rider can perform this action");
        _;
    }

    // Functions

    // Register as a Rider
    function registerRider() external {
        require(riders[msg.sender].riderAddress == address(0), "Rider already registered");
        riders[msg.sender] = Rider(msg.sender, false, 0, 0);
        emit RiderRegistered(msg.sender);
    }

    // Verify Rider (Owner only)
    function verifyRider(address _rider) external onlyOwner {
        require(riders[_rider].riderAddress != address(0), "Rider not registered");
        riders[_rider].verified = true;
    }

    // Request a Delivery
    function requestDelivery(uint256 _fee) external payable {
        require(msg.value == _fee, "Fee must be paid upfront");
        deliveryCounter++;
        deliveries[deliveryCounter] = Delivery(msg.sender, address(0), _fee, false, false);
        emit DeliveryRequested(deliveryCounter, msg.sender, _fee);
    }

    // Accept a Delivery
    function acceptDelivery(uint256 _deliveryId) external {
        require(riders[msg.sender].verified, "Only verified riders can accept deliveries");
        require(deliveries[_deliveryId].rider == address(0), "Delivery already accepted");
        deliveries[_deliveryId].rider = msg.sender;
        emit DeliveryAccepted(_deliveryId, msg.sender);
    }

    // Complete a Delivery
    function completeDelivery(uint256 _deliveryId) external onlyRider(_deliveryId) {
        require(!deliveries[_deliveryId].completed, "Delivery already completed");
        deliveries[_deliveryId].completed = true;
        emit DeliveryCompleted(_deliveryId);
    }

    // Release Payment
    function releasePayment(uint256 _deliveryId) external onlyCustomer(_deliveryId) {
        require(deliveries[_deliveryId].completed, "Delivery not completed yet");
        require(!deliveries[_deliveryId].paid, "Payment already released");
        deliveries[_deliveryId].paid = true;

        address rider = deliveries[_deliveryId].rider;
        uint256 fee = deliveries[_deliveryId].fee;

        riders[rider].balance += fee;
        emit PaymentReleased(_deliveryId, rider);
    }

    // Withdraw Balance
    function withdrawBalance() external {
        uint256 balance = riders[msg.sender].balance;
        require(balance > 0, "No balance to withdraw");

        riders[msg.sender].balance = 0;
        payable(msg.sender).transfer(balance);
    }

    // Fallback to accept Ether
    receive() external payable {}

    fallback() external payable {}
}
