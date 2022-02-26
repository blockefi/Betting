// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.0;

interface OracleInterface{
    function latestAnswer() external view returns (int256);
}

