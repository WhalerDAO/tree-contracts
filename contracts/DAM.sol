// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract DAM is ERC20("DAM", "DAM"), ERC20Burnable {
  /**
    @notice the DAMRebaser contract
   */
  address public immutable rebaser;

  constructor(address _rebaser) public {
    rebaser = _rebaser;
  }

  function mint(address account, uint256 amount) external {
    require(msg.sender == rebaser);
    _mint(account, amount);
  }
}
