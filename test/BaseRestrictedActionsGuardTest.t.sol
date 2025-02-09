// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseTest} from "@test/BaseTest.t.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {RestrictedActionsGuard} from "@src/RestrictedActionsGuard.sol";
import {WETH} from "@solady/src/tokens/WETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626Mock} from "@openzeppelin/contracts/mocks/token/ERC4626Mock.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract BaseRestrictedActionsGuardTest is BaseTest {
    RestrictedActionsGuard public restrictedActionsGuard;
    address public owner1;
    address public owner2;
    address public owner3;
    address public owner4;
    address public owner5;
    address public unauthorized;
    WETH public weth;
    ERC4626Mock public wethVault;

    function setUp() public virtual override {
        super.setUp();
        restrictedActionsGuard = new RestrictedActionsGuard();

        owner1 = _makeAddrAndSaveKey("owner1");
        owner2 = _makeAddrAndSaveKey("owner2");
        owner3 = _makeAddrAndSaveKey("owner3");
        owner4 = _makeAddrAndSaveKey("owner4");
        owner5 = _makeAddrAndSaveKey("owner5");
        unauthorized = _makeAddrAndSaveKey("unauthorized");
        weth = new WETH();
        wethVault = new ERC4626Mock(address(weth));

        vm.label(address(weth), "WETH");
        vm.label(address(wethVault), "WETHVault");
        vm.label(address(restrictedActionsGuard), "RestrictedActionsGuard");
    }

    function _setRestrictedActions(Safe safe, address target, bytes[] memory datas, bytes[] memory masks) internal {
        address[] memory signers = safe.getOwners();
        _execTransaction(
            safe,
            address(restrictedActionsGuard),
            abi.encodeCall(RestrictedActionsGuard.setRestrictedActions, (target, datas, masks)),
            signers
        );
    }

    function _setRestrictedActions(Safe safe, address target, bytes memory pattern, bytes memory mask) internal {
        bytes[] memory patterns = new bytes[](1);
        patterns[0] = pattern;
        bytes[] memory masks = new bytes[](1);
        masks[0] = mask;
        _setRestrictedActions(safe, target, patterns, masks);
    }

    function _setRestrictedActions(
        Safe safe,
        address target,
        bytes memory pattern1,
        bytes memory mask1,
        bytes memory pattern2,
        bytes memory mask2
    ) internal {
        bytes[] memory patterns = new bytes[](2);
        patterns[0] = pattern1;
        patterns[1] = pattern2;
        bytes[] memory masks = new bytes[](2);
        masks[0] = mask1;
        masks[1] = mask2;
        _setRestrictedActions(safe, target, patterns, masks);
    }

    function _getRestrictedActionErc20ApproveSpenderAnyAmount(address spender)
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = abi.encodeCall(IERC20.approve, (spender, type(uint256).max));
        mask = abi.encodeWithSelector(bytes4(0xFFFFFFFF), address(uint160(type(uint160).max)), 0);
    }

    function _getRestrictedActionWethReceiveAnyAmount()
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = bytes("");
        mask = bytes("");
    }

    function _getRestrictedActionWethDepositAnyAmount()
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = abi.encodeCall(WETH.deposit, ());
        mask = abi.encodeWithSelector(bytes4(0xFFFFFFFF));
    }

    function _getRestrictedActionWethWithdrawAnyAmount()
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = abi.encodeCall(WETH.withdraw, (type(uint256).max));
        mask = abi.encodeWithSelector(bytes4(0xFFFFFFFF), 0);
    }

    function _getRestrictedActionDepositVaultToSelfAnyAmount(Safe safe)
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = abi.encodeCall(ERC4626.deposit, (type(uint256).max, address(safe)));
        mask = abi.encodeWithSelector(bytes4(0xFFFFFFFF), 0, address(uint160(type(uint160).max)));
    }

    function _getRestrictedActionWithdrawVaultToSelfAnyAmount(Safe safe)
        internal
        pure
        returns (bytes memory pattern, bytes memory mask)
    {
        pattern = abi.encodeCall(ERC4626.withdraw, (type(uint256).max, address(safe), address(safe)));
        mask = abi.encodeWithSelector(
            bytes4(0xFFFFFFFF), 0, address(uint160(type(uint160).max)), address(uint160(type(uint160).max))
        );
    }
}
