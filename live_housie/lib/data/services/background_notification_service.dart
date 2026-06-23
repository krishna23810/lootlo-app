import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'local_storage_service.dart';
import 'websocket_service.dart';

/// Service to handle OS-level notifications when the app is in background or closed.
class BackgroundNotificationService {
  static const String notificationChannelId = 'lootlo_notifications';
  static const String foregroundChannelId = 'lootlo_foreground';
  static const int notificationId = 888;

  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize background service and local notification settings.
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // 1. Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // App opened from background notification
      },
    );

    // Create high-importance and low-importance notification channels for Android
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      // High importance channel for game/wallet updates
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        notificationChannelId,
        'Game & Wallet Updates',
        description: 'Alerts for starting games, pattern claims, and wallet deposits.',
        importance: Importance.max,
        playSound: true,
      ));

      // Low importance channel for the sticky background service notification
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        foregroundChannelId,
        'Background Sync Status',
        description: 'Indicates if the Lootlo background notification listener is running.',
        importance: Importance.low,
      ));
    }

    // 2. Configure the background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: foregroundChannelId,
        initialNotificationTitle: 'Lootlo Service',
        initialNotificationContent: 'Notification listener running...',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    // Start service
    await service.startService();
    debugPrint('[BackgroundNotificationService] Background service configured and started.');
  }

  /// Request permissions for local notifications (needed on Android 13+).
  static Future<void> requestPermissions() async {
    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  /// Broadcast credentials to the background isolate so it knows who to connect for.
  static void sendCredentials(String? userId, String? token) {
    FlutterBackgroundService().invoke('updateCredentials', {
      'userId': userId,
      'token': token,
    });
  }
}

/// Isolate entrypoint for background service.
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  DartPluginRegistrant.ensureInitialized();

  WebSocketService? socketService;
  String? currentUserId;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  // Handle service shutdown cleanly
  service.on('stopService').listen((event) {
    socketService?.disconnect();
    service.stopSelf();
  });

  // Handle credentials updates from the main isolate
  service.on('updateCredentials').listen((event) {
    final userId = event?['userId'] as String?;
    final token = event?['token'] as String?;

    if (userId == null || token == null || userId.isEmpty) {
      debugPrint('[BackgroundIsolate] Credentials cleared. Disconnecting socket.');
      socketService?.disconnect();
      socketService = null;
      currentUserId = null;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Lootlo Status',
          content: 'Logged out. Standing by...',
        );
      }
      return;
    }

    // Only establish a connection if the userId changed or is brand new
    if (currentUserId != userId) {
      debugPrint('[BackgroundIsolate] New user credentials received. Connecting socket...');
      socketService?.disconnect();
      currentUserId = userId;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Lootlo Notifications',
          content: 'Syncing in background...',
        );
      }

      // Initialize zero-dependency websocket service
      socketService = WebSocketService();

      socketService!.on('connect', (_) {
        debugPrint('[BackgroundIsolate] Connected. Joining user room: user:$userId');
        socketService!.emit('join', 'user:$userId');
      });

      socketService!.on('notification:new', (data) {
        debugPrint('[BackgroundIsolate] notification:new received: $data');
        if (data is Map) {
          final title = data['title']?.toString() ?? 'Lootlo Update';
          final body = data['body']?.toString() ?? 'You have a new update.';
          _showSystemNotification(title, body);
        }
      });

      socketService!.on('error', (err) {
        debugPrint('[BackgroundIsolate] Socket error: $err');
      });

      socketService!.on('disconnect', (_) {
        debugPrint('[BackgroundIsolate] Socket disconnected.');
      });

      socketService!.connect();
    }
  });
}

/// Entrypoint callback for iOS background executions.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

/// Helper function to show native OS-level notifications from background isolate.
Future<void> _showSystemNotification(String title, String body) async {
  final localNotifications = FlutterLocalNotificationsPlugin();

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    BackgroundNotificationService.notificationChannelId,
    'Game & Wallet Updates',
    channelDescription: 'Alerts for starting games, pattern claims, and wallet deposits.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
  final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  await localNotifications.show(
    notificationId,
    title,
    body,
    platformDetails,
  );
}
