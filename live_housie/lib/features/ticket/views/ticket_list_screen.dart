import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../models/ticket_model.dart';
import '../viewmodels/ticket_viewmodel.dart';
import 'ticket_view_screen.dart';

/// My Tickets Screen — shows list of games with tickets, tap to see ticket details.
class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour24 = dt.hour;
    final isPm = hour24 >= 12;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = isPm ? 'PM' : 'AM';
    return '$hour12:$minute $amPm';
  }

  String _formatDate(DateTime dt) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(userTicketsProvider());
    final walletAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Top Bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6063EE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4648D4), width: 2),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('My Tickets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4648D4))),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: walletAsync.when(
                      data: (wallet) {
                        final balanceCents = wallet['balanceCents'] as int? ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF6063EE), borderRadius: BorderRadius.circular(16)),
                          child: Text(
                            '₹${(balanceCents / 100).toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Tab Switcher & Content ──────────────────────────
            ticketsAsync.when(
              loading: () => const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xFF6063EE)))),
              error: (err, _) => Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Failed to load tickets: $err', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(userTicketsProvider()),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6063EE)),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              data: (tickets) {
                final activeTickets = tickets.where((t) => t.game.state != 'completed' && t.game.state != 'cancelled').toList();
                final pastTickets = tickets.where((t) => t.game.state == 'completed' || t.game.state == 'cancelled').toList();

                return Expanded(
                  child: Column(
                    children: [
                      // TabBar Switcher
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFFE6E8EA), borderRadius: BorderRadius.circular(14)),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: const Color(0xFF4648D4),
                            unselectedLabelColor: const Color(0xFF464554),
                            labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            tabs: [
                              Tab(text: 'Active (${activeTickets.length})'),
                              Tab(text: 'Past (${pastTickets.length})'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // TabBarView Content
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildTicketsList(activeTickets, isActive: true),
                            _buildTicketsList(pastTickets, isActive: false),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.tickets),
    );
  }

  Widget _buildTicketsList(List<TicketModel> tickets, {required bool isActive}) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                isActive ? 'No active tickets' : 'No past tickets',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Group tickets by gameId
    final Map<String, List<TicketModel>> groupsMap = {};
    for (final ticket in tickets) {
      groupsMap.putIfAbsent(ticket.gameId, () => []).add(ticket);
    }
    
    final groupsList = groupsMap.values.toList();

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userTicketsProvider());
        await ref.read(userTicketsProvider().future);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: groupsList.length + 1,
        itemBuilder: (context, index) {
          if (index == groupsList.length) {
            return const SizedBox(height: 80); // padding for bottom nav
          }
          final groupTickets = groupsList[index];
          final ticket = groupTickets.first;
          final game = ticket.game;
          final ticketCount = groupTickets.length;
          
          String statusText = 'Upcoming';
          Color statusColor = const Color(0xFF855300);
          String subtitleText = '';
          bool isLive = false;

          if (game.state == 'live') {
            statusText = 'LIVE';
            statusColor = Colors.red;
            subtitleText = 'Game is live now!';
            isLive = true;
          } else if (game.state == 'upcoming') {
            final timeLeft = game.scheduledStartTime.difference(DateTime.now());
            final minutes = timeLeft.inMinutes;
            if (timeLeft.isNegative) {
              statusText = 'Starting';
            } else if (minutes > 60) {
              statusText = 'In ${timeLeft.inHours}h ${minutes % 60}m';
            } else {
              statusText = 'In ${minutes}m';
            }
            statusColor = const Color(0xFF855300);
            subtitleText = 'Starts at ${_formatTime(game.scheduledStartTime)}';
          } else {
            statusText = game.state.toUpperCase();
            statusColor = const Color(0xFF464554);
            subtitleText = 'Played on ${_formatDate(ticket.purchasedAt)}';
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildGameGroupCard(
              gameId: game.id,
              gameName: game.gameName,
              status: statusText,
              statusColor: statusColor,
              subtitle: subtitleText,
              ticketCount: ticketCount,
              isLive: isLive,
              isPast: game.state == 'completed' || game.state == 'cancelled',
            ),
          );
        },
      ),
    );
  }

  Widget _buildGameGroupCard({
    required String gameId,
    required String gameName,
    required String status,
    required Color statusColor,
    required String subtitle,
    required int ticketCount,
    required bool isLive,
    bool isPast = false,
  }) {
    return InkWell(
      onTap: () {
        context.push(
          '/tickets/game/$gameId',
          extra: {'gameName': gameName},
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isLive ? const Color(0xFF4648D4).withValues(alpha: 0.2) : const Color(0xFFE0E3E5)),
          boxShadow: isLive ? [BoxShadow(color: const Color(0xFF4648D4).withValues(alpha: 0.08), blurRadius: 12)] : null,
        ),
        child: Row(
          children: [
            // Left icon
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: isLive ? const Color(0xFF4648D4).withValues(alpha: 0.1) : const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isLive ? Icons.play_circle_filled : (isPast ? Icons.history : Icons.schedule),
                color: isLive ? const Color(0xFF4648D4) : const Color(0xFF464554),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            // Middle content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(gameName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF464554))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4648D4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$ticketCount ${ticketCount == 1 ? "Ticket" : "Tickets"}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4648D4)),
                    ),
                  ),
                ],
              ),
            ),
            // Right status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                      ],
                      Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.chevron_right, size: 20, color: Color(0xFF767586)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
