// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;

import {TestBase} from "./utils/v6/TestBase.sol";
import {UniswapV2Library} from "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

/// @notice UniswapV2Library는 대부분 internal 이라 wrapper로 외부에서 호출 가능하게 만든다.
contract UniswapV2LibraryWrapper {
    function sortTokens(address tokenA, address tokenB) external pure returns (address token0, address token1) {
        return UniswapV2Library.sortTokens(tokenA, tokenB);
    }

    function pairFor(address factory, address tokenA, address tokenB) external pure returns (address pair) {
        return UniswapV2Library.pairFor(factory, tokenA, tokenB);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountOut) {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut) external pure returns (uint256 amountIn) {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getReserves(address factory, address tokenA, address tokenB) external view returns (uint256 reserveA, uint256 reserveB) {
        return UniswapV2Library.getReserves(factory, tokenA, tokenB);
    }

    function getAmountsOut(address factory, uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(address factory, uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }
}

/// @notice pairFor로 계산된 주소에 "심을" mock pair
/// @dev UniswapV2Library는 IUniswapV2Pair.getReserves()만 호출하므로 그 시그니처만 맞추면 됨
contract PairMock {
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    function setReserves(uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
        blockTimestampLast = _blockTimestampLast;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }
}

contract UniswapV2LibraryTest is TestBase {
    UniswapV2LibraryWrapper private wrapper;

    function setUp() public {
        wrapper = new UniswapV2LibraryWrapper();
    }

    function test_sortTokens_revert_identical() public {
        vm.expectRevert();
        wrapper.sortTokens(address(0xBEEF), address(0xBEEF));
    }

    function test_sortTokens_revert_zero() public {
        vm.expectRevert();
        wrapper.sortTokens(address(0), address(0xBEEF));
    }

    function test_sortTokens_orders() public {
        (address token0, address token1) = wrapper.sortTokens(address(0xBEEF), address(0xCAFE));
        assertEq(token0, address(0xBEEF), "token0 should be lower address");
        assertEq(token1, address(0xCAFE), "token1 should be higher address");
    }

    function test_quote_revert_amount_zero() public {
        vm.expectRevert();
        wrapper.quote(0, 10, 10);
    }

    function test_quote_revert_reserve_zero() public {
        vm.expectRevert();
        wrapper.quote(1, 0, 10);
    }

    function test_quote_basic() public {
        uint256 out = wrapper.quote(2, 10, 25);
        assertEq(out, 5, "quote should be proportional");
    }

    function test_getAmountOut_revert_amount_zero() public {
        vm.expectRevert();
        wrapper.getAmountOut(0, 10, 10);
    }

    function test_getAmountOut_revert_liquidity_zero() public {
        vm.expectRevert();
        wrapper.getAmountOut(1, 0, 10);
    }

    function test_getAmountOut_basic() public {
        // 수수료(0.3%) 반영: amountInWithFee = 100*997
        uint256 out = wrapper.getAmountOut(100, 1000, 1000);
        assertTrue(out > 0, "amountOut should be > 0");
        assertTrue(out < 100, "with fee, out should be < amountIn for symmetric reserves");
    }

    function test_getAmountIn_revert_amount_zero() public {
        vm.expectRevert();
        wrapper.getAmountIn(0, 10, 10);
    }

    function test_getAmountIn_revert_liquidity_zero() public {
        vm.expectRevert();
        wrapper.getAmountIn(1, 0, 10);
    }

    function test_pairFor_is_symmetric() public {
        address factory = address(0xFACADE);
        address tokenA = address(0xBEEF);
        address tokenB = address(0xCAFE);
        address p1 = wrapper.pairFor(factory, tokenA, tokenB);
        address p2 = wrapper.pairFor(factory, tokenB, tokenA);
        assertEq(p1, p2, "pairFor should ignore token order");
    }

    function test_getReserves_works_with_etched_pair() public {
        // 핵심 아이디어:
        // - pairFor(factory, A, B)로 '페어 주소'를 계산
        // - vm.etch로 그 주소에 mock pair 런타임코드를 심고
        // - setReserves 호출로 리저브를 세팅
        // - UniswapV2Library.getReserves가 올바르게 정렬/리턴하는지 확인
        address factory = address(0xFACADE);
        address tokenA = address(0xBEEF);
        address tokenB = address(0xCAFE);

        address pair = wrapper.pairFor(factory, tokenA, tokenB);

        PairMock impl = new PairMock();
        bytes memory code = _getRuntimeCode(address(impl));
        vm.etch(pair, code);

        // tokenA(0xBEEF) < tokenB(0xCAFE)이므로 token0 = A
        PairMock(pair).setReserves(111, 222, 1);

        (uint256 reserveA, uint256 reserveB) = wrapper.getReserves(factory, tokenA, tokenB);
        assertEq(reserveA, 111, "reserveA should map to tokenA");
        assertEq(reserveB, 222, "reserveB should map to tokenB");

        (uint256 reserveB2, uint256 reserveA2) = wrapper.getReserves(factory, tokenB, tokenA);
        assertEq(reserveB2, 222, "reserveB should map to tokenB");
        assertEq(reserveA2, 111, "reserveA should map to tokenA");
    }

    function test_getAmountsOut_revert_invalid_path() public {
        address[] memory path = new address[](1);
        path[0] = address(0xBEEF);
        vm.expectRevert();
        wrapper.getAmountsOut(address(0xFACADE), 1, path);
    }

    function test_getAmountsIn_revert_invalid_path() public {
        address[] memory path = new address[](1);
        path[0] = address(0xBEEF);
        vm.expectRevert();
        wrapper.getAmountsIn(address(0xFACADE), 1, path);
    }

    function test_getAmountsOut_two_hops_with_etched_pairs() public {
        address factory = address(0xFACADE);
        address tokenA = address(0xBEEF);
        address tokenB = address(0xCAFE);
        address tokenC = address(0xD00D);

        // A-B 페어 심기
        address pairAB = wrapper.pairFor(factory, tokenA, tokenB);
        // B-C 페어 심기
        address pairBC = wrapper.pairFor(factory, tokenB, tokenC);

        PairMock impl = new PairMock();
        bytes memory code = _getRuntimeCode(address(impl));
        vm.etch(pairAB, code);
        vm.etch(pairBC, code);

        // 리저브는 token 주소 정렬(token0/token1)에 맞춰 넣는다.
        // A(0xBEEF) < B(0xCAFE)
        PairMock(pairAB).setReserves(1000, 2000, 1);
        // B(0xCAFE) < C(0xD00D)
        PairMock(pairBC).setReserves(3000, 6000, 1);

        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = tokenC;

        uint256[] memory amounts = wrapper.getAmountsOut(factory, 100, path);
        assertEq(amounts.length, 3, "amounts length");
        assertEq(amounts[0], 100, "amounts[0]");

        // 내부적으로 getAmountOut를 2번 적용한 값과 동일해야 함
        uint256 outAB = wrapper.getAmountOut(100, 1000, 2000);
        uint256 outBC = wrapper.getAmountOut(outAB, 3000, 6000);
        assertEq(amounts[1], outAB, "amounts[1] should equal hop1 out");
        assertEq(amounts[2], outBC, "amounts[2] should equal hop2 out");
    }

    function test_getAmountsIn_two_hops_with_etched_pairs() public {
        address factory = address(0xFACADE);
        address tokenA = address(0xBEEF);
        address tokenB = address(0xCAFE);
        address tokenC = address(0xD00D);

        address pairAB = wrapper.pairFor(factory, tokenA, tokenB);
        address pairBC = wrapper.pairFor(factory, tokenB, tokenC);

        PairMock impl = new PairMock();
        bytes memory code = _getRuntimeCode(address(impl));
        vm.etch(pairAB, code);
        vm.etch(pairBC, code);

        PairMock(pairAB).setReserves(1000, 2000, 1);
        PairMock(pairBC).setReserves(3000, 6000, 1);

        address[] memory path = new address[](3);
        path[0] = tokenA;
        path[1] = tokenB;
        path[2] = tokenC;

        uint256 desiredOut = 50;
        uint256[] memory amounts = wrapper.getAmountsIn(factory, desiredOut, path);
        assertEq(amounts.length, 3, "amounts length");
        assertEq(amounts[2], desiredOut, "amounts[last] should equal desiredOut");

        uint256 inBC = wrapper.getAmountIn(desiredOut, 3000, 6000);
        uint256 inAB = wrapper.getAmountIn(inBC, 1000, 2000);
        assertEq(amounts[1], inBC, "amounts[1] should be required for hop2");
        assertEq(amounts[0], inAB, "amounts[0] should be required for hop1");
    }

    function _getRuntimeCode(address target) private view returns (bytes memory code) {
        assembly {
            let size := extcodesize(target)
            code := mload(0x40)
            mstore(code, size)
            extcodecopy(target, add(code, 0x20), 0, size)
            mstore(0x40, add(add(code, 0x20), size))
        }
    }
}


