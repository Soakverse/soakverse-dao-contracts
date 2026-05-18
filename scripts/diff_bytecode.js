/**
 * Compare the runtime bytecode at TARGET_IMPL on chain against the locally
 * compiled SoakverseDAO artifact. Prints sizes, metadata blob lengths, and
 * where they diverge.
 *
 * Usage: TARGET_IMPL=0x... npx hardhat run scripts/diff_bytecode.js --network mainnet
 */
const { ethers, artifacts } = require("hardhat");

function metadataLen(hex) {
  if (!hex || hex === "0x" || hex.length < 8) return null;
  return parseInt(hex.slice(-4), 16);
}

function stripMetadata(hex) {
  const len = metadataLen(hex);
  if (len === null || Number.isNaN(len)) return hex;
  const end = hex.length - 4 - len * 2;
  return end > 2 ? hex.slice(0, end) : hex;
}

function firstDiff(a, b) {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) {
    if (a[i] !== b[i]) return i;
  }
  return a.length === b.length ? -1 : n;
}

async function main() {
  const target = process.env.TARGET_IMPL;
  if (!target) throw new Error("Set TARGET_IMPL=0x...");

  const [signer] = await ethers.getSigners();
  const onchain = await signer.provider.getCode(target);
  const local = (await artifacts.readArtifact("SoakverseDAO")).deployedBytecode;

  const oM = metadataLen(onchain);
  const lM = metadataLen(local);
  const oStripped = stripMetadata(onchain);
  const lStripped = stripMetadata(local);

  console.log("On-chain bytecode bytes:", (onchain.length - 2) / 2);
  console.log("Local bytecode bytes:   ", (local.length - 2) / 2);
  console.log("On-chain metadata bytes:", oM);
  console.log("Local metadata bytes:   ", lM);
  console.log("On-chain stripped bytes:", (oStripped.length - 2) / 2);
  console.log("Local stripped bytes:   ", (lStripped.length - 2) / 2);

  const matchStripped = oStripped.toLowerCase() === lStripped.toLowerCase();
  console.log("\nStripped bytecodes match:", matchStripped);

  if (!matchStripped) {
    const i = firstDiff(oStripped.toLowerCase(), lStripped.toLowerCase());
    console.log("First diff at hex offset:", i, "(byte", Math.floor((i - 2) / 2), ")");
    console.log("On-chain @diff:", oStripped.slice(Math.max(0, i - 20), i + 40));
    console.log("Local @diff:   ", lStripped.slice(Math.max(0, i - 20), i + 40));
  }

  // Also show the metadata payloads — they reveal the embedded source paths
  // and solc version, which often explains compile-environment drift.
  const oMetaStart = onchain.length - 4 - (oM || 0) * 2;
  const lMetaStart = local.length - 4 - (lM || 0) * 2;
  console.log("\nOn-chain metadata blob (hex):", onchain.slice(oMetaStart, -4));
  console.log("Local metadata blob (hex):   ", local.slice(lMetaStart, -4));
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
