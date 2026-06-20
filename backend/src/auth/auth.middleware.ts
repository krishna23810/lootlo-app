/**
 * Auth Middleware — verifies access tokens on protected routes.
 *
 * HOW IT WORKS:
 * 1. Client sends request with header: Authorization: Bearer <accessToken>
 * 2. Middleware extracts the token from the header
 * 3. Verifies the JWT signature (was it really signed by our server?)
 * 4. Checks if the token is expired
 * 5. Optionally checks Redis session (for extra security — can revoke mid-flight)
 * 6. Attaches user info to the request so route handlers can use it
 *
 * WHY middleware?
 * Instead of copy-pasting token verification in every route handler,
 * we define it ONCE and apply it to any route that needs auth.
 * This is the "DRY" principle — Don't Repeat Yourself.
 */

import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { unauthorizedError, forbiddenError } from '../common/errors';
import { getSession } from './session-store';
import { AdminRole } from '../common/types';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';

// Extend Express Request type to include our custom `user` field
// This is TypeScript "declaration merging" — adds fields to an existing type
declare global {
  namespace Express {
    interface Request {
      user?: {
        userId: string;
        email: string;
        isAdmin?: boolean;
        adminRole?: AdminRole;
      };
    }
  }
}

/**
 * Middleware: Require a valid access token.
 * Use on any route that needs an authenticated user.
 *
 * Usage: router.get('/protected', requireAuth, (req, res) => { ... })
 */
export async function requireAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    // ── Extract token from "Authorization: Bearer <token>" header ──────
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw unauthorizedError('Access token is required');
    }

    // Split "Bearer eyJhbG..." → ["Bearer", "eyJhbG..."]
    const token = authHeader.split(' ')[1];

    if (!token) {
      throw unauthorizedError('Access token is required');
    }

    // ── Verify JWT signature and expiry ───────────────────────────────────
    // jwt.verify() does two things:
    // 1. Checks the signature (was it signed with our JWT_SECRET?)
    // 2. Checks expiry (is `exp` claim in the future?)
    // If either fails, it throws an error
    const payload = jwt.verify(token, JWT_SECRET) as { userId: string; email: string; type: string; isAdmin?: boolean; adminRole?: string };

    // Make sure it's an access token (not a different type)
    if (payload.type !== 'access') {
      throw unauthorizedError('Invalid token type');
    }

    // ── Check Redis session (skip for admin tokens — they don't use Redis sessions)
    if (!payload.isAdmin) {
      const session = await getSession(token);
      if (!session) {
        throw unauthorizedError('Session expired or invalidated');
      }
    }

    // ── Attach user info to request ──────────────────────────────────────
    req.user = {
      userId: payload.userId,
      email: payload.email,
      isAdmin: payload.isAdmin,
      adminRole: payload.adminRole as AdminRole | undefined,
    };

    next(); // Continue to the route handler
  } catch (error) {
    // JWT verify throws specific errors for expired/invalid tokens
    if (error instanceof jwt.TokenExpiredError) {
      next(unauthorizedError('Access token has expired'));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(unauthorizedError('Invalid access token'));
    } else {
      next(error);
    }
  }
}

/**
 * Middleware: Require admin role.
 * Must be used AFTER requireAuth (needs req.user to exist).
 *
 * For now, we check a simple flag. Later this will check the Admin table.
 * Usage: router.post('/admin-only', requireAuth, requireAdmin, handler)
 *
 * TODO: Once admin auth is fully implemented, this will verify against
 * the Admin model with proper role-based access control.
 */
export function requireAdmin(req: Request, _res: Response, next: NextFunction): void {
  // For now, check if request has admin flag (set by admin login flow)
  if (!req.user?.isAdmin) {
    next(forbiddenError('Admin access required'));
    return;
  }
  next();
}
