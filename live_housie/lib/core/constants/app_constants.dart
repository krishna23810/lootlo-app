/// Application-wide constants for Live Housie.
class AppConstants {
  AppConstants._();

  static const String appName = 'Lootlo';
  // ─── Production VPS configuration ───
  static const String baseUrl = 'https://api.kktechsolution.app/api';
  static const String wsUrl = 'https://api.kktechsolution.app';
  // ─── For ngrok (signaling only, no video) ───
  // ─── For Android emulator ───
  // static const String baseUrl = 'http://10.176.190.238:3000/api';
  // static const String wsUrl = 'http://10.176.190.238:3000';
  // Game constraints
  static const int maxTicketsPerUser = 6;
  static const int minTicketCount = 10;
  static const int maxTicketCount = 1000;
  static const int minCommission = 1;
  static const int maxCommission = 30;

  // Wallet constraints
  static const int minTopUpAmount = 1;
  static const int maxTopUpAmount = 100000;
  static const int minWithdrawalAmount = 100;
  static const int maxWithdrawalAmount = 50000;

  // WebRTC reconnection
  static const int maxReconnectAttempts = 3;
  static const Duration reconnectInterval = Duration(seconds: 5);

  // Claim retry
  static const int maxClaimRetries = 3;
  static const Duration claimRetryInterval = Duration(seconds: 2);
}
