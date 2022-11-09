import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";
dotenv.config();
import "./tasks/index";
const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const GOERLI_PRIVATE_KEY = process.env.GOERLI_PRIVATE_KEY!;
// yarn hardhat verify --network goerli 0xA926382F92e3B50C7485453f6eF80370bFD4BE5D 0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D 0xd5B55D3Ed89FDa19124ceB5baB620328287b915d 0x27B4692C93959048833f40702b22FE3578E77759

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
    goerli: {
      url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
      accounts: [GOERLI_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
