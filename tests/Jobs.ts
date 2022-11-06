import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { ethers } from "hardhat";
import { Web3Jobs__factory } from "../typechain-types";

describe("Web3Jobs", function () {
  async function deploy() {
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const Web3Jobs = await ethers.getContractFactory("Web3Jobs");
    const web3jobs = await Web3Jobs.deploy();

    return { web3jobs };
  }
});
