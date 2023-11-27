const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory("SoakverseDAO");

  console.log("Deploying contracts with the account");

  const instance = await upgrades.deployProxy(ContractFactory, [
    "0xc9e95F627B0a0f1df636a875A6Df3cF7b0071Ca5",
    "0x2019f1aa40528e632b4add3b8bcbc435dbf86404",
  ]);
  await instance.waitForDeployment();
  console.log("Proxy deployed to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
