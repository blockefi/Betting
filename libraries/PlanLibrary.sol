// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


library PlanLibrary {
    
    struct PlanDetails { //check packing
        uint64 risk;
        uint64 reward;
        uint120 drop;
        bool isActive;
    }
    
    function setPlan(PlanDetails storage plan, uint256 _reward, uint256 _risk, uint256 _drop) internal {
        require(_risk >= 0 && _risk <= 100, "PlanLibrary : Invalid");
        require(_drop > 0 && _drop <= 100, "PlanLibrary : Invalid");
        
        plan.reward = uint64(_reward);
        plan.risk = uint64(_risk);
        plan.drop = uint120(_drop);
        plan.isActive = true;
    }
    
    function setReward(PlanDetails storage plan, uint256 _reward) internal {
        require(_reward > 0, "PlanLibrary : Invalid reward");
        
        plan.reward = uint64(_reward);
    }
    
    function setRisk(PlanDetails storage plan, uint256 _risk) internal {
        require(_risk >= 0 && _risk <= 100, "PlanLibrary : Invalid");
        
        plan.risk = uint64(_risk);
    }
    
    function setDrop(PlanDetails storage plan, uint256 _drop) internal {
        require(_drop > 0 && _drop <= 100, "PlanLibrary : Invalid");
        
        plan.drop = uint120(_drop);
        
    }
    
    function setStatus(PlanDetails storage plan, bool status) internal {
        
        if (plan.isActive != status) {
                plan.isActive = status;
            }
    }
}