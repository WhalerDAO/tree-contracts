// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";


contract UniswapOracleManipulator {
  using SafeMath for uint256;
  bool public updated;

  uint256 public price;

  constructor() public {
    updated = true;
    // from `price1CumulativeLast` in https://etherscan.io/address/0xcf70a458b86607ed65f03409f84bcb869e62538d#readContract
    // price = 12 * 10**18;  // $1.20
    price = 108 * 10**16;  // $1.08
  }

  function setPrice(uint256 _price) public {
    price = _price;
  }

  function update() external pure returns (bool success) {
    return true;
  }

  // token1 = TREE
  function consult(address token, uint256 amountIn)
    external
    view
    returns (uint256 amountOut)
  {
    // amountOut = price.mul(amountIn);
    amountOut = price;
  }

}
