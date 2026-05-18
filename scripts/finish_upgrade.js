/**
 * Manual finish for an upgrade that already deployed an implementation but
 * failed before swapping the proxy. Only use this if `upgrades.upgradeProxy`
 * cannot succeed on retry. Refuses to run unless:
 *   - TARGET_IMPL is explicitly pinned (no "pick newest" heuristic)
 *   - the impl's runtime bytecode matches the locally compiled artifact
 *   - the impl is ERC-1822 compliant (returns expected proxiableUUID)
 *   - OZ storage-layout validation passes against the new factory
 *   - operator confirms via CONFIRM=I_UNDERSTAND env var
 */
const { ethers, upgrades, artifacts, network } = require("hardhat");

// --- REQUIRED: pin the exact implementation address you intend to swap to.
//     Read it from .openzeppelin/<network>.json (the entry whose txHash matches
//     the deploy tx your previous run printed). Do NOT guess.
const TARGET_IMPL = process.env.TARGET_IMPL || "";

const PROXY_ADDRESS = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";
const CONTRACT_NAME = "SoakverseDAO";

// EIP-1967 implementation slot
const IMPL_SLOT = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
// ERC-1822 proxiableUUID() always returns this value for UUPS proxies
const EXPECTED_PROXIABLE_UUID = IMPL_SLOT;

async function readImplSlot(provider, proxy) {
  const raw = await provider.send("eth_getStorageAt", [proxy, IMPL_SLOT, "latest"]);
  return ethers.getAddress("0x" + raw.slice(-40));
}

function stripMetadata(hex) {
  // Solidity appends a CBOR-encoded metadata trailer to runtime bytecode that
  // varies between compilations even for identical source. Strip it so we can
  // compare implementations across machines / build artifacts.
  // The last 2 bytes are the metadata length; the rest before that is metadata.
  if (!hex || hex === "0x") return hex;
  const len = parseInt(hex.slice(-4), 16);
  if (Number.isNaN(len)) return hex;
  const end = hex.length - 4 - len * 2;
  return end > 2 ? hex.slice(0, end) : hex;
}

async function main() {
  if (!TARGET_IMPL || !ethers.isAddress(TARGET_IMPL)) {
    throw new Error(
      "Set TARGET_IMPL=0x... env var to the implementation you intend to swap to. " +
      "Find it in .openzeppelin/" + network.name + ".json under impls — match by the deploy txHash you got from the failed run."
    );
  }
  if (process.env.CONFIRM !== "I_UNDERSTAND") {
    throw new Error("Set CONFIRM=I_UNDERSTAND to acknowledge you reviewed the risks.");
  }

  const [signer] = await ethers.getSigners();
  const provider = signer.provider;
  console.log("Network:        ", network.name);
  console.log("Proxy:          ", PROXY_ADDRESS);
  console.log("Target impl:    ", TARGET_IMPL);
  console.log("Signer:         ", await signer.getAddress());

  // 1. Make sure the target impl has bytecode on this chain
  const code = await provider.getCode(TARGET_IMPL);
  if (code === "0x") throw new Error("Target impl has no bytecode on " + network.name);

  // 2. Bytecode integrity. Compare the on-chain runtime code against the
  //    locally compiled artifact. Two acceptable cases:
  //      (a) full stripped bytecodes match exactly, or
  //      (b) the embedded metadata IPFS hash matches (same source + settings),
  //          which OZ uses for impl deduplication. This covers the case where
  //          Solidity has patched in `immutable` values (e.g. UUPSUpgradeable's
  //          __self = address(this)) that the local artifact leaves as zeros.
  const artifact = await artifacts.readArtifact(CONTRACT_NAME);
  const expected = stripMetadata(artifact.deployedBytecode);
  const actual = stripMetadata(code);
  const fullMatch = expected.toLowerCase() === actual.toLowerCase();

  const metaOf = (hex) => {
    const len = parseInt(hex.slice(-4), 16);
    if (Number.isNaN(len)) return null;
    const start = hex.length - 4 - len * 2;
    return start > 2 ? hex.slice(start, -4) : null;
  };
  const metadataMatch =
    metaOf(code) && metaOf(code) === metaOf(artifact.deployedBytecode);

  if (!fullMatch && !metadataMatch) {
    throw new Error(
      "Target impl bytecode does not match locally compiled " + CONTRACT_NAME +
      ". Refusing to upgrade. (Rebuild with `npx hardhat compile` if you intended this impl, or pin a different TARGET_IMPL.)"
    );
  }
  if (fullMatch) {
    console.log("Bytecode check: OK (exact match)");
  } else {
    console.log("Bytecode check: OK (metadata IPFS hash matches; non-metadata diffs are Solidity immutable resolution)");
  }

  // 3. ERC-1822 compliance — the impl must declare itself UUPS-proxiable.
  //    Calling proxiableUUID() directly on the impl, not the proxy.
  const impl = new ethers.Contract(
    TARGET_IMPL,
    ["function proxiableUUID() view returns (bytes32)"],
    provider
  );
  let uuid;
  try {
    uuid = await impl.proxiableUUID();
  } catch (e) {
    throw new Error("Target impl does not expose proxiableUUID() — not a valid UUPS impl. Refusing.");
  }
  if (uuid.toLowerCase() !== EXPECTED_PROXIABLE_UUID.toLowerCase()) {
    throw new Error("proxiableUUID() = " + uuid + " (expected " + EXPECTED_PROXIABLE_UUID + "). Refusing.");
  }
  console.log("ERC-1822 check: OK");

  // 4. OZ storage-layout validation against the new factory.
  const Factory = await ethers.getContractFactory(CONTRACT_NAME, signer);
  await upgrades.validateUpgrade(PROXY_ADDRESS, Factory, { kind: "uups" });
  console.log("Storage check:  OK");

  // 5. Idempotency — bail if proxy is already pointing here.
  const currentImpl = await readImplSlot(provider, PROXY_ADDRESS);
  console.log("Current impl:   ", currentImpl);
  if (currentImpl.toLowerCase() === TARGET_IMPL.toLowerCase()) {
    console.log("Proxy already points at TARGET_IMPL. Nothing to do.");
    return;
  }

  // 6. Swap. Use upgradeTo (not upgradeToAndCall) because this migration
  //    introduces no new initializable storage. OZ 4.x's upgradeToAndCall
  //    always delegate-calls the implementation even when data is empty
  //    (forceCall=true internally) — and SoakverseDAO has no fallback, so
  //    that path reverts with "Address: low-level delegate call failed".
  //    If a future migration needs reinitialization, encode the reinitializer
  //    calldata and call upgradeToAndCall with it explicitly.
  const proxy = new ethers.Contract(
    PROXY_ADDRESS,
    ["function upgradeTo(address newImplementation) external"],
    signer
  );

  console.log("\nCalling upgradeTo(TARGET_IMPL) ...");
  const tx = await proxy.upgradeTo(TARGET_IMPL);
  console.log("Tx hash:        ", tx.hash);
  const receipt = await tx.wait();
  console.log("Confirmed in block", receipt.blockNumber);

  const after = await readImplSlot(provider, PROXY_ADDRESS);
  console.log("New impl:       ", after);
  if (after.toLowerCase() !== TARGET_IMPL.toLowerCase()) {
    throw new Error("Post-upgrade impl mismatch: " + after);
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
