// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRestrictedActionsGuardTest} from "@test/BaseRestrictedActionsGuardTest.t.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {ERC20Mock} from "@solady/ext/wake/ERC20Mock.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {GuardManager} from "@safe/contracts/base/GuardManager.sol";

contract RestrictedActionsGuard_1_1_2_Test is BaseRestrictedActionsGuardTest {
    function setUp() public override {
        super.setUp();
        vm.label(address(this), "RestrictedActionsGuard_1_1_2_Test");
    }

    function test_RestrictedActionsGuard_1_1_2_setup() public returns (Safe safe) {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        safe = _deploySafe(owners, 1);
        address[] memory signers = new address[](1);
        signers[0] = owner1;
        _execTransaction(
            safe, address(restrictedActionsGuard), abi.encodeCall(RestrictedActionsGuard.setup, (1)), signers
        );
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        assertEq(restrictedActionsGuard.getDescription(address(safe)), "1/1/2");
    }

    function test_RestrictedActionsGuard_1_1_2_checkTransaction_1_signature_unrestricted() public {
        Safe safe = test_RestrictedActionsGuard_1_1_2_setup();

        ERC20Mock token = new ERC20Mock("Test", "TEST", 18);
        token.mint(address(safe), 1e18);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        assertEq(token.balanceOf(address(safe)), 1e18);
        assertEq(token.balanceOf(owner1), 0);

        _execTransaction(safe, address(token), abi.encodeCall(token.transfer, (owner1, 1e18)), signers);

        assertEq(token.balanceOf(address(safe)), 0);
        assertEq(token.balanceOf(owner1), 1e18);
    }

    function test_RestrictedActionsGuard_1_1_2_checkTransaction_unauthorized() public {
        Safe safe = test_RestrictedActionsGuard_1_1_2_setup();

        ERC20Mock token = new ERC20Mock("Test", "TEST", 18);
        token.mint(address(safe), 1e18);

        address[] memory signers = new address[](1);
        signers[0] = unauthorized;

        bytes memory data = abi.encodeCall(token.transfer, (unauthorized, 1e18));
        bytes32 dataHash = _getDataHash(safe, address(token), data);
        vm.expectRevert("GS026");
        _execTransaction(safe, address(token), data, signers, dataHash);
    }
}
