// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

import {IActivityLog} from "./IActivityLog.sol";

/**
 * This contracts gathers the number of activites of addresses with several partner contracts
 * during fixed intervals. Partner contracts that should report activities need to be granted 
 * the `ACTIVITY_LOGGER_ROLE` role.
 */
abstract contract AcitivtyLog is IActivityLog, Initializable, AccessControlEnumerableUpgradeable {

    bytes32 public constant ACTIVITY_LOGGER_ROLE = keccak256("ACTIVITY_LOGGER_ROLE");

    uint256 public constant ACTIVITY_INTERVAL = 28 days;
    uint256 public intervalZeroStart;

    mapping(address => mapping(uint256 => uint16)) internal userToIntervalToActivity;

    function __CCIPReceiverUpgradeable_init(uint256 _intervalZeroTimestamp) internal onlyInitializing {
        intervalZeroStart = _intervalZeroTimestamp;
    }

    function currentInterval() public view returns (uint256) {
        return (block.timestamp - intervalZeroStart) / ACTIVITY_INTERVAL;
    }

    /**
     * Log an activity of the specified address during the current interval.
     */
    function logActivity(address user) external virtual onlyRole(ACTIVITY_LOGGER_ROLE) {
        uint256 interval = currentInterval();
        uint16 activityCounter = userToIntervalToActivity[user][interval] + 1;
        userToIntervalToActivity[user][interval] = activityCounter;
        emit ActivityLogged(msg.sender, user, interval, activityCounter);
    }

    /**
     * Get the number of active intervals of the specified address since the specified
     * timespan, as well the total number of all activies performed by this address since
     * the specified timestamp.
     */
    function activitySince(address user, uint256 startTimestamp) 
        public view virtual returns (uint256 activeIntervals, uint256 totalActivities) {

        (activeIntervals, totalActivities) = activityFromTo(user, startTimestamp, block.timestamp); 
    }

    /**
     * Get the number of active intervals of the speicified address in the specified timespan,
     * as well as the total number of all activies performed by this address during the timespan.
     */
    function activityFromTo(address user, uint256 startTimestamp, uint256 endTimestamp) 
        public view virtual returns (uint256 activeIntervals, uint256 totalActivities) {

        if (startTimestamp < intervalZeroStart) {
            revert TimestampBeforeIntervalZero();
        }
        uint256 startInterval = (startTimestamp - intervalZeroStart) / ACTIVITY_INTERVAL;
        uint256 endInterval = (endTimestamp - intervalZeroStart) / ACTIVITY_INTERVAL;

        activeIntervals = 0;
        totalActivities = 0;
        uint16 tmpIntervalActivities = 0;

        for(uint256 i = startInterval; i <= endInterval; i++) {
            tmpIntervalActivities = userToIntervalToActivity[user][i];
            if (tmpIntervalActivities > 0) {
                activeIntervals += 1;
                totalActivities += tmpIntervalActivities;
            }
        }
    }

}