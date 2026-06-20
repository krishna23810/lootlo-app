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
import '../../features/wallet/views/wallet_screen.dart';
import '../../features/live_session/views/live_session_screen.dart';

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
  static const String wallet = '/wallet';
  static const String liveSession = '/games/:gameId/live';
}

@riverpod
GoRouter appRouter(Ref ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.games,
        name: 'games',
        builder: (context, state) => const GameListScreen(),
      ),
      GoRoute(
        path: AppRoutes.gameDetail,
        name: 'gameDetail',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          return GameDetailScreen(gameId: gameId);
        },
      ),
      GoRoute(
        path: AppRoutes.tickets,
        name: 'tickets',
        builder: (context, state) => const TicketListScreen(),
      ),
      GoRoute(
        path: AppRoutes.ticket,
        name: 'ticket',
        builder: (context, state) {
          final ticketId = state.pathParameters['ticketId']!;
          return TicketViewScreen(ticketId: ticketId);
        },
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.liveSession,
        name: 'liveSession',
        builder: (context, state) {
          final gameId = state.pathParameters['gameId']!;
          return LiveSessionScreen(gameId: gameId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
