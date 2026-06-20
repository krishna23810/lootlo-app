/**
 * Game Service — handles game creation, listing, and state management.
 *
 * WHAT IS A "GAME"?
 * A game is a scheduled Housie/Tambola session. It has:
 * - A future start time (when live draw begins)
 * - A ticket price (what users pay to join)
 * - A max ticket count (capacity)
 * - A commission % (platform's cut from the prize pool)
 * - A prize config (how winnings are split between patterns)
 *
 * GAME STATES:
 *   upcoming → live → completed
 *                  → cancelled
 */

import { prisma } from '../common/prisma';
import {
  validateTicketPrice,
  validateCommissionPercentage,
  validateMaxTicketCount,
} from '../common/validators';
import { validationError, notFoundError } from '../common/errors';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateGameInput {
  scheduledStartTime: string; // ISO date string from client
  ticketPriceCents: number;
  maxTicketCount: number;
  commissionPercentage: number;
  prizeConfig: {
    full_house: number;
    top_line: number;
    middle_line: number;
    bottom_line: number;
    early_five: number;
    four_corners: number;
  };
}

// ─── Create Game ─────────────────────────────────────────────────────────────

/**
 * Create a new game (admin only).
 *
 * VALIDATION:
 * - Start time must be at least 30 minutes in the future
 * - Ticket price must be a positive integer (in cents)
 * - Max ticket count between 10 and 1000
 * - Commission between 1% and 30%
 * - Prize config percentages must sum to 100
 *
 * WHY 30 minutes minimum?
 * Users need time to discover, browse, and purchase tickets.
 * A game created 2 minutes from now would have zero participants.
 */
export async function createGame(input: CreateGameInput) {
  const errors: Record<string, string> = {};

  // ── Validate start time ─────────────────────────────────────────────────
  const startTime = new Date(input.scheduledStartTime);

  // Check if date is valid (invalid dates become NaN)
  if (isNaN(startTime.getTime())) {
    errors.scheduledStartTime = 'Must be a valid ISO date string';
  } else {
    const thirtyMinFromNow = new Date(Date.now() + 30 * 60 * 1000);
    if (startTime < thirtyMinFromNow) {
      errors.scheduledStartTime = 'Must be at least 30 minutes in the future';
    }
  }

  // ── Validate ticket price ───────────────────────────────────────────────
  const priceResult = validateTicketPrice(input.ticketPriceCents);
  if (!priceResult.valid) {
    Object.assign(errors, priceResult.errors);
  }

  // ── Validate max ticket count ───────────────────────────────────────────
  const countResult = validateMaxTicketCount(input.maxTicketCount);
  if (!countResult.valid) {
    Object.assign(errors, countResult.errors);
  }

  // ── Validate commission ─────────────────────────────────────────────────
  const commResult = validateCommissionPercentage(input.commissionPercentage);
  if (!commResult.valid) {
    Object.assign(errors, commResult.errors);
  }

  // ── Validate prize config sums to 100 ──────────────────────────────────
  if (input.prizeConfig) {
    const totalPercentage = Object.values(input.prizeConfig).reduce((sum, val) => sum + val, 0);
    if (totalPercentage !== 100) {
      errors.prizeConfig = `Prize percentages must sum to 100, got ${totalPercentage}`;
    }
  } else {
    errors.prizeConfig = 'Prize configuration is required';
  }

  // ── If any validation failed, throw all errors at once ──────────────────
  if (Object.keys(errors).length > 0) {
    throw validationError('Game creation validation failed', errors);
  }

  // ── Create the game in database ─────────────────────────────────────────
  const game = await prisma.game.create({
    data: {
      scheduledStartTime: startTime,
      ticketPriceCents: input.ticketPriceCents,
      maxTicketCount: input.maxTicketCount,
      commissionPercentage: input.commissionPercentage,
      prizePoolCents: BigInt(0),
      state: 'upcoming',
      prizeConfig: input.prizeConfig,
    },
  });

  return formatGameResponse(game);
}

// ─── List Upcoming Games ─────────────────────────────────────────────────────

/**
 * List all upcoming games sorted by start time (earliest first).
 *
 * WHY sorted by start time?
 * Users want to see "what's happening next" — the soonest game is most relevant.
 *
 * Prisma's orderBy: { scheduledStartTime: 'asc' }
 * 'asc' = ascending = smallest first = earliest date first
 */
export async function listUpcomingGames() {
  const games = await prisma.game.findMany({
    where: { state: 'upcoming' },
    orderBy: { scheduledStartTime: 'asc' },
  });

  return games.map(formatGameResponse);
}

// ─── Get Single Game ─────────────────────────────────────────────────────────

/**
 * Get a single game by ID.
 */
export async function getGame(gameId: string) {
  const game = await prisma.game.findUnique({
    where: { id: gameId },
  });

  if (!game) {
    throw notFoundError('Game');
  }

  return formatGameResponse(game);
}

// ─── Helper: Format game response ────────────────────────────────────────────

/**
 * Format a Prisma game record into the API response shape.
 *
 * WHY a formatter?
 * - Prisma returns BigInt for monetary fields — JSON can't serialize BigInt directly
 * - We want to expose "availableTickets" (computed field) not raw "soldTicketCount"
 * - Keeps the response shape consistent and controlled
 */
function formatGameResponse(game: {
  id: string;
  scheduledStartTime: Date;
  ticketPriceCents: number;
  maxTicketCount: number;
  soldTicketCount: number;
  commissionPercentage: number;
  prizePoolCents: bigint;
  state: string;
  prizeConfig: unknown;
  createdAt: Date;
}) {
  return {
    id: game.id,
    scheduledStartTime: game.scheduledStartTime.toISOString(),
    ticketPriceCents: game.ticketPriceCents,
    maxTicketCount: game.maxTicketCount,
    soldTicketCount: game.soldTicketCount,
    availableTickets: game.maxTicketCount - game.soldTicketCount,
    commissionPercentage: game.commissionPercentage,
    prizePoolCents: Number(game.prizePoolCents), // BigInt → Number for JSON
    state: game.state,
    prizeConfig: game.prizeConfig,
    createdAt: game.createdAt.toISOString(),
  };
}
