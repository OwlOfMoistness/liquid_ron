// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "../interfaces/ITimingInfo.sol";

contract MockValidatorSet {

	uint256 constant DURATIOM = 1 days;

	function currentPeriod() external view returns (uint256) {
		return block.timestamp / DURATIOM;
	}
}