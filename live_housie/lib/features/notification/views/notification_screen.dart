import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/notification_model.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  IconData _getIconForType(String type) {
    switch (type) {
      case 'game_start':
      case 'game_live':
      case 'game_started':
      case 'game_starting_soon':
      case 'new_game_announced':
        return Icons.play_circle_filled_rounded;
      case 'game_completed':
      case 'winning':
      case 'pattern_won':
        return Icons.emoji_events_rounded;
      case 'game_cancelled':
        return Icons.cancel_rounded;
      case 'wallet_topup':
      case 'wallet_withdrawal':
      case 'winnings_credited':
      case 'withdrawal_approved':
      case 'withdrawal_rejected':
      case 'wallet':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'game_live':
      case 'game_started':
      case 'withdrawal_approved':
        return const Color(0xFF00885D); // Live Emerald/Green
      case 'winning':
      case 'pattern_won':
        return const Color(0xFFFFB03A); // Gold/Amber
      case 'game_cancelled':
      case 'withdrawal_rejected':
        return Colors.red;
      case 'wallet_topup':
      case 'winnings_credited':
      case 'game_starting_soon':
        return const Color(0xFF4C50E1); // Indigo/Blue
      default:
        return const Color(0xFF767586);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F101A), // Sleek dark blue/black background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F101A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Color(0xFF4C50E1), fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF4C50E1),
          backgroundColor: const Color(0xFF1E2130),
          onRefresh: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
          child: notificationsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFF4C50E1)),
            ),
            error: (err, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Failed to load notifications',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(notificationsProvider.notifier).fetchNotifications(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C50E1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: Colors.white24),
                          SizedBox(height: 16),
                          Text(
                            'No notifications yet',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "We'll notify you here about your game updates.",
                            style: TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index];
                  final timeStr = DateFormat('dd MMM, hh:mm a').format(item.createdAt.toLocal());

                  return InkWell(
                    onTap: () {
                      if (!item.isRead) {
                        ref.read(notificationsProvider.notifier).markAsRead(item.id);
                      }
                      
                      // Navigate conditionally based on notification type
                      final isGameType = item.type.startsWith('game_') || 
                                         item.type == 'pattern_won' || 
                                         item.type == 'new_game_announced';
                      
                      if (isGameType && item.data != null) {
                        final gameId = item.data!['gameId'] as String?;
                        if (gameId != null) {
                          if (item.type == 'game_live' || item.type == 'game_started') {
                            context.push('/games/$gameId/live');
                          } else {
                            context.push('/games/$gameId');
                          }
                        }
                      } else if (item.type.startsWith('wallet_') ||
                                 item.type == 'winnings_credited' ||
                                 item.type == 'withdrawal_approved' ||
                                 item.type == 'withdrawal_rejected') {
                        context.push('/wallet');
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: item.isRead ? Colors.transparent : const Color(0xFF131520),
                        border: const Border(
                          bottom: BorderSide(color: Colors.white10, width: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status Dot Indicator for unread notifications
                          if (!item.isRead)
                            Container(
                              margin: const EdgeInsets.only(top: 8, right: 8),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF4C50E1),
                                shape: BoxShape.circle,
                              ),
                            )
                          else
                            const SizedBox(width: 14), // spacing equivalent to dot + margin

                          // Notification Icon Card
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getColorForType(item.type).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _getColorForType(item.type).withOpacity(0.3), width: 1),
                            ),
                            child: Icon(
                              _getIconForType(item.type),
                              color: _getColorForType(item.type),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(color: Colors.white30, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.body,
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
