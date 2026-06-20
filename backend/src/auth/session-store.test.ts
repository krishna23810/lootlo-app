import {
  storeSession,
  getSession,
  invalidateSession,
  incrementFailedAttempts,
  getFailedAttempts,
  isAccountLocked,
  resetFailedAttempts,
  hashToken,
} from './session-store';

// In-memory Redis mock store
const store: Record<string, { value: string; expiry?: number }> = {};

jest.mock('../common/redis', () => ({
  getRedisClient: jest.fn().mockResolvedValue({
    set: jest.fn(async (key: string, value: string, options?: { EX?: number }) => {
      store[key] = { value, expiry: options?.EX };
    }),
    get: jest.fn(async (key: string) => store[key]?.value ?? null),
    del: jest.fn(async (key: string) => {
      delete store[key];
    }),
    incr: jest.fn(async (key: string) => {
      if (!store[key]) {
        store[key] = { value: '0' };
      }
      const newVal = parseInt(store[key].value, 10) + 1;
      store[key].value = String(newVal);
      return newVal;
    }),
    expire: jest.fn(async (_key: string, _seconds: number) => {
      // no-op for testing
    }),
  }),
}));

describe('Session Store', () => {
  beforeEach(() => {
    // Clear the mock store
    Object.keys(store).forEach((key) => delete store[key]);
  });

  describe('hashToken', () => {
    it('should produce a consistent SHA-256 hash', () => {
      const token = 'my-test-token';
      const hash1 = hashToken(token);
      const hash2 = hashToken(token);
      expect(hash1).toBe(hash2);
      expect(hash1).toHaveLength(64); // SHA-256 produces 64-char hex
    });

    it('should produce different hashes for different tokens', () => {
      const hash1 = hashToken('token-a');
      const hash2 = hashToken('token-b');
      expect(hash1).not.toBe(hash2);
    });
  });

  describe('storeSession / getSession / invalidateSession', () => {
    it('should store and retrieve a session', async () => {
      await storeSession('user-123', 'my-token');
      const session = await getSession('my-token');
      expect(session).not.toBeNull();
      expect(session!.userId).toBe('user-123');
    });

    it('should return null for non-existent session', async () => {
      const session = await getSession('non-existent-token');
      expect(session).toBeNull();
    });

    it('should invalidate a session', async () => {
      await storeSession('user-456', 'token-to-remove');
      await invalidateSession('token-to-remove');
      const session = await getSession('token-to-remove');
      expect(session).toBeNull();
    });

    it('should store session with custom TTL', async () => {
      await storeSession('user-789', 'short-token', 3600);
      const key = 'session:' + hashToken('short-token');
      expect(store[key].expiry).toBe(3600);
    });

    it('should use default 24-hour TTL when not specified', async () => {
      await storeSession('user-101', 'default-ttl-token');
      const key = 'session:' + hashToken('default-ttl-token');
      expect(store[key].expiry).toBe(86400);
    });
  });

  describe('Failed login attempt tracking', () => {
    it('should increment failed attempts', async () => {
      const count = await incrementFailedAttempts('test@example.com');
      expect(count).toBe(1);
    });

    it('should track multiple failed attempts', async () => {
      await incrementFailedAttempts('multi@example.com');
      await incrementFailedAttempts('multi@example.com');
      const count = await incrementFailedAttempts('multi@example.com');
      expect(count).toBe(3);
    });

    it('should get the current failed attempts count', async () => {
      await incrementFailedAttempts('count@example.com');
      await incrementFailedAttempts('count@example.com');
      const count = await getFailedAttempts('count@example.com');
      expect(count).toBe(2);
    });

    it('should return 0 for email with no failed attempts', async () => {
      const count = await getFailedAttempts('clean@example.com');
      expect(count).toBe(0);
    });

    it('should lock account after 5 failed attempts', async () => {
      for (let i = 0; i < 5; i++) {
        await incrementFailedAttempts('lockme@example.com');
      }
      const locked = await isAccountLocked('lockme@example.com');
      expect(locked).toBe(true);
    });

    it('should not lock account with fewer than 5 attempts', async () => {
      for (let i = 0; i < 4; i++) {
        await incrementFailedAttempts('almost@example.com');
      }
      const locked = await isAccountLocked('almost@example.com');
      expect(locked).toBe(false);
    });

    it('should reset failed attempts on successful login', async () => {
      for (let i = 0; i < 3; i++) {
        await incrementFailedAttempts('reset@example.com');
      }
      await resetFailedAttempts('reset@example.com');
      const count = await getFailedAttempts('reset@example.com');
      expect(count).toBe(0);
    });

    it('should be case-insensitive for email tracking', async () => {
      await incrementFailedAttempts('User@Example.COM');
      const count = await getFailedAttempts('user@example.com');
      expect(count).toBe(1);
    });
  });
});
