// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IUserContract {
    function isVerifiedUser(address _address) external view returns (bool);
}

interface IRiderContract {
    function getRider(address _address) external view returns (bool);
    function updateRiderRating(address _rider, uint256 _rating) external;
}

interface IPaymentContract {
    function depositOrderPayment(uint256 _orderId) external payable;

    function releasePayment(uint256 _orderId, address _rider) external;

    function refundPartialPayment(uint256 _orderId, address _user) external;

    function refundPayment(uint256 _orderId, address _user) external;
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
        address payable user;
        address payable rider;
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
        string destination,
        uint256 timestamp
    );
    event OrderAccepted(uint256 indexed orderId, address indexed rider, uint256 timestamp);
    event OrderCompleted(uint256 indexed orderId, address indexed rider, uint256 timestamp);
    event OrderCancelled(uint256 indexed orderId, address indexed user, uint256 timestamp);
    event FeedbackAdded(
        uint256 indexed orderId,
        uint256 rating,
        string comment,
        uint256 timestamp
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

    modifier onlyVerifiedUser() {
        require(
            IUserContract(userContractAddress).isVerifiedUser(msg.sender),
            "Caller must be a verified user"
        );
        _;
    }

    modifier onlyRider() {
        require(
            IRiderContract(riderContractAddress).getRider(msg.sender),
            "Caller must be a verified rider"
        );
        _;
    }

    function createOrder(
        uint256 _fee,
        string memory _pickupLocation,
        string memory _destination,
        uint256 _tip
    ) external onlyVerifiedUser returns (uint256) {
        orderCounter++;
        orders[orderCounter] = Order(
            payable(msg.sender),
            payable(address(0)),
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

        uint256 totalAmount = _fee + _tip;

        IPaymentContract(paymentContractAddress).depositOrderPayment{
            value: totalAmount
        }(orderCounter);

        emit OrderCreated(
            orderCounter,
            msg.sender,
            _fee,
            _tip,
            _pickupLocation,
            _destination,
            block.timestamp
        );
        return orderCounter;
    }

    function acceptOrder(uint256 _orderId) external onlyRider {
        Order storage order = orders[_orderId];
        require(
            order.status == OrderStatus.Pending,
            "Order not in pending state"
        );

        order.rider = payable(msg.sender);
        order.status = OrderStatus.Accepted;
        emit OrderAccepted(_orderId, msg.sender, block.timestamp);
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

        // Integrate the PaymentContract
        IPaymentContract(paymentContractAddress).releasePayment(
            _orderId,
            order.rider
        );

        order.status = OrderStatus.Completed;
        emit OrderCompleted(_orderId, msg.sender, block.timestamp);
    }

    // Cancel order by the user
    function userCancelOrder(uint256 _orderId) external onlyVerifiedUser nonReentrant {
        Order storage order = orders[_orderId];
        require(order.user == msg.sender, "Only user can cancel");
        require(
            order.status != OrderStatus.Completed,
            "Cannot cancel completed order"
        );

        if (order.status == OrderStatus.InProgress) {
            IPaymentContract(paymentContractAddress).releasePayment(_orderId, order.rider);
        } else if (order.status == OrderStatus.Accepted) {
            IPaymentContract(paymentContractAddress).refundPartialPayment(_orderId, order.user);
        } else {
            IPaymentContract(paymentContractAddress).refundPayment(_orderId, order.user);
        }

        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(_orderId, msg.sender, block.timestamp);
    }

    // Cancel order by the rider
    function riderCancelOrder(uint256 _orderId) external onlyRider {
        Order storage order = orders[_orderId];
        require(order.rider == msg.sender, "Only rider can cancel");
        require(
            order.status != OrderStatus.Completed,
            "Cannot cancel completed order"
        );

        IPaymentContract(paymentContractAddress).refundPayment(_orderId, order.user);

        order.status = OrderStatus.Cancelled;
        emit OrderCancelled(_orderId, msg.sender, block.timestamp);
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
        // Send feedback to the rider contract
        IRiderContract(riderContractAddress).updateRiderRating(order.rider, _rating);

        order.userComment = _comment;
        emit FeedbackAdded(_orderId, _rating, _comment, block.timestamp);
    }
}
