import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "./tasks/index";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  paths: { tests: "tests" },
};

export default config;
