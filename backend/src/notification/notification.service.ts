/**
 * Notification Service — self-hosted push notification system.
 *
 * HOW IT WORKS (no Firebase, no third-party):
 * ───────────────────────────────────────────
 * 1. Backend creates a notification → stores it in PostgreSQL
 * 2. If user is ONLINE (connected via Socket.io) → push immediately via WebSocket
 * 3. If user is OFFLINE → notification waits in DB
 * 4. When user reconnects → fetch all unread notifications and deliver them
 *
 * WHY store in DB instead of just WebSocket?
 * - User might be offline when notification fires
 * - User wants to see notification history
 * - Notifications can be marked as read
 * - Server restarts don't lose pending notifications
 *
 * THE DELIVERY STRATEGY:
 * ┌─────────────┐     ┌──────────────┐
 * │   Backend   │────→│  PostgreSQL  │  (store notification)
 * │  (trigger)  │     └──────────────┘
 * │             │────→│  Socket.io   │  (push to online user)
 * └─────────────┘     └──────────────┘
 *
 * For background/lock-screen notifications on Android without FCM:
 * The Flutter app maintains a foreground service with a persistent Socket.io
 * connection. When a WebSocket message arrives, the app creates a local
 * notification using flutter_local_notifications package.
 */

import { prisma } from '../common/prisma';
import { Prisma } from '@prisma/client';
import crypto from 'crypto';

// This will be set by the Socket.io server when it initializes
// Allows this service to push to connected users
let socketIO: { to: (room: string) => { emit: (event: string, data: unknown) => void } } | null = null;

/**
 * Set the Socket.IO server instance.
 * Called once during app startup after Socket.IO is initialized.
 */
export function setSocketIO(io: typeof socketIO): void {
  socketIO = io;
}

/**
 * Broadcast an event to all sockets in a room.
 */
export function broadcastToRoom(room: string, event: string, data: unknown): void {
  if (socketIO) {
    socketIO.to(room).emit(event, data);
  } else {
    console.warn(`[Socket.io] Cannot broadcast to room ${room}: socketIO not initialized`);
  }
}

// ─── Types ───────────────────────────────────────────────────────────────────

export interface CreateNotificationInput {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

// ─── Send Notification ───────────────────────────────────────────────────────

/**
 * Create and send a notification to a user.
 *
 * FLOW:
 * 1. Save to database (persistent — survives server restarts)
 * 2. Try to deliver via WebSocket (instant — if user is online)
 *
 * The Socket.IO "room" concept:
 * Each user joins a room named "user:{userId}" when they connect.
 * So we can target a specific user by emitting to their room.
 */
export async function sendNotification(input: CreateNotificationInput): Promise<void> {
  // Step 1: Persist in database
  const notification = await prisma.notification.create({
    data: {
      userId: input.userId,
      type: input.type as never, // Prisma enum type
      title: input.title,
      body: input.body,
      data: (input.data ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      isRead: false,
    },
  });

  // Step 2: Push via WebSocket if user is online
  if (socketIO) {
    socketIO.to(`user:${input.userId}`).emit('notification:new', {
      id: notification.id,
      type: notification.type,
      title: notification.title,
      body: notification.body,
      data: notification.data,
      createdAt: notification.createdAt.toISOString(),
    });
  }
}

/**
 * Send notification to multiple users at once.
 * Useful for "game starting soon" — notify all ticket holders.
 */
export async function sendBulkNotification(
  userIds: string[],
  type: string,
  title: string,
  body: string,
  data?: Record<string, unknown>,
): Promise<void> {
  // Create all notifications in one batch (efficient DB operation)
  await prisma.notification.createMany({
    data: userIds.map((userId) => ({
      userId,
      type: type as never,
      title,
      body,
      data: (data ?? Prisma.JsonNull) as Prisma.InputJsonValue,
      isRead: false,
    })),
  });

  // Push to all online users
  if (socketIO) {
    for (const userId of userIds) {
      socketIO.to(`user:${userId}`).emit('notification:new', {
        id: crypto.randomUUID(),
        userId,
        type,
        title,
        body,
        data,
        isRead: false,
        createdAt: new Date().toISOString(),
      });
    }
  }
}

// ─── Read Notifications ──────────────────────────────────────────────────────

/**
 * Get unread notifications for a user.
 * Called when user opens the app or navigates to notifications screen.
 */
export async function getUnreadNotifications(userId: string) {
  return prisma.notification.findMany({
    where: { userId, isRead: false },
    orderBy: { createdAt: 'desc' },
    take: 50, // Max 50 unread at a time
  });
}

/**
 * Get all notifications with pagination.
 */
export async function getNotifications(userId: string, page: number, pageSize: number) {
  const [notifications, total] = await Promise.all([
    prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    }),
    prisma.notification.count({ where: { userId } }),
  ]);

  return { notifications, total, page, pageSize };
}

/**
 * Mark a notification as read.
 */
export async function markAsRead(notificationId: string, userId: string): Promise<void> {
  await prisma.notification.updateMany({
    where: { id: notificationId, userId }, // userId check prevents reading others' notifications
    data: { isRead: true },
  });
}

/**
 * Mark all notifications as read for a user.
 */
export async function markAllAsRead(userId: string): Promise<void> {
  await prisma.notification.updateMany({
    where: { userId, isRead: false },
    data: { isRead: true },
  });
}
