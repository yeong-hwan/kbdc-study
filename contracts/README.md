## Contracts (공용 Hardhat 패키지)

여기는 week 과제들과 무관하게 재사용 가능한 **공용 Hardhat(컨트랙트/테스트/배포)** 패키지입니다.

### 환경 변수 준비
- `contracts/env.example`을 참고해서 `contracts/.env` 파일을 직접 만드세요.
  - (예시 파일은 커밋해도 되지만) 실제 `contracts/.env` 는 **절대 커밋하지 마세요.**

### 설치
```bash
pnpm -C contracts install
```

### 컴파일/테스트
```bash
pnpm -C contracts compile
pnpm -C contracts test
```

### Sepolia 배포
```bash
pnpm -C contracts deploy:sepolia
```



