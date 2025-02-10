// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct DepositParams {
    address token;
    uint256 amount;
    address to;
}

struct WithdrawParams {
    address token;
    uint256 amount;
    address to;
}

interface ISize {
    function deposit(DepositParams calldata params) external;
    function withdraw(WithdrawParams calldata params) external;
}
