// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Safe} from "@safe/contracts/Safe.sol";
import {SafeMath} from "@safe/contracts/external/SafeMath.sol";
import {OwnerManager} from "@safe/contracts/base/OwnerManager.sol";
import {ISignatureValidator} from "@safe/contracts/interfaces/ISignatureValidator.sol";
import {ISignatureValidatorConstants} from "@safe/contracts/interfaces/ISignatureValidator.sol";
import {SignatureDecoder} from "@safe/contracts/common/SignatureDecoder.sol";

/// @title ExtendedSignatureDecoder
/// @author Antonio Viggiano (@aviggiano)
/// @notice Extends `SignatureDecoder` to get the Safe signers from the `signatures` bytes value
abstract contract ExtendedSignatureDecoder is SignatureDecoder, ISignatureValidatorConstants {
    using SafeMath for uint256;

    /// @dev Copy/pasted from `OwnerManager.sol`
    address internal constant SENTINEL_OWNERS = address(0x1);

    /// @notice Get the number of Safe signers from the `signatures` bytes value
    /// @dev Copy/pasted from `Safe.sol` with the following modifications:
    ///      - `requiredSignatures` is derived from the length of `signatures`
    ///      - This function reenters into the Safe contract as well as in EIP-1271 signers
    ///      - Assumes `msg.sender` is the Safe contract
    /// @param dataHash the hash of the signed data
    /// @param data the calldata
    /// @param signatures the concatenated list of signatures
    /// @return signersCount the number of signers
    function _getSignersCount(bytes32 dataHash, bytes memory data, bytes memory signatures)
        internal
        view
        returns (uint256 signersCount)
    {
        uint256 requiredSignatures = signatures.length / 65;

        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        for (uint256 i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                require(keccak256(data) == dataHash, "GS027");
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                // slither-disable-next-line divide-before-multiply
                require(uint256(s) >= requiredSignatures.mul(65), "GS021");

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                require(uint256(s).add(32) <= signatures.length, "GS022");

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(uint256(s).add(32).add(contractSignatureLen) <= signatures.length, "GS023");

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                require(
                    ISignatureValidator(currentOwner).isValidSignature(data, contractSignature) == EIP1271_MAGIC_VALUE,
                    "GS024"
                );
            } else if (v == 1) {
                // If v is 1 then it is an approved hash
                // When handling approved hashes the address of the approver is encoded into r
                currentOwner = address(uint160(uint256(r)));
                // Hashes are automatically approved by the sender of the message or when they have been pre-approved via a separate transaction
                require(
                    msg.sender == currentOwner || Safe(payable(msg.sender)).approvedHashes(currentOwner, dataHash) != 0,
                    "GS025"
                );
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                currentOwner =
                    ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v - 4, r, s);
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(
                currentOwner > lastOwner && Safe(payable(msg.sender)).isOwner(currentOwner)
                    && currentOwner != SENTINEL_OWNERS,
                "GS026"
            );
            signersCount++;
            lastOwner = currentOwner;
        }
    }
}
