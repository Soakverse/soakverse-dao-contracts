/**
 * Recover the contract address deployed by a given tx hash.
 * Usage: TX_HASH=0x... npx hardhat run scripts/lookup_deploy.js --network mainnet
 */
const { ethers } = require("hardhat");

async function main() {
  const txHash = process.env.TX_HASH;
  if (!txHash) throw new Error("Set TX_HASH=0x...");

  const [signer] = await ethers.getSigners();
  const provider = signer.provider;

  const receipt = await provider.getTransactionReceipt(txHash);
  if (!receipt) throw new Error("Tx not found on this network");
  if (!receipt.contractAddress) {
    throw new Error("This tx didn't create a contract (no contractAddress field)");
  }

  console.log("Block:           ", receipt.blockNumber);
  console.log("From:            ", receipt.from);
  console.log("Status:          ", receipt.status === 1 ? "success" : "failed");
  console.log("Deployed at:     ", receipt.contractAddress);

  const code = await provider.getCode(receipt.contractAddress);
  console.log("Bytecode length: ", (code.length - 2) / 2, "bytes");
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
