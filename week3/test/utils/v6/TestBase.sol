// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;

import {Vm} from "./Vm.sol";

/// @notice forge-std 없이도 기본 assert/cheatcode를 쓰기 위한 베이스(0.6.6)
contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool condition, string memory message) internal pure {
        require(condition, message);
    }

    function assertEq(uint256 a, uint256 b, string memory message) internal pure {
        require(a == b, message);
    }

    function assertEq(address a, address b, string memory message) internal pure {
        require(a == b, message);
    }
}


