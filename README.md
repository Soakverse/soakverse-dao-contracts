# Soakverse DAO Smart Contract Collection

## Documentation

* [Soakverse DAO](/docs/SoakverseDAO.md)


## Local deployment with Hardhat

### Prerequiste 
* Install Hardhat

### Deployment
```
npm install
npx hardhat node
```

* create .secrets.json from .secrets.json.example
* put first private key from hardat node inside localhostDeployAccount variable
* you must deploy full pancake swap or any other Uniswap clone on your local blockchain
* write dex router address and dev wallet in .secrets.json
* add a custom RPC to localhost:8545, chainId= 31337 and currency name BNB inside metamask

```
npx hardhat run --network localhost scripts/1_deploy_token.js --show-stack-traces
```

### Verify

npx hardhat verify --network <NETWORK_NAME> <CONTRACT_ADDRESS> "ConstructorArg1" "ConstructorArg2"


## Testing upgrades

cd soakverse-dao-contracts

  # 1. Put your REAL admin private key in .secrets.json -> mainnetAccount
  #

  # 2. (Recommended) Pause staking first to give users a clean error during the upgrade:
  #    Call setCanStake(false) on the proxy from your admin wallet.

  # 3. Fork-test the upgrade locally:
  FORK_URL="https://eth-mainnet.g.alchemy.com/v2/{alchemy key}" npx hardhat node

    or

  npx hardhat node --fork "https://eth-mainnet.g.alchemy.com/v2/{alchemy key}"
  # in another shell:
  npx hardhat run scripts/upgrade_soakverse_dao.js --network localhost

  # 4. Push the real upgrade:
  npx hardhat run scripts/upgrade_soakverse_dao.js --network mainnet

  # 5. Smoke test: call estimateStakeFee() on Etherscan Read tab. Then a tiny stake().

  # 6. setCanStake(true) once verified.

  ---

  ### Check roles on contract

  npx hardhat run scripts/who_has_upgrader_role.js --network localhost

  npx hardhat --network localhost console

  const c = await ethers.getContractAt("SoakverseDAO","0x80233f7b42b503B09fc1cFF0894912cbCDA816e6");
  await c.estimateStakeFee()