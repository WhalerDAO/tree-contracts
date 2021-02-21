// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.0;

contract UniswapOracleManipulator {

    // TODO: minimum to trigger rebalance?
  uint256 public price = 108 * 10**16;  // $1.08

  constructor() public {}

  function update() external pure returns (bool success) {
    return true;
  }

  function consult(address token, uint256 amountIn)
    external
    view
    returns (uint256 amountOut)
  {
    amountOut = price;
  }

}
