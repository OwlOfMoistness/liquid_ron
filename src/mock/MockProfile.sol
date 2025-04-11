// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import {IProfile} from "../interfaces/IProfile.sol";

contract MockProfile is IProfile {
	mapping(address => address) public id2Consensus;
	mapping(address => address) public consensus2Id;

	function register(address id, address consensus) public {
		require(id2Consensus[id] == address(0), "Profile: already registered");
		require(consensus2Id[consensus] == address(0), "Profile: already registered");
		id2Consensus[id] = consensus;
		consensus2Id[consensus] = id;
	}

	function updateConsensus(address id, address consensus) public {
		require(id2Consensus[id] != address(0), "Profile: not registered");
		address oldConsensus = id2Consensus[id];
		require(oldConsensus != consensus, "Profile: same consensus");
		id2Consensus[id] = consensus;
		consensus2Id[consensus] = id;
		delete consensus2Id[oldConsensus];
	}

	function registerMany(address[] calldata idList, address[] calldata consensusList) public {
		for (uint256 i = 0; i < idList.length; i++) {
			register(idList[i], consensusList[i]);
		}
	}

	function getId2Consensus(address id) external view override returns (address) {
		address consensus = id2Consensus[id];
		if (consensus == address(0)) {
			revert("Profile: not registered");
		}
		return consensus;
	}

	function getManyId2Consensus(address[] calldata idList) external view override returns (address[] memory consensusList) {
		consensusList = new address[](idList.length);
		for (uint256 i = 0; i < idList.length; i++) {
			address consensus = id2Consensus[idList[i]];
			if (consensus == address(0)) {
				revert("Profile: not registered");
			}
			consensusList[i] = consensus;
		}
	}

	function getConsensus2Id(address consensus) external view override returns (address) {
		if (consensus2Id[consensus] == address(0)) {
			revert("Profile: not registered");
		}
		return consensus2Id[consensus];
	}

	function getManyConsensus2Id(address[] calldata consensusList) external view override returns (address[] memory idList) {
		idList = new address[](consensusList.length);
		for (uint256 i = 0; i < consensusList.length; i++) {
			if (consensus2Id[consensusList[i]] == address(0)) {
				revert("Profile: not registered");
			}
			idList[i] = consensus2Id[consensusList[i]];
		}
	}
}