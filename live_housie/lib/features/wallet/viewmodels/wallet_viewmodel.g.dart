// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetch wallet balance from API

@ProviderFor(walletBalance)
const walletBalanceProvider = WalletBalanceProvider._();

/// Fetch wallet balance from API

final class WalletBalanceProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>>,
          Map<String, dynamic>,
          FutureOr<Map<String, dynamic>>
        >
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  /// Fetch wallet balance from API
  const WalletBalanceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletBalanceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletBalanceHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>> create(Ref ref) {
    return walletBalance(ref);
  }
}

String _$walletBalanceHash() => r'1d7c531c2dc6b5c5052c5611a8a4ce8c605577b8';

/// Fetch transaction history from API

@ProviderFor(walletTransactions)
const walletTransactionsProvider = WalletTransactionsProvider._();

/// Fetch transaction history from API

final class WalletTransactionsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, dynamic>>,
          Map<String, dynamic>,
          FutureOr<Map<String, dynamic>>
        >
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  /// Fetch transaction history from API
  const WalletTransactionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'walletTransactionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$walletTransactionsHash();

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>> create(Ref ref) {
    return walletTransactions(ref);
  }
}

String _$walletTransactionsHash() =>
    r'6030da427733be2ccdff749d39211719433bd8ad';
