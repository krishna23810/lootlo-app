// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This provider fetches the game list.
/// autoDispose: true (default) — disposes when no widget is watching.
/// This means it re-fetches every time you navigate back to the games screen.

@ProviderFor(gameList)
const gameListProvider = GameListProvider._();

/// This provider fetches the game list.
/// autoDispose: true (default) — disposes when no widget is watching.
/// This means it re-fetches every time you navigate back to the games screen.

final class GameListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GameModel>>,
          List<GameModel>,
          FutureOr<List<GameModel>>
        >
    with $FutureModifier<List<GameModel>>, $FutureProvider<List<GameModel>> {
  /// This provider fetches the game list.
  /// autoDispose: true (default) — disposes when no widget is watching.
  /// This means it re-fetches every time you navigate back to the games screen.
  const GameListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameListHash();

  @$internal
  @override
  $FutureProviderElement<List<GameModel>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<GameModel>> create(Ref ref) {
    return gameList(ref);
  }
}

String _$gameListHash() => r'cfee75d71cfd07d9bf9c0f510f69dfacf3b06232';
