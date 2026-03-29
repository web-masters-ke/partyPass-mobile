import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../../core/config/constants.dart';
import '../../core/network/dio_client.dart';

const _storage = FlutterSecureStorage();

final currentUserProvider = FutureProvider<User?>((ref) async {
  final token = await _storage.read(key: AppConstants.tokenKey);
  if (token == null || token.isEmpty) return null;

  // Always try to get fresh data from API (so avatarUrl etc. stay current)
  try {
    final data = await DioClient.instance.get<Map<String, dynamic>>('/users/me');
    final user = User.fromJson(data);
    await _storage.write(key: AppConstants.userKey, value: jsonEncode(user.toJson()));
    return user;
  } catch (_) {
    // Network unavailable — fall back to cached storage
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (userJson == null) return null;
    try {
      return User.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
});

final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  final token = await _storage.read(key: AppConstants.tokenKey);
  return token != null && token.isNotEmpty;
});
