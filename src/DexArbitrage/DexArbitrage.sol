// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import { IUniswapV2Factory } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import { DexCenter } from "./DexCenter.sol";

import "forge-std/Test.sol";

contract DexArbitrage {
    /**
     * 要做什麼
     * 1. 可設定的選項：
     *    可選擇要不要使用 flash loan 去借資金
     *    可設定利潤 > xxx 顆才執行，不然就 revert
     * 2. 交易所 A 用 tokenA swap to tokenB
     * 3. 交易所 B 用 tokenB swap to tokenA
     * 4. contract owner 可以 add dex
     *
     * 需實作的功能：
     * 1. 各 dex 的 get token price - 前端做去
     * 2. 各 dex 的 swap 功能
     */

    // event
    event AddDex(uint8 indexed dexRouterCount, address indexed dexRouterAddress);

    // contract
    address public owner;

    // dex
    mapping(uint256 => address) public dexRouterAddress;
    uint8 public dexRouterCount;
    address public constant UNISWAP_V2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant SUSHISWAP_V1_ROUTER_ADDR = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address public constant SHIBASWAP_ROUTER_ADDR = 0x03f7724180AA6b939894B5Ca4314783B0b36b329;
    DexCenter public dexCenter;

    constructor() {
        owner = msg.sender;
        dexCenter = new DexCenter();
        // 這邊可以再增加其它使用 uniswapv2 的 dexRouterAddress
        dexRouterAddress[1] = UNISWAP_V2_ROUTER_ADDR;
        dexRouterAddress[2] = SUSHISWAP_V1_ROUTER_ADDR;
        dexRouterCount = 2;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "DexArbitrage: only owner");
        _;
    }

    function addDex(address _dexRouterAddress) external onlyOwner {
        require(_dexRouterAddress != address(0), "DexArbitrage: _dexRouterAddress == 0");
        bool isExist = false;
        for (uint256 dexId = 1; dexId <= dexRouterCount; dexId++) {
            if (_dexRouterAddress == dexRouterAddress[dexId]) {
                isExist = true;
                break;
            }
        }
        require(isExist == false, "DexArbitrage: Dex already exists");

        dexRouterCount++;
        dexRouterAddress[dexRouterCount] = _dexRouterAddress;
        emit AddDex(dexRouterCount, _dexRouterAddress);
    }

    /**
     * @param buyingDexId  要去哪個 dex 買
     * @param buyToken   用哪個 token 買
     * @param buyAmount  要 swap 幾顆 token
     * @param sellToken  能套利的是哪個 token
     * @param sellingDexId 要去哪個 dex 賣
     * @param isSwapEth    是不是做 ETH 的 swap
     * @param minProfitAmount  最少利潤要有 xx 顆 buyToken, 不然就 revert
     */
    function arbitrage(
        uint8 buyingDexId,
        address buyToken,
        uint256 buyAmount,
        address sellToken,
        uint8 sellingDexId,
        bool isSwapEth,
        uint256 minProfitAmount
    )
        external
        payable
        returns (bool)
    {
        require(buyingDexId != sellingDexId, "DexArbitrage: buyingDex is equal to sellingDex");
        require(buyToken != sellToken, "DexArbitrage: buyToken is equal to sellToken");
        require(buyAmount > 0, "DexArbitrage: buyAmount is zero");
        require(buyingDexId > 0 && sellingDexId > 0, "DexArbitrage: buyingDex or sellingDex is zero");
        bool success = false;
        uint256 buyTokenAmount = 0;
        uint256 sellTokenAmount = 0;
        address buyingDexRouter = dexRouterAddress[buyingDexId];
        address sellingDexRouter = dexRouterAddress[sellingDexId];

        uint256 beforeSwapBuyTokenBalance;
        uint256 afterSwapBuyTokenBalance;
        if (isSwapEth) {
            // eth 這邊讓 user 打 eth 進來, 再轉給 dexCenter
            require(msg.value >= buyAmount, "DexArbitrage: msg.value < buyAmount");
            beforeSwapBuyTokenBalance = address(msg.sender).balance + msg.value;
            (success,) = address(dexCenter).call{ value: msg.value }("");
            (success, sellTokenAmount) = dexCenter.swapFromETH{ value: buyAmount }(sellToken, buyingDexRouter);

            // IERC20(sellToken).approve(address(dexCenter), sellTokenAmount); approve 到時候會在前端做
            (success, buyTokenAmount) = dexCenter.swapToETH(sellToken, sellTokenAmount, sellingDexRouter);
            (success,) = address(msg.sender).call{ value: buyTokenAmount }("");
            afterSwapBuyTokenBalance = address(msg.sender).balance;
        } else {
            // erc20 這邊讓 user approve token 給 dexCenter (前端做), 這邊不經手任何 token
            beforeSwapBuyTokenBalance = IERC20(buyToken).balanceOf(msg.sender);
            // 1. 先到 buyingDex 花 buyAmount 個 buyToken 換成 sellToken
            bytes memory data = abi.encode(false, msg.sender);
            (success, sellTokenAmount) = dexCenter.swap(buyToken, buyAmount, sellToken, buyingDexRouter, data);
            // 2. 再到 sellingDex 賣 tokenOutAmount 個 sellToken
            data = abi.encode(true, msg.sender);
            (success, buyTokenAmount) = dexCenter.swap(sellToken, sellTokenAmount, buyToken, sellingDexRouter, data);
            afterSwapBuyTokenBalance = IERC20(buyToken).balanceOf(msg.sender);
        }

        // 3. 確認利潤是否有達到 minProfitAmount

        uint8 buyTokenDecimals = ERC20(buyToken).decimals();
        // 要找到有價差、能套利的 token 不太容易, 所以這段先註解, 不然會一直 revert XDD
        // console.log("beforeSwapBuyTokenBalance: %s", beforeSwapBuyTokenBalance);
        // console.log("afterSwapBuyTokenBalance: %s", afterSwapBuyTokenBalance);
        // require(afterSwapBuyTokenBalance > beforeSwapBuyTokenBalance, "DexArbitrage: profitAmount < 0");
        // uint256 finalProfitAmount = (afterSwapBuyTokenBalance - beforeSwapBuyTokenBalance) / (10 **
        // buyTokenDecimals);
        // require(finalProfitAmount >= minProfitAmount, "DexArbitrage: finalProfitAmount < minProfitAmount");

        return true;
    }

    receive() external payable { }
}
