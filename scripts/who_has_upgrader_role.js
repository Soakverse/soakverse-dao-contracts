const { ethers } = require("hardhat");

async function main() {
  const proxyAddress = "0x80233f7b42b503B09fc1cFF0894912cbCDA816e6";
  const dao = await ethers.getContractAt("SoakverseDAO", proxyAddress);

  const role = ethers.id("UPGRADER_ROLE"); // keccak256("UPGRADER_ROLE")
  const count = await dao.getRoleMemberCount(role);
  console.log(`UPGRADER_ROLE holders: ${count}`);
  for (let i = 0n; i < count; i++) {
    const addr = await dao.getRoleMember(role, i);
    console.log(`  [${i}] ${addr}`);
  }

  const adminRole = await dao.DEFAULT_ADMIN_ROLE();
  const adminCount = await dao.getRoleMemberCount(adminRole);
  console.log(`DEFAULT_ADMIN_ROLE holders: ${adminCount}`);
  for (let i = 0n; i < adminCount; i++) {
    const addr = await dao.getRoleMember(adminRole, i);
    console.log(`  [${i}] ${addr}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
