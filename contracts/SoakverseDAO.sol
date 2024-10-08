// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721EnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721RoyaltyUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";

import {IRegistry} from "./IRegistry.sol";
import {ISoakverseOG} from "./ISoakverseOG.sol";

import {CCIPSenderUpgradeable} from "./ccip/CCIPSenderUpgradeable.sol";


/**
 * @title Soakverse DAO ERC-721 Smart Contract
 */
contract SoakverseDAO is
  ERC721EnumerableUpgradeable,
  ERC721RoyaltyUpgradeable,
  UUPSUpgradeable,
  AccessControlEnumerableUpgradeable,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable,
  CCIPSenderUpgradeable
{
  using StringsUpgradeable for uint256;

  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  // indicator that specifies if OGs can be migrated to DAO NFTs
  bool public claimIsActive;
  // indicator that specifies if DAO NFTs can be staked
  bool public canStake;

  uint256 public maxSupply;

  string private baseURI;

  // registry that maintains transfer operator blacklists
  IRegistry public registry;

  // Soakverse OGs NFT contract
  ISoakverseOG public soakverseOg;

  mapping(uint256 => uint256) public tokensLastStakedAt;

  // nft level mapping by index. Index 0 is related to NFT with id 1
  uint8[365] private tokenLevels;

  // uri to metadata that describes the whole collection
  string public contractURI;


  error NonExistentToken();
  error NotAuthorizedToClaim();
  error UnauthorizedOwnerOfOg();
  error TokenStaked();
  error ClaimNotActive();
  error CcipFeeTooLow(uint256 actualFee, uint256 requiredFee);

  event ClaimActivation(bool isActive);
  event DaoPassClaimed(address indexed claimer, uint256 indexed tokenId, uint8 level);
  event Stake(uint256 indexed tokenId, address indexed by, uint256 stakedAt);
  event Unstake(uint256 indexed tokenId, address indexed by, uint256 stakedAt, uint256 unstakedAt);

  modifier onlyActiveClaim() {
    if(!claimIsActive) {
      revert ClaimNotActive();
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(
    address _registryContract,
    address _soakverseOgContract,
    address _ccipRouter
  )
  external
  initializer
  {
    __ERC721_init("Soakverse DAO Pass", "SOAKDAO");
    __ERC721Royalty_init(); 

    __UUPSUpgradeable_init();
    __ReentrancyGuard_init();
    __AccessControlEnumerable_init();
    __Pausable_init();

    __CCIPSenderUpgradeable_init(_ccipRouter, address(0));

    registry = IRegistry(_registryContract);
    soakverseOg = ISoakverseOG(_soakverseOgContract);

    claimIsActive = false;
    maxSupply = 365;
    canStake = false;

    // configure royalties
    _setDefaultRoyalty(address(0x4464FC02d751938B987745B2ff34860Ea1De00a0), 1000); // 10% royalties

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(PAUSER_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);

    // configure token levels
    tokenLevels = [ 
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 1, 4, 1, 2, 2, 1, 3, 3, 2, 1, 1, 5, 1, 2, 4, 1,
      1, 1, 3, 2, 3, 5, 1, 3, 1, 2, 3, 1, 1, 1, 4, 3, 3, 4, 1, 1, 1, 4, 1, 3, 1, 1,
      1, 2, 2, 4, 4, 2, 1, 5, 2, 1, 4, 1, 2, 5, 2, 3, 2, 1, 2, 5, 1, 4, 4, 1, 2, 3,
      2, 3, 2, 2, 2, 3, 1, 1, 5, 4, 3, 2, 2, 2, 2, 1, 1, 1, 3, 1, 2, 3, 2, 1, 1, 3,
      3, 4, 1, 1, 1, 5, 3, 3, 1, 1, 1, 2, 2, 3, 2, 2, 1, 2, 1, 3, 1, 1, 4, 2, 3, 2,
      2, 3, 5, 3, 2, 1, 1, 1, 4, 1, 3, 2, 3, 5, 1, 3, 1, 4, 3, 3, 2, 1, 3, 3, 1, 1,
      1, 1, 1, 2, 3, 3, 1, 1, 1, 1, 2, 3, 2, 5, 1, 1, 2, 3, 1, 1, 1, 1, 2, 5, 2, 1,
      5, 1, 1, 1, 5, 3, 2, 3, 2, 2, 3, 2, 3, 2, 2, 3, 1, 2, 1, 1, 4, 1, 1, 1, 3, 4,
      4, 3, 2, 1, 1, 1, 3, 1, 4, 1, 3, 4, 1, 4, 1, 1, 3, 1, 2, 1, 5, 1, 1, 4, 2, 2,
      3, 2, 5, 3, 2, 5, 5, 1, 2, 2, 1, 1, 2, 2, 3, 3, 2, 2, 2, 4, 3, 3, 1, 2, 1, 1,
      2, 2, 1, 3, 4, 3, 1, 2, 2, 2, 2, 2, 1, 1, 1, 4, 1, 4, 1, 4, 1, 1, 1, 2, 3, 4,
      4, 3, 1, 2, 3, 1, 1, 3, 1, 1, 4, 1, 3, 2, 2, 2, 2, 2, 3, 2, 2, 3, 1, 1, 1, 1,
      1, 1, 2, 2, 2, 1, 2, 2, 1, 2, 1, 2, 5, 2, 1, 1, 5, 1, 2, 2, 2, 5, 1, 3, 3, 2,
      1, 2, 3, 3, 2, 2, 3, 3, 1, 3, 2, 1, 4, 3, 2, 4, 2, 1, 2, 3, 2, 1, 3, 3, 4, 3,
      1];
  }

  function version() external pure virtual returns (string memory) {
    return "1.0.0";
  }

  /**
   * Get the level that is assigned to an NFT id. Various partner contracts
   * depend their logic on these levels.
   */
  function tokenLevel(uint256 tokenId) public view returns (uint8) {
    if(tokenId >= 1 && tokenId <= 365) {
      return tokenLevels[tokenId-1];
    }
    return 0;
  }

  /**
   * Claim a DAO pass for an OG NFT. As a precondition, this contract
   * needs approval to transfer the OG NFT via either `soakverseOg#approve`
   * or `soakverseOg#setApprovalForAll`.
   */
  function claim(uint256 ogId) external nonReentrant onlyActiveClaim {

    // only owner of OG can trigger claim
    if(soakverseOg.ownerOf(ogId) != msg.sender){
      revert UnauthorizedOwnerOfOg();
    }

    _claim(ogId);
  }

  /**
   * Claim DAO passes for all OG NFTs that the sender owns. The function
   * automatically identifies the ids of all relevant NFTs. 
   * As a precondition, this contract needs approval to transfer all
   * OGs NFTs of the sender via either `soakverseOg#approve` for each id
   * or `soakverseOg#setApprovalForAll`.
   */
  function claimAll() external nonReentrant onlyActiveClaim {
    uint256 claimerBalance = soakverseOg.balanceOf(msg.sender);

    // since the owner balance is shrinking during this process, we need
    // to have a temporary array of all ids to avoid any out-of-bounds
    // errors when we directly loop over the balance.
    uint256[] memory tokenIds = new uint256[](claimerBalance);
    for(uint256 i = 0; i < claimerBalance; i++) {
      tokenIds[i] = soakverseOg.tokenOfOwnerByIndex(msg.sender, i);
    }

    for(uint256 j = 0; j < tokenIds.length; j++) {
      _claim(tokenIds[j]);
    }
  }

  function _claim(uint256 ogId) private {
    address deadAddress = 0x000000000000000000000000000000000000dEaD;

    soakverseOg.transferFrom(
      msg.sender,
      deadAddress,
      ogId
    );
    _safeMint(msg.sender, ogId);
    emit DaoPassClaimed(msg.sender, ogId, tokenLevel(ogId));
  }


  // ---- METADATA ----
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if (!_exists(tokenId)) {
      revert NonExistentToken();
    }
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  function setBaseURI(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
    baseURI = uri;
  }

  function setContractURI(string memory newContractUri) external onlyRole(DEFAULT_ADMIN_ROLE) {
    contractURI = newContractUri;
  }

  // ---- ADMINISTRATION ----
  function toggleClaimStatus() public onlyRole(DEFAULT_ADMIN_ROLE) {
    claimIsActive = !claimIsActive;
    emit ClaimActivation(claimIsActive);
  }

  function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setDefaultRoyalty(receiver, feeNumerator);
  }

  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }


  // ---- TOKENOMICS ----
  function safeMint(address to, uint256 tokenId) public onlyRole(MINTER_ROLE) {
    _safeMint(to, tokenId);
  }

  function _safeMint(address to, uint256 tokenId) internal virtual override {
    require(totalSupply() + 1 <= maxSupply, "Maximum Supply reached");
    super._safeMint(to, tokenId, "");
  }

  function _burn(uint256 tokenId) internal override(ERC721Upgradeable, ERC721RoyaltyUpgradeable) {
    ERC721Upgradeable._burn(tokenId);  
  }

  function adminBurner(uint256[] calldata tokenIds) external onlyRole(DEFAULT_ADMIN_ROLE) {
    for (uint256 i; i < tokenIds.length; i++) {
        _burn(tokenIds[i]);
    }
  }

  function changeMaxSupply(uint256 number) external onlyRole(DEFAULT_ADMIN_ROLE) {
    maxSupply = number;
  }

  // ---- CCIP MESSAGING ----
  function setCcipRouter(address _router) external onlyRole(DEFAULT_ADMIN_ROLE) {
    CCIPSenderUpgradeable.setRouter(_router);
  }

  function setCcipGasLimit(uint256 _gasLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
    CCIPSenderUpgradeable.setGasLimit(_gasLimit);
  } 

  function setCcipFeeToken(address _feeToken) external onlyRole(DEFAULT_ADMIN_ROLE) {
    CCIPSenderUpgradeable.setFeeToken(_feeToken);
  }

  // ---- STAKING ----
  function setCanStake(bool _canStake) external onlyRole(DEFAULT_ADMIN_ROLE) {
    canStake = _canStake;
  }

  /**
   * request CCIP messaging fee to notify BSC ledger about staking
   */
  function estimateStakeFee() external view returns (uint256) {
    bytes memory dummyMessage = abi.encode(uint8(0), uint256(0), uint8(0), address(0), uint256(0)); // dummy stake message
    return CCIPSenderUpgradeable.estimateMessageFee(uint64(15971525489660198786), dummyMessage);
  }

  function stake(uint256 tokenId) public payable nonReentrant {
    require(canStake, "staking not open");
    require(
      msg.sender == ownerOf(tokenId) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
      "caller must be owner of token or contract owner"
    );
    require(tokensLastStakedAt[tokenId] == 0, "already staking");
    tokensLastStakedAt[tokenId] = block.timestamp;
    emit Stake(tokenId, msg.sender, tokensLastStakedAt[tokenId]);

    // notify Base ledger about stake
    // message structure:
    // |- uint8     1 - staked | 0 - unstaked
    // |- uint256   tokenId
    // |- uint8     tokenLevel
    // |- address   token owner
    // |- uint256   block timestamp
    CCIPSenderUpgradeable.sendCcipMessage(uint64(15971525489660198786), address(0x1e724A9769AfD222FfD7FF854fd781d1f4F8c91F), // tbd update with new address on base
      abi.encode(uint8(1), tokenId, tokenLevel(tokenId), ownerOf(tokenId), block.timestamp));
  }

  function unstake(uint256 tokenId) public payable nonReentrant {
    require(
      msg.sender == ownerOf(tokenId) || hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
      "caller must be owner of token or contract owner"
    );
    require(tokensLastStakedAt[tokenId] > 0, "not staking");
    uint256 lsa = tokensLastStakedAt[tokenId];
    tokensLastStakedAt[tokenId] = 0;
    emit Unstake(tokenId, msg.sender, lsa, block.timestamp);

    CCIPSenderUpgradeable.sendCcipMessage(uint64(15971525489660198786), address(0x1e724A9769AfD222FfD7FF854fd781d1f4F8c91F), // tbd update with new address on base
      abi.encode(uint8(0), tokenId, tokenLevel(tokenId), ownerOf(tokenId), block.timestamp));
  }

  // ---- TRANFER MODIFICATION ----

  /**
    * @notice Checks whether operator is valid on the registry. Will return true if registry isn't active.
    * @param operator - Operator address
  */
  function _isValidAgainstRegistry(address operator)
  internal
  view
  returns (bool)
  {
    return registry.isAllowedOperator(operator);
  }

  /**
    * @notice Checks whether msg.sender is valid on the registry. If not, it will
    * block the transfer of the token.
    * @param from - Address token is transferring from
    * @param to - Address token is transferring to
    * @param tokenId - Token ID being transfered
    * @param batchSize - Batch size
    */
  function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
    internal whenNotPaused override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    
    // check if token is staked
    if (tokensLastStakedAt[tokenId] != 0){
      revert TokenStaked();
    }

    // if if transfer operator is valid by querying registry
    if (_isValidAgainstRegistry(msg.sender)) {
      super._beforeTokenTransfer(
        from,
        to,
        tokenId,
        batchSize
      );
    } else {
      revert IRegistry.NotAllowed();
    }
  }

  function supportsInterface(bytes4 interfaceId)
  public
  view
  virtual
  override(ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable, AccessControlEnumerableUpgradeable)
  returns (bool)
  {
    return ERC721EnumerableUpgradeable.supportsInterface(interfaceId) 
      || ERC721RoyaltyUpgradeable.supportsInterface(interfaceId)
      || AccessControlEnumerableUpgradeable.supportsInterface(interfaceId);
  }

  function _authorizeUpgrade(address newImplementation)
  internal
  virtual
  override
  onlyRole(UPGRADER_ROLE)
  {}
}
