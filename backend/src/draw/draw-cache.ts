import { getRedisClient } from '../common/redis';

/** Prefix for draw state sorted sets in Redis */
const DRAW_CACHE_PREFIX = 'draw:game:';

/**
 * Add a drawn number to the Redis sorted set for a game.
 * The position (draw order) is used as the score for ordering.
 */
export async function addDrawnNumber(
  gameId: string,
  number: number,
  position: number,
): Promise<void> {
  const client = await getRedisClient();
  const key = DRAW_CACHE_PREFIX + gameId;
  // Score = position (draw order), Member = the drawn number
  await client.zAdd(key, { score: position, value: String(number) });
}

/**
 * Get all drawn numbers for a game in draw order.
 * Returns an array of numbers sorted by the position they were drawn.
 */
export async function getDrawnNumbers(gameId: string): Promise<number[]> {
  const client = await getRedisClient();
  const key = DRAW_CACHE_PREFIX + gameId;
  // Retrieve all members sorted by score (position) ascending
  const members = await client.zRangeByScore(key, '-inf', '+inf');
  return members.map((m) => parseInt(m, 10));
}

/**
 * Clear the draw cache for a game (cleanup after game ends).
 */
export async function clearGameCache(gameId: string): Promise<void> {
  const client = await getRedisClient();
  const key = DRAW_CACHE_PREFIX + gameId;
  await client.del(key);
}

/**
 * Get the count of drawn numbers for a game.
 * Useful for determining the next position in the draw sequence.
 */
export async function getDrawnCount(gameId: string): Promise<number> {
  const client = await getRedisClient();
  const key = DRAW_CACHE_PREFIX + gameId;
  return await client.zCard(key);
}

/**
 * Check if a specific number has already been drawn in a game.
 */
export async function isNumberDrawn(gameId: string, number: number): Promise<boolean> {
  const client = await getRedisClient();
  const key = DRAW_CACHE_PREFIX + gameId;
  const score = await client.zScore(key, String(number));
  return score !== null;
}
