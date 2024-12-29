// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "../interfaces/IRoninValidators.sol";

contract ValidatorSet is IValidatorSet {

	mapping(uint256 => address) public validators;
	mapping(address => ValidatorCandidate) public validatorCandidates;
	uint256 public validatorCount;

	function addValidator(address _validator) external {
		validatorCandidates[_validator].__shadowedConsensus = _validator;
		validators[validatorCount] = _validator;
		validatorCount++;
	}

	function getCandidateInfos() external view override returns (ValidatorCandidate[] memory list) {
		list = new ValidatorCandidate[](validatorCount);
		for (uint256 i = 0; i < validatorCount; i++) {
			list[i] = validatorCandidates[validators[i]];
		}
	}
}