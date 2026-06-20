import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../models/ticket_model.dart';
import '../viewmodels/ticket_viewmodel.dart';

/// Ticket View Screen — shows a single ticket with the 3×9 Housie grid.
/// Matches the Lootlo ticket detail mockup with Lootlo branding, batch ID,
/// grid, legend, pro tip, and action buttons.
class TicketViewScreen extends ConsumerWidget {
  final String ticketId;
  final int? ticketIndex;

  const TicketViewScreen({
    super.key,
    required this.ticketId,
    this.ticketIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TicketModel> ticketAsync = ref.watch(userTicketsProvider()).whenData(
          (tickets) => tickets.firstWhere(
            (t) => t.id == ticketId,
            orElse: () => throw Exception('Ticket not found'),
          ),
        );

    return ticketAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4648D4))),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Ticket Details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load ticket: $err', style: const TextStyle(color: Color(0xFF464554))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userTicketsProvider()),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4648D4)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
      data: (t) {
        final game = t.game;
        final grid = t.grid;
        final calledNumbers = t.game.drawEvents.toSet();
        final shortId = t.id.length > 8 ? t.id.substring(0, 8).toUpperCase() : t.id.toUpperCase();

        final timeLeft = game.scheduledStartTime.difference(DateTime.now());
        final isPast = game.state == 'completed' || game.state == 'cancelled';
        
        String statusText = 'Game is live';
        if (game.state == 'upcoming') {
          final h = timeLeft.inHours;
          final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
          statusText = timeLeft.isNegative ? 'Starting soon' : 'Game starts in ${h.toString().padLeft(2, '0')}:${m}';
        } else if (isPast) {
          statusText = 'Game Finished';
        }

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
                      Text(
                        ticketIndex != null ? 'Ticket #$ticketIndex' : '#$shortId',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)),
                      ),
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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(userTicketsProvider());
                      await ref.read(userTicketsProvider().future);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: game.state == 'live'
                                      ? Colors.red
                                      : game.state == 'upcoming'
                                          ? const Color(0xFF006C49)
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Text(statusText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF464554))),
                              ]),
                              Text(game.state.toUpperCase(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
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
                                        Text(shortId, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('TICKET PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF767586))),
                                        Text(game.formattedPrice, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF4648D4))),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: game.state == 'completed' || game.state == 'cancelled' ? null : () {
                                        // TODO: Open WebRTC / WebSocket Live Session draw page
                                      },
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

                        // ─── Claimed Patterns ──────────────────────────
                        if (t.winningClaims.isNotEmpty) ...[
                          const Text('CLAIMED PATTERNS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF464554), letterSpacing: 1)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: t.winningClaims.map((wc) {
                              final isValid = wc.status == 'valid';
                              final isPending = wc.status == 'pending';
                              final color = isValid 
                                  ? const Color(0xFF00885D) 
                                  : isPending 
                                      ? const Color(0xFF855300) 
                                      : Colors.red;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: color.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isValid 
                                          ? Icons.check_circle 
                                          : isPending 
                                              ? Icons.hourglass_empty 
                                              : Icons.cancel, 
                                      color: color, 
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${wc.formattedPattern} (${wc.status.toUpperCase()})',
                                      style: TextStyle(
                                        fontSize: 13, 
                                        fontWeight: FontWeight.bold, 
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 20),
                        ],

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
              ),
            ],
          ),
        ),
        bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.tickets),
      );
      },
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
