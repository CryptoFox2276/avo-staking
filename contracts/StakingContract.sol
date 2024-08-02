// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingContract is Ownable, ReentrancyGuard {
    IERC20 StakingToken;
    IERC20 RewardToken;
    
    // Total reward token supply and total tokens staked
    uint256 public rewardTokenSupply;
    uint256 public totalStakedToken;

    // Struct to hold information about user stakes
    struct info {
        uint256 amount;         // Amount staked
        uint256 lastClaim;      // Last claim time for rewards
        uint256 stakedTime;     // Time when the user staked
        uint32 duration;        // Duration for which token are staked
        uint32 rate;            // Rate of reward
        uint position;          // Position in the staked IDs array
        uint256 earned;         // Total rewards earned
    }

    uint8 public constant MAX_POOL_LEN = 4;         // Maximum number of staking options available
    uint32 public constant PERCENT_UNIT = 1000;     // 1000 represents 100%
    uint32 public constant MAX_LIMIT_RATE = 600;    // Maximum rate cap is 60%
    uint256 public constant MIN_STAKE_AMOUNT = 0;   // Minimum stake that can be accepted

    uint32[4] public durations;     // Array for staking durations
    uint32[4] public rates;         // Array for staking rates

    mapping(address => uint256) public userID;
    mapping(address => uint256) public userTotalStaked;
    mapping(address => uint256) public userTotalEarnedReward;
    mapping(address => mapping(uint256 => info)) public userStaked; // USER > ID > INFO
    mapping(address => uint256[]) public stakedIDs;                 // Array to track staking IDs for each user

    bool public paused;     // Boolean flag to pause the contract

    event Staked(
        address indexed _user,
        uint256 _amount,
        uint256 _stakedTime,
        uint32 _duration,
        uint32 _rate,
        uint256 _stakedIndex
    );
    event Unstaked(address indexed _user, uint256 _stakedIndex);
    event ClaimReward(address indexed _from, uint256 _claimedTime, uint256 _stakedIndex);
    event ClaimRewardAll(address indexed _from, uint256 _claimedTime, uint256 _amount);
    event Paused();
    event Unpaused();
    event RewardTokenAdded(address indexed _from, uint256 _amount);
    event RewardTokenRemoved(address indexed _to, uint256 _amount);
    event UpdatedDurations(address indexed _from);
    event UpdatedRates(address indexed _from);

    constructor(address _stakingToken, address _rewardToken) {
        StakingToken = IERC20(_stakingToken);
        RewardToken = IERC20(_rewardToken);
        durations = [30 days, 90 days, 180 days, 360 days]; // [1 month, 3 months, 6 months, 12 months]
        rates = [15, 30, 100, 300]; // [1.5%, 3%, 10%, 30%]
    }

    function addRewardToken(uint256 _amount) public onlyOwner {
        RewardToken.transferFrom(msg.sender, address(this), _amount); // Transfer reward token
        rewardTokenSupply += _amount;       // Increase total reward token supply

        emit RewardTokenAdded(msg.sender, _amount);
    }

    function removeRewardToken(uint256 _amount) public onlyOwner {
        require(_amount <= rewardTokenSupply, "Invalid amount");
        
        RewardToken.transfer(msg.sender, _amount);  // Transfer back the tokens
        rewardTokenSupply -= _amount;               // Decrease the supply

        emit RewardTokenRemoved(msg.sender, _amount);
    }

    function setDurations(uint32[4] memory _durations) public onlyOwner {
        durations = _durations; // Set new durations

        emit UpdatedDurations(msg.sender);
    }

    function setRates(uint32[4] memory _rates) public onlyOwner {
        rates = _rates; // Set new rates

        emit UpdatedRates(msg.sender);
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        require(_rewardToken != address(0), "Invalid address");

        RewardToken = IERC20(_rewardToken); // Set new reward token
    }

    function setStakingToken(address _stakingToken) public onlyOwner {
        require(_stakingToken != address(0), "Invalid address");

        StakingToken = IERC20(_stakingToken);
    }

    // Function for users to stake token with a specified duration
    function stake(uint256 _amount, uint32 _durationCode) public nonReentrant {
        require(!paused, "Paused");
        require( _amount > 0 && _amount > MIN_STAKE_AMOUNT, "Invalid stake amount");
        require(_durationCode < MAX_POOL_LEN, "Invalid duration");

        // Increment the user ID and create a new stake record
        userID[msg.sender]++;
        userStaked[msg.sender][userID[msg.sender]] = info(
            _amount,
            block.timestamp,
            block.timestamp,
            durations[_durationCode],
            rates[_durationCode],
            stakedIDs[msg.sender].length,
            0
        );
        stakedIDs[msg.sender].push(userID[msg.sender]); // Store the new stake ID

        require(StakingToken.transferFrom(msg.sender, address(this), _amount), "Insufficient balance");

        totalStakedToken += _amount;
        userTotalStaked[msg.sender] += _amount;

        emit Staked(
            msg.sender,
            _amount,
            block.timestamp,
            durations[_durationCode],
            rates[_durationCode],
            stakedIDs[msg.sender].length - 1
        );
    }

    // Function for users to unstake their token
    function unStake(uint256 _id) public nonReentrant {
        claim(_id);

        info storage userInfo = userStaked[msg.sender][_id];
        require(userInfo.amount != 0, "Invalid ID");
        require(block.timestamp - userInfo.stakedTime >= userInfo.duration, "Not unlocked yet");
        require(StakingToken.balanceOf(address(this)) >= userInfo.amount, "Insufficient token balance");

        StakingToken.transfer(msg.sender, userInfo.amount); // Transfer the staked tokens back to the user
        popSlot(_id);   // Remove the stake from the IDs array

        delete userStaked[msg.sender][_id];

        totalStakedToken -= userInfo.amount;
        userTotalStaked[msg.sender] -= userInfo.amount;

        emit Unstaked(msg.sender, _id);
    }

    // Function for the owner to increase the reward rate of a specific user's stake
    function increaseRate(address _user, uint256 _id, uint32 _increaseRate) public nonReentrant onlyOwner {
        info storage userInfo = userStaked[_user][_id];
        if (userInfo.rate + _increaseRate <= MAX_LIMIT_RATE) {
            userInfo.rate += _increaseRate;
        }
    }

    // Function for the owner to increase the reward rates for all stakes of a user
    function increaseRateAll(address _user, uint32 _increaseRate) public nonReentrant onlyOwner {
        uint256 length = stakedIDs[_user].length;
        for(uint32 i=0; i<length; i++){
            increaseRate(_user, stakedIDs[_user][i], _increaseRate);
        }
    }

    // Function for users to claim rewards for a specific stake after the duration has passed
    function claimReward(uint256 _id) public nonReentrant {
        info storage userInfo = userStaked[msg.sender][_id];
        require (block.timestamp - userInfo.stakedTime >= userInfo.duration, "Locked still");

        claim(_id); // Claim rewards

        emit ClaimReward(msg.sender, block.timestamp, _id);
    }

    // Function for users to claim rewards from all stakes
    function claimAllReward() public nonReentrant {
        uint256 amount = 0;
        uint256 length = stakedIDs[msg.sender].length;
        for(uint32 i=0; i < length; i++){
            info storage userInfo = userStaked[msg.sender][stakedIDs[msg.sender][i]];
            if (userInfo.amount == 0)
                continue;

            if (block.timestamp - userInfo.stakedTime < userInfo.duration)
                continue;

            uint256 amountIndex = getReward(msg.sender, stakedIDs[msg.sender][i]);  // Calculate rewards
            if (amountIndex == 0)
                continue;

            userInfo.lastClaim = block.timestamp;
            userInfo.earned += amountIndex;
            amount += amountIndex;
        }

        RewardToken.transfer(msg.sender, amount);
        rewardTokenSupply -= amount;
        userTotalEarnedReward[msg.sender] += amount;

        emit ClaimRewardAll(msg.sender, block.timestamp, amount);
    }

    // View functions
    function getReward(address _user, uint256 _id) public view returns(uint256) {
        info storage userInfo = userStaked[_user][_id];

        uint256 reward = userInfo.amount * userInfo.rate / PERCENT_UNIT;

        return reward;
    }

    function getAllReward(address _user) public view returns(uint256) {
        uint256 amount = 0;
        uint256 length = stakedIDs[_user].length;
        for(uint32 i = 0; i < length; i++){
            info storage userInfo = userStaked[_user][stakedIDs[_user][i]];
            if (userInfo.amount == 0)
                continue;

            uint256 amountIndex = getReward(_user, stakedIDs[_user][i]);
            amount += amountIndex;
        }

        return amount;
    }

    function claimableReward(address _user, uint256 _id) public view returns(uint256) {
        info storage userInfo = userStaked[_user][_id];

        if (block.timestamp - userInfo.stakedTime < userInfo.duration)
            return 0;

        return getReward(_user, _id);
    }

    function claimableAllReward(address _user) public view returns(uint256) {
        uint256 amount = 0;
        uint256 length = stakedIDs[_user].length;
        for(uint256 i=0; i<length; i++){
            info storage userInfo = userStaked[_user][stakedIDs[_user][i]];
            if (userInfo.amount == 0)
                continue;

            if (block.timestamp - userInfo.stakedTime < userInfo.duration)
                continue;

            uint256 amountIndex = getReward(_user, stakedIDs[_user][i]);
            amount += amountIndex;
        }

        return amount;
    }

    // Function to handle the actual reward claiming process
    function claim(uint256 _id) private {
        uint256 amount = 0;
        require(userStaked[msg.sender][_id].amount != 0, "Invalid ID"); // Ensure valid ID

        amount = getReward(msg.sender, _id);

        require(RewardToken.balanceOf(address(this)) >= amount, "Insufficient token balance");

        RewardToken.transfer(msg.sender, amount);   // Transfer rewards to user

        info storage userInfo = userStaked[msg.sender][_id];
        userInfo.lastClaim = block.timestamp;
        userInfo.earned += amount;

        userTotalEarnedReward[msg.sender] += amount;    // Update user's total rewards earned
        rewardTokenSupply -= amount;    // Reduce reward token supply
    }

    // Function to remove an ID from the user's staked IDs
    function popSlot(uint256 _id) private {
        uint256 length = stakedIDs[msg.sender].length;
        bool replace = false;
        for (uint256 i = 0 ; i < length ; i ++ ) {
            if (stakedIDs[msg.sender][i] == _id) {
                replace = true;
            }
            if (replace && i < length - 1) {
                stakedIDs[msg.sender][i] = stakedIDs[msg.sender][i + 1];
            }
        }
        stakedIDs[msg.sender].pop();
    }

    // Setter
    function pause() public onlyOwner {
        paused = true;

        emit Paused();
    }

    function unPause() public onlyOwner {
        paused = false;

        emit Unpaused();
    }
}

