// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.5.16;

/// @notice Foundry/Hevm cheatcode 인터페이스(최소 subset)
/// @dev forge-std 없이도 expectRevert/warp 등을 쓰기 위해 직접 정의
interface Vm {
    function warp(uint256 newTimestamp) external;

    function expectRevert(bytes calldata revertData) external;
    function expectRevert(bytes4 revertSelector) external;
    function expectRevert() external;
}


