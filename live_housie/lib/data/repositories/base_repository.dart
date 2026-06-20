import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';
import '../services/local_storage_service.dart';

/// Base repository providing shared Dio HTTP client configuration.
///
/// KEY FEATURE: Automatic Token Refresh
/// ─────────────────────────────────────
/// When an API call fails with 401 (token expired):
/// 1. Interceptor catches the error
/// 2. Calls /auth/refresh with the saved refresh token
/// 3. Gets a new access token
/// 4. Saves it to local storage
/// 5. Retries the original request with the new token
///
/// The user never sees the 401 — it's handled silently in the background.
abstract class BaseRepository {
  late final Dio dio;

  /// A separate Dio instance for refresh calls (to avoid interceptor loops)
  static final Dio _refreshDio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  /// Flag to prevent multiple simultaneous refresh attempts
  static bool _isRefreshing = false;

  BaseRepository() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // Add token interceptor with auto-refresh
    dio.interceptors.add(
      InterceptorsWrapper(
        // ─── Attach token to every request ────────────────────────
        onRequest: (options, handler) {
          final token = LocalStorageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },

        // ─── Handle 401: refresh token and retry ──────────────────
        onError: (error, handler) async {
          // Only handle 401 (Unauthorized)
          if (error.response?.statusCode != 401) {
            handler.next(error);
            return;
          }

          // Don't retry refresh requests themselves (avoid infinite loop)
          if (error.requestOptions.path.contains('/auth/refresh')) {
            handler.next(error);
            return;
          }

          // Try to refresh the token
          final refreshToken = LocalStorageService.getRefreshToken();
          if (refreshToken == null || refreshToken.isEmpty) {
            // No refresh token — user must login again
            await LocalStorageService.clearAuth();
            handler.next(error);
            return;
          }

          // Prevent multiple simultaneous refresh attempts
          if (_isRefreshing) {
            handler.next(error);
            return;
          }

          try {
            _isRefreshing = true;

            // Call refresh endpoint (using separate Dio to avoid interceptor loop)
            final response = await _refreshDio.post('/auth/refresh', data: {
              'refreshToken': refreshToken,
            });

            // Save the new access token
            final newAccessToken = response.data['data']['accessToken'] as String;
            await LocalStorageService.saveToken(newAccessToken);

            // Retry the original request with the new token
            final retryOptions = error.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer $newAccessToken';

            final retryResponse = await dio.fetch(retryOptions);
            handler.resolve(retryResponse);
          } on DioException {
            // Refresh failed — token is fully expired, user must login again
            await LocalStorageService.clearAuth();
            handler.next(error);
          } finally {
            _isRefreshing = false;
          }
        },
      ),
    );
  }
}
