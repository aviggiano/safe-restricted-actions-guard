// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console, Script} from "forge-std/Script.sol";
import {Mainnet} from "@script/addresses/Mainnet.sol";
import {WETH} from "@solady/src/tokens/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISizeWrong} from "@script/interfaces/ISize.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";

contract CTFScript is Script, Mainnet {
    address internal constant RESTRICTED_ACTIONS_GUARD_ADDRESS = 0x457f785000cA495FAe63AAb38C9fC4b2965B106a;

    function run() public {
        vm.startBroadcast();
        Safe safe = Safe(payable(vm.envAddress("SAFE_ADDRESS")));

        console.log("[CTF] running...");
        address target;
        bytes[] memory patterns;
        bytes[] memory masks;

        console.log("--------------------------------");
        console.log("[CTF] WETH restricted actions");
        console.log("\t[CTF] allow WETH receive");
        patterns = new bytes[](2);
        masks = new bytes[](2);
        target = address(WETH_ADDRESS);
        patterns[0] = bytes("");
        masks[0] = bytes("");
        console.log(target);
        console.logBytes(patterns[0]);
        console.logBytes(masks[0]);

        console.log("--------------------------------");
        console.log("\t[CTF] allow WETH withdraw any amount");
        patterns[1] = abi.encodeCall(WETH.withdraw, (0));
        masks[1] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), 0);
        console.log(target);
        console.logBytes(patterns[1]);
        console.logBytes(masks[1]);
        _setRestrictedActions(safe, target, patterns, masks);

        console.log("--------------------------------");
        console.log("[CTF] USDC restricted actions");
        console.log("\t[CTF] allow USDC approve any amount to Size sUSDe/USDC market");
        patterns = new bytes[](1);
        masks = new bytes[](1);
        target = address(USDC_ADDRESS);
        patterns[0] = abi.encodeCall(IERC20.approve, (address(SIZE_SUSDE_USDC_ADDRESS), 0));
        masks[0] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(uint160(type(uint160).max)), 0);
        console.log(target);
        console.logBytes(patterns[0]);
        console.logBytes(masks[0]);
        _setRestrictedActions(safe, target, patterns, masks);

        console.log("--------------------------------");
        console.log("\t[CTF] allow Size.deposit any token, any amount to safe");
        patterns = new bytes[](2);
        masks = new bytes[](2);
        target = address(SIZE_SUSDE_USDC_ADDRESS);
        patterns[0] = abi.encodeCall(ISizeWrong.deposit, (address(0), 0, address(safe)));
        masks[0] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(0), 0, address(uint160(type(uint160).max)));
        console.log(target);
        console.logBytes(patterns[0]);
        console.logBytes(masks[0]);

        console.log("--------------------------------");
        console.log("\t[CTF] allow Size.withdraw any token, any amount to safe");
        patterns[1] = abi.encodeCall(ISizeWrong.withdraw, (address(0), 0, address(safe)));
        masks[1] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(0), 0, address(uint160(type(uint160).max)));
        console.log(target);
        console.logBytes(patterns[1]);
        console.logBytes(masks[1]);
        _setRestrictedActions(safe, target, patterns, masks);

        console.log("[CTF] done");
        vm.stopBroadcast();
    }

    function _setRestrictedActions(Safe safe, address target, bytes[] memory patterns, bytes[] memory masks) public {
        bytes memory data = abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (target, patterns, masks));

        uint256 nonce = safe.nonce();
        bytes32 dataHash = safe.getTransactionHash(
            RESTRICTED_ACTIONS_GUARD_ADDRESS,
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            nonce
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dataHash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        safe.execTransaction(
            RESTRICTED_ACTIONS_GUARD_ADDRESS,
            0,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            signatures
        );
    }
}
