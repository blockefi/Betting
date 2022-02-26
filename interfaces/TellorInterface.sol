// SPDX-License-Identifier: UNLICENCED

pragma solidity ^0.8.0;

interface tellorInterface{
    function getLastNewValueById(uint _requestId) external view returns(uint,bool);
}