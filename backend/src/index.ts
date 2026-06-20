/**
 * Express Application Entry Point.
 *
 * HOW EXPRESS WORKS:
 * Express processes requests through a pipeline of "middleware" in ORDER:
 *   1. express.json() — parses JSON body from the request
 *   2. Route handlers — matches URL pattern and runs the handler
 *   3. Error handler — catches any errors thrown by handlers
 *
 * Think of it like a water pipe: the request flows through each layer.
 * If a layer calls next(), it passes to the next layer.
 * If a layer sends res.json(), the flow stops — response is sent.
 */

import express from 'express';
import cors from 'cors';
import { authRouter } from './auth/auth.router';
import { gameRouter } from './game/game.router';
import { walletRouter } from './wallet/wallet.router';
import { ticketRouter } from './ticket/ticket.router';
import { adminRouter } from './admin/admin.router';
import { errorHandler } from './common/error-handler';
import { apiLimiter } from './common/rate-limiter';

const app = express();
const PORT = process.env.PORT || 3000;

// ─── Middleware Pipeline ─────────────────────────────────────────────────────

// Parse JSON bodies (client sends { "email": "...", "password": "..." })
// After this middleware, req.body contains the parsed object
app.use(express.json());

// Enable CORS for admin panel and Flutter app
app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000', 'http://10.0.2.2:3000'],
  credentials: true,
}));

// Apply general rate limiting to all routes
app.use(apiLimiter);

// ─── Routes ──────────────────────────────────────────────────────────────────

// Health check — used by load balancers to verify the server is alive
app.get('/health', (_req, res) => {
  res.json({ status: 'ok' });
});

// Auth routes — prefixed with /api/auth
// So authRouter's '/register' becomes '/api/auth/register'
app.use('/api/auth', authRouter);

// Game routes — prefixed with /api/games
app.use('/api/games', gameRouter);

// Wallet routes — prefixed with /api/wallet
app.use('/api/wallet', walletRouter);

// Ticket routes — prefixed with /api/tickets
app.use('/api/tickets', ticketRouter);

// Admin routes — prefixed with /api/admin (all require admin auth)
app.use('/api/admin', adminRouter);

// ─── Error Handler (MUST be last) ────────────────────────────────────────────
// Express requires error handlers to be registered AFTER all routes.
// Any error thrown or passed via next(error) ends up here.
app.use(errorHandler);

// ─── Start Server ────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`Lootlo backend running on port ${PORT}`);
});

export default app;
