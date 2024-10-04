// hardhat.config.js
import '@nomiclabs/hardhat-ethers';
import '@openzeppelin/hardhat-upgrades';
import '@nomicfoundation/hardhat-verify';
import { HardhatUserConfig } from 'hardhat/types';

const {
  mainnetAccount,
  testnetAccount,
  localhostDeployAccount,
  infuraProjectId,
  etherscanApiKey,
  bscScanDevApiKey,
  basescanApiKey,
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
      accounts: [localhostDeployAccount],
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
      url: 'https://mainnet.infura.io/v3/' + infuraProjectId,
      accounts: [mainnetAccount],
    },
    base: {
      url: 'https://mainnet.base.org',
      chainId: 8453,
      accounts: [mainnetAccount],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: etherscanApiKey,
      bsc: bscScanDevApiKey,
      base: basescanApiKey,
    },
  },
};

export default config;
