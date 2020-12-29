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

    modifier onlyGov {
        require(msg.sender == gov, "Router: not gov");
        _;
    }

    event Pledge(address indexed sender, uint256 amount);
    event Unpledge(address indexed sender, uint256 amount);
    event ClaimTree(address indexed sender, uint256 amount);
    event Rebase(totalPledged, numPledgers, totalBurned, numBurners);
    event WithdrawToken(address token, address to, uint256 amount);
    event SetReserveToken(address token);
    event SetCharityCut(uint256 _newValue);
    event SetRewardsCut(uint256 _newValue);
    event SetOmniBridge(address _newValue);
    event SetGov(address _newValue);
    event SetCharity(address _newValue);
    event SetLPRewards(address _newValue);
    event SetTargetPriceMultiplier(uint256 _newValue);
    event AddToBurnPool(address indexed sender, uint256 amount);
    event RemoveFromBurnPool(address indexed sender, uint256 amount);
    event ClaimReserve(address indexed sender, uint256 amount);

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

	address public gov;
	address public charity;
	address public omniBridge;
	uint256 public charityCut;
	uint256 public rewardsCut;
	uint256 public targetPriceMultiplier = 1002 * 10 ** 15; // 1.002%
	uint256 public oldReserveBalance;
	bool public hasTransferredOldReserveBalance;

    I_ERC20 public tree = I_ERC20(TREE);
    I_ERC20 public reserveToken = I_ERC20(DAI);
    I_TREERewards public lpRewards;

	uint256 public treeSupply;
	uint256 public targetPrice;
    uint256 public totalReserveClaimable;

    uint256 public totalPledged;
    uint256 public numPledgers;
    mapping (uint256 => address) public pledgers;
    mapping (address => uint256) public amountsPledged;
    mapping (address => uint256) public treeClaimable;

    uint256 public totalInBurnPool;
    uint256 public numBurners;
    mapping (uint256 => address) public burners;
    mapping (address => uint256) public amountsBurned;
    mapping (address => uint256) public reserveClaimable;

	constructor(
		address _gov,
		address _charity,
		address _lpRewards,
		address _omniBridge,
		uint256 _charityCut,
		uint256 _rewardsCut,
		uint256 _oldReserveBalance,
		uint256 _treeSupply,
		uint256 _targetPrice,
		uint256 _targetPriceMultiplier
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
		targetPrice = _targetPrice;
		targetPriceMultiplier = _targetPriceMultiplier;
	}


    function pledge(uint256 _amount, bool max) external {
        require(!Address.isContract(msg.sender), "Must pledge from EOA");
        if (max) {_amount = reserveToken.balanceOf(msg.sender);}
        require(_amount > 0, "Must pledge more than 0.");
        require(reserveToken.balanceOf(msg.sender) >= _amount, "Cannot pledge more reserveToken than held.");
        reserveToken.transferFrom(msg.sender, address(this), _amount);

        totalPledged = totalPledged.add(_amount);

        if (amountsPledged[msg.sender] == 0) {
            // User has not pledged before. Add them to pledgers[] so we can loop over them.
            pledgers[++numPledgers] = msg.sender;
        }
        amountsPledged[msg.sender] = amountsPledged[msg.sender].add(_amount);

        emit Pledge(msg.sender, _amount);
    }


    function unpledge(uint256 _amount, bool max) external nonReentrant {
        require(hasPledged(msg.sender), "User has not pledged.");
        if (max) {_amount = amountsPledged[msg.sender];}
        require(_amount <= amountsPledged[msg.sender], "Cannot unpledge more than already pledged.");

        totalPledged = totalPledged.sub(_amount);
        amountsPledged[msg.sender] = amountsPledged.sub(_amount);

        reserveToken.transfer(msg.sender, _amount);

        emit Unpledge(msg.sender, _amount);
    }


    function claimTREE() external nonReentrant {
        uint256 claimable = treeClaimable[msg.sender];
        require(claimable > 0, "No TREE claimable from this address.");

        tree.transfer(msg.sender, claimable);
        emit ClaimTree(msg.sender, claimable);

        delete(treeClaimable[msg.sender]);
    }


    function addTreeToBurnPool(uint256 amount, bool max) external {
        if (max) {
            amount = tree.balanceOf(msg.sender);
        }
        require(amount > 0, "Must burn more than 0.");
        require(tree.balanceOf(msg.sender) >= amount, "Cannot burn more TREE than held.");

        tree.transferFrom(msg.sender, address(this), amount);

        totalInBurnPool = totalInBurnPool.add(amount);

        if (amountsBurned[msg.sender] == 0) {
            // User has not burned before. Add them to burners[] so we can loop over them.
            burners[++numBurners] = msg.sender;
        }
        amountsBurned[msg.sender] = amountsBurned[msg.sender].add(amount);

        emit AddToBurnPool(msg.sender, amount);
    }


    function removeTreeFromBurnPool(uint256 amount, bool max) external nonReentrant {
        if (max) {
            amount = amountsBurned[msg.sender];
        }
        require(amount <= amountsBurned[msg.sender], "Cannot remove more from burn pool than already added.");

        totalInBurnPool = totalInBurnPool.sub(amount);
        amountsBurned[msg.sender] = amountsBurned.sub(amount);

        tree.transfer(msg.sender, amount);

        emit RemoveFromBurnPool(msg.sender, amount);
    }


    function claimReserve() external nonReentrant {
        uint256 claimable = reserveClaimable[msg.sender];
        require(claimable > 0, "No reserve claimable from this address.");

        reserveToken.transfer(msg.sender, claimable);

        totalReserveClaimable = totalReserveClaimable.sub(claimable);

        delete(reserveClaimable[msg.sender]);

        emit ClaimReserve(msg.sender, claimable);
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
		require(totalPledged >= amountIn.mul(targetPrice),
			"Not enough tokens pledged to reach target price. Rebase postponed.");

        // Update TREE claimable for each pledger
        for (uint i = 1; i <= numPledgers; i++) {
            address pledger = pledgers[i];
            uint256 amountPledged = amountsPledged[pledger];

            if (amountPledged > 0) {
                // treeToReceive = value pledged * (amountIn / totalPledged)
                // For example, if 100 DAI is pledged and there's only 50 TREE available
                // an address that pledged 5 DAI would receive 5 * (50/100) = 2.5 TREE
                uint256 treeToReceive = amountPledged.mul(amountIn).div(totalPledged);
                treeClaimable[pledger] = treeClaimable[pledger].add(treeToReceive);

                delete(amountsPledged[pledger]);
            }
            delete(pledgers[i]);
        }

	    tree.transferFrom(msg.sender, address(this), amountIn);

	    if (totalInBurnPool > 0) {
            // To find how much of the reserve is available to distribute, start with the reserve balance in this
            // contract, subtract the total that was just pledged, subtract the reserve that is waiting to be claimed
            // from previous burns. Multiply this by the square root of the percentage of TREE in the burn pool.
            // For example, if 49% of the TREE supply is being burned, 70% (sqrt .49 = .70) of the available reserve
            // will be distributed proportionally to contributors to the burn pool.
            uint reserveToDistribute =
                (reserveToken.balanceOf(address(this)).sub(totalPledged).sub(totalReserveClaimable))
                .mul(Babylonian.sqrt(totalInBurnPool)).div(Babylonian.sqrt(treeSupply));

            // Update reserve token claimable for each burner
            for (uint i = 1; i <= numBurners; i++) {
                address burner = burners[i];
                uint256 amountBurned = amountsBurned[burner];

                if (amountBurned > 0) {
                    // reserveToReceive = reserveToDistribute * (amountBurned / totalInBurnPool)
                    // Everyone gets available reserve tokens back proportional to their share of the burn pool.
                    uint256 reserveToReceive = amountBurned.mul(reserveToDistribute).div(totalInBurnPool);
                    reserveClaimable[burner] = reserveClaimable[burner].add(reserveToReceive);

                    delete (amountsBurned[burner]);
                }
                delete (burners[i]);
            }

            totalReserveClaimable = totalReserveClaimable.add(reserveToDistribute);

		    // Burn the TREE
		    tree.transfer(address(0), totalInBurnPool);
        }

        // Increase our internal measure of treeSupply by the amount sent in plus the amount sent to LP rewards
        // minus the amount burned
        treeSupply = treeSupply.add(amountIn.div(PRECISION.sub(rewardsCut))).sub(totalInBurnPool);

        if (!hasTransferredOldReserveBalance) {
            // move oldReserveBalance to charity by reversing the code that computes the charityCutAmount
            amounts[0] = 0;
            amounts[1] = oldReserveBalance.div(charityCut).mul(PRECISION.sub(rewardsCut));
            hasTransferredOldReserveBalance = true;
        } else {
            // send some of the reserveToken to charity
	        uint256 charityCutAmount = totalPledged.mul(charityCut).div(PRECISION.sub(rewardsCut));
            reserveToken.safeIncreaseAllowance(address(omniBridge), charityCutAmount);
            omniBridge.relayTokens(address(reserveToken), charity, charityCutAmount);
        }

        emit Rebase(totalPledged, numPledgers, totalInBurnPool, numBurners);

        // Reset pledging and burning pools
        totalPledged = 0;
        numPledgers = 0;
        totalInBurnPool = 0;
        numBurners = 0;

		// Increase targetPrice after a successful rebase

		targetPrice = targetPrice.mul(targetPriceMultiplier).div(PRECISION);
	}


    function withdrawToken(address _token, address _to, uint256 _amount, bool max) external onlyGov {
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

    function getTreeClaimableAmount(address _addr) external view returns (uint256) {
        return treeClaimable[_addr];
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

    function setReserveToken(address _newToken) external onlyGov {
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

	function setTargetPriceMultiplier(uint256 _newValue) external onlyGov {
		targetPriceMultiplier _newValue;
		emit SetTargetPriceMultiplier(_newValue);
	}

}
