const { ethers, network } = require("hardhat");

async function main() {
  const proxyAddress = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";

  // EIP-1967 impl slot
  const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
  const raw = await network.provider.send("eth_getStorageAt", [proxyAddress, IMPL_SLOT, "latest"]);
  const implAddress = ethers.getAddress("0x" + raw.slice(-40));
  console.log("Proxy:           ", proxyAddress);
  console.log("Implementation:  ", implAddress);

  // Try estimateStakeFee and surface what happens
  const c = await ethers.getContractAt("SoakverseDAO", proxyAddress);
  try {
    const fee = await c.estimateStakeFee();
    console.log("estimateStakeFee() =", fee.toString(), "wei");
  } catch (e) {
    console.log("estimateStakeFee() reverted:");
    console.log(e.message.split("\n")[0]);
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
