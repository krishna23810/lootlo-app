/**
 * Wallet Router — endpoints for user wallet operations.
 *
 * ENDPOINTS:
 * GET /api/wallet/balance       → Get current balance + available balance
 * GET /api/wallet/transactions  → Get paginated transaction history
 *
 * All wallet routes require authentication (user must be logged in).
 * The userId comes from the verified JWT token (req.user.userId).
 */

import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../auth/auth.middleware';
import { getWalletBalance, getTransactionHistory, topUpWallet, requestWithdrawal } from './wallet.service';

const router = Router();

// All wallet routes need authentication
router.use(requireAuth);

/**
 * GET /api/wallet/balance
 *
 * Returns the user's wallet balance.
 * The userId is extracted from the JWT token — user can only see their OWN balance.
 *
 * Response: {
 *   balanceCents: 50000,        // ₹500.00 total
 *   heldAmountCents: 10000,     // ₹100.00 held for pending withdrawal
 *   availableBalanceCents: 40000 // ₹400.00 available to spend
 * }
 */
router.get('/balance', async (req: Request, res: Response, next: NextFunction) => {
  try {
    // req.user is set by requireAuth middleware (from the JWT payload)
    const balance = await getWalletBalance(req.user!.userId);
    res.json({ success: true, data: balance });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/wallet/transactions?page=1&pageSize=20
 *
 * Returns paginated transaction history (newest first).
 *
 * QUERY PARAMETERS:
 * - page (optional, default 1): which page to fetch
 * - pageSize (optional, default 20): how many per page
 *
 * These come from the URL: /api/wallet/transactions?page=2&pageSize=10
 * Express parses them into req.query object automatically.
 *
 * parseInt(value, 10): converts string "2" to number 2
 * The || provides defaults if parsing fails (NaN || 1 = 1)
 */
router.get('/transactions', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = parseInt(req.query.page as string, 10) || 1;
    const pageSize = Math.min(parseInt(req.query.pageSize as string, 10) || 20, 100); // Cap at 100

    const result = await getTransactionHistory(req.user!.userId, page, pageSize);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/wallet/topup
 *
 * Add money to wallet (uses mock payment gateway).
 * Request body: { amountCents: 5000 }  // ₹50.00
 */
router.post('/topup', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { amountCents } = req.body;
    const result = await topUpWallet(req.user!.userId, amountCents);
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/wallet/withdraw
 *
 * Request a withdrawal. Places a hold on the amount.
 * Request body: { amountCents: 10000, paymentDestination: "UPI:user@paytm" }
 */
router.post('/withdraw', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { amountCents, paymentDestination } = req.body;
    const result = await requestWithdrawal(req.user!.userId, amountCents, paymentDestination);
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

export { router as walletRouter };
