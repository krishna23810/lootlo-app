/// Game ViewModel — fetches and holds the list of upcoming games.
///
/// KEY RIVERPOD CONCEPT: @riverpod on an async function
/// ─────────────────────────────────────────────────────
/// When you annotate an async function with @riverpod, Riverpod creates
/// an "AsyncValue" provider. This automatically gives you THREE states:
///
/// AsyncValue.loading  → data is being fetched (show skeleton)
/// AsyncValue.data     → data arrived (show the list)
/// AsyncValue.error    → request failed (show error message)
///
/// The widget uses: ref.watch(gameListProvider).when(
///   loading: () => skeleton,
///   data: (games) => listView,
///   error: (err, _) => errorWidget,
/// )
///
/// No manual isLoading/hasError booleans needed!

import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/game_model.dart';
import '../repositories/game_repository.dart';

part 'game_viewmodel.g.dart';

/// This provider fetches the game list.
/// autoDispose: true (default) — disposes when no widget is watching.
/// This means it re-fetches every time you navigate back to the games screen.
@riverpod
Future<List<GameModel>> gameList(Ref ref) async {
  final repository = GameRepository();
  return await repository.getUpcomingGames();
}

@riverpod
Future<GameModel> gameDetail(Ref ref, String gameId) async {
  final repository = GameRepository();
  return await repository.getGameById(gameId);
}
