import { NextRequest, NextResponse } from 'next/server';
import { getNonceRecord, consumeNonce, upsertUser } from '@lib/store';
import { AUTH_COOKIE_NAME, issueJwt, verifyEthSignature } from '@lib/auth';
import { isAddress } from 'viem';

export const runtime = 'nodejs';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => null) as {
    address?: string;
    signature?: string;
    nonce?: string;
  } | null;

  const address = (body?.address || '').toLowerCase();
  const signature = body?.signature || '';
  const nonce = body?.nonce || '';

  if (!isAddress(address as `0x${string}`) || !signature || !nonce) {
    return NextResponse.json({ error: 'bad request' }, { status: 400 });
  }

  const rec = getNonceRecord(address);
  if (!rec) {
    return NextResponse.json({ error: 'nonce not found or expired' }, { status: 400 });
  }
  if (rec.nonce !== nonce) {
    return NextResponse.json({ error: 'nonce mismatch' }, { status: 400 });
  }

  const ok = await verifyEthSignature(address, rec.message, signature);
  if (!ok) {
    return NextResponse.json({ error: 'signature invalid' }, { status: 401 });
  }

  const consumed = consumeNonce(address, nonce);
  if (!consumed) {
    return NextResponse.json({ error: 'nonce already used' }, { status: 400 });
  }

  upsertUser(address);

  const token = await issueJwt(address);
  const res = NextResponse.json({ ok: true, address });
  res.cookies.set({
    name: AUTH_COOKIE_NAME,
    value: token,
    httpOnly: true,
    sameSite: 'lax',
    secure: true,
    path: '/',
    maxAge: 60 * 60 * 24 * 7,
  });
  return res;
}


