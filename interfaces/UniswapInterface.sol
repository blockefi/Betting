// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.0;

interface uniswapInterface{
    function getAmountsOut(uint amountIn, address[] memory path)external view returns (uint[] memory amounts);
}