import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../repositories/wallet_repository.dart';

part 'wallet_viewmodel.g.dart';

/// Fetch wallet balance from API
@riverpod
Future<Map<String, dynamic>> walletBalance(Ref ref) async {
  final repo = WalletRepository();
  return await repo.getBalance();
}

/// Fetch transaction history from API
@riverpod
Future<Map<String, dynamic>> walletTransactions(Ref ref) async {
  final repo = WalletRepository();
  return await repo.getTransactions();
}
