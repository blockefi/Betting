//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface InverseV0Events {

   event LPEvent(uint typeOfLP,address  userAddress,uint amount,uint timestamp);
   event Addcoins(uint coinType, uint planType, uint counter, bool status, address coinAddress);
   event CoinStatus(address coinAddress, uint coinType, uint planType, bool status);
   event IndexCoinStatus(uint coinType, uint planType, bool status);
   event NewBet(address indexed user, address coinAddress, address betCoin, uint indexed betIndex, uint planIndex, uint planDays, uint startTime, uint indexed endTime);
   event BetResolved(address indexed user, uint indexed index, uint indexed result, uint endTime);
   event BetClaimed(address indexed user, uint indexed betIndex, uint timeOfClaim, uint winningAmount);
   event UserPenalized(address indexed user, uint256 indexed betIndex, bool indexed isClaimed);
}