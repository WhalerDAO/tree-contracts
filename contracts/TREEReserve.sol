// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.6;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./TREE.sol";
import "./TREERebaser.sol";
import "./interfaces/ITREEOracle.sol";
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
  event SellTREE(uint256 treeSold, uint256 reserveTokenReceived);
  event BurnTREE(
    address indexed sender,
    uint256 burnTreeAmount,
    uint256 receiveReserveTokenAmount
  );
  event SetGov(address _newValue);
  event SetCharity(address _newValue);
  event SetLPRewards(address _newValue);
  event SetCharityCut(uint256 _newValue);
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
    System parameters
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
    @notice the maximum slippage factor when buying reserve token
  */
  uint256 public maxSlippageFactor;

  /**
    External contracts
   */
  TREE public immutable tree;
  ERC20 public immutable reserveToken;
  TREERebaser public rebaser;
  ITREERewards public lpRewards;
  ITREEOracle public immutable oracle;
  IUniswapV2Router02 public immutable uniswapRouter;

  constructor(
    uint256 _charityCut,
    uint256 _rewardsCut,
    uint256 _maxSlippageFactor,
    address _tree,
    address _gov,
    address _charity,
    address _reserveToken,
    address _lpRewards,
    address _oracle,
    address _uniswapRouter
  ) public {
    charityCut = _charityCut;
    rewardsCut = _rewardsCut;
    maxSlippageFactor = _maxSlippageFactor;

    tree = TREE(_tree);
    gov = _gov;
    charity = _charity;
    reserveToken = ERC20(_reserveToken);
    lpRewards = ITREERewards(_lpRewards);
    oracle = ITREEOracle(_oracle);
    uniswapRouter = IUniswapV2Router02(_uniswapRouter);
  }

  function initContracts(address _rebaser) external onlyOwner {
    require(_rebaser != address(0), "TREE: invalid rebaser");
    require(address(rebaser) == address(0), "TREE: rebaser already set");
    rebaser = TREERebaser(_rebaser);
  }

  /**
    @notice distribute minted TREE to TREERewards and TREEGov, and sell the rest
    @param mintedTREEAmount the amount of TREE minted
    @param offPegPerc the TREE price off peg percentage
   */
  function handlePositiveRebase(uint256 mintedTREEAmount, uint256 offPegPerc)
    external
    onlyRebaser
    nonReentrant
  {
    // send TREE to TREERewards
    uint256 rewardsCutAmount = mintedTREEAmount.mul(rewardsCut).div(PRECISION);
    tree.transfer(address(lpRewards), rewardsCutAmount);
    lpRewards.notifyRewardAmount(rewardsCutAmount);

    // sell remaining TREE for reserveToken
    uint256 remainingTREEAmount = mintedTREEAmount.sub(rewardsCutAmount);
    (uint256 treeSold, uint256 reserveTokenReceived) = _sellTREE(
      remainingTREEAmount,
      offPegPerc
    );

    // burn unsold TREE
    if (treeSold < remainingTREEAmount) {
      tree.reserveBurn(address(this), remainingTREEAmount.sub(treeSold));
    }

    // send reserveToken to charity
    uint256 charityCutAmount = reserveTokenReceived.mul(charityCut).div(
      PRECISION.sub(rewardsCut)
    );
    reserveToken.safeTransfer(address(charity), charityCutAmount);

    // emit event
    emit SellTREE(treeSold, reserveTokenReceived);
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
    Utilities
   */
  /**
    @notice create a sell order for TREE
    @param amount the amount of TREE to sell
    @param offPegPerc the TREE price off peg percentage
    @return treeSold the amount of TREE sold
            reserveTokenReceived the amount of reserve tokens received
   */
  function _sellTREE(uint256 amount, uint256 offPegPerc)
    internal
    returns (uint256 treeSold, uint256 reserveTokenReceived)
  {
    IUniswapV2Pair pair = IUniswapV2Pair(oracle.pair());
    (uint256 token0Reserves, uint256 token1Reserves, ) = pair.getReserves();
    uint256 tokensToMaxSlippage = _uniswapMaxSlippage(
      token0Reserves,
      token1Reserves,
      offPegPerc
    );
    treeSold = amount > tokensToMaxSlippage ? tokensToMaxSlippage : amount;
    tree.increaseAllowance(address(uniswapRouter), treeSold);
    address[] memory path = new address[](2);
    path[0] = address(tree);
    path[1] = address(reserveToken);
    uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
      treeSold,
      1,
      path,
      address(this),
      block.timestamp
    );
    reserveTokenReceived = amounts[1];
  }

  function _uniswapMaxSlippage(
    uint256 token0,
    uint256 token1,
    uint256 offPegPerc
  ) internal view returns (uint256) {
    if (oracle.token0() == address(tree)) {
      if (offPegPerc >= 10**17) {
        // cap slippage
        return token0.mul(maxSlippageFactor).div(10**18);
      } else {
        // in the 5-10% off peg range, slippage is essentially 2*x (where x is percentage of pool to buy).
        // all we care about is not pushing below the peg, so underestimate
        // the amount we can sell by dividing by 3. resulting price impact
        // should be ~= offPegPerc * 2 / 3, which will keep us above the peg
        //
        // this is a conservative heuristic
        return token0.mul(offPegPerc.div(3)).div(10**18);
      }
    } else {
      if (offPegPerc >= 10**17) {
        return token1.mul(maxSlippageFactor).div(10**18);
      } else {
        return token1.mul(offPegPerc.div(3)).div(10**18);
      }
    }
  }

  /**
    Param setters
   */
  function setGov(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    gov = _newValue;
    emit SetGov(_newValue);
  }

  function setCharity(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    charity = _newValue;
    emit SetCharity(_newValue);
  }

  function setLPRewards(address _newValue) external onlyGov {
    require(_newValue != address(0), "TREEReserve: 0");
    lpRewards = ITREERewards(_newValue);
    emit SetLPRewards(_newValue);
  }

  function setCharityCut(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_CHARITY_CUT && _newValue <= MAX_CHARITY_CUT,
      "TREEReserve: invalid value"
    );
    charityCut = _newValue;
    emit SetCharityCut(_newValue);
  }

  function setRewardsCut(uint256 _newValue) external onlyGov {
    require(
      _newValue >= MIN_REWARDS_CUT && _newValue <= MAX_REWARDS_CUT,
      "TREEReserve: invalid value"
    );
    rewardsCut = _newValue;
    emit SetRewardsCut(_newValue);
  }
}
