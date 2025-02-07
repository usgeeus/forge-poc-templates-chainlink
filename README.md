# Bug Description

The **Chainlink VRFCoordinatorV2_5** contract contains a high vulnerability that arises when an **externally owned account (EOA)** directly requests random words. Unlike a contract consumer (which has extcodesize > 0), an EOA will trigger a revert inside the `_callWithExactGas` check, causing the random words request to remain perpetually unfulfilled. This leads to **subscription lock** (preventing `cancelSubscription`, `removeConsumer`, and `migrate`) and **uncollected protocol fees**.

> **Key Issue**:  
> `VRFCoordinatorV2_5` attempts to call into the target address, checking `extcodesize(target)` before fulfilling. If `target` is an EOA (thus `extcodesize` is 0), the code reverts with `revert(0, 0)`, permanently leaving a pending request.

# Brief/Intro

When an EOA directly requests random words from the VRFCoordinatorV2_5, the transaction reverts inside `_callWithExactGas`, effectively marking the request as “in-flight” forever. Because `pendingRequestExists(subId)` never clears, the subscriber cannot exit the subscription or remove that EOA, and the protocol fails to collect fees for the work already performed.

In other words, **both the user’s subscription** (lock issue) **and the protocol** (lost fee revenue) **are negatively impacted by this bug**.

# Details

1. **How it Normally Works**

   - A consumer contract calls `VRFCoordinatorV2_5::requestRandomWords`.
   - The oracle node fulfills the request via `VRFCoordinatorV2_5::fulfillRandomWords`, which calls `_chargePayment` (increasing `s_withdrawableNative`) and then attempts to deliver random words to the consumer contract.
   - If the consumer’s callback fails, the transaction does not revert entirely; a `RandomWordsFulfilled` event indicates success or failure.

2. **What Goes Wrong with an EOA**

   - The same process is triggered when an EOA calls `requestRandomWords`.
   - However, `VRFCoordinatorV2_5::_callWithExactGas` checks `if iszero(extcodesize(target)) { revert(0, 0); }`. Because an EOA has no code, `extcodesize` is `0`, causing `revert(0, 0)`.
   - As a result, **the protocol reverts after consuming resources** (no fees collected) and **the request is never cleared** (the subscription remains in a pending state indefinitely).

3. **Consequences**
   - **Subscription Lock**: `pendingRequestExists(subId)` will be `true`, blocking `cancelSubscription`, `removeConsumer`, or `migrate`.
   - **Lost Fees**: The request reverts before `_chargePayment` can finalize, so the protocol is not compensated for its processing.
   - **Denial of Service**: The subscriber can only escape this situation by asking the contract owner to call `ownerCancelSubscription`. In a trust-minimized setting, that approach undermines decentralization and potentially requires additional overhead.

> **Relevant Snippet (Within `_callWithExactGas`)**
>
> ```
> if iszero(extcodesize(target)) {
>   revert(0, 0);
> }
> ```

# Impact

- \*\*High
  - **Blocking Subscription Cancellation**: Users cannot recover funds or remove the stuck consumer.
  - **Off-Chain Resource Consumption**: The oracle has already used resources to compute the random words.
  - **Protocol Revenue Loss**: The protocol does not earn fees for the resources expended.

Given that this can cause a user’s subscription to be permanently locked and denies rightful fees to the protocol, it represents a high-priority vulnerability.

# Risk Breakdown

- **Exploitation Difficulty**: Low. Any EOA that calls `requestRandomWords` directly will trigger the bug. There is no special exploit code needed other than interacting with the contract from an EOA.
- **Severity**: High. It has a wide impact on user funds (locked subscriptions) and protocol fees.
- **Likelihood**: Moderate. A user might accidentally or intentionally call from an EOA.

Referencing **Immunefi’s Vulnerability Severity Classification System**:

- **Funds/User Lockout**: This typically falls under the **High** category due to the potential to block user actions.
- **Indirect Financial Loss**: Also relevant, as the protocol misses out on its legitimate fees.

# Recommendation

- **Replace the `revert(0, 0)` Logic**
  - Change the `_callWithExactGas` check to **return false** if `extcodesize` is zero. For example:
    ```
    if (extcodesize(target) == 0) {
      // Instead of reverting, return false
      return(0, 0);
    }
    ```
  - This allows fee collection to proceed and the request to finalize successfully, even if the EOA cannot handle callbacks.
- **Validate Target Before Request**
  - The protocol can enforce that only contracts be used as consumers by checking code size **before** processing requests, preventing EOA-based requests from even entering the system.

# References

- [VRFCoordinatorV2_5 `_callWithExactGas` code on GitHub](https://github.com/smartcontractkit/chainlink/blob/e6dfb808bc4d9f192f211aafebedde73d0e6cda3/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol#L344-L346)

# Proof of Concept

Below is a step-by-step guide to replicate and verify the issue in a Foundry-based environment. By following these instructions, you can observe how an EOA's random words request gets stuck due to the revert caused by `extcodesize == 0`, effectively locking the subscription and preventing fee collection.

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (d14a7b4 2024-11-24T00:24:44.637144000Z)`

## Build

```
git clone https://github.com/usgeeus/forge-poc-templates-chainlink.git
cd forge-poc-templates-chainlink
forge build
```

## Test

### Set .env

```
SEPOLIA_RPC_URL=<Sepolia RPC URL>
```

### Run Test

```
forge test -vv
```

The test suite includes:

- **Local Tests**: Demonstrates the revert on a mock version of `VRFCoordinatorV2_5`.
- **Forked Tests**: Forks the Sepolia testnet to show how the EOA request remains stuck in a real-world scenario, blocking subscription cancellation.

If the vulnerability is present, you will see:

- A revert when an EOA attempts to request random words.
- Failed attempts to `cancelSubscription` or `removeConsumer` due to `pendingRequestExists(subId) == true`.
- Zero fees collected by the protocol (`withdrawNative` failing for insufficient balance).
