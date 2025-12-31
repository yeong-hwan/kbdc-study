## 2주차: Wrapped Ether (WETH) 구현

### 목표
- **테스트넷에 ETH 예치(deposit) → 동일 수량의 WETH 민팅**
- **WETH 소각(withdraw) → 동일 수량의 ETH 반환**

구현 컨트랙트: `contracts/contracts/WETH.sol`

---

## Hardhat로 Sepolia 배포/테스트 (권장)

### 0) 환경 변수 준비
- `contracts/env.example`을 참고해서 `contracts/.env` 파일을 직접 만드세요.
  - **주의**: `.env`에는 private key가 들어가므로 절대 커밋하지 마세요.

### 1) 의존성 설치
```bash
pnpm -C contracts install
```

### 2) 로컬 테스트
```bash
pnpm -C contracts test
```

### 3) Sepolia 배포
```bash
pnpm -C contracts deploy:sepolia
```

배포 후 출력되는 컨트랙트 주소를 기록하세요.

---

## 컨트랙트 설계 요약
- `deposit()` / `receive()`:
  - `msg.value` 만큼 WETH 민팅
  - `Deposit` 이벤트 발생
- `withdraw(wad)`:
  - `wad` 만큼 WETH 소각
  - ETH를 `call`로 전송
  - `Withdrawal` 이벤트 발생
