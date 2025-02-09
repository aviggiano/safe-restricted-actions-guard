// SPDX-License-Identifier: MIT
// Further information: https://eips.ethereum.org/EIPS/eip-1014
pragma solidity ^0.8.9;

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;
}
