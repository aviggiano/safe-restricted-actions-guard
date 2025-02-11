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

contract AgentathonScript is Script {
    address internal constant RESTRICTED_ACTIONS_GUARD_ADDRESS = 0xa3212332057C479937EA5efE4c92EcE8d3a3100a;
    string[] public networks = ["optimism", "arbitrum", "celo", "linea", "avalanche"];
    address[][] public tokens = [
        [
            0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85, /* USDC */
            0x94b008aA00579c1307B0EF2c499aD98a8ce58e58, /* USDT */
            0x4200000000000000000000000000000000000006 /* WETH */
        ],
        [
            0xaf88d065e77c8cC2239327C5EDb3A432268e5831, /* USDC */
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9, /* USDT */
            0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 /* WETH */
        ],
        [
            0x765DE816845861e75A25fCA122bb6898B8B1282a, /* CUSD */
            0xD8763CBa276a3738E6DE85b4b3bF5FDed6D6cA73, /* CEUR */
            0x471EcE3750Da237f93B8E339c536989b8978a438 /* CELO */
        ],
        [
            0x176211869cA2b568f2A7D4EE941E073a821EE1ff, /* USDCe */
            0xA219439258ca9da29E9Cc4cE5596924745e12B93, /* USDT */
            0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f /* WETH */
        ],
        [
            0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E, /* USDC */
            0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7, /* USDT */
            0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7 /* WAVAX */
        ]
    ];
    address[] public swapRouters = [
        address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45),
        address(0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45),
        address(0x5615CDAb10dc425a742d643d949a7F474C01abc4),
        address(0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a),
        address(0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE)
    ];

    function run() public {
        console.log("[Agentathon] running...");
        Safe safe = Safe(payable(vm.envAddress("SAFE_ADDRESS")));

        for (uint256 i = 0; i < networks.length; i++) {
            vm.createSelectFork(networks[i]);
            vm.startBroadcast();
            console.log("--------------------------------");
            _tokens(safe, i);
            console.log("--------------------------------");
            _swapRouter(safe, i);
            console.log("--------------------------------");
            _setFallbackHandler(safe, address(0));
            console.log("--------------------------------");
            _setGuard(safe, RESTRICTED_ACTIONS_GUARD_ADDRESS, 1);
            console.log("--------------------------------");
            _changeThreshold(safe, 2);
            console.log("--------------------------------");
            vm.stopBroadcast();
            break;
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

    function _changeThreshold(Safe safe, uint256 threshold) internal {
        console.log("[Agentathon] changing threshold");
        bytes memory data = abi.encodeCall(OwnerManager.changeThreshold, (threshold));
        _execTransaction(safe, address(safe), data);

        assert(
            keccak256(
                abi.encodePacked(RestrictedActionsGuard(RESTRICTED_ACTIONS_GUARD_ADDRESS).getDescription(address(safe)))
            ) == keccak256("1/2/3")
        );
    }

    function _tokens(Safe safe, uint256 i) internal {
        address target;
        bytes[] memory patterns;
        bytes[] memory masks;

        console.log("[Agentathon] TOKENS restricted actions");
        console.log("\t[Agentathon] allow TOKEN approve any amount to SWAP_ROUTER_ADDRESS");

        assert(safe.getThreshold() == 1);

        for (uint256 j = 0; j < tokens[i].length; j++) {
            target = address(tokens[i][j]);
            patterns = new bytes[](1);
            masks = new bytes[](1);

            patterns[0] = abi.encodeCall(IERC20.approve, (address(swapRouters[i]), 0));
            masks[0] = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(uint160(type(uint160).max)), 0);

            console.log(target);
            console.logBytes(patterns[0]);
            console.logBytes(masks[0]);

            _setRestrictedActions(safe, target, patterns, masks);
        }
    }

    function _swapRouter(Safe safe, uint256 i) internal {
        address target = address(swapRouters[i]);
        bytes[] memory patterns;
        bytes[] memory masks;

        console.log("[Agentathon] SWAP_ROUTER restricted actions");
        console.log("\t[Agentathon] allow SWAP_ROUTER exactInputSingle");
        for (uint256 j = 0; j < tokens[i].length; j++) {
            patterns = new bytes[](tokens[i].length);
            masks = new bytes[](tokens[i].length);
            patterns[j] = abi.encodeCall(
                ISwapRouterV2.exactInputSingle,
                (
                    ISwapRouterV2.ExactInputSingleParams({
                        tokenIn: address(tokens[i][j]),
                        tokenOut: address(0),
                        fee: 0,
                        recipient: address(safe),
                        amountIn: 0,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                )
            );
            masks[j] = abi.encodeWithSelector(
                bytes4(0xFFFFFFFF),
                address(uint160(type(uint160).max)),
                address(0),
                uint24(0),
                address(uint160(type(uint160).max)),
                uint256(0),
                uint256(0),
                uint160(0)
            );
            console.log(target);
            console.logBytes(patterns[j]);
            console.logBytes(masks[j]);
            _setRestrictedActions(safe, target, patterns, masks);
        }
    }
}
