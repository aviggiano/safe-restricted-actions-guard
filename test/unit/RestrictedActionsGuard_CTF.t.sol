// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRestrictedActionsGuardTest} from "@test/BaseRestrictedActionsGuardTest.t.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {ERC20Mock} from "@solady/ext/wake/ERC20Mock.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";
import {GuardManager} from "@safe/contracts/base/GuardManager.sol";

contract RestrictedActionsGuard_CTF_Test is BaseRestrictedActionsGuardTest {
    Signature s1;

    function setUp() public override {
        super.setUp();
        vm.label(address(this), "RestrictedActionsGuard_CTF_Test");
    }

    function test_RestrictedActionsGuard_CTF_setup() public returns (Safe safe) {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = unauthorized;
        safe = _deploySafe(owners, 1);
        address[] memory signers = new address[](2);
        signers[0] = owner1;
        signers[1] = owner2;
        _execTransaction(
            safe, address(restrictedActionsGuard), abi.encodeCall(RestrictedActionsGuard.setup, (2)), signers
        );
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        assertEq(restrictedActionsGuard.getDescription(address(safe)), "1/2/3");
    }

    function test_RestrictedActionsGuard_CTF_hack() public {
        Safe safe = test_RestrictedActionsGuard_CTF_setup();
        address[] memory signers = new address[](2);
        signers[0] = owner1;
        signers[1] = owner2;

        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );

        (bytes memory pattern1, bytes memory mask1) = _getRestrictedActionWethReceiveAnyAmount();
        (bytes memory pattern2, bytes memory mask2) = _getRestrictedActionWethWithdrawAnyAmount();
        _setRestrictedActions(safe, address(weth), pattern1, mask1, pattern2, mask2);

        deal(address(safe), 1 ether);

        assertEq(weth.balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether);

        signers = new address[](1);
        signers[0] = unauthorized;

        assertEq(address(safe).balance, 1e18);
        assertEq(weth.balanceOf(unauthorized), 0);

        uint256 nonce = safe.nonce();
        bytes32 dataHash = safe.getTransactionHash(
            address(weth),
            1 ether,
            bytes(""),
            Enum.Operation.Call,
            200000,
            50000,
            4000000000000,
            address(weth),
            address(unauthorized),
            nonce
        );

        (s1.v, s1.r, s1.s) = vm.sign(privateKeys[unauthorized], dataHash);

        vm.prank(unauthorized);
        try safe.execTransaction(
            address(weth),
            1 ether,
            bytes(""),
            Enum.Operation.Call,
            200000,
            50000,
            4000000000000,
            address(weth),
            payable(address(unauthorized)),
            _encode(s1)
        ) {
            assertEq(weth.balanceOf(address(safe)), 0.594368 ether);
            assertEq(weth.balanceOf(unauthorized), 0.405632 ether);
        } catch (bytes memory reason) {
            assertEq(bytes4(reason), bytes4(RestrictedActionsGuard.RefundParamsNotAllowed.selector));
        }
    }
}
