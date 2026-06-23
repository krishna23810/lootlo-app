import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

part 'notification_viewmodel.g.dart';

/// Notifier that manages list of notifications and unread state.
@riverpod
class Notifications extends _$Notifications {
  final _repository = NotificationRepository();

  @override
  FutureOr<List<NotificationModel>> build() async {
    return await _repository.getNotifications();
  }

  Future<void> fetchNotifications() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getNotifications();
    });
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final currentList = state.value;
    if (currentList == null) return;

    // Optimistically update local UI state
    final updatedList = currentList.map((n) => n.copyWith(isRead: true)).toList();
    state = AsyncValue.data(updatedList);

    try {
      await _repository.markAllAsRead();
    } catch (e) {
      // If failed, restore/refetch
      fetchNotifications();
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String id) async {
    final currentList = state.value;
    if (currentList == null) return;

    final updatedList = currentList.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    state = AsyncValue.data(updatedList);

    try {
      await _repository.markAsRead(id);
    } catch (e) {
      // Ignore or restore
    }
  }

  /// Inserts a new notification received dynamically (e.g. from WebSockets)
  void insertNotification(NotificationModel notification) {
    final currentList = state.value ?? [];
    if (currentList.any((n) => n.id == notification.id)) return; // Avoid duplicates
    
    final updatedList = [notification, ...currentList];
    state = AsyncValue.data(updatedList);
  }
}

/// Derived provider to count unread notifications
@riverpod
int unreadNotificationsCount(Ref ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
}
