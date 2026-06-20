import '../../../data/repositories/base_repository.dart';

/// Repository for ticket-related API calls.
///
/// Endpoints:
/// - POST /api/tickets/purchase
/// - GET  /api/tickets/mine
/// - GET  /api/tickets/:id
class TicketRepository extends BaseRepository {
  /// Purchase a ticket for a game.
  Future<Map<String, dynamic>> purchaseTicket(String gameId) async {
    final response = await dio.post('/tickets/purchase', data: {
      'gameId': gameId,
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
