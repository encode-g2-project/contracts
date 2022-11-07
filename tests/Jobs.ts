import { expect } from "chai";
import { ethers } from "hardhat";
import { Web3Jobs, MyToken } from "../typechain-types";

describe("Web3Jobs", function () {
  let web3jobs: Web3Jobs;
  let bountyToken: MyToken;

  beforeEach(async function () {
    const Web3Jobs = await ethers.getContractFactory("Web3Jobs");
    web3jobs = await Web3Jobs.deploy();
    await web3jobs.deployed();

    const initialSupply = 1000;
    const BountyToken = await ethers.getContractFactory("MyToken");
    bountyToken = await BountyToken.deploy(initialSupply);
    await bountyToken.deployed();
  });

  it("Should be able to publish a Job with ETH", async function () {
    const [, employer1] = await ethers.getSigners();
    const bountyValue = 1;
    const bountyValueBN = ethers.utils.parseUnits(
      bountyValue.toString(),
      `ether`
    );

    const balanceBefore = await employer1.getBalance();
    const newJobWithEthBounty = await web3jobs
      .connect(employer1)
      .publishJob(
        "0x516d65536a53696e4870506e6d586d73704d6a776958794e367a533445397a63",
        "0",
        "0x0000000000000000000000000000000000000000",
        {
          value: bountyValueBN,
        }
      );
    const receipt = await newJobWithEthBounty.wait();
    const balanceAfter = await employer1.getBalance();

    await expect(newJobWithEthBounty).not.to.be.reverted;
    expect(balanceAfter).to.be.equal(
      balanceBefore.sub(receipt.gasUsed).sub(bountyValueBN)
    );
  });

  it("Should be able to publish a Job with ERC20", async function () {
    const [, employer1] = await ethers.getSigners();

    const bountyAmount = 10;
    const transferTokentoEmployer1 = await bountyToken.transfer(
      employer1.address,
      bountyAmount
    );
    await transferTokentoEmployer1.wait();

    const approveJobSC = await bountyToken
      .connect(employer1)
      .approve(web3jobs.address, bountyAmount);
    await approveJobSC.wait();

    const newJobWithERC20Bounty = await web3jobs
      .connect(employer1)
      .publishJob(
        "0x516d65536a53696e4870506e6d586d73704d6a776958794e367a533445397a63",
        bountyAmount,
        bountyToken.address,
        {
          value: ethers.utils.parseUnits(`0`, `wei`),
        }
      );
    await expect(newJobWithERC20Bounty).not.to.be.reverted;
    expect(await bountyToken.balanceOf(employer1.address)).to.be.equal(0);
    expect(await bountyToken.balanceOf(web3jobs.address)).to.be.equal(
      bountyAmount
    );
  });
});
