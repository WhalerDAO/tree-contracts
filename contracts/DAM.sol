// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

contract DAM is ERC20("DAM", "DAM"), ERC20Burnable {
  /**
    @notice the DAMRebaser contract
   */
  address public rebaser;
  /**
    @notice the DAMReserve contract
   */
  address public reserve;

  function initContracts(address _rebaser, address _reserve) external {
    require(_rebaser != address(0), "DAM: invalid rebaser");
    require(rebaser == address(0), "DAM: rebaser already set");
    rebaser = _rebaser;
    require(_reserve != address(0), "DAM: invalid reserve");
    require(reserve == address(0), "DAM: reserve already set");
    reserve = _reserve;
  }

  function rebaserMint(address account, uint256 amount) external {
    require(msg.sender == rebaser);
    _mint(account, amount);
  }

  function reserveBurn(address account, uint256 amount) external {
    require(msg.sender == reserve);
    _burn(account, amount);
  }
}
