
export type User = {
  address: string;
  createdAt: number;
  lastLoginAt?: number;
};

export type NonceRecord = {
  address: string;
  nonce: string;
  message: string;
  createdAt: number;
  used: boolean;
};

const NONCE_TTL_MS = 5 * 60 * 1000; // 5분

const addressToUser = new Map<string, User>();
const addressToNonce = new Map<string, NonceRecord>();

export function normalizeAddress(address: string): string {
  return address.toLowerCase();
}

export function upsertUser(address: string): User {
  const key = normalizeAddress(address);
  const existing = addressToUser.get(key);
  if (existing) {
    existing.lastLoginAt = Date.now();
    return existing;
  }
  const user: User = { address: key, createdAt: Date.now(), lastLoginAt: Date.now() };
  addressToUser.set(key, user);
  return user;
}

export function getUser(address: string): User | undefined {
  return addressToUser.get(normalizeAddress(address));
}

export function createNonceRecord(address: string, nonce: string, message: string): NonceRecord {
  const rec: NonceRecord = {
    address: normalizeAddress(address),
    nonce,
    message,
    createdAt: Date.now(),
    used: false,
  };
  addressToNonce.set(rec.address, rec);
  return rec;
}

export function getNonceRecord(address: string): NonceRecord | undefined {
  const rec = addressToNonce.get(normalizeAddress(address));
  if (!rec) return undefined;
  const isExpired = Date.now() - rec.createdAt > NONCE_TTL_MS;
  if (isExpired) {
    addressToNonce.delete(rec.address);
    return undefined;
  }
  return rec;
}

export function consumeNonce(address: string, nonce: string): boolean {
  const key = normalizeAddress(address);
  const rec = getNonceRecord(key);
  if (!rec) return false;
  if (rec.used) return false;
  if (rec.nonce !== nonce) return false;
  rec.used = true;
  addressToNonce.delete(key);
  return true;
}


