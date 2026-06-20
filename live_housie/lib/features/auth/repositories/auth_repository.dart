/// Auth Repository — makes HTTP calls to the auth API.
///
/// REPOSITORY PATTERN:
/// The repository is the ONLY place that knows about HTTP/Dio.
/// The ViewModel doesn't know or care HOW data is fetched —
/// it just calls repository.login() and gets back an AuthResponse.
///
/// This means:
/// - You can swap Dio for http package later (only change this file)
/// - You can mock this for testing (return fake data without network)
/// - The ViewModel stays clean and focused on business logic

import '../../../data/repositories/base_repository.dart';
import '../models/auth_response.dart';

class AuthRepository extends BaseRepository {
  /// Login with email and password.
  /// Returns AuthResponse on success, throws DioException on failure.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    // response.data = { success: true, data: { accessToken, refreshToken, user } }
    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Register a new user.
  Future<AuthResponse> register({
    required String email,
    required String mobile,
    required String password,
    required String displayName,
  }) async {
    final response = await dio.post('/auth/register', data: {
      'email': email,
      'mobile': mobile,
      'password': password,
      'displayName': displayName,
    });

    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Refresh the access token using refresh token.
  Future<String> refreshToken(String refreshToken) async {
    final response = await dio.post('/auth/refresh', data: {
      'refreshToken': refreshToken,
    });

    return response.data['data']['accessToken'] as String;
  }

  /// Logout — invalidate refresh token on server.
  Future<void> logout(String refreshToken) async {
    await dio.post('/auth/logout', data: {
      'refreshToken': refreshToken,
    });
  }

  /// Get current user profile details.
  Future<UserData> getMe() async {
    final response = await dio.get('/auth/me');
    return UserData.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
