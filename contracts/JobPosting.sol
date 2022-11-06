// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./JobCore.sol";

contract JobPosting is JobCore {
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

        // TODO: External call should be moved to the last statement of this method
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
            require(
                token.transferFrom(msg.sender, address(this), bountyAmount),
                "Failed to send ERC20 bounty to contract for custody"
            );
            ERC20BountyBalances[msg.sender][token] += bountyAmount;
        }

        address[] memory applicants;
        Bounty memory bounty = Bounty(token, amount);
        Jobs[jobId] = Job(jobId, msg.sender, applicants, bounty);

        Employers[msg.sender].push(jobId);
        // Supply bounty amount on AAVE
        collectBounty(bounty.token, bounty.amount);

        emit JobPublished(jobId, msg.sender, amount);
    }

    function unpublishJob(bytes32 jobId) external {
        require(
            Jobs[jobId].employer == msg.sender,
            "Offer doesn't exist or you're not the employer"
        );

        Bounty memory bounty = Jobs[jobId].bounty;

        if (bounty.token == IERC20(address(0))) {
            (bool sent, ) = msg.sender.call{value: bounty.amount}("");
            require(sent, "Failed to send Ether bounty to employer");
        } else {
            ERC20BountyBalances[msg.sender][bounty.token] -= bounty.amount;
            require(
                (bounty.token).transfer(msg.sender, bounty.amount),
                "Failed to send ERC20 bounty to employer"
            );
        }

        delete Jobs[jobId];
        emit JobUnpublished(jobId, msg.sender);
    }
}
