// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { DexArbitrage } from "../src/DexArbitrage/DexArbitrage.sol";

interface IUSDT {
    function allowance(address _owner, address _spender) external returns (uint256 remaining);
}

contract DexArbitrageTest is Test {
    DexArbitrage public dexArbitrage;
    address public bob;
    address public alice;
    address public constant UNISWAP_V2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public uniswapRouter;

    address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    string constant MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/HVFSJbF2lktX-HJntcTStYyuJg1orfYg";
    uint256 mainnetForkId;

    function setUp() public {
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        mainnetForkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetForkId);
        dexArbitrage = new DexArbitrage();
        uniswapRouter = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDR);

        vm.label(bob, "bob");
        vm.label(alice, "alice");
        vm.label(address(uniswapRouter), "uniswapRouter");
    }

    function testSwapToEth() public { }

    function testSwapFromEth() public { }

    function testSwapErc20() public { }

    function testMinProfit() public { }

    function testSwapEth() public {
        // deal(USDC_ADDR, bob, 10000 * 10 ** 6)
        console.log("bob balance", bob.balance);
        vm.deal(bob, 1 ether);
        console.log("bob balance", bob.balance);

        vm.startPrank(bob);
        address token0 = WETH_ADDR;
        address token1 = USDC_ADDR;
        address[] memory path = new address[](2);
        path[0] = address(token0);
        path[1] = address(token1);

        uniswapRouter.swapExactETHForTokens{ value: 1 ether }(0, path, bob, block.timestamp);
        // function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        //     external
        //     payable
        //     returns (uint[] memory amounts);
        console.log("=============== swap eth to usdc ===============");
        console.log("bob balance", bob.balance);
        console.log("bob usdc balance", ERC20(token1).balanceOf(bob)); // 1848_200463

        path[0] = address(token1);
        path[1] = address(token0);
        console.log("value", ERC20(token1).balanceOf(bob));
        console.log("allowend", IUSDT(token1).allowance(bob, address(uniswapRouter)));

        ERC20(token1).approve(address(uniswapRouter), 0);
        console.log("OZZ");
        ERC20(token1).approve(address(uniswapRouter), ERC20(token1).balanceOf(bob));
        // ERC20(token1).transfer(address(uniswapRouter), ERC20(token1).balanceOf(bob));
        // ERC20(token1).allowed(bob, address(uniswapRouter));
        // ERC20(token1).transferFrom(bob, address(uniswapRouter), ERC20(token1).balanceOf(bob));
        console.log("OOO");
        // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline)
        uniswapRouter.swapExactTokensForETH(ERC20(token1).balanceOf(bob), 0, path, bob, block.timestamp);

        console.log("=============== swap usdt to eth ===============");
        console.log("bob balance", bob.balance); // 0_994009406498583661
        console.log("bob usdc balance", ERC20(token1).balanceOf(bob));

        // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline)
        // external
        // override
        // ensure(deadline)
        // returns (uint[] memory amounts)

        vm.stopPrank();
    }

    function sortTokens(address tokenA, address tokenB) internal pure returns (address[] memory path) {
        require(tokenA != tokenB, "UniswapV2Library: IDENTICAL_ADDRESSES");
        path = new address[](2);
        (path[0], path[1]) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(path[0] != address(0), "UniswapV2Library: ZERO_ADDRESS");
    }
}
