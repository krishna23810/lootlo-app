import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/splash/views/splash_screen.dart';
import '../../features/auth/views/login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/game/views/game_list_screen.dart';
import '../../features/game/views/game_detail_screen.dart';
import '../../features/ticket/views/ticket_list_screen.dart';
import '../../features/ticket/views/ticket_view_screen.dart';
import '../../features/ticket/views/game_tickets_screen.dart';
import '../../features/wallet/views/wallet_screen.dart';
import '../../features/live_session/views/live_session_screen.dart';
import '../../features/profile/views/profile_screen.dart';
import '../../features/notification/views/notification_screen.dart';

part 'app_router.g.dart';

/// Route paths used throughout the app.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String games = '/games';
  static const String gameDetail = '/games/:gameId';
  static const String tickets = '/tickets';
  static const String ticket = '/tickets/:ticketId';
  static const String ticketGroup = '/tickets/game/:gameId';
  static const String wallet = '/wallet';
  static const String liveSession = '/games/:gameId/live';
  static const String profile = '/profile';
  static const String notifications = '/notifications';
}

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.games,
        name: 'games',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const GameListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.gameDetail,
        name: 'gameDetail',
        pageBuilder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          // gameName is passed via state.extra when navigating from the list screen
          final extra = state.extra as Map<String, dynamic>?;
          final gameName = extra?['gameName'] as String? ?? gameId;
          return NoTransitionPage(
            key: state.pageKey,
            child: GameDetailScreen(gameId: gameId, gameName: gameName),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tickets,
        name: 'tickets',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const TicketListScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.ticket,
        name: 'ticket',
        pageBuilder: (context, state) {
          final ticketId = state.pathParameters['ticketId']!;
          final extra = state.extra as Map<String, dynamic>?;
          final ticketIndex = extra?['ticketIndex'] as int?;
          return NoTransitionPage(
            key: state.pageKey,
            child: TicketViewScreen(ticketId: ticketId, ticketIndex: ticketIndex),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.ticketGroup,
        name: 'ticketGroup',
        pageBuilder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          final extra = state.extra as Map<String, dynamic>?;
          final gameName = extra?['gameName'] as String? ?? 'Game Tickets';
          return NoTransitionPage(
            key: state.pageKey,
            child: GameTicketsScreen(gameId: gameId, gameName: gameName),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const WalletScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.liveSession,
        name: 'liveSession',
        pageBuilder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          return NoTransitionPage(
            key: state.pageKey,
            child: LiveSessionScreen(gameId: gameId),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          child: const NotificationScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
