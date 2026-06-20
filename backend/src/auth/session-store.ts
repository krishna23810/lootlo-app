import { createHash } from 'crypto';
import { getRedisClient } from '../common/redis';

/** Default session TTL: 24 hours in seconds */
const DEFAULT_SESSION_TTL = 86400;

/** Prefix for session keys in Redis */
const SESSION_PREFIX = 'session:';

/** Prefix for login attempt tracking keys */
const LOGIN_ATTEMPTS_PREFIX = 'login_attempts:';

/** Lockout duration: 15 minutes in seconds */
const LOCKOUT_DURATION = 900;

/** Maximum failed login attempts before lockout */
const MAX_FAILED_ATTEMPTS = 5;

/**
 * Hash a token using SHA-256 for secure storage.
 * Sessions are keyed by token hash rather than raw token.
 */
export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/**
 * Store a session in Redis with a TTL.
 * The session is keyed by the SHA-256 hash of the token.
 */
export async function storeSession(
  userId: string,
  token: string,
  expiresInSeconds: number = DEFAULT_SESSION_TTL,
): Promise<void> {
  const client = await getRedisClient();
  const key = SESSION_PREFIX + hashToken(token);
  const sessionData = JSON.stringify({ userId, createdAt: Date.now() });
  await client.set(key, sessionData, { EX: expiresInSeconds });
}

/**
 * Retrieve user info for a valid session token.
 * Returns the userId if the session exists and hasn't expired, null otherwise.
 */
export async function getSession(token: string): Promise<{ userId: string } | null> {
  const client = await getRedisClient();
  const key = SESSION_PREFIX + hashToken(token);
  const data = await client.get(key);

  if (!data) {
    return null;
  }

  try {
    const parsed = JSON.parse(data);
    return { userId: parsed.userId };
  } catch {
    return null;
  }
}

/**
 * Invalidate a session by deleting it from Redis.
 */
export async function invalidateSession(token: string): Promise<void> {
  const client = await getRedisClient();
  const key = SESSION_PREFIX + hashToken(token);
  await client.del(key);
}

// ========================
// Failed Login Attempt Tracking
// ========================

/**
 * Increment the failed login attempt counter for an email address.
 * The counter auto-expires after the lockout duration.
 */
export async function incrementFailedAttempts(email: string): Promise<number> {
  const client = await getRedisClient();
  const key = LOGIN_ATTEMPTS_PREFIX + email.toLowerCase();
  const count = await client.incr(key);

  // Set/reset expiry on each failed attempt so lockout window resets
  if (count === 1) {
    await client.expire(key, LOCKOUT_DURATION);
  }

  return count;
}

/**
 * Get the current number of failed login attempts for an email.
 */
export async function getFailedAttempts(email: string): Promise<number> {
  const client = await getRedisClient();
  const key = LOGIN_ATTEMPTS_PREFIX + email.toLowerCase();
  const count = await client.get(key);
  return count ? parseInt(count, 10) : 0;
}

/**
 * Check if an account is locked out due to too many failed login attempts.
 * An account is locked if it has 5 or more failed attempts within the lockout window.
 */
export async function isAccountLocked(email: string): Promise<boolean> {
  const attempts = await getFailedAttempts(email);
  return attempts >= MAX_FAILED_ATTEMPTS;
}

/**
 * Reset the failed login attempt counter on successful login.
 */
export async function resetFailedAttempts(email: string): Promise<void> {
  const client = await getRedisClient();
  const key = LOGIN_ATTEMPTS_PREFIX + email.toLowerCase();
  await client.del(key);
}
