const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory("SoakverseDAO");

  console.log("Deploying contracts with the account");

  const proxyAddress = "0xEB40A91132741c6B96cab019b3Cb11b21608AEcF";

  const instance = await upgrades.upgradeProxy(proxyAddress, ContractFactory);
  console.log("Proxy upgraded to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
