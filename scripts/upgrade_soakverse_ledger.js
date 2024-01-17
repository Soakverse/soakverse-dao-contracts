const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory(
    "SoakverseLedgerUpgradeable"
  );

  console.log("Deploying contracts with the account");

  const proxyAddress = "0xAD13Ea5f72D8a8898a572777d1cba971105cEC11";

  const instance = await upgrades.upgradeProxy(proxyAddress, ContractFactory);
  console.log("Proxy upgraded to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
