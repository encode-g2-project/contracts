// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./JobCore.sol";

contract JobApplication is JobCore {
    event BountyClaimed(
        bytes32 indexed jobId,
        address indexed applicant,
        uint256 indexed amount,
        bool isEther
    );

    constructor(
        address _aavePoolAddressRegistryAddress,
        address _aaveWethGatewayAddress,
        address _aWethGatewayAddress
    )
        JobCore(
            _aavePoolAddressRegistryAddress,
            _aaveWethGatewayAddress,
            _aWethGatewayAddress
        )
    {}

    function newApplication(bytes32 jobId) public {
        require(
            !applicantExists(jobId) && Jobs[jobId].status,
            "You have already made an application or application is not open yet"
        );
        Jobs[jobId].applicants.push(msg.sender);

        Stage[2] memory stage;
        stage[0] = Stage.SCREENING;
        Applicants[msg.sender][jobId] = stage;
        MyApplications[msg.sender].push(jobId);
        MyApplicationsLength += 1;
    }

    function getMyApplicants(bytes32 jobId)
        external
        view
        returns (address[] memory)
    {
        return Jobs[jobId].applicants;
    }

    function changeApplicationStatus(
        address applicant,
        bytes32 jobId,
        uint8 status
    ) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );
        (Applicants[applicant][jobId])[1] = (Applicants[applicant][jobId])[0];
        (Applicants[applicant][jobId])[0] = Stage(status);
    }

    function closeJobOffer(bytes32 jobId) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );
        Jobs[jobId].status = false;
    }

    function claimBounty(bytes32 jobId) external {
        require(
            (Applicants[msg.sender][jobId])[0] == Stage.REJECTED &&
                (Applicants[msg.sender][jobId])[1] == Stage.FINAL_INTERVIEW &&
                !Jobs[jobId].status,
            "Not eligible for claiming bounty"
        );

        // TODO: Bounty can only be claimed upon employer approval

        bool isEther;
        Bounty memory bounty = Jobs[jobId].bounty;

        uint256 numberOfEligible = getEligibles(jobId);
        uint256 bountySlice = bounty.amount / numberOfEligible;

        // Withdraw bountySlice from aave to pay back on msg.sender
        withdrawBounty(address(bounty.token), bountySlice);
        if (bounty.token == IERC20(address(0))) {
            (bool success, ) = msg.sender.call{value: bountySlice}("");
            require(success, "Failed to send Ether bounty slice to applicant");
            isEther = true;
        } else {
            address employer = Jobs[jobId].employer;
            ERC20BountyBalances[employer][bounty.token] -= bountySlice;
            require(
                (bounty.token).transfer(msg.sender, bountySlice),
                "Failed to send ERC20 bounty slice to applicant"
            );
        }

        emit BountyClaimed(jobId, msg.sender, bountySlice, isEther);
    }

    function applicantExists(bytes32 jobId) internal view returns (bool) {
        address[] memory applicants = Jobs[jobId].applicants;
        for (uint256 i; i < applicants.length; i++) {
            if (applicants[i] == msg.sender) return true;
        }
        return false;
    }

    function getEligibles(bytes32 jobId) internal view returns (uint256) {
        address[] memory applicants = (Jobs[jobId].applicants);

        uint256 eligibles;
        for (uint256 i; i < applicants.length; i++) {
            if (
                (Applicants[applicants[i]][jobId])[0] == Stage.REJECTED &&
                (Applicants[applicants[i]][jobId])[1] == Stage.FINAL_INTERVIEW
            ) eligibles += 1;
        }

        return eligibles;
    }
}
