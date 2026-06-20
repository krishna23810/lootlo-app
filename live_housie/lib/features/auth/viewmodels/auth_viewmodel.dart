/// Auth ViewModel — manages authentication state with Riverpod.
///
/// THIS IS THE CORE RIVERPOD CONCEPT:
/// ──────────────────────────────────
/// A "Notifier" is a class that HOLDS STATE and provides METHODS to change it.
/// When the state changes, ALL widgets watching this provider automatically rebuild.
///
/// Think of it like:
///   ViewModel holds: "user is logged in" or "loading" or "error"
///   Widgets watch: ref.watch(authViewModelProvider)
///   When state changes: widgets rebuild with new data
///
/// AsyncNotifier specifically handles async operations (API calls) and gives you
/// three states for free: AsyncLoading, AsyncData, AsyncError
/// No manual `isLoading = true` / `isLoading = false` needed!

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../data/services/local_storage_service.dart';
import '../models/auth_response.dart';
import '../repositories/auth_repository.dart';

part 'auth_viewmodel.g.dart';

// ─── Auth State ──────────────────────────────────────────────────────────────

/// The possible states of authentication.
/// Using a sealed class gives us exhaustive pattern matching.
sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final UserData user;
  final String accessToken;
  AuthAuthenticated({required this.user, required this.accessToken});
}

class AuthError extends AuthState {
  final String message;
  final Map<String, dynamic>? fieldErrors; // For field-level validation errors
  AuthError({required this.message, this.fieldErrors});
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

/// @riverpod annotation tells the code generator to create:
/// - authViewModelProvider (the provider you watch in widgets)
/// - AuthViewModelRef (reference type)
///
/// `keepAlive: true` means this provider survives even when no widget is watching.
/// Without it, the auth state would be lost when navigating between screens!
@Riverpod(keepAlive: true)
class AuthViewModel extends _$AuthViewModel {
  late final AuthRepository _repository;

  /// build() is called when the provider is first read.
  /// It's like initState() but for Riverpod.
  /// Returns the initial state.
  @override
  AuthState build() {
    _repository = AuthRepository();
    // Check if user is already logged in (has stored token)
    return _checkSavedAuth();
  }

  /// Check if there's a saved auth token from a previous session.
  AuthState _checkSavedAuth() {
    final token = LocalStorageService.getToken();
    if (token != null) {
      // TODO: Validate token is still valid (call /auth/me or verify expiry)
      // For now, just trust the saved token
      return AuthAuthenticated(
        user: UserData(
          id: '',
          email: LocalStorageService.getEmail() ?? '',
          mobile: '',
          displayName: LocalStorageService.getDisplayName() ?? 'User',
          createdAt: DateTime.now(),
        ),
        accessToken: token,
      );
    }
    return AuthInitial();
  }

  /// Login with email and password.
  ///
  /// HOW STATE UPDATES WORK:
  /// 1. state = AuthLoading() → all watching widgets show loading spinner
  /// 2. API call happens (await)
  /// 3a. Success: state = AuthAuthenticated() → widgets show logged-in UI
  /// 3b. Error: state = AuthError() → widgets show error message
  ///
  /// The widgets don't need ANY logic — they just react to state changes.
  Future<void> login(String email, String password) async {
    state = AuthLoading();

    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );

      // Save tokens locally (persist across app restarts)
      await _saveAuthData(response);

      // Update state → widgets rebuild showing logged-in UI
      state = AuthAuthenticated(
        user: response.user,
        accessToken: response.accessToken,
      );
    } on DioException catch (e) {
      // DioException contains the HTTP error response from our backend
      state = _handleDioError(e);
    } catch (e) {
      state = AuthError(message: 'Something went wrong. Please try again.');
    }
  }

  /// Register a new account.
  Future<void> register({
    required String email,
    required String mobile,
    required String password,
    required String displayName,
  }) async {
    state = AuthLoading();

    try {
      final response = await _repository.register(
        email: email,
        mobile: mobile,
        password: password,
        displayName: displayName,
      );

      await _saveAuthData(response);

      state = AuthAuthenticated(
        user: response.user,
        accessToken: response.accessToken,
      );
    } on DioException catch (e) {
      state = _handleDioError(e);
    } catch (e) {
      state = AuthError(message: 'Something went wrong. Please try again.');
    }
  }

  /// Logout — clear tokens and reset state.
  Future<void> logout() async {
    final refreshToken = LocalStorageService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _repository.logout(refreshToken);
      } catch (_) {
        // Even if server logout fails, clear local state
      }
    }

    await LocalStorageService.clearAuth();
    state = AuthInitial();
  }

  /// Save auth data to local storage.
  Future<void> _saveAuthData(AuthResponse response) async {
    await LocalStorageService.saveToken(response.accessToken);
    await LocalStorageService.saveRefreshToken(response.refreshToken);
    await LocalStorageService.saveEmail(response.user.email);
    await LocalStorageService.saveDisplayName(response.user.displayName);
  }

  /// Convert Dio errors to user-friendly AuthError state.
  AuthError _handleDioError(DioException e) {
    final responseData = e.response?.data;

    if (responseData is Map<String, dynamic>) {
      // Our backend sends: { status, code, message, fields? }
      final message = responseData['message'] as String? ?? 'Request failed';
      final fields = responseData['fields'] as Map<String, dynamic>?;
      return AuthError(message: message, fieldErrors: fields);
    }

    // Network error (no internet, server down)
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AuthError(message: 'Cannot connect to server. Check your internet.');
    }

    return AuthError(message: 'Something went wrong. Please try again.');
  }
}
