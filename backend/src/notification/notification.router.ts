import { Router, Request, Response, NextFunction } from 'express';
import { requireAuth } from '../auth/auth.middleware';
import {
  getNotifications,
  getUnreadNotifications,
  markAsRead,
  markAllAsRead,
} from './notification.service';

const router = Router();

// Require auth for all notification endpoints
router.use(requireAuth);

/**
 * GET /api/notifications
 * Returns paginated notifications for the logged-in user.
 */
router.get('/', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const page = parseInt(req.query.page as string, 10) || 1;
    const pageSize = Math.min(parseInt(req.query.pageSize as string, 10) || 20, 100);

    const result = await getNotifications(req.user!.userId, page, pageSize);
    res.json({ success: true, data: result });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/notifications/unread
 * Returns up to 50 unread notifications for the logged-in user.
 */
router.get('/unread', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const notifications = await getUnreadNotifications(req.user!.userId);
    res.json({ success: true, data: notifications });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/notifications/read
 * Marks all notifications for the logged-in user as read.
 */
router.post('/read', async (req: Request, res: Response, next: NextFunction) => {
  try {
    await markAllAsRead(req.user!.userId);
    res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    next(error);
  }
});

/**
 * PATCH /api/notifications/:id/read
 * Marks a single notification as read.
 */
router.patch('/:id/read', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const notificationId = req.params.id;
    await markAsRead(notificationId, req.user!.userId);
    res.json({ success: true, message: 'Notification marked as read' });
  } catch (error) {
    next(error);
  }
});

export { router as notificationRouter };
