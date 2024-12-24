// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUserContract {
    function isVerifiedUser(address _address) external view returns (bool);
}

interface IRiderContract {
    function getRider(address _address) external view returns (bool);
}

interface IPaymentContract {
    function depositPayment(uint256 _orderId) external payable;

    function releasePayment(uint256 _orderId, address _rider) external;
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
        uint256 tip;
        string pickupLocation;
        string destination;
        string pickupLandmark;
        string destinationLandmark;
        OrderStatus status;
        uint256 timestamp;
        uint256 riderRating;
        string userComment;
    }

    mapping(uint256 => Order) public orders;
    mapping(uint256 => uint256) public escrow;
    uint256 public orderCounter;

    address public userContractAddress;
    address public riderContractAddress;
    address public paymentContractAddress;

    event OrderCreated(
        uint256 indexed orderId,
        address indexed user,
        uint256 fee,
        uint256 tip,
        string pickupLocation,
        string destination
    );
    event OrderAccepted(uint256 indexed orderId, address indexed rider);
    event OrderCompleted(uint256 indexed orderId);
    event OrderCancelled(uint256 indexed orderId);
    event FeedbackAdded(
        uint256 indexed orderId,
        uint256 rating,
        string comment
    );

    constructor(
        address _userContractAddress,
        address _riderContractAddress,
        address _paymentContractAddress
    ) {
        userContractAddress = _userContractAddress;
        riderContractAddress = _riderContractAddress;
        paymentContractAddress = _paymentContractAddress;
    }

    modifier onlyUser() {
        require(
            IUserContract(userContractAddress).isVerifiedUser(msg.sender),
            "Caller must be a registered user"
        );
        _;
    }

    modifier onlyRider() {
        require(
            IRiderContract(riderContractAddress).getRider(msg.sender),
            "Caller must be a registered rider"
        );
        _;
    }

    function createOrder(
        uint256 _fee,
        string memory _pickupLocation,
        string memory _destination,
        uint256 _tip
    ) external payable onlyUser returns (uint256) {
        require(
            msg.value == _fee + _tip,
            "Total payment must include fee and tip"
        );

        orderCounter++;
        orders[orderCounter] = Order(
            msg.sender,
            address(0),
            _fee,
            _tip,
            _pickupLocation,
            _destination,
            "",
            "",
            OrderStatus.Pending,
            block.timestamp,
            0,
            ""
        );

        uint256 totalAmount = msg.value;

        IPaymentContract(paymentContractAddress).depositPayment{
            value: totalAmount
        }(orderCounter);

        emit OrderCreated(
            orderCounter,
            msg.sender,
            _fee,
            _tip,
            _pickupLocation,
            _destination
        );
        return orderCounter;
    }

    function acceptOrder(uint256 _orderId) external onlyRider {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Pending,
            "Order not in pending state"
        );

        order.rider = msg.sender;
        order.status = OrderStatus.Accepted;
        emit OrderAccepted(_orderId, msg.sender);
    }

    function startOrder(uint256 _orderId) external onlyRider {
        Order storage order = orders[_orderId];
        require(order.rider == msg.sender, "Only assigned rider can start");
        require(order.status == OrderStatus.Accepted, "Order not in progress");

        order.status = OrderStatus.InProgress;
    }

    function completeOrder(uint256 _orderId) external onlyRider {
        Order storage order = orders[_orderId];
        require(order.rider == msg.sender, "Only assigned rider can complete");
        require(order.status == OrderStatus.Accepted, "Order not in progress");

        order.status = OrderStatus.Completed;
        // payable(order.rider).transfer(escrow[_orderId]);

        // Integrate the PaymentContract

        emit OrderCompleted(_orderId);
    }

    function cancelOrder(uint256 _orderId) external nonReentrant {
        Order storage order = orders[_orderId];
        require(order.user == msg.sender, "Only user can cancel");
        require(
            order.status != OrderStatus.Completed,
            "Cannot cancel completed order"
        );

        if (order.status == OrderStatus.Accepted) {
            payable(order.rider).transfer(escrow[_orderId]);
        } else {
            payable(order.user).transfer(escrow[_orderId]);
        }

        escrow[_orderId] = 0;
        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(_orderId);
    }

    function addFeedback(
        uint256 _orderId,
        uint256 _rating,
        string memory _comment
    ) external {
        Order storage order = orders[_orderId];
        require(order.user == msg.sender, "Only the user can add feedback");
        require(
            order.status == OrderStatus.Completed,
            "Order must be completed"
        );

        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");

        order.riderRating = _rating;
        order.userComment = _comment;
        emit FeedbackAdded(_orderId, _rating, _comment);
    }
}
