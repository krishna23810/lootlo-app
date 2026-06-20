import 'package:hive_flutter/hive_flutter.dart';

import '../../core/utils/logger.dart';

/// Service for local storage operations using Hive.
class LocalStorageService {
  static const String _authBoxName = 'auth';
  static const String _settingsBoxName = 'settings';
  static const String _cacheBoxName = 'cache';

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userIdKey = 'user_id';
  static const String emailKey = 'email';
  static const String displayNameKey = 'display_name';

  /// Initialize Hive and open required boxes.
  static Future<void> initialize() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(_authBoxName);
    await Hive.openBox<String>(_settingsBoxName);
    await Hive.openBox<dynamic>(_cacheBoxName);
    AppLogger.info('Hive local storage initialized');
  }

  // --- Auth Storage ---

  static Box<String> get _authBox => Hive.box<String>(_authBoxName);

  static Future<void> saveToken(String token) async {
    await _authBox.put(tokenKey, token);
  }

  static String? getToken() {
    return _authBox.get(tokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    await _authBox.put(userIdKey, userId);
  }

  static String? getUserId() {
    return _authBox.get(userIdKey);
  }

  static Future<void> clearAuth() async {
    await _authBox.clear();
  }

  static Future<void> saveRefreshToken(String token) async {
    await _authBox.put(refreshTokenKey, token);
  }

  static String? getRefreshToken() {
    return _authBox.get(refreshTokenKey);
  }

  static Future<void> saveEmail(String email) async {
    await _authBox.put(emailKey, email);
  }

  static String? getEmail() {
    return _authBox.get(emailKey);
  }

  static Future<void> saveDisplayName(String name) async {
    await _authBox.put(displayNameKey, name);
  }

  static String? getDisplayName() {
    return _authBox.get(displayNameKey);
  }

  // --- Settings Storage ---

  static Box<String> get _settingsBox => Hive.box<String>(_settingsBoxName);

  static Future<void> saveSetting(String key, String value) async {
    await _settingsBox.put(key, value);
  }

  static String? getSetting(String key) {
    return _settingsBox.get(key);
  }

  // --- Cache Storage ---

  static Box<dynamic> get _cacheBox => Hive.box<dynamic>(_cacheBoxName);

  static Future<void> cacheData(String key, dynamic value) async {
    await _cacheBox.put(key, value);
  }

  static dynamic getCachedData(String key) {
    return _cacheBox.get(key);
  }

  static Future<void> clearCache() async {
    await _cacheBox.clear();
  }

  /// Close all Hive boxes.
  static Future<void> dispose() async {
    await Hive.close();
  }
}
