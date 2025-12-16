'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';

type EthereumProvider = {
  request: (args: { method: string; params?: unknown[] }) => Promise<any>;
  on?: (event: string, handler: (...args: any[]) => void) => void;
  removeListener?: (event: string, handler: (...args: any[]) => void) => void;
};

declare global {
  interface Window {
    ethereum?: EthereumProvider;
  }
}

export default function Page() {
  const [address, setAddress] = useState<string>('');
  const [connected, setConnected] = useState<boolean>(false);
  const [loggingIn, setLoggingIn] = useState<boolean>(false);
  const [me, setMe] = useState<{ address: string } | null>(null);
  const [error, setError] = useState<string>('');

  const hasProvider = useMemo(() => typeof window !== 'undefined' && !!window.ethereum, []);

  // 새로고침 시 세션 확인
  useEffect(() => {
    const check = async () => {
      try {
        const res = await fetch('/api/me', { credentials: 'include' });
        if (res.ok) {
          const data = await res.json();
          setMe({ address: data.address });
        }
      } catch {
        // ignore
      }
    };
    check();
  }, []);

  useEffect(() => {
    if (!window.ethereum?.on) return;
    const handler = (accs: string[]) => {
      const next = (accs?.[0] || '').toLowerCase();
      setAddress(next);
      setConnected(!!next);
    };
    window.ethereum.on('accountsChanged', handler);
    return () => {
      window.ethereum?.removeListener?.('accountsChanged', handler);
    };
  }, []);

  // 지갑 연결
  const onConnect = useCallback(async () => {
    setError('');
    try {
      if (!window.ethereum) {
        setError('MetaMask가 필요합니다.');
        return;
      }
      const accounts: string[] = await window.ethereum.request({ method: 'eth_requestAccounts' });
      const acc = (accounts?.[0] || '').toLowerCase();
      setAddress(acc);
      setConnected(!!acc);
    } catch (e: any) {
      setError(e?.message || '지갑 연결 실패');
    }
  }, []);

  // 로그인 흐름: nonce 요청 -> message 서명 -> verify
  const onLogin = useCallback(async () => {
    setError('');
    setLoggingIn(true);
    try {
      if (!address) {
        setError('먼저 지갑을 연결하세요.');
        setLoggingIn(false);
        return;
      }
      // 1) nonce + message 받기
      const nonceRes = await fetch(`/api/auth/nonce?address=${address}`, {
        method: 'GET',
        credentials: 'include',
      });
      if (!nonceRes.ok) {
        const err = await nonceRes.json().catch(() => ({}));
        throw new Error(err?.error || 'nonce 요청 실패');
      }
      const { nonce, message } = await nonceRes.json();

      // 2) personal_sign으로 메시지 서명
      if (!window.ethereum) {
        throw new Error('Provider not found');
      }
      const signature: string = await window.ethereum.request({
        method: 'personal_sign',
        // MetaMask는 [message, address] 순서 권장
        params: [message, address],
      });

      // 3) 백엔드 검증 요청
      const verifyRes = await fetch('/api/auth/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ address, signature, nonce }),
      });
      if (!verifyRes.ok) {
        const err = await verifyRes.json().catch(() => ({}));
        throw new Error(err?.error || '검증 실패');
      }
      const verified = await verifyRes.json();
      setMe({ address: verified.address });
    } catch (e: any) {
      setError(e?.message || '로그인 실패');
    } finally {
      setLoggingIn(false);
    }
  }, [address]);

  const onLogout = useCallback(async () => {
    setError('');
    try {
      await fetch('/api/auth/logout', { method: 'POST', credentials: 'include' });
      setMe(null);
    } catch (e: any) {
      setError(e?.message || '로그아웃 실패');
    }
  }, []);

  return (
    <main style={{ maxWidth: 720, margin: '40px auto', padding: 16 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>EOA 기반 Web3 로그인 (EIP-1193)</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>MetaMask로 연결하고, 서버에서 제공한 메시지를 서명해 로그인합니다.</p>

      {!hasProvider && (
        <div style={{ padding: 12, background: '#fff3cd', border: '1px solid #ffeeba', borderRadius: 6, marginBottom: 16 }}>
          MetaMask가 설치되어 있지 않습니다. 브라우저에 지갑을 설치하세요.
        </div>
      )}

      <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <button onClick={onConnect} disabled={!hasProvider} style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #ddd' }}>
          {connected ? '지갑 재연결' : '지갑 연결'}
        </button>
        <button onClick={onLogin} disabled={!connected || loggingIn} style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #ddd' }}>
          {loggingIn ? '로그인 중...' : '서명으로 로그인'}
        </button>
        {me && (
          <button onClick={onLogout} style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #ddd' }}>
            로그아웃
          </button>
        )}
      </div>

      <div style={{ marginBottom: 8 }}>
        <div style={{ fontSize: 14, color: '#444' }}>
          연결된 주소: <strong>{address || '-'}</strong>
        </div>
        <div style={{ fontSize: 14, color: me ? '#2c7a7b' : '#444' }}>
          로그인 상태: <strong>{me ? `✅ ${me.address}` : '❌'}</strong>
        </div>
      </div>

      {error && (
        <div style={{ marginTop: 12, padding: 12, background: '#fdecea', border: '1px solid #f5c2c7', color: '#842029', borderRadius: 6 }}>
          {error}
        </div>
      )}

      <hr style={{ margin: '24px 0' }} />

      <ProtectedDemo />
    </main>
  );
}

function ProtectedDemo() {
  const [data, setData] = useState<string>('-');

  const onCall = useCallback(async () => {
    setData('-');
    const res = await fetch('/api/me', { credentials: 'include' });
    if (res.ok) {
      const json = await res.json();
      setData(`Hello ${json.address}`);
    } else {
      setData('401 Unauthorized');
    }
  }, []);

  return (
    <div>
      <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>보호 API 호출 데모</h2>
      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <button onClick={onCall} style={{ padding: '10px 14px', borderRadius: 8, border: '1px solid #ddd' }}>
          /api/me 호출
        </button>
        <span style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco' }}>{data}</span>
      </div>
    </div>
  );
}


