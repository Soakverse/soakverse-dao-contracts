// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
 * Graveyard contract for OGs that are supposed to be burned.
 */
contract SoakverseOgGraveyard is IERC721Receiver {
    
  function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

}