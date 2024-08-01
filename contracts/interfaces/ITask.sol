// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.17;

interface ITask {

    enum JOB_STATUS {
        CREATED,
        VERIFYING,
        VERIFIED_POST,
        VALIDATIED_POST, 
        DENIED_POST,
        POSTED,
        INPROGRESSING,
        COMPLETED,
        VERIFYING_COMPLETED,
        VERIFIED_COMPLETED,
        VALIDATED_COMPLETED,
        DENIED_COMPLETED,
        DISPUTE_COMPLETED,
        VALIDATED_DISPUTE,
        DONE,
        WITHDRAWED,
        CANCELED
    }

    struct Job {
        bool tgrEarning;
        uint8 jobType;
        uint256 escrowAmount;
        uint8 status;
        uint256 defineTime;
        uint256 completionTime;
        address buyer;
        string title;
        uint256 validationPeriod;
        uint8 jobLevel; // 0 ~ 5
        uint8 buyerReview; // 10 ~ 50
        string buyerReviewComment;
        uint8 sellerReview; // 10 ~ 50
        string sellerReviewComment;
        string description;
        uint256 createdAt;
        uint256 submittedAt;
        uint256 disputedAt;
        uint256 doneAt;
        uint256 withrawedAt;
    }

    struct Bid {
        address bidder;
        string description;        
    }

    struct Vote {
        address voter;
        bool result;
    }

    struct AgentsForJob {
        address seller;
        string submittedComment;
        Bid[] bidders;
        Vote[] validators;
        Vote[] participants;
    }
}