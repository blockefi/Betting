// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IERC20.sol";
import './interfaces/InverseV0Events.sol';
import "./libraries/TransferHelper.sol";
import "./libraries/StakingLibrary.sol";
import "./libraries/BettingLibrary.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/UserLibrary.sol";
import "./libraries/PlanLibrary.sol";
import "./upgradeability/CustomOwnable.sol";
import "./interfaces/IOracleWrapper.sol";

contract InverseV0 is InverseV0Events, CustomOwnable, ReentrancyGuard {

    using StakingLibrary for StakingLibrary.StakingCycle;
    using StakingLibrary for StakingLibrary.StakingReward;
    using StakingLibrary for StakingLibrary.ClaimDetails;
    using BettingLibrary for BettingLibrary.BettingDetailsOne;
    using BettingLibrary for BettingLibrary.BettingDetailsTwo;
    using UserLibrary for UserLibrary.UserDetails;
    using PlanLibrary for PlanLibrary.PlanDetails;
    
    uint256 public SECONDS_IN_DAY;         // Seconds in a day


    bool internal isInitialized;
    uint256 public globalPool;         //total amount in pool
    uint256 public miniStakeAmount ;   // Min amount of token that user can stake 
    uint256 public maxStakeAmount ;   // Max amount of token that user can stake 
    uint256 public betFactorLP;               // this is the ratio according to which users can bet considering the amount staked..
    uint256 public miniBetAmount;             // min amount that user can bet on.
    uint256 public maxBetAmount;            // max amount that user can bet on.
    uint256 public defiCoinsCounter;          // Number of Defi plans
    uint256 public chainCoinsCounter;         // Number of Chain plans      
    uint256 public NFTCoinsCounter;           // Number of NFT plan
    uint256 public stakerIncentiveCounter;
    uint256 public planCounter;
    uint256 public planDaysCounter;
    uint256 public maxWalks;
    uint256 public bufferTime;
    uint256 public betFees;
    uint256 public threshold;
    uint256 public accumulatedXIV;
    bool public isMultiTokenActive;
    
    address public oracleAddress;
    address public revokeComissionAddress;

    IERC20 public XIV;
    IERC20 coin;
    IERC20 public usdt;
    IOracleWrapper public oracle;

    mapping(address => UserLibrary.UserDetails) public users;
    mapping(address => mapping (uint256 => StakingLibrary.StakingCycle)) public stakes;
    mapping(address => StakingLibrary.ClaimDetails) public stakeDetails;
    mapping(address => uint256) public betCounter;
    mapping(address => mapping(uint256 => mapping (uint256 => bool))) public coinStatus;
    mapping(uint256 => mapping(uint256 => mapping(uint256 => address))) public coins;
    mapping(address => mapping(address => bool)) public isEligibleForBet;
    mapping(address => mapping(uint256 => BettingLibrary.BettingDetailsOne)) public userBetsOne;
    mapping(address => mapping(uint256 => BettingLibrary.BettingDetailsTwo)) public userBetsTwo;
    mapping(uint256 => StakingLibrary.StakingReward) public stakerRewards;
    
    mapping(uint256 => PlanLibrary.PlanDetails) public plans;
    mapping(uint256 => uint256) public planDaysIndexed;
    mapping(uint256 => mapping(uint256 => uint256)) public penalty;
    
    modifier typeValidation(uint256 _coinType, uint256 planType) {
        require((_coinType == 1 || _coinType == 2 || _coinType == 3), "Invalid");
        require((planType == 1 || planType == 2), "Invalid PlanType");
        _;
    }
    
    modifier planValidation(uint256 coinType, uint256 planType) {
        require((coinType == 1 || coinType == 2 || coinType == 3), "Invalid");
        require((planType == 1 || planType == 2), "Invalid PlanType");
        _;
    }

    modifier validateBetArguments(address coinAddress, uint coinType, uint planType, address betToken)  {
        require(betToken != address(0), "Invalid");
        
        if (!isMultiTokenActive) {
            require(betToken == address(XIV), "Multi token inactive");
        }
        require(coinStatus[coinAddress][coinType][planType], "Not active");
        require(!isEligibleForBet[_msgSender()][coinAddress], "Bet already active");
        
        _;
    }
    
    modifier amountValidation(uint amount) {
        require(amount > 0, "Invalid");
        _;
    }
    
    modifier countValidation(uint256 count, uint256 counter) {
        require(count >= 0 && (count < counter), "Invalid");
        _;
    }
   

    function initialize(address _admin, address _XIVAddress, address _revokeComissionAddress, uint _miniStakeAmount, uint _betFactorLP, uint _miniBetAmount, uint _maxBetAmount, address _oracle, address _usdt) public {
        require(!isInitialized);
        isInitialized = true;
        miniStakeAmount  = _miniStakeAmount;
        maxStakeAmount = (100000 * 10**18);
        betFactorLP = _betFactorLP;
        miniBetAmount = _miniBetAmount;
        maxBetAmount = _maxBetAmount;
        bufferTime = 3600;
        XIV = IERC20(_XIVAddress);
        oracle = IOracleWrapper(_oracle);
        usdt = IERC20(_usdt);
        _setOwner(_admin);
        maxWalks = 100;
        SECONDS_IN_DAY = 86400;
        setPlanDetails([6,3,5,7], [300,50,100,200], [0,0,0,0]);
        planCounter = 4;
        betFees = 7;
        threshold = (10000 * 10**18);
        revokeComissionAddress = _revokeComissionAddress;
        
        planDaysIndexed[0] = 1;
        planDaysIndexed[1] = 1;
        planDaysIndexed[2] = 3;
        planDaysIndexed[3] = 7;
        
        penalty[1][0] = 7;
        penalty[3][0] = 7;
        penalty[3][1] = 7;
        penalty[3][2] = 7;
        penalty[7][0] = 7;
        penalty[7][1] = 7;
        penalty[7][2] = 7;
        penalty[7][3] = 7;
        penalty[7][4] = 7;
        penalty[7][5] = 7;
        penalty[7][6] = 7;
        
        
        planDaysCounter = 4;
    }
    
    receive() external payable {
        
    }
    
    function stakeTokens(uint256 amount) external nonReentrant {
        require(amount >= miniStakeAmount && amount <= maxStakeAmount, "Invalid");
        _updateRewards(_msgSender());
        StakingLibrary.ClaimDetails storage stake = stakeDetails[_msgSender()];
        require((stake.lastClaimedBet == stakerIncentiveCounter) || (stake.stakeCounter == uint32(0)), "Claim all bets");
        TransferHelper.safeTransferFrom(address(XIV), _msgSender(), address(this), amount);
        
        uint256 count = stake.stakeCounter;
        
        stakes[_msgSender()][count].setStakeCycle(amount);
        stake.setStakingDetails(amount);
        globalPool += amount;
    }
    
    function unstakeTokens(uint256 amount) external nonReentrant {
        _updateRewards(_msgSender());
        require(stakeDetails[_msgSender()].lastClaimedBet == stakerIncentiveCounter, "Claim all bets");
        (uint256 balance, uint256 claimedIndex) = amountToUnlock(_msgSender());
        
        uint256 unstakedAmount = stakeDetails[_msgSender()].setClaimDetails(balance, amount, claimedIndex);
        require(globalPool >= unstakedAmount, "Insufficient funds");
        require(globalPool >= amount, "Insufficient funds");
        globalPool -= unstakedAmount;
        TransferHelper.safeTransfer(address(XIV), _msgSender(), amount);
    }
    
    function amountToUnlock(address user) public view returns (uint256, uint256) {
        StakingLibrary.ClaimDetails storage stake = stakeDetails[user];
        uint256 count = uint256(stake.stakeCounter);
        uint256 lastIndex = uint256(stake.lastUnstakeIndex);
        uint256 balance;
        uint256 claimedIndex = lastIndex;
        
        require(count >= lastIndex, "Invalid");
        
        if (count > lastIndex) {
            for (uint256 i = lastIndex; i < count; i++) {
                StakingLibrary.StakingCycle storage cycle = stakes[user][i];
                
                balance += uint256(cycle.stakedAmount);
                claimedIndex = (i+1);
            }
        }
        
        return (balance, claimedIndex);
    }
    
    function updateRewards(address user) external nonReentrant {
        require(stakeDetails[user].lastClaimedBet < stakerIncentiveCounter, "Already updated");
        _updateRewards(user);
    }
    
    function _updateRewards(address user) internal returns (bool) {
        StakingLibrary.ClaimDetails storage stake = stakeDetails[user];
        
        if (stake.lastClaimedBet == stakerIncentiveCounter) {
            return true;
        }
        
        if (stake.stakeCounter == uint32(0)) {
            stake.lastClaimedBet = uint32(stakerIncentiveCounter);
            return true;
        }
        
        (uint256 rewards, uint256 loss, uint256 lastClaimed) = getRewards(user);
        
        stake.lastClaimedBet = uint32(lastClaimed);
        
        if (rewards == 0 && loss == 0) {
            return true;
        }
        
        if (rewards > 0) {
            stake.profit += uint128(rewards);
        }
        
        if (loss > 0) {
            stake.losses += uint128(loss);
        }
        
        if (lastClaimed == stakerIncentiveCounter) {
            return true;
        } else {
            return false;
        }
    }
    
    function claimRewards() external nonReentrant {
        _updateRewards(_msgSender());
        StakingLibrary.ClaimDetails storage stake = stakeDetails[_msgSender()];
        
        require(stake.profit > stake.losses, "No rewards");
        uint256 amount = (stake.profit - stake.losses);
        
        stake.profit = uint128(0);
        stake.losses = uint128(0);
        
        TransferHelper.safeTransfer(address(XIV), _msgSender(), amount);
    }
    
    function getRewards(address user) public view returns (uint256, uint256, uint256) {
        StakingLibrary.ClaimDetails storage stake = stakeDetails[user];
        uint256 start = uint256(stake.lastClaimedBet);
        uint256 time = uint256(stake.lastStakedTime);
        uint256 amount = uint256(stake.lastStakedAmount);
        uint256 incentive;
        uint256 loss;
        uint256 end;
        
        if (start + maxWalks >= stakerIncentiveCounter) {
            end = stakerIncentiveCounter;
        } else {
            end = start + maxWalks;
        }
        
        for (uint256 i = start; i < end; i++) {
            StakingLibrary.StakingReward storage reward = stakerRewards[i];
            
            if (reward.betEndTime > time) {
                if (uint256(reward.status) == 2) {
                    incentive += ((uint256(reward.stakingReward) * amount) / uint256(reward.betEndStake));
                } else if (uint256(reward.status) == 1) {
                    loss += ((uint256(reward.stakingReward) * amount) / uint256(reward.betEndStake));
                }
            }
        }
        
        return (incentive, loss, end);
    }
    
    function betFlexible(uint amount, uint coinType, address coinAddress, address betToken, uint index, uint _daysIndex, bool _isInverse) external payable validateBetArguments(coinAddress, coinType, 2, betToken) nonReentrant {
        uint256 planDays = planDaysIndexed[_daysIndex];
        
        require(((index > 0) && (index < planCounter)));
        require(planDays != 0, "Invalid");
        
        saveBetDetailsOne(_msgSender(), amount, coinAddress, betToken, _isInverse);
        saveBetDetailsTwo(_msgSender(), index, planDays, 2);
    }
    
    function betFixed(uint amount, uint coinType, address coinAddress, address betToken, bool _isInverse) external payable validateBetArguments(coinAddress, coinType, 1, betToken) nonReentrant {     
        saveBetDetailsOne(_msgSender(), amount, coinAddress, betToken, _isInverse);
        saveBetDetailsTwo(_msgSender(), 0, planDaysIndexed[0],  1);
    }
    
    function saveBetDetailsOne(address user, uint256 amount, address _coinAddress, address betToken, bool _isInverse) internal {
        uint256 fees = (amount * betFees) / 100;
        uint256 actualAmount = amount;
        amount = (amount - fees);
        uint256 priceInXIV;
        
        
        if (betToken != address(XIV)) {
            priceInXIV = getPriceInXIV(betToken);
            
            uint256 amountInXIV;
            
            if (betToken == address(1)) {
                require(msg.value == actualAmount, "Invalid");
                amountInXIV = (actualAmount  * priceInXIV) / (10 ** 18);
            } else {
                amountInXIV = (actualAmount  * priceInXIV) / (10 ** (IERC20(betToken).decimals()));
            }
            
            // check this condition
            if (XIV.balanceOf(address(this)) > globalPool) {
                require((betFactorLP * globalPool) >= ((XIV.balanceOf(address(this)) - globalPool) + amountInXIV), "Betfactor");
            }
            
            require(amountInXIV >= miniBetAmount && amountInXIV <= maxBetAmount ,"Invalid");
        } else {
            //check this condition
            if (XIV.balanceOf(address(this)) > globalPool) {
                require((betFactorLP * globalPool) >= ((XIV.balanceOf(address(this)) - globalPool) + actualAmount), "Betfactor");
            }
            
            require(actualAmount >= miniBetAmount && actualAmount <= maxBetAmount ,"Invalid");
        }

        BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[user][betCounter[user]];
        BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[user][betCounter[user]];

        if (msg.value == 0 && (betToken != address(1))) {
            TransferHelper.safeTransferFrom(betToken, user, address(this), actualAmount);
            
            if (fees > 0 && betToken != address(XIV)) {
                TransferHelper.safeTransfer(betToken, revokeComissionAddress, fees);
            } else if (fees > 0 && betToken == address(XIV)) {
                accumulatedXIV += fees;
                
                if (accumulatedXIV > threshold) {
                    stakerRewards[stakerIncentiveCounter].setStakingRewards(globalPool, accumulatedXIV, 2);
                    stakerIncentiveCounter++;
                    accumulatedXIV = 0;
                }
            }
            
            betTwo.isInToken = true;
        } else {
            require(betToken == address(1), "BetToken must be 0x1");
            if (fees > 0) {
                TransferHelper.safeTransferETH(revokeComissionAddress, fees);
            }
            
        }

        betOne.setBetDetailsOne(amount, oracle.getPrice(_coinAddress, address(usdt)), priceInXIV, _coinAddress, betToken, _isInverse);
    }
    
    function saveBetDetailsTwo(address user, uint256 planIndex, uint _days, uint _planType) internal {
        BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[user][betCounter[user]];
        BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[user][betCounter[user]];
        
        if (_planType == 1) {
            betTwo.setBetDetailsTwo((plans[planIndex].reward), (plans[planIndex].risk), (plans[planIndex].drop), _planType, block.timestamp, (block.timestamp + (_days * (SECONDS_IN_DAY / 4))));
            emit NewBet(user, betOne.coinAddress, betOne.betTokenAddress, betCounter[user], planIndex, _days, block.timestamp, (block.timestamp + (_days * (SECONDS_IN_DAY / 4))));
        } else {
            betTwo.setBetDetailsTwo((plans[planIndex].reward), (plans[planIndex].risk), (plans[planIndex].drop), _planType, block.timestamp, (block.timestamp + (_days * SECONDS_IN_DAY)));
            emit NewBet(user, betOne.coinAddress, betOne.betTokenAddress, betCounter[user], planIndex, _days, block.timestamp, (block.timestamp + (_days * SECONDS_IN_DAY)));
        }

        
        isEligibleForBet[user][betOne.coinAddress] = true;
        
        betCounter[user]++;
    }

    function resolveBet(uint[] memory index, address[] memory user, bool timeCheck) external onlyOwner nonReentrant {
        require(index.length == user.length, "Length mismatch");
        
        for (uint256 i; i < index.length; i++) {
            require((index[i] < betCounter[user[i]]) ,"Invalid");
            BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[user[i]][index[i]];
            BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[user[i]][index[i]];
            require(betOne.status == 0, "Already resolved");
    
            if (timeCheck) {
                require(block.timestamp > betTwo.endTime && block.timestamp <= betTwo.endTime + bufferTime, "EndTime error");
            }
            
            uint currentPrice = oracle.getPrice(betOne.coinAddress, address(usdt));
    
            //Find the result
            uint256 result = betOne.declareBet(currentPrice, uint256(betTwo.dropValue));
            
            if(result == 2 || result == 1) {
                uint256 betRewards;
                uint256 amount = uint256(betOne.amount);
                uint256 priceInXIV = uint256(betOne.priceInXIV);
                uint256 risk;
                
                if (result == 2) {
                    risk = uint256(betTwo.risk);
                } else {
                    risk = uint256(betTwo.reward);
                }
                
                if (betOne.priceInXIV != 0 && (betOne.betTokenAddress != address(XIV))) {
                    if (betOne.betTokenAddress == address(1)) {
                        betRewards = (amount * priceInXIV * risk) / (10 ** 20);
                    } else {
                        betRewards = (amount * priceInXIV * risk) / (100 * (10 ** (IERC20(betOne.betTokenAddress).decimals())));
                    }
                } else {
                    betRewards = (amount * risk) / 100;
                }
                
                stakerRewards[stakerIncentiveCounter].setStakingRewards(globalPool, betRewards, result);
                stakerIncentiveCounter++;
            }
            
            isEligibleForBet[user[i]][betOne.coinAddress] = false;
            
            emit BetResolved(user[i], index[i], result, block.timestamp);
        }
    }

    function claimBets() external nonReentrant {
        
        uint256 amountInETH;
        uint256 amountInXIV;
        uint256 claimedIndex;
        uint256 lastIndex = users[_msgSender()].lastBetIndex;
        
        require(betCounter[_msgSender()] > lastIndex, "No new bet");
        
        for(uint256 i = lastIndex; i < betCounter[_msgSender()]; i++) {
            BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[_msgSender()][i];
            BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[_msgSender()][i];
            
            if (!betTwo.isClaimed && (betOne.status != 0)) {
                uint256 amount = uint256(betOne.amount);
                uint256 reward = uint256(betTwo.reward);
                uint256 risk = uint256(betTwo.risk);
                uint256 winningAmount;
                
                if((betOne.status == 1)) {
                    if (betTwo.isInToken) {
                        if (betOne.betTokenAddress != address(XIV)) {
                            TransferHelper.safeTransfer(betOne.betTokenAddress, _msgSender(), amount);
                        } else {
                            amountInXIV += amount;
                        }
                    } else {
                        amountInETH += amount;
                    }

                    if ((betOne.betTokenAddress != address(XIV)) && (betOne.priceInXIV > 0)) {
                        if (betOne.betTokenAddress == address(1)) {
                            winningAmount = ((amount * uint256(betOne.priceInXIV) * reward) /  (10 ** 20));
                        } else {
                            winningAmount = ((amount * uint256(betOne.priceInXIV) * reward) / (100 * (10 ** IERC20(betOne.betTokenAddress).decimals())));
                        }
                        
                        amountInXIV += winningAmount;
                    } else {
                        winningAmount = (amount * reward) / 100;
                        amountInXIV += winningAmount;
                    }
                    
                    betTwo.changeClaimedStatus();
                    
                } else if (betOne.status == 2) {
                    require(risk <= 100, "Invalid");
                    
                    uint256 loss = (risk * amount) / 100;
                    uint256 balance = (amount - loss);
                        
                    if (betTwo.isInToken) {
                        if (betOne.betTokenAddress != address(XIV)) {
                            if (balance > 0) {
                                TransferHelper.safeTransfer(betOne.betTokenAddress, _msgSender(), balance);
                            }
                            
                            if (loss > 0) {
                                TransferHelper.safeTransfer(betOne.betTokenAddress, revokeComissionAddress, loss);
                            }
                            
                        } else {
                            amountInXIV += balance;
                        }
                        
                    } else {
                        amountInETH += balance;
                        
                        if (loss > 0) {
                            TransferHelper.safeTransferETH(revokeComissionAddress, loss);
                        }
                        
                    }
                    
                    betTwo.changeClaimedStatus();
                }
                
                claimedIndex = (i+1);
                emit BetClaimed(_msgSender(), i, block.timestamp, winningAmount);
            }
        }
        
        users[_msgSender()].lastBetIndex = uint64(claimedIndex);
        
        if (amountInETH > 0) {
            TransferHelper.safeTransferETH(_msgSender(), amountInETH);
        }
            
        if (amountInXIV > 0) {
            TransferHelper.safeTransfer(address(XIV), _msgSender(), amountInXIV);
        }
    }
    
    function betPenalty(uint256 betIndex) external nonReentrant {
        require(betCounter[_msgSender()] > betIndex, "Invalid");
        BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[_msgSender()][betIndex];
        BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[_msgSender()][betIndex];
        require(!betTwo.isClaimed && uint256(betTwo.endTime) > block.timestamp, "EndTime");
        
        uint256 fine;
        uint256 claim;
        uint256 penaltyAmount;
        
        uint256 dayPassed = (block.timestamp - betTwo.startTime) / SECONDS_IN_DAY;
        uint256 planDaysIndex = uint256(betTwo.endTime - betTwo.startTime) / SECONDS_IN_DAY;
        fine = penalty[planDaysIndex][dayPassed];
        
        require(fine <= 100);
        
        penaltyAmount = (fine * uint256(betOne.amount)) / 100;
        claim = (uint256(betOne.amount) - penaltyAmount);
        
        
        if (claim > 0) {
            if (betTwo.isInToken) {
                TransferHelper.safeTransfer(betOne.betTokenAddress, _msgSender(), claim);
            } else {
                TransferHelper.safeTransferETH(_msgSender(), claim);
            }
        }
        
        if (penaltyAmount > 0) {
            if (betTwo.isInToken) {
                TransferHelper.safeTransfer(betOne.betTokenAddress, revokeComissionAddress, penaltyAmount);
            } else {
                TransferHelper.safeTransferETH(revokeComissionAddress, penaltyAmount);
            }
        }
        
        betTwo.isClaimed = true;
        isEligibleForBet[_msgSender()][betOne.coinAddress] = false;
        
        emit UserPenalized(_msgSender(), betIndex, betTwo.isClaimed);
    }
    
    function getBetRewards(address user) public view returns (uint256) {
        uint256 lastIndex = users[user].lastBetIndex;
        
        if (betCounter[user] == 0 || betCounter[user] == lastIndex) {
            return 0;
        }
        
        require(betCounter[user] > lastIndex, "No new bet");
        
        uint256 amountInXIV;
        
        for(uint256 i = lastIndex; i < betCounter[user]; i++) {
            BettingLibrary.BettingDetailsOne storage betOne = userBetsOne[user][i];
            BettingLibrary.BettingDetailsTwo storage betTwo = userBetsTwo[user][i];
            
            if (!betTwo.isClaimed && (block.timestamp > betTwo.endTime)) {
                uint256 amount = uint256(betOne.amount);
                uint256 reward = uint256(betTwo.reward);
                
                if((betOne.status == 1)) {
                    if ((betOne.betTokenAddress != address(XIV)) && (betOne.priceInXIV > 0)) {
                        if (betOne.betTokenAddress == address(1)) {
                            amountInXIV += ((amount * uint256(betOne.priceInXIV) * reward) / (10 ** 20));
                        } else {
                            amountInXIV += ((amount * uint256(betOne.priceInXIV) * reward) / (100 * (10 ** (IERC20(betOne.betTokenAddress).decimals()))));
                        }
                    } else {
                        amountInXIV += (amount * reward) / 100;
                    }
                }
            }
        }
        
        return amountInXIV;
    }

    function addCoins(uint _coinType, uint planType, address coinAddress) external onlyOwner typeValidation(_coinType, planType) {
        require(coinAddress != address(0), "Invalid");
        require(!coinStatus[coinAddress][_coinType][planType], "Already added");
        
        uint counter;

        if (_coinType == 1) {
            counter =  defiCoinsCounter;
            defiCoinsCounter++;
        } else if (_coinType == 2) {
            counter =  chainCoinsCounter;
            chainCoinsCounter++;
        } else {
            counter =  NFTCoinsCounter;
            NFTCoinsCounter++;
        }
    
        coins[_coinType][planType][counter] = coinAddress;
        coinStatus[coinAddress][_coinType][planType] = true;
        emit Addcoins(_coinType, planType, counter, true, coinAddress);
    }

    function changeCoinStaus(address coinAddress, uint coinType, uint planType, bool status) external onlyOwner planValidation(coinType, planType) {
        
        if (coinStatus[coinAddress][coinType][planType] != status) {
            coinStatus[coinAddress][coinType][planType] = status;
            emit CoinStatus(coinAddress, coinType, planType, status);
        }
    }

    function updateOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0));
        oracle = IOracleWrapper(_oracle);
    }
    
    function updateMiniStakeAmount(uint256 _miniStakeAmount ) external onlyOwner {
        miniStakeAmount  = _miniStakeAmount ;
    }
    
    function updateMaxStakeAmount(uint256 _maxStakeAmount ) external onlyOwner amountValidation(_maxStakeAmount) {
        maxStakeAmount  = _maxStakeAmount ;
    }

    function updateBetFactorLP(uint256 _betFactorLP) external onlyOwner amountValidation(_betFactorLP) {
        betFactorLP = _betFactorLP;
    }

    function updateMaxBetAmount(uint256 _maxBetAmount) external onlyOwner amountValidation(_maxBetAmount) {
        maxBetAmount = _maxBetAmount;
    }

    function updateMinBetAmount(uint256 _miniBetAmount) external onlyOwner {
        miniBetAmount = _miniBetAmount;
    }
    
    function setPlanDetails(uint8[4] memory drop, uint16[4] memory reward, uint8[4] memory risk) public onlyOwner {
        require(risk.length > 0 && risk.length == drop.length, "Invalid");
        
        for (uint256 i; i < drop.length; i++) {
            plans[i].setPlan(uint256(reward[i]), uint256(risk[i]), uint256(drop[i]));
        }
        
        planCounter = drop.length;
    }
    
    function setReward(uint256 count, uint _reward) external onlyOwner countValidation(count, planCounter) {
        plans[count].setReward(_reward);
    }
    
    function setRisk(uint256 count, uint _risk) external onlyOwner countValidation(count, planCounter) {
        plans[count].setRisk(_risk);
    }
    
    function setDropValue(uint256 count, uint _drop) external onlyOwner countValidation(count, planCounter) {
        plans[count].setDrop(_drop);
    }
    
    function setStatus(uint256 count, bool status) external onlyOwner countValidation(count, planCounter) {
        plans[count].setStatus(status);
    }
    
    function setMultiTokenStatus(bool status) external onlyOwner {
        if (isMultiTokenActive != status) {
            isMultiTokenActive = status;
        }
    }
    
    function setPlanDays(uint256 index, uint256 planDays) external onlyOwner {
        require(index >= 0 && (index <= planDaysCounter));
            
        if ((index == planDaysCounter) && (planDays != 0)) {
            planDaysIndexed[index] = planDays;
            planDaysCounter++;
        } else {
            planDaysIndexed[index] = planDays;
        }
    }
    
    function addPlan(uint256 _reward, uint256 _risk, uint256 _drop, bool status) external onlyOwner {
        uint256 count = planCounter;
        
        PlanLibrary.PlanDetails storage plan = plans[count];
        
        plan.setReward(_reward);
        plan.setRisk(_risk);
        plan.setDrop(_drop);
        plan.setStatus(status);
        planCounter++;
    }

    function checkCoinStatus(address _coin, uint256 _coinType, uint256 _planType) external view returns (bool) {
        return coinStatus[_coin][_coinType][_planType];
    }
    
    function setBufferTime(uint256 time) public onlyOwner {
        bufferTime = time;
    }
    
    function setPenalty(uint256 value, uint256 _days, uint256 planDaysIndex) external onlyOwner {
        require(value >= 0 && value <= 100);
        
        penalty[planDaysIndex][_days] = value;
        
    }
    
    function setRevokeComissionAddress(address newAddress) external onlyOwner {
        require(newAddress != address(0));
        revokeComissionAddress = newAddress;
    }
    
    function setMaxWalks(uint256 value) external onlyOwner amountValidation(value) {
        maxWalks = value;
    }
    
    function setBetFees(uint256 fees) external onlyOwner {
        require(fees >= 0 && fees <= 100);
        betFees = fees;
    }
    
    function setThreshold(uint256 value) external onlyOwner amountValidation(value) {
        threshold = value;
    }
    
    function getPriceInXIV(address betToken) public view returns (uint256 priceInXIV) {
        if (betToken == address(XIV)) {
            return priceInXIV = 1;
        }
        return priceInXIV = ((oracle.getPrice(betToken, address(usdt)) * (10 ** 18)) / oracle.getPrice(address(XIV), address(usdt)));
    }
}

