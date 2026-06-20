/**
 * Global Error Handler Middleware for Express.
 *
 * HOW IT WORKS:
 * When any route handler calls `next(error)` or throws inside an async handler,
 * Express skips all remaining route handlers and jumps to this middleware.
 *
 * WHY?
 * Without this, each route would need its own try/catch with error formatting.
 * With this, routes just throw errors and this middleware formats them consistently.
 *
 * Express knows this is an error handler because it has 4 parameters (err, req, res, next).
 */

import { Request, Response, NextFunction } from 'express';
import { AppError, ErrorResponse } from './errors';

export function errorHandler(
  err: Error,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  // If it's our custom AppError, we already have a nicely formatted response
  if (err instanceof AppError) {
    const response: ErrorResponse = err.response;
    res.status(response.status).json(response);
    return;
  }

  // For unexpected errors (bugs, unhandled exceptions), return a generic 500
  // NEVER expose internal error details to the client (security risk)
  console.error('[Unhandled Error]', err);

  res.status(500).json({
    status: 500,
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred',
    retryable: true,
  });
}
