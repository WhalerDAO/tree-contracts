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
  event BuyDAM(uint256 amount);
  event SellDAM(uint256 amount);
  event IssueDAMBonds(uint256 amount);
  event SetGovCut(uint256 newValue, uint256 oldValue);
  event SetRewardsCut(uint256 newValue, uint256 oldValue);

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
  IDAMRewards public rewards;
  ERC20 public reserveToken;

  constructor(
    address _dam,
    address _gov,
    address _reserveToken
  ) public {
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
    @notice buy up DAM and burn them, and issue bonds to buy & burn DAM when reserve is inadequate
    @param amount the amount of DAM that should be burnt
   */
  function handleNegativeRebase(uint256 amount) external onlyRebaser {
    // issue bonds if reserve is inadequate
    uint256 affordableBuyDAMAmount = reserveToken
      .balanceOf(address(this))
      .mul(PRECISION)
      .div(PEG);
    uint256 buyDAMAmount = amount;
    if (buyDAMAmount > affordableBuyDAMAmount) {
      // use entire reserve balance to buy DAM
      buyDAMAmount = affordableBuyDAMAmount;

      // issue bonds to buy remainder
      uint256 issueBondsAmountInDAM = amount.sub(buyDAMAmount);
      _issueDAMBonds(issueBondsAmountInDAM);
    }

    // buy DAM using reserveToken
    _buyDAM(buyDAMAmount);

    // burn bought DAM
    dam.burn(buyDAMAmount);
  }

  /**
    Utilities
   */
  /**
    @notice create a buy order for DAM
    @param amount the amount of DAM to buy
   */
  function _buyDAM(uint256 amount) internal {
    emit BuyDAM(amount);
  }

  /**
    @notice create a sell order for DAM
    @param amount the amount of DAM to sell
   */
  function _sellDAM(uint256 amount) internal {
    emit SellDAM(amount);
  }

  /**
    @notice issue DAMBond tokens to buy DAM
    @param amount the amount of DAM to buy
   */
  function _issueDAMBonds(uint256 amount) internal {
    emit IssueDAMBonds(amount);
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
