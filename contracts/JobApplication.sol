// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./JobCore.sol"; 

contract JobPosting is JobCore {
    // enum State {SCREENING, FIRST_INTERVIEW, TECHNICAL_TEST, FINAL_INTERVIEW, HIRED, REJECTED}
    // State public currentState;

    function newApplcation(bytes32 jobid) public {
        require(!checkApplicantExists(jobid, msg.sender), "You have already made an application");
        Job memory p = Jobs[jobid];
        p.applicants[p.applicants.length + 1] = msg.sender;
        Jobs[jobid] = Job(jobid, p.employer, p.rolesToFill, p.applicants, p.token, p.bountyAmount, p.bountySent);
    }

    function getMyApplications() public view returns (bytes32[] memory) {}

    function getMyApplicants(bytes32 jobid) public view returns (address[] memory) {
        Job memory p = Jobs[jobid];
        return p.applicants;
    }

    function changeApplicationStatus(address applicantAddress, bytes32 jobid, string memory status) public {
        // Several ways to do this:
        // OPTION 1: Delcare enum state with predefined stages
        // OPTION 2: Replace custom status with other custom status (defined by employer)
    }

    function claimBounty(bytes32 jobid) public {
        Job memory p = Jobs[jobid];
        require(p.bountySent != true, "You have already claimed your bounty");
        
        // TODO: Bounty needs to be split equally (e.g. bountyAmount / number_of_applicants).
        // TODO: Bounty can be claimed at certain stage (e.g. Final interview stage).
        // TODO: Bounty can only be claimed upon employer approval
        if (address(p.token) == address(0)) {
            (bool success, ) = address(this).call{value: p.bountyAmount}("");
            require(success, "Failed to send Ether");
        }  else {
            bool success = p.token.transferFrom(msg.sender, address(this), p.bountyAmount);
            require(success, "Failed to send ERC-20 Token");
        }
        p.bountySent = true;
        //Jobs[jobid] = p;
        //emit event
        //emit BountySent(p.jobid, p.bountySent, p.applicants);
    }
}