import { NextRequest, NextResponse } from 'next/server';
import { cookies } from 'next/headers';
import { AUTH_COOKIE_NAME, verifyJwt } from '@lib/auth';
import { getUser } from '@lib/store';

export const runtime = 'nodejs';

export async function GET(_req: NextRequest) {
  const token = cookies().get(AUTH_COOKIE_NAME)?.value || '';
  if (!token) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }
  const payload = await verifyJwt(token);
  if (!payload?.sub) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }
  const user = getUser(payload.sub);
  if (!user) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }
  return NextResponse.json({ address: user.address, lastLoginAt: user.lastLoginAt, createdAt: user.createdAt });
}


