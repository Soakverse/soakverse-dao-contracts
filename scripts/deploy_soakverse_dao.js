const { ethers, upgrades } = require("hardhat");

async function main() {
  const ContractFactory = await ethers.getContractFactory("SoakverseDAO");

  console.log("Deploying contracts with the account");

  const instance = await upgrades.deployProxy(ContractFactory, [
    "0xc9e95F627B0a0f1df636a875A6Df3cF7b0071Ca5", // registry
    "0x2019f1aa40528e632b4add3b8bcbc435dbf86404", // soakverse dao
    "0xE561d5E02207fb5eB32cca20a699E0d8919a1476"  // eth ccip router
  ]);
  await instance.waitForDeployment();
  console.log("Proxy deployed to:", await instance.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
