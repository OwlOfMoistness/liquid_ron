// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface IProfile {
	function getId2Consensus(address id) external view returns (address);
	function getManyId2Consensus(address[] calldata idList) external view returns (address[] memory consensusList);

	function getConsensus2Id(address consensus) external view returns (address);
	function getManyConsensus2Id(address[] calldata consensusList) external view returns (address[] memory idList);
}
