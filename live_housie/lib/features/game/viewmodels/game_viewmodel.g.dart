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

@ProviderFor(gameDetail)
const gameDetailProvider = GameDetailFamily._();

final class GameDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<GameModel>,
          GameModel,
          FutureOr<GameModel>
        >
    with $FutureModifier<GameModel>, $FutureProvider<GameModel> {
  const GameDetailProvider._({
    required GameDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gameDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameDetailHash();

  @override
  String toString() {
    return r'gameDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GameModel> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<GameModel> create(Ref ref) {
    final argument = this.argument as String;
    return gameDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GameDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameDetailHash() => r'c9473fc4c27d9d07b228a493f74ad42d6696cf9d';

final class GameDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GameModel>, String> {
  const GameDetailFamily._()
    : super(
        retry: null,
        name: r'gameDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GameDetailProvider call(String gameId) =>
      GameDetailProvider._(argument: gameId, from: this);

  @override
  String toString() => r'gameDetailProvider';
}
