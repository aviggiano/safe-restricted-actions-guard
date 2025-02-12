// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console, Script} from "forge-std/Script.sol";
import {Mainnet} from "@script/addresses/Mainnet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {GuardManager} from "@safe/contracts/base/GuardManager.sol";
import {OwnerManager} from "@safe/contracts/base/OwnerManager.sol";
import {FallbackManager} from "@safe/contracts/base/FallbackManager.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";
import {ISwapRouterV2} from "@script/interfaces/ISwapRouterV2.sol";
import {RestrictedActionsGuardAddressV003} from "@script/addresses/RestrictedActionsGuardAddressV003.sol";
import {AgentathonNetworks} from "@script/agentathon/AgentathonNetworks.s.sol";

contract AgentathonScript is Script, RestrictedActionsGuardAddressV003, AgentathonNetworks {
    function run() public {
        console.log("[Agentathon] running...");
        Safe safe = Safe(payable(vm.envAddress("SAFE_ADDRESS")));

        for (uint256 i = 0; i < networks.length; i++) {
            vm.createSelectFork(networks[i]);
            vm.startBroadcast();

            if (i == 3) {
                vm.txGasPrice(1 gwei);
            }

            assert(safe.getThreshold() == 1);
            console.log("--------------------------------");
            _tokens(safe, i);
            console.log("--------------------------------");
            _swapRouter(safe, i);
            console.log("--------------------------------");
            _setFallbackHandler(safe, address(0));
            console.log("--------------------------------");
            _setGuard(safe, RESTRICTED_ACTIONS_GUARD_ADDRESS, 1);
            console.log("--------------------------------");
            vm.stopBroadcast();
        }

        console.log("[Agentathon] done");
    }

    function _execTransaction(Safe safe, address to, bytes memory data) internal {
        uint256 nonce = safe.nonce();
        bytes32 dataHash =
            safe.getTransactionHash(to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dataHash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        safe.execTransaction(to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures);
    }

    function _setRestrictedActions(Safe safe, address target, bytes[] memory patterns, bytes[] memory masks) internal {
        bytes memory data = abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (target, patterns, masks));
        _execTransaction(safe, RESTRICTED_ACTIONS_GUARD_ADDRESS, data);
    }

    function _setGuard(Safe safe, address guard, uint256 guardThreshold) internal {
        console.log("[Agentathon] setting guard");
        bytes memory data = abi.encodeCall(GuardManager.setGuard, (guard));
        _execTransaction(safe, address(safe), data);
        data = abi.encodeCall(RestrictedActionsGuard.setup, (guardThreshold));
        _execTransaction(safe, address(guard), data);
    }

    function _setFallbackHandler(Safe safe, address fallbackHandler) internal {
        console.log("[Agentathon] setting the fallback handler");
        bytes memory data = abi.encodeCall(FallbackManager.setFallbackHandler, (fallbackHandler));
        _execTransaction(safe, address(safe), data);
    }

    function _tokens(Safe safe, uint256 i) internal {
        address swapRouter = address(swapRouters[i]);
        address[] memory tokensArray = tokens[i];

        console.log("[Agentathon] TOKENS restricted actions");
        console.log("\t[Agentathon] allow TOKEN approve any amount to SWAP_ROUTER_ADDRESS");

        for (uint256 j = 0; j < tokensArray.length; j++) {
            address target = address(tokensArray[j]);

            bytes[] memory patterns = new bytes[](1);
            bytes[] memory masks = new bytes[](1);

            patterns[0] = abi.encodeCall(IERC20.approve, (address(swapRouter), 0));
            masks[0] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(uint160(type(uint160).max)), 0);

            console.log(target);
            console.logBytes(patterns[0]);
            console.logBytes(masks[0]);

            _setRestrictedActions(safe, target, patterns, masks);
        }
    }

    function _swapRouter(Safe safe, uint256 i) internal {
        address swapRouter = address(swapRouters[i]);
        address[] memory tokensArray = tokens[i];

        address target = address(swapRouter);
        bytes[] memory patterns = new bytes[](tokensArray.length * tokensArray.length);
        bytes[] memory masks = new bytes[](tokensArray.length * tokensArray.length);

        console.log("[Agentathon] SWAP_ROUTER restricted actions");
        console.log("\t[Agentathon] allow SWAP_ROUTER exactInputSingle");
        for (uint256 j = 0; j < tokensArray.length; j++) {
            for (uint256 k = 0; k < tokensArray.length; k++) {
                patterns[j * tokensArray.length + k] = abi.encodeCall(
                    ISwapRouterV2.exactInputSingle,
                    (
                        ISwapRouterV2.ExactInputSingleParams({
                            tokenIn: address(tokensArray[j]),
                            tokenOut: address(tokensArray[k]),
                            fee: 0,
                            recipient: address(safe),
                            amountIn: 0,
                            amountOutMinimum: 0,
                            sqrtPriceLimitX96: 0
                        })
                    )
                );
                masks[j * tokensArray.length + k] = abi.encodeWithSelector(
                    bytes4(0xFFFFFFFF),
                    address(uint160(type(uint160).max)),
                    address(uint160(type(uint160).max)),
                    uint24(0),
                    address(uint160(type(uint160).max)),
                    uint256(0),
                    uint256(0),
                    uint160(0)
                );
                console.log(target);
                console.logBytes(patterns[j * tokensArray.length + k]);
                console.logBytes(masks[j * tokensArray.length + k]);
            }
        }
        _setRestrictedActions(safe, target, patterns, masks);
    }
}
