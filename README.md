# safe-restricted-actions-guard

## Description

`RestrictedActionsGuard` is a Safe Guard that allows onwers to perform only allowed actions on whitelisted targets.

It introduces a new *Guard threshold* concept that replaces the usual *Safe threshold*, allowing more nuanced permissions.

For example, a 3/5 Safe (3 owners out of 5 must sign in order to execute a transaction) can be converted into a 2/3/5 Safe (at least 2 owners out of 5 must sign in order to perform any of the allowed actions on whitelisted targets, while all other actions require at least 3 signatures out of 5 to execute a transaction).

## Use cases

- 1/2/3 Safe where one of the owners is an automated account that can place limit orders but not market orders.  
- 2/2/3 Safe where two of the owners are AI agents that can Safe manage funds but only if the recipient is the Safe account.  
- 2/3/5 Safe for a DAO treasury where at two owners can execute approved governance proposals, submit emergency transactions, but need 3 signatures for token transfers, or protocol parameter changes

## Deployments

| Network | Address |
| ------- | ------- |
| Ethereum | [`0xF22950636786102A678B4d821a810C865E28cD76`](https://etherscan.io/address/0xF22950636786102A678B4d821a810C865E28cD76) |
| Arbitrum | [`0xF22950636786102A678B4d821a810C865E28cD76`](https://arbiscan.io/address/0xF22950636786102A678B4d821a810C865E28cD76) |
| Optimism | [`0xF22950636786102A678B4d821a810C865E28cD76`](https://optimistic.etherscan.io/address/0xF22950636786102A678B4d821a810C865E28cD76) |
| Celo | [`0xF22950636786102A678B4d821a810C865E28cD76`](https://celoscan.io/address/0xF22950636786102A678B4d821a810C865E28cD76) |
| Linea | [`0xF22950636786102A678B4d821a810C865E28cD76`](https://lineascan.build/address/0xF22950636786102A678B4d821a810C865E28cD76) |

## How it works

1. Setup: After deploying the Safe, the `RestrictedActionsGuard` must be set up with a chosen Guard threshold.
2. Defining Restricted Actions: Owners specify which actions are allowed on particular `target` addresses. This is done using an array of `pattern` + `mask` pairs:
   1. Pattern: A predefined calldata signature that represents a function call
   2. Mask: A wildcard mask that defines which parts of the calldata must match exactly and which can be flexible. The byte `0x00` represents a "wildcard" operator, while any non-null byte represents an "exact match" operator. This allows owners to configure actions such as "deposit is allowed only if the recipient is the safe account"
3. Execution: When a transaction is proposed, the guard checks:
   1. If it meets the standard Safe threshold.
   2. If it matches a whitelisted restricted action and meets the Guard threshold.
   3. If neither condition is met, the transaction is blocked.

## Setup

```solidity
// example configuration for a 1/2/3 Safe
Safe singleton = address(new Safe());
RestrictedActionsGuard restrictedActionsGuard = new RestrictedActionsGuard();
uint256 threshold = 2;

// 0. Deploy a 2/3 Safe
address[] memory owners = new address[](3);
owners[0] = owner1;
owners[1] = owner2;
owners[2] = owner3;
SafeProxy proxy = safeProxyFactory.createProxyWithNonce(
    singleton,
    abi.encodeCall(
        Safe.setup,
        (owners, threshold, address(0), bytes(""), address(0), address(0), 0, payable(address(0)))
    ),
    0
);
Safe safe = Safe(payable(address(proxy)));

// 1. Call `RestrictedActionsGuard.setup` through your Safe:
uint256 guardThreshold = 1;
safe.execTransaction(
    address(restrictedActionsGuard),
    0,
    abi.encodeCall(RestrictedActionsGuard.setup, (guardThreshold)),
    Enum.Operation.Call,
    0,
    0,
    0,
    address(0),
    payable(address(0)),
    signatures
);

// 2. Set the guard on your Safe
safe.execTransaction(
    address(safe),
    0,
    abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))),
    Enum.Operation.Call,
    0,
    0,
    0,
    address(0),
    payable(address(0)),
    signatures
);

// 3. Optionally, reduce your Safe threshold to have a 1/2/3 Safe
safe.execTransaction(
    address(safe),
    0,
    abi.encodeCall(OwnerManager.changeThreshold, (1)),
    Enum.Operation.Call,
    0,
    0,
    0,
    address(0),
    payable(address(0)),
    signatures
);

// 4. Whitelist the restricted actions
// 4.1 Any owner can deposit to a vault but only if the recipient is the safe account
bytes memory pattern1 = abi.encodeCall(ERC4626.deposit, (type(uint256).max, address(safe)));
bytes memory mask1 = abi.encodeWithSelector(bytes4(0xFFFFFFFF), 0, address(uint160(type(uint160).max)));
// 4.2 Any owner can withdraw from a vault but only if the recipient is the safe account
bytes memory pattern2 = abi.encodeCall(ERC4626.withdraw, (type(uint256).max, address(safe), address(0)));
bytes memory mask2 = abi.encodeWithSelector(bytes4(0xFFFFFFFF), 0, address(uint160(type(uint160).max), 0));
address target = address(vault);
bytes[] memory patterns = new bytes[](2);
patterns[0] = pattern1;
patterns[1] = pattern2;
bytes[] memory masks = new bytes[](2);
masks[0] = mask1;
masks[1] = mask2;
safe.execTransaction(
    address(restrictedOwnersGuard),
    0,
    abi.encodeCall(RestrictedOwnersGuard.setRestrictedActions, (target, datas, masks)),
    Enum.Operation.Call,
    0,
    0,
    0,
    address(0),
    payable(address(0)),
    signatures
);
```

## Alternatives

Another approach to implementing restricted actions on a Safe is using the [Zodiac Roles Modifier](https://github.com/gnosisguild/zodiac-modifier-roles) by Gnosis Guild. This modifier enables role-based access control, allowing specific roles to call pre-approved functions with defined parameters.

While the Zodiac Roles Modifier provides a high degree of flexibility, it comes with added complexity. Managing permissions requires defining roles, assigning them to addresses, and explicitly scoping their permissions across multiple dimensions. This can be powerful but cumbersome to manage at scale, especially in multi-signature or automated environments where rules must be updated frequently.

If your use case requires straightforward permission control over a Safe while maintaining a simple setup, `RestrictedActionsGuard` can be a more practical choice.

## Disclaimer

This code is provided "as is" and has not undergone a formal security audit. Use it at your own risk. The author(s) assume no liability for any damages or losses resulting from the use of this code. It is your responsibility to thoroughly review, test, and validate its security and functionality before deploying or relying on it in any environment.
