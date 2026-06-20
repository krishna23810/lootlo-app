import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
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

  @override
  Widget build(BuildContext context) {
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
                    decoration: BoxDecoration(color: const Color(0xFF6063EE), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF4648D4), width: 2)),
                    child: const Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('My Tickets', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4648D4))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF6063EE), borderRadius: BorderRadius.circular(16)),
                    child: const Text('₹500', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // ─── Tab Switcher ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color(0xFFE6E8EA), borderRadius: BorderRadius.circular(14)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF4648D4),
                  unselectedLabelColor: const Color(0xFF464554),
                  labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Active (2)'), Tab(text: 'Past (15)')],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ─── Tab Content ─────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildActiveTab(), _buildPastTab()],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.tickets),
    );
  }

  Widget _buildActiveTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildGameTicketCard(
          gameName: 'Evening Gold',
          status: 'LIVE',
          statusColor: Colors.red,
          subtitle: 'Started 5 min ago',
          ticketCount: 2,
          isLive: true,
        ),
        const SizedBox(height: 12),
        _buildGameTicketCard(
          gameName: 'Speedy 90',
          status: 'In 1h 24m',
          statusColor: const Color(0xFF855300),
          subtitle: 'Starts at 8:00 PM',
          ticketCount: 1,
          isLive: false,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildPastTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildGameTicketCard(
          gameName: 'Nightly Rumble',
          status: 'Won ₹250 🏆',
          statusColor: const Color(0xFF006C49),
          subtitle: 'Oct 24, 2023',
          ticketCount: 3,
          isLive: false,
          isPast: true,
        ),
        const SizedBox(height: 12),
        _buildGameTicketCard(
          gameName: 'Weekly Mega',
          status: 'No wins',
          statusColor: const Color(0xFF464554),
          subtitle: 'Oct 22, 2023',
          ticketCount: 2,
          isLive: false,
          isPast: true,
        ),
        const SizedBox(height: 12),
        _buildGameTicketCard(
          gameName: 'Morning Rush',
          status: 'No wins',
          statusColor: const Color(0xFF464554),
          subtitle: 'Oct 20, 2023',
          ticketCount: 1,
          isLive: false,
          isPast: true,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildGameTicketCard({
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
        // Navigate to ticket detail view
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TicketViewScreen(ticketId: 'TK-9821')),
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
                  const SizedBox(height: 4),
                  Text('$ticketCount ticket${ticketCount > 1 ? 's' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF767586))),
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
