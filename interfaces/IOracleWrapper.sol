// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.0;

interface IOracleWrapper {
    function getPrice(address _coinAddress, address pair) external view returns (uint256);
}

