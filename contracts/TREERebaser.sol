// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./TREE.sol";
import "./interfaces/ITREEOracle.sol";
import "./TREEReserve.sol";

contract TREERebaser is ReentrancyGuard {
  using SafeMath for uint256;

  /**
    Modifiers
   */

  modifier onlyGov {
    require(msg.sender == gov, "TREEReserve: not gov");
    _;
  }

  /**
    Events
   */
  event Rebase(uint256 treeSupplyChange);
  event SetGov(address _newValue);
  event SetOracle(address _newValue);
  event SetMinimumRebaseInterval(uint256 _newValue);
  event SetDeviationThreshold(uint256 _newValue);
  event SetRebaseMultiplier(uint256 _newValue);

  /**
    Public constants
   */
  /**
    @notice precision for decimal calculations
   */
  uint256 public constant PRECISION = 10**18;
  /**
    @notice the peg for TREE price, in reserve tokens
   */
  uint256 public constant PEG = 10**18; // 1 reserveToken/TREE
  /**
    @notice the minimum value of minimumRebaseInterval
   */
  uint256 public constant MIN_MINIMUM_REBASE_INTERVAL = 12 hours;
  /**
    @notice the maximum value of minimumRebaseInterval
   */
  uint256 public constant MAX_MINIMUM_REBASE_INTERVAL = 14 days;
  /**
    @notice the minimum value of deviationThreshold
   */
  uint256 public constant MIN_DEVIATION_THRESHOLD = 10**16; // 1%
  /**
    @notice the maximum value of deviationThreshold
   */
  uint256 public constant MAX_DEVIATION_THRESHOLD = 10**17; // 10%
  /**
    @notice the minimum value of rebaseMultiplier
   */
  uint256 public constant MIN_REBASE_MULTIPLIER = 5 * 10**16; // 0.05x
  /**
    @notice the maximum value of rebaseMultiplier
   */
  uint256 public constant MAX_REBASE_MULTIPLIER = 10**19; // 10x

  /**
    System parameters
   */
  /**
    @notice the minimum interval between rebases, in seconds
   */
  uint256 public minimumRebaseInterval;
  /**
    @notice the threshold for the off peg percentage of TREE price above which rebase will occur
   */
  uint256 public deviationThreshold;
  /**
    @notice the multiplier for calculating how much TREE to mint during a rebase
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
    @notice the address that has governance power over the reserve params
   */
  address public gov;

  /**
    External contracts
   */
  TREE public immutable tree;
  ITREEOracle public oracle;
  TREEReserve public immutable reserve;

  constructor(
    uint256 _minimumRebaseInterval,
    uint256 _deviationThreshold,
    uint256 _rebaseMultiplier,
    address _tree,
    address _oracle,
    address _reserve,
    address _gov
  ) public {
    minimumRebaseInterval = _minimumRebaseInterval;
    deviationThreshold = _deviationThreshold;
    rebaseMultiplier = _rebaseMultiplier;

    lastRebaseTimestamp = block.timestamp; // have a delay between deployment and the first rebase

    tree = TREE(_tree);
    oracle = ITREEOracle(_oracle);
    reserve = TREEReserve(_reserve);
    gov = _gov;
  }

  function rebase() external nonReentrant {
    // ensure the last rebase was not too recent
    require(
      block.timestamp > lastRebaseTimestamp.add(minimumRebaseInterval),
      "TREERebaser: last rebase too recent"
    );
    lastRebaseTimestamp = block.timestamp;

    // query TREE price from oracle
    uint256 treePrice = _treePrice();

    // calculate TREE price off peg percentage
    (uint256 offPegPerc, bool positive) = _computeOffPegPerc(treePrice);

    // check whether TREE price has deviated from the peg by a proportion over the threshold
    require(offPegPerc > 0, "TREERebaser: not off peg");

    // apply multiplier to offPegPerc
    uint256 indexDelta = offPegPerc.mul(rebaseMultiplier).div(PRECISION);

    // calculate the change in total supply
    uint256 treeSupply = tree.totalSupply();
    uint256 supplyChangeAmount = treeSupply.mul(indexDelta).div(PRECISION);

    // rebase TREE
    if (positive) {
      // if TREE price > peg, mint TREE proportional to deviation
      // (1) mint TREE to reserve
      tree.rebaserMint(address(reserve), supplyChangeAmount);
      // (2) let reserve perform actions with the minted TREE
      reserve.handlePositiveRebase(supplyChangeAmount, offPegPerc);
    }

    // emit rebase event
    emit Rebase(supplyChangeAmount);
  }

  /**
    Utils
   */

  /**
   * @return price the price of TREE in reserve tokens
   */
  function _treePrice() internal returns (uint256 price) {
    bool updated = oracle.update();
    require(updated || oracle.updated(), "TREERebaser: oracle no price");
    return oracle.consult(address(tree), PRECISION);
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
    Param setters
   */

  function setGov(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    gov = _newValue;
    emit SetGov(_newValue);
  }

  function setOracle(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    oracle = ITREEOracle(_newValue);
    emit SetOracle(_newValue);
  }

  function setMinimumRebaseInterval(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_MINIMUM_REBASE_INTERVAL &&
        _newValue <= MAX_MINIMUM_REBASE_INTERVAL,
      "TREERebaser: invalid value"
    );
    minimumRebaseInterval = _newValue;
    emit SetMinimumRebaseInterval(_newValue);
  }

  function setDeviationThreshold(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_DEVIATION_THRESHOLD &&
        _newValue <= MAX_DEVIATION_THRESHOLD,
      "TREERebaser: invalid value"
    );
    deviationThreshold = _newValue;
    emit SetDeviationThreshold(_newValue);
  }

  function setRebaseMultiplier(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_REBASE_MULTIPLIER && _newValue <= MAX_REBASE_MULTIPLIER,
      "TREERebaser: invalid value"
    );
    rebaseMultiplier = _newValue;
    emit SetRebaseMultiplier(_newValue);
  }
}
