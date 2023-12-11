// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IActivityLog {

    event ActivityLogged(address indexed reporter, address indexed user, uint256 indexed interval, uint16 totalUserActivitiesInInterval);
    error TimestampBeforeIntervalZero(); 

    function currentInterval() external view returns (uint256);
    function logActivity(address user) external;
    function activitySince(address user, uint256 startTimestamp) external view returns (uint256 activeIntervals, uint256 totalActivities);
    function activityFromTo(address user, uint256 startTimestamp, uint256 endTimestamp) external view returns (uint256 activeIntervals, uint256 totalActivities); 

}