pragma solidity ^0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";
import "./interfaces/IOmniBridge.sol";


interface I_ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint256 addedAmount) public virtual returns (bool);
    function totalSupply() external returns(uint256);
}

interface I_TREERewards {
  function notifyRewardAmount(uint256 reward) external;
}


contract Router is ReentrancyGuard {
    using SafeMath for uint256;

    event Pledge(address addr, uint256 amount);
    event Unpledge(address addr, uint256 amount);
    event Claim(address addr, uint256 amount);
    event Rebase(totalPledged, numPledgers);
    event WithdrawToken(address token, address to, uint256 amount);
    event SetReserveToken(address token);
    event SetCharityCut(uint256 _newValue);
    event SetRewardsCut(uint256 _newValue);
    event SetOmniBridge(address _newValue);
    event SetGov(address _newValue);
    event SetCharity(address _newValue);
    event SetLPRewards(address _newValue);
    event BurnTREE(
        address indexed sender,
        uint256 burnTreeAmount,
        uint256 receiveReserveTokenAmount
    );

    address constant private TREE = 0xCE222993A7E4818E0D12BC56376c5a60f92A5783;
    address constant private RESERVE = 0x390a8Fb3fCFF0bB0fCf1F91c7E36db9c53165d17;
    address constant private DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Constants are from the original Reserve
    /// @notice precision for decimal calculations
    uint256 public constant PRECISION = 10**18;
    uint256 public constant UNISWAP_GAMMA = 997 * 10**15;
    /// @notice the minimum value of charityCut
    uint256 public constant MIN_CHARITY_CUT = 10**17; // 10%
    /// @notice the maximum value of charityCut
    uint256 public constant MAX_CHARITY_CUT = 5 * 10**17; // 50%
    /// @notice the minimum value of rewardsCut
    uint256 public constant MIN_REWARDS_CUT = 5 * 10**15; // 0.5%
    /// @notice the maximum value of rewardsCut
    uint256 public constant MAX_REWARDS_CUT = 10**17; // 10%

    address private gov;
    address private charity;
    address private omniBridge;
    uint256 private charityCut;
    uint256 private rewardsCut;
    uint256 private oldReserveBalance;
    bool private hasTransferredOldReserveBalance;

    I_ERC20 public tree = I_ERC20(TREE);
    I_ERC20 public reserveToken = I_ERC20(DAI);
    I_TREERewards public lpRewards;

    uint256 public treeSupply;

    uint256 private totalPledged;
    uint256 private numPledgers;
    mapping (uint256 => address) private pledgers;
    mapping (address => uint256) private amountsPledged;
    mapping (address => uint256) private amountsClaimable;

    constructor(
        address _gov,
        address _charity,
        address _lpRewards,
        address _omniBridge,
        uint256 _charityCut,
        uint256 _rewardsCut,
        uint256 _oldReserveBalance,
        uint256 _treeSupply
    ) public {
        gov = _gov;
        charity = _charity;
        lpRewards = _lpRewards;
        omniBridge = _omniBridge;
        charityCut = _charityCut;
        rewardsCut = _rewardsCut;
        oldReserveBalance = _oldReserveBalance;

        // Because this contract isn't allowed to call TREE.reserveBurn(), TREE.totalSupply() may be wrong.
        // We will track treeSupply starting from the amount that is passed in (which may be TREE.totalSupply())
        treeSupply = _treeSupply;
    }


    function pledge(uint256 _amount, bool max) external payable {
        require(!Address.isContract(msg.sender), "Must pledge from EOA");
        if (max) {_amount = reserveToken.balanceOf(msg.sender);}
        require(_amount > 0, "Must pledge more than 0.");
        require(reserveToken.balanceOf(msg.sender) >= _amount, "Cannot pledge more reserveToken than held.");
        reserveToken.transferFrom(msg.sender, address(this), _amount);

        totalPledged = totalPledged + _amount;

        if (amountsPledged[msg.sender] == 0) {
            // User has not pledged before. Add them to pledgers[] so we can loop over them.
            pledgers[++numPledgers] = msg.sender;
        }
        amountsPledged[msg.sender] = amountsPledged[msg.sender].add(_amount);

        emit Pledge(msg.sender, _amount);
    }


    function unpledge(uint256 _amount, bool max) external payable {
        require(hasPledged(msg.sender), "User has not pledged.");
        if (max) {_amount = amountsPledged[msg.sender];}
        require(_amount <= amountsPledged[msg.sender], "Cannot unpledge more than already pledged.");

        totalPledged = totalPledged.sub(_amount);
        amountsPledged[msg.sender] = amountsPledged.sub(_amount);

        reserveToken.transfer(msg.sender, _amount);

        emit Unpledge(msg.sender, _amount);
    }


    function claim() external nonReentrant {
        uint256 claimable = amountsClaimable[msg.sender];
        
        tree.transfer(msg.sender, claimable);
        emit Claim(msg.sender, claimable);

        delete(amountsClaimable[msg.sender]);
    }


    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint256[] memory amounts) {
        require(msg.sender == RESERVE, 'UniswapV2Router: not reserve');
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        require(totalPledged >= amountIn, "Not enough DAI pledged. Rebase postponed.");

        // Send TREE to each pledger
        // transfer pledged reserveToken to reserve
        reserveToken.increaseAllowance(address(this), totalPledged);
        reserveToken.transfer(RESERVE, totalPledged);

        // Update TREE claimable for each pledger
        for (uint i=1; i<=numPledgers; i++) {
            address pledger = pledgers[i];
            uint256 amountPledged = amountsPledged[pledger];

            if (amountPledged > 0) {
                // treeToReceive = value pledged * (amountIn / totalPledged)
                // For example, if 100 DAI is pledged and there's only 50 TREE available
                // an address that pledged 5 DAI would receive 5 * (50/100) = 2.5 TREE
                uint256 treeToReceive = amountPledged.mul(amountIn).div(totalPledged);
                treeSold = treeSold.add(treeToReceive);
                amountsClaimable[pledger] = amountsClaimable[pledger].add(treeToReceive);

                delete(amountsPledged[pledger]);
            }
            delete(pledgers[i]);
        }

        // Increase our internal measure of treeSupply by the amount sent in plus the amount sent to LP rewards
        treeSupply = treeSupply.add(amountIn.div(PRECISION.sub(rewardsCut)));

        if (!hasTransferredOldReserveBalance) {
            // move oldReserveBalance to charity by reversing the code that computes the charityCutAmount
            // https://github.com/WhalerDAO/tree-contracts/blob/master/contracts/TREEReserve.sol#L173-L175
            amounts[0] = 0;
            amounts[1] = oldReserveBalance.div(charityCut).mul(PRECISION.sub(rewardsCut));
            hasTransferredOldReserveBalance = true;
        } else {
            // send some of the reserveToken to charity
            uint256 charityCutAmount = reserveTokenReceived.mul(charityCut).div(
                PRECISION.sub(rewardsCut)
            );
            reserveToken.safeIncreaseAllowance(address(omniBridge), charityCutAmount);
            omniBridge.relayTokens(address(reserveToken), charity, charityCutAmount);
        }

        emit Rebase(totalPledged, numPledgers);

        // Reset tracking variables
        totalPledged = 0;
        numPledgers = 0;
    }


    function burnTREE(uint256 amount) external nonReentrant {
        // Burn TREE for msg.sender. This doesn't update TREE.totalSupply() like TREE.reserveBurn()
        tree.transferFrom(msg.sender, amount, address(0));

        // Give reserveToken to msg.sender based on % of Tree supply burned ^ 1.25

        // totalReserveTokens * (amount ^ 1.25) / (treeSupply ^ 1.25) =
        // totalReserveTokens * (amount / treeSupply) ^ 1.25
        uint256 amountToReceive = reserveToken.balanceOf(address(this)).mul(
            amount.mul(Babylonian.sqrt(Babylonian.sqrt(amount)))).div(
            treeSupply.mul(Babylonian.sqrt(Babylonian.sqrt(treeSupply))));

        reserveToken.safeTransfer(msg.sender, amountToReceive);

        // Since we cant call TREE.reserveBurn(), we have to track treeSupply ourselves.
        treeSupply = treeSupply.sub(amountToReceive);

        emit BurnTREE(msg.sender, amount, amountToReceive);
    }

    function withdrawToken(address _token, address _to, uint256 _amount, bool max) external payable {
        require(msg.sender == gov, "UniswapRouter: not gov");
        if (max) {_amount = I_ERC20(_token).balanceOf(address(this));}
        I_ERC20(_token).transfer(_to, _amount);
        emit WithdrawToken(_token, _to, _amount);
    }


    function getTotalPledged() public view returns (uint256) {
        return totalPledged;
    }

    function hasPledged(address _addr) external view returns (bool) {
        return amountsPledged[_addr] > 0;
    }

    function getPledgeAmount(address _addr) external view returns (uint256) {
        return amountsPledged[_addr];
    }

    function getClaimAmount(address _addr) external view returns (uint256) {
        return amountsClaimable[_addr];
    }

    function getGov() external view returns (address) {return gov;}
    function getCharity() external view returns (address) {return charity;}
    function getCharityCut() external view returns (uint256) {return charityCut;}
    function getRewardsCut() external view returns (uint256) {return rewardsCut;}

    function setGov(address _newValue) external onlyGov {
        require(_newValue != address(0), "TREEReserve: address is 0");
        gov = _newValue;
        emit SetGov(_newValue);
    }

    function setCharity(address _newValue) external onlyGov {
        require(_newValue != address(0), "TREEReserve: address is 0");
        charity = _newValue;
        emit SetCharity(_newValue);
    }

    function setLPRewards(address _newValue) external onlyGov {
        require(_newValue != address(0), "TREEReserve: address is 0");
        lpRewards = ITREERewards(_newValue);
        emit SetLPRewards(_newValue);
    }

    function setReserveToken(address _newToken) external {
        require(msg.sender == gov, "UniswapRouter: not gov");
        reserveToken = I_ERC20(_newToken);
        emit SetReserveToken(_newToken);
    }

    function setCharityCut(uint256 _newValue) external onlyGov {
        require(
        _newValue >= MIN_CHARITY_CUT && _newValue <= MAX_CHARITY_CUT,
        "TREEReserve: value out of range"
        );
        charityCut = _newValue;
        emit SetCharityCut(_newValue);
    }

    function setRewardsCut(uint256 _newValue) external onlyGov {
        require(
        _newValue >= MIN_REWARDS_CUT && _newValue <= MAX_REWARDS_CUT,
        "TREEReserve: value out of range"
        );
        rewardsCut = _newValue;
        emit SetRewardsCut(_newValue);
    }

    function setOmniBridge(address _newValue) external onlyGov {
        require(_newValue != address(0), "TREEReserve: address is 0");
        omniBridge = IOmniBridge(_newValue);
        emit SetOmniBridge(_newValue);
    }

}
