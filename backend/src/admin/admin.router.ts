/**
 * Admin Router — all admin-only endpoints grouped under /api/admin.
 *
 * SEPARATION OF CONCERNS:
 * Why separate admin from public routes?
 * - Different auth requirements (admin token vs user token)
 * - Different rate limits (admins need more freedom)
 * - Easier to audit/secure (one folder to lock down)
 * - Clear boundary: if it's in /admin, only admin panel calls it
 *
 * ENDPOINTS:
 * POST /api/admin/games           → Create a new game
 * GET  /api/admin/games           → List ALL games (including past/cancelled)
 * GET  /api/admin/users           → List users with pagination
 * GET  /api/admin/withdrawals     → List pending withdrawals
 * POST /api/admin/withdrawals/:id → Approve/reject a withdrawal
 */

import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth, requireAdmin } from '../auth/auth.middleware';
import { createGame } from '../game/game.service';
import { adminLogin } from './admin-auth.service';
import { prisma } from '../common/prisma';

const router = Router();

/**
 * POST /api/admin/login
 * Admin login — separate from user login.
 * Returns a token with isAdmin: true in the payload.
 */
router.post('/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body;
    const result = await adminLogin(email, password);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

// All routes below require admin auth
router.use(requireAuth, requireAdmin);

/**
 * GET /api/admin/stats
 * Dashboard statistics — real data from database.
 */
router.get('/stats', async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const [totalUsers, totalGames, upcomingGames, pendingWithdrawals] = await Promise.all([
      prisma.user.count(),
      prisma.game.count(),
      prisma.game.count({ where: { state: 'upcoming' } }),
      prisma.withdrawalRequest.count({ where: { status: 'pending' } }),
    ]);

    // Calculate total revenue (sum of all prize pools × commission %)
    const games = await prisma.game.findMany({ where: { state: 'completed' } });
    const totalRevenueCents = games.reduce((sum, g) => sum + Number(g.prizePoolCents) * g.commissionPercentage / 100, 0);

    res.json({
      success: true,
      data: {
        totalUsers,
        totalGames,
        activeGames: upcomingGames,
        totalRevenueCents: Math.round(totalRevenueCents),
        pendingWithdrawals,
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/admin/games
 * Create a new game (admin only).
 */
router.post('/games', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const game = await createGame(req.body);
    res.status(201).json({ success: true, data: game });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/admin/users
 * Paginated user list with wallet balances and ticket counts.
 * Query params: ?page=1&limit=20&search=term
 */
router.get('/users', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 20));
    const search = (req.query.search as string || '').trim();
    const skip = (page - 1) * limit;

    const where = search
      ? {
          OR: [
            { displayName: { contains: search, mode: 'insensitive' as const } },
            { email: { contains: search, mode: 'insensitive' as const } },
            { mobile: { contains: search } },
          ],
        }
      : {};

    const [users, totalCount] = await Promise.all([
      prisma.user.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          email: true,
          mobile: true,
          displayName: true,
          createdAt: true,
          wallet: {
            select: {
              balanceCents: true,
              heldAmountCents: true,
            },
          },
          _count: {
            select: {
              tickets: true,
            },
          },
        },
      }),
      prisma.user.count({ where }),
    ]);

    const data = users.map((u) => ({
      id: u.id,
      email: u.email,
      mobile: u.mobile,
      displayName: u.displayName,
      createdAt: u.createdAt,
      balanceCents: u.wallet ? Number(u.wallet.balanceCents) : 0,
      heldAmountCents: u.wallet ? Number(u.wallet.heldAmountCents) : 0,
      ticketCount: u._count.tickets,
    }));

    res.json({
      success: true,
      data,
      pagination: {
        page,
        limit,
        totalCount,
        totalPages: Math.ceil(totalCount / limit),
      },
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/admin/games/:id
 * Delete a game (only if no tickets sold).
 */
router.delete('/games/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // Check if game has sold tickets
    const game = await prisma.game.findUnique({ where: { id } });
    if (!game) {
      res.status(404).json({ status: 404, code: 'NOT_FOUND', message: 'Game not found', retryable: false });
      return;
    }
    if (game.soldTicketCount > 0) {
      res.status(400).json({ status: 400, code: 'CANNOT_DELETE', message: 'Cannot delete game with sold tickets', retryable: false });
      return;
    }

    await prisma.game.delete({ where: { id } });
    res.json({ success: true, message: 'Game deleted' });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/admin/games/:id
 * Update a game (only upcoming games can be edited).
 */
router.patch('/games/:id', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { scheduledStartTime, ticketPriceCents, maxTicketCount, commissionPercentage } = req.body;

    const game = await prisma.game.findUnique({ where: { id } });
    if (!game) {
      res.status(404).json({ status: 404, code: 'NOT_FOUND', message: 'Game not found', retryable: false });
      return;
    }
    if (game.state !== 'upcoming') {
      res.status(400).json({ status: 400, code: 'CANNOT_EDIT', message: 'Only upcoming games can be edited', retryable: false });
      return;
    }

    const updated = await prisma.game.update({
      where: { id },
      data: {
        ...(scheduledStartTime && { scheduledStartTime: new Date(scheduledStartTime) }),
        ...(ticketPriceCents && { ticketPriceCents }),
        ...(maxTicketCount && { maxTicketCount }),
        ...(commissionPercentage && { commissionPercentage }),
      },
    });

    res.json({ success: true, data: updated });
  } catch (error) {
    next(error);
  }
});

export { router as adminRouter };
