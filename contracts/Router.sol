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

    // Constants are from the original Reserve
    /// @notice precision for decimal calculations
    uint256 public constant PRECISION = 10**18;

    // Hardcoded data pulled from current reserve
    // https://etherscan.io/address/0x390a8fb3fcff0bb0fcf1f91c7e36db9c53165d17#readContract
    uint256 public charityCut = 100000000000000000;
	uint256 public rewardsCut = 100000000000000000;
    address public gov = 0xade20A93179003300529AfeF3853F9679234D929;
    address public reserve = 0x504397F81b1676710815f09CC3F3e1F3ee46c455;
    // address public charity = 0x703e0bEFF5d4f917b4b97ec8dC6D9ddbC90fb175;
    // I_TREERewards public lpRewards = I_TREERewards(0xe7B7d02296A016e25a40F18DFD55626A64308fE3);
    // I_OmniBridge public omniBridge = I_OmniBridge(0xc47192E48F75B612c792833C8b54Ad6BE319af90);
    // Current DAI balance
    uint256 public oldReserveBalance = 17621554639972284767269;
    
	constructor() public {}

	function swapExactTokensForTokens(
		uint amountIn,
		uint amountOutMin,
		address[] calldata path,
		address to,
		uint deadline
	// ) external returns (uint256[] memory amounts) {
	) external returns (uint256[] memory amounts) {
		// require(msg.sender == address(reserve), 'UniswapV2Router: not reserve');
		require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');

        // move oldReserveBalance to charity by reversing the code that computes the charityCutAmount
        // NOTE: multiplying before dividing leads to less rounding :)
        amounts = new uint256[](2);
        amounts[0] = 0;
        amounts[1] = oldReserveBalance.mul(PRECISION.sub(rewardsCut)).div(charityCut);

        emit ReserveTransferred();
        return amounts;
	}


    function withdrawToken(address _token, address _to, uint256 _amount, bool max) external {
        require(msg.sender == address(gov), "Router: not gov");
        if (max) {_amount = I_ERC20(_token).balanceOf(address(this));}
        I_ERC20(_token).transfer(_to, _amount);
        emit WithdrawToken(_token, _to, _amount);
    }

}
