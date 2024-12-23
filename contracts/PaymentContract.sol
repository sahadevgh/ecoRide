// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract PaymentContract {
    mapping(uint256 => uint256) public escrow;

    event PaymentDeposited(uint256 indexed orderId, uint256 amount);
    event PaymentReleased(uint256 indexed orderId, address indexed rider);

    function depositPayment(uint256 _orderId) external payable {
        require(msg.value > 0, "Payment must be greater than zero");
        escrow[_orderId] += msg.value;
        emit PaymentDeposited(_orderId, msg.value);
    }

    function releasePayment(uint256 _orderId, address _rider) external {
        uint256 amount = escrow[_orderId];
        require(amount > 0, "No payment in escrow");

        escrow[_orderId] = 0;
        payable(_rider).transfer(amount);
        emit PaymentReleased(_orderId, _rider);
    }
}