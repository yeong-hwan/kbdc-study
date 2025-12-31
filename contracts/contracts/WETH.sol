// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Wrapped Ether (WETH)
 * @notice 테스트넷에서 ETH를 예치하면 동일 수량의 WETH(ERC-20)를 민팅하고,
 *         WETH를 소각하면 동일 수량의 ETH를 반환하는 래핑 컨트랙트입니다.
 *
 * @dev
 * - WETH는 1:1로 ETH에 페그됩니다.
 * - `deposit()` 또는 `receive()`로 ETH를 보내면 WETH가 민팅됩니다.
 * - `withdraw()`로 WETH를 소각하면 ETH가 전송됩니다.
 * - ERC-20 표준: balanceOf/allowance/transfer/approve/transferFrom 포함
 */
contract WETH {
    // ERC-20 메타데이터
    string public name = "Wrapped Ether";
    string public symbol = "WETH";
    uint8 public immutable decimals = 18;

    // ERC-20 상태
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // WETH 전용 이벤트 (WETH9와 유사)
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    // ERC-20 이벤트
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // 간단한 재진입 방지 락 (withdraw에서 ETH 전송이 있으므로 명시적으로 보호)
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    /**
     * @notice 컨트랙트로 ETH를 직접 보내도 deposit과 동일하게 동작합니다.
     */
    receive() external payable {
        deposit();
    }

    /**
     * @notice ETH를 예치하고 동일 수량의 WETH를 민팅합니다.
     */
    function deposit() public payable {
        require(msg.value > 0, "ZERO_DEPOSIT");
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice WETH를 소각하고 동일 수량의 ETH를 반환받습니다.
     * @param wad 출금할 WETH 수량(wei 단위, decimals=18)
     */
    function withdraw(uint256 wad) external nonReentrant {
        require(wad > 0, "ZERO_WITHDRAW");
        require(balanceOf[msg.sender] >= wad, "INSUFFICIENT_WETH");

        _burn(msg.sender, wad);
        emit Withdrawal(msg.sender, wad);

        // 상태 변경(소각) 이후 ETH 전송 -> 재진입 시에도 추가 인출 불가
        (bool ok, ) = msg.sender.call{value: wad}("");
        require(ok, "ETH_TRANSFER_FAILED");
    }

    /**
     * @notice ERC-20 approve
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @notice ERC-20 transfer
     */
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /**
     * @notice ERC-20 transferFrom
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "ALLOWANCE");

        // 무한 승인 패턴 지원: allowance가 type(uint256).max이면 감소시키지 않음
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "TO_ZERO");
        require(balanceOf[from] >= value, "BALANCE");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        require(to != address(0), "MINT_TO_ZERO");
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        require(balanceOf[from] >= value, "BURN_BALANCE");
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }
}


