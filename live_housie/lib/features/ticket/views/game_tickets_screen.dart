import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/ticket_viewmodel.dart';

/// Screen listing all tickets purchased for a specific game.
class GameTicketsScreen extends ConsumerWidget {
  final String gameId;
  final String gameName;

  const GameTicketsScreen({
    super.key,
    required this.gameId,
    required this.gameName,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(userTicketsProvider(gameId: gameId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4648D4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          gameName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF191C1E)),
        ),
      ),
      body: SafeArea(
        child: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF6063EE))),
          error: (err, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Failed to load tickets: $err', style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userTicketsProvider(gameId: gameId)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6063EE)),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          data: (tickets) {
            if (tickets.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('No tickets found for this game', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userTicketsProvider(gameId: gameId));
                await ref.read(userTicketsProvider(gameId: gameId).future);
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: tickets.length + 1,
                itemBuilder: (context, index) {
                  if (index == tickets.length) {
                    return const SizedBox(height: 40);
                  }
                  
                  final ticket = tickets[index];
                  // List is sorted desc by purchase time, but to number them index #1, #2, etc. in purchase order:
                  // Chronological index = tickets.length - index
                  final ticketIndex = tickets.length - index;

                  final winningsText = ticket.winningsStatusText;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        context.push(
                          '/tickets/${ticket.id}',
                          extra: {'ticketIndex': ticketIndex},
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE0E3E5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4648D4).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.confirmation_number,
                                color: Color(0xFF4648D4),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ticket #$ticketIndex',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF191C1E),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    winningsText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: winningsText.startsWith('Won')
                                          ? const Color(0xFF00885D)
                                          : winningsText.contains('Pending')
                                              ? const Color(0xFF855300)
                                              : const Color(0xFF767586),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF767586)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
