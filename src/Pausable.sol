// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "@openzeppelinups/access/OwnableUpgradeable.sol";

abstract contract Pausable is OwnableUpgradeable {
	error ErrPaused();
	bool public paused;

	modifier whenNotPaused() {
		if (paused) revert ErrPaused();
		_;
	}

	function pause() external onlyOwner {
		paused = true;
	}

	function unpause() external onlyOwner {
		paused = false;
	}
}