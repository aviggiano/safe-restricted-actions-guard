// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "@test/BaseTest.t.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {GuardManager} from "@safe/contracts/base/GuardManager.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {ERC20Mock} from "@solady/ext/wake/ERC20Mock.sol";
import {WETH} from "@solady/src/tokens/WETH.sol";
import {BaseRestrictedActionsGuardTest} from "@test/BaseRestrictedActionsGuardTest.t.sol";

contract RestrictedActionsGuard_1_3_5_Test is BaseRestrictedActionsGuardTest {
    function setUp() public override {
        super.setUp();
        vm.label(address(this), "RestrictedActionsGuard_1_3_5_Test");
    }

    function test_RestrictedActionsGuard_1_3_5_setup() public returns (Safe safe) {
        address[] memory owners = new address[](5);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        owners[3] = owner4;
        owners[4] = owner5;
        address[] memory signers = new address[](5);
        signers[0] = owner1;
        signers[1] = owner2;
        signers[2] = owner3;
        signers[3] = owner4;
        signers[4] = owner5;

        safe = _deploySafe(owners, 1);
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        _execTransaction(
            safe, address(restrictedActionsGuard), abi.encodeCall(RestrictedActionsGuard.setup, (3)), signers
        );
        assertEq(restrictedActionsGuard.getDescription(address(safe)), "1/3/5");
    }

    function test_RestrictedActionsGuard_1_3_5_setGuardThreshold() public {
        Safe safe = test_RestrictedActionsGuard_1_3_5_setup();

        address[] memory signers = safe.getOwners();
        _execTransaction(
            safe,
            address(restrictedActionsGuard),
            abi.encodeCall(RestrictedActionsGuard.setGuardThreshold, (2)),
            signers
        );
        assertEq(restrictedActionsGuard.getDescription(address(safe)), "1/2/5");
    }

    function test_RestrictedActionsGuard_1_3_5_removeRestrictedAllowedTarget() public {
        Safe safe = test_RestrictedActionsGuard_1_3_5_setup();

        (bytes memory pattern, bytes memory mask) = _getRestrictedActionWethDepositAnyAmount();
        _setRestrictedActions(safe, address(weth), pattern, mask);

        deal(address(safe), 1 ether);

        assertEq(weth.balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        _execTransaction(safe, address(weth), 1 ether, abi.encodeCall(weth.deposit, ()), signers);

        assertEq(weth.balanceOf(address(safe)), 1 ether);
        assertEq(address(safe).balance, 0);

        signers = new address[](3);
        signers[0] = owner1;
        signers[1] = owner3;
        signers[2] = owner5;

        _execTransaction(
            safe,
            address(restrictedActionsGuard),
            abi.encodeCall(RestrictedActionsGuard.removeRestrictedActions, (address(weth))),
            signers
        );

        signers = new address[](1);
        signers[0] = owner1;

        deal(address(safe), 1 ether);

        bytes memory data = abi.encodeCall(weth.deposit, ());
        bytes32 dataHash = _getDataHash(safe, address(weth), 1 ether, data);
        vm.expectRevert(
            abi.encodeWithSelector(RestrictedActionsGuard.ActionNotAllowed.selector, address(safe), address(weth), data)
        );
        _execTransaction(safe, address(weth), 1 ether, data, signers, dataHash);
    }

    function test_RestrictedOwnersGuard_1_3_2_checkGuardThreshold() public {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        address[] memory signers = new address[](1);
        signers[0] = owner1;

        Safe safe = _deploySafe(owners, 1);
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        bytes memory data = abi.encodeCall(RestrictedActionsGuard.setup, (3));
        bytes32 dataHash = _getDataHash(safe, address(restrictedActionsGuard), data);
        vm.expectRevert("GS013");
        _execTransaction(safe, address(restrictedActionsGuard), data, signers, dataHash);
    }

    function test_RestrictedOwnersGuard_4_3_5_checkGuardThreshold() public {
        address[] memory owners = new address[](5);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        owners[3] = owner4;
        owners[4] = owner5;
        address[] memory signers = new address[](4);
        signers[0] = owner1;
        signers[1] = owner2;
        signers[2] = owner3;
        signers[3] = owner4;

        Safe safe = _deploySafe(owners, 4);
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        bytes memory data = abi.encodeCall(RestrictedActionsGuard.setup, (3));
        bytes32 dataHash = _getDataHash(safe, address(restrictedActionsGuard), data);
        vm.expectRevert("GS013");
        _execTransaction(safe, address(restrictedActionsGuard), data, signers, dataHash);
    }

    function test_RestrictedOwnersGuard_1_3_5_patterns_masks_same_length_1_signer() public {
        Safe safe = test_RestrictedActionsGuard_1_3_5_setup();
        (bytes memory pattern, bytes memory mask) = _getRestrictedActionWethDepositAnyAmount();
        (bytes memory pattern2,) = _getRestrictedActionErc20ApproveSpenderAnyAmount(address(wethVault));
        bytes[] memory patterns = new bytes[](2);
        bytes[] memory masks = new bytes[](1);
        patterns[0] = pattern;
        patterns[1] = pattern2;
        masks[0] = mask;
        address[] memory signers = new address[](1);
        signers[0] = owner1;
        bytes memory data =
            abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (address(weth), patterns, masks));
        bytes32 dataHash = _getDataHash(safe, address(restrictedActionsGuard), data);
        vm.expectRevert(
            abi.encodeWithSelector(
                RestrictedActionsGuard.ActionNotAllowed.selector, address(safe), address(restrictedActionsGuard), data
            )
        );
        _execTransaction(safe, address(restrictedActionsGuard), data, signers, dataHash);
    }

    function test_RestrictedOwnersGuard_1_3_5_patterns_masks_same_length_all_signers() public {
        Safe safe = test_RestrictedActionsGuard_1_3_5_setup();
        (bytes memory pattern, bytes memory mask) = _getRestrictedActionWethDepositAnyAmount();
        (bytes memory pattern2,) = _getRestrictedActionErc20ApproveSpenderAnyAmount(address(wethVault));
        bytes[] memory patterns = new bytes[](2);
        bytes[] memory masks = new bytes[](1);
        patterns[0] = pattern;
        patterns[1] = pattern2;
        masks[0] = mask;
        address[] memory signers = safe.getOwners();
        bytes memory data =
            abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (address(weth), patterns, masks));
        bytes32 dataHash = _getDataHash(safe, address(restrictedActionsGuard), data);
        vm.expectRevert("GS013");
        _execTransaction(safe, address(restrictedActionsGuard), data, signers, dataHash);
    }

    function test_RestrictedOwnersGuard_1_3_5_pattern_mask_same_length() public {
        Safe safe = test_RestrictedActionsGuard_1_3_5_setup();
        (bytes memory pattern,) = _getRestrictedActionWethDepositAnyAmount();
        bytes[] memory patterns = new bytes[](1);
        patterns[0] = pattern;
        bytes[] memory masks = new bytes[](1);
        masks[0] = bytes("");
        address[] memory signers = safe.getOwners();
        bytes memory data =
            abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (address(weth), patterns, masks));
        bytes32 dataHash = _getDataHash(safe, address(restrictedActionsGuard), data);
        vm.expectRevert("GS013");
        _execTransaction(safe, address(restrictedActionsGuard), data, signers, dataHash);
    }
}
