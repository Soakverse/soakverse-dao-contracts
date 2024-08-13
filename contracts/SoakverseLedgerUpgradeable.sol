// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

import {ISoakverseLedger} from "./ISoakverseLedger.sol";
import {CCIPReceiverUpgradeable} from "./ccip/CCIPReceiverUpgradeable.sol";

/**
 * Ledger contract that maintains information on staked DAO passes on Ethereum.
 * It receives updates on staking/unstaking via CCIP Messages from the SoakverseDAO contract on Ethereum.
 */
contract SoakverseLedgerUpgradeable is
  UUPSUpgradeable,
  AccessControlEnumerableUpgradeable,
  ISoakverseLedger,
  CCIPReceiverUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(uint256 => DaoPassStatus) private tokenIdToDaoPassStatus;

    mapping(address => uint256) private ownerToStakedBalance;
    mapping(address => mapping(uint256 => uint256)) private ownerToStakedTokens;
    mapping(uint256 => uint256) private stakedTokenToOwnerIndex;

    error UnknownCcipMessageSender(uint64 chainSelector, address sender);
    error IndexOutOfStakedBounds();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _ccipRouter, bytes[] memory _alreadyStaked) external initializer {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __CCIPReceiverUpgradeable_init(_ccipRouter);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);

        for(uint256 i = 0; i < _alreadyStaked.length; i++) {
            // decode message content
            (uint256 tokenId, uint8 tokenLevel, address tokenOwner, uint256 timestamp) = 
                abi.decode(_alreadyStaked[i], (uint256, uint8, address, uint256));

            // update storage
            DaoPassStatus memory status = DaoPassStatus(tokenOwner, true, tokenLevel, timestamp);
            tokenIdToDaoPassStatus[tokenId] = status;

            uint256 ownerBalance = ownerToStakedBalance[tokenOwner];
            ownerToStakedTokens[tokenOwner][ownerBalance] = tokenId;
            stakedTokenToOwnerIndex[tokenId] = ownerBalance;
            ownerToStakedBalance[tokenOwner] = ownerBalance + 1;
        }
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyRole(UPGRADER_ROLE){}

    function supportsInterface(bytes4 interfaceId) public pure virtual
        override(CCIPReceiverUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool) {
            
        return CCIPReceiverUpgradeable.supportsInterface(interfaceId)
           || interfaceId ==  type(ISoakverseLedger).interfaceId;
    }

    // handle receiving ccip message
    function _ccipReceive(Client.Any2EVMMessage memory ccipMessage) internal override {

        // sender: DAO Pass on Ethereum
        if((ccipMessage.sourceChainSelector == uint64(5009297550715157269)) 
            && (abi.decode(ccipMessage.sender, (address)) == address(0x80233f7b42b503B09fc1cFF0894912cbCDA816e6))) {

            // decode message content
            (uint8 action, uint256 tokenId, uint8 tokenLevel, address tokenOwner, uint256 timestamp) = 
                abi.decode(ccipMessage.data, (uint8, uint256, uint8, address, uint256));
            
            // update dao pass status (action = 1 staking | action = 0 unstaking)
            DaoPassStatus memory status = DaoPassStatus(
                                            tokenOwner,
                                            action == 1 ? true : false,
                                            tokenLevel,
                                            action == 1 ? timestamp : 0
            );
            tokenIdToDaoPassStatus[tokenId] = status;

            // update structures of staked passes per user
            uint256 ownerBalance = ownerToStakedBalance[tokenOwner];
            if(action == 1) {
                ownerToStakedTokens[tokenOwner][ownerBalance] = tokenId;
                stakedTokenToOwnerIndex[tokenId] = ownerBalance;
                ownerToStakedBalance[tokenOwner] = ownerBalance + 1;
            }
            else {
                uint256 tokenIndex = stakedTokenToOwnerIndex[tokenId];
                uint256 tokenIdOwnerAtLastIndex = ownerToStakedTokens[tokenOwner][ownerBalance-1];
                ownerToStakedTokens[tokenOwner][tokenIndex] = tokenIdOwnerAtLastIndex;
                ownerToStakedTokens[tokenOwner][ownerBalance-1] = 0;
                ownerToStakedBalance[tokenOwner] = ownerBalance - 1;
            }

        }
        else {
            revert UnknownCcipMessageSender(ccipMessage.sourceChainSelector, abi.decode(ccipMessage.sender, (address)));
        }
    }

    // --- DAO pass status and information on staked passes ---
    function daoPassStatus(uint256 tokenId) external view returns (DaoPassStatus memory) {
        return tokenIdToDaoPassStatus[tokenId];
    }

    function stakedBalance(address owner) external view returns (uint256) {
        return ownerToStakedBalance[owner];
    }

    function stakedTokenForOwnerAtIndex(address owner, uint256 index) external view returns (uint256) {
        if(index >= ownerToStakedBalance[owner]) revert IndexOutOfStakedBounds();
        return ownerToStakedTokens[owner][index];
    }

}