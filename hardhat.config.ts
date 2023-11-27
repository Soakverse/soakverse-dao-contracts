// hardhat.config.js
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-verify";
import { HardhatUserConfig } from "hardhat/types";

const {
  mainnetAccount,
  testnetAccount,
  localhostDeployAccount,
  infuraProjectId,
  etherscanApiKey,
} = require("./.secrets.json");

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: { enabled: true, runs: 1500 },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://localhost:8545",
      accounts: [localhostDeployAccount],
    },
    testnet: {
      url: "https://bsc-testnet.publicnode.com",
      chainId: 97,
      accounts: [testnetAccount],
    },
    bscMainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [mainnetAccount],
    },
    mainnet: {
      url: "https://mainnet.infura.io/v3/" + infuraProjectId,
      accounts: [mainnetAccount],
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: etherscanApiKey,
  },
};

export default config;
