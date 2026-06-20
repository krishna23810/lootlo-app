import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

/// Reusable Bottom Navigation Bar component.
///
/// Usage: Pass the current tab index (0=Games, 1=Wallet, 2=Tickets, 3=Profile)
/// and it handles navigation automatically.
///
/// Example:
/// ```dart
/// bottomNavigationBar: const LootloBottomNav(currentIndex: 0),
/// ```
enum NavTab { games, wallet, tickets, profile }

class LootloBottomNav extends StatelessWidget {
  final NavTab currentTab;

  const LootloBottomNav({super.key, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 16,
        right: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.sports_esports,
            label: 'Games',
            isActive: currentTab == NavTab.games,
            onTap: () => _navigate(context, NavTab.games),
          ),
          _NavItem(
            icon: Icons.account_balance_wallet,
            label: 'Wallet',
            isActive: currentTab == NavTab.wallet,
            onTap: () => _navigate(context, NavTab.wallet),
          ),
          _NavItem(
            icon: Icons.confirmation_number_outlined,
            label: 'Tickets',
            isActive: currentTab == NavTab.tickets,
            onTap: () => _navigate(context, NavTab.tickets),
          ),
          _NavItem(
            icon: Icons.person_outline,
            label: 'Profile',
            isActive: currentTab == NavTab.profile,
            onTap: () => _navigate(context, NavTab.profile),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, NavTab tab) {
    if (tab == currentTab) return; // Already on this tab

    switch (tab) {
      case NavTab.games:
        context.go(AppRoutes.games);
        break;
      case NavTab.wallet:
        context.go(AppRoutes.wallet);
        break;
      case NavTab.tickets:
        context.go(AppRoutes.tickets);
        break;
      case NavTab.profile:
        // TODO: Add profile route
        break;
    }
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: isActive
            ? BoxDecoration(
                color: const Color(0xFF6063EE),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xFF464554),
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF464554),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
