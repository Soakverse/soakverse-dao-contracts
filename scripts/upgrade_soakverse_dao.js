const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory("SoakverseDAO");

  console.log("Deploying contracts with the account");

  const proxyAddress = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";

  const instance = await upgrades.upgradeProxy(proxyAddress, ContractFactory);
  console.log("Proxy upgraded to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
