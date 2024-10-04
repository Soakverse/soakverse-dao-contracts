const { ethers } = require('hardhat');
const fs = require('fs');

async function main() {
  console.log('PROCESS STARTED');
  const proxyAddress = '0x80233f7b42b503B09fc1cFF0894912cbCDA816e6';
  const dao = await ethers.getContractAt('SoakverseDAO', proxyAddress);

  // get all stake events
  const startBlock = 18691929;
  const endBlock = await ethers.provider.getBlockNumber();
  const stepSize = 5000;
  let stakeEvents = [];

  for (let i = startBlock; i <= endBlock; i += stepSize) {
    console.log('STEP STARTED: ');
    console.log(i);
    const stepEnd = Math.min(i + stepSize - 1, endBlock);

    const stepEvents = await dao.queryFilter(
      dao.filters['Stake(uint256,address,uint256)'],
      i,
      stepEnd
    );
    stakeEvents = stakeEvents.concat(
      stepEvents.map((event) => {
        const tokenId = String(event.args.tokenId);
        const by = event.args.by;
        const stakedAt = String(event.args.stakedAt);
        return { tokenId, by, stakedAt };
      })
    );
    console.log('STEP FINISHED');
  }

  // get all unstake events
  let unstakeEvents = [];
  for (let i = startBlock; i <= endBlock; i += stepSize) {
    const stepEnd = Math.min(i + stepSize - 1, endBlock);

    const stepEvents = await dao.queryFilter(
      dao.filters['Unstake(uint256,address,uint256,uint256)'],
      i,
      stepEnd
    );
    unstakeEvents = unstakeEvents.concat(
      stepEvents.map((event) => {
        const tokenId = String(event.args.tokenId);
        const by = event.args.by;
        const stakedAt = String(event.args.unstakedAt); // note: this is because of a bug in the contract where we the timestamp for stake and unstake are switched. this will be fixed with the next contract upgrade
        return { tokenId, by, stakedAt };
      })
    );
  }

  // filter out all unstake events from all stake events
  let stakedTokens = stakeEvents.filter(
    (stakeEvent) =>
      !unstakeEvents.some(
        (unstakeEvent) =>
          unstakeEvent.tokenId == stakeEvent.tokenId &&
          unstakeEvent.by == stakeEvent.by &&
          unstakeEvent.stakedAt == stakeEvent.stakedAt
      )
  );

  // add token level for each staked token
  for (let i = 0; i < stakedTokens.length; i++) {
    const tokenLevel = await dao.tokenLevel(stakedTokens[i].tokenId);
    stakedTokens[i] = { ...stakedTokens[i], level: String(tokenLevel) };
  }

  // abi encode all staked tokens
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  const stakedTokensEncoded = stakedTokens.map((i) =>
    abiCoder.encode(
      ['uint256', 'uint8', 'address', 'uint256'],
      [BigInt(i.tokenId), Number(i.level), i.by, BigInt(i.stakedAt)]
    )
  );

  fs.writeFileSync(
    'stakedTokens.json',
    JSON.stringify({ decoded: stakedTokens, encoded: stakedTokensEncoded }),
    'utf8'
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
