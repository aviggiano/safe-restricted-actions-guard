// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console, Script} from "forge-std/Script.sol";
import {ICreate2Deployer} from "@script/interfaces/ICreate2Deployer.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";

contract DeployScript is Script {
    ICreate2Deployer create2Deployer = ICreate2Deployer(0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2);

    function run() public {
        vm.startBroadcast();
        console.log("[RestrictedActionsGuard] deploying...");

        create2Deployer.deploy(0, bytes32(0), type(RestrictedActionsGuard).creationCode);
        console.log("[RestrictedActionsGuard] done");

        vm.stopBroadcast();
    }
}
