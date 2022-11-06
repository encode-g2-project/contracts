import { ethers } from "hardhat";

async function main() {
  const Web3Jobs = await ethers.getContractFactory("Web3Jobs");
  const web3jobs = await Web3Jobs.deploy();

  await web3jobs.deployed();

  console.log(`Contract deployed to ${web3jobs.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
