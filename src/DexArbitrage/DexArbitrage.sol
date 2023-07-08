// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import { UniSwapV2 } from "./dex/UniSwapV2.sol";
import { SushiSwapV1 } from "./dex/SushiSwapV1.sol";

import { Dex } from "./interface/Dex.sol";

contract DexArbitrage {
    /**
     * 要做什麼
     * 1. 可設定的選項：
     *    可選擇要不要使用 flash loan 去借資金
     *    可設定利潤 > xxx 顆才執行，不然就 revert
     * 2. 交易所 A 用 tokenA swap to tokenB
     * 3. 交易所 B 用 tokenB swap to tokenA
     *
     *
     * 需實作的功能：
     * 1. 各 dex 的 get token price
     * 2. 各 dex 的 swap 功能
     */

    // dex id
    mapping(uint256 => address) dexSwapAddress;

    constructor() {
        // 這邊可以再增加其它使用 uniswapv2 的 dex
        dexSwapAddress[1] = address(new UniSwapV2());
        dexSwapAddress[2] = address(new SushiSwapV1());
    }

    /**
     * @param buyingDex  要去哪個 dex 買
     * @param buyToken   用哪個 token 買
     * @param buyAmount  要 swap 幾顆 token
     * @param sellToken  能套利的是哪個 token
     * @param sellingDex 要去哪個 dex 賣
     * @param swapEth    是不是做 ETH 的 swap
     * @param minProfit  最少利潤要有 xx 顆 buyToken, 不然就 revert
     */
    function swap(
        uint8 buyingDex,
        address buyToken,
        uint256 buyAmount,
        address sellToken,
        uint8 sellingDex,
        bool swapEth,
        uint256 minProfit
    )
        external
        returns (bool)
    {
        require(buyingDex != sellingDex, "DexArbitrage: buyingDex == sellingDex");
        require(buyToken != sellToken, "DexArbitrage: buyToken == sellToken");
        require(buyAmount > 0, "DexArbitrage: buyAmount == 0");
        require(buyingDex > 0 && sellingDex > 0, "DexArbitrage: buyingDex or sellingDex == 0");
        bool success = false;
        uint256 tokenOutAmount = 0;

        uint256 beforeSwapBuyTokenBalance = ERC20(buyToken).balanceOf(msg.sender);
        if (swapEth) {
            (success, tokenOutAmount) = Dex(dexSwapAddress[buyingDex]).swapToETH(buyToken, buyAmount);
            (success, tokenOutAmount) = Dex(dexSwapAddress[sellingDex]).swapFromETH{ value: tokenOutAmount }(buyToken);
        } else {
            // 1. 先到 buyingDex 花 buyAmount 個 buyToken 換成 sellToken
            ERC20(buyToken).approve(dexSwapAddress[buyingDex], buyAmount);
            (success, tokenOutAmount) = Dex(dexSwapAddress[buyingDex]).swap(buyToken, buyAmount, sellToken);
            // 2. 再到 sellingDex 賣 buyAmount 個 sellToken
            ERC20(sellToken).approve(dexSwapAddress[sellingDex], buyAmount);
            (success, tokenOutAmount) = Dex(dexSwapAddress[sellingDex]).swap(sellToken, buyAmount, buyToken);
        }

        // 3. 確認利潤是否有達到 minProfit
        uint256 afterSwapBuyTokenBalance = ERC20(buyToken).balanceOf(msg.sender);
        uint8 buyTokenDecimals = ERC20(buyToken).decimals();
        require(afterSwapBuyTokenBalance > beforeSwapBuyTokenBalance, "DexArbitrage: profitAmount < 0");
        uint256 finalProfitAmount = (afterSwapBuyTokenBalance - beforeSwapBuyTokenBalance) / (10 ** buyTokenDecimals);

        require(finalProfitAmount >= minProfit, "DexArbitrage: finalProfitAmount < minProfit");
        return true;
    }

    receive() external payable { }
}
