pragma solidity ^0.6.6;

contract UniswapPairManipulator {
    // uint256 public reserve0 = 4334506208368730625564;
    // uint256 public reserve1 = 6747708227968965321210;
    uint256 public reserve0 = 10**18;
    uint256 public reserve1 = 10**18;

    // Manipulate result

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = 100000;
    }
}   