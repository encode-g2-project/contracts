// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Web3Jobs {
    enum Stage {
        SCREENING,
        FIRST_INTERVIEW,
        TECHNICAL_TEST,
        FINAL_INTERVIEW,
        HIRED,
        REJECTED
    }

    struct Bounty {
        IERC20 token;
        uint256 amount;
    }

    struct Job {
        bytes32 jobId;
        address employer;
        address[] applicants;
        Bounty bounty;
    }

    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    mapping(bytes32 => Job) public Jobs;
    mapping(address => mapping(bytes32 => Stage[2])) public Applicants;
    mapping(address => bytes32[]) public Employers;

    event JobPublished(
        bytes32 indexed jobId,
        address indexed employer,
        uint256 indexed bountyAmount
    );
    event JobUnpublished(bytes32 indexed jobId, address indexed employer);

    function publishJob(
        bytes32 jobId,
        uint256 bountyAmount,
        IERC20 token
    ) external payable {
        uint256 amount;

        if (msg.value != 0) {
            require(
                bountyAmount == 0 && token == IERC20(address(0)),
                "Only a single currency can be used for bounty"
            );
            amount = msg.value;
        } else {
            require(
                bountyAmount != 0 && token != IERC20(address(0)),
                "Wrong amount or token provided for bounty"
            );
            amount = bountyAmount;
        }

        address[] memory applicants;
        Bounty memory bounty = Bounty(token, amount);
        Jobs[jobId] = Job(jobId, msg.sender, applicants, bounty);

        Employers[msg.sender].push(jobId);

        emit JobPublished(jobId, msg.sender, amount);
    }

    function unpublishJob(bytes32 jobId) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );
        delete Jobs[jobId];
        emit JobUnpublished(jobId, msg.sender);
    }

    event BountyClaimed(
        bytes32 indexed jobId,
        address indexed applicant,
        uint256 indexed amount,
        bool isEther
    );

    function newApplication(bytes32 jobId) public {
        require(
            !applicantExists(jobId),
            "You have already made an application"
        );
        Jobs[jobId].applicants.push(msg.sender);

        Stage[2] memory stage;
        stage[0] = Stage.SCREENING;
        Applicants[msg.sender][jobId] = stage;
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

    function claimBounty(bytes32 jobId) external {
        require(
            (Applicants[msg.sender][jobId])[0] == Stage.REJECTED &&
                (Applicants[msg.sender][jobId])[1] == Stage.FINAL_INTERVIEW,
            "Not eligible for claiming bounty"
        );

        // TODO: Bounty can only be claimed upon employer approval

        bool isEther;
        Bounty memory bounty = Jobs[jobId].bounty;

        uint256 numberOfEligible = getEligible(jobId);
        uint256 bountySlice = bounty.amount / numberOfEligible;

        if (bounty.token == IERC20(address(0))) {
            (bool success, ) = address(this).call{value: bountySlice}("");
            require(success, "Failed to send Ether");
            isEther = true;
        } else {
            bool success = bounty.token.transferFrom(
                msg.sender,
                address(this),
                bountySlice
            );
            require(success, "Failed to send ERC-20 Token");
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

    function getEligible(bytes32 jobId) internal view returns (uint256) {
        address[] memory applicants = (Jobs[jobId].applicants);

        uint256 eligible;
        for (uint256 i; i < applicants.length; i++) {
            if (
                (Applicants[applicants[i]][jobId])[0] == Stage.REJECTED &&
                (Applicants[applicants[i]][jobId])[1] == Stage.FINAL_INTERVIEW
            ) eligible += 1;
        }

        return eligible;
    }
}
