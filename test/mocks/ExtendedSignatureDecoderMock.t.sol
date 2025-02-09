// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ExtendedSignatureDecoder} from "@src/ExtendedSignatureDecoder.sol";

contract ExtendedSignatureDecoderMock is ExtendedSignatureDecoder {
    function getSignersCount(bytes32 dataHash, bytes memory data, bytes memory signatures)
        public
        view
        returns (uint256 signersCount)
    {
        return _getSignersCount(dataHash, data, signatures);
    }
}
