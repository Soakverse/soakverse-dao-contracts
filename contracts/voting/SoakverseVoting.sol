// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import {ISoakverseLedger} from "../ISoakverseLedger.sol";
import {IActivityLog} from "../activity/IActivityLog.sol";


contract SoakverseVoting is
  ERC721EnumerableUpgradeable,
  UUPSUpgradeable,
  AccessControlEnumerableUpgradeable
{

    using StringsUpgradeable for uint256;

    struct VoteDetail {
        address creator;
        uint256 createdAt;
        uint256 consensusId;
        uint256 participants;
        uint256 weightTrue;
        uint256 weightFalse;
    }

    struct ConsensusDetail {
        uint256 createdAt;
        uint256 voteDuration;                   // duration until a vote has ended
        uint256 weightAttendeeTreshold;         // minimum total attendee weight to consider a vote to be valid
        uint256 successPercentage;              // percentage one directions needs to have for the vote to be considered valid
                                                // we consider a percentage value with up to 2 decimals, so 1% is 100 <-- To BE CHECKED
    }

    ISoakverseLedger public ledger;
    IActivityLog public activityLog;

    // number of created votes
    uint256 public totalVotes;

    // mapping that assigns each level of a DAO pass a certain voting weight
    mapping(uint8 => uint8) public levelToWeight;

    // mapping that stores the timestamp when a user created their last vote
    mapping(address => uint256) public userToLastVoteCreatedAt;

    // mapping that stores historical consensus models
    mapping(uint256 => ConsensusDetail) public consensusIdToConsensusDetail;

    // mapping that stores the vote details for each vote id
    mapping(uint256 => VoteDetail) private voteIdToVoteDetail;

    // mapping that stores if an address participated in a vote
    mapping(address => mapping(uint256 => bool)) private userToVoteToAttended;

    //--- vote configurations ---
    uint32 public voteCreationWeightTreshold;       // total voting weight that an address needs to have to create a vote
    uint32 public voteAttendanceWeightTreshold;     // total voting weight that an address needs to have to attend a vote
    uint256 public voteCreationCooldown;             // timespan until an address can create another vote

    uint256 public currentConsensusId;              // id of the currently valid consensus

    event VoteAttendance(uint256 voteId);
    event NewVote(uint256 voteId);

    error VoteNFTCannotBeTransferred();
    error VotingWeightTooLow(uint32 actual, uint32 required);
    error VoteCreationCooldown(uint256 actual, uint256 required);
    error NonExistingVoteId(uint256 voteId);
    error VoteDurationExpired(uint256 voteId);
    error UserAlreadyVoted(uint256 voteId, address voter);


    modifier onlyExistingVote(uint256 voteId) {
        if(voteId < totalVotes) {
            _;
        }
        else {
            revert NonExistingVoteId(voteId);
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _ledger, address _activityLog) external initializer {
        __ERC721_init("Soakverse Voting", "SOAKVOTING");

        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __Pausable_init();

        ledger = ISoakverseLedger(_ledger);
        activityLog = IActivityLog(_activityLog);

        // init level to weight mapping
        levelToWeight[1] = 4;
        levelToWeight[2] = 5;
        levelToWeight[3] = 6;
        levelToWeight[4] = 8;
        levelToWeight[5] = 10;

        totalVotes = 0;

        voteCreationCooldown = 7 days;
        voteCreationWeightTreshold = 10;
        voteAttendanceWeightTreshold = 1;

        currentConsensusId = 0;
        consensusIdToConsensusDetail[currentConsensusId] = ConsensusDetail(
                                                                block.timestamp,
                                                                7 days,
                                                                605,    
                                                                7500);    //75.00%
    }

    function version() external pure virtual returns (string memory) {
        return "1.0.0";
    }

    /**
     * Create a new vote as an NFT.
     */
    function createVote() public {

        uint32 voteWeight = totalVoteWeight(msg.sender);

        // check 1: has user enough vote weight to create a vote?
        if(voteWeight >= voteCreationWeightTreshold) {

            uint256 cooldown = block.timestamp - userToLastVoteCreatedAt[msg.sender];

            // chek 2: has user not created another vote before cooldown?
            if(cooldown > voteCreationCooldown) {

                // actual vote creation - to be extended regarding metadata
                _safeMint(msg.sender, totalVotes);
                userToLastVoteCreatedAt[msg.sender] = block.timestamp;

                voteIdToVoteDetail[totalVotes] = VoteDetail(msg.sender, block.timestamp, currentConsensusId, 1, voteWeight, 0);
            
                activityLog.logActivity(msg.sender);
                emit NewVote(totalVotes);
                totalVotes = totalVotes + 1;
            }
            else {
                revert VoteCreationCooldown(cooldown, voteCreationCooldown);
            }
        }
        else {
            revert VotingWeightTooLow(voteWeight, voteCreationWeightTreshold);
        }
    }

    /**
     * Participate in a vote.
     */
    function vote(uint256 voteId, bool position) public onlyExistingVote(voteId) {

        uint32 userVoteWeight = totalVoteWeight(msg.sender);

        // check 1: does user have enough voting weight?
        if(userVoteWeight >= voteAttendanceWeightTreshold) {

            VoteDetail memory detail = voteIdToVoteDetail[voteId];
            ConsensusDetail memory consensus = consensusIdToConsensusDetail[detail.consensusId];

            // check 2: is vote duration not expired?
            if((detail.createdAt + consensus.voteDuration) > block.timestamp) { 

                // check 3: has user not voted yet?
                if(!userToVoteToAttended[msg.sender][voteId]) {
        
                    // update vote details
                    if (position) {
                        detail.weightTrue = detail.weightTrue + userVoteWeight;
                    }
                    else {
                        detail.weightFalse = detail.weightFalse + userVoteWeight;

                    }

                    // update state variables
                    voteIdToVoteDetail[voteId] = detail;
                    userToVoteToAttended[msg.sender][voteId] = true;
                    // log activity
                    activityLog.logActivity(msg.sender);

                    emit VoteAttendance(voteId);
                }
                else {
                    revert UserAlreadyVoted(voteId, msg.sender);
                }
            }
            else {
                revert VoteDurationExpired(voteId);
            }

        }
        else {
            revert VotingWeightTooLow(userVoteWeight, voteAttendanceWeightTreshold);
        }
    }


    /**
     * Get the details on a vote including the consensus information that were
     * active when the vote was created.
     * Additionally, this function checks if the vote suits all criterias to 
     * be considered a valid vote.
     */
    function voteStatus(uint256 voteId) public view onlyExistingVote(voteId)
        returns (bool valid, VoteDetail memory detail, ConsensusDetail memory consensus) {
        
        detail = voteIdToVoteDetail[voteId];
        consensus = consensusIdToConsensusDetail[detail.consensusId];
        valid = false;

        // check 1: vote has ended
        if((detail.createdAt + consensus.voteDuration) < block.timestamp) {         

            uint256 totalWeight = detail.weightTrue + detail.weightFalse;

            // check 2: attendee total weight surpasses treshold
            if(totalWeight >= consensus.weightAttendeeTreshold) {                   

                uint256 truePercentage = (detail.weightTrue * 10000) / totalWeight;
                uint256 falsePercentage = (detail.weightFalse * 10000) / totalWeight;

                // check 3: either one option reached sucess percentage
                if((truePercentage >= consensus.successPercentage) || (falsePercentage >= consensus.successPercentage)) {
                    valid = true;
                }
            }
        }
    }

    /**
     * Get the total voting weight of an address based on the levels of their staked DAO passes, 
     * queried from the connected Soakverse ledger.
     */
    function totalVoteWeight(address user) public view returns (uint32) {
        uint256 ledgerBalance = ledger.stakedBalance(user);
        uint32 totalWeight = 0;
        for (uint256 i = 0; i < ledgerBalance; i++) {
            ISoakverseLedger.DaoPassStatus memory tmpStatus = ledger.daoPassStatus(ledger.stakedTokenForOwnerAtIndex(user, i));
            totalWeight = totalWeight + levelToWeight[tmpStatus.level];
        }
        return totalWeight;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        
        revert VoteNFTCannotBeTransferred();

    }

    function supportsInterface(bytes4 interfaceId) public view virtual
        override(ERC721EnumerableUpgradeable, AccessControlEnumerableUpgradeable)
        returns (bool) {

        return ERC721EnumerableUpgradeable.supportsInterface(interfaceId) 
        || AccessControlEnumerableUpgradeable.supportsInterface(interfaceId);
  }



}