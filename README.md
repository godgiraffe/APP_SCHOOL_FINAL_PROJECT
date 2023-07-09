# Final Project - Dex Arbitrage

## Description

- 在多個 Dex(UniSwapV2Router) 間進行價差套利
  - 例如：WETH 在 UniSwap 的價格為 1800 USDC, 在 SushiSwap 的價格為 1900 USDC, 合約會去 SushiSwap 買到低價的 WETH, 再到 UniSwap 賣出高價的 WETH 進行套利
- 可設定如果利潤沒有 > 多少, 則 revert
- contract owner 可再添加 dex
- (未來) 使用 proxy contract 讓合約能升級
- (未來) 計算池子深度 & 滑點, 判斷最大能用多少資金去套利
- (未來) 可使用閃電貸增加資金利用率
- 目前支援的 dex
  - UniSwap
  - Sushi Swap

## Framework

![](https://hackmd.io/_uploads/H1h0x_dKn.png)

User 可選擇使用 ETH 或 ERC20 token 發起套利：

- User 使用 ETH 的話，合約流程為：
  1. User transfer ETH to DexArbitrage
  2. DexArbitrage transfer ETH to DexCenter
  3. DexCenter 跟低價的 DexRouter 做 ETH swap to ERC20 (用 ETH 換比較低價的 ERC20)
  4. DexCenter 跟高價的 DexRouter 做 ERC20 swap to ETH (用比較高價的 ERC20 換回 ETH)
  5. DexCenter transfer ETH to User
- User 使用 ERC20 token 的話，合約流向為：
  1. User ERC20.approve(DexCenter, amount)
  2. DexCenter ERC20.transferFrom(user, DexCenter, amount)
  3. DexCenter 跟低價的 DexRouter 做 ERC20 swap to ERC20
  4. DexCenter 跟高價的 DexRouter 做 ERC20 swap to ERC20
  5. DexCenter transfer ERC20 to User

#### DexArbitrage

- 創建合約者 = owner
- 只有 owner 才能添加 Dex
- User 會跟此合約互動，可選擇使用 ETH / ERC20 token 進行套利
- 透過傳入不同 DexRouterAddress 給 DexCenter，決定要跟哪個 Router 互動

### DexCenter

- 此合約會根據傳入的參數, 去跟不同的 Router 進行 token swap, 並判斷是否要將 swap 後的 token 回傳給 user

## Development

1. clone repo:

```shell=
git clone https://github.com/godgiraffe/APP_SCHOOL_FINAL_PROJECT.git
```

2. 進入 `APP_SCHOOL_FINAL_PROJECT` 資料夾
3. forge install
4. 執行 `cp .env.example .env`
5. 填入 `.env` 中的`API_KEY_ALCHEMY`、`API_KEY_INFURA`

## Testing

```shell=
forge test --via-ir
```

![](https://hackmd.io/_uploads/rJ-7yuuKn.png)
目前有測試：

- 增加 Dex
- 選 2 個 dex, 進行 ERC20 → ERC20 → ERC20 的套利流程
- 選 2 個 dex, 進行 eth → ERC20 → eth 的套利
- DexArbitrage.arbitrage() 的各個 revert
- 每個 dex, 從 ERC20 swap to ERC20 的流程
- 每個 dex, ERC20 swap to eth 的流程
- 每個 dex, 從 eth swap to ERC20 的流程

## Usage
