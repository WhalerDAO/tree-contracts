// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

contract UniswapOracle {

  bool public updated;

  uint256 public price;

  constructor() public {
    updated = true;
    price = 11 * 10**17;  // 1,1
  }

  function setPrice(uint256 _price) public {
    price = _price;
  }

  function update() external pure returns (bool success) {
    return true;
  }

  // note this will always return 0 before update has been called successfully for the first time.
  function consult(address token, uint256 amountIn)
    external
    view
    returns (uint256 amountOut)
  {
    amountOut = price;
  }

}
