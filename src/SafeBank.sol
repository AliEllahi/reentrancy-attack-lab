// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title SafeBank
/// @notice The same bank as VulnerableBank, with two protections against reentrancy.
/// @dev 1) Checks-Effects-Interactions: the balance is set to zero BEFORE ETH is sent.
///      2) A simple reentrancy lock (`nonReentrant`) blocks any second call while one is running.
///      Simplified and NOT audited.
contract SafeBank {
    error ZeroDeposit();
    error NoBalance();
    error SendFailed();
    error Reentrancy();

    mapping(address => uint256) public balances;

    uint256 private locked = 1; // 1 = free, 2 = a call is running

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    modifier nonReentrant() {
        if (locked != 1) revert Reentrancy();
        locked = 2;
        _;
        locked = 1;
    }

    function deposit() external payable {
        if (msg.value == 0) revert ZeroDeposit();
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];
        if (amount == 0) revert NoBalance();

        // Effect first: set the balance to zero BEFORE sending ETH.
        balances[msg.sender] = 0;

        // Interaction last.
        (bool ok,) = msg.sender.call{value: amount}("");
        if (!ok) revert SendFailed();

        emit Withdrawn(msg.sender, amount);
    }

    function totalAssets() external view returns (uint256) {
        return address(this).balance;
    }
}
