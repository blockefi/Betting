// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


library BettingLibrary {
    
    struct BettingDetailsOne { //check packing
        uint128 amount;
        uint120 status; //1 => Win, 2 => Loose
        bool isInverse;
        uint96 initialPrice;
        uint96 priceInXIV;
        address betTokenAddress;
        address coinAddress;
        
    }
    
    struct BettingDetailsTwo { //check packing
        uint64 reward;
        uint32 risk;
        uint32 dropValue;
        uint48 planType;
        uint32 startTime;
        uint32 endTime;
        bool isInToken;
        bool isClaimed;
    }

    function setBetDetailsOne(BettingDetailsOne storage bet, uint256 _amount, uint256 _initialPrice, uint256 _priceInXIV, address _coinAddress, address betToken, bool _isInverse) internal {
        bet.amount = uint128(_amount);
        bet.isInverse = _isInverse;
        bet.initialPrice = uint96(_initialPrice);
        bet.priceInXIV = uint96(_priceInXIV);
        bet.coinAddress = _coinAddress;
        bet.betTokenAddress = betToken;
    }
    
    function setBetDetailsTwo(BettingDetailsTwo storage bet, uint256 _reward, uint256 _riak, uint256 _drop, uint256 _planType, uint256 _startTime, uint256 _endTime) internal {
        bet.reward = uint64(_reward);
        bet.risk = uint32(_riak);
        bet.dropValue = uint32(_drop);
        bet.planType = uint48(_planType);
        bet.startTime = uint32(_startTime);
        bet.endTime = uint32(_endTime);
    }

    function changeClaimedStatus (BettingDetailsTwo storage bet) internal {
        if (bet.isClaimed == false) {
            bet.isClaimed = true;
        }
    }
    
    function declareBet(BettingDetailsOne storage bet, uint finalPrice, uint drop) internal returns (uint120) {
        uint256 initialPrice = uint256(bet.initialPrice);
        uint256 dip;

        if (bet.isInverse) {
            if (finalPrice < initialPrice) {
                dip = ((initialPrice - finalPrice) * 100) / initialPrice;
                if (dip >= drop) {
                    return bet.status = 1;
                }
            }    
        } else {
            if (finalPrice > initialPrice) {
                dip = (((finalPrice - initialPrice) * 100) / initialPrice);
                if (dip >= drop) {
                    return bet.status = 1;
                }
            }
        }

        return bet.status = 2;
    }
}