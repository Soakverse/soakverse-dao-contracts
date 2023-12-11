// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IAny2EVMMessageReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

/**
 * Upgradeable version of: https://github.com/smartcontractkit/ccip/blob/ccip-develop/contracts/src/v0.8/ccip/applications/CCIPReceiver.sol
 */
abstract contract CCIPReceiverUpgradeable is Initializable, IAny2EVMMessageReceiver, IERC165  {

    IRouterClient internal ccipRouter;

    error InvalidRouter(address routerAddress);

    //only calls from the set router are accepted.
    modifier onlyRouter() {
        if (msg.sender != address(ccipRouter)) revert InvalidRouter(msg.sender);
        _;
    }

    function __CCIPReceiverUpgradeable_init(address _router) internal onlyInitializing {
        if (_router == address(0)) revert InvalidRouter(address(0));
        ccipRouter = IRouterClient(_router);
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IAny2EVMMessageReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function ccipReceive(Client.Any2EVMMessage calldata message) external virtual override onlyRouter {
        _ccipReceive(message);
    }

    /// @notice Override this function in your implementation.
    function _ccipReceive(Client.Any2EVMMessage memory message) internal virtual;

    function getRouter() public view returns (address) {
        return address(ccipRouter);
    }
}
