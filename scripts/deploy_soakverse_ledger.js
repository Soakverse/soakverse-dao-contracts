const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory("SoakverseLedgerUpgradeable");

  console.log("Deploying Soakverse Ledger");

  const bscCCipRouterAddress = "0x536d7E53D0aDeB1F20E7c81fea45d02eC9dBD698"; // https://docs.chain.link/ccip/supported-networks/mainnet#bnb-mainnet

  const instance = await upgrades.deployProxy(ContractFactory, [bscCCipRouterAddress]);
  await instance.waitForDeployment();
  console.log("Proxy deployed to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
