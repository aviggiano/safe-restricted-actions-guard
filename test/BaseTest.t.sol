// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Safe} from "@safe/contracts/Safe.sol";
import {SafeProxy} from "@safe/contracts/proxies/SafeProxy.sol";
import {SafeProxyFactory} from "@safe/contracts/proxies/SafeProxyFactory.sol";
import {Enum} from "@safe/contracts/common/Enum.sol";

contract BaseTest is Test {
    address public singleton;
    SafeProxyFactory public safeProxyFactory;
    mapping(address => uint256) public privateKeys;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    function setUp() public virtual {
        singleton = address(new Safe());
        safeProxyFactory = new SafeProxyFactory();

        vm.label(singleton, "Safe");
        vm.label(address(safeProxyFactory), "SafeProxyFactory");
    }

    function _makeAddrAndSaveKey(string memory name) internal returns (address) {
        (address addr, uint256 key) = makeAddrAndKey(name);
        privateKeys[addr] = key;
        return addr;
    }

    function _deploySafe(
        address[] memory owners,
        uint256 threshold,
        address to,
        bytes memory data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address paymentReceiver,
        uint256 saltNonce
    ) internal returns (Safe) {
        SafeProxy proxy = safeProxyFactory.createProxyWithNonce(
            singleton,
            abi.encodeCall(
                Safe.setup,
                (owners, threshold, to, data, fallbackHandler, paymentToken, payment, payable(paymentReceiver))
            ),
            saltNonce
        );
        vm.label(address(proxy), "SafeProxy");
        return Safe(payable(address(proxy)));
    }

    function _deploySafe(address[] memory owners, uint256 threshold) internal returns (Safe) {
        return _deploySafe(owners, threshold, address(0), "", address(0), address(0), 0, address(0), 0);
    }

    function _deploySafe(address[] memory owners) internal returns (Safe) {
        return _deploySafe(owners, owners.length, address(0), "", address(0), address(0), 0, address(0), 0);
    }

    function _deploySafe(address owner) internal returns (Safe) {
        address[] memory owners = new address[](1);
        owners[0] = owner;
        return _deploySafe(owners);
    }

    function _deploySafe(address owner1, address owner2) internal returns (Safe) {
        address[] memory owners = new address[](2);
        owners[0] = owner1;
        owners[1] = owner2;
        return _deploySafe(owners);
    }

    function _encode(Signature memory signature) internal pure returns (bytes memory) {
        return abi.encodePacked(signature.r, signature.s, signature.v);
    }

    function _encodeSorted(address address1, Signature memory signature1, address address2, Signature memory signature2)
        internal
        pure
        returns (bytes memory)
    {
        address[] memory owners = new address[](2);
        owners[0] = address1;
        owners[1] = address2;
        Signature[] memory signatures = new Signature[](2);
        signatures[0] = signature1;
        signatures[1] = signature2;
        return _encodeSorted(owners, signatures);
    }

    function _encodeSorted(address[] memory owners, Signature[] memory signatures)
        internal
        pure
        returns (bytes memory)
    {
        (, Signature[] memory sortedSignatures) = _sort(owners, signatures);
        bytes[] memory encodedSignatures = new bytes[](sortedSignatures.length);
        for (uint256 i = 0; i < sortedSignatures.length; i++) {
            encodedSignatures[i] = _encode(sortedSignatures[i]);
        }
        bytes memory encoded;
        for (uint256 i = 0; i < encodedSignatures.length; i++) {
            encoded = abi.encodePacked(encoded, encodedSignatures[i]);
        }
        return encoded;
    }

    function _sort(address[] memory owners, Signature[] memory signatures)
        internal
        pure
        returns (address[] memory sortedOwners, Signature[] memory sortedSignatures)
    {
        sortedOwners = new address[](owners.length);
        for (uint256 i = 0; i < owners.length; i++) {
            sortedOwners[i] = owners[i];
        }

        address temp;
        uint256 n = sortedOwners.length;

        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - 1 - i; j++) {
                if (sortedOwners[j] > sortedOwners[j + 1]) {
                    temp = sortedOwners[j];
                    sortedOwners[j] = sortedOwners[j + 1];
                    sortedOwners[j + 1] = temp;
                }
            }
        }

        sortedSignatures = new Signature[](sortedOwners.length);
        for (uint256 i = 0; i < sortedOwners.length; i++) {
            for (uint256 j = 0; j < owners.length; j++) {
                if (sortedOwners[i] == owners[j]) {
                    sortedSignatures[i] = signatures[j];
                    break;
                }
            }
        }
    }

    function _getDataHash(Safe safe, address to, bytes memory data) internal view returns (bytes32) {
        return _getDataHash(safe, to, 0, data);
    }

    function _getDataHash(Safe safe, address to, uint256 value, bytes memory data) internal view returns (bytes32) {
        uint256 nonce = safe.nonce();
        return safe.getTransactionHash(
            to, value, data, Enum.Operation.Call, 0, 0, 0, address(0), payable(address(0)), nonce
        );
    }

    function _execTransaction(Safe safe, address to, bytes memory data, address[] memory signers) internal {
        _execTransaction(safe, to, 0, data, signers);
    }

    function _execTransaction(Safe safe, address to, uint256 value, bytes memory data, address[] memory signers)
        internal
    {
        bytes32 dataHash = _getDataHash(safe, to, value, data);
        _execTransaction(safe, to, value, data, signers, dataHash);
    }

    function _execTransaction(Safe safe, address to, bytes memory data, address[] memory signers, bytes32 dataHash)
        internal
    {
        _execTransaction(safe, to, 0, data, signers, dataHash);
    }

    function _execTransaction(
        Safe safe,
        address to,
        uint256 value,
        bytes memory data,
        address[] memory signers,
        bytes32 dataHash
    ) internal {
        Signature[] memory signatures = new Signature[](signers.length);
        for (uint256 i = 0; i < signers.length; i++) {
            (signatures[i].v, signatures[i].r, signatures[i].s) = vm.sign(privateKeys[signers[i]], dataHash);
        }

        safe.execTransaction(
            to,
            value,
            data,
            Enum.Operation.Call,
            0,
            0,
            0,
            address(0),
            payable(address(0)),
            _encodeSorted(signers, signatures)
        );
    }
}
