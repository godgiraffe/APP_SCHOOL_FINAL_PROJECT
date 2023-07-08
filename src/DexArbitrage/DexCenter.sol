// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { Utils } from "./Utils.sol";

contract DexCenter is Utils {
    address public constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    constructor() { }

    function swap(
        address tokenIn,
        uint256 tokenInAmount,
        address tokenOut,
        address dexRouterAddress
    )
        external
        returns (bool success, uint256 tokenOutAmount)
    {
        // 1. 先從 user transferFrom tokenInAmount 個 tokenIn, 給 dexCenter
        IERC20(tokenIn).transferFrom(msg.sender, address(this), tokenInAmount);
        // 2. dexCenter approve 給 dexRouterAddress, 允許 dexRouterAddress 使用 tokenInAmount 個 tokenIn
        IERC20(tokenIn).approve(dexRouterAddress, tokenInAmount);
        // 3. 把 tokenInAmount 個 tokenIn 換成 tokenOut
        // 先來做 ERC20 token 換成各個 ERC20 token
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline) external returns (uint[] memory amounts);
        uint256[] memory amounts = IUniswapV2Router02(dexRouterAddress).swapExactTokensForTokens(
            tokenInAmount, 0, sortTokens(tokenIn, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swap failed");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapToETH(
        address tokenIn,
        uint256 tokenInAmount,
        address dexRouterAddress
    )
        external
        returns (bool success, uint256 tokenOutAmount)
    {
        // 1. 先從 user transferFrom tokenInAmount 個 tokenIn, 給 dexCenter
        IERC20(tokenIn).transferFrom(msg.sender, address(this), tokenInAmount);
        // 2. dexCenter approve 給 dexRouterAddress, 允許 dexRouterAddress 使用 tokenInAmount 個 tokenIn
        IERC20(tokenIn).approve(dexRouterAddress, tokenInAmount);
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline)
        uint256[] memory amounts = IUniswapV2Router02(dexRouterAddress).swapExactTokensForETH(
            tokenInAmount, 0, sortTokens(tokenIn, WETH_ADDR), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swapToETH failed");
        // 3. 把換到的 eth 轉給 user
        (bool trannsferResult,) = msg.sender.call{ value: amounts[1] }(""); // 注意 external call 的風險
        require(trannsferResult, "Transfer ETH failed.");
        return (amounts[1] > 0, amounts[1]);
    }

    function swapFromETH(
        address tokenOut,
        address dexRouterAddress
    )
        external
        payable
        returns (bool success, uint256 tokenOutAmount)
    {
        // user 使用這 function 時, 會轉 ETH 給 dexCenter
        uint256 tokenInAmount = msg.value;
        // ### amountOutMin 設成 0, 不知道會不會有三明治攻擊問題(?) ###
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) returns
        // (uint[] memory amounts)
        uint256[] memory amounts = IUniswapV2Router02(dexRouterAddress).swapExactETHForTokens{ value: tokenInAmount }(
            0, sortTokens(WETH_ADDR, tokenOut), address(this), block.timestamp + 15
        );
        require(amounts[1] > 0, "swapFromETH failed");
        return (amounts[1] > 0, amounts[1]);
    }

    receive() external payable { }
}
