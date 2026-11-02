// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice The two functions every bank in this lab exposes. Used by the attacker contract and the tests.
interface IBank {
    function deposit() external payable;
    function withdraw() external;
}
