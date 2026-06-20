/// Game Repository — fetches game data from the backend API.

import '../../../data/repositories/base_repository.dart';
import '../models/game_model.dart';

class GameRepository extends BaseRepository {
  /// Get all upcoming games sorted by start time.
  Future<List<GameModel>> getUpcomingGames() async {
    final response = await dio.get('/games');

    // response.data = { success: true, data: [ {...game1}, {...game2} ] }
    final List<dynamic> gamesJson = response.data['data'] as List<dynamic>;
    return gamesJson
        .map((json) => GameModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single game by ID.
  Future<GameModel> getGameById(String gameId) async {
    final response = await dio.get('/games/$gameId');
    final gameJson = response.data['data'] as Map<String, dynamic>;
    return GameModel.fromJson(gameJson);
  }
}
