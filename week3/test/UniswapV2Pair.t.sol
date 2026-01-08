// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.5.16;

import {TestBase} from "./utils/TestBase.sol";

import {UniswapV2Factory} from "@uniswap/v2-core/contracts/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@uniswap/v2-core/contracts/UniswapV2Pair.sol";
import {ERC20} from "@uniswap/v2-core/contracts/test/ERC20.sol";
import {IERC20} from "@uniswap/v2-core/contracts/interfaces/IERC20.sol";

contract ReentrantCallee {
    UniswapV2Pair private pair;
    bool private entered;

    constructor(UniswapV2Pair _pair) public {
        pair = _pair;
    }

    // UniswapV2Pair.swap()에서 data.length > 0일 때 호출됨
    function uniswapV2Call(address, uint, uint, bytes calldata) external {
        // 콜백 중 재진입 시도 -> lock() 때문에 revert가 나야 함
        if (!entered) {
            entered = true;
            pair.skim(address(this));
        }
    }
}

contract UniswapV2PairTest is TestBase {
    UniswapV2Factory private factory;
    ERC20 private token0;
    ERC20 private token1;
    UniswapV2Pair private pair;

    address private constant FEE_TO = address(0xFEE);

    function setUp() public {
        factory = new UniswapV2Factory(address(this));

        // token0/token1 정렬이 예측 가능하도록 두 토큰을 순서대로 배치
        token0 = new ERC20(10**24);
        token1 = new ERC20(10**24);

        address pairAddr = factory.createPair(address(token0), address(token1));
        pair = UniswapV2Pair(pairAddr);

        // pair.token0()/token1() 기준으로 테스트의 token0/token1을 정렬해둔다 (실수 방지)
        if (pair.token0() != address(token0)) {
            ERC20 tmp = token0;
            token0 = token1;
            token1 = tmp;
        }
    }

    function test_mint_initial_locks_minimum_liquidity() public {
        // sqrt(amount0*amount1) - MINIMUM_LIQUIDITY > 0 이어야 mint가 성공
        _addLiquidity(10_000, 10_000, address(this));

        // MINIMUM_LIQUIDITY(1e3)는 address(0)으로 영구 락
        assertEq(pair.balanceOf(address(0)), 1000, "minimum liquidity should be locked");
        assertGt(pair.totalSupply(), 1000, "totalSupply should be > MINIMUM_LIQUIDITY");
    }

    function test_mint_revert_insufficient_liquidity() public {
        // sqrt(1*1) - 1000 < 0 이므로 revert
        _transfer(address(token0), address(pair), 1);
        _transfer(address(token1), address(pair), 1);
        vm.expectRevert();
        pair.mint(address(this));
    }

    function test_burn_returns_pro_rata() public {
        _addLiquidity(10_000, 20_000, address(this));

        // 일부 LP를 pair로 보내고 burn
        uint liquidity = pair.balanceOf(address(this)) / 2;
        require(pair.transfer(address(pair), liquidity), "lp transfer failed");

        (uint amount0, uint amount1) = pair.burn(address(this));
        assertTrue(amount0 > 0 && amount1 > 0, "burn amounts should be > 0");

        // burn 후 pair의 토큰 잔고는 리저브와 일치해야 함 (update 수행)
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(IERC20(address(token0)).balanceOf(address(pair)), uint(r0), "balance0 == reserve0");
        assertEq(IERC20(address(token1)).balanceOf(address(pair)), uint(r1), "balance1 == reserve1");
    }

    function test_swap_exact_in_token0_for_token1() public {
        _addLiquidity(10_000, 10_000, address(this));

        (uint112 r0, uint112 r1,) = pair.getReserves();

        // token0를 input으로 넣고 token1 output을 받는 케이스
        uint amountIn = 1000;
        _transfer(address(token0), address(pair), amountIn);

        // UniswapV2Library의 공식과 동일 (997/1000 수수료)
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * uint(r1);
        uint denominator = uint(r0) * 1000 + amountInWithFee;
        uint amountOut = numerator / denominator;

        uint bal1Before = token1.balanceOf(address(this));
        pair.swap(0, amountOut, address(this), new bytes(0));
        uint bal1After = token1.balanceOf(address(this));

        assertEq(bal1After - bal1Before, amountOut, "token1 out should match");

        // swap 이후 리저브 업데이트 확인
        (uint112 r0After, uint112 r1After,) = pair.getReserves();
        assertEq(uint(r0After), uint(r0) + amountIn, "reserve0 should increase by amountIn");
        assertEq(uint(r1After), uint(r1) - amountOut, "reserve1 should decrease by amountOut");
    }

    function test_swap_revert_invalid_to() public {
        _addLiquidity(10_000, 10_000, address(this));
        vm.expectRevert(_revertReason("UniswapV2: INVALID_TO"));
        pair.swap(0, 1, address(token0), new bytes(0));
    }

    function test_swap_revert_insufficient_output() public {
        _addLiquidity(10_000, 10_000, address(this));
        vm.expectRevert(_revertReason("UniswapV2: INSUFFICIENT_OUTPUT_AMOUNT"));
        pair.swap(0, 0, address(this), new bytes(0));
    }

    function test_swap_revert_insufficient_liquidity() public {
        _addLiquidity(10_000, 10_000, address(this));
        vm.expectRevert(_revertReason("UniswapV2: INSUFFICIENT_LIQUIDITY"));
        pair.swap(0, 10_000, address(this), new bytes(0));
    }

    function test_swap_revert_insufficient_input() public {
        _addLiquidity(10_000, 10_000, address(this));
        // input 없이 output만 시도
        vm.expectRevert(_revertReason("UniswapV2: INSUFFICIENT_INPUT_AMOUNT"));
        pair.swap(0, 1, address(this), new bytes(0));
    }

    function test_lock_reentrancy_guard() public {
        _addLiquidity(10_000, 10_000, address(this));

        // reentrant callee가 콜백에서 skim 호출 -> LOCKED revert 기대
        ReentrantCallee callee = new ReentrantCallee(pair);

        // 콜백이 실행되도록 data.length > 0로 호출
        // output을 아주 작게 주고, 그 전에 input을 넣어서 swap이 진행되게 만든다.
        _transfer(address(token0), address(pair), 1000);

        vm.expectRevert(_revertReason("UniswapV2: LOCKED"));
        pair.swap(0, 1, address(callee), abi.encodePacked(uint8(1)));
    }

    function test_skim_sends_excess_balance() public {
        _addLiquidity(10_000, 10_000, address(this));

        // pair에 추가로 토큰을 보내서 excess 만들기
        _transfer(address(token0), address(pair), 1234);

        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint bal0Before = token0.balanceOf(address(this));
        pair.skim(address(this));
        uint bal0After = token0.balanceOf(address(this));

        // skim 후 pair의 token0 잔고는 reserve0로 맞춰져야 함
        assertEq(IERC20(address(token0)).balanceOf(address(pair)), uint(r0), "pair balance0 should equal reserve0");
        assertEq(uint(bal0After - bal0Before), 1234, "skim should transfer excess");

        // token1은 변화 없어야 함(여기서는 excess를 만들지 않았으므로)
        assertEq(IERC20(address(token1)).balanceOf(address(pair)), uint(r1), "pair balance1 should equal reserve1");
    }

    function test_sync_updates_reserves_to_balances() public {
        _addLiquidity(10_000, 10_000, address(this));

        // 잔고만 늘리고 sync로 리저브를 따라가게 한다
        _transfer(address(token0), address(pair), 111);
        _transfer(address(token1), address(pair), 222);

        pair.sync();
        (uint112 r0, uint112 r1,) = pair.getReserves();
        assertEq(uint(r0), 10_000 + 111, "reserve0 should match balance0");
        assertEq(uint(r1), 10_000 + 222, "reserve1 should match balance1");
    }

    function test_priceCumulative_increases_over_time() public {
        _addLiquidity(10_000, 20_000, address(this));

        uint p0 = pair.price0CumulativeLast();
        uint p1 = pair.price1CumulativeLast();

        // 같은 블록이면 누적이 안 되므로 시간 이동 후 sync
        vm.warp(block.timestamp + 10);
        pair.sync();

        assertGt(pair.price0CumulativeLast(), p0, "price0 cumulative should increase");
        assertGt(pair.price1CumulativeLast(), p1, "price1 cumulative should increase");
    }

    function test_feeOn_mints_to_feeTo_on_growth() public {
        // feeOn 켜기
        factory.setFeeTo(FEE_TO);

        // totalSupply가 너무 작으면(예: 10_000) rootK 증가가 1이어도 0으로 떨어질 수 있음
        // 그래서 초기 유동성을 크게 잡아 feeTo mint가 0이 되지 않게 한다.
        _addLiquidity(1_000_000, 1_000_000, address(this));
        uint feeToBefore = pair.balanceOf(FEE_TO);

        // swap으로 수수료가 쌓여 k가 성장하도록 만든다
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint amountIn = 100_000;
        _transfer(address(token0), address(pair), amountIn);
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * uint(r1);
        uint denominator = uint(r0) * 1000 + amountInWithFee;
        uint amountOut = numerator / denominator;
        pair.swap(0, amountOut, address(this), new bytes(0));

        // 추가 유동성 공급으로 _mintFee 트리거
        _transfer(address(token0), address(pair), 100_000);
        _transfer(address(token1), address(pair), 100_000);
        pair.mint(address(this));

        uint feeToAfter = pair.balanceOf(FEE_TO);
        assertTrue(feeToAfter >= feeToBefore, "feeTo LP should not decrease");
        assertTrue(feeToAfter > 0, "feeTo should receive some LP when fee is on and k grew");
    }

    // -----------------------
    // Helpers
    // -----------------------

    function _addLiquidity(uint amount0, uint amount1, address to) private {
        _transfer(address(token0), address(pair), amount0);
        _transfer(address(token1), address(pair), amount1);
        pair.mint(to);
    }

    function _transfer(address token, address to, uint amount) private {
        require(IERC20(token).transfer(to, amount), "transfer failed");
    }

    function _revertReason(string memory reason) private pure returns (bytes memory) {
        // 표준 revert(string) ABI: Error(string)
        return abi.encodeWithSignature("Error(string)", reason);
    }
}


