pragma solidity ^0.6.6;

contract UniswapPairManipulator {
    uint256 public reserve0;
    uint256 public reserve1;

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1, uint32 _blockTimestampLast) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = 100000;
    }
}