// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import {ITimingInfo} from "./interfaces/ITimingInfo.sol";

/// @title RewardTracker contract used to track rewards, current lowest balance of all staked assets and APR
/// @dev This contract allows us to give a decent approximation of future daily rewards to calculate correct depositing fees for users
/// @author OwlOfMoistness
abstract contract RewardTracker {
	uint256 immutable public periodStartOfVault;

	address internal validatorSet;
	mapping(uint256 => uint256) public stakedBalance;
	mapping(uint256 => uint256) public rewardsClaimed;
	mapping(uint256 => uint256) public indexTracker;
	mapping(uint256 => uint256) public loggedFees;
	uint256 public currentLoggedPeriod;
	uint256 public latestValidLoggedPeriod;
	bool public depositFeeEnabled;

	constructor(address _validatorSet) {
		validatorSet = _validatorSet;
		periodStartOfVault = ITimingInfo(validatorSet).currentPeriod();
	}

	/// @dev Internal functino used to update the logged period in the contract
	///      It also logs the total staked balance for the period
	/// @param _period The period to sync to
	function _syncTracker(uint256 _period) internal {
		if (_period == 0)
			_period = ITimingInfo(validatorSet).currentPeriod();
		if (_period != currentLoggedPeriod) {
			currentLoggedPeriod = _period;
			if (stakedBalance[_period] == 0)
				stakedBalance[_period] = getTotalStaked();
		}
	}

	/// @dev Internal function used to increase the staked balance for the current period	
	///      Balance can only decrease as we make sure to log the balance before ever decreasing
	/// @param _amount The amount to increase the staked balance with
	function _decreaseStakedBalance(uint256 _amount) internal {
		uint256 period = ITimingInfo(validatorSet).currentPeriod();
		stakedBalance[period] -= _amount;
	}

	/// @dev Internal function used log rewards of each proxy.
	///      Once all proxies have logged their rewards, the period is marked as valid
	///      Allowing it to be used for fee calculations
	/// @param _index The index of the proxy
	/// @param _amount The amount of rewards to log
	function _logReward(uint256 _index, uint256 _amount) internal {
		uint256 period = ITimingInfo(validatorSet).currentPeriod();
		_syncTracker(period);
		rewardsClaimed[period] += _amount;
		indexTracker[period] |= 1 << _index;
		if (indexTracker[period] == 2 ** _getProxyCount() - 1 && stakedBalance[period - 1] != 0)
			latestValidLoggedPeriod = period;
	}

	/// @dev Internal function used to log fees for the current period
	///      Once the logged fees exceed the expected rewards,
	///      the fees are not logged anymore and the fees are not charged until next period
	/// @param _amount The amount of fees to log
	function _logFee(uint256 _amount) internal {
		if (_amount == 0) return;
		uint256 period = ITimingInfo(validatorSet).currentPeriod();
		_syncTracker(period);
		loggedFees[period] += _amount;
	}

	/// @dev Internal function used to calculate the deposit fee for a user
	///      The fee is calculated based on the expected rewards for the current period and the staked balance of the previous period
	/// @param _amount The amount to calculate the fee for
	function _getDepositFee(uint256 _amount) internal view returns (uint256) {
		uint256 period = ITimingInfo(validatorSet).currentPeriod();
		uint256 validPeriod = latestValidLoggedPeriod;
		if (validPeriod == 0) return 0;
		uint256 previoudStakedBalance = stakedBalance[validPeriod - 1];
		if(previoudStakedBalance == 0) return 0;

		uint256 expectedRewards = rewardsClaimed[validPeriod] * stakedBalance[validPeriod] / previoudStakedBalance;
		if (loggedFees[period] >= expectedRewards) return 0;
		uint256 fee =  expectedRewards * _amount / (previoudStakedBalance + _amount);
		return fee;
	}

	/// @dev External function to get the expected fee given an amount
	/// @param _amount The amount to calculate the fee from
	function getDepositFee(uint256 _amount) external view returns (uint256) {
		return _getDepositFee(_amount);
	}

	function getTotalStaked() public virtual view returns (uint256);
	function _getProxyCount() internal virtual view returns (uint256);
}