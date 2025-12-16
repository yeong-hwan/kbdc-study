# Week1 - EIP-1193 기반 Web3 로그인 (Next.js + TypeScript)

간단한 SIWE 스타일의 로그인 데모입니다. MetaMask(혹은 EIP-1193 Provider)를 이용해 서버가 제공하는 메시지에 서명하고, 서버는 서명을 검증한 뒤 httpOnly JWT 쿠키를 발급합니다.

> 이 리포지토리는 pnpm workspace(루트)에서 패키지를 관리합니다. 루트에서 설치/실행하는 것을 권장합니다.

## 빠른 시작

1) 의존성 설치

```bash
pnpm install           # 루트에서 실행(추천)
# 또는 개별 패키지 디렉터리에서 실행해도 루트 lockfile이 사용됩니다.
```

2) 개발 서버 실행

```bash
pnpm dev:week1         # 루트에서 실행
# 또는
pnpm -C week1 dev      # 디렉터리 지정 실행
```

3) 브라우저에서 접속  
`http://localhost:3000`

## 환경변수

선택 사항:
- `JWT_SECRET`: JWT 서명 시크릿 문자열 (기본값: `dev-secret-change-me`)

## 구조

- `app/page.tsx`: 프론트엔드 DApp. 지갑 연결, nonce 요청, `personal_sign` 서명, 검증 요청을 수행
- `app/api/auth/nonce`: 주소를 받아 nonce와 서명할 메시지 생성/저장
- `app/api/auth/verify`: 서명 검증 후 JWT 쿠키 발급
- `app/api/auth/logout`: JWT 쿠키 제거
- `app/api/me`: JWT 검증 후 현재 사용자 정보 반환
- `lib/store.ts`: 인메모리 저장소 (유저, nonce)
- `lib/auth.ts`: JWT 발급/검증 및 서명 검증(viem)

## 주의

- 인메모리 저장소로 구현되어 있어 서버 재시작 시 데이터가 사라집니다. 실제 서비스에서는 DB로 대체하세요.
- SIWE 정식 스펙을 단순화하여 메시지를 구성했습니다. 과제 요건에 맞춰 핵심 흐름만 구현했습니다.
- 개발 환경에서는 `secure` 쿠키 설정이 켜져 있어 HTTPS가 아닌 환경에서 쿠키가 동작하지 않을 수 있습니다. 필요시 `app/api/auth/verify`의 쿠키 설정에서 `secure`를 수정하세요.

## Checklist
- [x] 지갑 연결
- [ ] nonce 요청
- [ ] 메시지 서명
- [ ] 서명 검증 및 JWT 쿠키 발급
- [ ] 인증 상태 유지
- [ ] 로그아웃
- [ ] 지갑 연결 해제
- [ ] 지갑 잔고 조회

