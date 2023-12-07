# Soakverse DAO
The Soakverse DAO contract is an updated version of the [Soakverse OG NFT contract](https://etherscan.io/address/0x2019f1aa40528e632b4add3b8bcbc435dbf86404). While this documentation focuses on technical details of the smart contracts and additional components, domain-specific information on Soakverse DAO and Soakverse OG can be found within the [offical documentation](https://docs.soakverse.io/soakverse/skmt-token-1/soakverse-ogs-genesis).

## Migration from OG to DAO
Since Soakverse OG's are deprecated, the Soakverse DAO contract offers the functionality to convert Soakverse OG NFTs to Soakverse DAO NFTs, so-called *DAO passes*. Future Soakverse projects and mechanisms will be base a lot of functionality on *DAO passes*.

## Communication with Partner Components
The Soakverse DAO contract is communicating with various partner contracts on different EVM-based network. In general, this communication is based on [Chainlink CCIP](https://chain.link/cross-chain).

The following list provides an overview of all partner contracts and provides a general understand on the communication with Soakverse DAO.

**SoakverseLedger (BSC)**
Whenever a Soakverse DAO pass is staked, the *SoakverseLedger* contract on Binance Smart Chain (BSC) is notified along with information about the staked DAO pass. SoakverseLedger then updates its internal state to provide information on staked DAO passes for any supporting contract on BSC.

### Additional Ressources
* Chainlink CCIP Documentation
    * https://docs.chain.link/ccip/getting-started
    * https://docs.chain.link/ccip/tutorials/send-arbitrary-data
    * https://docs.chain.link/ccip/supported-networks
