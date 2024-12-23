// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUserContract {
    function isUser(address _address) external view returns (bool);
}

contract OrderContract is ReentrancyGuard {
    enum OrderStatus {
        Pending,
        Accepted,
        InProgress,
        Completed,
        Cancelled
    }

    struct Order {
        address user;
        address rider;
        uint256 fee;
        OrderStatus status;
    }

    mapping(uint256 => Order) public orders;
    uint256 public orderCounter;
    mapping(uint256 => uint256) public escrow;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        uint256 fee
    );

    address public userContractAddress; // Address of the UserContract

    event OrderAccepted(uint256 indexed orderId, address indexed rider);
    event OrderCompleted(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);

    constructor(address _userContractAddress) {
        userContractAddress = _userContractAddress;
    }

    // Modifier to ensure caller is a registered user
    modifier onlyUser() {
        require(
            IUserContract(userContractAddress).isUser(msg.sender),
            "Caller must be a registered user"
        );
        _;
    }

    // Create an order
    function createOrder(uint256 _fee) external payable returns (uint256) {
        require(msg.value == _fee, "Fee must match payment");
        orderCounter++;
        orders[orderCounter] = Order(
            msg.sender,
            address(0),
            _fee,
            OrderStatus.Pending
        );
        escrow[orderCounter] = _fee;
        emit OrderCreated(orderCounter, msg.sender, _fee);
        return orderCounter;
    }

    // Accept an order
    function acceptOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Pending,
            "Order not in pending state"
        );

        order.rider = msg.sender;
        order.status = OrderStatus.Accepted;
        emit OrderAccepted(_orderId, msg.sender);
    }

    // Complete an order
    function completeOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.rider == msg.sender, "Only assigned rider can complete");

        order.status = OrderStatus.Completed;
        emit OrderCompleted(_orderId);
    }

    // Cancel an order
    function cancelOrder(uint256 _orderId) external nonReentrant {
        Order storage order = orders[_orderId];
        require(order.user == msg.sender, "Only user can cancel");
        require(
            order.status == OrderStatus.Pending,
            "Order not in pending state"
        );

        uint256 fee = escrow[_orderId];
        escrow[_orderId] = 0;

        payable(order.user).transfer(fee);
        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(_orderId);
    }
}