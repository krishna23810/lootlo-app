/**
 * Ticket Service — handles ticket purchases.
 *
 * TICKET PURCHASE is the most CRITICAL transaction in the app:
 * Three things must happen ATOMICALLY (all-or-nothing):
 * 1. Deduct wallet balance (user pays)
 * 2. Create ticket record (user gets their ticket)
 * 3. Add to prize pool (game's pot grows)
 *
 * If ANY of these fails, NONE should happen.
 * This is why we use Prisma's $transaction — it wraps everything in a
 * database transaction with automatic rollback on failure.
 *
 * CONCURRENCY CONCERN:
 * What if two users try to buy the last ticket at the same time?
 * We use "optimistic locking" — check the sold count, then update with a
 * WHERE clause that includes the expected count. If it changed between
 * our read and write, the update affects 0 rows and we know someone else
 * got there first.
 */

import { prisma } from '../common/prisma';
import { validationError, conflictError, notFoundError } from '../common/errors';
import { generateTicket } from './ticket-generator';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface PurchaseResult {
  ticketId: string;
  gameId: string;
  grid: (number | null)[][];
  purchasedAt: string;
  newBalanceCents: number;
}

// ─── Purchase Ticket ─────────────────────────────────────────────────────────

/**
 * Purchase a ticket for a game.
 *
 * CHECKS (in order):
 * 1. Game exists and is in "upcoming" state
 * 2. Game is not sold out
 * 3. User hasn't already bought 6 tickets for this game
 * 4. User's wallet has enough balance
 *
 * ATOMIC OPERATIONS (all-or-nothing):
 * 1. Deduct wallet balance
 * 2. Increment game's sold ticket count + prize pool
 * 3. Generate and save ticket with valid grid
 * 4. Record transaction in history
 */
export async function purchaseTicket(userId: string, gameId: string): Promise<PurchaseResult> {
  // ── Pre-checks (outside transaction for performance) ────────────────────

  // Check 1: Game exists and is upcoming
  const game = await prisma.game.findUnique({ where: { id: gameId } });
  if (!game) {
    throw notFoundError('Game');
  }
  if (game.state !== 'upcoming') {
    throw validationError('Cannot purchase tickets', {
      game: `Game is "${game.state}" — tickets can only be purchased for upcoming games`,
    });
  }

  // Check 2: Game not sold out
  if (game.soldTicketCount >= game.maxTicketCount) {
    throw conflictError('Game is sold out — no tickets available');
  }

  // Check 3: User hasn't exceeded the game's max tickets limit
  const userTicketCount = await prisma.ticket.count({
    where: { userId, gameId },
  });
  if (userTicketCount >= game.maxTicketsPerUser) {
    throw validationError('Ticket limit reached', {
      tickets: `Maximum ${game.maxTicketsPerUser} tickets per user per game`,
    });
  }

  // Check 4: Wallet has enough balance
  const wallet = await prisma.wallet.findUnique({ where: { userId } });
  if (!wallet) {
    throw notFoundError('Wallet');
  }

  const availableBalance = Number(wallet.balanceCents) - Number(wallet.heldAmountCents);
  if (availableBalance < game.ticketPriceCents) {
    throw validationError('Insufficient balance', {
      balance: `Need ${game.ticketPriceCents} cents, available: ${availableBalance} cents`,
    });
  }

  // ── Generate the ticket grid ────────────────────────────────────────────
  const grid = generateTicket();

  // ── Atomic transaction: debit + create ticket + update game ──────────────
  const result = await prisma.$transaction(async (tx) => {
    // 1. Deduct from wallet
    const updatedWallet = await tx.wallet.update({
      where: { userId },
      data: {
        balanceCents: { decrement: BigInt(game.ticketPriceCents) },
      },
    });

    // Safety check: balance shouldn't go negative
    if (Number(updatedWallet.balanceCents) < 0) {
      throw validationError('Insufficient balance', {
        balance: 'Balance went negative — concurrent purchase detected',
      });
    }

    // 2. Increment game's sold count and prize pool
    // Using a conditional update to handle concurrency:
    // Only update if soldTicketCount is still less than max
    const updatedGame = await tx.game.updateMany({
      where: {
        id: gameId,
        soldTicketCount: { lt: game.maxTicketCount }, // Concurrency guard
        state: 'upcoming',
      },
      data: {
        soldTicketCount: { increment: 1 },
        prizePoolCents: { increment: BigInt(game.ticketPriceCents) },
      },
    });

    // If no rows updated, someone else bought the last ticket
    if (updatedGame.count === 0) {
      throw conflictError('Game sold out — another purchase completed first');
    }

    // 3. Create the ticket
    const ticket = await tx.ticket.create({
      data: {
        userId,
        gameId,
        grid: grid as unknown as object, // Cast for Prisma JSON field
      },
    });

    // 4. Record the transaction
    await tx.transaction.create({
      data: {
        walletId: wallet.id,
        type: 'ticket_purchase',
        amountCents: BigInt(game.ticketPriceCents),
        referenceId: ticket.id,
        referenceType: 'ticket',
      },
    });

    return { ticket, updatedWallet };
  });

  return {
    ticketId: result.ticket.id,
    gameId: result.ticket.gameId,
    grid: grid,
    purchasedAt: result.ticket.purchasedAt.toISOString(),
    newBalanceCents: Number(result.updatedWallet.balanceCents),
  };
}

// ─── Get User's Tickets ──────────────────────────────────────────────────────

/**
 * Get all tickets for a user, optionally filtered by game.
 */
export async function getUserTickets(userId: string, gameId?: string) {
  const where: { userId: string; gameId?: string } = { userId };
  if (gameId) {
    where.gameId = gameId;
  }

  const tickets = await prisma.ticket.findMany({
    where,
    orderBy: { purchasedAt: 'desc' },
    include: {
      game: {
        select: {
          id: true,
          state: true,
          scheduledStartTime: true,
          ticketPriceCents: true,
        },
      },
    },
  });

  return tickets.map((t) => ({
    id: t.id,
    gameId: t.gameId,
    grid: t.grid,
    purchasedAt: t.purchasedAt.toISOString(),
    game: {
      id: t.game.id,
      state: t.game.state,
      scheduledStartTime: t.game.scheduledStartTime.toISOString(),
      ticketPriceCents: t.game.ticketPriceCents,
    },
  }));
}
