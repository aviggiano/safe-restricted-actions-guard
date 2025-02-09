// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ExtendedSignatureDecoderMock} from "@test/mocks/ExtendedSignatureDecoderMock.t.sol";
import {BaseTest} from "@test/BaseTest.t.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {ECDSA} from "@solady/src/utils/ECDSA.sol";
import {SignatureValidatorMock} from "@test/mocks/SignatureValidatorMock.sol";

contract ExtendedSignatureDecoderTest is BaseTest {
    ExtendedSignatureDecoderMock public extendedSignatureDecoder;
    Signature s1;
    Signature s2;

    function setUp() public override {
        super.setUp();
        extendedSignatureDecoder = new ExtendedSignatureDecoderMock();
    }

    function test_ExtendedSignatureDecoder_getSigners_1_1_signer_ecdsa() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        Safe safe = _deploySafe(alice);

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        Signature memory signature;
        (signature.v, signature.r, signature.s) = vm.sign(alicePk, dataHash);

        vm.prank(address(safe));
        uint256 signersCount = extendedSignatureDecoder.getSignersCount(dataHash, data, _encode(signature));

        assertEq(signersCount, 1);
    }

    function test_ExtendedSignatureDecoder_getSigners_2_2_signers_ecdsa() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        Safe safe = _deploySafe(alice, bob);

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        Signature memory signature1;
        (signature1.v, signature1.r, signature1.s) = vm.sign(alicePk, dataHash);
        Signature memory signature2;
        (signature2.v, signature2.r, signature2.s) = vm.sign(bobPk, dataHash);

        vm.prank(address(safe));
        uint256 signersCount =
            extendedSignatureDecoder.getSignersCount(dataHash, data, _encodeSorted(alice, signature1, bob, signature2));

        assertEq(signersCount, 2);
    }

    function test_ExtendedSignatureDecoder_getSigners_2_3_signers_ecdsa() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        (address bob, uint256 bobPk) = makeAddrAndKey("bob");
        address charlie = makeAddr("charlie");
        address[] memory signers = new address[](3);
        signers[0] = alice;
        signers[1] = bob;
        signers[2] = charlie;
        Safe safe = _deploySafe(signers, 2);

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);

        (s1.v, s1.r, s1.s) = vm.sign(alicePk, dataHash);
        (s2.v, s2.r, s2.s) = vm.sign(bobPk, dataHash);

        vm.prank(address(safe));
        uint256 signersCount =
            extendedSignatureDecoder.getSignersCount(dataHash, data, _encodeSorted(alice, s1, bob, s2));

        assertEq(signersCount, 2);
    }

    function test_ExtendedSignatureDecoder_getSigners_1_1_signer_eth_sign() public {
        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        Safe safe = _deploySafe(alice);

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        bytes32 ethSignedDataHash = ECDSA.toEthSignedMessageHash(dataHash);
        Signature memory signature;
        (signature.v, signature.r, signature.s) = vm.sign(alicePk, ethSignedDataHash);
        signature.v += 4;

        vm.prank(address(safe));
        uint256 signersCount = extendedSignatureDecoder.getSignersCount(dataHash, data, _encode(signature));

        assertEq(signersCount, 1);
    }

    function test_ExtendedSignatureDecoder_getSigners_1_1_signer_eip_1271_is_valid() public {
        SignatureValidatorMock signatureValidator = new SignatureValidatorMock();
        signatureValidator.setIsValidSignature(true);
        Safe safe = _deploySafe(address(signatureValidator));

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        bytes memory contractSignature = abi.encodePacked("Signature");

        bytes memory encoded = abi.encodePacked(
            bytes32(uint256(uint160(address(signatureValidator)))),
            bytes32(uint256(65)),
            bytes1(0x00),
            bytes32(uint256(contractSignature.length)),
            data,
            contractSignature
        );

        vm.prank(address(safe));
        uint256 signersCount = extendedSignatureDecoder.getSignersCount(dataHash, data, encoded);

        assertEq(signersCount, 1);
    }

    function test_ExtendedSignatureDecoder_getSigners_1_1_signer_eip_1271_is_invalid() public {
        SignatureValidatorMock signatureValidator = new SignatureValidatorMock();
        signatureValidator.setIsValidSignature(false);
        Safe safe = _deploySafe(address(signatureValidator));

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        bytes memory contractSignature = abi.encodePacked("Signature");

        bytes memory encoded = abi.encodePacked(
            bytes32(uint256(uint160(address(signatureValidator)))),
            bytes32(uint256(65)),
            bytes1(0x00),
            bytes32(uint256(contractSignature.length)),
            data,
            contractSignature
        );

        vm.prank(address(safe));
        vm.expectRevert("GS024");
        extendedSignatureDecoder.getSignersCount(dataHash, data, encoded);
    }

    function test_ExtendedSignatureDecoder_getSigners_1_1_signer_no_approvedHashes_is_invalid() public {
        SignatureValidatorMock signatureValidator = new SignatureValidatorMock();
        signatureValidator.setIsValidSignature(true);
        Safe safe = _deploySafe(address(signatureValidator));

        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        bytes memory contractSignature = abi.encodePacked("Signature");

        bytes memory encoded = abi.encodePacked(
            bytes32(uint256(uint160(address(signatureValidator)))),
            bytes32(uint256(65)),
            bytes1(0x01),
            bytes32(uint256(contractSignature.length)),
            data,
            contractSignature
        );

        vm.prank(address(safe));
        vm.expectRevert("GS025");
        extendedSignatureDecoder.getSignersCount(dataHash, data, encoded);
    }

    function test_ExtendedSignatureDecoder_getSigners_no_signatures() public view {
        bytes memory data = abi.encodePacked("Message");
        bytes32 dataHash = keccak256(data);
        uint256 signersCount = extendedSignatureDecoder.getSignersCount(dataHash, data, "");
        assertEq(signersCount, 0);
    }
}
