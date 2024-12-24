// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IUserContract {
    function isVerifiedUser(address _address) external view returns (bool);
}

contract RiderContract {
    struct Rider {
        address riderAddress;
        bool verified;
        bool isAvailable;
        uint256 completedDeliveries;
        uint256 totalRatings;
        uint256 ratingCount;
        uint256 averageRating;
        uint256 totalEarnings;
        string city;
        string bikeModel;
        string color;
        string bikeNumber;
        uint256 tokenBalance;
    }

    struct Applicant {
        address applicantAddress;
        bool applied;
    }

    address public admin;
    address public userContractAddress;
    uint256 public riderFee;

    // store rider application data
    mapping(address => Applicant) public applicants;
    mapping(address => Rider) public riders;

    Applicant[] public applicantList;
    mapping(address => uint256) public applicantEscrowFee;
    Rider[] public riderList;
    Rider[] public removedRiders;

    event NewApplicant(address indexed applicant, uint256 timestamp);
    event RiderRegistered(address indexed rider, uint256 timestamp);
    event RiderVerified(address indexed rider, uint256 timestamp);
    event RiderRatingUpdated(
        address indexed rider,
        uint256 rating,
        uint256 timestamp
    );
    event ApplicantRemoved(address indexed applicant, uint256 timestamp);

    constructor(address _userContractAddress) {
        userContractAddress = _userContractAddress;
        admin = msg.sender;
    }

    //  Modifier to ensure caller is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    // set rider fee
    function setRiderFee(uint256 _fee) external onlyAdmin {
        riderFee = _fee;
    }

    modifier onlyVerifiedUser(address _address) {
        require(
            IUserContract(userContractAddress).isVerifiedUser(_address),
            "User not verified"
        );
        _;
    }

    // apply to become a rider
    function riderApplication() external payable onlyVerifiedUser(msg.sender) {
        require(msg.value == riderFee, "Insufficient fee");
        require(
            applicants[msg.sender].applicantAddress == address(0),
            "Application already submitted"
        );
        require(
            riders[msg.sender].riderAddress == address(0),
            "Rider already registered"
        );

        applicantEscrowFee[msg.sender] += msg.value;

        // add applicant to list
        applicants[msg.sender] = Applicant(msg.sender, true);
        applicantList.push(applicants[msg.sender]);

        emit NewApplicant(msg.sender, block.timestamp);
    }

    function verifyRider(address _applicantAddress) external onlyAdmin {
        require(
            applicants[_applicantAddress].applicantAddress != address(0),
            "Applicant not found"
        );
        require(applicants[_applicantAddress].applied, "Applicant not applied");
        require(
            IUserContract(userContractAddress).isVerifiedUser(
                _applicantAddress
            ),
            "User not verified"
        );
        require(
            riders[_applicantAddress].riderAddress == address(0),
            "Rider already registered"
        );

        // add rider to list
        riders[_applicantAddress] = Rider(
            _applicantAddress, 
            true, 
            true,
            0,
            0,
            0,
            0,
            0,
            "",
            "",
            "",
            "",
            0
            );
        riderList.push(riders[_applicantAddress]);

        // Reassign the escrow fee to the contract
        payable(admin).transfer(applicantEscrowFee[_applicantAddress]);
        // Reset the escrow fee to 0
        applicantEscrowFee[_applicantAddress] = 0;

        emit RiderVerified(_applicantAddress, block.timestamp);
    }

    function rejectRider(address _applicantAddress) external onlyAdmin {
        require(
            applicants[_applicantAddress].applicantAddress != address(0),
            "Applicant not found"
        );
        require(applicants[_applicantAddress].applied, "Applicant not applied");
        require(
            riders[_applicantAddress].riderAddress == address(0),
            "Rider already registered"
        );

        // Reassign the escrow fee to the applicant
        payable(_applicantAddress).transfer(
            applicantEscrowFee[_applicantAddress]
        );

        // Escrow fee is reset to 0
        applicantEscrowFee[_applicantAddress] = 0;
        // remove applicant
        delete applicants[_applicantAddress];

        // emit event
        emit ApplicantRemoved(_applicantAddress, block.timestamp);
    }

    // Update rider rating
    function updateRiderRating(
        address _rider,
        uint256 _rating
    ) external {
        require(riders[_rider].verified, "Rider not verified");
        require(_rating >= 1 && _rating <= 5, "Invalid rating");

        // Update rider rating
        riders[_rider].totalRatings += _rating;
        riders[_rider].ratingCount++;
        riders[_rider].averageRating = riders[_rider].totalRatings / riders[_rider].ratingCount;

        // emit event
        emit RiderRatingUpdated(_rider, _rating, block.timestamp);
    }

    modifier onlyRider() {
        require(riders[msg.sender].verified, "Rider not verified");
        _;
    }

    // Unavailable rider
    function setRiderUnavailable() external onlyRider {
        riders[msg.sender].isAvailable = false;
    }

    // Available rider
    function setRiderAvailable() external onlyRider {
        riders[msg.sender].isAvailable = true;
    }

    // remove rider
    function removeRider(address _rider) external onlyAdmin {
        require(riders[_rider].riderAddress != address(0), "Rider not found");
        removedRiders.push(riders[_rider]);
        delete riders[_rider];
    }

    function incrementDeliveries(address _rider) external {
        require(riders[_rider].verified, "Rider not verified");
        riders[_rider].completedDeliveries++;
    }

    function getApplicant(address _applicant) external view returns (bool) {
        return applicants[_applicant].applied;
    }

    function getAllApplicants() external view returns (Applicant[] memory) {
        return applicantList;
    }

    function getRider(address _rider) external view returns (bool) {
        return riders[_rider].verified;
    }

    function getAllRiders() external view returns (Rider[] memory) {
        return riderList;
    }
}
