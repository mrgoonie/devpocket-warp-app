import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'ai_service_models.dart';

/// HTTP client for AI service API communication
class AIHttpClient {
  final http.Client _client;
  final AIServiceConfig _config;

  AIHttpClient({
    http.Client? client,
    AIServiceConfig? config,
  }) : _client = client ?? http.Client(),
       _config = config ?? const AIServiceConfig();

  /// Make HTTP request to OpenRouter API
  Future<http.Response> makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    required String apiKey,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${_config.baseUrl}$endpoint');
    final headers = _buildHeaders(apiKey);
    
    late http.Response response;
    final requestTimeout = timeout ?? _config.defaultTimeout;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri, headers: headers)
            .timeout(requestTimeout);
        break;
        
      case 'POST':
        response = await _client.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ).timeout(requestTimeout);
        break;
        
      case 'PUT':
        response = await _client.put(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ).timeout(requestTimeout);
        break;
        
      case 'DELETE':
        response = await _client.delete(uri, headers: headers)
            .timeout(requestTimeout);
        break;
        
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    return response;
  }

  /// Make chat completion request to OpenRouter
  Future<OpenRouterResponse> makeChatCompletion({
    required String prompt,
    required String apiKey,
    String? model,
    double? temperature,
    int? maxTokens,
  }) async {
    final requestBody = {
      'model': model ?? _config.defaultModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': temperature ?? 0.7,
      'max_tokens': maxTokens ?? 1000,
      'stream': false,
    };

    final response = await makeRequest(
      endpoint: '/chat/completions',
      method: 'POST',
      body: requestBody,
      apiKey: apiKey,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return OpenRouterResponse.fromJson(data);
    } else {
      throw _createHttpException(response);
    }
  }

  /// Validate API key
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final response = await makeRequest(
        endpoint: '/auth/key',
        method: 'GET',
        apiKey: apiKey,
        timeout: const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] != null;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get user credits
  Future<Map<String, dynamic>?> getCredits(String apiKey) async {
    try {
      final response = await makeRequest(
        endpoint: '/auth/key',
        method: 'GET',
        apiKey: apiKey,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Build HTTP headers for API requests
  Map<String, String> _buildHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://devpocket.app',
      'X-Title': 'DevPocket',
    };
  }

  /// Create appropriate exception from HTTP response
  Exception _createHttpException(http.Response response) {
    try {
      final errorData = json.decode(response.body);
      final errorMessage = errorData['error']?['message'] ?? 'Unknown API error';
      return Exception('API Error (${response.statusCode}): $errorMessage');
    } catch (e) {
      return Exception('HTTP Error (${response.statusCode}): ${response.reasonPhrase}');
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _client.close();
  }
}