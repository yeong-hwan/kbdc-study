# KBDC Study - Week 3 (Uniswap V2 테스트)

3주차 과제는 Uniswap V2의 `@v2-core`, `@v2-periphery` 코드를 **import(remapping)** 해서,
일반적인 케이스와 엣지 케이스를 고려한 **Foundry 테스트 케이스를 작성**하는 것입니다.

## 실행 방법

```bash
cd kbdc-study/week3
forge test
```

## Import 구조 (핵심)

- `foundry.toml`의 remapping으로 로컬 소스를 import 합니다.
  - `@uniswap/v2-core/=../../v2-core/`
  - `@uniswap/v2-periphery/=../../v2-periphery/`
- `v2-core(0.5.16)` + `v2-periphery(0.6.6)`가 섞여 있어서 `auto_detect_solc = true`로 pragma 기반 멀티 컴파일을 사용합니다.

## 테스트 대상 파일

- **Core**
  - `@uniswap/v2-core/contracts/UniswapV2Pair.sol`
- **Periphery**
  - `@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol`

## 테스트 목록 (한눈에 보기)

### `test/UniswapV2Library.t.sol` (17 tests)

> `UniswapV2Library`는 대부분 `internal`이라 `UniswapV2LibraryWrapper`로 외부 호출이 가능하게 만든 후 테스트합니다.  
> `getReserves/getAmounts{In,Out}`는 `pairFor()`로 계산되는 주소에 `vm.etch`로 `PairMock` 런타임 코드를 심어서 검증합니다.

- **sortTokens**
  - `test_sortTokens_revert_identical`: 동일 주소 입력 revert
  - `test_sortTokens_revert_zero`: zero address 포함 revert
  - `test_sortTokens_orders`: 주소 오름차순 정렬 확인
- **quote**
  - `test_quote_revert_amount_zero`: amountA=0 revert
  - `test_quote_revert_reserve_zero`: reserve=0 revert
  - `test_quote_basic`: 비율 계산 정상 동작
- **getAmountOut**
  - `test_getAmountOut_revert_amount_zero`: amountIn=0 revert
  - `test_getAmountOut_revert_liquidity_zero`: reserve=0 revert
  - `test_getAmountOut_basic`: 수수료(0.3%) 반영 결과 sanity check
- **getAmountIn**
  - `test_getAmountIn_revert_amount_zero`: amountOut=0 revert
  - `test_getAmountIn_revert_liquidity_zero`: reserve=0 revert
- **pairFor**
  - `test_pairFor_is_symmetric`: (A,B)와 (B,A)가 동일 pair 주소인지 확인
- **getReserves / getAmountsOut / getAmountsIn**
  - `test_getReserves_works_with_etched_pair`: `vm.etch`로 심은 mock pair의 reserve를 정렬해 반환하는지
  - `test_getAmountsOut_revert_invalid_path`: path 길이 < 2 revert
  - `test_getAmountsIn_revert_invalid_path`: path 길이 < 2 revert
  - `test_getAmountsOut_two_hops_with_etched_pairs`: 2-hop 경로 amountsOut 체인 계산 검증
  - `test_getAmountsIn_two_hops_with_etched_pairs`: 2-hop 경로 amountsIn 역산 검증

### `test/UniswapV2Pair.t.sol` (13 tests)

> Factory로 pair를 만들고, core의 `contracts/test/ERC20.sol`을 토큰으로 사용합니다.  
> 재진입 가드는 `swap(..., data!=0)` 콜백(`uniswapV2Call`)로 lock revert를 유도해 검증합니다.

- **mint**
  - `test_mint_initial_locks_minimum_liquidity`: 초기 mint 시 `MINIMUM_LIQUIDITY`가 `address(0)`로 락되는지
  - `test_mint_revert_insufficient_liquidity`: 너무 작은 초기 유동성에서 revert
- **burn**
  - `test_burn_returns_pro_rata`: LP를 pair로 보낸 뒤 burn 시 pro-rata 분배 + reserve==balance 업데이트 확인
- **swap (정상/리버트)**
  - `test_swap_exact_in_token0_for_token1`: exact-in 스왑 amountOut 계산/리저브 업데이트 검증
  - `test_swap_revert_invalid_to`: `to`가 token0/token1이면 revert
  - `test_swap_revert_insufficient_output`: output=0/0 revert
  - `test_swap_revert_insufficient_liquidity`: 리저브 초과 output revert
  - `test_swap_revert_insufficient_input`: input 없이 output만 시도하면 revert
- **reentrancy lock**
  - `test_lock_reentrancy_guard`: 콜백에서 `skim` 재진입 시 `LOCKED` revert
- **skim / sync**
  - `test_skim_sends_excess_balance`: excess balance를 외부로 보내고 잔고가 reserve로 맞춰지는지
  - `test_sync_updates_reserves_to_balances`: balance 변화 후 `sync()`로 reserve가 따라가는지
- **price cumulative**
  - `test_priceCumulative_increases_over_time`: 시간 경과 후 `sync()`로 누적 가격이 증가하는지
- **protocol fee (feeOn)**
  - `test_feeOn_mints_to_feeTo_on_growth`: `feeTo` 설정 후 k 성장 + 다음 mint에서 `feeTo`로 LP mint되는지


