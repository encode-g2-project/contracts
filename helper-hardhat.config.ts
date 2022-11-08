export const networkConfig = {
  31337: {
    name: "localhost",
    aavePoolAddressRegistryAddress:
      "0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D",
    aaveWethGatewayAddress: "0xd5B55D3Ed89FDa19124ceB5baB620328287b915d",
    aWethTokenAddress: "0x27B4692C93959048833f40702b22FE3578E77759",
  },
  5: {
    name: "goerli",
    wethToken: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
    // This is the AaveV3 Lending Pool Addresses Provider
    aavePoolAddressRegistryAddress:
      "0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D",
    aaveWethGatewayAddress: "0xd5B55D3Ed89FDa19124ceB5baB620328287b915d",
    aWethTokenAddress: "0x27B4692C93959048833f40702b22FE3578E77759",
  },
};

const developmentChains = ["hardhat", "localhost"];

module.exports = {
  networkConfig,
  developmentChains,
};
