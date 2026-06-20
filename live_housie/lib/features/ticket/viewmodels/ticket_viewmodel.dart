import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/ticket_model.dart';
import '../repositories/ticket_repository.dart';

part 'ticket_viewmodel.g.dart';

@riverpod
Future<List<TicketModel>> userTickets(Ref ref, {String? gameId}) async {
  final repository = TicketRepository();
  return await repository.getMyTickets(gameId: gameId);
}
