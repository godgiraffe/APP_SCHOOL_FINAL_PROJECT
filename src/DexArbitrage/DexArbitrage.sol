// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import { DexCenter } from "./DexCenter.sol";

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
     * 1. 各 dex 的 get token price - 前端做去
     * 2. 各 dex 的 swap 功能
     */

    // dex
    mapping(uint256 => address) public dexRouterAddress;
    uint8 public dexRouterCount;
    address public constant UNISWAP_V2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant SUSHISWAP_V1_ROUTER_ADDR = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public constant SHIBASWAP_ROUTER_ADDR = 0x03f7724180AA6b939894B5Ca4314783B0b36b329;
    DexCenter public dexCenter;

    constructor() {
        dexCenter = new DexCenter();
        // 這邊可以再增加其它使用 uniswapv2 的 dexRouterAddress
        dexRouterAddress[1] = UNISWAP_V2_ROUTER_ADDR;
        dexRouterAddress[2] = SUSHISWAP_V1_ROUTER_ADDR;
        dexRouterCount = 2;
    }

    /**
     * @param buyingDexId  要去哪個 dex 買
     * @param buyToken   用哪個 token 買
     * @param buyAmount  要 swap 幾顆 token
     * @param sellToken  能套利的是哪個 token
     * @param sellingDexId 要去哪個 dex 賣
     * @param swapEth    是不是做 ETH 的 swap
     * @param minProfitAmount  最少利潤要有 xx 顆 buyToken, 不然就 revert
     */
    function swap(
        uint8 buyingDexId,
        address buyToken,
        uint256 buyAmount,
        address sellToken,
        uint8 sellingDexId,
        bool swapEth,
        uint256 minProfitAmount
    )
        external
        returns (bool)
    {
        require(buyingDexId != sellingDexId, "DexArbitrage: buyingDex == sellingDex");
        require(buyToken != sellToken, "DexArbitrage: buyToken == sellToken");
        require(buyAmount > 0, "DexArbitrage: buyAmount == 0");
        require(buyingDexId > 0 && sellingDexId > 0, "DexArbitrage: buyingDex or sellingDex == 0");
        bool success = false;
        uint256 buyTokenAmount = 0;
        uint256 sellTokenAmount = 0;
        address buyingDexRouter = dexRouterAddress[buyingDexId];
        address sellingDexRouter = dexRouterAddress[sellingDexId];

        uint256 beforeSwapBuyTokenBalance = IERC20(buyToken).balanceOf(msg.sender);
        if (swapEth) {
            (success, sellTokenAmount) = dexCenter.swapFromETH{ value: buyAmount }(buyToken, buyingDexRouter);
            (success, buyTokenAmount) = dexCenter.swapToETH(buyToken, sellTokenAmount, sellingDexRouter);
        } else {
            // 1. 先到 buyingDex 花 buyAmount 個 buyToken 換成 sellToken
            IERC20(buyToken).approve(address(dexCenter), buyAmount); // 到時候會在前端做
            (success, sellTokenAmount) = dexCenter.swap(buyToken, buyAmount, sellToken, buyingDexRouter);
            // 2. 再到 sellingDex 賣 tokenOutAmount 個 sellToken
            IERC20(sellToken).approve(address(dexCenter), sellTokenAmount); // 到時候會在前端做
            (success, buyTokenAmount) = dexCenter.swap(sellToken, sellTokenAmount, buyToken, sellingDexRouter);
        }

        // 3. 確認利潤是否有達到 minProfitAmount
        uint256 afterSwapBuyTokenBalance = IERC20(buyToken).balanceOf(msg.sender);
        uint8 buyTokenDecimals = ERC20(buyToken).decimals();
        require(afterSwapBuyTokenBalance > beforeSwapBuyTokenBalance, "DexArbitrage: profitAmount < 0");
        uint256 finalProfitAmount = (afterSwapBuyTokenBalance - beforeSwapBuyTokenBalance) / (10 ** buyTokenDecimals);

        require(finalProfitAmount >= minProfitAmount, "DexArbitrage: finalProfitAmount < minProfitAmount");
        return true;
    }

    receive() external payable { }
}
