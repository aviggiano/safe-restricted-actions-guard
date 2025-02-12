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

contract SetGuardThresholdScript is Script, RestrictedActionsGuardAddressV003, AgentathonNetworks {
    function run() public {
        for (uint256 i = 0; i < networks.length; i++) {
            vm.createSelectFork(networks[i]);
            vm.startBroadcast();

            console.log("[SetGuardThreshold] running...");
            Safe safe = Safe(payable(vm.envAddress("SAFE_ADDRESS")));

            if (i == 3) {
                vm.txGasPrice(1 gwei);
            }

            _setGuardThreshold(safe, 2);

            console.log("[SetGuardThreshold] done");
            vm.stopBroadcast();
        }
    }

    function _execTransaction(Safe safe, address to, bytes memory data) internal {
        uint256 nonce = safe.nonce();
        bytes32 dataHash =
            safe.getTransactionHash(to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonce);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(dataHash);
        bytes memory signatures = abi.encodePacked(r, s, v);

        safe.execTransaction(to, 0, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), signatures);
    }

    function _setGuardThreshold(Safe safe, uint256 threshold) internal {
        console.log("[SetGuardThreshold] setting guard threshold");
        bytes memory data = abi.encodeCall(RestrictedActionsGuard.setGuardThreshold, (threshold));
        _execTransaction(safe, address(RESTRICTED_ACTIONS_GUARD_ADDRESS), data);

        string memory description =
            RestrictedActionsGuard(RESTRICTED_ACTIONS_GUARD_ADDRESS).getDescription(address(safe));
        console.log("[SetGuardThreshold] description", description);

        assert(keccak256(abi.encodePacked(description)) == keccak256("1/2/3"));
    }
}
