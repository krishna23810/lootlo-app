import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'live_stream_view.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../models/ticket_model.dart';
import '../repositories/ticket_repository.dart';
import '../viewmodels/ticket_viewmodel.dart';

/// Ticket View Screen — shows user tickets with a 3×9 Tambola grid.
/// Supports a horizontal swipeable PageView carousel of all user tickets for this game.
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
  // Store marked numbers independently for each ticket by mapping ticketId -> Set<int>
  final Map<String, Set<int>> _markedNumbersPerTicket = {};
  bool _claiming = false;
  Timer? _timer;
  
  PageController? _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Update the UI every second to keep the countdown ticking
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
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

  Future<void> _claimPattern(String pattern, String gameId, String ticketId) async {
    if (_claiming) return;
    setState(() => _claiming = true);

    try {
      final repository = TicketRepository();
      await repository.submitClaim(
        ticketId: ticketId,
        gameId: gameId,
        pattern: pattern,
      );

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

  double getPrizeAmount(String patternKey, int prizePoolCents, Map<String, dynamic> config) {
    final percent = config[patternKey] as num? ?? 10; // Default fallback to 10%
    final cents = (prizePoolCents * percent) / 100;
    return cents / 100; // in Rupees
  }

  void _showRulesBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'How to Play & Rules',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1E),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Numbers will be called one by one from the live stream.',
                style: TextStyle(fontSize: 14, color: Color(0xFF464554)),
              ),
              const SizedBox(height: 8),
              const Text(
                '2. If the number is on your ticket, tap it to mark it manually.',
                style: TextStyle(fontSize: 14, color: Color(0xFF464554)),
              ),
              const SizedBox(height: 8),
              const Text(
                '3. Claim your prize immediately by tapping the "CLAIM" button once you complete the pattern.',
                style: TextStyle(fontSize: 14, color: Color(0xFF464554)),
              ),
              const SizedBox(height: 8),
              const Text(
                '4. First person to claim correctly wins the prize for that pattern!',
                style: TextStyle(fontSize: 14, color: Color(0xFF464554)),
              ),
              const SizedBox(height: 8),
              const Text(
                '5. Players get blocked from claiming after 5 incorrect (false) claims.',
                style: TextStyle(fontSize: 14, color: Color(0xFF464554), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletBalanceProvider);

    // Resolve ALL tickets for the user, then filter to show only those belonging to the same game
    final AsyncValue<List<TicketModel>> ticketsAsync = ref.watch(userTicketsProvider()).whenData(
      (tickets) {
        final clickedTicket = tickets.firstWhere(
          (t) => t.id == widget.ticketId,
          orElse: () => throw Exception('Ticket not found'),
        );
        final targetGameId = clickedTicket.gameId;
        // Filter and return sorted by purchase time to keep order stable
        return tickets.where((t) => t.gameId == targetGameId).toList()..sort((a, b) => a.purchasedAt.compareTo(b.purchasedAt));
      },
    );

    final balanceText = walletAsync.maybeWhen(
      data: (data) => '₹${((data['availableBalanceCents'] ?? 0) / 100).toStringAsFixed(0)}',
      orElse: () => '₹--',
    );

    return ticketsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFF7F9FB),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4648D4))),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: const Color(0xFFF7F9FB),
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
              Text('Failed to load tickets: $err', style: const TextStyle(color: Color(0xFF464554))),
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
      data: (tickets) {
        if (tickets.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F9FB),
            body: Center(child: Text('No tickets found')),
          );
        }

        // Initialize PageController once the tickets list loads
        if (_pageController == null) {
          final initialIndex = tickets.indexWhere((t) => t.id == widget.ticketId);
          final safeIndex = initialIndex >= 0 ? initialIndex : 0;
          _pageController = PageController(initialPage: safeIndex);
          _currentPage = safeIndex;
        }

        // Derive active ticket state from active PageView page
        final activeTicket = tickets[_currentPage];
        final game = activeTicket.game;
        final calledNumbers = game.drawEvents.toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF7F9FB),
          body: SafeArea(
            child: Column(
              children: [
                // ─── Header Bar ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF191C1E)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Lootlo',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4648D4),
                        ),
                      ),
                      const Spacer(),
                      // Wallet Balance Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4648D4).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          balanceText,
                          style: const TextStyle(
                            color: Color(0xFF4648D4),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.share, color: Color(0xFF464554), size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // ─── Scrollable Content ──────────────────────────────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(userTicketsProvider());
                      ref.invalidate(walletBalanceProvider);
                      await ref.read(userTicketsProvider().future);
                    },
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Game Header Card
                          _buildGameHeaderCard(game),
                          const SizedBox(height: 20),

                          // 2. Called Numbers Ticker (Newest First)
                          if (game.state == 'live' && calledNumbers.isNotEmpty) ...[
                            const Text(
                              'CALLED NUMBERS (LATEST FIRST)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF464554),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 48,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: calledNumbers.length,
                                itemBuilder: (context, idx) {
                                  final num = calledNumbers[calledNumbers.length - 1 - idx];
                                  final isLast = idx == 0;
                                  return Container(
                                    width: 44,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      color: isLast ? const Color(0xFF4648D4) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF4648D4),
                                        width: 2,
                                      ),
                                      boxShadow: isLast
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFF4648D4).withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        num.toString().padLeft(2, '0'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isLast ? Colors.white : const Color(0xFF4648D4),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // 3. Your Tickets Carousel Title & Buy More
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Your Tickets',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF191C1E),
                                ),
                              ),
                              if (game.state != 'completed' && game.state != 'cancelled')
                                TextButton.icon(
                                  onPressed: () {
                                    context.push('/games/${game.id}');
                                  },
                                  icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF4648D4)),
                                  label: const Text(
                                    'Buy More',
                                    style: TextStyle(
                                      color: Color(0xFF4648D4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 4. Horizontal Swipeable Tickets Carousel
                          SizedBox(
                            height: 195,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentPage = index;
                                });
                              },
                              itemCount: tickets.length,
                              itemBuilder: (context, index) {
                                final ticketItem = tickets[index];
                                final gridItem = ticketItem.grid;
                                final shortIdItem = ticketItem.id.length > 8 ? ticketItem.id.substring(0, 8).toUpperCase() : ticketItem.id.toUpperCase();
                                
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 362),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: _buildTicketGridCard(ticketItem, gridItem, calledNumbers, shortIdItem),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Carousel Dot Indicators
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'TICKET ${_currentPage + 1} OF ${tickets.length}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF464554),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(tickets.length, (idx) {
                                    final isActive = idx == _currentPage;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFF4648D4) : const Color(0xFFC7C4D7),
                                        shape: BoxShape.circle,
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 5. Prize Pool Header & Amount
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Prize Pool',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF191C1E),
                                ),
                              ),
                              Text(
                                game.prizePoolCents > 0 ? game.formattedPrizePool : '₹15,000',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4648D4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 6. Prize breakdown cards (stacked vertically - claims tied to activeTicket)
                          _buildPrizeCard('full_house', 'Full House', 'All 15 numbers', Icons.stars, const Color(0xFF855300), const Color(0xFFFEA619).withValues(alpha: 0.2), activeTicket, game),
                          const SizedBox(height: 10),
                          _buildPrizeCard('early_five', 'Early Five', 'Any first 5 numbers', Icons.bolt, const Color(0xFF006C49), const Color(0xFF006C49).withValues(alpha: 0.1), activeTicket, game),
                          const SizedBox(height: 10),
                          _buildPrizeCard('top_line', 'Top Line', 'Row 1 completed', Icons.horizontal_rule, const Color(0xFF4648D4), const Color(0xFF6063EE).withValues(alpha: 0.1), activeTicket, game),
                          const SizedBox(height: 10),
                          _buildPrizeCard('middle_line', 'Middle Line', 'Row 2 completed', Icons.view_headline, const Color(0xFF4648D4), const Color(0xFF6063EE).withValues(alpha: 0.1), activeTicket, game),
                          const SizedBox(height: 10),
                          _buildPrizeCard('bottom_line', 'Bottom Line', 'Row 3 completed', Icons.view_headline, const Color(0xFF4648D4), const Color(0xFF6063EE).withValues(alpha: 0.1), activeTicket, game),
                          const SizedBox(height: 10),
                          _buildPrizeCard('four_corners', 'Four Corners', 'First & last of top & bottom', Icons.crop_free, const Color(0xFF855300), const Color(0xFFFEA619).withValues(alpha: 0.2), activeTicket, game),
                          const SizedBox(height: 24),

                          // 7. Game Details Card
                          _buildGameDetailsCard(game, context),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Sticky Bottom Action Bar ──────────────────────────────
          bottomNavigationBar: game.state == 'completed' || game.state == 'cancelled'
              ? null
              : Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    border: const Border(
                      top: BorderSide(color: Color(0xFFE0E3E5), width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      12 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'MY TICKETS: ${tickets.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF464554),
                              ),
                            ),
                            Text(
                              'EST. WIN: ₹${((game.prizePoolCents > 0 ? game.prizePoolCents : 1500000) * 0.5 / 100).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4648D4),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () {
                                    context.push('/games/${game.id}/live');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4648D4),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Enter Game Room',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(Icons.chevron_right, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _showRulesBottomSheet(context),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECEEF0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                  Icons.help_outline,
                                  color: Color(0xFF191C1E),
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildGameHeaderCard(TicketGameModel game) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4648D4),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4648D4).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'HOUSIE CLASSIC',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game.gameName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildTimerBadge(game),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 28,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEA619),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4648D4), width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00885D),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4648D4), width: 2),
                        ),
                        child: const Center(
                          child: Icon(Icons.person, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 28,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC0C1FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF4648D4), width: 2),
                        ),
                        child: const Center(
                          child: Text(
                            '+',
                            style: TextStyle(
                              color: Color(0xFF4648D4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(game.prizePoolCents > 0 ? (game.prizePoolCents / 100).round() : 1200)}+ Players joining the pool',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBadge(TicketGameModel game) {
    if (game.state == 'live') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF00885D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    if (game.state == 'completed' || game.state == 'cancelled') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          game.state.toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final timeLeft = game.scheduledStartTime.difference(DateTime.now());
    if (timeLeft.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF00885D),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'LIVE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    String timeStr;
    if (timeLeft.inHours > 0) {
      final h = timeLeft.inHours;
      final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
      timeStr = '${h.toString().padLeft(2, '0')}:$m';
    } else {
      final m = timeLeft.inMinutes;
      final s = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');
      timeStr = '${m.toString().padLeft(2, '0')}:$s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFEA619),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'STARTS IN',
            style: TextStyle(
              color: Color(0xFF684000),
              fontWeight: FontWeight.w800,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            timeStr,
            style: const TextStyle(
              color: Color(0xFF2A1700),
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketGridCard(
    TicketModel t,
    List<List<int?>> grid,
    List<int> calledNumbers,
    String shortId,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: _buildGrid(t, grid, calledNumbers),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: DashedDivider(height: 1),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TICKET ID: #$shortId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF464554),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00885D).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF00885D), size: 6),
                      SizedBox(width: 4),
                      Text(
                        'VERIFIED',
                        style: TextStyle(
                          color: Color(0xFF00885D),
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(TicketModel t, List<List<int?>> grid, List<int> calledNumbers) {
    // Get or initialize the marked numbers set for this specific ticket
    final markedNumbers = _markedNumbersPerTicket[t.id] ??= {};

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 27,
      itemBuilder: (context, index) {
        final row = index ~/ 9;
        final col = index % 9;
        final number = grid[row][col];

        if (number == null) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFECEEF0),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }

        final isMarked = markedNumbers.contains(number);
        final isCalled = calledNumbers.contains(number);

        Color bgColor;
        Color textColor;

        if (isMarked) {
          bgColor = const Color(0xFF4648D4);
          textColor = Colors.white;
        } else if (isCalled) {
          bgColor = const Color(0xFFFFDDB8); // Light amber (called but unmarked)
          textColor = const Color(0xFF855300);
        } else {
          bgColor = const Color(0xFFE1E0FF).withValues(alpha: 0.3); // Light blue-purple
          textColor = const Color(0xFF4648D4);
        }

        return GestureDetector(
          onTap: () {
            setState(() {
              if (markedNumbers.contains(number)) {
                markedNumbers.remove(number);
              } else {
                markedNumbers.add(number);
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                number.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrizeCard(
    String pattern,
    String label,
    String desc,
    IconData icon,
    Color iconColor,
    Color iconBgColor,
    TicketModel t,
    TicketGameModel game,
  ) {
    final pool = game.prizePoolCents > 0 ? game.prizePoolCents : 1500000;
    final amount = getPrizeAmount(pattern, pool, game.prizeConfig);
    final formattedAmount = '₹${amount.toStringAsFixed(0)}';

    final existingClaim = t.winningClaims.where((wc) => wc.pattern == pattern).firstOrNull;
    final hasWon = existingClaim != null && existingClaim.status == 'valid';
    final isPending = existingClaim != null && existingClaim.status == 'pending';

    final isLive = game.state == 'live';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF191C1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF464554),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF4648D4),
                ),
              ),
              if (isLive) ...[
                const SizedBox(height: 4),
                if (hasWon)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00885D).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'WON',
                      style: TextStyle(
                        color: Color(0xFF00885D),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  )
                else if (isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF855300).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PENDING',
                      style: TextStyle(
                        color: Color(0xFF855300),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 24,
                    child: ElevatedButton(
                      onPressed: _claiming ? null : () => _claimPattern(pattern, game.id, t.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4648D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'CLAIM',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGameDetailsCard(TicketGameModel game, BuildContext context) {
    final startTimeStr = '${_formatDate(game.scheduledStartTime)}, ${_formatTime(game.scheduledStartTime)}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.info, color: Color(0xFF4648D4), size: 18),
                SizedBox(width: 8),
                Text(
                  'Game Details',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF191C1E),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailField(
                        'ENTRY FEE',
                        '${game.formattedPrice} / ticket',
                      ),
                    ),
                    Expanded(
                      child: _buildDetailField(
                        'START TIME',
                        startTimeStr,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailField(
                        'PLAYER LIMIT',
                        'Unlimited',
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HOST',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF464554),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.green.shade700,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Lootlo Official',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF191C1E),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFC7C4D7),
                  width: 0.5,
                ),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                title: const Text(
                  'How to Play',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4648D4),
                    fontSize: 14,
                  ),
                ),
                iconColor: const Color(0xFF4648D4),
                collapsedIconColor: const Color(0xFF4648D4),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '1. Numbers will be called one by one from the live stream.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF464554)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '2. If the number is on your ticket, tap it to mark it manually.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF464554)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '3. Claim your prize immediately by tapping the "CLAIM" button once you fulfill a pattern.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF464554)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '4. First person to claim correctly wins the prize for that pattern!',
                    style: TextStyle(fontSize: 13, color: Color(0xFF464554)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF464554),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF191C1E),
          ),
        ),
      ],
    );
  }
}

/// A custom dashed divider that draws a horizontal line of dashes.
class DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashGap;

  const DashedDivider({
    super.key,
    this.height = 1,
    this.color = const Color(0xFFC7C4D7),
    this.dashWidth = 5,
    this.dashGap = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashGap)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}
