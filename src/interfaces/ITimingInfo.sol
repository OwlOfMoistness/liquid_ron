// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface ITimingInfo {
  /**
   * @dev Returns the block that validator set was updated.
   */
  function getLastUpdatedBlock() external view returns (uint256);

  /**
   * @dev Returns the number of blocks in a epoch.
   */
  function numberOfBlocksInEpoch() external view returns (uint256 _numberOfBlocks);

  /**
   * @dev Returns the block number that `period` ending at.
   *
   * Throws error if the period has not ended yet.
   * Throws error if the period ending block does not exist.
   *
   * @param period The period index.
   */
  function getPeriodEndBlock(uint256 period) external view returns (uint256 blockNumber);

  /**
   * @dev Returns whether the period ending at the current block number.
   */
  function isPeriodEnding() external view returns (bool);

  /**
   * @dev Returns the period index from the current block.
   */
  function currentPeriod() external view returns (uint256);

  /**
   * @dev Returns the block number that the current period starts at.
   */
  function currentPeriodStartAtBlock() external view returns (uint256);
}