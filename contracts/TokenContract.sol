// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EcoRideToken is ERC20 {
    constructor() ERC20("EcoRideToken", "ERT") {
        _mint(msg.sender, 1000000 * 10 ** decimals()); // Initial supply
    }

    function reward(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}