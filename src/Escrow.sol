// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "@openzeppelin/token/ERC20/IERC20.sol";
import "./LiquidRon.sol";

contract Escrow {
	constructor(address _token) {
		IERC20(_token).approve(msg.sender, type(uint256).max);
	}

	function deposit(uint256 _amount, address _receiver) external {
		LiquidRon(payable(msg.sender)).deposit( _amount, _receiver);
	}
}