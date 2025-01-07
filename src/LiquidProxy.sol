// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "./interfaces/IRoninValidators.sol";
import "./interfaces/ILiquidProxy.sol";
import "./RonHelper.sol";

contract LiquidProxy is RonHelper, ILiquidProxy {
	address public vault;
	address public roninStaking;

	constructor(address _roninStaking, address _wron)
	RonHelper(_wron) {
		vault = msg.sender;
		roninStaking = _roninStaking;
	}

	modifier onlyVault() {
		require(msg.sender == vault, "LiquidProxy: not vault");
		_;
	}

	function harvest(address[] calldata _consensusAddrs) external onlyVault returns(uint256) {
		for (uint256 i = 0; i < _consensusAddrs.length; i++) {
			IRoninValidator(roninStaking).claimRewards(_consensusAddrs);
		}
		uint256 claimedAmount = address(this).balance;
		_depositRONTo(vault, claimedAmount);
		return claimedAmount;
	}

	function harvestAndDelegateRewards(address[] calldata _consensusAddrs, address _consensusAddrDst) external onlyVault returns(uint256) {
		uint256 claimableAmount = IRoninValidator(roninStaking).delegateRewards(_consensusAddrs, _consensusAddrDst);
		return claimableAmount;
	}

	function delegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external onlyVault {
		for (uint256 i = 0; i < _amounts.length; i++) {
			IRoninValidator(roninStaking).delegate{value: _amounts[i]}(_consensusAddrs[i]);
		}
	}

	function redelegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrsSrc, address[] calldata _consensusAddrsDst) external onlyVault {
		for (uint256 i = 0; i < _amounts.length; i++) {
			IRoninValidator(roninStaking).redelegate(_consensusAddrsSrc[i], _consensusAddrsDst[i], _amounts[i]);
		}
	}

	function undelegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external onlyVault {
		uint256 totalUndelegated;
		for (uint256 i = 0; i < _amounts.length; i++) {
			totalUndelegated += _amounts[i];
		}
		IRoninValidator(roninStaking).bulkUndelegate(_consensusAddrs, _amounts);
		_depositRONTo(vault, totalUndelegated);
	}

	/**
	 * @notice
	 * Receive function remains open as method to calculate total ron in contract does not use contract balance.
	 */
	receive() external payable {}
}