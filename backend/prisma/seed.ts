/**
 * Database Seed Script — creates test data for development.
 *
 * Run with: npm run db:seed
 * Or automatically after: npx prisma migrate reset
 *
 * Creates:
 * - 1 test user (with wallet pre-loaded with ₹1000)
 * - 2 upcoming games
 */

import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create a test user
  const passwordHash = await bcrypt.hash('Test1234', 12);
  
  const user = await prisma.user.upsert({
    where: { email: 'test@lootlo.com' },
    update: {},
    create: {
      email: 'test@lootlo.com',
      mobile: '+919876543210',
      passwordHash,
      displayName: 'Test Player',
      wallet: {
        create: {
          balanceCents: BigInt(100000), // ₹1000.00
          heldAmountCents: BigInt(0),
        },
      },
    },
  });
  console.log(`  ✓ User created: ${user.email} (password: Test1234)`);

  // Create admin user
  const adminPasswordHash = await bcrypt.hash('Admin1234', 12);
  await prisma.admin.upsert({
    where: { email: 'admin@lootlo.com' },
    update: {},
    create: {
      email: 'admin@lootlo.com',
      passwordHash: adminPasswordHash,
      name: 'Super Admin',
      role: 'super_admin',
      isActive: true,
    },
  });
  console.log(`  ✓ Admin created: admin@lootlo.com (password: Admin1234)`);

  // Create test games
  await prisma.game.create({
    data: {
      scheduledStartTime: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours from now
      ticketPriceCents: 5000, // ₹50
      maxTicketCount: 100,
      commissionPercentage: 10,
      prizePoolCents: BigInt(0),
      state: 'upcoming',
      prizeConfig: {
        full_house: 40,
        top_line: 15,
        middle_line: 15,
        bottom_line: 15,
        early_five: 10,
        four_corners: 5,
      },
    },
  });
  console.log(`  ✓ Game 1 created: ₹50 ticket, 100 max (starts in 24h)`);

  await prisma.game.create({
    data: {
      scheduledStartTime: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48 hours from now
      ticketPriceCents: 10000, // ₹100
      maxTicketCount: 50,
      commissionPercentage: 15,
      prizePoolCents: BigInt(0),
      state: 'upcoming',
      prizeConfig: {
        full_house: 35,
        top_line: 15,
        middle_line: 15,
        bottom_line: 15,
        early_five: 10,
        four_corners: 10,
      },
    },
  });
  console.log(`  ✓ Game 2 created: ₹100 ticket, 50 max (starts in 5h)`);

  console.log('\n✅ Seed complete!');
  console.log('\nTest credentials:');
  console.log('  User:  test@lootlo.com / Test1234');
  console.log('  Admin: admin@lootlo.com / Admin1234');
  console.log('  Wallet: ₹1000.00');
}

main()
  .catch((e) => {
    console.error('Seed failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
