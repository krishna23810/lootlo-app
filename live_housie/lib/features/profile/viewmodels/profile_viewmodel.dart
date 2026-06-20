import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/auth_response.dart';
import '../../auth/repositories/auth_repository.dart';

/// Provider that fetches the complete profile details of the authenticated user.
final userProfileProvider = FutureProvider<UserData>((ref) async {
  final repository = AuthRepository();
  return await repository.getMe();
});
