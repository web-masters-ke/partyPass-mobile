import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/config/constants.dart';
import '../../../shared/models/user.dart';

class AuthRepository {
  final _client = DioClient.instance;
  final _storage = const FlutterSecureStorage();

  Future<User> login(String email, String password) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _saveTokens(data, user);
    return user;
  }

  Future<User> register({
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
    final body = <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'password': password,
    };
    if (phone.isNotEmpty) body['phone'] = phone;
    if (role != null) body['role'] = role;
    if (organizerName != null && organizerName.isNotEmpty) body['organizerName'] = organizerName;
    if (payoutMethod != null) body['payoutMethod'] = payoutMethod;
    if (paybillNumber != null && paybillNumber.isNotEmpty) body['paybillNumber'] = paybillNumber;
    if (tillNumber != null && tillNumber.isNotEmpty) body['tillNumber'] = tillNumber;
    if (mpesaAccountRef != null && mpesaAccountRef.isNotEmpty) body['mpesaAccountRef'] = mpesaAccountRef;
    final data = await _client.post<Map<String, dynamic>>(
      '/auth/register',
      data: body,
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _saveTokens(data, user);
    return user;
  }

  Future<void> sendOTP(String phone) async {
    await _client.post<dynamic>(
      '/auth/otp/send',
      data: {'phone': phone},
    );
  }

  Future<User> verifyOTP(String phone, String code) async {
    final data = await _client.post<Map<String, dynamic>>(
      '/auth/otp/verify',
      data: {'phone': phone, 'code': code},
    );
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await _saveTokens(data, user);
    return user;
  }

  Future<void> logout() async {
    try {
      await _client.post<dynamic>('/auth/logout');
    } catch (_) {}
    await _storage.delete(key: AppConstants.tokenKey);
    await _storage.delete(key: AppConstants.refreshTokenKey);
    await _storage.delete(key: AppConstants.userKey);
  }

  Future<User?> refreshToken() async {
    final refreshToken =
        await _storage.read(key: AppConstants.refreshTokenKey);
    final userJson = await _storage.read(key: AppConstants.userKey);
    if (refreshToken == null || userJson == null) return null;
    try {
      final userMap = jsonDecode(userJson) as Map<String, dynamic>;
      final userId = userMap['id']?.toString() ?? '';
      final data = await _client.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'userId': userId, 'refreshToken': refreshToken},
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _saveTokens(data, user);
      return user;
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> data, User user) async {
    final token = data['accessToken']?.toString() ?? '';
    final refresh = data['refreshToken']?.toString() ?? '';
    await _storage.write(key: AppConstants.tokenKey, value: token);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);
    await _storage.write(
        key: AppConstants.userKey, value: jsonEncode(user.toJson()));
  }
}
