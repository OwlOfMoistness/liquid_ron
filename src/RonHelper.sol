// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface IWRON {
	function deposit() external payable;
	function withdraw(uint256) external;
	function transfer(address, uint256) external;
}

abstract contract RonHelper {
	address wron;

	constructor(address _wron) {
		wron = _wron;
	}

	function _depositRONTo(address to, uint256 amount) internal {
		IWRON(wron).deposit{value: amount}();
		IWRON(wron).transfer(to, amount);
	}

	function _withdrawRONTo(address to, uint256 amount) internal {
		IWRON(wron).withdraw(amount);
		(bool success, ) = to.call{value: amount}("");
		require(success, "RonHelper: withdraw failed");
	}
}