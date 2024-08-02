// SPDX-License-Identifier: MIT 

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract StakingContract is Ownable, ReentrancyGuard {
    IERC20 StakingToken;
    IERC20 RewardToken;
    
    uint256 public rewardTokenSupply;
    uint256 public totalStakedToken;

    struct info {
        uint256 amount;
        uint256 lastClaim;
        uint256 stakedTime;
        uint32 duration;
        uint32 rates;
        uint256 position;
        uint256 earned;    
    }

    uint8 public constant POOL_LEN = 4;
    uint256 public constant MIN_STAKE_AMOUNT = 0;

    uint32[4] public durations;
    uint32[4] public rates;

    mapping(address => mapping(uint256 => info)) public userStaked; // USER > ID > INFO
    mapping(address => uint256) public userID;
    mapping(address => uint256) public userTotalEarnedReward;
    mapping(address => uint256) public userTotalStaked;
    mapping(address => uint256[]) public stakedIDs;

    bool public paused;

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
        durations = [30 days, 90 days, 180 days, 360 days];
        rates = [15, 30, 100, 300];
    }

    function addRewardToken(uint256 _amount) public onlyOwner {
        // transfer from (need allowance)
        RewardToken.transferFrom(msg.sender, address(this), _amount);
        rewardTokenSupply += _amount;

        emit RewardTokenAdded(msg.sender, _amount);
    }

    function removeRewardToken(uint256 _amount) public onlyOwner {
        require(_amount <= rewardTokenSupply, "Invalid amount");
        
        RewardToken.transfer(msg.sender, _amount);
        rewardTokenSupply -= _amount;

        emit RewardTokenRemoved(msg.sender, _amount);
    }

    function updateDurations(uint32[4] memory _durations) public onlyOwner {
        durations = _durations;

        emit UpdatedDurations(msg.sender);
    }

    function updateRates(uint32[4] memory _rates) public onlyOwner {
        rates = _rates;

        emit UpdatedRates(msg.sender);
    }

    function setRewardToken(address _rewardToken) public onlyOwner {
        require(_rewardToken != address(0), "Invalid address");

        RewardToken = IERC20(_rewardToken);
    }

    function setStakingToken(address _stakingToken) public onlyOwner {
        require(_stakingToken != address(0), "Invalid address");

        StakingToken = IERC20(_stakingToken);
    }

    function stake(uint256 _amount, uint32 _durationCode) public nonReentrant {
        require(!paused, "Paused");
        require( _amount > 0 && _amount > MIN_STAKE_AMOUNT, "Invalid amount");
        require(_durationCode < POOL_LEN, "Invalid duration");

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
        stakedIDs[msg.sender].push(userID[msg.sender]);

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

    function unStake(uint256 _id) public nonReentrant {
        claim(_id);

        info storage userInfo = userStaked[msg.sender][_id];
        require(userInfo.amount != 0, "Invalid ID");
        require(block.timestamp - userInfo.stakedTime >= userInfo.duration, "Not unlocked yet");
        require(StakingToken.balanceOf(address(this)) >= userInfo.amount, "Insufficient token balance");

        StakingToken.transfer(msg.sender, userInfo.amount);

        popSlot(_id);

        delete userStaked[msg.sender][_id];

        totalStakedToken -= userInfo.amount;
        userTotalStaked[msg.sender] -= userInfo.amount;

        emit Unstaked(msg.sender, _id);
    }

    function unStake(uint256 _amount, uint256 _id) public nonReentrant {
        claim(_id);

        info storage userInfo = userStaked[msg.sender][_id];
        require(userInfo.amount != 0 && _amount <= userInfo.amount, "Invalid ID");
        require(block.timestamp - userInfo.stakedTime >= userInfo.duration, "Not unlocked yet");

        if (_amount == userInfo.amount) {
            popSlot(_id);
            delete userStaked[msg.sender][_id];
        } else {
            userInfo.amount -= _amount;
        }

        require(StakingToken.balanceOf(address(this)) >= _amount, "Insufficient token balance");

        StakingToken.transfer(msg.sender, _amount);

        totalStakedToken -= _amount;
        userTotalStaked[msg.sender] -= _amount;

        emit Unstaked(msg.sender, _id);
    }

    function claimReward(uint256 _id) public nonReentrant(){
        info storage userInfo = userStaked[msg.sender][_id];
        require (block.timestamp - userInfo.stakedTime >= userInfo.duration, "Locked still.");

        claim(_id);

        emit ClaimReward(msg.sender, block.timestamp, _id);
    }

    function claimRewardAll() public nonReentrant {
        uint amount = 0;
        uint length = stakedIDs[msg.sender].length;
        for(uint i=0; i<length; i++){
            info storage userInfo = userStaked[msg.sender][stakedIDs[msg.sender][i]];
            if (userInfo.amount == 0)
                continue;

            if (block.timestamp - userInfo.stakedTime < userInfo.duration)
                continue;

            uint amountIndex = getReward(msg.sender, stakedIDs[msg.sender][i]);
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

    // Getter
    function getReward(address _user, uint256 _id) public view returns(uint256) {
        info storage userInfo = userStaked[_user][_id];
        uint256 timeDiff = block.timestamp - userInfo.lastClaim;

        uint256 reward = userInfo.amount * timeDiff * userInfo.rates / (userInfo.duration * 100);

        return reward;
    }

    function getAllReward(address _user) public view returns(uint) {
        uint amount = 0;
        uint length = stakedIDs[_user].length;
        for(uint i=0; i<length; i++){
            info storage userInfo = userStaked[_user][stakedIDs[_user][i]];
            if (userInfo.amount == 0)
                continue;

            uint amountIndex = getReward(_user, stakedIDs[_user][i]);
            amount += amountIndex;
        }

        return amount;
    }

    function claimableReward(address _user, uint _id) public view returns(uint) {
        info storage userInfo = userStaked[_user][_id];

        if (block.timestamp - userInfo.stakedTime < userInfo.duration)
            return 0;

        return getReward(_user, _id);
    }

    function claimableAllReward(address _user) public view returns(uint) {
        uint amount = 0;
        uint length = stakedIDs[_user].length;
        for(uint i=0; i<length; i++){
            info storage userInfo = userStaked[_user][stakedIDs[_user][i]];
            if (userInfo.amount == 0)
                continue;

            if (block.timestamp - userInfo.stakedTime < userInfo.duration)
                continue;

            uint amountIndex = getReward(_user, stakedIDs[_user][i]);
            amount += amountIndex;
        }

        return amount;
    }

    // private functions
    function claim(uint256 _id) private {
        uint256 amount = 0;
        require(userStaked[msg.sender][_id].amount != 0, "Invalid ID");

        amount = getReward(msg.sender, _id);

        require(RewardToken.balanceOf(address(this)) >= amount, "Insufficient token balance");

        RewardToken.transfer(msg.sender, amount);

        info storage userInfo = userStaked[msg.sender][_id];
        userInfo.lastClaim = block.timestamp;
        userInfo.earned += amount;

        userTotalEarnedReward[msg.sender] += amount;
        rewardTokenSupply -= amount;
    }

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

