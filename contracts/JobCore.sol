// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract JobCore {
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
        bool status;
    }

    bytes32[] public JobIds;
    mapping(bytes32 => Job) public Jobs;
    mapping(address => mapping(bytes32 => Stage[2])) public Applicants;
    mapping(address => bytes32[]) public Employers;
    mapping(address => mapping(IERC20 => uint256)) public ERC20BountyBalances;
}
