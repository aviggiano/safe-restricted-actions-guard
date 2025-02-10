// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ISize {
    function deposit(address token, uint256 amount, address to) external;
    function withdraw(address token, uint256 amount, address to) external;
}
