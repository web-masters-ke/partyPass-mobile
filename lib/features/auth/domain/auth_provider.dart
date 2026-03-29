import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/auth_repository.dart';
import '../../../shared/models/user.dart';
import '../../../core/config/constants.dart';
import '../../../shared/providers/auth_provider.dart' show currentUserProvider;

final authRepositoryProvider = Provider((ref) => AuthRepository());

final authStateProvider =
    AsyncNotifierProvider<AuthNotifier, User?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<User?> {
  final _storage = const FlutterSecureStorage();

  @override
  Future<User?> build() async {
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson == null) return null;
    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email, password),
    );
    if (state.hasError) throw state.error!;
    // Flush all cached user data so the new account's data loads fresh
    ref.invalidate(currentUserProvider);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String password,
    String? role,
    String? organizerName,
    String? payoutMethod,
    String? paybillNumber,
    String? tillNumber,
    String? mpesaAccountRef,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).register(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phone,
            password: password,
            role: role,
            organizerName: organizerName,
            payoutMethod: payoutMethod,
            paybillNumber: paybillNumber,
            tillNumber: tillNumber,
            mpesaAccountRef: mpesaAccountRef,
          ),
    );
    if (state.hasError) throw state.error!;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
    ref.invalidate(currentUserProvider);
  }

  void clearError() {
    if (state.hasError) state = const AsyncData(null);
  }
}
