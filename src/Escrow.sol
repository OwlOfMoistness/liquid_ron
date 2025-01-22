// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "@openzeppelin/token/ERC20/IERC20.sol";

interface IVault {
    function deposit(uint256 _amount, address _receiver) external payable;
}

/// @title Escrow contract used to store RON tokens from the vault to prevent total assets miscalculations
/// @author OwlOfMoistness
contract Escrow {
    error ErrNotVault();

    address _vault;

    constructor(address _token) {
        _vault = msg.sender;
        IERC20(_token).approve(msg.sender, type(uint256).max);
    }

    /// @dev Deposit WRON tokens to the vault.
    ///      The reason we do it here is to prevent total assets miscalculations
    ///      in the vault and send the wrong amount of shares to the receiver. 
    /// @param _amount The amount of RON to deposit
    /// @param _receiver The receiver of the RON tokens
    function deposit(uint256 _amount, address _receiver) external {
        if (msg.sender != _vault) revert ErrNotVault();
        IVault(payable(_vault)).deposit(_amount, _receiver);
    }
}
