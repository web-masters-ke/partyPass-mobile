import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  AppException({required this.message, this.code, this.statusCode});

  @override
  String toString() => message;
}

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Navigator key used to redirect on 401
  static void Function()? onUnauthorized;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Request interceptor: attach token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              await _storage.read(key: AppConstants.tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Unwrap the { success, data } envelope
          final body = response.data;
          if (body is Map<String, dynamic> &&
              body.containsKey('success') &&
              body['success'] == true) {
            response.data = body['data'];
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Clear token and trigger redirect
            await _storage.delete(key: AppConstants.tokenKey);
            await _storage.delete(key: AppConstants.refreshTokenKey);
            onUnauthorized?.call();
          }

          final errorBody = error.response?.data;
          String message = 'Something went wrong';
          String? code;

          // No response = connection/network error
          if (error.response == null) {
            message = 'Could not reach server. Check your connection.';
          } else if (errorBody is Map<String, dynamic>) {
            final err = errorBody['error'];
            if (err is Map<String, dynamic>) {
              message = err['message']?.toString() ?? message;
              code = err['code']?.toString();
            } else if (errorBody['message'] is String) {
              message = errorBody['message'] as String;
            }
          } else if (errorBody is String && errorBody.isNotEmpty) {
            message = errorBody;
          }

          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              response: error.response,
              error: AppException(
                message: message,
                code: code,
                statusCode: error.response?.statusCode,
              ),
            ),
          );
        },
      ),
    );
  }

  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get<T>(path, queryParameters: queryParameters);
      return response.data as T;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<T> post<T>(String path, {dynamic data}) async {
    try {
      final response = await _dio.post<T>(path, data: data);
      return response.data as T;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<T> patch<T>(String path, {dynamic data}) async {
    try {
      final response = await _dio.patch<T>(path, data: data);
      return response.data as T;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<T> delete<T>(String path) async {
    try {
      final response = await _dio.delete<T>(path);
      return response.data as T;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  Future<T> uploadFile<T>(String path, String filePath,
      {String field = 'file'}) async {
    try {
      final formData = FormData.fromMap({
        field: await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post<T>(path, data: formData);
      return response.data as T;
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  AppException _extractError(DioException e) {
    if (e.error is AppException) return e.error as AppException;
    return AppException(
      message: e.message ?? 'Network error',
      statusCode: e.response?.statusCode,
    );
  }
}
