import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/background_notification_service.dart';
import 'data/services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local storage with error handling
  try {
    await LocalStorageService.initialize();
  } catch (e) {
    debugPrint('Hive init failed: $e');
  }

  // Initialize background notification sync
  try {
    await BackgroundNotificationService.initialize();
    
    // Request permission (POST_NOTIFICATIONS on Android 13+)
    await BackgroundNotificationService.requestPermissions();

    // Send credentials to background service if already logged in
    final userId = LocalStorageService.getUserId();
    final token = LocalStorageService.getToken();
    if (userId != null && token != null) {
      BackgroundNotificationService.sendCredentials(userId, token);
    }
  } catch (e) {
    debugPrint('Background sync initialization failed: $e');
  }

  runApp(
    const ProviderScope(
      child: LiveHousieApp(),
    ),
  );
}

/// Root application widget wrapped in Riverpod ProviderScope.
class LiveHousieApp extends ConsumerWidget {
  const LiveHousieApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Lootlo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
