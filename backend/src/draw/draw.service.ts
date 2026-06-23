import { prisma } from '../common/prisma';
import { addDrawnNumber, clearGameCache } from './draw-cache';
import { validateClaim } from './pattern-detector';
import { janusClient } from '../common/janus.client';
import { broadcastToRoom, sendNotification, sendBulkNotification } from '../notification/notification.service';
import {
  notFoundError,
  validationError,
  conflictError,
  forbiddenError,
} from '../common/errors';
import { WinningPattern } from '@prisma/client';

export const drawService = {
  /**
   * Start a live draw session for a game.
   */
  async startSession(gameId: string): Promise<void> {
    const game = await prisma.game.findUnique({ where: { id: gameId } });
    if (!game) {
      throw notFoundError('Game');
    }
    if (game.state !== 'upcoming') {
      throw validationError('Game cannot be started', {
        state: `Game is in "${game.state}" state. Only upcoming games can be started.`,
      });
    }

    // Update game state in database
    await prisma.game.update({
      where: { id: gameId },
      data: { state: 'live' },
    });

    // Create the VideoRoom in Janus WebRTC Gateway
    await janusClient.createRoom(gameId);

    // Broadcast live state change to socket clients
    broadcastToRoom(`game:${gameId}`, 'game:state_change', { gameId, state: 'live' });
    broadcastToRoom('lobby', 'game:state_change', { gameId, state: 'live' });

    // Notify all ticket holders that the game is now live
    try {
      const tickets = await prisma.ticket.findMany({
        where: { gameId },
        select: { userId: true },
      });
      const uniqueUserIds = Array.from(new Set(tickets.map((t) => t.userId)));
      if (uniqueUserIds.length > 0) {
        await sendBulkNotification(
          uniqueUserIds,
          'game_started',
          '🔴 Game is Live!',
          `The host has started "${game.gameName}". Join the game room now to play!`,
          { gameId }
        );
      }
    } catch (err) {
      console.error('[Notification Error] Failed to send bulk game start notification:', err);
    }
  },

  /**
   * Input/Draw a new random number into the game.
   */
  async drawNumber(gameId: string): Promise<{ number: number; position: number }> {
    const game = await prisma.game.findUnique({ where: { id: gameId } });
    if (!game) {
      throw notFoundError('Game');
    }
    if (game.state !== 'live') {
      throw validationError('Cannot draw number', {
        state: `Game must be "live" to draw numbers, currently it is "${game.state}".`,
      });
    }

    // Get numbers already drawn
    const drawEvents = await prisma.drawEvent.findMany({
      where: { gameId },
      select: { number: true },
    });
    const drawnNumbers = drawEvents.map((de) => de.number);

    if (drawnNumbers.length >= 90) {
      throw validationError('Cannot draw number', {
        draw: 'All 90 numbers have already been drawn for this game.',
      });
    }

    // Pick a random number not yet drawn
    const availablePool = Array.from({ length: 90 }, (_, i) => i + 1).filter(
      (n) => !drawnNumbers.includes(n),
    );
    const randomIndex = Math.floor(Math.random() * availablePool.length);
    const number = availablePool[randomIndex];
    const position = drawnNumbers.length + 1;

    // Persist DrawEvent in DB
    await prisma.drawEvent.create({
      data: {
        gameId,
        number,
        position,
      },
    });

    // Cache in Redis
    await addDrawnNumber(gameId, number, position);

    // Broadcast draw number via Socket.io
    broadcastToRoom(`game:${gameId}`, 'game:draw_number', { gameId, number, position });

    return { number, position };
  },

  /**
   * Submit and evaluate a winning pattern claim.
   */
  async submitClaim(
    userId: string,
    gameId: string,
    ticketId: string,
    pattern: WinningPattern,
  ): Promise<any> {
    // 1. Check false claims limit (5 strikes)
    const invalidClaimsCount = await prisma.winningClaim.count({
      where: {
        userId,
        gameId,
        status: 'invalid',
      },
    });
    if (invalidClaimsCount >= 5) {
      throw validationError('Claim blocked', {
        claim: 'You have been blocked from claiming in this game due to multiple false claims.',
      });
    }

    // 2. Fetch game
    const game = await prisma.game.findUnique({ where: { id: gameId } });
    if (!game) {
      throw notFoundError('Game');
    }
    if (game.state !== 'live') {
      throw validationError('Cannot submit claim', {
        state: 'Claims can only be submitted during live games.',
      });
    }

    // 3. Check if pattern already claimed by someone else in this game
    const existingValidClaim = await prisma.winningClaim.findFirst({
      where: {
        gameId,
        pattern,
        status: 'valid',
      },
    });

    const drawEvents = await prisma.drawEvent.findMany({
      where: { gameId },
      orderBy: { position: 'asc' },
      select: { number: true },
    });
    const drawnNumbers = drawEvents.map((de) => de.number);
    const currentPosition = drawEvents.length;

    if (existingValidClaim) {
      // Record this attempt as an invalid claim so it counts as a strike
      await prisma.winningClaim.create({
        data: {
          userId,
          gameId,
          ticketId,
          pattern,
          status: 'invalid',
          claimedAtPosition: currentPosition,
          prizeAmountCents: BigInt(0),
        },
      });
      throw conflictError('This pattern has already been successfully claimed by another player.');
    }

    // 4. Fetch ticket
    const ticket = await prisma.ticket.findUnique({
      where: { id: ticketId },
      include: { user: true },
    });
    if (!ticket) {
      throw notFoundError('Ticket');
    }
    if (ticket.userId !== userId) {
      throw forbiddenError('This ticket does not belong to you.');
    }

    // 5. Evaluate the claim against the ticket grid
    const grid = ticket.grid as unknown as (number | null)[][];
    const isValid = validateClaim(grid, drawnNumbers, pattern);

    if (!isValid) {
      // Record failed attempt in DB
      await prisma.winningClaim.create({
        data: {
          userId,
          gameId,
          ticketId,
          pattern,
          status: 'invalid',
          claimedAtPosition: currentPosition,
          prizeAmountCents: BigInt(0),
        },
      });
      throw validationError('Invalid claim', {
        claim: 'The numbers required for this pattern have not been drawn yet.',
      });
    }

    // 6. Calculate prize share from prize pool config
    const prizeConfig = game.prizeConfig as Record<string, number>;
    const percentage = prizeConfig[pattern] || 0;
    const prizeAmountCents = (game.prizePoolCents * BigInt(percentage)) / BigInt(100);

    // 7. Atomic transaction: create claim, update wallet, log transaction
    const claim = await prisma.$transaction(async (tx) => {
      const claimRecord = await tx.winningClaim.create({
        data: {
          userId,
          gameId,
          ticketId,
          pattern,
          status: 'valid',
          claimedAtPosition: currentPosition,
          prizeAmountCents,
        },
      });

      const wallet = await tx.wallet.findUnique({ where: { userId } });
      if (!wallet) {
        throw notFoundError('Wallet');
      }

      await tx.wallet.update({
        where: { userId },
        data: {
          balanceCents: { increment: prizeAmountCents },
        },
      });

      await tx.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'winning',
          amountCents: prizeAmountCents,
          referenceId: claimRecord.id,
          referenceType: 'winning_claim',
        },
      });

      return claimRecord;
    });

    // 8. Broadcast claim validation socket event to room
    broadcastToRoom(`game:${gameId}`, 'game:claim_validation', {
      gameId,
      userId,
      displayName: ticket.user.displayName,
      pattern,
      status: 'valid',
      prizeAmountCents: Number(prizeAmountCents),
    });

    // 9. Send persistent notification to the winning user
    try {
      await sendNotification({
        userId,
        type: 'pattern_won',
        title: '🏆 Pattern Won!',
        body: `Congratulations! Your claim for "${pattern}" in "${game.gameName}" is verified. You won ₹${(Number(prizeAmountCents) / 100).toFixed(2)}!`,
        data: { gameId, pattern, prizeAmountCents: Number(prizeAmountCents) },
      });
    } catch (err) {
      console.error('[Notification Error] Failed to send winning notification:', err);
    }

    return {
      id: claim.id,
      gameId: claim.gameId,
      ticketId: claim.ticketId,
      userId: claim.userId,
      displayName: ticket.user.displayName,
      pattern: claim.pattern,
      status: claim.status,
      prizeAmountCents: Number(claim.prizeAmountCents),
      claimedAtPosition: claim.claimedAtPosition,
    };
  },

  /**
   * End a live session.
   */
  async endSession(gameId: string): Promise<void> {
    const game = await prisma.game.findUnique({ where: { id: gameId } });
    if (!game) {
      throw notFoundError('Game');
    }

    // Update game state in DB
    await prisma.game.update({
      where: { id: gameId },
      data: { state: 'completed' },
    });

    // Destroy VideoRoom in Janus
    await janusClient.destroyRoom(gameId);

    // Clear Redis Cache
    await clearGameCache(gameId);

    // Broadcast completion state change to socket clients
    broadcastToRoom(`game:${gameId}`, 'game:state_change', { gameId, state: 'completed' });
    broadcastToRoom('lobby', 'game:state_change', { gameId, state: 'completed' });
  },
};
