/**
 * Auth Service — handles user registration, login, and session management.
 *
 * TOKEN STRATEGY (Access + Refresh):
 * ─────────────────────────────────
 * • Access Token  = JWT, short-lived (15 min), sent with every API request
 * • Refresh Token = random string, long-lived (7 days), stored in DB
 *
 * WHY two tokens?
 * - Access token is short → if stolen, attacker has only 15 min window
 * - Refresh token is long → user doesn't have to login every 15 min
 * - Refresh token is sent to ONLY one endpoint → less exposure
 * - On logout, delete refresh token → can't get new access tokens
 */

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { prisma } from '../common/prisma';
import { validateRegistration } from '../common/validators';
import { validationError, conflictError, unauthorizedError } from '../common/errors';
import { storeSession } from './session-store';

// ─── Constants ───────────────────────────────────────────────────────────────

const BCRYPT_ROUNDS = 12;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';

/**
 * ACCESS_TOKEN_EXPIRY: Short-lived — forces frequent refresh.
 * If stolen, damage is limited to this window.
 */
const ACCESS_TOKEN_EXPIRY = '15m'; // 15 minutes
const ACCESS_TOKEN_EXPIRY_MS = 15 * 60 * 1000;

/**
 * REFRESH_TOKEN_EXPIRY: Long-lived — keeps user logged in.
 * Stored in database so it can be revoked (unlike JWT which can't be revoked).
 */
const REFRESH_TOKEN_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000; // 7 days

// ─── Types ───────────────────────────────────────────────────────────────────

export interface RegisterInput {
  email: string;
  mobile: string;
  password: string;
  displayName: string;
}

export interface AuthTokens {
  accessToken: string;
  accessTokenExpiresAt: Date;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
  user: {
    id: string;
    email: string;
    mobile: string;
    displayName: string;
    createdAt: Date;
  };
}

// ─── Token Generation Helpers ────────────────────────────────────────────────

/**
 * Generate a short-lived JWT access token.
 *
 * Contains userId and email in the payload.
 * Expires in 15 minutes — client must refresh before then.
 */
function generateAccessToken(userId: string, email: string): { token: string; expiresAt: Date } {
  const token = jwt.sign(
    { userId, email, type: 'access' },
    JWT_SECRET,
    { expiresIn: ACCESS_TOKEN_EXPIRY },
  );
  const expiresAt = new Date(Date.now() + ACCESS_TOKEN_EXPIRY_MS);
  return { token, expiresAt };
}

/**
 * Generate a random refresh token.
 *
 * WHY not JWT for refresh token?
 * - Refresh tokens are stored in the database — we look them up, not decode them
 * - A random string is simpler and just as secure for a lookup-based token
 * - crypto.randomBytes(40) gives us 40 random bytes → 80 hex chars → very hard to guess
 */
function generateRefreshToken(): { token: string; expiresAt: Date } {
  const token = crypto.randomBytes(40).toString('hex');
  const expiresAt = new Date(Date.now() + REFRESH_TOKEN_EXPIRY_MS);
  return { token, expiresAt };
}

// ─── Registration ────────────────────────────────────────────────────────────

/**
 * Register a new user account.
 *
 * FLOW:
 * 1. Validate all input fields
 * 2. Check if email or mobile already exists
 * 3. Hash the password with bcrypt
 * 4. Create user + wallet atomically
 * 5. Generate access token (JWT, 15min) + refresh token (random, 7 days)
 * 6. Store refresh token in database + session in Redis
 * 7. Return both tokens and user info
 */
export async function registerUser(input: RegisterInput): Promise<AuthTokens> {
  const { email, mobile, password, displayName } = input;

  // ── Step 1: Validate input ──────────────────────────────────────────────
  const validation = validateRegistration(email, mobile, password, displayName);
  if (!validation.valid) {
    throw validationError('Registration validation failed', validation.errors);
  }

  // ── Step 2: Check uniqueness ────────────────────────────────────────────
  const existingUser = await prisma.user.findFirst({
    where: {
      OR: [
        { email: { equals: email, mode: 'insensitive' } },
        { mobile: mobile },
      ],
    },
  });

  if (existingUser) {
    if (existingUser.email.toLowerCase() === email.toLowerCase()) {
      throw conflictError('Email is already registered');
    }
    if (existingUser.mobile === mobile) {
      throw conflictError('Mobile number is already registered');
    }
  }

  // ── Step 3: Hash password ───────────────────────────────────────────────
  const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

  // ── Step 4: Create user + wallet atomically ─────────────────────────────
  const user = await prisma.user.create({
    data: {
      email: email.toLowerCase(),
      mobile,
      passwordHash,
      displayName,
      wallet: {
        create: {
          balanceCents: BigInt(0),
          heldAmountCents: BigInt(0),
        },
      },
    },
  });

  // ── Step 5: Generate both tokens ────────────────────────────────────────
  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = generateRefreshToken();

  // ── Step 6: Store refresh token in DB + session in Redis ────────────────
  // Store refresh token in database — this lets us:
  // - Revoke it on logout (delete the row)
  // - Detect stolen tokens (if used after revocation)
  // - Track all active sessions for a user
  await prisma.session.create({
    data: {
      userId: user.id,
      tokenHash: crypto.createHash('sha256').update(refreshToken.token).digest('hex'),
      expiresAt: refreshToken.expiresAt,
      isValid: true,
    },
  });

  // Also store access token session in Redis for quick validation
  // Redis TTL auto-deletes it after 15 min
  await storeSession(user.id, accessToken.token, Math.floor(ACCESS_TOKEN_EXPIRY_MS / 1000));

  // ── Step 7: Return result ───────────────────────────────────────────────
  return {
    accessToken: accessToken.token,
    accessTokenExpiresAt: accessToken.expiresAt,
    refreshToken: refreshToken.token,
    refreshTokenExpiresAt: refreshToken.expiresAt,
    user: {
      id: user.id,
      email: user.email,
      mobile: user.mobile,
      displayName: user.displayName,
      createdAt: user.createdAt,
    },
  };
}

// ─── Login ───────────────────────────────────────────────────────────────────

export interface LoginInput {
  email: string;
  password: string;
}

/**
 * Login an existing user.
 *
 * FLOW:
 * 1. Find user by email (case-insensitive)
 * 2. Check if account is locked (too many failed attempts)
 * 3. Compare password with stored hash using bcrypt
 * 4. On failure: increment failed attempts, check lockout threshold
 * 5. On success: reset failed attempts, generate tokens
 *
 * SECURITY NOTES:
 * - We return a GENERIC error on failure — never say "email not found" vs "wrong password"
 *   WHY? If we say "email not found", attacker knows that email ISN'T registered.
 *   If we say "wrong password", attacker knows the email IS registered.
 *   Generic error reveals nothing.
 * - Account lockout: after 5 failed attempts, lock for 15 minutes
 *   This makes brute-force impractical (5 attempts every 15 min = 480/day max)
 */
export async function loginUser(input: LoginInput): Promise<AuthTokens> {
  const { email, password } = input;

  // ── Step 1: Find user ───────────────────────────────────────────────────
  const user = await prisma.user.findFirst({
    where: { email: { equals: email, mode: 'insensitive' } },
  });

  // If user doesn't exist, return generic error (don't reveal "email not found")
  if (!user) {
    throw unauthorizedError('Invalid email or password');
  }

  // ── Step 2: Check account lockout ───────────────────────────────────────
  // lockedUntil is a timestamp — if it's in the future, account is locked
  if (user.lockedUntil && user.lockedUntil > new Date()) {
    throw unauthorizedError('Account is temporarily locked. Try again later.');
  }

  // ── Step 3: Compare password ────────────────────────────────────────────
  // bcrypt.compare(plainPassword, storedHash):
  // - Extracts the salt from the hash
  // - Hashes the plain password with that same salt
  // - Compares the result with the stored hash
  // - Returns true if they match, false otherwise
  const passwordValid = await bcrypt.compare(password, user.passwordHash);

  if (!passwordValid) {
    // ── Step 4: Handle failed attempt ─────────────────────────────────────
    const newAttemptCount = user.failedLoginAttempts + 1;

    // Lock account after 5 consecutive failures
    const lockData = newAttemptCount >= 5
      ? { failedLoginAttempts: newAttemptCount, lockedUntil: new Date(Date.now() + 15 * 60 * 1000) }
      : { failedLoginAttempts: newAttemptCount };

    await prisma.user.update({
      where: { id: user.id },
      data: lockData,
    });

    // Same generic error — attacker can't distinguish "wrong password" from "no account"
    throw unauthorizedError('Invalid email or password');
  }

  // ── Step 5: Success — reset failed attempts ─────────────────────────────
  // Reset counter on successful login so previous failures don't carry over
  if (user.failedLoginAttempts > 0 || user.lockedUntil) {
    await prisma.user.update({
      where: { id: user.id },
      data: { failedLoginAttempts: 0, lockedUntil: null },
    });
  }

  // ── Step 6: Generate tokens (same as registration) ──────────────────────
  const accessToken = generateAccessToken(user.id, user.email);
  const refreshToken = generateRefreshToken();

  // Store refresh token in DB
  await prisma.session.create({
    data: {
      userId: user.id,
      tokenHash: crypto.createHash('sha256').update(refreshToken.token).digest('hex'),
      expiresAt: refreshToken.expiresAt,
      isValid: true,
    },
  });

  // Store access token in Redis
  await storeSession(user.id, accessToken.token, Math.floor(ACCESS_TOKEN_EXPIRY_MS / 1000));

  return {
    accessToken: accessToken.token,
    accessTokenExpiresAt: accessToken.expiresAt,
    refreshToken: refreshToken.token,
    refreshTokenExpiresAt: refreshToken.expiresAt,
    user: {
      id: user.id,
      email: user.email,
      mobile: user.mobile,
      displayName: user.displayName,
      createdAt: user.createdAt,
    },
  };
}

// ─── Refresh Token ───────────────────────────────────────────────────────────

/**
 * Use a refresh token to get a new access token.
 *
 * FLOW:
 * 1. Hash the incoming refresh token (we store hashes, not raw tokens)
 * 2. Look it up in the database
 * 3. Check it's valid and not expired
 * 4. Generate a new access token
 * 5. Store new access token session in Redis
 * 6. Return new access token (refresh token stays the same)
 *
 * WHY hash the refresh token before lookup?
 * If the database is ever breached, attackers get hashes — not usable tokens.
 */
export async function refreshAccessToken(refreshToken: string): Promise<{
  accessToken: string;
  accessTokenExpiresAt: Date;
}> {
  // Hash the incoming token to look it up
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

  // Find the session in database
  const session = await prisma.session.findFirst({
    where: {
      tokenHash,
      isValid: true,
      expiresAt: { gt: new Date() }, // Not expired
    },
    include: { user: true },
  });

  if (!session) {
    throw unauthorizedError('Invalid or expired refresh token');
  }

  // Generate new access token
  const newAccessToken = generateAccessToken(session.userId, session.user.email);

  // Store in Redis
  await storeSession(session.userId, newAccessToken.token, Math.floor(ACCESS_TOKEN_EXPIRY_MS / 1000));

  return {
    accessToken: newAccessToken.token,
    accessTokenExpiresAt: newAccessToken.expiresAt,
  };
}

// ─── Logout ──────────────────────────────────────────────────────────────────

/**
 * Logout — invalidate the refresh token so no new access tokens can be issued.
 *
 * The current access token will still work until it expires (max 15 min),
 * but no NEW tokens can be obtained. This is the tradeoff of JWT:
 * you can't truly "revoke" a JWT — you can only wait for it to expire.
 */
export async function logout(refreshToken: string): Promise<void> {
  const tokenHash = crypto.createHash('sha256').update(refreshToken).digest('hex');

  await prisma.session.updateMany({
    where: { tokenHash },
    data: { isValid: false },
  });
}
