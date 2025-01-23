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
        if (paused) revert ErrPaused();
        _;
    }

    function pause() external onlyOwner {
        paused = true;
    }

    function unpause() external onlyOwner {
        paused = false;
    }
}
