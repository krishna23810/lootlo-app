import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'live_stream_view.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../models/ticket_model.dart';
import '../repositories/ticket_repository.dart';
import '../viewmodels/ticket_viewmodel.dart';

/// Ticket View Screen — shows a single ticket with the 3×9 Housie grid.
/// Allows manual cell-marking, displays live called numbers, and lets
/// players claim winning patterns.
class TicketViewScreen extends ConsumerStatefulWidget {
  final String ticketId;
  final int? ticketIndex;

  const TicketViewScreen({
    super.key,
    required this.ticketId,
    this.ticketIndex,
  });

  @override
  ConsumerState<TicketViewScreen> createState() => _TicketViewScreenState();
}

class _TicketViewScreenState extends ConsumerState<TicketViewScreen> {
  // Local state to keep track of numbers the user has manually marked
  final Set<int> _markedNumbers = {};
  bool _claiming = false;

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

  Future<void> _claimPattern(String pattern, String gameId) async {
    if (_claiming) return;
    setState(() => _claiming = true);

    try {
      final repository = TicketRepository();
      await repository.submitClaim(
        ticketId: widget.ticketId,
        gameId: gameId,
        pattern: pattern,
      );

      // Invalidate provider to fetch latest ticket and claim status
      ref.invalidate(userTicketsProvider());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim submitted successfully!'),
            backgroundColor: Color(0xFF00885D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString().replaceAll('DioException:', '').trim();
        // Clean error messages from server response
        if (errMsg.contains('Blocked from claiming')) {
          errMsg = 'Blocked from claiming in this game due to multiple false claims (5 strikes).';
        } else if (errMsg.contains('already been successfully claimed')) {
          errMsg = 'This pattern has already been successfully claimed by another player.';
        } else if (errMsg.contains('not been drawn yet')) {
          errMsg = 'Invalid Claim! Strike added. The required numbers have not been drawn yet.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _claiming = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TicketModel> ticketAsync = ref.watch(userTicketsProvider()).whenData(
          (tickets) => tickets.firstWhere(
            (t) => t.id == widget.ticketId,
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
        final calledNumbers = t.game.drawEvents.toList();
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
                        widget.ticketIndex != null ? 'Ticket #${widget.ticketIndex}' : '#$shortId',
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
                          const SizedBox(height: 16),

                          // ─── Called Numbers Ticker (Newest First) ───────────────────
                          if (game.state == 'live' && calledNumbers.isNotEmpty) ...[
                            const Text('CALLED NUMBERS (LATEST FIRST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF464554), letterSpacing: 1)),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 48,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: calledNumbers.length,
                                itemBuilder: (context, idx) {
                                  // Reverse to show latest drawn first
                                  final num = calledNumbers[calledNumbers.length - 1 - idx];
                                  final isLast = idx == 0;
                                  return Container(
                                    width: 44,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: isLast ? const Color(0xFF6063EE) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF6063EE),
                                        width: 2,
                                      ),
                                      boxShadow: isLast
                                          ? [BoxShadow(color: const Color(0xFF6063EE).withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        num.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isLast ? Colors.white : const Color(0xFF6063EE),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

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
                                // 3×9 Grid with Manual Taps
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF2F4F6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.4)),
                                    ),
                                    child: _buildGrid(grid),
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
                                          LiveStreamView.show(context, game.id, game.gameName);
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
                          const SizedBox(height: 20),

                          // ─── Submit Claims Section ───────────────────────
                          if (game.state == 'live') ...[
                            const Text('SUBMIT CLAIMS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF464554), letterSpacing: 1)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildClaimButton('early_five', 'Early Five', t, game),
                                _buildClaimButton('four_corners', 'Corners', t, game),
                                _buildClaimButton('top_line', 'Top Line', t, game),
                                _buildClaimButton('middle_line', 'Middle Line', t, game),
                                _buildClaimButton('bottom_line', 'Bottom Line', t, game),
                                _buildClaimButton('full_house', 'Full House', t, game),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ─── Claimed Patterns (Results) ───────────────────
                          if (t.winningClaims.isNotEmpty) ...[
                            const Text('WINNING CLAIMS STATUS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF464554), letterSpacing: 1)),
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
                              Expanded(child: _buildLegendItem('12', 'Unmarked', false)),
                              const SizedBox(width: 10),
                              Expanded(child: _buildLegendItem('12', 'Manual Marked', true)),
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
                                  'Tap the numbers on your ticket as the host draws them. Submit claims as soon as you complete a pattern. You are blocked from claiming if you submit 5 false claims.',
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

  Widget _buildGrid(List<List<int?>> grid) {
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
        final isMarked = number != null && _markedNumbers.contains(number);

        if (number == null) {
          return Container(
            decoration: BoxDecoration(color: const Color(0xFFE0E3E5).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4)),
          );
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (_markedNumbers.contains(number)) {
                _markedNumbers.remove(number);
              } else {
                _markedNumbers.add(number);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isMarked ? const Color(0xFF4648D4) : Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isMarked ? const Color(0xFF4648D4) : const Color(0xFF4648D4).withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 2)],
            ),
            child: Center(
              child: Text(
                number.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isMarked ? Colors.white : const Color(0xFF4648D4)),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClaimButton(String pattern, String label, TicketModel t, TicketGameModel game) {
    // Check if player has already made a valid or pending claim for this pattern
    final existingClaim = t.winningClaims.where((wc) => wc.pattern == pattern).firstOrNull;
    final hasWon = existingClaim != null && existingClaim.status == 'valid';
    final isPending = existingClaim != null && existingClaim.status == 'pending';

    final isBtnEnabled = !hasWon && !isPending && !_claiming;

    Color btnColor = const Color(0xFF6063EE);
    if (hasWon) {
      btnColor = const Color(0xFF00885D);
    } else if (isPending) {
      btnColor = const Color(0xFF855300);
    }

    return ElevatedButton(
      onPressed: isBtnEnabled ? () => _claimPattern(pattern, game.id) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: btnColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: hasWon 
            ? const Color(0xFF00885D).withValues(alpha: 0.6) 
            : isPending 
                ? const Color(0xFF855300).withValues(alpha: 0.6) 
                : Colors.grey[300],
        disabledForegroundColor: hasWon || isPending ? Colors.white : Colors.grey[500],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
      ),
      child: Text(
        hasWon 
            ? '$label (Won)' 
            : isPending 
                ? '$label (Pending)' 
                : label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLegendItem(String number, String label, bool isMarked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFECEEF0), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: isMarked ? const Color(0xFF4648D4) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF4648D4)),
            ),
            child: Center(child: Text(number, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isMarked ? Colors.white : const Color(0xFF4648D4)))),
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
