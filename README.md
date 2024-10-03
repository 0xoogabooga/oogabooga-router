# Ooga Booga Router

## Overview

The Ooga Booga Router (OBRouter) contract acts as a secure intermediary within the Smart Order Routing system, safeguarding user funds during token swaps. It functions as a slippage guard, ensuring that users receive the expected amount of tokens. While the Router handles the initial verification and approval processes, the actual execution of the trade route is delegated to an external proprietary contract. This separation of concerns enhances security and flexibility. To streamline the swapping process, the Router supports both ERC20 and Permit2 approvals, providing users with convenient authorization options. Furthermore, the Router generates revenue through positive slippage and/or fees associated with swaps.

## Features

### Swapping

The primary functions of the router are the user-facing swap functions that facilitate token exchange for users.  Its method of revenue collection involves gathering positive slippage on the `_swap` function when it occurs (defined as the difference between the executed and quoted output when the executed output is higher).

The `_swap` has two externally facing functions that can be called. For accessing the user's ERC20s, both variants allow for traditional approvals made directly to the router, as well as the use of Uniswap's Permit2 contract (as seen here: https://github.com/Uniswap/permit2).

The swap mechanism is also able to cater for rebase tokens which are continuously changing. By setting amount as 0, the OBRouter is able to swap carry a swap using all of user's available balance.

### Referrals

The router supports referral codes to track usage and, optionally, an additional fee that can be charged in conjunction with this referral code being used. New referral codes are registered in a permissioned manner with the `registerReferralCode` function. A referral registration will consist of mapping a referral code to a `referralInfo` struct, which specifies the additional fee (if any), the beneficiary of the fee (again if any), and a boolean value specifying if that code has already been registered or not. The largest half of the space of possible referral codes is eligible for an additional fee to be registered, while the lower half is strictly for tracking purposes in order to avoid extra storage reads. Once registered, `referralInfo` is immutable - if a change is needed, a new referral code will need to be registered.

A referral code can be used by passing into the swap function as an argument when a swap is executed. If specified, the swap will then charge the referral fee on the output(s) of the swap and send 80% of the fee to the specified beneficiary immediately, retaining the remaining 20% as router revenue similar to positive slippage. The referral code will then be emitted in the swap event in order to track the activity.

### Owner Functionality

Through positive slippage, the router collects and holds revenue generated from swap fees. This revenue is held in the router in order to avoid extra gas fees during the user's swap for additional transfers. Therefore, all funds held in the router are considered revenue already owned by the `onlyApproved` role. To manage this revenue, the `owner` can set multiple addresses (including itself) to be `approved` to withdraw funds from the router. To collect the revenue, `approved` entities can call the `transferRouterFunds` function to withdraw any ERC20 or native token held in the router to be transferred to a specified destination. It also automatically wraps native tokens upon withdrawal. Finally it includes the ability to withdrawal all by providing amount of 0.

The referral fee system is currently permissioned and handled by the `owner` of the router.
 
Pausing capabilities (`pause` and `unpause`) have been included and used during exigent circumstances.

## Setup

The OBRouter uses Foundry as the testing framework.

Follow the [instructions](https://book.getfoundry.sh/getting-started/installation) to install [Foundry](https://github.com/foundry-rs/foundry).

```bash
curl -L https://foundry.paradigm.xyz | bash
``` 

The project relies on v5.0.2 of OpenZeppelin's contract dependencies. It should be immediately be available upon cloning as it is a git submodule.

## Tests

To test the Router's functionality, MockExecutor.sol is provided as an example Ooga Booga Executor (Production Executors will be much more complex but will interact with the router in the same way). The WETH and [Permit2](https://github.com/Uniswap/permit2/) contracts are also provided as examples of what contracts the router may be interacting with.

```bash
forge test
```

### Code coverage

#### Pre-requisite
Make sure you have [lcov](https://github.com/linux-test-project/lcov) installed to render test coverage results

macOS:
```bash
brew install lcov
```

Linux:
```bash
sudo apt-get install lcov
```

Or use whichever package manager of preference on Linux

#### Check
```bash
./coverage
```

## Deployed Contracts

### 80084-bArtio Berachain Testnet
| Contract     | Address                                    | Owner:Deployer                             |
| ------------ | ------------------------------------------ | ------------------------------------------ |
| OBRouter.sol | 0xF6eDCa3C79b4A3DFA82418e278a81604083b999D | 0x4b741204257ED68A7E0a8542eC1eA1Ac1Db829d7 |

## Troubleshooting

If certain commands, make sure you are running the latest version of foundry by running:

```bash
foundryup
```