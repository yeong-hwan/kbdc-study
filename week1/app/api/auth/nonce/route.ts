import { NextRequest, NextResponse } from 'next/server';
import { createNonceRecord } from '@lib/store';
import { isAddress } from 'viem';

export const runtime = 'nodejs';

function buildSignMessage(host: string, address: string, nonce: string): string {
  return [
    '로그인을 위해 아래 메시지에 서명하세요.',
    '',
    `도메인: ${host}`,
    `주소: ${address}`,
    `Nonce: ${nonce}`,
  ].join('\n');
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const address = (searchParams.get('address') || '').toLowerCase();
  if (!isAddress(address as `0x${string}`)) {
    return NextResponse.json({ error: 'invalid address' }, { status: 400 });
  }

  // host 결정 (origin 없을 수 있으므로 req.url에서 host 추출)
  const host = new URL(req.url).host;

  // UUID nonce 생성
  const nonce = crypto.randomUUID();
  const message = buildSignMessage(host, address, nonce);

  createNonceRecord(address, nonce, message);

  return NextResponse.json({ address, nonce, message });
}


