// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TREE.sol";
import "./TREERebaser.sol";
import "./interfaces/ITREERewards.sol";

contract TREEReserve is ReentrancyGuard, Ownable {
  using SafeMath for uint256;
  using SafeERC20 for ERC20;

  /**
    Modifiers
   */

  modifier onlyRebaser {
    require(msg.sender == address(rebaser), "TREEReserve: not rebaser");
    _;
  }

  modifier onlyGov {
    require(msg.sender == gov, "TREEReserve: not gov");
    _;
  }

  /**
    Events
   */
  event SellTREE(uint256 amount);
  event BuyTREEFromSale(uint256 saleIdx, uint256 amount);
  event BurnExpiredSale(uint256 saleIdx);
  event BurnTREE(
    address indexed sender,
    uint256 burnTreeAmount,
    uint256 receiveReserveTokenAmount
  );
  event SetGovCandidate(address _newValue);
  event SetGov(address _newValue);
  event SetCharityCandidate(address _newValue);
  event SetCharity(address _newValue);
  event SetCharityCutCandidate(uint256 _newValue);
  event SetCharityCut(uint256 _newValue);
  event SetRewardsCutCandidate(uint256 _newValue);
  event SetRewardsCut(uint256 _newValue);

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
    @notice the minimum value of charityCut
   */
  uint256 public constant MIN_CHARITY_CUT = 10**17; // 10%
  /**
    @notice the maximum value of charityCut
   */
  uint256 public constant MAX_CHARITY_CUT = 5 * 10**17; // 50%
  /**
    @notice the minimum value of rewardsCut
   */
  uint256 public constant MIN_REWARDS_CUT = 5 * 10**15; // 0.5%
  /**
    @notice the maximum value of rewardsCut
   */
  uint256 public constant MAX_REWARDS_CUT = 10**17; // 10%

  /**
    Immutable system parameters
   */
  /**
    @notice the length of a TREE sale, stored in seconds
   */
  uint256 public immutable saleLength;
  /**
    @notice the time lock length for changing params, stored in seconds
   */
  uint256 public immutable timelockLength;

  /**
    Mutable system parameters
   */
  /**
    @notice the address that has governance power over the reserve params
   */
  address public gov;
  /**
    @notice the address that will store the TREE donation
   */
  address public charity;
  /**
    @notice the proportion of rebase income given to charity
   */
  uint256 public charityCut;
  /**
    @notice the proportion of rebase income given to LPRewards
   */
  uint256 public rewardsCut;

  /**
    Mutable system parameter timelock variables
   */
  address public govCandidate;
  uint256 public govCandidateProposeTimestamp;
  address public charityCandidate;
  uint256 public charityCandidateProposeTimestamp;
  uint256 public charityCutCandidate;
  uint256 public charityCutCandidateProposeTimestamp;
  uint256 public rewardsCutCandidate;
  uint256 public rewardsCutCandidateProposeTimestamp;

  /**
    Public variables
   */
  struct TREESale {
    uint256 amount;
    uint256 expireTimestamp;
  }
  TREESale[] public treeSales;

  /**
    External contracts
   */
  TREE public immutable tree;
  ERC20 public immutable reserveToken;
  TREERebaser public rebaser;
  ITREERewards public immutable lpRewards;

  constructor(
    uint256 _charityCut,
    uint256 _rewardsCut,
    uint256 _saleLength,
    uint256 _timelockLength,
    address _tree,
    address _gov,
    address _charity,
    address _reserveToken,
    address _lpRewards
  ) public {
    charityCut = _charityCut;
    rewardsCut = _rewardsCut;
    saleLength = _saleLength;
    timelockLength = _timelockLength;

    tree = TREE(_tree);
    gov = _gov;
    charity = _charity;
    reserveToken = ERC20(_reserveToken);
    lpRewards = ITREERewards(_lpRewards);
  }

  function initContracts(address _rebaser) external onlyOwner {
    require(_rebaser != address(0), "TREE: invalid rebaser");
    require(address(rebaser) == address(0), "TREE: rebaser already set");
    rebaser = TREERebaser(_rebaser);
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
    tree.transfer(address(lpRewards), rewardsCutAmount);
    lpRewards.notifyRewardAmount(rewardsCutAmount);

    // send TREE to charity
    uint256 charityCutAmount = amount.mul(charityCut).div(PRECISION);
    tree.transfer(address(charity), charityCutAmount);

    // sell remaining TREE for reserveToken
    uint256 remainingAmount = amount.sub(rewardsCutAmount).sub(
      charityCutAmount
    );
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

    // emit event
    emit BurnExpiredSale(saleIdx);
  }

  function burnTREE(uint256 amount) external nonReentrant {
    require(!Address.isContract(msg.sender), "TREEReserve: not EOA");

    uint256 treeSupply = tree.totalSupply();

    // burn TREE for msg.sender
    tree.reserveBurn(msg.sender, amount);

    // give reserveToken to msg.sender based on quadratic shares
    uint256 reserveTokenBalance = reserveToken.balanceOf(address(this));
    uint256 deserveAmount = reserveTokenBalance.mul(amount.mul(amount)).div(
      treeSupply.mul(treeSupply)
    );
    reserveToken.safeTransfer(msg.sender, deserveAmount);

    // emit event
    emit BurnTREE(msg.sender, amount, deserveAmount);
  }

  /**
    Param setters
   */
  function setGovCandidate(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    govCandidate = _newValue;
    govCandidateProposeTimestamp = block.timestamp;
    emit SetGovCandidate(_newValue);
  }

  function setGov() external {
    require(
      block.timestamp >= govCandidateProposeTimestamp.add(timelockLength),
      "TREEReserve: timelock"
    );
    gov = govCandidate;
    emit SetGov(gov);
  }

  function setCharityCandidate(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    charityCandidate = _newValue;
    charityCandidateProposeTimestamp = block.timestamp;
    emit SetCharityCandidate(_newValue);
  }

  function setCharity() external {
    require(
      block.timestamp >= charityCandidateProposeTimestamp.add(timelockLength),
      "TREEReserve: timelock"
    );
    charity = charityCandidate;
    emit SetCharity(charity);
  }

  function setCharityCutCandidate(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_CHARITY_CUT && _newValue <= MAX_CHARITY_CUT,
      "TREEReserve: invalid value"
    );
    charityCutCandidate = _newValue;
    charityCutCandidateProposeTimestamp = block.timestamp;
    emit SetCharityCutCandidate(_newValue);
  }

  function setCharityCut() external {
    require(
      block.timestamp >=
        charityCutCandidateProposeTimestamp.add(timelockLength),
      "TREEReserve: timelock"
    );
    charityCut = charityCutCandidate;
    emit SetCharityCut(charityCut);
  }

  function setRewardsCutCandidate(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_REWARDS_CUT && _newValue <= MAX_REWARDS_CUT,
      "TREEReserve: invalid value"
    );
    rewardsCutCandidate = _newValue;
    rewardsCutCandidateProposeTimestamp = block.timestamp;
    emit SetRewardsCutCandidate(_newValue);
  }

  function setRewardsCut() external {
    require(
      block.timestamp >=
        rewardsCutCandidateProposeTimestamp.add(timelockLength),
      "TREEReserve: timelock"
    );
    rewardsCut = rewardsCutCandidate;
    emit SetRewardsCut(rewardsCut);
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
    emit SellTREE(amount);
  }
}
