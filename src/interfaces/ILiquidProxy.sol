// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface ILiquidProxy {
    function harvest(address[] calldata _consensusAddrs) external returns (uint256);
    function harvestAndDelegateRewards(
        address[] calldata _consensusAddrs,
        address _consensusAddrDst
    ) external returns (uint256);
    function delegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external;
    function redelegateAmount(
        uint256[] calldata _amounts,
        address[] calldata _consensusAddrsSrc,
        address[] calldata _consensusAddrsDst
    ) external;
    function undelegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external;
}
