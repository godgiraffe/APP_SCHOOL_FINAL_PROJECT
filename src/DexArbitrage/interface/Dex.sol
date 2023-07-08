// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface Dex {
    function swap(
        address tokenIn,
        uint256 tokenInAmount,
        address tokenOut
    )
        external
        returns (bool success, uint256 tokenOutAmount);
    function swapToETH(
        address tokenIn,
        uint256 tokenInAmount
    )
        external
        returns (bool success, uint256 tokenOutAmount);
    function swapFromETH(address tokenOut) external payable returns (bool success, uint256 tokenOutAmount);
}
