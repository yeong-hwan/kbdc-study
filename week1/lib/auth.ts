import { SignJWT, jwtVerify, JWTPayload } from 'jose';
import { verifyMessage } from 'viem';

export const AUTH_COOKIE_NAME = 'auth_token';

// 데모용 시크릿. 실제 서비스에서는 강력한 랜덤 시크릿을 환경변수로 주입
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
const secretKey = new TextEncoder().encode(JWT_SECRET);

export type AuthToken = {
  sub: string; // address
  iat: number;
  exp: number;
};

// JWT 발급
export async function issueJwt(address: string, maxAgeSeconds: number = 60 * 60 * 24 * 7): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(address.toLowerCase())
    .setIssuedAt(now)
    .setExpirationTime(now + maxAgeSeconds)
    .sign(secretKey);
  return token;
}

// JWT 검증
export async function verifyJwt(token: string): Promise<AuthToken | null> {
  try {
    const { payload } = await jwtVerify(token, secretKey);
    const sub = (payload.sub || '').toLowerCase();
    if (!sub) return null;
    return {
      sub,
      iat: payload.iat || 0,
      exp: payload.exp || 0,
    };
  } catch {
    return null;
  }
}

// 이더리움 서명 검증
export async function verifyEthSignature(address: string, message: string, signature: string): Promise<boolean> {
  return verifyMessage({
    address: address.toLowerCase() as `0x${string}`,
    message,
    signature: signature as `0x${string}`,
  });
}


