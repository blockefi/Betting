// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


library StakingLibrary {
   
    struct StakingCycle {
        uint64 stakingTime;
        uint64 lastIndex;
        uint128 stakedAmount;
    }

    struct StakingReward {
        uint96 betEndStake;
        uint96 stakingReward;
        uint32 betEndTime;
        uint32 status;
    }
    
    struct ClaimDetails {
        uint128 lastStakedAmount;
        uint128 amountUnstaked;//check if this is required
        uint128 stakeResidual;
        uint128 profit;
        uint128 losses;
        uint32 lastStakedTime;
        uint32 lastClaimedBet;
        uint32 stakeCounter;
        uint32 lastUnstakeIndex;
    }

    function setStakingRewards(StakingReward storage stake, uint256 endStake, uint256 _stakingReward, uint256 result) internal {
        stake.betEndStake = uint96(endStake);
        stake.stakingReward = uint96(_stakingReward);
        stake.betEndTime = uint32(block.timestamp);
        stake.status = uint32(result);
    }
    
    function setStakeCycle(StakingCycle storage cycle, uint256 amount) internal {
        cycle.stakingTime = uint64(block.timestamp);
        cycle.stakedAmount = uint128(amount);
    }
    
    function setStakingDetails(ClaimDetails storage stake, uint256 amount) internal {
        stake.lastStakedAmount += uint128(amount);
        stake.lastStakedTime = uint32(block.timestamp);
        stake.stakeCounter++;
    }
    
    function setClaimDetails(ClaimDetails storage stake, uint256 balance, uint256 amount, uint256 claimedIndex) internal returns (uint256) {
        uint256 diff;
        if (stake.losses > stake.profit) {
            diff = uint256(stake.losses - stake.profit);
        }
        require(balance + uint256(stake.stakeResidual) >= (amount + diff), "StakingLibrary: Insufficient");
        require(uint256(stake.lastStakedAmount) >= (amount + diff), "StakingLibrary: Insufficient");
        
        uint256 residual = ((balance + uint256(stake.stakeResidual)) - (amount + diff));
        
        stake.stakeResidual = uint128(residual);
        
        if (diff > 0) {
            stake.profit = uint128(0);
            stake.losses = uint128(0);
        }
        
        stake.lastStakedTime = uint32(block.timestamp);
        
        if (stake.lastUnstakeIndex != uint32(claimedIndex)) {
            stake.lastUnstakeIndex = uint32(claimedIndex);
        }
        
        stake.amountUnstaked += uint128(amount + diff);
        stake.lastStakedAmount -= uint128(amount + diff);
        
        return (amount + diff);
        
    }
}