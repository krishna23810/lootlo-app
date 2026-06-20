/**
 * Token Utilities — Generates, verifies, and manages auth tokens + cookies.
 *
 * WHY a separate file?
 * - Token logic is reused in multiple places (register, login, refresh, middleware)
 * - Keeps auth.service.ts focused on business logic, not JWT/cookie details
 * - Easy to test token generation/verification independently
 *
 * TOKEN TYPES:
 * ────────────
 * • Access Token  — JWT signed with JWT_SECRET, short-lived (15 min)
 *                   Sent with every API request to prove identity
 *
 * • Refresh Token — JWT signed with JWT_REFRESH_SECRET (different key!), long-lived (7 days)
 *                   Used ONLY to get a new access token when the old one expires
 *
 * WHY different secrets for access vs refresh?
 * If one secret is compromised, the other token type remains safe.
 * An attacker with the access secret can't forge refresh tokens and vice versa.
 *
 * COOKIE STRATEGY:
 * ────────────────
 * Tokens are stored in HTTP-only cookies (not localStorage).
 * - httpOnly: true  → JavaScript can't read them (XSS attacks can't steal tokens)
 * - secure: true    → Only sent over HTTPS (production)
 * - sameSite: strict → Not sent with cross-site requests (CSRF protection)
 */

import jwt from 'jsonwebtoken';
import { Response } from 'express';

// ─── Environment Variables ───────────────────────────────────────────────────

const JWT_SECRET = process.env.JWT_SECRET || 'dev-access-secret';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'dev-refresh-secret';
const NODE_ENV = process.env.NODE_ENV || 'development';

// ─── Token Generation ────────────────────────────────────────────────────────

/**
 * Generate a short-lived access token (15 min default).
 *
 * @param userId - The user's ID to embed in the token payload
 * @returns JWT string — send this to the client
 *
 * WHAT'S INSIDE THE TOKEN (payload):
 * { userId: "abc-123", iat: 1719000000, exp: 1719000900 }
 * iat = "issued at" (unix timestamp)
 * exp = "expires at" (iat + 15 minutes)
 */
export const generateAccessToken = (userId: string): string => {
  return jwt.sign(
    { userId },
    JWT_SECRET,
    { expiresIn: '15m' } as jwt.SignOptions,
  );
};

/**
 * Generate a long-lived refresh token (7 days default, 30 days if "remember me").
 *
 * @param userId - The user's ID
 * @param expiresIn - Custom expiry (e.g., '30d' for remember me)
 * @returns JWT string — stored securely, used only at /api/auth/refresh
 *
 * WHY also a JWT (not random string)?
 * - We can verify it without a database lookup (faster)
 * - It's self-contained: if it's expired, jwt.verify() throws automatically
 * - But we ALSO store a hash in DB so we can revoke it on logout
 */
export const generateRefreshToken = (userId: string, expiresIn: string | null = null): string => {
  return jwt.sign(
    { userId },
    JWT_REFRESH_SECRET,
    { expiresIn: expiresIn || '7d' } as jwt.SignOptions,
  );
};

// ─── Token Verification ──────────────────────────────────────────────────────

/**
 * Verify an access token and extract the payload.
 *
 * @returns { userId: string } if valid
 * @throws if token is expired, tampered, or invalid
 */
export const verifyAccessToken = (token: string): { userId: string } => {
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
    return decoded;
  } catch {
    throw new Error('Invalid access token');
  }
};

/**
 * Verify a refresh token and extract the payload.
 *
 * @returns { userId: string } if valid
 * @throws if token is expired, tampered, or invalid
 *
 * NOTE: Even if this passes, you should ALSO check the DB
 * to confirm the token hasn't been revoked (logout).
 */
export const verifyRefreshToken = (token: string): { userId: string } => {
  try {
    const decoded = jwt.verify(token, JWT_REFRESH_SECRET) as { userId: string };
    return decoded;
  } catch {
    throw new Error('Invalid refresh token');
  }
};

// ─── Cookie Management ───────────────────────────────────────────────────────

/**
 * Set both auth tokens as HTTP-only cookies on the response.
 *
 * WHY cookies instead of sending tokens in response body?
 * - HttpOnly cookies can't be accessed by JavaScript → immune to XSS attacks
 * - Automatically sent with every request → no manual header management
 * - sameSite: 'strict' prevents CSRF attacks
 *
 * @param res - Express response object
 * @param accessToken - The JWT access token
 * @param refreshToken - The JWT refresh token
 * @param remember - If true, refresh token lasts 30 days instead of 7
 */
export const setAuthCookies = (
  res: Response,
  accessToken: string,
  refreshToken: string,
  remember: boolean = false,
): void => {
  // Access token cookie — expires in 15 minutes
  res.cookie('accessToken', accessToken, {
    httpOnly: true,                          // JS can't read this cookie
    secure: NODE_ENV === 'production',       // HTTPS only in production
    sameSite: 'strict',                      // Not sent with cross-site requests
    maxAge: 15 * 60 * 1000,                 // 15 minutes in milliseconds
  });

  // Refresh token cookie — 7 days (or 30 days with "remember me")
  const refreshMaxAge = remember
    ? 30 * 24 * 60 * 60 * 1000   // 30 days
    : 7 * 24 * 60 * 60 * 1000;   // 7 days

  res.cookie('refreshToken', refreshToken, {
    httpOnly: true,
    secure: NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: refreshMaxAge,
  });
};

/**
 * Clear auth cookies — used during logout.
 *
 * Sets both cookies to empty strings with an expired date.
 * The browser will delete them immediately.
 */
export const clearAuthCookies = (res: Response): void => {
  res.cookie('accessToken', '', {
    httpOnly: true,
    expires: new Date(0),   // Expired = browser deletes it
  });

  res.cookie('refreshToken', '', {
    httpOnly: true,
    expires: new Date(0),
  });
};
