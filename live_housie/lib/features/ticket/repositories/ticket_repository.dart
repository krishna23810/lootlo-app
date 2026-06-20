import '../../../data/repositories/base_repository.dart';
import '../models/ticket_model.dart';

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

  /// Get all tickets for the authenticated user.
  Future<List<TicketModel>> getMyTickets({String? gameId}) async {
    final response = await dio.get(
      '/tickets/mine',
      queryParameters: gameId != null ? {'gameId': gameId} : null,
    );
    final List<dynamic> listJson = response.data['data'] as List<dynamic>;
    return listJson.map((json) => TicketModel.fromJson(json as Map<String, dynamic>)).toList();
  }
}
