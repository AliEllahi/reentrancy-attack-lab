// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title VulnerableBank
/// @notice A tiny ETH bank used to demonstrate a reentrancy attack.
/// @dev NOT SAFE. `withdraw` sends ETH BEFORE it sets the user's balance to zero, so a malicious
///      contract can call `withdraw` again from inside its `receive` function and be paid many times.
contract VulnerableBank {
    mapping(address => uint256) public balances;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "no balance");

        // BUG: interaction (sending ETH) happens before the effect (balance = 0).
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok, "send failed");

        balances[msg.sender] = 0;
        emit Withdrawn(msg.sender, amount);
    }

    function totalAssets() external view returns (uint256) {
        return address(this).balance;
    }
}
