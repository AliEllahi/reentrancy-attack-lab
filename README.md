# Reentrancy Attack Lab

![test](https://github.com/AliEllahi/reentrancy-attack-lab/actions/workflows/test.yml/badge.svg)

A small Foundry project that shows a classic **reentrancy attack** on an ETH bank and two ways to fix it.

> Built while learning, with the help of an AI assistant (Claude). I ran the tests myself. Simplified contracts, **not audited, not for production**.

## What is in here

| File | What it does |
|------|--------------|
| `src/VulnerableBank.sol` | Sends ETH **before** setting the balance to zero. Vulnerable. |
| `src/SafeBank.sol` | Sets the balance to zero first (Checks-Effects-Interactions) and adds a reentrancy lock. |
| `test/mocks/ReentrancyAttacker.sol` | The attacker contract (for tests only). |
| `test/ReentrancyAttack.t.sol` | Exploit test, defence tests, and a fuzz test. |

## The attack in plain words

1. Alice and Bob deposit 6 ETH and 4 ETH. The bank holds 10 ETH.
2. The attacker deposits 1 ETH and calls `withdraw()`.
3. The bank sends 1 ETH to the attacker **before** it sets the attacker's balance to zero.
4. Receiving ETH triggers the attacker's `receive()` function, which calls `withdraw()` again.
5. The bank still thinks the attacker has 1 ETH, so it pays again. This repeats until the bank is empty.
6. **Result:** the attacker put in 1 ETH and took out 11 ETH. Alice and Bob lose everything.

## The fix

`SafeBank` has two protections:

- **Checks-Effects-Interactions:** set `balances[msg.sender] = 0` first, and only then send ETH.
- **`nonReentrant` lock:** a second call to `withdraw()` while one is running reverts.

With these, the same attack reverts and the bank keeps all its money.

## Run it

```bash
git clone --recurse-submodules https://github.com/AliEllahi/reentrancy-attack-lab.git
cd reentrancy-attack-lab
forge test -vv
```

## Limits (known)

- Simplified contracts: only ETH, no ERC-20 tokens, no access control, no upgrade logic.
- The fuzz test checks one specific attack shape, so it is **not a proof of safety**.
- Cross-function and cross-contract reentrancy are not covered.
- Planning to: compare with OpenZeppelin's `ReentrancyGuard`, add an invariant test, and try a read-only reentrancy example.

## Related

- [erc4626-donation-attack-lab](https://github.com/HesamQorbani/erc4626-donation-attack-lab) by Hesam Qorbani, a similar lab about the ERC-4626 donation attack.
