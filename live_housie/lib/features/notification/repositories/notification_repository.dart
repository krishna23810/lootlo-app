import '../../../data/repositories/base_repository.dart';
import '../models/notification_model.dart';

/// Repository for notification-related API calls.
///
/// Endpoints:
/// - GET   /api/notifications
/// - GET   /api/notifications/unread
/// - POST  /api/notifications/read
/// - PATCH /api/notifications/:id/read
class NotificationRepository extends BaseRepository {
  /// Get all notifications (paginated) for the user.
  Future<List<NotificationModel>> getNotifications({int page = 1, int pageSize = 20}) async {
    final response = await dio.get('/notifications', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    
    // The response is { success: true, data: { notifications: [...], total: X, ... } }
    final dynamic responseData = response.data['data'];
    if (responseData == null || responseData['notifications'] == null) {
      return [];
    }
    
    final List<dynamic> listJson = responseData['notifications'] as List<dynamic>;
    return listJson.map((json) => NotificationModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get unread notifications for the user.
  Future<List<NotificationModel>> getUnreadNotifications() async {
    final response = await dio.get('/notifications/unread');
    
    final List<dynamic> listJson = response.data['data'] as List<dynamic>;
    return listJson.map((json) => NotificationModel.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Mark all notifications as read.
  Future<void> markAllAsRead() async {
    await dio.post('/notifications/read');
  }

  /// Mark a single notification as read.
  Future<void> markAsRead(String id) async {
    await dio.patch('/notifications/$id/read');
  }
}
