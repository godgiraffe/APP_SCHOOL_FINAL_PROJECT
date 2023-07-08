// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Dex } from "../interface/Dex.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { Utils } from "../Utils.sol";

// https://docs.uniswap.org/sdk/v2/guides/quick-start
contract SushiSwapV1 is Dex, Utils {
    address public constant SUSHISWAP_V1_ROUTER_ADDR = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    IUniswapV2Router02 public sushiswapRouter;
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() {
        sushiswapRouter = IUniswapV2Router02(SUSHISWAP_V1_ROUTER_ADDR);
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
        uint256[] memory amounts = sushiswapRouter.swapExactTokensForTokens(
            tokenInAmount, 0, sortTokens(tokenIn, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "SushiSwapV1: swap failed");
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
        // function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint
        // deadline) returns (uint[] memory amounts);
        uint256[] memory amounts = sushiswapRouter.swapTokensForExactETH(
            0, tokenInAmount, sortTokens(tokenIn, WETH_ADDR), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "SushiSwapV1: swapToETH failed");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapFromETH(address tokenOut) external payable returns (bool success, uint256 tokenOutAmount) {
        uint256 tokenInAmount = msg.value;
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) returns
        // (uint[] memory amounts)
        uint256[] memory amounts = sushiswapRouter.swapExactETHForTokens{ value: tokenInAmount }(
            0, sortTokens(WETH_ADDR, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "SushiSwapV1: swapFromETH failed");
        return (amounts[1] > 0, amounts[1]);
    }
}
