// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import {IRoninValidator} from "./interfaces/IRoninValidators.sol";
import {ILiquidProxy} from "./interfaces/ILiquidProxy.sol";
import {RonHelper} from "./RonHelper.sol";

/// @title A proxy contract deployed by the LiquidRon vault.
/// 	   It allows to granulate staking amounts to reduce reward waste by movings assets around
/// @author OwlOfMoistness
contract LiquidProxy is RonHelper, ILiquidProxy {
    error ErrNotVault();

    address public vault;
    address public roninStaking;

    constructor(address _roninStaking, address _wron, address _vault) RonHelper(_wron) {
        vault = _vault;
        roninStaking = _roninStaking;
    }

    /// @dev Only the LRON vault can call any function
    modifier onlyVault() {
        if (msg.sender != vault) revert ErrNotVault();
        _;
    }

    /// @dev Harvest rewards from the Ronin staking contract and deposit them to the vault
    /// @param _consensusAddrs The consensus addresses to harvest rewards from
    /// @return claimedAmount The amount of RON claimed from the staking contract
    function harvest(address[] calldata _consensusAddrs) external onlyVault returns (uint256) {
        for (uint256 i = 0; i < _consensusAddrs.length; i++) {
            IRoninValidator(roninStaking).claimRewards(_consensusAddrs);
        }
        uint256 claimedAmount = address(this).balance;
        _depositRONTo(vault, claimedAmount);
        return claimedAmount;
    }

    /// @dev Harvest rewards from the Ronin staking contract and delegate them to another validator
    /// @param _consensusAddrs The consensus addresses to harvest rewards from
    /// @param _consensusAddrDst The consensus address to delegate the rewards to
    /// @return claimableAmount The amount of RON claimed from the staking contract
    function harvestAndDelegateRewards(
        address[] calldata _consensusAddrs,
        address _consensusAddrDst
    ) external onlyVault returns (uint256) {
        uint256 claimableAmount = IRoninValidator(roninStaking).delegateRewards(_consensusAddrs, _consensusAddrDst);
        return claimableAmount;
    }

    /// @dev Delegate a specific amount of RON to a validator
    /// @param _amounts The amounts to delegate
    /// @param _consensusAddrs The consensus addresses to delegate to
    function delegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external onlyVault {
        for (uint256 i = 0; i < _amounts.length; i++) {
            IRoninValidator(roninStaking).delegate{value: _amounts[i]}(_consensusAddrs[i]);
        }
    }

    /// @dev Redelegate a specific amount of RON from one validator to another
    /// @param _amounts The amounts to redelegate
    /// @param _consensusAddrsSrc The consensus addresses to redelegate from
    /// @param _consensusAddrsDst The consensus addresses to redelegate to
    function redelegateAmount(
        uint256[] calldata _amounts,
        address[] calldata _consensusAddrsSrc,
        address[] calldata _consensusAddrsDst
    ) external onlyVault {
        for (uint256 i = 0; i < _amounts.length; i++) {
            IRoninValidator(roninStaking).redelegate(_consensusAddrsSrc[i], _consensusAddrsDst[i], _amounts[i]);
        }
    }

    /// @dev Undelegate a specific amount of RON from a validator
    /// @param _amounts The amounts to undelegate
    /// @param _consensusAddrs The consensus addresses to undelegate from
    function undelegateAmount(uint256[] calldata _amounts, address[] calldata _consensusAddrs) external onlyVault {
        uint256 totalUndelegated;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalUndelegated += _amounts[i];
        }
        IRoninValidator(roninStaking).bulkUndelegate(_consensusAddrs, _amounts);
        _depositRONTo(vault, totalUndelegated);
    }

    /// @dev Receive function remains open as method to calculate total ron in contract does not use contract balance.
    receive() external payable {}
}
