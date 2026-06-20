import { createClient, RedisClientType } from 'redis';

/**
 * Redis client configuration and connection helper.
 * Uses REDIS_URL or REDIS_HOST/REDIS_PORT environment variables.
 */

let redisClient: RedisClientType | null = null;

function getRedisUrl(): string {
  if (process.env.REDIS_URL) {
    return process.env.REDIS_URL;
  }
  const host = process.env.REDIS_HOST || '127.0.0.1';
  const port = process.env.REDIS_PORT || '6379';
  return `redis://${host}:${port}`;
}

/**
 * Get or create a singleton Redis client instance.
 * Connects automatically if not already connected.
 */
export async function getRedisClient(): Promise<RedisClientType> {
  if (redisClient && redisClient.isOpen) {
    return redisClient;
  }

  redisClient = createClient({ url: getRedisUrl() }) as RedisClientType;

  redisClient.on('error', (err) => {
    console.error('[Redis] Connection error:', err.message);
  });

  redisClient.on('connect', () => {
    console.log('[Redis] Connected successfully');
  });

  redisClient.on('reconnecting', () => {
    console.log('[Redis] Reconnecting...');
  });

  await redisClient.connect();
  return redisClient;
}

/**
 * Disconnect the Redis client gracefully.
 */
export async function disconnectRedis(): Promise<void> {
  if (redisClient && redisClient.isOpen) {
    await redisClient.quit();
    redisClient = null;
  }
}

/**
 * Check if Redis is connected and responsive.
 */
export async function isRedisHealthy(): Promise<boolean> {
  try {
    if (!redisClient || !redisClient.isOpen) {
      return false;
    }
    const pong = await redisClient.ping();
    return pong === 'PONG';
  } catch {
    return false;
  }
}
