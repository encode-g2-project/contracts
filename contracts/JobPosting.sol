// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./JobCore.sol";

contract JobPosting is JobCore {
    event JobPublished(bytes32 indexed jobid, uint256 indexed amount);
    event JobUnpublished(bytes32 indexed jobid, address indexed employer);

    constructor(){}

    function publishJob(uint256 rolesToFill, uint256 bountyAmount, IERC20 token) external payable {
        if (bountyAmount == 0)
            require(msg.value != 0, "Bounty can't be zero");
            bountyAmount = msg.value;  
        if (msg.value == 0)
            require(bountyAmount != 0, "Bounty can't be zero");  

        // saving the details in Job struct
        bytes32 jobid = keccak256(abi.encodePacked(msg.sender, bountyAmount, block.timestamp));
        address[] memory lApplicants = new address[](1);
        Job memory p = Job(jobid, msg.sender, rolesToFill, lApplicants, token, bountyAmount, false);
        Jobs[jobid] = p;

        //emit event
        emit JobPublished(jobid, bountyAmount);
    }

    function unpublishJob(bytes32 jobid) external onlyEmployer(jobid) {
        Job memory p = Jobs[jobid];
        delete Jobs[jobid];

        //emit event
        emit JobUnpublished(p.jobid, p.employer);
    }

    function getJobInfo(bytes32 jobid) external view returns (Job memory) {
        return Jobs[jobid];
    }

    modifier onlyEmployer(bytes32 jobid) {
        // check that Job exists
        Job memory p = Jobs[jobid];
        // check that msg.sender is the employer
        require(msg.sender == p.employer, "You are not the employer");
        _;
    }
}
