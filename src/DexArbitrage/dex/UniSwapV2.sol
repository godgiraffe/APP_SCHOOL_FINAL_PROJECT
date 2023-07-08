// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Dex } from "../interface/Dex.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { Utils } from "../Utils.sol";

// https://docs.uniswap.org/sdk/v2/guides/quick-start
contract UniSwapV2 is Dex, Utils {
    /**
     * 要做什麼
     * 1. 可設定的選項：
     *    可選擇要不要使用 flash loan 去借資金
     *    可設定利潤 > xxx 才執行，不然就 revert
     * 2. 交易所 A 用 tokenA swap to tokenB
     * 3. 交易所 B 用 tokenB swap to tokenA
     *
     *
     * 需實作的功能：
     * 1. 各 dex 的 get token price
     * 2. 各 dex 的 swap 功能
     */

    /**
     * 需要輸入的參數
     * 1. 交易所 A 的合約地址
     * 2. 交易所 B 的合約地址
     * 3. tokenA 的合約地址
     * 4. tokenB 的合約地址
     * 5. tokenA 的數量
     * 6. tokenB 的數量
     * 7. 交易所 A 的 swap function & 所需參數
     * 8. 交易所 B 的 swap function & 所需參數
     */

    /**
     * 做一個 interface 把要支援的交易所都做成一個合約，合約的作用是 tokenA swap to TokenB
     * 需要輸入的參數是：
     * 1. tokenA 的合約地址
     * 2. tokenB 的合約地址
     * 3. tokenA 的數量
     * 4. tokenB 的數量
     */
    address public constant UNISWAP_V2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public uniswapRouter;
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() {
        uniswapRouter = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDR);
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
        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
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
        uint256[] memory amounts = uniswapRouter.swapTokensForExactETH(
            0, tokenInAmount, sortTokens(tokenIn, WETH_ADDR), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "SushiSwapV1: swapFromETH failed");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapFromETH(address tokenOut) external payable returns (bool success, uint256 tokenOutAmount) {
        uint256 tokenInAmount = msg.value;
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) returns
        // (uint[] memory amounts)
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{ value: tokenInAmount }(
            0, sortTokens(WETH_ADDR, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "SushiSwapV1: swapFromETH failed");
        return (amounts[1] > 0, amounts[1]);
    }
}
