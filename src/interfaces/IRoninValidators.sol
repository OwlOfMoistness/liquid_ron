// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface IRoninValidator {
    function delegate(address) external payable;
    function undelegate(address consensusAddr, uint256 amount) external;
    function redelegate(address consensusAddrSrc, address consensusAddrDst, uint256 amount) external;
    function bulkUndelegate(address[] calldata, uint256[] calldata) external;
    function claimRewards(address[] calldata) external;
    function delegateRewards(address[] calldata, address consensusAddrDst) external returns (uint256 amount);
    function getRewards(address user, address[] calldata) external view returns (uint256[] memory);
    function getReward(address user, address) external view returns (uint256);
    function getStakingTotal(address consensusAddr) external view returns (uint256);
    function getManyStakingTotals(address[] calldata consensusAddrs) external view returns (uint256[] memory);
    function getStakingAmount(address consensusAddr, address user) external view returns (uint256);
    function getManyStakingAmounts(
        address[] calldata consensusAddrs,
        address[] calldata userList
    ) external view returns (uint256[] memory);
}
