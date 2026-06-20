/**
 * Game Router — PUBLIC game endpoints for regular users.
 *
 * ENDPOINTS:
 * GET /api/games      → List upcoming games (authenticated users)
 * GET /api/games/:id  → Get single game details
 *
 * NOTE: Game CREATION is in admin/admin.router.ts (separation of concerns).
 * This file only has READ operations that regular users need.
 */

import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../auth/auth.middleware';
import { listUpcomingGames, getGame } from './game.service';

const router = Router();

/**
 * GET /api/games
 * List all upcoming games sorted by start time (earliest first).
 */
router.get('/', requireAuth, async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const games = await listUpcomingGames();
    res.json({ success: true, data: games });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/games/:id
 * Get details for a single game.
 */
router.get('/:id', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const game = await getGame(req.params.id);
    res.json({ success: true, data: game });
  } catch (error) {
    next(error);
  }
});

export { router as gameRouter };
