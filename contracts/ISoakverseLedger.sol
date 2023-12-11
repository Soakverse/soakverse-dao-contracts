// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISoakverseLedger {

    struct DaoPassStatus {
        address owner;
        bool staked;
        uint8 level;
        uint256 stakeTimestamp;
    }

  function daoPassStatus(uint256 tokenId) external view returns (DaoPassStatus memory);
  function stakedBalance(address owner) external view returns (uint256);
  function stakedTokenForOwnerAtIndex(address owner, uint256 index) external view returns (uint256);
}