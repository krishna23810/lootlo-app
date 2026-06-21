import { PrismaClient } from '@prisma/client';

/**
 * Singleton Prisma Client instance.
 * Reuses the same client across the application to leverage connection pooling.
 */

let prisma: PrismaClient;

const logLevels: ('query' | 'info' | 'warn' | 'error')[] = ['warn', 'error'];
if (process.env.LOG_QUERIES === 'true') {
  logLevels.push('query');
}

if (process.env.NODE_ENV === 'production') {
  prisma = new PrismaClient({ log: logLevels });
} else {
  // In development, reuse client across hot-reloads to avoid too many connections
  const globalForPrisma = globalThis as unknown as { prisma: PrismaClient | undefined };
  if (!globalForPrisma.prisma) {
    globalForPrisma.prisma = new PrismaClient({
      log: logLevels,
    });
  }
  prisma = globalForPrisma.prisma;
}

export { prisma };
export default prisma;
