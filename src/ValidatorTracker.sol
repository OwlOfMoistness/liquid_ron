// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */


abstract contract ValidatorTracker {

	address[] public validators;

	mapping(address => bool) public validatorStakeActive;
	mapping(address => uint256) public validatorStakeCount;
	mapping(address => uint256) public validatorIndex;
	uint256 public validatorCount;

	function getValidators() external view returns (address[] memory) {
		return validators;
	}

	function _getValidators() internal view returns (address[] memory) {
		return validators;
	}

	function _tryPushValidator(address _validator) internal {
		if (!validatorStakeActive[_validator]) {
			validatorStakeActive[_validator] = true;
			validatorIndex[_validator] = validatorCount++;
			validators.push(_validator);
		}
	}

	function _removeValidator(address _validator) internal {
		if (validatorStakeActive[_validator]) {
			uint256 index = validatorIndex[_validator];
			address lastValidator = validators[--validatorCount];
			validatorStakeActive[_validator] = false;
			validators[index] = lastValidator;
			validatorIndex[lastValidator] = index;
			validators.pop();
		}
	}
}