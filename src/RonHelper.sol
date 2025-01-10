// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import {Initializable} from "@openzeppelinups/proxy/utils/Initializable.sol";

interface IWRON {
	function deposit() external payable;
	function withdraw(uint256) external;
	function transfer(address, uint256) external;
}

/// @title RonHelper contract used to help with WRON token transfer operations
/// @author OwlOfMoistness
abstract contract RonHelper is Initializable {
	address wron;

	function __RonHelper_init(address _wron) internal initializer {
		wron = _wron;
	}

	/// @dev Deposit RON tokens into WRON to the recipient
	/// @param to The recipient of the WRON tokens
	/// @param amount The amount of RON to deposit
	function _depositRONTo(address to, uint256 amount) internal {
		IWRON(wron).deposit{value: amount}();
		IWRON(wron).transfer(to, amount);
	}

	/// @dev Withdraw RON tokens to the recipient
	/// @param to The recipient of the RON tokens
	/// @param amount The amount of WRON to withdraw
	function _withdrawRONTo(address to, uint256 amount) internal {
		IWRON(wron).withdraw(amount);
		(bool success, ) = to.call{value: amount}("");
		require(success, "RonHelper: withdraw failed");
	}
}