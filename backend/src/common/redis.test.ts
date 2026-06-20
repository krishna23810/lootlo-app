// Mock the redis module before importing
const mockClient = {
  isOpen: true,
  connect: jest.fn().mockResolvedValue(undefined),
  quit: jest.fn().mockResolvedValue(undefined),
  ping: jest.fn().mockResolvedValue('PONG'),
  on: jest.fn(),
};

jest.mock('redis', () => ({
  createClient: jest.fn(() => mockClient),
}));

// Use isolateModules to get a fresh module instance for each test suite
let getRedisClient: typeof import('./redis').getRedisClient;
let disconnectRedis: typeof import('./redis').disconnectRedis;
let isRedisHealthy: typeof import('./redis').isRedisHealthy;

beforeAll(() => {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const redis = require('./redis');
  getRedisClient = redis.getRedisClient;
  disconnectRedis = redis.disconnectRedis;
  isRedisHealthy = redis.isRedisHealthy;
});

describe('Redis Client', () => {
  describe('getRedisClient', () => {
    it('should create and connect a Redis client', async () => {
      const client = await getRedisClient();
      expect(client).toBeDefined();
      expect(mockClient.connect).toHaveBeenCalled();
    });

    it('should register error, connect, and reconnecting event handlers', async () => {
      // After getRedisClient is called, event handlers should be registered
      const eventNames = mockClient.on.mock.calls.map(
        (call: [string, unknown]) => call[0],
      );
      expect(eventNames).toContain('error');
      expect(eventNames).toContain('connect');
      expect(eventNames).toContain('reconnecting');
    });
  });

  describe('isRedisHealthy', () => {
    it('should return true when Redis responds with PONG', async () => {
      await getRedisClient();
      const healthy = await isRedisHealthy();
      expect(healthy).toBe(true);
    });

    it('should return false when ping throws', async () => {
      await getRedisClient();
      mockClient.ping.mockRejectedValueOnce(new Error('Connection lost'));
      const healthy = await isRedisHealthy();
      expect(healthy).toBe(false);
    });
  });

  describe('disconnectRedis', () => {
    it('should call quit on the client', async () => {
      await getRedisClient();
      await disconnectRedis();
      expect(mockClient.quit).toHaveBeenCalled();
    });
  });
});
