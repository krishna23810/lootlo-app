import 'dart:developer' as developer;

/// Simple app logger utility.
class AppLogger {
  AppLogger._();

  static void debug(String message, {String? tag}) {
    developer.log(message, name: tag ?? 'LiveHousie');
  }

  static void info(String message, {String? tag}) {
    developer.log('[INFO] $message', name: tag ?? 'LiveHousie');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    developer.log(
      '[ERROR] $message',
      name: tag ?? 'LiveHousie',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
