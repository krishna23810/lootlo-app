import '../../../data/repositories/base_repository.dart';

class WalletRepository extends BaseRepository {
  /// Get wallet balance
  Future<Map<String, dynamic>> getBalance() async {
    final response = await dio.get('/wallet/balance');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Get transaction history
  Future<Map<String, dynamic>> getTransactions({int page = 1, int pageSize = 20}) async {
    final response = await dio.get('/wallet/transactions', queryParameters: {
      'page': page,
      'pageSize': pageSize,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Top up wallet (mock payment)
  Future<Map<String, dynamic>> topUp(int amountCents) async {
    final response = await dio.post('/wallet/topup', data: {
      'amountCents': amountCents,
    });
    return response.data['data'] as Map<String, dynamic>;
  }
}
