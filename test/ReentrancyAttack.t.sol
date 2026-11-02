// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IBank} from "../src/IBank.sol";
import {VulnerableBank} from "../src/VulnerableBank.sol";
import {SafeBank} from "../src/SafeBank.sol";
import {ReentrancyAttacker} from "./mocks/ReentrancyAttacker.sol";

contract ReentrancyAttackTest is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal attackerEoa = makeAddr("attackerEoa");

    function _depositAs(address user, IBank bank, uint256 amount) internal {
        vm.deal(user, amount);
        vm.prank(user);
        bank.deposit{value: amount}();
    }

    /// @notice The exploit: the attacker puts in 1 ETH and walks away with all 11 ETH in the bank.
    function test_vulnerableBank_isDrained() public {
        VulnerableBank bank = new VulnerableBank();
        _depositAs(alice, IBank(address(bank)), 6 ether);
        _depositAs(bob, IBank(address(bank)), 4 ether);

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        vm.deal(attackerEoa, 1 ether);
        vm.prank(attackerEoa);
        attacker.attack{value: 1 ether}();

        assertEq(address(bank).balance, 0, "bank should be empty");
        assertEq(address(attacker).balance, 11 ether, "attacker should hold all the ETH");
        // The bank still thinks Alice and Bob have money, but it cannot pay them: it is insolvent.
        assertEq(bank.balances(alice), 6 ether);
        assertEq(bank.balances(bob), 4 ether);
    }

    /// @notice After the attack, an honest user cannot get their money back.
    function test_vulnerableBank_honestUserCannotWithdrawAfterAttack() public {
        VulnerableBank bank = new VulnerableBank();
        _depositAs(alice, IBank(address(bank)), 6 ether);
        _depositAs(bob, IBank(address(bank)), 4 ether);

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        vm.deal(attackerEoa, 1 ether);
        vm.prank(attackerEoa);
        attacker.attack{value: 1 ether}();

        vm.prank(alice);
        vm.expectRevert();
        bank.withdraw();
    }

    /// @notice The fix: the same attack now reverts and nobody loses money.
    function test_safeBank_attackReverts() public {
        SafeBank bank = new SafeBank();
        _depositAs(alice, IBank(address(bank)), 6 ether);
        _depositAs(bob, IBank(address(bank)), 4 ether);

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        vm.deal(attackerEoa, 1 ether);
        vm.prank(attackerEoa);
        vm.expectRevert(SafeBank.SendFailed.selector);
        attacker.attack{value: 1 ether}();

        assertEq(address(bank).balance, 10 ether, "victims' money must be intact");
        assertEq(address(attacker).balance, 0);
    }

    /// @notice The fix must not break normal use: an honest user can deposit and withdraw.
    function test_safeBank_honestUserCanWithdraw() public {
        SafeBank bank = new SafeBank();
        _depositAs(alice, IBank(address(bank)), 6 ether);

        vm.prank(alice);
        bank.withdraw();

        assertEq(alice.balance, 6 ether);
        assertEq(address(bank).balance, 0);
        assertEq(bank.balances(alice), 0);
    }

    /// @notice For any victim deposit and any attacker stake, the victims' money stays in the bank
    ///         and the attacker never ends up with more than they put in.
    function testFuzz_safeBank_attackerNeverProfits(uint256 victimDeposit, uint256 stake) public {
        victimDeposit = bound(victimDeposit, 1, 100 ether);
        stake = bound(stake, 1, 100 ether);

        SafeBank bank = new SafeBank();
        _depositAs(alice, IBank(address(bank)), victimDeposit);

        ReentrancyAttacker attacker = new ReentrancyAttacker(IBank(address(bank)));
        vm.deal(attackerEoa, stake);
        vm.prank(attackerEoa);
        // The attack may revert (re-entry blocked) or succeed with no re-entry. Both are fine.
        try attacker.attack{value: stake}() {} catch {}

        assertEq(address(bank).balance, victimDeposit, "victim's money must stay in the bank");
        assertLe(address(attacker).balance, stake, "attacker must not profit");
    }
}
