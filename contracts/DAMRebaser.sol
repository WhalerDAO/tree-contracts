// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./DAM.sol";
import "./DAMOracle.sol";
import "./DAMReserve.sol";

contract DAMRebaser {
  using SafeMath for uint256;

  /**
    Modifiers
   */
  modifier onlyGov {
    require(msg.sender == gov, "DAMRebaser: not gov");
    _;
  }

  /**
    Events
   */
  event Rebase(uint256 damSupplyChange);
  event SetMinimumRebaseInterval(uint256 newValue, uint256 oldValue);
  event SetDeviationThreshold(uint256 newValue, uint256 oldValue);
  event SetRebaseMultiplier(uint256 newValue, uint256 oldValue);
  event SetOracle(address newValue, address oldValue);
  event SetGov(address newValue, address oldValue);

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
  uint256 public constant PEG = 10**18; // 1 DAM = 1 reserveTOken
  /**
    @notice the precision of DAM decimals
   */
  uint256 public constant DAM_PRECISION = 10**18;
  /**
    @notice the minimum value for minimumRebaseInterval
   */
  uint256 public constant MIN_MINIMUM_REBASE_INTERVAL = 24 hours;
  /**
    @notice the maximum value for minimumRebaseInterval
   */
  uint256 public constant MAX_MINIMUM_REBASE_INTERVAL = 30 days;
  /**
    @notice the minimum value for deviationThreshold
   */
  uint256 public constant MIN_DEVIATION_THRESHOLD = 1 * 10**16; // 1%
  /**
    @notice the maximum value for deviationThreshold
   */
  uint256 public constant MAX_DEVIATION_THRESHOLD = 10 * 10**16; // 10%
  /**
    @notice the minimum value for rebaseMultiplier
   */
  uint256 public constant MIN_REBASE_MINT_MULTIPLIER = 1 * 10**17; // 0.1x
  /**
    @notice the maximum value for rebaseMultiplier
   */
  uint256 public constant MAX_REBASE_MINT_MULTIPLIER = 10 * 10**18; // 10x

  /**
    System parameters
   */
  /**
    @notice the minimum interval between rebases, in seconds
   */
  uint256 public minimumRebaseInterval;
  /**
    @notice the threshold for the off peg percentage of DAM price above which rebase will occur
   */
  uint256 public deviationThreshold;
  /**
    @notice the multiplier for calculating how much DAM to mint during a rebase
   */
  uint256 public rebaseMultiplier;

  /**
    Public variables
   */
  /**
    @notice the timestamp of the last rebase
   */
  uint256 public lastRebaseTimestamp;

  /**
    External contracts
   */
  DAM public dam;
  DAMOracle public oracle;
  DAMReserve public immutable reserve;
  ERC20 public immutable reserveToken;
  address public gov;

  constructor(
    uint256 _minimumRebaseInterval,
    uint256 _deviationThreshold,
    uint256 _rebaseMultiplier,
    address _dam,
    address _oracle,
    address _reserve,
    address _reserveToken,
    address _gov
  ) public {
    minimumRebaseInterval = _minimumRebaseInterval;
    deviationThreshold = _deviationThreshold;
    rebaseMultiplier = _rebaseMultiplier;

    lastRebaseTimestamp = block.timestamp; // have a delay between deployment and the first rebase

    dam = DAM(_dam);
    oracle = DAMOracle(_oracle);
    reserve = DAMReserve(_reserve);
    reserveToken = ERC20(_reserveToken);
    gov = _gov;
  }

  function rebase() external {
    // ensure the last rebase was not too recent
    require(
      block.timestamp > lastRebaseTimestamp.add(minimumRebaseInterval),
      "DAMRebaser: last rebase too recent"
    );
    lastRebaseTimestamp = block.timestamp;

    // query DAM price from oracle
    uint256 damPrice = _damPrice();

    // calculate DAM price off peg percentage
    (uint256 offPegPerc, bool positive) = _computeOffPegPerc(damPrice);

    // check whether DAM price has deviated from the peg by a proportion over the threshold
    require(offPegPerc > 0, "DAMRebaser: not off peg");

    // apply multiplier to offPegPerc
    uint256 indexDelta = offPegPerc.mul(rebaseMultiplier).div(PRECISION);

    // calculate the change in total supply
    uint256 damSupply = dam.totalSupply();
    uint256 supplyChangeAmount = damSupply.mul(indexDelta).div(PRECISION);

    // rebase DAM
    if (positive) {
      // (1) if DAM price > peg, mint DAM proportional to deviation
      // (1.1) mint DAM to reserve
      dam.mint(address(reserve), supplyChangeAmount);
      // (1.2) let reserve perform actions with the minted DAM
      reserve.receiveMintedDAM(supplyChangeAmount);
    } else {
      // (2) if DAM price < peg, tell reserve to buy DAM at peg price & burn
      reserve.buyAndBurnDAM(supplyChangeAmount);
    }

    // emit rebase event
    emit Rebase(supplyChangeAmount);
  }

  /**
    Utils
   */

  /**
   * @return price the price of DAM in reserve tokens
   */
  function _damPrice() internal returns (uint256 price) {
    oracle.update();
    return oracle.consult(address(dam), DAM_PRECISION);
  }

  /**
   * @return offPegPerc in % how far off market is from peg
   *         positive true if the rate is over the peg, false if the rate is below the peg
   */
  function _computeOffPegPerc(uint256 rate)
    internal
    view
    returns (uint256 offPegPerc, bool positive)
  {
    if (_withinDeviationThreshold(rate)) {
      return (0, false);
    }

    // indexDelta =  (rate - PEG) / PEG
    if (rate > PEG) {
      return (rate.sub(PEG).mul(10**18).div(PEG), true);
    } else {
      return (PEG.sub(rate).mul(10**18).div(PEG), false);
    }
  }

  /**
   * @param rate The current exchange rate, an 18 decimal fixed point number.
   * @return If the rate is within the deviation threshold from the target rate, returns true.
   *         Otherwise, returns false.
   */
  function _withinDeviationThreshold(uint256 rate)
    internal
    view
    returns (bool)
  {
    uint256 absoluteDeviationThreshold = PEG.mul(deviationThreshold).div(
      10**18
    );

    return
      (rate >= PEG && rate.sub(PEG) < absoluteDeviationThreshold) ||
      (rate < PEG && PEG.sub(rate) < absoluteDeviationThreshold);
  }

  /**
    Parameter setters
   */
  function setMinimumRebaseInterval(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_MINIMUM_REBASE_INTERVAL &&
        newValue <= MAX_MINIMUM_REBASE_INTERVAL,
      "DAMRebaser: invalid value"
    );
    emit SetMinimumRebaseInterval(newValue, minimumRebaseInterval);
    minimumRebaseInterval = newValue;
  }

  function setDeviationThreshold(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_DEVIATION_THRESHOLD &&
        newValue <= MAX_DEVIATION_THRESHOLD,
      "DAMRebaser: invalid value"
    );
    emit SetDeviationThreshold(newValue, deviationThreshold);
    deviationThreshold = newValue;
  }

  function setRebaseMultiplier(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_REBASE_MINT_MULTIPLIER &&
        newValue <= MAX_REBASE_MINT_MULTIPLIER,
      "DAMRebaser: invalid value"
    );
    emit SetRebaseMultiplier(newValue, rebaseMultiplier);
    rebaseMultiplier = newValue;
  }

  function setOracle(address newValue) external onlyGov {
    require(newValue != address(0), "DAMRebaser: invalid value");
    emit SetOracle(newValue, address(oracle));
    oracle = DAMOracle(newValue);
  }

  function setGov(address newValue) external onlyGov {
    require(newValue != address(0), "DAMRebaser: invalid value");
    emit SetGov(newValue, gov);
    gov = newValue;
  }
}
