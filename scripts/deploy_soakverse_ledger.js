const { ethers, upgrades } = require("hardhat");
const fs = require("fs");

async function main() {

  // const alreadyStakedEncoded = [];
  // run `get_staked_passes.js` to generate a file of already staked tokens.
  const alreadyStaked = JSON.parse(fs.readFileSync("stakedTokens.json"), "utf8");
  const aleadyStakedEncoded = alreadyStaked.encoded;

  const ContractFactory = await ethers.getContractFactory("SoakverseLedgerUpgradeable");

  console.log("Deploying Soakverse Ledger");

  // const bscCCipRouterAddress = "0x536d7E53D0aDeB1F20E7c81fea45d02eC9dBD698"; // https://docs.chain.link/ccip/supported-networks/mainnet#bnb-mainnet
  const baseCCipRouterAddress = "0x881e3A65B4d4a04dD529061dd0071cf975F58bCD"; // https://docs.chain.link/ccip/supported-networks/v1_2_0/mainnet#base-mainnet

  const instance = await upgrades.deployProxy(ContractFactory, [baseCCipRouterAddress, aleadyStakedEncoded]);
  await instance.waitForDeployment();
  console.log("Proxy deployed to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
