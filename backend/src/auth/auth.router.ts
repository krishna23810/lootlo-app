/**
 * Auth Router — Express route definitions for authentication.
 *
 * ENDPOINTS:
 * POST /api/auth/register  → Create account, get access + refresh tokens
 * POST /api/auth/refresh   → Use refresh token to get new access token
 * POST /api/auth/logout    → Invalidate refresh token
 *
 * THE TOKEN FLOW (from client perspective):
 * ──────────────────────────────────────────
 * 1. Register/Login → save both tokens (access in memory, refresh in secure storage)
 * 2. Every API call → send access token in header
 * 3. Got 401? → call /refresh with refresh token → get new access token → retry
 * 4. Refresh also 401? → user must login again
 * 5. Logout → call /logout → delete both tokens locally
 */

import { Router, Request, Response, NextFunction } from 'express';
import { registerUser, loginUser, refreshAccessToken, logout } from './auth.service';
import { authLimiter } from '../common/rate-limiter';
import { requireAuth } from './auth.middleware';
import { prisma } from '../common/prisma';

const router = Router();

// Apply strict rate limiting to all auth routes (5 failed attempts / 15 min)
router.use(authLimiter);

/**
 * POST /api/auth/register
 *
 * Creates a new user account and returns both tokens.
 *
 * Request body: { email, mobile, password, displayName }
 * Success (201): { success, data: { accessToken, refreshToken, user } }
 * Error (400): { status, code, message, fields }
 * Error (409): { status, code, message } — email/mobile already taken
 */
router.post('/register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, mobile, password, displayName } = req.body;
    const result = await registerUser({ email, mobile, password, displayName });

    // 201 Created — new resource (user) was created
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/login
 *
 * Authenticates an existing user and returns both tokens.
 *
 * Request body: { email, password }
 * Success (200): { success, data: { accessToken, refreshToken, user } }
 * Error (401): Invalid credentials (generic — no hint about which field is wrong)
 * Error (401): Account locked (after 5 failed attempts)
 *
 * SECURITY: The error message is IDENTICAL whether:
 * - Email doesn't exist
 * - Password is wrong
 * - Both are wrong
 * This prevents "user enumeration" attacks.
 */
router.post('/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'Email and password are required',
        retryable: false,
      });
      return;
    }

    const result = await loginUser({ email, password });
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/refresh
 *
 * Uses a valid refresh token to issue a new access token.
 * The refresh token itself is NOT rotated (stays the same until logout/expiry).
 *
 * Request body: { refreshToken }
 * Success (200): { success, data: { accessToken, accessTokenExpiresAt } }
 * Error (401): Invalid or expired refresh token
 */
router.post('/refresh', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      res.status(400).json({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'refreshToken is required',
        retryable: false,
      });
      return;
    }

    const result = await refreshAccessToken(refreshToken);
    res.status(200).json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/logout
 *
 * Invalidates the refresh token. The access token will expire naturally (15min).
 *
 * Request body: { refreshToken }
 * Success (200): { success, message }
 */
router.post('/logout', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      res.status(400).json({
        status: 400,
        code: 'VALIDATION_ERROR',
        message: 'refreshToken is required',
        retryable: false,
      });
      return;
    }

    await logout(refreshToken);
    res.status(200).json({ success: true, message: 'Logged out successfully' });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/auth/me
 *
 * Retrieve the current user's profile information.
 * Requires authentication.
 */
router.get('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.userId },
      select: {
        id: true,
        email: true,
        mobile: true,
        displayName: true,
        createdAt: true,
      },
    });

    if (!user) {
      res.status(404).json({
        status: 404,
        code: 'NOT_FOUND',
        message: 'User not found',
        retryable: false,
      });
      return;
    }

    res.status(200).json({ success: true, data: user });
  } catch (error) {
    next(error);
  }
});

export { router as authRouter };
