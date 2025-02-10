# Bug Description

The **Chainlink VRFCoordinatorV2_5** contract contains a high-severity vulnerability that arises when an **externally owned account (EOA)** directly requests random words. Because `extcodesize(EOA)` equals 0, the `_callWithExactGas` check reverts the transaction—**locking the subscription** and **blocking all subsequent withdrawal or cancellation operations**. The user’s funds remain stuck in the subscription, and the protocol fails to collect fees for the resources consumed.

> **Key Issue**:
> A non-contract (EOA) triggers `revert(0, 0)` in `_callWithExactGas`, leaving the random words request permanently “in flight,” which in turn prevents the user from calling `cancelSubscription` (and other subscription-related functions).

# Brief/Intro

When an EOA calls `requestRandomWords` on `VRFCoordinatorV2_5`, the `fulfillRandomword` transaction reverts within `_callWithExactGas`. This reversion results in a persistent pending request (`pendingRequestExists(subId) == true`), **locking any funds** tied to that subscription. Subscribers cannot exit or reclaim their funds by cancelling the subscription, effectively losing access to their balance.

# Details

1. **How It Normally Works**

   - A contract consumer calls `requestRandomWords`, and the oracle node later fulfills via `fulfillRandomWords`.
   - During fulfillment, `_chargePayment` increments the protocol’s fee, and the consumer is sent random words (or the call fails gracefully without reverting the entire transaction).

2. **What Happens with an EOA**

   - The same process breaks when an EOA initiates the request.
   - `_callWithExactGas` does `if iszero(extcodesize(target)) { revert(0, 0); }`, which is always `true` for EOAs, leading to a full revert.
   - No fee is collected, and the request remains **perpetually pending**, thus `cancelSubscription` (and other subscription-altering functions) fail because `pendingRequestExists(subId)` is never cleared.

3. **Consequences**
   - **Subscription Lock**: Users are unable to free or withdraw their subscription funds.
   - **Denial of Service**: No way to remove the stuck consumer or migrate while the request remains pending.
   - **Lost Fees**: The protocol does not earn fees for the resources already spent.

> **Relevant Snippet (Within `_callWithExactGas`)**
>
> if iszero(extcodesize(target)) {
> revert(0, 0);
> }

# Impact

- **High Severity**
  - **User Funds Locked**: Users cannot withdraw funds from locked subscriptions if an EOA-based request is stuck.
  - **Denied Revenue**: Protocol fees are not collected for consumed resources.
  - **Service Disruption**: Full subscription functionality is blocked until an owner intervention (`ownerCancelSubscription`) is performed, which contradicts a trust-minimized system.

# Risk Breakdown

- **Exploitation Difficulty**: Low. Any EOA accidentally or deliberately calling `requestRandomWords` triggers the bug.
- **Severity**: High. Users lose access to their subscription funds, causing potential financial and operational harm.
- **Likelihood**: Moderate. An EOA invocation can easily occur and remain perpetually unresolved without privileged intervention.

# Recommendation

- **Graceful Handling for EOAs**  
  Replace the revert in `_callWithExactGas` with a non-reverting response, e.g., `return(0, 0)`. This prevents indefinite pending requests and preserves the protocol’s fee logic.
  - Change the `_callWithExactGas` check to **return false** if `extcodesize` is zero. For example:
    ```
    if (extcodesize(target) == 0) {
      // Instead of reverting, return false
      return(0, 0);
    }
    ```
  - This allows fee collection to proceed and the request to finalize successfully, even if the EOA cannot handle callbacks.

# References

- [VRFCoordinatorV2_5 `_callWithExactGas` code on GitHub](https://github.com/smartcontractkit/chainlink/blob/e6dfb808bc4d9f192f211aafebedde73d0e6cda3/contracts/src/v0.8/vrf/dev/VRFCoordinatorV2_5.sol#L344-L346)

# Proof of Concept

Below is a step-by-step guide to replicate and verify the issue in a Foundry-based environment. By following these instructions, you can observe how an EOA’s random words request leads to **locking the user’s funds in the subscription** and preventing protocol fee collection, due to the `extcodesize == 0` check.

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.2.0 (d14a7b4 2024-11-24T00:24:44.637144000Z)`

## Build

git clone https://github.com/usgeeus/forge-poc-templates-chainlink.git
cd forge-poc-templates-chainlink
forge build

## Test

### Set .env

SEPOLIA_RPC_URL=<Sepolia RPC URL>

### Run Test

forge test -vv

The test suite includes:

- **Local Tests**: Demonstrates the revert on a mock version of `VRFCoordinatorV2_5`.
- **Forked Tests**: Forks the Sepolia testnet to show how an EOA request remains stuck, blocking subscription cancellation.

If the vulnerability is present, you will see:

- Failed attempts to `cancelSubscription` or `removeConsumer` due to `pendingRequestExists(subId) == true`.
- Zero fees collected by the protocol (`withdrawNative` failing for insufficient balance).

This confirms the real-world impact of the bug—**subscriptions remain locked, and users cannot withdraw their funds**.
