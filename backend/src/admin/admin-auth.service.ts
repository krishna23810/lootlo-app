/**
 * Admin Auth Service — handles admin login separately from user auth.
 */

import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { prisma } from '../common/prisma';
import { unauthorizedError } from '../common/errors';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';

export interface AdminLoginResult {
  token: string;
  admin: {
    id: string;
    email: string;
    name: string;
    role: string;
  };
}

/**
 * Login an admin user.
 * Returns a JWT token with isAdmin flag set to true.
 */
export async function adminLogin(email: string, password: string): Promise<AdminLoginResult> {
  const admin = await prisma.admin.findUnique({
    where: { email: email.toLowerCase() },
  });

  if (!admin || !admin.isActive) {
    throw unauthorizedError('Invalid admin credentials');
  }

  const passwordValid = await bcrypt.compare(password, admin.passwordHash);
  if (!passwordValid) {
    throw unauthorizedError('Invalid admin credentials');
  }

  // Update last login
  await prisma.admin.update({
    where: { id: admin.id },
    data: { lastLoginAt: new Date() },
  });

  // Generate token with admin flag
  const token = jwt.sign(
    { userId: admin.id, email: admin.email, isAdmin: true, adminRole: admin.role, type: 'access' },
    JWT_SECRET,
    { expiresIn: '8h' }, // Admin tokens last longer (8 hours)
  );

  return {
    token,
    admin: {
      id: admin.id,
      email: admin.email,
      name: admin.name,
      role: admin.role,
    },
  };
}
