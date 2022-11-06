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
    }

    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    mapping(bytes32 => Job) public Jobs;
    mapping(address => mapping(bytes32 => Stage[2])) public Applicants;
    mapping(address => bytes32[]) public Employers;
}
