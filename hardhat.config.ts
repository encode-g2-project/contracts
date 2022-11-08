import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
dotenv.config();
import "./tasks/index";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: "0.8.10",
  paths: { tests: "tests" },
  networks: {
    "truffle-dashboard": {
      url: "http://localhost:24012/rpc",
    },
    hardhat: {
      chainId: 31337,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
