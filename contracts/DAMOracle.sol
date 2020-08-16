// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

interface DAMOracle {
  function update() external returns (bool success);

  function consult(address token, uint256 amountIn)
    external
    view
    returns (uint256 amountOut);
}
