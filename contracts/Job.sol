// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAgent {
    function getLevelOfAgent(address agent) external returns(uint256);
}

contract Task1 {
    IAgent public agentContract;
    address owner;

    struct Job {
        bool tgrEarning;
        uint256 escrowAmount;
        uint8 status;
        uint256 defineTime;
        address buyer;
        string title;
        string description;
        uint256 endTime;
    }

    struct AgentsForJob {
        address seller;
        address[] bidders;
        address[] approvalValidators;
        address[] approvalDeniers;
        address[] completionValidators;
        address[] completionDeniers;
        address[] tempValidators;
        address[] tempDeniers;
    }

    mapping(uint256=>Job) public jobList;
    mapping(uint256=>AgentsForJob) private agentsListForJobs;
    uint256 public numberOfJobs;
    IERC20 public htzToken;
    IERC20 public tgrToken;
    uint256 duration = 10;

    event validatorsOfJobAdded(address validator);
    event validatorsOfCompletenessAdded(address validator);
    event getStatusOfJob(uint jobId);

    constructor() {
        owner = msg.sender;
    }

    //  Set TGR Token and HTZ tokens
    function setTokens(address tgrTokenAddress, address htzTokenAddress) external {
        require(msg.sender == owner, 'You are not allowed to do this action');
        tgrToken = IERC20(tgrTokenAddress);
        htzToken = IERC20(htzTokenAddress);
    }
    //  Set Agent Contract
    function setAgentContract(IAgent _agentContract) external {
        require(address(_agentContract) != address(0), "Invalid address.");
        agentContract = _agentContract;
    }

    //  Define Job
    function defineJob(
        string calldata title,
        string calldata description,
        bool tgrEarning,
        uint256 escrowAmount
        // uint8 jobLevel
    ) external canDefineJob {
        Job storage jobItem = jobList[numberOfJobs];

        jobItem.tgrEarning = tgrEarning;
        jobItem.escrowAmount = escrowAmount * 10 ** 18;
        jobItem.status = 0;
        jobItem.defineTime = block.timestamp;
        jobItem.buyer = msg.sender;
        jobItem.title = title;
        jobItem.description = description;
        jobItem.endTime = 0;

        //increase the number of Jobs added
        numberOfJobs++;
        //Deposit Escrow Amount to this contract
        htzToken.transferFrom(msg.sender, address(this), escrowAmount);
        jobItem.status = 1;

        //  if job is not TGR Earning, directly posted
        if (!tgrEarning) {
            jobItem.status = 6;
        }
    }

    // Check whether agent have tgr to get in specific job
    function checkTgrClaim(address agent, uint jobId) external view returns(uint){
        Job storage job = jobList[jobId];
        if (job.tgrEarning) {
            if (job.endTime < block.timestamp && job.endTime > 0) {
                bool participated = false;
                if (job.status == 2 || job.status == 3 ) {
                    participated = checkDuplicatersOfApproval(agent, jobId);
                } else if (job.status == 9 || job.status == 10) {
                    participated = checkDuplicatersOfCompletion(agent, jobId);
                } else {
                    return 0;
                }
                if(participated) {
                    return job.escrowAmount / 1000;
                }
            } else {
             return 0;
            }
        }
        return 0;
    }

    //   Add msg sender to the list of VALIDATORs of job APPROVAL
    function addValidatorsForApproval(uint256 jobId) public availableForApproval(jobId){
        AgentsForJob storage agents = agentsListForJobs[jobId];
        bool duplicated = checkDuplicatersOfApproval(msg.sender, jobId);
        if (duplicated) {
            revert('You have already participated in job approval');
        } else {
            agents.approvalValidators.push(msg.sender);
            agents.tempValidators.push(msg.sender);
            _refreshStatus(jobId, true);
        }
    }

    //  Add msg sender to the list of DENIERs of job APPROVAL
    function addDeniersForApproval(uint jobId) public availableForApproval(jobId){
        AgentsForJob storage agents = agentsListForJobs[jobId];
        bool duplicated = checkDuplicatersOfApproval(msg.sender, jobId);
        if (duplicated) {
            revert('You have already participated in job approval');
        } else {
            agents.approvalDeniers.push(msg.sender);
            agents.tempDeniers.push(msg.sender);
            _refreshStatus(jobId, false);
        }
    }

    //   Add msg sender to the list of VALIDATORs of job ESCROW
    function addValidatorsForEscrow(uint jobId) public availableForCompletion(jobId){
        AgentsForJob storage agents = agentsListForJobs[jobId];
        bool duplicated = checkDuplicatersOfCompletion(msg.sender, jobId);
        if (duplicated) {
            revert('You have already participated in job completion');
        } else {
            agents.completionValidators.push(msg.sender);
            agents.tempValidators.push(msg.sender);
            _refreshStatus(jobId, true);
        }
    }

    //   Add msg sender to the list of VALIDATORs of job ESCROW
    function addDeniersForEscrow(uint jobId) public availableForCompletion(jobId){
        AgentsForJob storage agents = agentsListForJobs[jobId];
        bool duplicated = checkDuplicatersOfCompletion(msg.sender, jobId);
        if (duplicated) {
            revert('You have already participated in job completion');
        } else {
            agents.completionDeniers.push(msg.sender);
            agents.tempDeniers.push(msg.sender);
            _refreshStatus(jobId, false);
        }
    }

    //  check whether agent already participated in approval
    function checkDuplicatersOfApproval(address agent, uint jobId) public view returns(bool){
        AgentsForJob memory agents = agentsListForJobs[jobId];
        for(uint i = 0; i < agents.approvalDeniers.length; i++) {
            if (agents.approvalDeniers[i] == agent) {
                return true;
            }
        }
        for(uint i = 0; i < agents.approvalValidators.length; i++) {
            if (agents.approvalValidators[i] == agent) {
                return true;
            }
        }
        return false;
    }

    //  check whether agent already participated in approval
    function checkDuplicatersOfCompletion(address agent, uint jobId) public view returns(bool){
        AgentsForJob memory agents = agentsListForJobs[jobId];
        for(uint i = 0; i < agents.completionDeniers.length; i++) {
            if (agents.completionDeniers[i] == agent) {
                return true;
            }
        }
        for(uint i = 0; i < agents.completionValidators.length; i++) {
            if (agents.completionValidators[i] == agent) {
                return true;
            }
        }
        return false;
    }

    function _emptyTempAgents(uint jobId) private {
        AgentsForJob storage agents = agentsListForJobs[jobId];
        delete agents.tempDeniers;
        delete agents.tempValidators;
    }

    /** Update Job status whenever validators or deniers added
    for job approval and completeness */
    function _refreshStatus(uint jobId, bool validationValue) private {
        AgentsForJob storage agents = agentsListForJobs[jobId];
        Job storage job = jobList[jobId];
        uint totalTempAgents = agents.tempValidators.length + agents.tempDeniers.length;
        if(totalTempAgents % 3 == 0) {
            job.endTime = block.timestamp + duration;
            if (job.status == 1) {
                if (agents.tempValidators.length > agents.tempDeniers.length) {
                    job.status = 2;
                } else {
                    job.status = 3;
                }
                _emptyTempAgents(jobId);
            } else if (job.status == 8) {
                if (agents.tempValidators.length > agents.tempDeniers.length) {
                    job.status = 9;
                } else {
                    job.status = 10;
                }
                _emptyTempAgents(jobId);
            }
        } else {
            if (job.status == 2 && !validationValue) {
                job.status = 1;
                job.endTime = 0;
            } else if (job.status == 3 && validationValue) {
                job.status = 1;
                job.endTime = 0;
            } else if (job.status == 9 && !validationValue) {
                job.status = 8;
                job.endTime = 0;
            } else if (job.status == 10 && validationValue) {
                job.status = 8;
                job.endTime = 0;
            }
        }
    }

    // Set Job status to in progress by buyer
    function setJobInProgress(uint jobId) external onlyBuyer(jobId) {
        Job storage job = jobList[jobId];
        // Condition to define whether it is ready to be in progress
        if (job.status == 2 && job.endTime > 0 && (job.endTime < block.timestamp)) {
            job.status = 7;
        } else if (job.status == 5) {
            job.status = 7;
        }
    }

    //Assign seller to job
    function assignSellerToJob(uint jobId, address seller) external onlyBuyer(jobId) {
        AgentsForJob storage agents = agentsListForJobs[jobId];
        agents.seller = seller;
    }
    // Remove Job... called by Buyer while job is in progress
    function removeJobByBuyer(uint jobId) external onlyBuyer(jobId) canRemoveJobByBuyer(jobId){
        Job storage job = jobList[jobId];
        job.status = 6;
    //  Return Escrow Amount to service buyer
        htzToken.transfer(job.buyer, job.escrowAmount);
    }

    // Claim Escrow ... called by Seller
    function claimEscrow(uint jobId) external canClaimEscrow(jobId){
        Job storage job = jobList[jobId];
        job.status = 8;
    }

    // Remove Job ... called by Contract Owner when job approval is denied
    function treatApprovalByOwnerAndSlash(uint jobId) external {
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];
        require(owner == msg.sender, 'Only contract owner can slash losers');
        if (job.tgrEarning) {
            require(job.endTime < block.timestamp, 'It is still under approval status at the moment');
            if (job.status == 2) {
                agents.approvalDeniers.push(job.buyer);
                for(uint i = 0; i < agents.approvalDeniers.length; i++) {
                    _slashTgrOfAgents(agents.approvalDeniers[i], job.escrowAmount);
                }
                for(uint i = 0; i < agents.approvalValidators.length; i++) {
                    _prizeToAgents(agents.approvalValidators[i], job.escrowAmount);
                }
                job.status = 7;
            } else if (job.status == 3) {
                agents.completionValidators.push(job.buyer);
                for(uint i = 0; i < agents.approvalValidators.length; i++) {
                    _slashTgrOfAgents(agents.approvalValidators[i], job.escrowAmount);
                }
                for(uint i = 0; i < agents.approvalDeniers.length; i++) {
                    _prizeToAgents(agents.approvalDeniers[i], job.escrowAmount);
                }
                job.status = 12;
            }
        } else {
            require(job.status == 8, 'Service Seller need to claim the escrow.');
            _transferEscrowToSeller(jobId);
            job.status = 12;
        }
    }

    //Release Escrow by buyer or not TGR Earning
    function treatEscrowOnCompletionAndSlash(uint jobId) external {
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];
        require(owner == msg.sender, 'Only this contract owner can carry out the action');
        if (job.tgrEarning) {
            require(job.endTime < block.timestamp, 'It is still under dispute at the moment');
            if (job.status == 9) {
                _transferEscrowToSeller(jobId);
                for(uint i = 0; i < agents.completionDeniers.length; i++) {
                    _slashTgrOfAgents(agents.completionDeniers[i], job.escrowAmount);
                }
                for(uint i = 0; i < agents.completionValidators.length; i++) {
                    _prizeToAgents(agents.completionValidators[i], job.escrowAmount);
                }
                job.status = 12;
            } else if (job.status == 10) {
                _refundEscrowToBuyer(jobId);
                for(uint i = 0; i < agents.completionValidators.length; i++) {
                    _slashTgrOfAgents(agents.completionValidators[i], job.escrowAmount);
                }
                for(uint i = 0; i < agents.completionDeniers.length; i++) {
                    _prizeToAgents(agents.completionDeniers[i], job.escrowAmount);
                }
                job.status = 12;
            }
        } else {
            require(job.status == 8, 'Service Seller need to claim the escrow.');
            _transferEscrowToSeller(jobId);
            job.status = 12;
        }

    }

    function _slashTgrOfAgents(address agent, uint escrowAmount) private {
        uint256 tgrAmountToBeSlashed = escrowAmount / 1000;
        tgrToken.transferFrom(agent, address(this), tgrAmountToBeSlashed);
    }

    function _prizeToAgents(address agent, uint escrowAmount) private {
        uint256 tgrAmountToBeSlashed = escrowAmount / 1000;
        tgrToken.transfer(agent, tgrAmountToBeSlashed);
    }
    function _refundEscrowToBuyer(uint jobId) private {
        Job storage job = jobList[jobId];
        htzToken.transfer(job.buyer, job.escrowAmount);
    }

    function _transferEscrowToSeller(uint jobId) private {
        AgentsForJob storage agents = agentsListForJobs[jobId];
        Job storage job = jobList[jobId];
        htzToken.transfer(agents.seller, job.escrowAmount);
    }

    modifier canDefineJob()  {
        uint256 level = agentContract.getLevelOfAgent(msg.sender);
        require(level >= 4, 'Your level is below 4 and not allowed to post jobs');
        _;
    }

    modifier canClaimEscrow(uint jobId) {
        Job storage job = jobList[jobId];
        AgentsForJob storage agent = agentsListForJobs[jobId];
        require(agent.seller == msg.sender, 'Only service seller of this job can claim escrow.');
        require(job.status != 6, 'This job is already removed by buyer.');
        require(job.status < 8, 'It is already under completion dispute mode at the moment.');
        _;
    }

    modifier canRemoveJobByBuyer(uint jobId) {
        Job storage job = jobList[jobId];
        require(job.status !=6, 'This job is already removed...');
        bool result = false;
        if (job.tgrEarning && job.status == 7) {
            result = true;
        } else if (!job.tgrEarning && job.status == 5) {
            result = true;
        }
        require(result, 'Not available to remove the job at the moment: buyer');
        _;
    }

    modifier onlyBuyer(uint jobId) {
        Job storage job = jobList[jobId];
        require(job.buyer == msg.sender, 'Only service buyer can carry out the action');
        _;
    }

    modifier availableForApproval(uint jobId) {
        Job storage job = jobList[jobId];
        require(job.status >= 1 && job.status < 4, 'This job is not available for agents to approval.');
        _;
    }

    modifier availableForCompletion(uint jobId) {
        Job storage job = jobList[jobId];
        require(job.status >= 8 && job.status < 11, 'This job is not available for agents to dispute completion.');
        _;
    }

}