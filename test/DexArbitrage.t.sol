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
    address public dexArbitrageOwner;
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

    // event
    event AddDex(uint8 indexed dexRouterCount, address indexed dexRouterAddress);

    function setUp() public { }

    function forkToNow() public {
        mainnetForkId = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetForkId);
        setAddrAndDeploy();
    }

    function forkToBlockNumber(uint256 blockNumber) public {
        vm.createSelectFork(MAINNET_RPC_URL, blockNumber);
        setAddrAndDeploy();
    }

    function setAddrAndDeploy() public {
        dexArbitrageOwner = makeAddr("dexArbitrageOwner");
        bob = makeAddr("bob");
        alice = makeAddr("alice");
        vm.startPrank(dexArbitrageOwner);
        dexArbitrage = new DexArbitrage();
        dexCenter = dexArbitrage.dexCenter();
        vm.stopPrank();

        vm.label(bob, "bob");
        vm.label(alice, "alice");
        vm.label(UNISWAP_V2_ROUTER_ADDR, "UNISWAP_V2_ROUTER_ADDR");
        vm.label(SUSHISWAP_V1_ROUTER_ADDR, "SUSHISWAP_V1_ROUTER_ADDR");
        vm.label(USDT_ADDR, "USDT");
        vm.label(USDC_ADDR, "USDC");
        vm.label(WETH_ADDR, "WETH");
        vm.label(LINK_ADDR, "LINK");
    }

    function testAddDex() public {
        forkToNow();
        vm.startPrank(bob);
        // 測試只有 dexArbitrageOwner 可以新增 dex
        vm.expectRevert("DexArbitrage: only owner");
        dexArbitrage.addDex(UNISWAP_V2_ROUTER_ADDR);
        vm.stopPrank();

        vm.startPrank(dexArbitrageOwner);
        // 測試不能新增重複的 dex
        uint8 dexRouterCount = dexArbitrage.dexRouterCount();
        address exitsDexRouterAddress = dexArbitrage.dexRouterAddress(dexRouterCount);
        vm.expectRevert("DexArbitrage: Dex already exists");
        dexArbitrage.addDex(exitsDexRouterAddress);

        // 測試新增 dex 成功
        address newRouterAddress = makeAddr("newRouterAddress");
        bool dexRouterCountAddSuccess = true;
        bool dexRouterAddressAddSuccess = true;
        vm.expectEmit(false, dexRouterCountAddSuccess, dexRouterAddressAddSuccess, false);
        emit AddDex(dexArbitrage.dexRouterCount(), newRouterAddress);
        dexArbitrage.addDex(newRouterAddress);
        vm.stopPrank();
    }

    // 測試每個 dex, 從 Erc-20 swap to eth
    function testErc20SwapToEth() public {
        forkToNow();
        uint256 initialBalance = 10_000 * 10 ** 6;
        address token0 = USDC_ADDR; // 這邊可以指定任意 ERC20
        IERC20 IERC20_token0 = IERC20(token0);

        vm.startPrank(address(dexCenter));
        for (uint256 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            deal(token0, address(dexCenter), initialBalance);
            (bool clearEth,) = address(0).call{ value: address(dexCenter).balance }("");
            assertEq(clearEth, true, "clear eth fail");
            assertEq(bob.balance, 0, "ETH InitialBalance Error");
            assertEq(IERC20_token0.balanceOf(address(dexCenter)), initialBalance, "ERC20 InitialBalance Error");

            // 測試每個 dex, 從 ERC20 swap to WETH
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            (bool success, uint256 tokenOutAmount) =
                dexCenter.swapToETH(token0, IERC20_token0.balanceOf(address(dexCenter)), dexRouterAddress);
            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
        }
        vm.stopPrank();
    }

    // 測試每個 dex, 從 eth swap to ERC20
    function testEthSwapToErc20() public {
        forkToNow();
        uint256 initialBalance = 1 ether;
        address token1 = USDC_ADDR; // 這邊可以指定任意 ERC20
        IERC20 IERC20_token1 = IERC20(token1);

        vm.startPrank(address(dexCenter));
        for (uint256 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            (bool clearEth,) = address(0).call{ value: address(dexCenter).balance }("");
            vm.deal(address(dexCenter), initialBalance);
            // 把 ERC20 送去 address(0) 會報錯, 所以就送給 alice 了
            if (IERC20_token1.balanceOf(address(dexCenter)) > 0) {
                IERC20_token1.transfer(alice, IERC20_token1.balanceOf(address(dexCenter)));
            }
            assertEq(address(dexCenter).balance, initialBalance, "ETH InitialBalance Error");
            assertEq(IERC20_token1.balanceOf(address(dexCenter)), 0, "ERC20 InitialBalance Error");

            // 測試每個 dex, 從 ETH swap to ERC20
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            assertEq(dexRouterAddress != address(0), true, "router address == 0");

            (bool success, uint256 tokenOutAmount) =
                dexCenter.swapFromETH{ value: address(dexCenter).balance }(token1, dexRouterAddress);

            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
            assertGt(IERC20_token1.balanceOf(address(dexCenter)), 0, "after swap, dexCenter ERC20 balance < 0");
            assertEq(
                tokenOutAmount,
                IERC20_token1.balanceOf(address(dexCenter)),
                "after swap, tokenOut Amount != dexCenter ERC20 balance"
            );
        }
        vm.stopPrank();
    }

    // 測試每個 dex, 從 ERC20 swap to ERC20
    function testErc20SwapToErc20() public {
        forkToNow();
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
            bytes memory data = abi.encode(true, bob);
            (bool success, uint256 tokenOutAmount) =
                dexCenter.swap(token0, IERC20_token0.balanceOf(bob), token1, dexRouterAddress, data);

            assertEq(success, true, "Swap Fail");
            assertGt(tokenOutAmount, 0, "after swap, tokenOut Amount < 0");
            assertGt(IERC20_token1.balanceOf(bob), 0, "after swap, user ERC20 balance < 0");
            assertEq(tokenOutAmount, IERC20_token1.balanceOf(bob), "after swap, tokenOut Amount != user ERC20 balance");
        }
    }

    // 測試套利行為, 隨機選 2 個 dex, 進行 ERC20 → ERC20 → ERC20 的套利
    function testArbitrageErc20() public {
        // uint256 blockNumber = 15_207_858;
        // forkToBlockNumber(blockNumber);
        forkToNow();
        address token0 = USDC_ADDR;
        address token1 = WETH_ADDR;
        uint8 hightPriceDexId;
        uint8 lowPriceDexId;
        uint256 hightPrice;
        uint256 lowePrice;
        uint256 initialBalance = 2000 * 10 ** 6;

        // console.log("block number", block.number);
        // 取得各 dex tokenA / tokenB 的價格, 取得高價/低價的 dexId
        (hightPriceDexId, lowPriceDexId, hightPrice, lowePrice) = getDexPairInfo(token1, token0);

        // console.log("lowPriceDexId", lowPriceDexId);
        // console.log("hightPrice", hightPrice);
        // console.log("hightPriceDexId", hightPriceDexId);
        // console.log("lowePrice", lowePrice);

        vm.startPrank(bob);
        deal(token0, bob, initialBalance);
        vm.deal(address(dexArbitrage), initialBalance); // 因為真的要花 gas = =, 所以要給他一點 eth
        // 進行套利: 用 token0 去 lowPriceDex 買 token1, 再去 hightPriceDex 賣 token1 換回 token0, 這樣 token0 就會變多
        /**
         * function swap(uint8 buyingDexId, address buyToken, uint256 buyAmount, address sellToken, uint8 sellingDexId,
         * bool isSwapEth, uint256 minProfitAmount)
         */
        IERC20(token0).approve(address(dexCenter), type(uint256).max);
        (bool arbitrageResult) =
            dexArbitrage.arbitrage(lowPriceDexId, token0, initialBalance, token1, hightPriceDexId, false, 0);
        // (bool arbitrageResult) = dexArbitrage.swap{ value: initialBalance }(
        //     lowPriceDexId, token0, initialBalance, token1, hightPriceDexId, true, 0
        // );
        assertEq(arbitrageResult, true, "arbitrageResult == false");
        vm.stopPrank();
    }

    // 測試套利行為, 隨機選 2 個 dex, 進行 eth → ERC20 → eth 的套利
    function testArbitrageEth() public {
        forkToNow();
        address token0 = WETH_ADDR;
        address token1 = LINK_ADDR;
        uint8 hightPriceDexId;
        uint8 lowPriceDexId;
        uint256 hightPrice;
        uint256 lowePrice;
        uint256 initialBalance = 1 * 10 ** 18;

        // console.log("block number", block.number);
        // 取得各 dex tokenA / tokenB 的價格, 取得高價/低價的 dexId
        (hightPriceDexId, lowPriceDexId, hightPrice, lowePrice) = getDexPairInfo(token1, token0);

        vm.startPrank(bob);
        vm.deal(bob, initialBalance);
        vm.deal(address(dexArbitrage), initialBalance); // 因為真的要花 gas = =, 所以要給 dexArbitrage 一點 eth
        // 進行套利: 用 token0 去 lowPriceDex 買 token1, 再去 hightPriceDex 賣 token1 換回 token0, 這樣 token0 就會變多
        (bool arbitrageResult) = dexArbitrage.arbitrage{ value: initialBalance }(
            lowPriceDexId, token0, initialBalance, token1, hightPriceDexId, true, 0
        );
        assertEq(arbitrageResult, true, "arbitrageResult == false");
        vm.stopPrank();
    }

    // 測試 arbitrage 的各個 revert
    function testArbitrageRevert() public {
        forkToNow();
        address token0 = USDC_ADDR;
        address token1 = WETH_ADDR;
        uint8 hightPriceDexId;
        uint8 lowPriceDexId;
        uint256 buyAmount = 2000 * 10 ** 6;

        hightPriceDexId = 1;
        lowPriceDexId = 1;
        vm.expectRevert("DexArbitrage: buyingDex is equal to sellingDex");
        (bool arbitrageResult) =
            dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, false, 0);

        hightPriceDexId = 1;
        lowPriceDexId = 2;
        token0 = WETH_ADDR;
        token1 = WETH_ADDR;
        vm.expectRevert("DexArbitrage: buyToken is equal to sellToken");
        arbitrageResult = dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, false, 0);

        hightPriceDexId = 1;
        lowPriceDexId = 2;
        token0 = WETH_ADDR;
        token1 = USDC_ADDR;
        buyAmount = 0;
        vm.expectRevert("DexArbitrage: buyAmount is zero");
        arbitrageResult = dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, false, 0);

        hightPriceDexId = 0;
        lowPriceDexId = 2;
        buyAmount = 2000 * 10 ** 6;
        vm.expectRevert("DexArbitrage: buyingDex or sellingDex is zero");
        arbitrageResult = dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, false, 0);

        hightPriceDexId = 1;
        lowPriceDexId = 0;
        vm.expectRevert("DexArbitrage: buyingDex or sellingDex is zero");
        arbitrageResult = dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, false, 0);

        token0 = USDC_ADDR;
        token1 = WETH_ADDR;
        hightPriceDexId = 1;
        lowPriceDexId = 2;
        buyAmount = 2000 * 10 ** 6;

        vm.startPrank(bob);
        deal(token0, bob, buyAmount);
        vm.deal(address(dexArbitrage), buyAmount); // 因為真的要花 gas = =, 所以要給他一點 eth
        vm.expectRevert("DexArbitrage: msg.value < buyAmount");
        arbitrageResult = dexArbitrage.arbitrage(lowPriceDexId, token0, buyAmount, token1, hightPriceDexId, true, 0);
        vm.stopPrank();
    }

    function testSwapEth() public {
        forkToNow();
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

    // 取得各 dex tokenA / tokenB 的價格, 取得高價/低價的 dexId
    function getDexPairInfo(
        address tokenA,
        address tokenB
    )
        public
        view
        returns (uint8 hightPriceDexId, uint8 lowPriceDexId, uint256 hightPrice, uint256 lowePrice)
    {
        address[] memory path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
        for (uint8 i = 1; i <= dexArbitrage.dexRouterCount(); i++) {
            address dexRouterAddress = dexArbitrage.dexRouterAddress(i);
            IUniswapV2Router02 dexRouter = IUniswapV2Router02(dexRouterAddress);
            uint256[] memory amounts = dexRouter.getAmountsOut(1 ether, path);

            if (amounts[1] > hightPrice) {
                hightPrice = amounts[1];
                hightPriceDexId = i;
            }

            if (amounts[1] < lowePrice || lowePrice == 0) {
                lowePrice = amounts[1];
                lowPriceDexId = i;
            }
        }
    }
}
