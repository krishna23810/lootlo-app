import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../models/game_model.dart';
import '../viewmodels/game_viewmodel.dart';
import '../../ticket/repositories/ticket_repository.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';

/// Game Detail Screen — shows full game info with buy ticket action.
/// Matches the Lootlo mockup design with hero banner, progress, rules.
class GameDetailScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String gameName;

  const GameDetailScreen({super.key, required this.gameId, required this.gameName});

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends ConsumerState<GameDetailScreen> {
  bool _isBuying = false;

  String _formatDateTime(DateTime dt) {
    final weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    final weekday = weekdayNames[dt.weekday - 1];
    final month = monthNames[dt.month - 1];
    final day = dt.day;
    
    final hour24 = dt.hour;
    final isPm = hour24 >= 12;
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = isPm ? 'PM' : 'AM';
    
    return '$weekday, $month $day at $hour12:$minute $amPm';
  }

  Future<void> _purchaseTicket(GameModel game) async {
    setState(() {
      _isBuying = true;
    });

    try {
      final ticketRepo = TicketRepository();
      await ticketRepo.purchaseTicket(game.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket purchased successfully!'),
            backgroundColor: Color(0xFF006C49),
          ),
        );
        
        // Refresh states
        ref.invalidate(walletBalanceProvider);
        ref.invalidate(gameDetailProvider(widget.gameId));
        ref.invalidate(gameListProvider);
      }
    } catch (e) {
      if (mounted) {
        String errorMsg = 'Failed to purchase ticket';
        if (e is DioException) {
          final data = e.response?.data;
          if (data is Map && data['message'] != null) {
            errorMsg = data['message'] as String;
          } else if (data is Map && data['errors'] != null) {
            final errors = data['errors'] as Map;
            errorMsg = errors.values.join('\n');
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBuying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameAsync = ref.watch(gameDetailProvider(widget.gameId));
    final walletAsync = ref.watch(walletBalanceProvider);

    return gameAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4648D4))),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text(widget.gameName),
          backgroundColor: const Color(0xFFE0E3E5),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF4648D4)),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load game details: $err', style: const TextStyle(color: Color(0xFF464554))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(gameDetailProvider(widget.gameId)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4648D4)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
      data: (game) {
        final timeLeft = game.timeUntilStart;
        final h = timeLeft.inHours;
        final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
        final timeStr = timeLeft.isNegative ? 'Started' : '${h}h ${m}m';

        final percentFull = game.maxTicketCount > 0
            ? (game.soldTicketCount / game.maxTicketCount)
            : 0.0;

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
                    title: Text(
                      game.gameName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4648D4)),
                    ),
                    actions: [
                      GestureDetector(
                        onTap: () => context.push('/wallet'),
                        child: walletAsync.when(
                          data: (wallet) {
                            final balanceCents = wallet['balanceCents'] as int? ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(right: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6063EE),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '₹${(balanceCents / 100).toStringAsFixed(0)}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
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
                              child: Row(
                                children: [
                                  const Icon(Icons.timer, color: Color(0xFFFEA619), size: 18),
                                  const SizedBox(width: 6),
                                  Text(timeStr, style: const TextStyle(color: Color(0xFFFEA619), fontWeight: FontWeight.w800, fontSize: 16)),
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
                                    Text('₹${(game.prizePoolCents / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Color(0xFF4648D4))),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('TICKET PRICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600], letterSpacing: 1.5)),
                                    const SizedBox(height: 4),
                                    Text('₹${(game.ticketPriceCents / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF191C1E))),
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
                                  Text('${game.soldTicketCount}/${game.maxTicketCount}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: percentFull,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFECEEF0),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4648D4)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                game.isSoldOut
                                    ? 'Sold out! No tickets remaining.'
                                    : 'Selling fast! Only ${game.availableTickets} tickets remaining.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF767586), fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ─── Feature Cards Row ────────────────────────
                        Row(
                          children: [
                            Expanded(child: _buildFeatureCard(Icons.videocam, 'Live Draw', 'Watch the balls roll live on ${_formatDateTime(game.scheduledStartTime)}.', const Color(0xFF006C49))),
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
                              _buildRule('1', 'Purchase a ticket for ₹${(game.ticketPriceCents / 100).toStringAsFixed(0)}. You can buy up to ${game.maxTicketsPerUser} tickets per account.'),
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
                bottom: 16,
                left: 16,
                right: 16,
                child: SafeArea(
                  child: ElevatedButton.icon(
                    onPressed: _isBuying || game.isSoldOut ? null : () => _purchaseTicket(game),
                    icon: _isBuying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.confirmation_number, size: 22),
                    label: Text(
                      _isBuying
                          ? 'Processing...'
                          : game.isSoldOut
                              ? 'Sold Out'
                              : 'Buy Ticket • ₹${(game.ticketPriceCents / 100).toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
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
            ],
          ),
          bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.games),
        );
      },
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
