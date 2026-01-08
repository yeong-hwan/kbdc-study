// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;

/// @notice Foundry/Hevm cheatcode 인터페이스(0.6.6용, 최소 subset)
interface Vm {
    function warp(uint256 newTimestamp) external;

    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertSelector) external;
    function expectRevert() external;

    // 임의 주소에 런타임 코드를 덮어쓰기 (pairFor로 계산된 주소에 mock pair를 심는 용도)
    function etch(address where, bytes calldata code) external;
}


