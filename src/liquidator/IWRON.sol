// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface Iwron {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address, uint256) external;
}