import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import { MyToken, JobPosting } from "../typechain-types";
import { networkConfig } from "../helper-hardhat.config";
import { BigNumber } from "ethers";

describe("JobApplication", () => {
  let jobPosting: JobPosting;
  let bountyToken: MyToken;
  let deployer: SignerWithAddress;
  let employer: SignerWithAddress;
  let applicant: SignerWithAddress;

  beforeEach(async () => {
    [deployer, employer, applicant] = await ethers.getSigners();
    const poolAddressesProvider = await ethers.getContractAt(
      "IPoolAddressesProvider",
      networkConfig[network.config.chainId].aavePoolAddressRegistryAddress,
      deployer
    );
    const aaveWethGateway = await ethers.getContractAt(
      "IWETHGateway",
      networkConfig[network.config.chainId].aaveWethGatewayAddress,
      deployer
    );
    const aWethToken = await ethers.getContractAt(
      "WETH",
      networkConfig[network.config.chainId].aWethTokenAddress,
      deployer
    );
    const jobPostingFactory = await ethers.getContractFactory("JobPosting");
    jobPosting = (await jobPostingFactory.deploy(
      poolAddressesProvider.address,
      aaveWethGateway.address,
      aWethToken.address
    )) as JobPosting;
    await jobPosting.deployed();

    const initialSupply = 1000;
    const BountyToken = await ethers.getContractFactory("MyToken");
    bountyToken = await BountyToken.deploy(initialSupply);
    await bountyToken.deployed();

    const transferTokentoEmployer1 = await bountyToken.transfer(
      employer.address,
      ethers.utils.parseEther("10.00")
    );
    await transferTokentoEmployer1.wait();
  });

  it("Should be able to publish a Job with ETH", async function () {
    const [, employer1] = await ethers.getSigners();
    let purchaseGasCost: BigNumber;
    const bountyValue = 1;
    const bountyValueBN = ethers.utils.parseEther(bountyValue.toString());

    const balanceBefore = await employer1.getBalance();
    const newJobWithEthBounty = await jobPosting
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

    const gasUnitUsed = receipt.gasUsed;
    const gasPrice = receipt.effectiveGasPrice;
    purchaseGasCost = gasPrice.mul(gasUnitUsed);

    expect(balanceAfter).to.be.equal(
      balanceBefore.sub(purchaseGasCost).sub(bountyValueBN)
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
