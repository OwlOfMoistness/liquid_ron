// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/*
 *     ,_,
 *    (',')
 *    {/"\}
 *    -"-"-
 */

interface IUniPoolV3 {
  function slot0()
    external
    view
    returns (
      uint160 sqrtPriceX96,
      int24 tick,
      uint16 observationIndex,
      uint16 observationCardinality,
      uint16 observationCardinalityNext,
      uint8 feeProtocolNum,
      uint8 feeProtocolDen,
      bool unlocked
    );
	function tickSpacing() external view returns (int24);
	function maxLiquidityPerTick() external view returns (uint128);
	function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
	function token0() external view returns (address);
	function token1() external view returns (address);
  function fee() external view returns (uint24);
}

interface IUniPoolV3Factory {
  function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);
}