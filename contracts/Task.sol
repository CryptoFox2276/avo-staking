// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IAgent.sol";
import "./interfaces/ITask.sol";
import "hardhat/console.sol";

contract Task is ITask{
    using SafeERC20 for IERC20;

    IAgent public agentContract;
    address owner;

    uint256 MAX_DURATION = 300 seconds; // 2 days = 2 * 86400 seconds = 172800 seconds
    uint256 BURN_PERCENT = 25; // 25%;
    uint8 MAX_LIMIT_VALIDATORS = 3; // 11
    address burn_address = 0x000000000000000000000000000000000000dEaD;

    string[] jobTypes;
    Job[] jobList;
    mapping(uint256=>AgentsForJob) private agentsListForJobs;
    uint256 public numberOfJobs;
    IERC20 public htzToken;
    IERC20 public tgrToken;    
    uint256 duration = MAX_DURATION;
    uint256 submissionDisputeDuration = 500 seconds; // 3 days = 3 * 86400 seconds = 259200 seconds
    // JOB_STATUS public job_status;

    event validatorsOfJobAdded(address validator);
    event validatorsOfCompletenessAdded(address validator);
    event updateJobStatus(uint256 jobId, uint8 jobStatus);

    // Modifiers

    modifier onlyOwner() {
        require(msg.sender == owner, "Task: Only owner call");
        _;
    }

    modifier onlyBuyer(uint jobId) {
        require(jobList[jobId].buyer == msg.sender, 'Task: Not Buyer');
        _;
    }

    // modifier canRemoveJobByBuyer(uint jobId) {
    //     require(jobList[jobId].status !=6, 'Task: Already Removed');
    //     bool result = false;
    //     if (jobList[jobId].tgrEarning && jobList[jobId].status == 7) {
    //         result = true;
    //     } else if (!jobList[jobId].tgrEarning && jobList[jobId].status == 5) {
    //         result = true;
    //     }
    //     require(result, 'Task: Remove Not available');
    //     _;
    // }

    modifier availableForVerifying(uint jobId) {
        uint256 userLevel = agentContract.getLevelOfAgent(msg.sender);
        uint8 _status = jobList[jobId].status;

        require(userLevel != 0 && userLevel > jobList[jobId].jobLevel, "Task: Invalid User Level");
        require(jobList[jobId].buyer != msg.sender && agentsListForJobs[jobId].seller != msg.sender, "Task: Invalid User");
        require(_status == uint8(JOB_STATUS.VERIFYING) || _status == uint8(JOB_STATUS.VERIFYING_COMPLETED) || _status == uint8(JOB_STATUS.DISPUTE_COMPLETED), 'Task: Invalid Status');
        _;
    }

    // modifier availableForValidating(uint256 jobId) {
    //     uint256 userLevel = agentContract.getLevelOfAgent(msg.sender);
    //     require(userLevel != 0 && userLevel >= jobList[jobId].jobLevel, "Task: Invalid User Level");

    //     uint8 _status = jobList[jobId].status;
    //     require(_status == uint8(JOB_STATUS.VERIFIED_POST) || _status == uint8(JOB_STATUS.VERIFIED_COMPLETED), 'Task: Invalid Validation Status');
    //     require(block.timestamp <= jobList[jobId].validationPeriod, "Task: Invalid Validation Time");
    //     _;
    // }


    constructor() {
        owner = msg.sender;
    }

    function setTokens(address tgrTokenAddress, address htzTokenAddress) external onlyOwner {
        tgrToken = IERC20(tgrTokenAddress);
        htzToken = IERC20(htzTokenAddress);
    }
    function setAgentContract(IAgent _agentContract) external onlyOwner {
        require(address(_agentContract) != address(0), "Task: Invalid Address");
        agentContract = _agentContract;
    }
    function setJobTypes(string[] calldata _jobtypes) external onlyOwner {
        for(uint8 i = 0 ; i < _jobtypes.length ; i ++) {
            jobTypes.push(_jobtypes[i]);
        }
    }

    function getDuration() public view returns(uint256) {
        return duration;
    }
    
    function setDuration(uint256 _duration) external onlyOwner {
        require(_duration >= MAX_DURATION, "Task: Invalid duration");
        duration = _duration;
    }

    function getSubmissionDisputeDuration() public view returns(uint256){
        return submissionDisputeDuration;
    }

    function setSubmissionDisputeDuration(uint256 _submissionDisputeDuration) external onlyOwner {
        require(_submissionDisputeDuration >= MAX_DURATION, "Task: Invalid duration");
        submissionDisputeDuration = _submissionDisputeDuration;
    }    

    //  Define Job
    function defineJob(
        uint8 jobType,
        uint8 jobLevel,
        string calldata title,
        string calldata description,
        bool tgrEarning,
        uint256 escrowAmount,
        uint256 completionTime
    ) external {

        Job memory newJobItem = Job({
            jobType: jobType,
            jobLevel: jobLevel,
            title: title,
            description: description,
            tgrEarning: tgrEarning,
            escrowAmount: escrowAmount,
            status: uint8(JOB_STATUS.CREATED),
            defineTime: block.timestamp,
            completionTime: completionTime,
            buyer: msg.sender,
            validationPeriod: 0,
            buyerReview: 0,
            sellerReview:0,
            buyerReviewComment: '',
            sellerReviewComment: '',
            createdAt: block.timestamp,
            submittedAt: block.timestamp,
            disputedAt: block.timestamp,
            doneAt: block.timestamp,
            withrawedAt: block.timestamp
        });

        jobList.push(newJobItem);
        Job storage job = jobList[jobList.length - 1];

        //Deposit Escrow Amount to this contract
        uint256 htzBalance = htzToken.allowance(msg.sender, address(this));
        
        require(htzBalance >= escrowAmount, "Task: HTZ Token Insufficient Balance");
        htzToken.safeTransferFrom(msg.sender, address(this), escrowAmount);

        if (!tgrEarning) job.status = uint8(JOB_STATUS.POSTED); 
        else job.status = uint8(JOB_STATUS.VERIFYING);

        emit updateJobStatus(jobList.length - 1, job.status);
    }

    /*
     * @dev Verification stage for defined/completed job
     * In this stage, 11 agents can participate in approval/deny voting.
     * @param jobId: Inex of job
     * @param isApprove: True if the voter approves the job posting, false otherwise
    **/
    function verifyJob(uint256 jobId, bool isApprove) public availableForVerifying(jobId){
        AgentsForJob storage agents = agentsListForJobs[jobId];

        bool duplicated = checkForDoubleAgents(msg.sender, jobId);
        if (duplicated) revert('Task: Already Participated');

        Vote memory newVoter = Vote({
            voter: msg.sender,
            result: isApprove
        });

        agents.validators.push(newVoter);
        agents.participants.push(newVoter);
        
        _refreshStatus(jobId);
    }

    /*
     * @dev disputing job: The voter can dispute the validation result of the previous result.
     * @param jobId: job index
    */
    function disputeJob(uint256 jobId) public {
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];  
        uint256 userLevel = agentContract.getLevelOfAgent(msg.sender);
        uint8 _status = job.status;

        require(userLevel != 0 || userLevel > jobList[jobId].jobLevel, "Task: Invalid user level");

        bool duplicated = checkForDoubleAgents(msg.sender, jobId);
        if (duplicated) revert('Task: Already Participated');

        if(job.tgrEarning) {
            require(_status == uint8(JOB_STATUS.VERIFIED_POST) || _status == uint8(JOB_STATUS.VERIFIED_COMPLETED), 'Task: Invalid Status');

            uint32 isApproved = 0;
            uint32 isDenied = 0;
            bool isApprove = true;

            if(agents.validators.length > 0) {
                for(uint32 i = 0 ; i < agents.validators.length ; i ++) {
                    Vote memory vote = agents.validators[i];
                    if(vote.result) isApproved += 1;
                    else isDenied += 1;
                }
            }

            if (job.status == uint8(JOB_STATUS.VERIFIED_POST)) {
                _returnStatus(jobId, uint8(JOB_STATUS.VERIFYING));
            } else {
                _returnStatus(jobId, uint8(JOB_STATUS.VERIFYING_COMPLETED));
            }

            if (isApproved > isDenied) {
                isApprove = false;
            }
            Vote memory newVoter = Vote({
                voter: msg.sender,
                result: isApprove
            });
            agents.validators.push(newVoter);
            agents.participants.push(newVoter);
        } else {
            require(_status == uint8(JOB_STATUS.VALIDATED_DISPUTE), 'Task: Invalid Status');
            require(block.timestamp > job.validationPeriod, "Task: Can't Dispute");

            _returnStatus(jobId, uint8(JOB_STATUS.DISPUTE_COMPLETED));

            Vote memory newVoter = Vote({
                voter: msg.sender,
                result: false
            });

            agents.validators.push(newVoter);
            agents.participants.push(newVoter);
        }
        
    }

    function disputeSubmission(uint256 jobId) public {
        Job storage job = jobList[jobId];
        uint8 _status = job.status;

        require(!job.tgrEarning, "Task: Should be nontgr Job");
        require(_status == uint8(JOB_STATUS.COMPLETED), "Task: Invalid Status");
        require(msg.sender == job.buyer, "Task: Invalid User");

        job.status = uint8(JOB_STATUS.DISPUTE_COMPLETED);
        job.disputedAt = block.timestamp;

        emit updateJobStatus(jobId, job.status);
    }

    function checkForDoubleAgents(address agent, uint256 jobId) public view returns(bool) {
        AgentsForJob memory agents = agentsListForJobs[jobId];
        for(uint32 i = 0; i < agents.participants.length; i ++) {
            if (agents.participants[i].voter == agent) return true;
        }
        return false;
    }

    //  check whether bidder already bidded for the job
    function checkForDoubleBidders(address _bidder, uint _jobId) public view returns(bool){
        for(uint i = 0; i < agentsListForJobs[_jobId].bidders.length; i++) {
            if (agentsListForJobs[_jobId].bidders[i].bidder == _bidder) return true;
        }
        return false;
    }

    // Checking out job status
    function _refreshStatus(uint jobId) private {
        AgentsForJob memory agents = agentsListForJobs[jobId];
        Job storage job = jobList[jobId];

        uint256 totalVoters = agents.validators.length;

        if (job.tgrEarning) {
            if(totalVoters % MAX_LIMIT_VALIDATORS == 0) {
                if (job.status == uint8(JOB_STATUS.VERIFYING)) job.status = uint8(JOB_STATUS.VERIFIED_POST);
                if (job.status == uint8(JOB_STATUS.VERIFYING_COMPLETED)) job.status = uint8(JOB_STATUS.VERIFIED_COMPLETED);

                job.validationPeriod = block.timestamp + duration;

                emit updateJobStatus(jobId, job.status);
            }
        } else {
            if(totalVoters % MAX_LIMIT_VALIDATORS == 0) {
                uint32 isApproved = 0;
                uint32 isDenied = 0;
                if(agents.validators.length > 0) {
                    for(uint32 i = 0 ; i < agents.validators.length ; i ++) {
                        Vote memory vote = agents.validators[i];
                        if(vote.result) isApproved += 1;
                        else isDenied += 1;
                    }
                }

                if (isApproved > isDenied) {
                    job.status = uint8(JOB_STATUS.VALIDATED_DISPUTE);
                    job.validationPeriod = block.timestamp + duration;

                    emit updateJobStatus(jobId, job.status);
                } else {
                    _returnStatus(jobId, uint8(JOB_STATUS.DISPUTE_COMPLETED));
                }
            }
        }
        
    }

    // Checking out whether job pass validation stage or not
    function validateJob(uint256 jobId) public {
        Job storage job = jobList[jobId];
        AgentsForJob memory agents = agentsListForJobs[jobId];
        uint256 totalVoters = agents.validators.length;

        uint32 isApproved = 0;
        uint32 isDenied = 0;
        if(agents.validators.length > 0) {
            for(uint32 i = 0 ; i < agents.validators.length ; i ++) {
                Vote memory vote = agents.validators[i];
                if(vote.result) isApproved += 1;
                else isDenied += 1;
            }
        }

        if(job.validationPeriod > 0 && (block.timestamp > job.validationPeriod || totalVoters % MAX_LIMIT_VALIDATORS == 0)) {
            // uint32 isApproved = 0;
            // uint32 isDenied = 0;
            // if(agents.validators.length > 0) {
            //     for(uint32 i = 0 ; i < agents.validators.length ; i ++) {
            //         Vote memory vote = agents.validators[i];
            //         if(vote.result) isApproved += 1;
            //         else isDenied += 1;
            //     }
            // }
            if(job.tgrEarning) {

                if (job.status == uint8(JOB_STATUS.VERIFIED_POST)) {
                    if (isApproved > isDenied) {
                        job.status = uint8(JOB_STATUS.VALIDATIED_POST);
                    } else {
                        job.status = uint8(JOB_STATUS.DENIED_POST);
                    }
                    treatApprovalOnValidationAndSlash(jobId);
                } 
                if (job.status == uint8(JOB_STATUS.VERIFIED_COMPLETED)) {
                    if (isApproved > isDenied) {
                        job.status = uint8(JOB_STATUS.VALIDATED_COMPLETED);
                    } else {
                        job.status = uint8(JOB_STATUS.DENIED_COMPLETED);
                    }
                    treatEscrowOnCompletionAndSlash(jobId);
                }
                // if (job.status == uint8(JOB_STATUS.VALIDATED_DISPUTE)) {
                //     if (isApproved > isDenied) {
                //         job.status = uint8(JOB_STATUS.DONE);
                //     }
                // }

                emit updateJobStatus(jobId, job.status);
            } else {
                if (isApproved >= isDenied) {
                    treatEscrowOnCompletionAndSlash(jobId);
                } else {
                    _returnStatus(jobId, uint8(JOB_STATUS.DISPUTE_COMPLETED));
                }
            }
        } else if (!job.tgrEarning && ((job.status == uint8(JOB_STATUS.DISPUTE_COMPLETED) && block.timestamp > job.disputedAt + duration) || (job.status == uint8(JOB_STATUS.VALIDATED_COMPLETED) && block.timestamp > job.validationPeriod))) {
            if (isApproved >= isDenied) {
                treatEscrowOnCompletionAndSlash(jobId);
            } else {
                _returnStatus(jobId, uint8(JOB_STATUS.COMPLETED));
                emit updateJobStatus(jobId, job.status);
            }
        } else if(!job.tgrEarning && job.status == uint8(JOB_STATUS.COMPLETED) && block.timestamp > job.submittedAt + submissionDisputeDuration) {
            // Release escrow to freelancer
            _transferHTZ(agents.seller, job.escrowAmount);

            job.status = uint8(JOB_STATUS.WITHDRAWED);
            job.withrawedAt = block.timestamp;

            emit updateJobStatus(jobId, job.status);
        } else {
            revert("No Action");
        }
    }

    function _returnStatus(uint256 jobId, uint8 status) private {
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];
        
        job.status = status;
        job.validationPeriod = 0;
        // Empty agents
        delete agents.validators;

        emit updateJobStatus(jobId, status);
    }

    // Treat for validated job
    function treatApprovalOnValidationAndSlash(uint jobId) public{
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];

        if (job.tgrEarning) {
            require(job.status == uint8(JOB_STATUS.VALIDATIED_POST) || job.status == uint8(JOB_STATUS.DENIED_POST), "Task: Invalid Status");

            if (job.status == uint8(JOB_STATUS.VALIDATIED_POST)) {

                for (uint32 i = 0 ; i < agents.participants.length ; i ++) {
                    Vote memory vote = agents.participants[i];
                    if (vote.result) {
                        _prizeToAgents(vote.voter, job.escrowAmount);
                    }
                    else {
                        _slashTgrOfAgents(vote.voter, job.escrowAmount);
                    }
                }
                
                job.status = uint8(JOB_STATUS.POSTED);
                
            } else if (job.status == uint8(JOB_STATUS.DENIED_POST)) {

                for (uint32 i = 0 ; i < agents.participants.length ; i ++ ) {
                    Vote memory vote = agents.participants[i];
                    if (!vote.result) {
                        _prizeToAgents(vote.voter, job.escrowAmount);
                    }
                    else {
                        _slashTgrOfAgents(vote.voter, job.escrowAmount);
                    }
                }
                // Remove a job
                job.status = uint8(JOB_STATUS.CANCELED);
                _refundEscrow(job.buyer, job.escrowAmount);
            }
            
            _slashTgrOfAgents(job.buyer, job.escrowAmount);

            // Empty agents
            delete agents.validators;
            delete agents.participants;

            emit updateJobStatus(jobId, job.status);
        }
    }

    //  Add bidder
    function addBidder(uint jobId, string calldata description) external {
        require(msg.sender != jobList[jobId].buyer, 'Task: Can`t Bid');
        require(jobList[jobId].status == uint8(JOB_STATUS.POSTED), 'Task: Job In Progress');

        // check if a bidder is in bidders 
        bool duplicated = checkForDoubleBidders(msg.sender, jobId);
        if (duplicated) {
            revert('Already bidded');
        }        

        AgentsForJob storage agents = agentsListForJobs[jobId];
        Bid memory newBid = Bid({
            bidder: msg.sender,
            description: description
        });
        agents.bidders.push(newBid);
    }

    //Assign seller to job
    function assignSellerToJob(uint jobId, address seller) external onlyBuyer(jobId) {
        require(jobList[jobId].status == uint8(JOB_STATUS.POSTED), "Task: Can't Assign Seller");
        Job storage job = jobList[jobId];
        AgentsForJob storage agents = agentsListForJobs[jobId];
        agents.seller = seller;
        job.status = uint8(JOB_STATUS.INPROGRESSING);

        emit updateJobStatus(jobId, job.status);
    }

    // Set Job status to in progress by buyer
    function setJobInProgress(uint jobId) external onlyBuyer(jobId) {
        Job storage job = jobList[jobId];
        require(job.status == uint8(JOB_STATUS.POSTED), "Task: Job is not posted");
        job.status = uint8(JOB_STATUS.INPROGRESSING);

        emit updateJobStatus(jobId, job.status);
    }

    function submitJob(uint256 _jobId,  string memory _comment) external{
        Job storage job = jobList[_jobId];
        AgentsForJob storage agents = agentsListForJobs[_jobId];

        require(agents.seller == msg.sender, "Task: Not freelancer of Job");
        require(job.status == uint8(JOB_STATUS.INPROGRESSING), "Task: Job Not In Progress");

        job.status = uint8(JOB_STATUS.COMPLETED);
        if(job.tgrEarning) job.status = uint8(JOB_STATUS.VERIFYING_COMPLETED);        
        job.submittedAt = block.timestamp;
        agents.submittedComment = _comment;

        emit updateJobStatus(_jobId, job.status);
    }


    // Treat for completed job
    function treatEscrowOnCompletionAndSlash(uint jobId) public {
        Job storage job = jobList[jobId];
        AgentsForJob memory agents = agentsListForJobs[jobId];

        if (job.tgrEarning) {
            require(job.status == uint8(JOB_STATUS.VALIDATED_COMPLETED) || job.status == uint8(JOB_STATUS.DENIED_COMPLETED), "Invalid Status");

            if (job.status == uint8(JOB_STATUS.VALIDATED_COMPLETED)) {
                for (uint32 i = 0 ; i < agents.participants.length ; i ++) {
                    Vote memory vote = agents.participants[i];
                    if (vote.result) {
                        _prizeToAgents(vote.voter, job.escrowAmount);
                    }
                    else {
                        _slashTgrOfAgents(vote.voter, job.escrowAmount);
                    }
                }

                job.status = uint8(JOB_STATUS.DONE);

            } else if (job.status == uint8(JOB_STATUS.DENIED_COMPLETED)) {
                for (uint32 i = 0 ; i < agents.participants.length ; i ++ ) {
                    Vote memory vote = agents.participants[i];
                    if (!vote.result) {
                        _prizeToAgents(vote.voter, job.escrowAmount);
                    }
                    else {
                        _slashTgrOfAgents(vote.voter, job.escrowAmount);
                    }
                }

                _slashTgrOfAgents(agents.seller, job.escrowAmount);                 
                _refundEscrow(job.buyer, job.escrowAmount);

                job.status = uint8(JOB_STATUS.CANCELED);
                job.withrawedAt = block.timestamp;
            }
        } else {
            require((job.status == uint8(JOB_STATUS.DISPUTE_COMPLETED) || job.status == uint8(JOB_STATUS.VALIDATED_COMPLETED)) && block.timestamp > job.disputedAt + duration, 'Task:Invalid Status');

            for (uint32 i = 0 ; i < agents.participants.length ; i ++ ) {
                Vote memory vote = agents.participants[i];
                if (!vote.result) {
                    _prizeToAgents(vote.voter, job.escrowAmount);
                }
                else {
                    _slashTgrOfAgents(vote.voter, job.escrowAmount);
                }
            }

            _slashTgrOfAgents(agents.seller, job.escrowAmount);
            _refundEscrow(job.buyer, job.escrowAmount);

            job.status = uint8(JOB_STATUS.CANCELED);
            job.withrawedAt = block.timestamp;
        }

        // Empty agents
        delete agents.validators;
        delete agents.participants;

        emit updateJobStatus(jobId, job.status);
    }

    function releaseEscrow(uint256 jobId) public {
        Job storage job = jobList[jobId];
        require(msg.sender == job.buyer, "Task: No Owner of Job");
        require(job.status >= uint8(JOB_STATUS.COMPLETED), "Task: Invalid Status");

        _transferHTZ(agentsListForJobs[jobId].seller, job.escrowAmount);

        job.status = uint8(JOB_STATUS.WITHDRAWED); // Escrow is claimed
        job.withrawedAt = block.timestamp;

        emit updateJobStatus(jobId, job.status);
    }
    
    // Claim Escrow
    function claimEscrow(uint _jobId) external {
        Job storage job = jobList[_jobId];
        require(msg.sender == agentsListForJobs[_jobId].seller, 'Task: Not Seller');
        require(job.status == uint8(JOB_STATUS.DONE), "Task: Job Not Done");
        
        _transferHTZ(msg.sender, job.escrowAmount);

        job.status = uint8(JOB_STATUS.WITHDRAWED); // Escrow is claimed
        job.withrawedAt = block.timestamp;

        emit updateJobStatus(_jobId, job.status);
    }

    // Refund escrow to buyer
    function refundEscrowToBuyer(uint jobId) external onlyBuyer(jobId) {
        Job storage job = jobList[jobId];
        require(job.escrowAmount > 0, "Task: Invalid Amount");
        if (block.timestamp > job.completionTime) require(job.status <= uint8(JOB_STATUS.INPROGRESSING), "Task: Can't Refund");
        else require(job.status < uint8(JOB_STATUS.INPROGRESSING), "Task: Can't Refund");

        job.status = uint8(JOB_STATUS.CANCELED);
        _refundEscrow(job.buyer, job.escrowAmount);

        emit updateJobStatus(jobId, job.status);
    }

    // Set review of buyer
    function setBuyerReview(uint256 _jobId, uint8 _reviewMarker, string calldata _comment) public {
        Job storage job = jobList[_jobId];
        require(job.buyerReview == 0, "Already set");
        require(job.status == uint8(JOB_STATUS.WITHDRAWED), "Task: Job Not Done");
        require(agentsListForJobs[_jobId].seller == msg.sender, 'Task: Not Seller');

        job.buyerReview = _reviewMarker;
        job.buyerReviewComment = _comment;
    }

    // Set review of seller
    function setSellerReview(uint256 _jobId, uint8 _reviewMarker, string calldata _comment) public {
        Job storage job = jobList[_jobId];
        require(job.sellerReview == 0, "Task: Already set");
        require(job.status == uint8(JOB_STATUS.WITHDRAWED), "Task: Job Not Done");
        require(job.buyer == msg.sender, 'Task: Not Buyer');

        job.sellerReview = _reviewMarker;
        job.sellerReviewComment = _comment;
    }

    function _slashTgrOfAgents(address agent, uint escrowAmount) private {
        uint256 tgrAmountToBeSlashed = escrowAmount / 1000;
        agentContract.slashTokenOfAgent(agent, tgrAmountToBeSlashed);
    }

    function _prizeToAgents(address agent, uint escrowAmount) private {
        uint256 tgrAmountToBePrized = escrowAmount / 1000;
        agentContract.prizeTokenOfAgent(agent, tgrAmountToBePrized);
    }

    function _refundEscrow(address refunder, uint256 escrowAmount) private {
        _transferHTZ(burn_address, escrowAmount * BURN_PERCENT / 100);
        _transferHTZ(refunder, escrowAmount * (100 - BURN_PERCENT) / 100);
    }

    function _transferHTZ(address sender, uint256 amount) private {
        require(sender != address(0), "Task: Zero Address");
        require(amount > 0, "Task: Zero Amount");
        require(htzToken.balanceOf(address(this)) >= amount, "Task: Insufficient Balance");

        htzToken.safeTransfer(sender, amount);
    }

    function getJobList() external view returns(Job[] memory) {
        return jobList;
    }

    function getJobTypes() external view returns(string[] memory){
        return jobTypes;
    }

    function getStatusOfJob(uint256 _jobId) external view returns(uint256) {
        return jobList[_jobId].status;
    }

    function getAgentsForJob(uint _jobId) external view returns(AgentsForJob memory _agentsForJob) {
        _agentsForJob = agentsListForJobs[_jobId];
    }

}