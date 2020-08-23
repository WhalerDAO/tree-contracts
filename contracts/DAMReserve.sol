// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./DAM.sol";
import "./DAMRebaser.sol";
import "./DAMGov.sol";
import "./interfaces/IDAMRewards.sol";

contract DAMReserve {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  /**
    Modifiers
   */

  modifier onlyRebaser {
    require(msg.sender == address(rebaser), "DAMReserve: not rebaser");
    _;
  }

  /**
    Events
   */
  event SellDAM(uint256 amount);

  /**
    Public constants
   */
  /**
    @notice precision for decimal calculations
   */
  uint256 public constant PRECISION = 10**18;
  /**
    @notice the peg for DAM price, in reserve tokens
   */
  uint256 public constant PEG = 10**18; // 1 DAM = 1 reserveToken

  /**
    System parameters
   */
  /**
    @notice the proportion of rebase income given to DAMGov
   */
  uint256 public immutable govCut;
  /**
    @notice the proportion of rebase income given to DAMRewards
   */
  uint256 public immutable rewardsCut;

  /**
    External contracts
   */
  DAM public immutable dam;
  DAMGov public immutable gov;
  ERC20 public immutable reserveToken;
  DAMRebaser public rebaser;
  IDAMRewards public rewards;

  constructor(
    uint256 _govCut,
    uint256 _rewardsCut,
    address _dam,
    address _gov,
    address _reserveToken
  ) public {
    govCut = _govCut;
    rewardsCut = _rewardsCut;

    dam = DAM(_dam);
    gov = DAMGov(_gov);
    reserveToken = ERC20(_reserveToken);
  }

  function initContracts(address _rebaser, address _rewards) external {
    require(_rebaser != address(0), "DAM: invalid rebaser");
    require(address(rebaser) == address(0), "DAM: rebaser already set");
    require(_rewards != address(0), "DAM: invalid rewards");
    require(address(rewards) == address(0), "DAM: rewards already set");
    rebaser = DAMRebaser(_rebaser);
    rewards = IDAMRewards(_rewards);
  }

  /**
    @notice distribute minted DAM to DAMRewards and DAMGov, and sell the rest
    @param amount the amount of DAM minted
   */
  function handlePositiveRebase(uint256 amount) external onlyRebaser {
    // send DAM to DAMRewards
    uint256 rewardsCutAmount = amount.mul(rewardsCut).div(PRECISION);
    dam.transfer(address(rewards), rewardsCutAmount);
    rewards.notifyRewardAmount(rewardsCutAmount);

    // send DAM to DAMGov
    uint256 govCutAmount = amount.mul(govCut).div(PRECISION);
    dam.transfer(address(gov), govCutAmount);

    // sell remaining DAM for reserveToken
    uint256 remainingAmount = amount.sub(rewardsCutAmount).sub(govCutAmount);
    _sellDAM(remainingAmount);
  }

  /**
    Utilities
   */
  /**
    @notice create a sell order for DAM
    @param amount the amount of DAM to sell
   */
  function _sellDAM(uint256 amount) internal {
    emit SellDAM(amount);
  }
}
