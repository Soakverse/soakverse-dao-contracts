const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";
  const ContractFactory = await ethers.getContractFactory("SoakverseDAO");

  console.log(`Validating storage compatibility for upgrade of ${proxyAddress}...`);
  await upgrades.validateUpgrade(proxyAddress, ContractFactory, {
    kind: "uups",
  });
  console.log("Storage layout OK — safe to upgrade.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
