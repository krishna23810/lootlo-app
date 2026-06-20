/**
 * Ticket Router — endpoints for ticket purchase and listing.
 *
 * ENDPOINTS:
 * POST /api/tickets/purchase  → Buy a ticket for a game
 * GET  /api/tickets/mine      → List user's tickets (optional ?gameId=xxx)
 */

import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../auth/auth.middleware';
import { purchaseTicket, getUserTickets } from './ticket.service';

const router = Router();

// All ticket routes need authentication
router.use(requireAuth);

/**
 * POST /api/tickets/purchase
 *
 * Purchase a ticket for an upcoming game.
 * Request body: { gameId: "uuid-of-the-game" }
 *
 * Returns the ticket with its generated grid.
 * Wallet balance is deducted automatically.
 */
router.post('/purchase', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { gameId } = req.body;

    if (!gameId) {
      res.status(400).json({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'gameId is required',
        retryable: false,
      });
      return;
    }

    const result = await purchaseTicket(req.user!.userId, gameId);
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/tickets/mine?gameId=optional
 *
 * List all tickets owned by the current user.
 * Optionally filter by gameId.
 */
router.get('/mine', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const gameId = req.query.gameId as string | undefined;
    const tickets = await getUserTickets(req.user!.userId, gameId);
    res.json({ success: true, data: tickets });
  } catch (error) {
    next(error);
  }
});

export { router as ticketRouter };
