// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JobCore { 
    // enum LocationSate {REMOTE, HYBRID, IN_PERSON}
    // enum StageState {SCREENING, FIRST_INTERVIEW, TECHNICAL_TEST, FINAL_INTERVIEW, HIRED, REJECTED}
    
    // LocationSate public currentState;
    // StageState public currentState;

    struct Job {
        bytes32 jobid;
        address employer;
        uint256 rolesToFill;
        address[] applicants;
        IERC20 token;
        uint256 bountyAmount;
        bool bountySent;
        // string title;
        // string description;
        // LocationSate currentState;
    }

    mapping (bytes32 => Job) Jobs;
    mapping (address => Job) Applicant;

    function checkApplicantExists(bytes32 jobid, address applicantAddress) internal view returns (bool){
        Job memory p = Jobs[jobid];
        for (uint i=0; i < p.applicants.length; i++ ) {
            if (applicantAddress == p.applicants[i]) {
                return true;
            }
        }
        return false;
    }
}