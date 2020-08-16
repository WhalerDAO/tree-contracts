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
  event SetMinimumRebaseInterval(uint256 newValue, uint256 oldValue);
  event SetDeviationThreshold(uint256 newValue, uint256 oldValue);

  /**
    Public constants
   */
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
    System parameters
   */
  /**
    @notice the minimum interval between rebases
   */
  uint256 public minimumRebaseInterval;
  /**
    @notice the threshold for the off peg percentage of DAM price above which rebase will occur
   */
  uint256 public deviationThreshold;

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
  DAMReserve public reserve;
  ERC20 public immutable reserveToken;
  address public gov;

  constructor(
    uint256 _minimumRebaseInterval,
    address _dam,
    address _oracle,
    address _reserveToken,
    address _gov
  ) public {
    minimumRebaseInterval = _minimumRebaseInterval;
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

    // query DAM price on Uniswap
    oracle.update();
    uint256 damPrice = oracle.consult(address(dam), DAM_PRECISION);

    // calculate DAM price off peg percentage
    (uint256 offPegPerc, bool positive) = _computeOffPegPerc(damPrice);

    // check whether DAM price has deviated from the peg by a proportion over the threshold
    require(offPegPerc > 0, "DAMRebaser: price too close to peg");

    // rebase DAM
    if (positive) {
      // (1) if DAM price > peg, mint DAM proportional to deviation
      // (1.1) calculate mint amount
      // (1.2) mint DAM
      // (1.3) send DAM to reserve
    } else {
      // (2) if DAM price < peg, tell reserve to buy DAM at peg price & burn
    }
  }

  /**
    Utils
   */
  /**
   * @return Computes in % how far off market is from peg
   */
  function _computeOffPegPerc(uint256 rate)
    internal
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
  function _withinDeviationThreshold(uint256 rate) internal returns (bool) {
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
      "DAMRebaser: value out of range"
    );
    emit SetMinimumRebaseInterval(newValue, minimumRebaseInterval);
    minimumRebaseInterval = newValue;
  }

  function setDeviationThreshold(uint256 newValue) external onlyGov {
    require(
      newValue >= MIN_DEVIATION_THRESHOLD &&
        newValue <= MAX_DEVIATION_THRESHOLD,
      "DAMRebaser: value out of range"
    );
    emit SetDeviationThreshold(newValue, deviationThreshold);
    deviationThreshold = newValue;
  }
}
