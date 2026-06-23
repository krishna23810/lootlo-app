import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../../core/widgets/shimmer_skeleton.dart';
import '../models/game_model.dart';
import '../viewmodels/game_viewmodel.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../../notification/viewmodels/notification_viewmodel.dart';
import 'game_detail_screen.dart';

/// Games List Screen — redesigned to match the Lootlo mockup.
/// Features: top bar with wallet, welcome message, featured banner,
/// game cards with progress bars, and bottom navigation.
class GameListScreen extends ConsumerWidget {
  const GameListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesAsync = ref.watch(gameListProvider);
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
                  // Logo + App Name
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6063EE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF4648D4), width: 2),
                    ),
                    child: const Icon(Icons.grid_view_rounded, color: Color(0xFF4648D4), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Lootlo',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF4648D4),
                    ),
                  ),
                  const Spacer(),
                  // Notifications Badge
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6E8EA),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.notifications_none_rounded, color: Color(0xFF4648D4), size: 20),
                          if (ref.watch(unreadNotificationsCountProvider) > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Wallet Badge
                  GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: walletAsync.when(
                      data: (wallet) {
                        final balanceCents = wallet['balanceCents'] as int? ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6E8EA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, color: Color(0xFF4648D4), size: 18),
                              const SizedBox(width: 6),
                              Text(
                                '₹${(balanceCents / 100).toStringAsFixed(0)}',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4648D4), fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.add_circle_outline, color: Color(0xFF767586), size: 16),
                            ],
                          ),
                        );
                      },
                      loading: () => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E8EA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Color(0xFF4648D4), size: 18),
                            SizedBox(width: 6),
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF4648D4)),
                            ),
                          ],
                        ),
                      ),
                      error: (_, __) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6E8EA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.red, size: 18),
                            SizedBox(width: 6),
                            Text('₹0', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Scrollable Content ──────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(gameListProvider);
                  ref.invalidate(notificationsProvider);
                  await Future.wait([
                    ref.read(gameListProvider.future),
                    ref.read(notificationsProvider.future),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Welcome Message ───────────────────────
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF191C1E)),
                          children: [
                            TextSpan(text: 'Ready to win, '),
                            TextSpan(text: 'Player?', style: TextStyle(color: Color(0xFF4648D4))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Join a game and start winning!',
                        style: TextStyle(fontSize: 16, color: Color(0xFF464554)),
                      ),
                      const SizedBox(height: 20),


                      // ─── Game Cards ────────────────────────────
                      gamesAsync.when(
                        loading: () => Column(
                          children: List.generate(3, (index) => const GameCardSkeleton()),
                        ),
                        error: (err, _) => Center(
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 8),
                              Text('Failed to load games', style: TextStyle(color: Colors.grey[600])),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: () => ref.invalidate(gameListProvider), child: const Text('Retry')),
                            ],
                          ),
                        ),
                        data: (games) {
                          // Find the featured game — safe null check with == true
                          final featuredGame = games.where((g) => g.isFeatured == true).firstOrNull;
                          // Non-featured games for the list below
                          final listedGames = featuredGame != null
                              ? games.where((g) => g.id != featuredGame.id).toList()
                              : games;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ─── Featured Banner (dynamic) ─────────
                              if (featuredGame != null) ...[
                                _buildFeaturedBanner(context, featuredGame),
                                const SizedBox(height: 24),
                              ],

                              // ─── Upcoming Games Header ─────────────
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Upcoming Games', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Row(
                                      children: [
                                        Text('View All', style: TextStyle(color: Color(0xFF4648D4), fontWeight: FontWeight.w600, fontSize: 14)),
                                        Icon(Icons.chevron_right, size: 18, color: Color(0xFF4648D4)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // ─── Game Cards ────────────────────────
                              if (games.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(child: Text('No upcoming games. Check back later!', style: TextStyle(color: Color(0xFF464554)))),
                                )
                              else
                                ...listedGames.map((game) => _buildGameCard(context, game)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 80), // Space for bottom nav
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // ─── Bottom Navigation Bar ─────────────────────────────────
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.games),
    );
  }

  Widget _buildGameCard(BuildContext context, GameModel game) {
    final percentFull = game.maxTicketCount > 0
        ? (game.soldTicketCount / game.maxTicketCount * 100).round()
        : 0;
    final timeLeft = game.timeUntilStart;
    final minutes = timeLeft.inMinutes;
    final timeStr = minutes > 60
        ? '${timeLeft.inHours}:${(minutes % 60).toString().padLeft(2, '0')}:00'
        : '${minutes.toString().padLeft(2, '0')}:00';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          // Title + Timer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.gameName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined, size: 16, color: Color(0xFF006C49)),
                      const SizedBox(width: 4),
                      Text(
                        '₹${(game.prizePoolCents / 100).toStringAsFixed(0)} Prize Pool',
                        style: const TextStyle(color: Color(0xFF006C49), fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEA619).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text('Starts in', style: TextStyle(fontSize: 10, color: Color(0xFF653E00))),
                    Text(timeStr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF653E00))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${game.soldTicketCount}/${game.maxTicketCount} joined', style: const TextStyle(fontSize: 12, color: Color(0xFF464554))),
                  Text('$percentFull% Full', style: const TextStyle(fontSize: 12, color: Color(0xFF4648D4), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: percentFull / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE6E8EA),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6063EE)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price + Join button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ticket Price', style: TextStyle(fontSize: 12, color: Color(0xFF464554))),
                  Text(game.formattedPrice, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF4648D4))),
                ],
              ),
              ElevatedButton(
                onPressed: game.isSoldOut ? null : () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GameDetailScreen(gameId: game.id, gameName: game.gameName),
                  ));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4648D4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: Text(game.isSoldOut ? 'Sold Out' : 'Join Now', style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the dynamic featured banner from a real featured game.
  Widget _buildFeaturedBanner(BuildContext context, GameModel game) {
    final timeLeft = game.timeUntilStart;
    final h = timeLeft.inHours;
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final timeStr = timeLeft.isNegative ? 'Starting soon' : '${h}h ${m}m';

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4648D4), Color(0xFF6063EE), Color(0xFF8B5CF6)],
        ),
      ),
      child: Stack(
        children: [
          // Left content
          Positioned(
            bottom: 20,
            left: 20,
            right: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEA619),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('FEATURED EVENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text(
                  game.gameName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ticket: ${game.formattedPrice}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Timer badge top-right
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: Color(0xFFFEA619), size: 16),
                  const SizedBox(width: 4),
                  Text(timeStr, style: const TextStyle(color: Color(0xFFFEA619), fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
          // Enter Now button bottom-right
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: game.isSoldOut ? null : () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => GameDetailScreen(gameId: game.id, gameName: game.gameName),
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4648D4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(game.isSoldOut ? 'Sold Out' : 'Enter Now', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

}
