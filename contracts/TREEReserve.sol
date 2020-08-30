// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./TREE.sol";
import "./TREERebaser.sol";
import "./interfaces/ITREERewards.sol";

contract TREEReserve is ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  /**
    Modifiers
   */

  modifier onlyRebaser {
    require(msg.sender == address(rebaser), "TREEReserve: not rebaser");
    _;
  }

  /**
    Events
   */
  event SellTREE(uint256 amount);
  event BuyTREEFromSale(uint256 saleIdx, uint256 amount);
  event BurnExpiredSale(uint256 saleIdx);
  event Ragequit(
    address indexed sender,
    uint256 burnTreeAmount,
    uint256 receiveReserveTokenAmount
  );
  event SetGovCandidate(address _newValue);
  event SetGov(address _newValue);

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
    System parameters
   */
  /**
    @notice the proportion of rebase income given to TREEGov
   */
  uint256 public immutable govCut;
  /**
    @notice the proportion of rebase income given to TREERewards
   */
  uint256 public immutable rewardsCut;
  /**
    @notice the length of a TREE sale, stored in seconds
   */
  uint256 public immutable saleLength;
  /**
    @notice the time lock length for changing gov, stored in seconds
   */
  uint256 public immutable govTimelockLength;

  /**
    Public variables
   */
  struct TREESale {
    uint256 amount;
    uint256 expireTimestamp;
  }
  TREESale[] public treeSales;
  uint256 public treeOnSaleAmount;
  address public govCandidate;
  uint256 public govCandidateProposeTimestamp;

  /**
    External contracts
   */
  TREE public immutable tree;
  address public gov;
  ERC20 public immutable reserveToken;
  TREERebaser public rebaser;
  ITREERewards public rewards;

  constructor(
    uint256 _govCut,
    uint256 _rewardsCut,
    uint256 _saleLength,
    uint256 _govTimelockLength,
    address _tree,
    address _gov,
    address _reserveToken
  ) public {
    govCut = _govCut;
    rewardsCut = _rewardsCut;
    saleLength = _saleLength;
    govTimelockLength = _govTimelockLength;

    tree = TREE(_tree);
    gov = _gov;
    reserveToken = ERC20(_reserveToken);
  }

  function initContracts(address _rebaser, address _rewards) external {
    require(_rebaser != address(0), "TREE: invalid rebaser");
    require(address(rebaser) == address(0), "TREE: rebaser already set");
    require(_rewards != address(0), "TREE: invalid rewards");
    require(address(rewards) == address(0), "TREE: rewards already set");
    rebaser = TREERebaser(_rebaser);
    rewards = ITREERewards(_rewards);
  }

  /**
    @notice distribute minted TREE to TREERewards and TREEGov, and sell the rest
    @param amount the amount of TREE minted
   */
  function handlePositiveRebase(uint256 amount)
    external
    onlyRebaser
    nonReentrant
  {
    // send TREE to TREERewards
    uint256 rewardsCutAmount = amount.mul(rewardsCut).div(PRECISION);
    tree.transfer(address(rewards), rewardsCutAmount);
    rewards.notifyRewartreeount(rewardsCutAmount);

    // send TREE to TREEGov
    uint256 govCutAmount = amount.mul(govCut).div(PRECISION);
    tree.transfer(address(gov), govCutAmount);

    // sell remaining TREE for reserveToken
    uint256 remainingAmount = amount.sub(rewardsCutAmount).sub(govCutAmount);
    _sellTREE(remainingAmount);
  }

  /**
    @notice buy TREE from an ongoing rebase sale
    @param saleIdx the index of the sale in treeSales
    @param amount the amount of TREE to buy
   */
  function buyTREEFromSale(uint256 saleIdx, uint256 amount)
    external
    nonReentrant
  {
    uint256 remainingSaleAmount = treeSales[saleIdx].amount;
    uint256 expireTimestamp = treeSales[saleIdx].expireTimestamp;
    require(
      amount <= remainingSaleAmount && amount > 0,
      "TREEReserve: invalid amount"
    );
    require(block.timestamp < expireTimestamp, "TREEReserve: sale expired");

    // transfer reserveToken from msg.sender
    uint256 payAmount = amount.mul(PEG).div(PRECISION);
    reserveToken.safeTransferFrom(msg.sender, address(this), payAmount);

    // transfer TREE to msg.sender
    tree.transfer(msg.sender, amount);

    // update sale data
    treeSales[saleIdx].amount = remainingSaleAmount.sub(amount);
    treeOnSaleAmount = treeOnSaleAmount.sub(amount);

    // emit event
    emit BuyTREEFromSale(saleIdx, amount);
  }

  /**
    @notice burn the TREE locked in an expired sale
    @param saleIdx the index of the sale in treeSales
   */
  function burnExpiredSale(uint256 saleIdx) external nonReentrant {
    uint256 remainingSaleAmount = treeSales[saleIdx].amount;
    uint256 expireTimestamp = treeSales[saleIdx].expireTimestamp;
    require(remainingSaleAmount > 0, "TREEReserve: nothing to burn");
    require(block.timestamp >= expireTimestamp, "TREEReserve: sale active");

    // burn TREE
    tree.burn(remainingSaleAmount);

    // update sale data
    delete treeSales[saleIdx];
    treeOnSaleAmount = treeOnSaleAmount.sub(remainingSaleAmount);

    // emit event
    emit BurnExpiredSale(saleIdx);
  }

  function ragequit(uint256 amount) external nonReentrant {
    uint256 treeSupply = tree.totalSupply();

    // burn TREE for msg.sender
    tree.reserveBurn(msg.sender, amount);

    // give reserveToken to msg.sender based on quadratic shares
    uint256 reserveTokenBalance = reserveToken.balanceOf(address(this)).sub(
      treeOnSaleAmount.mul(PEG).div(PRECISION)
    );
    uint256 deserveAmount = reserveTokenBalance.mul(amount.mul(amount)).div(treeSupply.mul(treeSupply));
    reserveToken.safeTransfer(msg.sender, deserveAmount);

    // emit event
    emit Ragequit(msg.sender, amount, deserveAmount);
  }

  /**
    Param setters
   */
  function setGovCandidate(address _newValue) external {
    require(msg.sender == gov, "TREEReserve: not gov");
    govCandidate = _newValue;
    govCandidateProposeTimestamp = block.timestamp;
    emit SetGovCandidate(_newValue);
  }

  function setGov() external {
    require(msg.sender == gov, "TREEReserve: not gov");
    require(block.timestamp >= govCandidateProposeTimestamp.add(govTimelockLength));
    gov = govCandidate;
    emit SetGov(gov);
  }

  /**
    Utilities
   */
  /**
    @notice create a sell order for TREE
    @param amount the amount of TREE to sell
   */
  function _sellTREE(uint256 amount) internal {
    treeSales.push(
      TREESale({
        amount: amount,
        expireTimestamp: saleLength.add(block.timestamp)
      })
    );
    treeOnSaleAmount = treeOnSaleAmount.add(amount);
    emit SellTREE(amount);
  }
}
