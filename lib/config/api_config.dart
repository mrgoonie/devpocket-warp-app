import 'package:flutter/foundation.dart';

/// API configuration for different environments
class ApiConfig {
  static const String _prodBaseUrl = 'https://api.devpocket.app';
  static const String _devBaseUrl = 'https://api.dev.devpocket.app';
  
  /// Get base URL based on current environment
  static String get baseUrl {
    if (kDebugMode) {
      return _devBaseUrl; // Use development server in debug mode
    }
    return _prodBaseUrl; // Use production server in release mode
  }
  
  /// Get WebSocket URL based on current environment
  static String get wsUrl {
    final base = baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
    return '$base/ws';
  }
  
  /// Get WebSocket base URL (without /ws path) for terminal service
  static String get wsBaseUrl {
    return baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');
  }
  
  /// API version prefix
  static const String apiVersion = '/api/v1';
  
  /// Full API base URL with version
  static String get fullBaseUrl => '$baseUrl$apiVersion';
  
  /// Request timeout configurations
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
  
  /// Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(milliseconds: 1000);
  
  /// Rate limiting
  static const int maxConcurrentRequests = 10;
  
  /// OpenRouter API configuration
  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';
  
  /// Health check endpoints
  static const String healthEndpoint = '/health';
  static const String readyEndpoint = '/health/ready';
  static const String liveEndpoint = '/health/live';
  
  /// Environment detection
  static bool get isProduction => !kDebugMode;
  static bool get isDevelopment => kDebugMode;
  
  /// Feature flags
  static bool get enableLogging => kDebugMode;
  static bool get enableRetryOnFailure => true;
  static bool get enableCacheInterceptor => true;
}