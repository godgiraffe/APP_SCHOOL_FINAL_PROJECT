// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
// import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { DexArbitrage } from "../src/DexArbitrage/DexArbitrage.sol";
import { DexCenter } from "../src/DexArbitrage/DexCenter.sol";

contract DexArbitrageTest is Test {
    DexArbitrage public dexArbitrage;
    address public bob;
    address public alice;
    address public constant UNISWAP_V2_ROUTER_ADDR = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address public constant SUSHISWAP_V1_ROUTER_ADDR = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    IUniswapV2Router02 public uniswapRouter;
    DexCenter public dexCenter;

    address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC_ADDR = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH_ADDR = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC_ADDR = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant SHIB_ADDR = 0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE;
    address constant UNI_ADDR = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant LDO_ADDR = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address constant APE_ADDR = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;
    address constant LINK_ADDR = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant WSTETH_ADDR = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    string constant MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/HVFSJbF2lktX-HJntcTStYyuJg1orfYg";
    uint256 mainnetForkId;

    function setUp() public {
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        mainnetForkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetForkId);
        dexArbitrage = new DexArbitrage();
        dexCenter = dexArbitrage.dexCenter();

        vm.label(bob, "bob");
        vm.label(alice, "alice");
        vm.label(UNISWAP_V2_ROUTER_ADDR, "UNISWAP_V2_ROUTER_ADDR");
        vm.label(SUSHISWAP_V1_ROUTER_ADDR, "SUSHISWAP_V1_ROUTER_ADDR");
        vm.label(USDT_ADDR, "USDT");
        vm.label(USDC_ADDR, "USDC");
        vm.label(WETH_ADDR, "WETH");
    }

    // 測試每個 dex, 從 Erc-20 swap to eth
    function testErc20SwapToEth() public {
        uint256 initialBalance = 10_000 * 10 ** 6;
        address token0 = USDC_ADDR; // 這邊可以指定任意 ERC20
        IERC20 IERC20_token0 = IERC20(token0);

        vm.startPrank(bob);
        for (uint256 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            deal(token0, bob, initialBalance);
            (bool clearEth,) = address(0).call{ value: bob.balance }("");
            assertEq(clearEth, true, "clear eth fail");
            assertEq(bob.balance, 0, "ETH InitialBalance Error");
            assertEq(IERC20_token0.balanceOf(bob), initialBalance, "ERC20 InitialBalance Error");

            // 測試每個 dex, 從 ERC20 swap to WETH
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            assertEq(dexRouterAddress != address(0), true, "router address == 0");

            // USDT 的話，要先 approve 給 0, 其它 ERC20 的話，就正常 approve
            if (token0 == USDT_ADDR) IERC20_token0.approve(address(dexCenter), 0);
            IERC20_token0.approve(address(dexCenter), IERC20_token0.balanceOf(bob));
            (bool success, uint256 tokenOutAmount) =
                dexCenter.swapToETH(token0, IERC20_token0.balanceOf(bob), dexRouterAddress);

            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
            assertGt(bob.balance, 0, "after swap, user balance < 0");
        }
        vm.stopPrank();
    }

    // 測試每個 dex, 從 eth swap to ERC20
    function testEthSwapToErc20() public {
        uint256 initialBalance = 1 ether;
        address token1 = USDC_ADDR; // 這邊可以指定任意 ERC20
        IERC20 IERC20_token1 = IERC20(token1);

        vm.startPrank(bob);
        for (uint256 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            (bool clearEth,) = address(0).call{ value: bob.balance }("");
            vm.deal(bob, initialBalance);
            // 把 ERC20 送去 address(0) 會報錯, 所以就送給 alice 了
            if (IERC20_token1.balanceOf(bob) > 0) IERC20_token1.transfer(alice, IERC20_token1.balanceOf(bob));
            assertEq(bob.balance, initialBalance, "ETH InitialBalance Error");
            assertEq(IERC20_token1.balanceOf(bob), 0, "ERC20 InitialBalance Error");

            // 測試每個 dex, 從 ETH swap to ERC20
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            assertEq(dexRouterAddress != address(0), true, "router address == 0");

            (bool success, uint256 tokenOutAmount) =
                dexCenter.swapFromETH{ value: bob.balance }(token1, dexRouterAddress);

            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
            assertGt(IERC20_token1.balanceOf(bob), 0, "after swap, user ERC20 balance < 0");
            assertEq(tokenOutAmount, IERC20_token1.balanceOf(bob), "after swap, tokenOut Amount != user ERC20 balance");
        }
    }

    // 測試每個 dex, 從 ERC20 swap to ERC20
    function testErc20SwapToErc20() public {
        uint256 initialBalance = 1_000_000;
        // toke0、token1 可以指定任意 ERC20 (但 v2 有池子)
        address token0 = WETH_ADDR;
        address token1 = LINK_ADDR;
        IERC20 IERC20_token0 = IERC20(token0);
        IERC20 IERC20_token1 = IERC20(token1);

        vm.startPrank(bob);
        for (uint256 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            deal(token0, bob, initialBalance);
            // 把 ERC20 送去 address(0) 會報錯, 所以就送給 alice 了
            if (IERC20_token1.balanceOf(bob) > 0) IERC20_token1.transfer(alice, IERC20_token1.balanceOf(bob));
            assertEq(IERC20_token0.balanceOf(bob), initialBalance, "token0 InitialBalance Error");
            assertEq(IERC20_token1.balanceOf(bob), 0, "token1 InitialBalance Error");

            // 測試每個 dex, 從 ERC20 swap to ERC20
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            assertEq(dexRouterAddress != address(0), true, "router address == 0");

            // USDT 的話，要先 approve 給 0, 其它 ERC20 的話，就正常 approve
            if (token0 == USDT_ADDR) IERC20_token0.approve(address(dexCenter), 0);
            IERC20_token0.approve(address(dexCenter), IERC20_token0.balanceOf(bob));
            (bool success, uint256 tokenOutAmount) =
                dexCenter.swap(token0, IERC20_token0.balanceOf(bob), token1, dexRouterAddress);

            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
            assertGt(IERC20_token1.balanceOf(bob), 0, "after swap, user ERC20 balance < 0");
            assertEq(tokenOutAmount, IERC20_token1.balanceOf(bob), "after swap, tokenOut Amount != user ERC20 balance");
        }
    }

    // 測試套利行為, 隨機選 2 個 dex, 進行 ERC20 → ERC20 → ERC20 的套利
    function testArbitrageErc20() public { }

    // 測試套利行為, 隨機選 2 個 dex, 進行 ERC20 → eth → ERC20 的套利
    function testArbitrageEth() public { }

    function testSwapEth() public {
        // deal(USDC_ADDR, bob, 10_000 * 10 ** 6)
        uniswapRouter = IUniswapV2Router02(UNISWAP_V2_ROUTER_ADDR);
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
        console.log("bob usdc balance", IERC20(token1).balanceOf(bob)); // 1848_200463

        path[0] = address(token1);
        path[1] = address(token0);
        console.log("value", IERC20(token1).balanceOf(bob));

        console.log("OZZ");
        IERC20(token1).approve(address(uniswapRouter), IERC20(token1).balanceOf(bob));
        // IERC20(token1).transfer(address(uniswapRouter), IERC20(token1).balanceOf(bob));
        // IERC20(token1).allowed(bob, address(uniswapRouter));
        // IERC20(token1).transferFrom(bob, address(uniswapRouter), IERC20(token1).balanceOf(bob));
        console.log("OOO");
        // function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint
        // deadline)
        uniswapRouter.swapExactTokensForETH(IERC20(token1).balanceOf(bob), 0, path, bob, block.timestamp);

        console.log("=============== swap usdt to eth ===============");
        console.log("bob balance", bob.balance); // 0_994009406498583661
        console.log("bob usdc balance", IERC20(token1).balanceOf(bob));

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
