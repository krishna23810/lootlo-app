import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/services/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive local storage with error handling
  try {
    await LocalStorageService.initialize();
  } catch (e) {
    debugPrint('Hive init failed: $e');
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
