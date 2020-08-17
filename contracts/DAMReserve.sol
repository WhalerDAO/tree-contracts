// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "./DAM.sol";
import "./DAMRebaser.sol";
import "./DAMGov.sol";
import "./DAMRewards.sol";

contract DAMReserve {
  /**
    Modifiers
   */
  modifier onlyGov {
    require(msg.sender == address(gov), "DAMReserve: not gov");
    _;
  }

  modifier onlyRebaser {
    require(msg.sender == address(rebaser), "DAMReserve: not rebaser");
    _;
  }

  /**
    Events
   */
  event SetGovCut(uint256 newValue, uint256 oldValue);
  event SetRewardsCut(uint256 newValue, uint256 oldValue);

  /**
    Public constants
   */
  /**
    @notice the minimum value for govCut
   */
  uint256 public constant MIN_GOV_CUT = 1 * 10**16; // 1%
  /**
    @notice the maximum value for govCut
   */
  uint256 public constant MAX_GOV_CUT = 20 * 10**16; // 20%
  /**
    @notice the minimum value for rewardsCut
   */
  uint256 public constant MIN_REWARDS_CUT = 1 * 10**16; // 1%
  /**
    @notice the maximum value for rewardsCut
   */
  uint256 public constant MAX_REWARDS_CUT = 20 * 10**16; // 20%

  /**
    System parameters
   */
  /**
    @notice the proportion of rebase income given to DAMGov
   */
  uint256 public govCut;
  /**
    @notice the proportion of rebase income given to DAMRewards
   */
  uint256 public rewardsCut;

  /**
    External contracts
   */
  DAM public dam;
  DAMRebaser public rebaser;
  DAMGov public gov;
  DAMRewards public rewards;

  constructor(address _dam, address _gov) public {
    dam = DAM(_dam);
    gov = DAMGov(_gov);
  }

  function initContracts(address _rebaser, address _rewards) external {
    require(_rebaser != address(0), "DAM: invalid rebaser");
    require(address(rebaser) == address(0), "DAM: rebaser already set");
    require(_rewards != address(0), "DAM: invalid rewards");
    require(address(rewards) == address(0), "DAM: rewards already set");
    rebaser = DAMRebaser(_rebaser);
    rewards = DAMRewards(_rewards);
  }

  function receiveMintedDAM(uint256 amount) external onlyRebaser {
    // sell received DAM on Uniswap
    // send funds to DAMGov
    // send funds to DAMRewards
  }

  function buyAndBurnDAM(uint256 amount) external onlyRebaser {
    // buy DAM on Uniswap
    // issue bonds if reserve is inadequate
    // burn bought DAM
  }

  /**
    Parameter setters
   */
  function setGovCut(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_GOV_CUT && newValue <= MAX_GOV_CUT,
      "DAMReserve: invalid value"
    );
    emit SetGovCut(newValue, govCut);
    govCut = newValue;
  }

  function setRewardsCut(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_REWARDS_CUT && newValue <= MAX_REWARDS_CUT,
      "DAMReserve: invalid value"
    );
    emit SetRewardsCut(newValue, rewardsCut);
    rewardsCut = newValue;
  }
}
