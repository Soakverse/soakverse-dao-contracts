// hardhat.config.js
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-verify';
import { HardhatUserConfig } from 'hardhat/types';

const {
  mainnetAccount,
  testnetAccount,
  localhostDeployAccount,
  alchemyApiKey,
  etherscanApiKey,
} = require('./.secrets.json');

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  solidity: {
    compilers: [
      {
        version: '0.8.17',
        settings: {
          optimizer: { enabled: true, runs: 200 },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: 'http://localhost:8545',
      chainId: 1,
      accounts: [localhostDeployAccount],
    },
    hardhat: {
      chainId: 1,
      forking: process.env.FORK_URL
        ? { url: process.env.FORK_URL }
        : undefined,
    },
    testnet: {
      url: 'https://bsc-testnet.publicnode.com',
      chainId: 97,
      accounts: [testnetAccount],
    },
    bscMainnet: {
      url: 'https://bsc-dataseed.binance.org/',
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [mainnetAccount],
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/' + alchemyApiKey,
      accounts: [mainnetAccount],
    },
    base: {
      url: process.env.BASE_RPC_URL || 'https://base-mainnet.g.alchemy.com/v2/' + alchemyApiKey,
      chainId: 8453,
      accounts: [mainnetAccount],
    },
  },
  etherscan: {
    // Single Etherscan V2 API key works across mainnet, base, bsc, etc.
    // Get one at https://etherscan.io/myapikey
    apiKey: etherscanApiKey,
  },
};

export default config;
