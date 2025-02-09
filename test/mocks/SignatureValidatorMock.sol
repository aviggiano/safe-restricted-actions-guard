// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ISignatureValidator} from "@safe/contracts/interfaces/ISignatureValidator.sol";

contract SignatureValidatorMock is ISignatureValidator {
    bool public isValidSignatureResult;

    function setIsValidSignature(bool isValid) public {
        isValidSignatureResult = isValid;
    }

    function isValidSignature(bytes memory, bytes memory) public view override returns (bytes4) {
        return isValidSignatureResult ? EIP1271_MAGIC_VALUE : bytes4(0);
    }
}
