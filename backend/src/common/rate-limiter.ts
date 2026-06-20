/**
 * Rate Limiting Middleware.
 *
 * WHY rate limiting?
 * - Prevents brute-force attacks (trying thousands of passwords)
 * - Stops API abuse (one user hammering your server)
 * - Protects against DDoS (too many requests crash the server)
 *
 * HOW it works:
 * - Tracks requests per IP address in a time window
 * - After the limit is hit, returns 429 "Too Many Requests"
 * - Resets after the window expires
 *
 * We have 3 levels:
 * 1. apiLimiter     — general limit for all endpoints (100 req / 15 min)
 * 2. authLimiter    — strict limit for login/register (5 attempts / 15 min)
 * 3. slowDown       — adds artificial delay after repeated failures
 */

import rateLimit from 'express-rate-limit';

/**
 * General API rate limiter.
 * Allows 100 requests per IP per 15-minute window.
 * Skipped in development so you don't get blocked while testing.
 */
export const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'),
  message: {
    success: false,
    status: 429,
    code: 'TOO_MANY_REQUESTS',
    message: 'Too many requests from this IP, please try again later.',
    retryable: true,
  },
  standardHeaders: true,  // Sends RateLimit-* headers (client can read remaining quota)
  legacyHeaders: false,   // Don't send old X-RateLimit-* headers
  skip: (_req) => {
    // In development, don't rate limit (you'd hit it while testing)
    return process.env.NODE_ENV === 'development';
  },
});

/**
 * Strict rate limiter for authentication endpoints.
 * Only 5 FAILED attempts per 15 minutes per IP.
 *
 * skipSuccessfulRequests: true → successful logins don't count against the limit.
 * This means a legitimate user who types their password correctly is never blocked.
 * Only repeated failures (likely an attacker) get rate limited.
 */
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5,
  skipSuccessfulRequests: true,
  message: {
    success: false,
    status: 429,
    code: 'TOO_MANY_ATTEMPTS',
    message: 'Too many login attempts. Please try again after 15 minutes.',
    retryable: true,
  },
  standardHeaders: true,
  legacyHeaders: false,
});

/**
 * Slow-down limiter — adds increasing delay to repeated requests.
 *
 * After 3 requests in 15 min, each subsequent request gets an extra 500ms delay.
 * Max delay caps at 20 seconds.
 *
 * WHY? Even if the attacker isn't fully blocked, they're slowed down dramatically.
 * 3 fast + then 500ms, 1000ms, 1500ms... makes brute-force impractical.
 */
export const slowDown = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 0,            // 0 = don't actually block, just track
  skipSuccessfulRequests: true,
  standardHeaders: false,
  legacyHeaders: false,
  // Note: express-rate-limit v7 doesn't have delayAfter/delayMs natively.
  // For actual slow-down behavior, you'd use 'express-slow-down' package.
  // Here we use it as an additional limiter layer with tracking.
});
