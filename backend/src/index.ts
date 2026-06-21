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
import { createServer } from 'http';
import { Server } from 'socket.io';
import { authRouter } from './auth/auth.router';
import { gameRouter } from './game/game.router';
import { walletRouter } from './wallet/wallet.router';
import { ticketRouter } from './ticket/ticket.router';
import { adminRouter } from './admin/admin.router';
import { errorHandler } from './common/error-handler';
import { apiLimiter } from './common/rate-limiter';
import { setSocketIO } from './notification/notification.service';

const app = express();
const PORT = process.env.PORT || 3000;
const server = createServer(app);
const io = new Server(server, {
  cors: {
    origin: ['http://localhost:5173', 'http://localhost:3000', 'http://10.0.2.2:3000', 'https://unworn-embassy-glowworm.ngrok-free.dev', 'https://admin.kktechsolution.app'],
    credentials: true,
  }
});

// ─── Middleware Pipeline ─────────────────────────────────────────────────────

app.use(express.json());

app.use(cors({
  origin: ['http://localhost:5173', 'http://localhost:3000', 'http://10.0.2.2:3000', 'https://unworn-embassy-glowworm.ngrok-free.dev', 'https://admin.kktechsolution.app'],
  credentials: true,
}));

app.use(apiLimiter);

// ─── Routes ──────────────────────────────────────────────────────────────────

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

// ─── Janus Reverse Proxy ──────────────────────────────────────────────────────
// Proxy /janus/* requests to the local Janus Gateway so a single tunnel can serve both API and WebRTC signaling
const JANUS_INTERNAL_URL = process.env.JANUS_URL || 'http://localhost:8088';

app.use('/janus', async (req, res) => {
  const targetUrl = `${JANUS_INTERNAL_URL}${req.originalUrl}`;
  try {
    const fetchOptions: RequestInit = {
      method: req.method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      fetchOptions.body = JSON.stringify(req.body);
    }
    const proxyRes = await fetch(targetUrl, fetchOptions);
    const data = await proxyRes.json();
    res.status(proxyRes.status).json(data);
  } catch (err: any) {
    console.error('[Janus Proxy] Error:', err.message);
    res.status(502).json({ error: 'Janus gateway unreachable' });
  }
});

// ─── Error Handler (MUST be last) ────────────────────────────────────────────
// Express requires error handlers to be registered AFTER all routes.
// Any error thrown or passed via next(error) ends up here.
app.use(errorHandler);

// ─── Socket.io Connection ────────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);

  socket.on('join', (room: string) => {
    socket.join(room);
    console.log(`Socket ${socket.id} joined room ${room}`);
  });

  socket.on('chat:send', (data: { room: string; message: string; displayName: string }) => {
    io.to(data.room).emit('chat:message', {
      userId: socket.id,
      displayName: data.displayName,
      message: data.message,
      timestamp: new Date().toISOString(),
    });
  });

  socket.on('disconnect', () => {
    console.log(`Socket disconnected: ${socket.id}`);
  });
});

setSocketIO(io);

// ─── Start Server ────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`Lootlo backend running on port ${PORT}`);
});

export default app;
