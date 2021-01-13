pragma solidity ^0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";


interface I_ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface I_TREERewards {
	function notifyRewardAmount(uint256 reward) external;
}

interface I_OmniBridge {
  function relayTokens(address token, address _receiver, uint256 _value) external;
  function mediatorBalance(address _token) external view returns (uint256);
}


contract Router is ReentrancyGuard {
    using SafeMath for uint256;

    modifier onlyGov {
        require(msg.sender == gov, "Router: not gov");
        _;
    }

    event ReserveTransferred();
    event SetReserveToken(address token);
    event WithdrawToken(address token, address to, uint256 amount);

    address constant private TREE = 0xCE222993A7E4818E0D12BC56376c5a60f92A5783;
    address constant private RESERVE = 0x390a8Fb3fCFF0bB0fCf1F91c7E36db9c53165d17;
    address constant private DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Constants are from the original Reserve
    /// @notice precision for decimal calculations
    uint256 public constant PRECISION = 10**18;

	address public gov;
	address public charity;
	uint256 public charityCut;
	uint256 public rewardsCut;
    uint256 public oldReserveBalance;

    I_ERC20 public tree = I_ERC20(TREE);
    I_ERC20 public reserveToken = I_ERC20(DAI);
    I_TREERewards public lpRewards;
    I_OmniBridge public omniBridge;

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
		lpRewards = I_TREERewards(_lpRewards);
		omniBridge = I_OmniBridge(_omniBridge);
		charityCut = _charityCut;
		rewardsCut = _rewardsCut;
		oldReserveBalance = _oldReserveBalance;
	}

	function swapExactTokensForTokens(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		address to,
		uint deadline
	) external returns (uint256[] memory amounts) {
		require(msg.sender == RESERVE, 'UniswapV2Router: not reserve');
		require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');

        // move oldReserveBalance to charity by reversing the code that computes the charityCutAmount
        amounts[0] = 0;
        amounts[1] = oldReserveBalance.div(charityCut).mul(PRECISION.sub(rewardsCut));

        emit ReserveTransferred();
	}


    function withdrawToken(address _token, address _to, uint256 _amount, bool max) external onlyGov {
        if (max) {_amount = I_ERC20(_token).balanceOf(address(this));}
        I_ERC20(_token).transfer(_to, _amount);
        emit WithdrawToken(_token, _to, _amount);
    }

    function setReserveToken(address _newToken) external onlyGov {
        reserveToken = I_ERC20(_newToken);
        emit SetReserveToken(_newToken);
    }

}
