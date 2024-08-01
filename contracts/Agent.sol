// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract Agent {
    using SafeERC20 for IERC20;
    address burn_address = 0x000000000000000000000000000000000000dEaD;
    IERC20 public tgrToken; // governence token address
    mapping (uint256=>uint256) public levels; // key: value of level(such as "0", "1"), value: max token amount for the level
    uint256 public maxLevel = 0;
    address owner;
    address taskContract;

    struct PoolStaker {
        string profile_name; // name of the profile
        string img_uri; // logo image url from ipfs
        uint256 amount; // The tokens quantity the user has staked
        uint256 stakedTime; // The time at tokens staked
        uint256 latestUnstakedTime; // The latest time at tokens unstaked
    }

    uint256 public totalStaked;
    uint256 public lockedTime; // To lock the tokens in contract for definite time
    mapping(address => PoolStaker) public poolStakers;

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Burn(address indexed user, uint256 amount);
    event SlashedToken(address indexed user, uint256 amount);
    event PrizedToken(address indexed user, uint256 amount);
    event SaveNameAndLogo(address indexed user, string contract_name, string img_uri);

    constructor(address _taskContract, uint256 _lockedTime) {
        owner = msg.sender;
        taskContract = _taskContract;
        lockedTime = _lockedTime;
    }

    modifier isTaskContract() {
        require(msg.sender == taskContract, "Caller is not a taskContract");
        _;
    }

    function setToken(address tgrTokenAddress) external {
        require(msg.sender == owner, 'You are not allowed to do this action');
        tgrToken = IERC20(tgrTokenAddress);
    }

    function setLevels(uint256 level, uint256 maxAmount) external { // example: level=1, maxAmount=10*1e18
        require(msg.sender == owner, 'You are not allowed to do this action');
        if(level > maxLevel) {
            maxLevel = level;
        }
        levels[level] = maxAmount;
    }

    function getStakedAmountOfAgent(address agent) external view returns(uint256) {
        return poolStakers[agent].amount;
    }

    function getLevelOfAgent(address agent) external view returns(uint256) {
        // uint256 tokenBalance = tgrToken.balanceOf(agent); // to do with "staked"
        PoolStaker storage staker = poolStakers[agent];
        uint256 tokenBalance = staker.amount;
        
        if(maxLevel == 0) {
            return 0;
        }
        uint256 level = 0;
        for(uint256 i = 0; i <= (maxLevel); i++) {
            if (tokenBalance >= levels[i]) {
                level = i;
            }
        }
        return level;
    }

    function getMaxAmountOfLevel(uint256 _id) external view returns(uint256) {
        if(_id > maxLevel) _id = maxLevel;
        return levels[_id];
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "Insufficient Amount");
        
        uint256 userBalance = tgrToken.allowance(msg.sender, address(this));
        require(userBalance >= _amount, "Your balance is not enough");

        PoolStaker storage staker = poolStakers[msg.sender];

        staker.amount += _amount;
        staker.stakedTime = block.timestamp;
        totalStaked += _amount;
        tgrToken.safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(msg.sender, _amount);
    }


    function withdraw(uint256 _amount) external {
        require(_amount > 0, "Agent: Invalid Argument");        
        require(totalStaked >= _amount, "Agent: Insufficient amount");

        PoolStaker storage staker = poolStakers[msg.sender];
        require(staker.amount >= _amount, "Agent: Insufficient amount");
        require(block.timestamp > staker.stakedTime + lockedTime, "Agent: Time locked");
        staker.amount -= _amount;
        staker.latestUnstakedTime = block.timestamp;
        totalStaked -= _amount;
        tgrToken.transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function slashTokenOfAgent(address agent, uint256 slashAmount) external isTaskContract{
        PoolStaker storage staker = poolStakers[agent];
        if(staker.amount > slashAmount) staker.amount -= slashAmount;
        else staker.amount = 0;

        emit SlashedToken(agent, slashAmount);
    }

    function prizeTokenOfAgent(address agent, uint256 prizeAmount) external isTaskContract{
        PoolStaker storage staker = poolStakers[agent];
        staker.amount += prizeAmount;

        emit PrizedToken(agent, prizeAmount);
    }

    function saveNameAndLogo(string calldata contract_name, string calldata img_uri) external {
        PoolStaker storage staker = poolStakers[msg.sender];
        staker.profile_name = contract_name;
        staker.img_uri = img_uri;   
        emit SaveNameAndLogo(msg.sender, staker.profile_name, staker.img_uri);
    }
}