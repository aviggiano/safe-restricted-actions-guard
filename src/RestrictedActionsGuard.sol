// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseGuard, Guard} from "@safe/contracts/base/GuardManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {ExtendedSignatureDecoder} from "@src/ExtendedSignatureDecoder.sol";

/// @title RestrictedActionsGuard
/// @author Antonio Viggiano (@aviggiano)
/// @notice This guard is used to restrict actions that can be performed by the owners of a Safe with less signatures than the threshold.
/// @notice Upon setup, the guard threshold is set.
/// @notice The guard threshold must be at least the Safe threshold, and at most the number of owners,
///         and is intended to replace the threshold of an usual Safe.
///         For example, a 3/5 Safe (threshold/owners) can be set up as 2/3/5 (threshold/guardThreshold/owners),
///         where signers can perform restricted actions with less signatures than the guardThreshold, such as:
///         - Propose actions to a TimeLock but not execute them
///         - Deposit funds to a vault but not withdraw them
///         - Deposit and withdraw funds to a vault, but only if funds are sent to the Safe account
/// @dev All functions are intended to be executed by the Safe contract, and can reenter to fetch relevant information.
/// @dev To setup this guard, after the Safe setup, call
///      - `RestrictedActionsGuard.setup` through `Safe.execTransaction`
///      - `Safe.setGuard` through `Safe.execTransaction`
///      - If necessary, `Safe.changeThreshold` to reduce the threshold, so that the owners can execute restricted actions independently
/// @dev Each pattern+mask pair can be used to match the calldata with required or optional bytes
///      Example usage:
///        pattern = 0x12345678abcd...
///        mask    = 0xffffffff0000...
///      This means for each byte:
///        - `mask` is non-zero => require exact match of `data` to `pattern`
///        - `mask` is 0x00     => wildcard (allow any byte)
/// @dev Invariants:
///      - threshold <= guardThreshold <= ownersCount
///      - safe.executeTransaction is successful if signers.length >= guardThreshold OR calldata is valid wrt target/pattern/match
contract RestrictedActionsGuard is BaseGuard, ExtendedSignatureDecoder {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address _safe => uint256 _guardThreshold) public guardThreshold;
    mapping(address _safe => mapping(address _to => bytes[] _patterns)) public patterns;
    mapping(address _safe => mapping(address _to => bytes[] _masks)) public masks;

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/

    event GuardThresholdSet(
        address indexed _safe, uint256 indexed _oldGuardThreshold, uint256 indexed _newGuardThreshold
    );
    event RestrictedActionsSet(address indexed _safe, address indexed _to, bytes[] _patterns, bytes[] _masks);

    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error GuardThresholdMustBeAtLeastSafeThreshold(address _safe, uint256 _guardThreshold, uint256 _safeThreshold);
    error GuardThresholdMustBeAtMostSafeOwnersCount(address _safe, uint256 _guardThreshold, uint256 _safeOwnersCount);
    error PatternsAndMasksMustHaveSameLength(address _safe, address _to, uint256 _patternsLength, uint256 _masksLength);
    error PatternAndMaskMustHaveSameLength(address _safe, address _to, uint256 _patternLength, uint256 _maskLength);
    error ActionNotAllowed(address _safe, address _to, bytes _data);
    error RefundParamsNotAllowed(address _safe, address _to, bytes _data);

    /*//////////////////////////////////////////////////////////////
                            METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Setup the guard
    /// @dev This function is intended to be called by the Safe contract
    /// @param _guardThreshold the guard threshold to set
    function setup(uint256 _guardThreshold) external {
        _setGuardThreshold(_guardThreshold);
    }

    /// @notice Set the guard threshold
    /// @param _guardThreshold the guard threshold to set
    function setGuardThreshold(uint256 _guardThreshold) external {
        _setGuardThreshold(_guardThreshold);
    }

    /// @notice Get the guard description
    /// @param _safe the safe address
    /// @return the guard description as a string, in the format "threshold/guardThreshold/ownersCount"
    function getDescription(address _safe) external view returns (string memory) {
        return string.concat(
            Strings.toString(Safe(payable(_safe)).getThreshold()),
            "/",
            Strings.toString(guardThreshold[_safe]),
            "/",
            Strings.toString(Safe(payable(_safe)).getOwners().length)
        );
    }

    /// @notice Set the restricted action (target and calldata pattern+mask)
    /// @dev To enable the `fallback`, it suffices to pass `_pattern` and `_mask` as empty bytes
    /// @param _to the target address
    /// @param _patterns the patterns to set
    /// @param _masks the masks to set
    function setRestrictedActions(address _to, bytes[] memory _patterns, bytes[] memory _masks) external {
        _setRestrictedActions(_to, _patterns, _masks);
    }

    /// @notice Remove all restricted actions from a target
    /// @param _to the target address
    function removeRestrictedActions(address _to) external {
        _setRestrictedActions(_to, new bytes[](0), new bytes[](0));
    }

    /// @inheritdoc Guard
    /// @notice This function is called after `checkSignatures` during `Safe.execTransaction`,
    ///         so we are sure that the transaction is signed by at least the Safe threshold number of owners
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address /* executor */
    ) external view override {
        // code from `DebugTransactionGuard.sol`
        Safe safe = Safe(payable(msg.sender));
        uint256 nonce = safe.nonce();
        bytes32 txHash = safe.getTransactionHash(
            to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, nonce - 1
        );
        uint256 signersCount = _getSignersCount(txHash, data, signatures);

        if (signersCount >= guardThreshold[msg.sender]) {
            // there are at least guardThreshold signers, so the transaction is allowed
            return;
        } else if (_matchesPatternsMasks(to, data)) {
            if (
                safeTxGas != 0 || baseGas != 0 || gasPrice != 0 || gasToken != address(0)
                    || refundReceiver != address(0)
            ) {
                revert RefundParamsNotAllowed(msg.sender, to, data);
            } else {
                // data matches pattern+mask
                return;
            }
        } else {
            // action is not allowed
            revert ActionNotAllowed(msg.sender, to, data);
        }
    }

    /// @notice Check if the data matches any of the patterns+masks
    /// @param _to the target address
    /// @param _data the data to check
    /// @return true if the data matches any of the patterns+masks, false otherwise
    function _matchesPatternsMasks(address _to, bytes memory _data) private view returns (bool) {
        bytes[] memory _patterns;
        bytes[] memory _masks;

        if (_to == address(this)) {
            (_patterns, _masks) = _checkPatternsMasksLengths(_to);
        } else {
            _patterns = patterns[msg.sender][_to];
            _masks = masks[msg.sender][_to];
        }
        for (uint256 i = 0; i < _patterns.length; i++) {
            bytes memory pattern = _patterns[i];
            bytes memory mask = _masks[i];

            if (pattern.length != _data.length) {
                continue;
            }

            bool matches = true;
            for (uint256 j = 0; j < _data.length; j++) {
                // if mask[j] is 0x00, it's a wildcard - allow any value
                // if mask[j] is non-zero, require exact match with pattern[j]
                if (mask[j] != 0x00 && _data[j] != pattern[j]) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                return true;
            }
        }
        return false;
    }

    /// @inheritdoc Guard
    /// @notice If the Safe threshold or owners list are updated, the guard must be updated accordingly, to keep the state consistent.
    ///         Failure to do so will result in the Safe not being able to execute transactions. For example:
    ///         - Changing the threshold:
    ///           - If the Safe is configured as 2/3/5 and updated to 1/3/5, it is ok
    ///           - If the Safe is configured as 2/3/5 and updated to 3/3/5, it is ok
    ///           - If the Safe is configured as 2/3/5 and updated to 4/3/5, the Safe may become unusable, since guardThreshold < threshold
    ///           - If the Safe is configured as 2/3/5 and updated to 5/3/5, the Safe may become unusable, since guardThreshold < threshold
    ///           - If the Safe is configured as 2/3/5 and updated to 6/3/5, it reverts in `OwnerManager.changeThreshold`
    ///         - Changing the guardThreshold:
    ///             - If the Safe is configured as 2/3/5 and updated to 2/1/5, the Safe may become unusable, since guardThreshold < threshold
    ///             - If the Safe is configured as 2/3/5 and updated to 2/2/5, it is ok
    ///             - If the Safe is configured as 2/3/5 and updated to 2/4/5, it is ok
    ///             - If the Safe is configured as 2/3/5 and updated to 2/5/5, it is ok
    ///             - If the Safe is configured as 2/3/5 and updated to 2/6/5, the Safe may become unusable, since owners < guardThreshold
    ///         - Changing the owners:
    ///             - If the Safe is configured as 2/3/5 and updated to 2/3/1, the Safe may become unusable, since owners < guardThreshold
    ///             - If the Safe is configured as 2/3/5 and updated to 2/3/2, the Safe may become unusable, since owners < guardThreshold
    ///             - If the Safe is configured as 2/3/5 and updated to 2/3/3, it is ok
    ///             - If the Safe is configured as 2/3/5 and updated to 2/3/4, it is ok
    ///             - If the Safe is configured as 2/3/5 and updated to 2/3/6, it is ok
    function checkAfterExecution(bytes32, /*txHash*/ bool success) external view override {
        if (!success) {
            return;
        }

        _checkGuardThreshold();
    }

    /// @notice Set the guard threshold
    /// @param _guardThreshold the guard threshold to set
    function _setGuardThreshold(uint256 _guardThreshold) private {
        uint256 oldGuardThreshold = guardThreshold[msg.sender];
        guardThreshold[msg.sender] = _guardThreshold;
        emit GuardThresholdSet(msg.sender, oldGuardThreshold, _guardThreshold);

        _checkGuardThreshold();
    }

    /// @notice Set the restricted actions
    /// @param _to the target address
    /// @param _patterns the patterns to set
    /// @param _masks the masks to set
    function _setRestrictedActions(address _to, bytes[] memory _patterns, bytes[] memory _masks) private {
        patterns[msg.sender][_to] = _patterns;
        masks[msg.sender][_to] = _masks;

        // slither-disable-next-line unused-return
        _checkPatternsMasksLengths(_to);

        emit RestrictedActionsSet(msg.sender, _to, _patterns, _masks);
    }

    /// @notice Check if the patterns and masks have the same length, and if each pattern and mask have the same length
    /// @param to the target address
    /// @return _patterns the patterns
    /// @return _masks the masks
    function _checkPatternsMasksLengths(address to)
        private
        view
        returns (bytes[] memory _patterns, bytes[] memory _masks)
    {
        _patterns = patterns[msg.sender][to];
        _masks = masks[msg.sender][to];
        if (_patterns.length != _masks.length) {
            revert PatternsAndMasksMustHaveSameLength(msg.sender, to, _patterns.length, _masks.length);
        }
        for (uint256 i = 0; i < _patterns.length; i++) {
            if (_patterns[i].length != _masks[i].length) {
                revert PatternAndMaskMustHaveSameLength(msg.sender, to, _patterns[i].length, _masks[i].length);
            }
        }
    }

    /// @notice Check if the guard threshold is valid (is at least the Safe threshold and at most the number of owners)
    function _checkGuardThreshold() private view {
        uint256 safeThreshold = Safe(payable(msg.sender)).getThreshold();
        uint256 thisGuardThreshold = guardThreshold[msg.sender];
        if (thisGuardThreshold < safeThreshold) {
            revert GuardThresholdMustBeAtLeastSafeThreshold(msg.sender, thisGuardThreshold, safeThreshold);
        }
        uint256 safeOwnersCount = Safe(payable(msg.sender)).getOwners().length;
        if (thisGuardThreshold > safeOwnersCount) {
            revert GuardThresholdMustBeAtMostSafeOwnersCount(msg.sender, thisGuardThreshold, safeOwnersCount);
        }
    }

    // solhint-disable-next-line payable-fallback
    fallback() external {}
}
