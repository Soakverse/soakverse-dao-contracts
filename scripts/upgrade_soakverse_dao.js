const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";

  const [signer] = await ethers.getSigners();
  console.log(`Upgrading ${proxyAddress} with ${await signer.getAddress()}`);

  const ContractFactory = await ethers.getContractFactory("SoakverseDAO", signer);
  const instance = await upgrades.upgradeProxy(proxyAddress, ContractFactory);
  console.log("Proxy upgraded. Address:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
