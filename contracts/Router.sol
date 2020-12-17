pragma solidity ^0.6.6;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function increaseAllowance(address spender, uint256 addedAmount) public virtual returns (bool);
}


contract Router {
    using SafeMath for uint256;

    event Pledge(uint256 numCampaign, address addr, uint256 amount);
    event Unpledge(uint256 numCampaign, address addr, uint256 amount);
    event Rebase(uint256 numCampaign, treeSold, reserveTokenReceived);
    event WithdrawToken(address token, address to, uint256 amount);
    event SetReserveToken(address token);

    address constant private TREE = 0xCE222993A7E4818E0D12BC56376c5a60f92A5783;
    address constant private RESERVE = 0x390a8Fb3fCFF0bB0fCf1F91c7E36db9c53165d17;
    address constant private DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public gov;
    IERC20 public tree = IERC20(TREE);
    IERC20 public reserveToken = IERC20(DAI);

    struct Campaign {
        uint256 totalPledged;
        uint256 numPledgers;
        uint256 treeSold;
        mapping (uint256 => address) pledgers;
        mapping (address => uint256) amountsPledged;
    }

    uint256 private numCampaigns = 1;

    mapping(uint256 => Campaign) private campaigns;
 
    constructor(address _gov) public {
        gov = _gov;
    }


    function pledge(uint256 _amount, bool max) external payable {
        require(!Address.isContract(msg.sender), "Must pledge from EOA");
        if (max) {_amount = reserveToken.balanceOf(msg.sender);}
        require(_amount > 0, "Must pledge more than 0.");
        require(reserveToken.balanceOf(msg.sender) >= _amount, "Cannot pledge more reserveToken than held.");
        reserveToken.transferFrom(msg.sender, address(this), _amount);

        Campaign storage c = campaigns[numCampaigns];
        c.totalPledged = c.totalPledged + _amount;

        uint256 pledgerId = getPledgerId(numCampaigns, msg.sender);
        if (pledgerId == 0) {
            // user has not pledged before
            pledgerId = c.numPledgers++;
            c.pledgers[pledgerId] = msg.sender;
            c.amountsPledged[msg.sender] = _amount;
        } else {
            // user has pledged before, add to their total pledged
            c.amountsPledged[msg.sender] = c.amountsPledged[msg.sender].add(_amount);
        }

        emit Pledge(numCampaigns, msg.sender, _amount);
    }


    function unpledge(uint256 _amount, bool max) external payable {
        Campaign storage c = campaigns[numCampaigns];

        uint256 pledgerId = getPledgerId(numCampaigns, msg.sender);
        require(pledgerId != 0, "User has not pledged.");
        if (max) {_amount = c.amountsPledged[msg.sender];}
        require(_amount <= c.amountsPledged[msg.sender], "Cannot unpledge more than already pledged.");

        c.totalPledged = c.totalPledged.sub(_amount);
        c.amountsPledged[msg.sender] = c.amountsPledged.sub(_amount);

        reserveToken.transfer(msg.sender, _amount);

        emit Unpledge(numCampaigns, msg.sender, _amount);
    }


    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override returns (uint256[] memory amounts) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');

        Campaign storage c = campaigns[numCampaigns];
        require(c.totalPledged >= amountIn, "Not enough DAI pledged. Rebase postponed.");

        // transfer pledged reserveToken to reserve
        reserveToken.increaseAllowance(address(this), c.totalPledged);
        reserveToken.transfer(RESERVE, c.totalPledged);

        // Send TREE to each pledger
        for (uint i=1; i<c.numPledgers+1; i++) {
            
            address pledger = c.pledgers[i];
            uint256 amountPledged = c.amountsPledged[pledger];

            // treeToReceive = value pledged * (amountIn / totalPledged)
            // For example, if 100 DAI is pledged and there's only 50 TREE available
            // an address that pledged 5 DAI would receive 5 * (50/100) = 2.5 TREE
            uint256 treeToReceive = amountPledged.mul(amountIn).div(c.totalPledged);

            // Only transfer to EOAs to prevent unexpected reverts if pledge was done using CREATE2
            // Also, if user ended up unpledging 100%, do not waste a transfer of 0 tokens
            // note: TREE is already approved to transfer
            // https://github.com/WhalerDAO/tree-contracts/blob/4525d20def8fce41985f0711e9b742a0f3c0d30b/contracts/TREEReserve.sol#L228
            if (!Address.isContract(pledger) && amountPledged > 0) {
                tree.transfer(pledger, treeToReceive);
                c.treeSold = c.treeSold + treeToReceive;
            }
        }
        numCampaigns++;

        // Return amounts based on https://github.com/WhalerDAO/tree-contracts/blob/4525d20def8fce41985f0711e9b742a0f3c0d30b/contracts/TREEReserve.sol#L217
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = c.treeSold;
        amounts[1] = c.totalPledged;

        emit Rebase(numCampaigns-1, c.treeSold, c.totalPledged);
    }


    function getPledgerId(uint256 _numCampaign, address _addr) private returns (uint256 pledgerId) {
        Campaign storage c = campaigns[_numCampaign];
        pledgerId = 0;
        for (uint i=1; i < c.numPledgers+1; i++) {
            address pledger = c.pledgers[i];
            if (pledger == _addr) {
                pledgerId = i;
                break;
            }
        }
    }


    function setReserveToken(address _newToken) external {
        require(msg.sender == gov, "UniswapRouter: not gov");
        reserveToken = IERC20(_newToken);
        emit SetReserveToken(_newToken);
    }


    function withdrawToken(address _token, address _to, uint256 _amount, bool max) external payable {
        require(msg.sender == gov, "UniswapRouter: not gov");
        if (max) {_amount = IERC20(_token).balanceOf(address(this));}
        IERC20(_token).transfer(_to, _amount);
        emit WithdrawToken(_token, _to, _amount);
    }

    function getCampaignTotalPledged(uint256 _numCampaign) public view returns (uint256) {
        Campaign storage c = campaigns[_numCampaign];
        return c.totalPledged;
    }

    function hasPledged(uint256 _numCampaign, address _addr) external view returns (bool pledged) {
        Campaign storage c = campaigns[_numCampaign];
        pledged = false;
        for (i=1;i<c.numPledgers;i++) {
            if (c.pledgers[i] == _addr && c.amountsPledged[_addr] > 0) {
                pledged = true;
                break;
            }
        }
    }

    function getPledgeAmount(uint256 _numCampaign, address _addr) external view returns (uint256) {
        Campaign storage c = campaigns[_numCampaign];
        return c.amountsPledged[_addr];
    }

    function getNumCampaigns() external view returns (uint256) {
        return numCampaigns;
    }
}