import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:starq_app/core/config/app_constants.dart';
import 'package:starq_app/core/config/env_config.dart';
import 'package:starq_app/core/errors/app_exception.dart';
import 'package:starq_app/core/storage/secure_storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;

  void configure() {
    dio.options.baseUrl = EnvConfig.apiBaseUrl;
  }

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService().getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (!kReleaseMode &&
              (error.type == DioExceptionType.connectionError ||
               error.type == DioExceptionType.connectionTimeout)) {
            final candidates = [
              'http://127.0.0.1:3000/api/v1',
              'http://localhost:3000/api/v1',
              'http://192.168.0.100:3000/api/v1',
              'http://192.168.0.105:3000/api/v1',
              'http://192.168.0.118:3000/api/v1',
              'http://10.142.192.147:3000/api/v1',
              'http://10.0.2.2:3000/api/v1',
            ];


            if (error.requestOptions.extra['retried_alternate'] != true) {
              error.requestOptions.extra['retried_alternate'] = true;
              final currentBase = dio.options.baseUrl;
              for (final candidate in candidates) {
                if (candidate == currentBase) continue;
                try {
                  final probeDio = Dio(BaseOptions(
                    connectTimeout: const Duration(seconds: 2),
                    receiveTimeout: const Duration(seconds: 2),
                  ));
                  await probeDio.get('$candidate/health');
                  dio.options.baseUrl = candidate; // lock in the working URL
                  final options = error.requestOptions;
                  options.baseUrl = candidate;
                  final response = await dio.fetch(options);
                  return handler.resolve(response);
                } catch (_) {
                  // try next candidate
                }
              }
              dio.options.baseUrl = currentBase;
            }
          }

          final mappedError = _mapDioError(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: mappedError,
              response: error.response,
              type: error.type,
            ),
          );
        },
      ),
    );
  }

  AppException _mapDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return NetworkException();
    }

    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String message = 'An unexpected error occurred.';

    if (data is Map<String, dynamic> && data['message'] != null) {
      if (data['message'] is List) {
        message = (data['message'] as List).join(', ');
      } else {
        message = data['message'].toString();
      }
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }

    switch (statusCode) {
      case 400:
        return ValidationException(message);
      case 401:
        return UnauthorizedException(message);
      case 403:
        return AppException(message, statusCode: 403);
      case 404:
        return NotFoundException(message);
      case 409:
        return AppException(message, statusCode: 409);
      case 422:
        return ValidationException(message, details: data is Map ? data['details'] : null);
      case 500:
      case 502:
      case 503:
        return ServerException(message);
      default:
        return AppException(message, statusCode: statusCode);
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.get<T>(path, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error!;
      throw AppException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.post<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error!;
      throw AppException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.put<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error!;
      throw AppException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.delete<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error!;
      throw AppException(e.message ?? 'Unknown error');
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await dio.patch<T>(path, data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      if (e.error is AppException) throw e.error!;
      throw AppException(e.message ?? 'Unknown error');
    }
  }
}
