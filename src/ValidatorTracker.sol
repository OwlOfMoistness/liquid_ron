// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

/// @title ValidatorTracker contract used to store validators
/// @dev This allows us to not call the current set of validators and have renounced validators being removed from the list
///      We can prunce validators once we have removed all staked and claimed RON from them
/// @author OwlOfMoistness
abstract contract ValidatorTracker {
    address[] public validators;

    mapping(address => bool) public validatorStakeActive;
    mapping(address => uint256) public validatorStakeCount;
    mapping(address => uint256) public validatorIndex;
    uint256 public validatorCount;

    /// @dev Get the list of validators
    /// @return validators The list of validators
    function getValidators() external view returns (address[] memory) {
        return validators;
    }

    /// @dev Get the list of validators, internal function
    /// @return validators The list of validators
    function _getValidators() internal view returns (address[] memory) {
        return validators;
    }

    /// @dev Push a new validator in the list if it is not already in the list
    /// @param _validator The validator to push
    function _tryPushValidator(address _validator) internal {
        if (!validatorStakeActive[_validator]) {
            validatorStakeActive[_validator] = true;
            validatorIndex[_validator] = validatorCount++;
            validators.push(_validator);
        }
    }

    /// @dev Remove a validator from the list if it is in the list
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
