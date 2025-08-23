import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/api_response.dart';
import '../main.dart';

/// Enhanced API client with authentication, retry logic, and error handling
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();
  
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  ApiClient._() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }
  
  BaseOptions get _baseOptions => BaseOptions(
    baseUrl: ApiConfig.fullBaseUrl,
    connectTimeout: ApiConfig.connectTimeout,
    receiveTimeout: ApiConfig.receiveTimeout,
    sendTimeout: ApiConfig.sendTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'DevPocket/${AppConstants.appVersion} (${Platform.operatingSystem})',
    },
    validateStatus: (status) => status != null && status < 500,
  );
  
  void _setupInterceptors() {
    // Auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _addAuthHeader(options);
          handler.next(options);
        },
        onResponse: (response, handler) {
          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _handleTokenRefresh();
            if (refreshed) {
              // Retry the original request
              final newOptions = error.requestOptions;
              await _addAuthHeader(newOptions);
              try {
                final response = await _dio.fetch(newOptions);
                handler.resolve(response);
                return;
              } catch (retryError) {
                handler.next(DioException.badResponse(
                  statusCode: 401,
                  requestOptions: newOptions,
                  response: Response(
                    requestOptions: newOptions,
                    statusCode: 401,
                    data: {'message': 'Authentication failed'},
                  ),
                ));
                return;
              }
            }
          }
          handler.next(error);
        },
      ),
    );
    
    // Logging interceptor (debug mode only)
    if (ApiConfig.enableLogging) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: false,
          error: true,
          logPrint: (log) => debugPrint('[API] $log'),
        ),
      );
    }
    
    // Retry interceptor
    if (ApiConfig.enableRetryOnFailure) {
      _dio.interceptors.add(_RetryInterceptor());
    }
  }
  
  Future<void> _addAuthHeader(RequestOptions options) async {
    final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
  }
  
  Future<bool> _handleTokenRefresh() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;
      
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(
          headers: {'Authorization': null}, // Remove auth header for refresh
        ),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final newAccessToken = data['data']['accessToken'];
        final newRefreshToken = data['data']['refreshToken'];
        
        await _secureStorage.write(
          key: AppConstants.accessTokenKey,
          value: newAccessToken,
        );
        await _secureStorage.write(
          key: AppConstants.refreshTokenKey,
          value: newRefreshToken,
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      await _clearTokens();
      return false;
    }
  }
  
  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.userIdKey);
  }
  
  // GET request
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // POST request
  Future<ApiResponse<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // PUT request
  Future<ApiResponse<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // DELETE request
  Future<ApiResponse<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }
  
  // Health check
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get(
        ApiConfig.healthEndpoint,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }
  
  ApiResponse<T> _handleResponse<T>(Response response, T Function(dynamic)? fromJson) {
    if (response.statusCode! >= 200 && response.statusCode! < 300) {
      final data = response.data;
      
      if (data is Map<String, dynamic> && data['success'] == true) {
        final responseData = data['data'];
        T? parsedData;
        
        if (fromJson != null && responseData != null) {
          parsedData = fromJson(responseData);
        } else {
          parsedData = responseData as T?;
        }
        
        return ApiResponse.success(
          data: parsedData,
          message: data['message'],
        );
      } else {
        return ApiResponse.error(
          message: data['message'] ?? 'Unknown error occurred',
          statusCode: response.statusCode,
          errors: data['errors'],
        );
      }
    } else {
      final data = response.data;
      return ApiResponse.error(
        message: data?['message'] ?? 'Request failed',
        statusCode: response.statusCode,
        errors: data?['errors'],
      );
    }
  }
  
  // File upload request
  Future<ApiResponse<T>> uploadFile<T>(
    String path,
    List<int> fileBytes,
    String fileName, {
    String fieldName = 'file',
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    T Function(dynamic)? fromJson,
  }) async {
    try {
      final formData = FormData();
      
      // Add file
      formData.files.add(MapEntry(
        fieldName,
        MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      ));
      
      // Add other data if provided
      if (data != null) {
        data.forEach((key, value) {
          formData.fields.add(MapEntry(key, value.toString()));
        });
      }
      
      final response = await _dio.post(
        path,
        data: formData,
        queryParameters: queryParameters,
        options: options,
      );
      
      return _handleResponse<T>(response, fromJson);
    } on DioException catch (e) {
      return _handleError<T>(e);
    }
  }

  ApiResponse<T> _handleError<T>(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;
    List<String>? errors;
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        message = data?['message'] ?? 'Server error occurred';
        errors = data?['errors']?.cast<String>();
        break;
      case DioExceptionType.cancel:
        message = 'Request was cancelled';
        break;
      case DioExceptionType.connectionError:
        message = 'No internet connection. Please check your network.';
        break;
      default:
        message = 'An unexpected error occurred';
    }
    
    return ApiResponse.error(
      message: message,
      statusCode: statusCode,
      errors: errors,
    );
  }
  
  /// Store authentication tokens securely
  Future<void> storeTokens(String accessToken, String refreshToken) async {
    try {
      await _secureStorage.write(
        key: AppConstants.accessTokenKey,
        value: accessToken,
      );
      await _secureStorage.write(
        key: AppConstants.refreshTokenKey,
        value: refreshToken,
      );
      debugPrint('🔐 Tokens stored successfully');
    } catch (e) {
      debugPrint('❌ Failed to store tokens: $e');
      throw Exception('Failed to store authentication tokens');
    }
  }
}

/// Retry interceptor for handling transient failures
class _RetryInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    
    // Don't retry certain status codes
    if (err.response?.statusCode != null) {
      final statusCode = err.response!.statusCode!;
      if (statusCode >= 400 && statusCode < 500) {
        handler.next(err);
        return;
      }
    }
    
    // Check if we should retry
    final retryCount = options.extra['retryCount'] ?? 0;
    if (retryCount >= ApiConfig.maxRetries) {
      handler.next(err);
      return;
    }
    
    // Increment retry count
    options.extra['retryCount'] = retryCount + 1;
    
    // Wait before retry
    await Future.delayed(ApiConfig.retryDelay * (retryCount + 1));
    
    try {
      final response = await Dio().fetch(options);
      handler.resolve(response);
    } catch (e) {
      handler.next(err);
    }
  }
}