// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseRestrictedActionsGuardTest} from "@test/BaseRestrictedActionsGuardTest.t.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {GuardManager} from "@safe/contracts/base/GuardManager.sol";
import {OwnerManager} from "@safe/contracts/base/OwnerManager.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {ERC20Mock} from "@solady/ext/wake/ERC20Mock.sol";
import {WETH} from "@solady/src/tokens/WETH.sol";

contract RestrictedActionsGuard_1_2_3_Test is BaseRestrictedActionsGuardTest {
    function setUp() public override {
        super.setUp();
        vm.label(address(this), "RestrictedActionsGuard_1_2_3_Test");
    }

    function test_RestrictedActionsGuard_1_2_3_setup() public returns (Safe safe) {
        address[] memory owners = new address[](3);
        owners[0] = owner1;
        owners[1] = owner2;
        owners[2] = owner3;
        address[] memory signers = new address[](2);
        signers[0] = owner1;
        signers[1] = owner2;

        safe = _deploySafe(owners, 2);
        _execTransaction(
            safe, address(safe), abi.encodeCall(GuardManager.setGuard, (address(restrictedActionsGuard))), signers
        );
        _execTransaction(
            safe, address(restrictedActionsGuard), abi.encodeCall(RestrictedActionsGuard.setup, (2)), signers
        );
        _execTransaction(safe, address(safe), abi.encodeCall(OwnerManager.changeThreshold, (1)), signers);
        assertEq(restrictedActionsGuard.getDescription(address(safe)), "1/2/3");
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_2_signatures_unrestricted() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

        ERC20Mock token = new ERC20Mock("Test", "TEST", 18);
        token.mint(address(safe), 1e18);

        address[] memory signers = new address[](2);
        signers[0] = owner1;
        signers[1] = owner2;

        assertEq(token.balanceOf(address(safe)), 1e18);
        assertEq(token.balanceOf(owner1), 0);
        assertEq(token.balanceOf(owner2), 0);

        _execTransaction(safe, address(token), abi.encodeCall(token.transfer, (owner1, 1e18)), signers);

        assertEq(token.balanceOf(address(safe)), 0);
        assertEq(token.balanceOf(owner1), 1e18);
        assertEq(token.balanceOf(owner2), 0);
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_1_signature_unauthorized() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

        ERC20Mock token = new ERC20Mock("Test", "TEST", 18);
        token.mint(address(safe), 1e18);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        bytes memory data = abi.encodeCall(token.transfer, (owner1, 1e18));
        bytes32 dataHash = _getDataHash(safe, address(token), data);
        vm.expectRevert(
            abi.encodeWithSelector(
                RestrictedActionsGuard.ActionNotAllowed.selector, address(safe), address(token), data
            )
        );
        _execTransaction(safe, address(token), data, signers, dataHash);
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_1_signature_restricted_weth_deposit() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

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
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_1_signature_restricted_weth_receive() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

        (bytes memory pattern, bytes memory mask) = _getRestrictedActionWethReceiveAnyAmount();
        _setRestrictedActions(safe, address(weth), pattern, mask);

        deal(address(safe), 1 ether);

        assertEq(weth.balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        _execTransaction(safe, address(weth), 1 ether, "", signers);

        assertEq(weth.balanceOf(address(safe)), 1 ether);
        assertEq(address(safe).balance, 0);

        bytes memory data = abi.encodeCall(weth.withdraw, (1 ether));
        bytes32 dataHash = _getDataHash(safe, address(weth), data);
        vm.expectRevert(
            abi.encodeWithSelector(RestrictedActionsGuard.ActionNotAllowed.selector, address(safe), address(weth), data)
        );
        _execTransaction(safe, address(weth), data, signers, dataHash);

        signers = new address[](2);
        signers[0] = owner1;
        signers[1] = owner2;

        _execTransaction(safe, address(weth), data, signers, dataHash);
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_1_signature_restricted_weth_deposit_withdraw() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

        (bytes memory pattern1, bytes memory mask1) = _getRestrictedActionWethDepositAnyAmount();
        (bytes memory pattern2, bytes memory mask2) = _getRestrictedActionWethWithdrawAnyAmount();
        _setRestrictedActions(safe, address(weth), pattern1, mask1, pattern2, mask2);

        deal(address(safe), 1 ether);

        assertEq(weth.balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        _execTransaction(safe, address(weth), 1 ether, abi.encodeCall(weth.deposit, ()), signers);

        assertEq(weth.balanceOf(address(safe)), 1 ether);
        assertEq(address(safe).balance, 0);

        _execTransaction(safe, address(weth), abi.encodeCall(weth.withdraw, (1 ether)), signers);

        assertEq(weth.balanceOf(address(safe)), 0);
        assertEq(address(safe).balance, 1 ether);
    }

    function test_RestrictedActionsGuard_1_2_3_checkTransaction_deposit_vault_invalid_recipient() public {
        Safe safe = test_RestrictedActionsGuard_1_2_3_setup();

        deal(address(safe), 1 ether);

        address[] memory signers = new address[](1);
        signers[0] = owner1;

        (bytes memory pattern1, bytes memory mask1) = _getRestrictedActionWethDepositAnyAmount();
        (bytes memory pattern2, bytes memory mask2) =
            _getRestrictedActionErc20ApproveSpenderAnyAmount(address(wethVault));
        _setRestrictedActions(safe, address(weth), pattern1, mask1, pattern2, mask2);
        _execTransaction(safe, address(weth), 1 ether, abi.encodeCall(weth.deposit, ()), signers);
        _execTransaction(safe, address(weth), abi.encodeCall(weth.approve, (address(wethVault), 1 ether)), signers);

        (bytes memory pattern3, bytes memory mask3) = _getRestrictedActionDepositVaultToSelfAnyAmount(safe);
        _setRestrictedActions(safe, address(wethVault), pattern3, mask3);

        bytes memory data = abi.encodeCall(wethVault.deposit, (1 ether, owner1));
        bytes32 dataHash = _getDataHash(safe, address(wethVault), data);
        vm.expectRevert(
            abi.encodeWithSelector(
                RestrictedActionsGuard.ActionNotAllowed.selector, address(safe), address(wethVault), data
            )
        );
        _execTransaction(safe, address(wethVault), data, signers, dataHash);

        data = abi.encodeCall(wethVault.deposit, (1 ether, address(safe)));
        dataHash = _getDataHash(safe, address(wethVault), data);
        _execTransaction(safe, address(wethVault), data, signers, dataHash);
    }
}
