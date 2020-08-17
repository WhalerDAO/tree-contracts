// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract DAM is ERC20("DAM", "DAM"), ERC20Burnable {
  /**
    @notice the DAMRebaser contract, can't be changed
   */
  address public rebaser;

  function initRebaser(address _rebaser) external {
    require(_rebaser != address(0), "DAM: invalid rebaser");
    require(rebaser == address(0), "DAM: rebaser already set");
    rebaser = _rebaser;
  }

  function mint(address account, uint256 amount) external {
    require(msg.sender == rebaser);
    _mint(account, amount);
  }
}
