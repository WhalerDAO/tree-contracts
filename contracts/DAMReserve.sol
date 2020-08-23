// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./DAM.sol";
import "./DAMRebaser.sol";
import "./DAMGov.sol";
import "./interfaces/IDAMRewards.sol";

contract DAMReserve is ReentrancyGuard {
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
  event BuyDAMFromSale(uint256 saleIdx, uint256 amount);
  event BurnExpiredSale(uint256 saleIdx);
  event Ragequit(
    address indexed sender,
    uint256 burnDamAmount,
    uint256 receiveReserveTokenAmount
  );

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
  uint256 public constant PEG = 10**18; // 1 reserveToken/DAM

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
    @notice the length of a DAM sale, stored in seconds
   */
  uint256 public immutable saleLength;

  /**
    Public variables
   */
  struct DAMSale {
    uint256 amount;
    uint256 expireTimestamp;
  }
  DAMSale[] public damSales;
  uint256 public damOnSaleAmount;

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
    uint256 _saleLength,
    address _dam,
    address _gov,
    address _reserveToken
  ) public {
    govCut = _govCut;
    rewardsCut = _rewardsCut;
    saleLength = _saleLength;

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
  function handlePositiveRebase(uint256 amount)
    external
    onlyRebaser
    nonReentrant
  {
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
    @notice buy DAM from an ongoing rebase sale
    @param saleIdx the index of the sale in damSales
    @param amount the amount of DAM to buy
   */
  function buyDAMFromSale(uint256 saleIdx, uint256 amount)
    external
    nonReentrant
  {
    uint256 remainingSaleAmount = damSales[saleIdx].amount;
    uint256 expireTimestamp = damSales[saleIdx].expireTimestamp;
    require(
      amount <= remainingSaleAmount && amount > 0,
      "DAMReserve: invalid amount"
    );
    require(block.timestamp < expireTimestamp, "DAMReserve: sale expired");

    // transfer reserveToken from msg.sender
    uint256 payAmount = amount.mul(PEG).div(PRECISION);
    reserveToken.safeTransferFrom(msg.sender, address(this), payAmount);

    // transfer DAM to msg.sender
    dam.transfer(msg.sender, amount);

    // update sale data
    damSales[saleIdx].amount = remainingSaleAmount.sub(amount);
    damOnSaleAmount = damOnSaleAmount.sub(amount);

    // emit event
    emit BuyDAMFromSale(saleIdx, amount);
  }

  /**
    @notice burn the DAM locked in an expired sale
    @param saleIdx the index of the sale in damSales
   */
  function burnExpiredSale(uint256 saleIdx) external nonReentrant {
    uint256 remainingSaleAmount = damSales[saleIdx].amount;
    uint256 expireTimestamp = damSales[saleIdx].expireTimestamp;
    require(remainingSaleAmount > 0, "DAMReserve: nothing to burn");
    require(block.timestamp >= expireTimestamp, "DAMReserve: sale active");

    // burn DAM
    dam.burn(remainingSaleAmount);

    // update sale data
    delete damSales[saleIdx];
    damOnSaleAmount = damOnSaleAmount.sub(remainingSaleAmount);

    // emit event
    emit BurnExpiredSale(saleIdx);
  }

  function ragequit(uint256 amount) external nonReentrant {
    uint256 damSupply = dam.totalSupply();

    // burn DAM for msg.sender
    dam.reserveBurn(msg.sender, amount);

    // give reserveToken pro rata to msg.sender
    uint256 reserveTokenBalance = reserveToken.balanceOf(address(this)).sub(
      damOnSaleAmount.mul(PEG).div(PRECISION)
    );
    uint256 deserveAmount = reserveTokenBalance.mul(amount).div(damSupply);
    reserveToken.safeTransfer(msg.sender, deserveAmount);

    // emit event
    emit Ragequit(msg.sender, amount, deserveAmount);
  }

  /**
    Utilities
   */
  /**
    @notice create a sell order for DAM
    @param amount the amount of DAM to sell
   */
  function _sellDAM(uint256 amount) internal {
    damSales.push(
      DAMSale({
        amount: amount,
        expireTimestamp: saleLength.add(block.timestamp)
      })
    );
    damOnSaleAmount = damOnSaleAmount.add(amount);
    emit SellDAM(amount);
  }
}
