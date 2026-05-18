/**
 * Re-register the deployed proxy + its current implementation in the local OZ
 * manifest. Run this after a manual upgrade so subsequent `upgrades.upgradeProxy`
 * calls work normally again.
 *
 * Usage:
 *   npx hardhat run scripts/reimport_proxy.js --network mainnet
 */
const { ethers, upgrades, network } = require("hardhat");

const PROXY_ADDRESS = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";
const CONTRACT_NAME = "SoakverseDAO";

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("Network:    ", network.name);
  console.log("Proxy:      ", PROXY_ADDRESS);
  console.log("Contract:   ", CONTRACT_NAME);
  console.log("Signer:     ", await signer.getAddress());

  const Factory = await ethers.getContractFactory(CONTRACT_NAME, signer);

  // forceImport reads the proxy's current EIP-1967 implementation slot from
  // chain and writes both proxy + impl entries into .openzeppelin/<network>.json.
  // It also performs a storage-layout check against the provided factory.
  console.log("\nRunning forceImport...");
  const instance = await upgrades.forceImport(PROXY_ADDRESS, Factory, {
    kind: "uups",
  });
  console.log("Imported proxy at:", await instance.getAddress());
  console.log("Manifest updated. Subsequent upgrades.upgradeProxy(...) calls will work normally.");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
