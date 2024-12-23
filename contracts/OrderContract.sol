// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract OrderContract {
    struct Order {
        address customer;
        address rider;
        uint256 fee;
        string status; // "Pending", "Accepted", "In Progress", "Completed"
    }

    mapping(uint256 => Order) public orders;
    uint256 public orderCounter;

    event OrderCreated(uint256 indexed orderId, address indexed customer, uint256 fee);
    event OrderAccepted(uint256 indexed orderId, address indexed rider);
    event OrderCompleted(uint256 indexed orderId);

    function createOrder(uint256 _fee) external returns (uint256) {
        orderCounter++;
        orders[orderCounter] = Order(msg.sender, address(0), _fee, "Pending");
        emit OrderCreated(orderCounter, msg.sender, _fee);
        return orderCounter;
    }

    function acceptOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.customer != address(0), "Order does not exist");
        require(order.rider == address(0), "Order already accepted");

        order.rider = msg.sender;
        order.status = "Accepted";
        emit OrderAccepted(_orderId, msg.sender);
    }

    function completeOrder(uint256 _orderId) external {
        Order storage order = orders[_orderId];
        require(order.rider == msg.sender, "Only assigned rider can complete");

        order.status = "Completed";
        emit OrderCompleted(_orderId);
    }
}