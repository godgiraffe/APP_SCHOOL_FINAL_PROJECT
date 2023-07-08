// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract Utils {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address[] memory path) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        path = new address[](2);
        (path[0], path[1]) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(path[0] != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }
}
