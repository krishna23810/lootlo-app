import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bottom_nav_bar.dart';

/// Ticket View Screen — shows a single ticket with the 3×9 Housie grid.
/// Matches the Lootlo ticket detail mockup with Lootlo branding, batch ID,
/// grid, legend, pro tip, and action buttons.
class TicketViewScreen extends ConsumerWidget {
  final String ticketId;

  const TicketViewScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Fetch actual ticket data from API
    // Placeholder data matching the mockup
    final grid = [
      [7, null, 22, null, 45, 51, null, 73, null],
      [null, 14, null, 33, null, 58, 62, null, 89],
      [2, null, 29, null, 41, null, 66, null, 81],
    ];
    final calledNumbers = <int>{89}; // Numbers already called in the draw

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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF4648D4)),
                  ),
                  Text('#$ticketId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0xFF00885D), borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      children: [
                        Icon(Icons.verified, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text('Validated', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── Content ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E3E5)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Icon(Icons.circle, size: 8, color: Color(0xFF006C49)),
                            SizedBox(width: 8),
                            Text('Game starts in 04:21', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF464554))),
                          ]),
                          Text('LIVE DRAW', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ─── Ticket Card ─────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12)],
                      ),
                      child: Column(
                        children: [
                          // Ticket header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('LOOTLO', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic, color: Color(0xFFC0C1FF))),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('BATCH ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF767586))),
                                    const Text('X9-2201', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // 3×9 Grid
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F4F6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.4)),
                              ),
                              child: _buildGrid(grid, calledNumbers),
                            ),
                          ),
                          // Price + View Live Draw
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TICKET PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF767586))),
                                    Text('₹50.00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF4648D4))),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF855300),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  child: const Text('VIEW LIVE DRAW', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Quick Legend ─────────────────────────────
                    const Text('QUICK LEGEND', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF464554), letterSpacing: 1)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _buildLegendItem('12', 'Pending Call', false)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildLegendItem('12', 'Number Called', true)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ─── Pro Tip ─────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDDB8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Color(0xFF855300), size: 18),
                              SizedBox(width: 6),
                              Text('Pro Tip', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2A1700))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Watch for "Full House" calls to win the grand prize. Numbers are auto-marked on your screen during the live draw.',
                            style: TextStyle(fontSize: 14, color: const Color(0xFF2A1700).withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Action Buttons ──────────────────────────
                    Row(
                      children: [
                        _buildActionButton(Icons.share, 'Share'),
                        const SizedBox(width: 10),
                        _buildActionButton(Icons.download, 'Save'),
                        const SizedBox(width: 10),
                        _buildActionButton(Icons.help_outline, 'Rules'),
                      ],
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.tickets),
    );
  }

  Widget _buildGrid(List<List<int?>> grid, Set<int> calledNumbers) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1,
      ),
      itemCount: 27,
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final number = grid[row][col];
        final isCalled = number != null && calledNumbers.contains(number);

        if (number == null) {
          return Container(
            decoration: BoxDecoration(color: const Color(0xFFE0E3E5).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isCalled ? const Color(0xFF4648D4) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isCalled ? const Color(0xFF4648D4) : const Color(0xFF4648D4).withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2)],
          ),
          child: Center(
            child: Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCalled ? Colors.white : const Color(0xFF4648D4)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegendItem(String number, String label, bool isCalled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFECEEF0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isCalled ? const Color(0xFF4648D4) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF4648D4)),
            ),
            child: Center(child: Text(number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isCalled ? Colors.white : const Color(0xFF4648D4)))),
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFE6E8EA), borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF4648D4), size: 22),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
