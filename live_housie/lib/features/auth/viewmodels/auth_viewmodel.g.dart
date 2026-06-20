// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_viewmodel.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// @riverpod annotation tells the code generator to create:
/// - authViewModelProvider (the provider you watch in widgets)
/// - AuthViewModelRef (reference type)
///
/// `keepAlive: true` means this provider survives even when no widget is watching.
/// Without it, the auth state would be lost when navigating between screens!

@ProviderFor(AuthViewModel)
const authViewModelProvider = AuthViewModelProvider._();

/// @riverpod annotation tells the code generator to create:
/// - authViewModelProvider (the provider you watch in widgets)
/// - AuthViewModelRef (reference type)
///
/// `keepAlive: true` means this provider survives even when no widget is watching.
/// Without it, the auth state would be lost when navigating between screens!
final class AuthViewModelProvider
    extends $NotifierProvider<AuthViewModel, AuthState> {
  /// @riverpod annotation tells the code generator to create:
  /// - authViewModelProvider (the provider you watch in widgets)
  /// - AuthViewModelRef (reference type)
  ///
  /// `keepAlive: true` means this provider survives even when no widget is watching.
  /// Without it, the auth state would be lost when navigating between screens!
  const AuthViewModelProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authViewModelProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authViewModelHash();

  @$internal
  @override
  AuthViewModel create() => AuthViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authViewModelHash() => r'ad2358e6132a119532725f9d2798c490cd165474';

/// @riverpod annotation tells the code generator to create:
/// - authViewModelProvider (the provider you watch in widgets)
/// - AuthViewModelRef (reference type)
///
/// `keepAlive: true` means this provider survives even when no widget is watching.
/// Without it, the auth state would be lost when navigating between screens!

abstract class _$AuthViewModel extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
