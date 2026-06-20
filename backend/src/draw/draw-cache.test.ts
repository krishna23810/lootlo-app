import {
  addDrawnNumber,
  getDrawnNumbers,
  clearGameCache,
  getDrawnCount,
  isNumberDrawn,
} from './draw-cache';

// In-memory sorted set mock
const sortedSets: Record<string, { score: number; value: string }[]> = {};

jest.mock('../common/redis', () => ({
  getRedisClient: jest.fn().mockResolvedValue({
    zAdd: jest.fn(async (key: string, entry: { score: number; value: string }) => {
      if (!sortedSets[key]) {
        sortedSets[key] = [];
      }
      // Remove existing entry with same value if present
      sortedSets[key] = sortedSets[key].filter((e) => e.value !== entry.value);
      sortedSets[key].push(entry);
      sortedSets[key].sort((a, b) => a.score - b.score);
    }),
    zRangeByScore: jest.fn(async (key: string, _min: string, _max: string) => {
      if (!sortedSets[key]) return [];
      return sortedSets[key].map((e) => e.value);
    }),
    zCard: jest.fn(async (key: string) => {
      return sortedSets[key]?.length ?? 0;
    }),
    zScore: jest.fn(async (key: string, member: string) => {
      const entry = sortedSets[key]?.find((e) => e.value === member);
      return entry ? entry.score : null;
    }),
    del: jest.fn(async (key: string) => {
      delete sortedSets[key];
    }),
  }),
}));

describe('Draw Cache', () => {
  beforeEach(() => {
    Object.keys(sortedSets).forEach((key) => delete sortedSets[key]);
  });

  describe('addDrawnNumber', () => {
    it('should add a number to the draw cache', async () => {
      await addDrawnNumber('game-1', 42, 1);
      const numbers = await getDrawnNumbers('game-1');
      expect(numbers).toEqual([42]);
    });

    it('should maintain draw order by position', async () => {
      await addDrawnNumber('game-2', 55, 1);
      await addDrawnNumber('game-2', 12, 2);
      await addDrawnNumber('game-2', 88, 3);
      const numbers = await getDrawnNumbers('game-2');
      expect(numbers).toEqual([55, 12, 88]);
    });
  });

  describe('getDrawnNumbers', () => {
    it('should return empty array for game with no draws', async () => {
      const numbers = await getDrawnNumbers('nonexistent-game');
      expect(numbers).toEqual([]);
    });

    it('should return all drawn numbers in order', async () => {
      await addDrawnNumber('game-3', 7, 1);
      await addDrawnNumber('game-3', 23, 2);
      await addDrawnNumber('game-3', 45, 3);
      await addDrawnNumber('game-3', 67, 4);
      await addDrawnNumber('game-3', 89, 5);

      const numbers = await getDrawnNumbers('game-3');
      expect(numbers).toEqual([7, 23, 45, 67, 89]);
    });
  });

  describe('clearGameCache', () => {
    it('should remove all drawn numbers for a game', async () => {
      await addDrawnNumber('game-4', 10, 1);
      await addDrawnNumber('game-4', 20, 2);
      await clearGameCache('game-4');
      const numbers = await getDrawnNumbers('game-4');
      expect(numbers).toEqual([]);
    });
  });

  describe('getDrawnCount', () => {
    it('should return 0 for a game with no draws', async () => {
      const count = await getDrawnCount('empty-game');
      expect(count).toBe(0);
    });

    it('should return the correct count of drawn numbers', async () => {
      await addDrawnNumber('game-5', 1, 1);
      await addDrawnNumber('game-5', 2, 2);
      await addDrawnNumber('game-5', 3, 3);
      const count = await getDrawnCount('game-5');
      expect(count).toBe(3);
    });
  });

  describe('isNumberDrawn', () => {
    it('should return true for a number that has been drawn', async () => {
      await addDrawnNumber('game-6', 42, 1);
      const drawn = await isNumberDrawn('game-6', 42);
      expect(drawn).toBe(true);
    });

    it('should return false for a number that has not been drawn', async () => {
      await addDrawnNumber('game-6', 42, 1);
      const drawn = await isNumberDrawn('game-6', 43);
      expect(drawn).toBe(false);
    });

    it('should return false for a non-existent game', async () => {
      const drawn = await isNumberDrawn('no-game', 1);
      expect(drawn).toBe(false);
    });
  });
});
