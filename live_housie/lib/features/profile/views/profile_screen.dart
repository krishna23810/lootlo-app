import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/bottom_nav_bar.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../viewmodels/profile_viewmodel.dart';

/// User Profile Screen — displays account details, wallet balance,
/// settings options, and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  String _formatJoinDate(DateTime dt) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${monthNames[dt.month - 1]} ${dt.year}';
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final walletAsync = ref.watch(walletBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Color(0xFF6063EE)),
          ),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Failed to load profile: $err', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6063EE)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          data: (user) {
            final initials = _getInitials(user.displayName);
            final joinDateStr = _formatJoinDate(user.createdAt);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userProfileProvider);
                ref.invalidate(walletBalanceProvider);
                await Future.wait([
                  ref.read(userProfileProvider.future),
                  ref.read(walletBalanceProvider.future),
                ]);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ─── Header: Avatar and Profile Details ───────────
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6063EE), Color(0xFF4648D4)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(32),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                      child: Column(
                        children: [
                          // User Avatar Circle
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4648D4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Display Name
                          Text(
                            user.displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Email
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Member Since
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Member since $joinDateStr',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Wallet Balance Shortcut Card ───────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E3E5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6063EE).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF6063EE),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Wallet Balance',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF767586),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  walletAsync.when(
                                    data: (wallet) {
                                      final balanceCents = wallet['balanceCents'] as int? ?? 0;
                                      return Text(
                                        '₹${(balanceCents / 100).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF191C1E),
                                        ),
                                      );
                                    },
                                    loading: () => const Text(
                                      'Calculating...',
                                      style: TextStyle(fontSize: 16, color: Colors.grey),
                                    ),
                                    error: (_, __) => const Text(
                                      '--',
                                      style: TextStyle(fontSize: 16, color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => context.push('/wallet'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6063EE),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: const Text(
                                'Manage',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Account Settings Options ──────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E3E5)),
                        ),
                        child: Column(
                          children: [
                            _buildProfileMenuItem(
                              icon: Icons.phone_android,
                              title: 'Mobile Number',
                              trailingText: user.mobile,
                              showChevron: false,
                            ),
                            const Divider(height: 1, color: Color(0xFFE0E3E5)),
                            _buildProfileMenuItem(
                              icon: Icons.payment,
                              title: 'Payment History',
                              onTap: () => context.push('/wallet'),
                            ),
                            const Divider(height: 1, color: Color(0xFFE0E3E5)),
                            _buildProfileMenuItem(
                              icon: Icons.help_outline_rounded,
                              title: 'How to Play & Rules',
                              onTap: () => _showRulesDialog(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Log Out Option ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE0E3E5)),
                        ),
                        child: _buildProfileMenuItem(
                          icon: Icons.logout,
                          iconColor: Colors.red,
                          title: 'Log Out',
                          titleStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                          onTap: () => _showLogoutConfirmation(context, ref),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Spacing for bottom nav
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: const LootloBottomNav(currentTab: NavTab.profile),
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required String title,
    Color iconColor = const Color(0xFF6063EE),
    TextStyle titleStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: Color(0xFF191C1E),
    ),
    String? trailingText,
    bool showChevron = true,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: titleStyle,
              ),
            ),
            if (trailingText != null)
              Text(
                trailingText,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF767586),
                ),
              ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFF767586)),
            ],
          ],
        ),
      ),
    );
  }

  void _showRulesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.gavel, color: Color(0xFF6063EE)),
              SizedBox(width: 8),
              Text('Housie / Tambola Rules'),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1. Ticket Structure',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('Each ticket contains a 3x9 grid with 15 unique random numbers between 1 and 90. Each row contains exactly 5 numbers.'),
                SizedBox(height: 12),
                Text(
                  '2. The Live Draw',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('Numbers are drawn randomly from 1 to 90 by the host. Drawn numbers are automatically matched and highlighted on your tickets.'),
                SizedBox(height: 12),
                Text(
                  '3. Winning Patterns',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text('• Early Five: Be the first to mark 5 numbers on a ticket.\n'
                    '• Four Corners: Be the first to mark the 1st and last numbers of the top and bottom rows.\n'
                    '• Top Line: Mark all 5 numbers in the top row.\n'
                    '• Middle Line: Mark all 5 numbers in the middle row.\n'
                    '• Bottom Line: Mark all 5 numbers in the bottom row.\n'
                    '• Full House: Mark all 15 numbers on the ticket.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('GOT IT', style: TextStyle(color: Color(0xFF6063EE), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Log Out'),
          content: const Text('Are you sure you want to log out of your account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                
                // Perform logout
                await ref.read(authViewModelProvider.notifier).logout();
                
                // Go back to login
                if (context.mounted) {
                  context.go('/login');
                }
              },
              child: const Text('LOG OUT', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
