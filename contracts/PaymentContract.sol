// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface userContract {
    function isVerifiedUser(address _address) external view returns (bool);
    
}

interface riderContract {
    function getRider(address _address) external view returns (bool);
}

contract PaymentContract is ReentrancyGuard {
    struct Admin {
        address payable adminAddress;
        bool isSuperAdmin;
    }

    mapping(uint256 => uint256) public escrow;
    mapping(address => Admin) public admins;
    address public userContractAddress;
    address public riderContractAddress;
    uint256 public serviceFee;
    uint256 public refundFee;
    Admin public superAdmin;

    event OrderPaymentDeposited(uint256 indexed orderId, uint256 amount, address indexed user);
    event PaymentReleased(uint256 indexed orderId, address indexed recipient, uint256 amount);
    event serviceFeeReleased(uint256 indexed orderId, address indexed recipient, uint256 amount);
    event PaymentRefunded(uint256 indexed orderId, address indexed recipient, uint256 amount);
    
    constructor(address _userContractAddress, address _riderContractAddress) {
        userContractAddress = _userContractAddress;
        riderContractAddress = _riderContractAddress;
        superAdmin = Admin(payable(msg.sender), true);
        admins[msg.sender] = superAdmin;
    }

    modifier onlySuperAdmin() {
        require(superAdmin.isSuperAdmin && superAdmin.adminAddress != address(0), "Caller is not a super admin");
        _;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender].adminAddress != address(0), "Caller is not authorized");
        _;
    }

    modifier onlyVerifiedUser() {
        userContract userContractInstance = userContract(userContractAddress);
        require(userContractInstance.isVerifiedUser(msg.sender), "User is not verified");
        _;
    }

    modifier onlyRider() {
        riderContract riderContractInstance = riderContract(riderContractAddress);
        require(riderContractInstance.getRider(msg.sender), "Caller is not a rider");
        _;
    }

    // Deposit payment into escrow
    function depositOrderPayment(uint256 _orderId) external payable onlyVerifiedUser nonReentrant {
        require(msg.value > 0, "Payment must be greater than zero");
        escrow[_orderId] += msg.value;
        emit OrderPaymentDeposited(_orderId, msg.value, msg.sender);
    }

    // Release payment to the rider
    function releasePayment(uint256 _orderId, address _rider) external onlyRider nonReentrant {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");
        require(_rider != address(0), "Invalid rider address");

        escrow[_orderId] = 0;

        // Deduct service fee
        uint256 serviceFeeAmount = (amount * serviceFee) / 100;
        uint256 riderAmount = amount - serviceFeeAmount;

        payable(_rider).transfer(riderAmount);
        payable(superAdmin.adminAddress).transfer(serviceFeeAmount);
        emit PaymentReleased(_orderId, _rider, riderAmount);
        emit serviceFeeReleased(_orderId, superAdmin.adminAddress, serviceFeeAmount);
    }

    // Refund full payment to the user
    function refundPayment(uint256 _orderId, address _user) external nonReentrant {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");
        require(_user != address(0), "Invalid user address");

        escrow[_orderId] = 0;
        payable(_user).transfer(amount);
        emit PaymentRefunded(_orderId, _user, amount);
    }

    // Refund part of the payment to the user
    function refundPartialPayment(uint256 _orderId, address _user) external nonReentrant {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");
        require(_user != address(0), "Invalid user address");

        // Deduct refund fee
        uint256 refundFeeAmount = (amount * refundFee) / 100;
        uint256 refundAmount = amount - refundFeeAmount;

        escrow[_orderId] = 0;
        payable(_user).transfer(refundAmount);
        emit PaymentRefunded(_orderId, _user, refundAmount);
    }

    // Update service fee (only admin can do this)
    function updateServiceFee(uint256 _fee) external onlyAdmin {
        serviceFee = _fee;
    }

    // Update refund fee (only admin can do this)
    function updateRefundFee(uint256 _fee) external onlyAdmin {
        refundFee = _fee;
    }

    // Add admin address (only super admin can do this)
    function addAdmin(address _newAdmin) external onlySuperAdmin {
        require(_newAdmin != address(0), "Invalid admin address");
        admins[_newAdmin] = Admin(payable(_newAdmin), false);
    }

    // Remove admin address (only super admin can do this)
    function removeAdmin(address _admin) external onlySuperAdmin {
        require(_admin != address(0), "Invalid admin address");
        require(_admin != msg.sender, "Cannot remove self");
        delete admins[_admin];
    }
}
