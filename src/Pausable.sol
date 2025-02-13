// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

import "@openzeppelin/access/Ownable.sol";

abstract contract Pausable is Ownable {
    error ErrPaused();
    bool public paused;

    modifier whenNotPaused() {
        _checkIfPaused();
        _;
    }

    function _checkIfPaused() internal view {
        if (paused) revert ErrPaused();
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
