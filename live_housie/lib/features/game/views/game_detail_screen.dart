import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_nav_bar.dart';

/// Game Detail Screen — shows full game info with buy ticket action.
/// Matches the Lootlo mockup design with hero banner, progress, rules.
class GameDetailScreen extends ConsumerWidget {
  final String gameId;

  const GameDetailScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Fetch actual game data from API using gameId
    // For now using placeholder data to match the design

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: Stack(
        children: [
          // ─── Scrollable Content ────────────────────────────────
          CustomScrollView(
            slivers: [
              // ─── App Bar ───────────────────────────────────────
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: const Color(0xFFE0E3E5),
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.arrow_back, color: Color(0xFF4648D4), size: 20),
                  ),
                ),
                title: const Text(
                  'Mega Sunday Bumper',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4648D4)),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6063EE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('₹1,250', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),

              // ─── Hero Banner ───────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF4648D4), Color(0xFF6063EE), Color(0xFFF7F9FB)],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Timer badge
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.timer, color: Color(0xFFFEA619), size: 18),
                              SizedBox(width: 6),
                              Text('14:52:03', style: TextStyle(color: Color(0xFFFEA619), fontWeight: FontWeight.w800, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      // Prize info
                      Positioned(
                        bottom: 24,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TOTAL PRIZE POOL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7), letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                const Text('₹50,000', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF4648D4))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('TICKET PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.5)),
                                const SizedBox(height: 4),
                                const Text('₹50', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF191C1E))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ─── Content ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 16),

                    // ─── Tickets Sold Progress ────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tickets Sold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF464554))),
                              const Text('142/500', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: const LinearProgressIndicator(
                              value: 0.28,
                              minHeight: 10,
                              backgroundColor: Color(0xFFECEEF0),
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4648D4)),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Selling fast! Only 358 tickets remaining.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF767586), fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ─── Feature Cards Row ────────────────────────
                    Row(
                      children: [
                        Expanded(child: _buildFeatureCard(Icons.videocam, 'Live Draw', 'Watch the balls roll live on Sunday 8 PM.', const Color(0xFF006C49))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFeatureCard(Icons.verified_user, 'Verified', '100% fair RNG certified system.', const Color(0xFF855300))),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Game Rules ───────────────────────────────
                    const Text('Game Rules', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          _buildRule('1', 'Purchase a ticket for ₹50. You can buy up to 5 tickets per account.'),
                          const SizedBox(height: 16),
                          _buildRule('2', 'Each ticket contains a 3×9 grid of numbers. Numbers range from 1 to 90.'),
                          const SizedBox(height: 16),
                          _buildRule('3', "Be the first to claim 'Top Row', 'Full House' or 'Corners' to win cash prizes."),
                          const SizedBox(height: 16),
                          _buildRule('4', 'Prizes are credited instantly to your wallet upon verification.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── CTA Banner ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.2)),
                      ),
                      child: const Column(
                        children: [
                          Text('Next Big Win Could Be Yours!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)), textAlign: TextAlign.center),
                          SizedBox(height: 4),
                          Text('LIMITED SPOTS AVAILABLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4648D4), letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 200), // Space for bottom buttons + nav
                  ]),
                ),
              ),
            ],
          ),

          // ─── Sticky Buy Button ─────────────────────────────────
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Purchase ticket
                },
                icon: const Icon(Icons.confirmation_number, size: 22),
                label: const Text('Buy Ticket • ₹50', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4648D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                  shadowColor: const Color(0xFF4648D4).withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

          // ─── Bottom Nav ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: const LootloBottomNav(currentTab: NavTab.games),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF464554))),
        ],
      ),
    );
  }

  Widget _buildRule(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number.', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF464554)))),
      ],
    );
  }

}
