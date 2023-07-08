// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { Utils } from "../Utils.sol";

contract Dex is Utils {
    IUniswapV2Router02 public v2Router;
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor(address _v2RouterAddr) {
        v2Router = IUniswapV2Router02(_v2RouterAddr);
    }

    function swap(
        address tokenIn,
        uint256 tokenInAmount,
        address tokenOut
    )
        external
        returns (bool success, uint256 tokenOutAmount)
    {
        // 1. 花 tokenInAmount 個 tokenIn 換成 tokenOut
        // 先來做 ERC20 token 換成各個 ERC20 token
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline) external returns (uint[] memory amounts);
        uint256[] memory amounts = v2Router.swapExactTokensForTokens(
            tokenInAmount, 0, sortTokens(tokenIn, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swap failed");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapToETH(
        address tokenIn,
        uint256 tokenInAmount
    )
        external
        returns (bool success, uint256 tokenOutAmount)
    {
        // ### amountOut 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline)
        uint256[] memory amounts = v2Router.swapExactTokensForETH(
            tokenInAmount, 0, sortTokens(tokenIn, WETH_ADDR), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swapToETH failed");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapFromETH(address tokenOut) external payable returns (bool success, uint256 tokenOutAmount) {
        uint256 tokenInAmount = msg.value;
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) returns
        // (uint[] memory amounts)
        uint256[] memory amounts = v2Router.swapExactETHForTokens{ value: tokenInAmount }(
            0, sortTokens(WETH_ADDR, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swapFromETH failed");
        return (amounts[1] > 0, amounts[1]);
    }
}
