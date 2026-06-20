import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../viewmodels/wallet_viewmodel.dart';
import '../repositories/wallet_repository.dart';

/// Wallet Screen — fetches real balance + transactions from API.
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(walletBalanceProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);

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
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: const Color(0xFF6063EE), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('Wallet', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF4648D4))),
                  const Spacer(),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined, color: Color(0xFF464554))),
                ],
              ),
            ),

            // ─── Scrollable Content ──────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(walletBalanceProvider);
                  ref.invalidate(walletTransactionsProvider);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ─── Balance Card (from API) ───────────────
                      balanceAsync.when(
                        loading: () => _buildBalanceCard(0, 0, 0, isLoading: true),
                        error: (e, _) => _buildBalanceCard(0, 0, 0, error: e.toString()),
                        data: (data) => _buildBalanceCard(
                          data['balanceCents'] as int? ?? 0,
                          data['availableBalanceCents'] as int? ?? 0,
                          data['heldAmountCents'] as int? ?? 0,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Quick Add ─────────────────────────────
                      const Text('Quick Add', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF464554))),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildQuickAddChip(context, ref, 10000, '₹100'),
                          const SizedBox(width: 10),
                          _buildQuickAddChip(context, ref, 50000, '₹500'),
                          const SizedBox(width: 10),
                          _buildQuickAddChip(context, ref, 100000, '₹1000'),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ─── Transaction History (from API) ────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent Activities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                          TextButton(onPressed: () {}, child: const Text('Filter', style: TextStyle(color: Color(0xFF4648D4), fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 8),

                      transactionsAsync.when(
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
                        error: (e, _) => Center(child: Text('Failed to load transactions', style: TextStyle(color: Colors.grey[600]))),
                        data: (data) {
                          final transactions = data['transactions'] as List<dynamic>? ?? [];
                          if (transactions.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('No transactions yet', style: TextStyle(color: Color(0xFF464554)))),
                            );
                          }
                          return Column(
                            children: transactions.map((tx) {
                              final type = tx['type'] as String;
                              final amount = tx['amountCents'] as int;
                              final isCredit = type == 'top_up' || type == 'winning' || type == 'withdrawal_release';
                              final label = _getTransactionLabel(type);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildTransaction(
                                  isCredit ? Icons.south_west : Icons.north_east,
                                  label,
                                  tx['createdAt'] as String? ?? '',
                                  '${isCredit ? '+' : '-'}₹${(amount / 100).toStringAsFixed(0)}',
                                  isCredit,
                                ),
                              );
                            }).toList(),
                          );
                        },
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
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.wallet),
    );
  }

  // ─── Balance Card Widget ─────────────────────────────────────────────────

  Widget _buildBalanceCard(int balanceCents, int availableCents, int heldCents, {bool isLoading = false, String? error}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6063EE), Color(0xFF4648D4)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF4648D4).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Balance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 8),
          if (isLoading)
            const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
          else if (error != null)
            Text('Error loading balance', style: TextStyle(color: Colors.white.withValues(alpha: 0.7)))
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('₹${(balanceCents / 100).toStringAsFixed(2)}', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(width: 6),
                const Text('INR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Available: ₹${(availableCents / 100).toStringAsFixed(0)} | Held: ₹${(heldCents / 100).toStringAsFixed(0)}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_circle, size: 18),
                  label: const Text('+ Add Money', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF4648D4), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Withdraw', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.4)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick Add Chip ──────────────────────────────────────────────────────

  Widget _buildQuickAddChip(BuildContext context, WidgetRef ref, int amountCents, String label) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          try {
            await WalletRepository().topUp(amountCents);
            ref.invalidate(walletBalanceProvider);
            ref.invalidate(walletTransactionsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label added to wallet!')));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up failed')));
            }
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFFF2F4F6), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.3))),
          child: Center(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1E)))),
        ),
      ),
    );
  }

  // ─── Transaction Item ────────────────────────────────────────────────────

  Widget _buildTransaction(IconData icon, String title, String dateStr, String amount, bool isCredit) {
    final color = isCredit ? const Color(0xFF006C49) : const Color(0xFFBA1A1A);
    final formattedDate = dateStr.isNotEmpty ? _formatDate(dateStr) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7C4D7).withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF191C1E))),
                if (formattedDate.isNotEmpty)
                  Text(formattedDate, style: const TextStyle(fontSize: 12, color: Color(0xFF464554))),
              ],
            ),
          ),
          Text(amount, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  String _getTransactionLabel(String type) {
    switch (type) {
      case 'top_up': return 'Top Up';
      case 'ticket_purchase': return 'Ticket Purchase';
      case 'winning': return 'Winnings';
      case 'withdrawal': return 'Withdrawal';
      case 'withdrawal_hold': return 'Withdrawal Hold';
      case 'withdrawal_release': return 'Withdrawal Release';
      default: return type;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays} days ago';
    } catch (_) {
      return '';
    }
  }
}
