import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ai_chat_models.dart';
import '../models/api_response.dart';
import '../main.dart';

/// OpenRouter AI service for BYOK (Bring Your Own Key) integration
class OpenRouterAiService {
  static OpenRouterAiService? _instance;
  static OpenRouterAiService get instance => _instance ??= OpenRouterAiService._();
  
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _modelsEndpoint = '/models';
  static const String _chatCompletionsEndpoint = '/chat/completions';
  
  OpenRouterAiService._() {
    _dio = Dio(_baseOptions);
    _setupInterceptors();
  }
  
  BaseOptions get _baseOptions => BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5), // Longer for AI responses
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'DevPocket/${AppConstants.appVersion} (${Platform.operatingSystem})',
      'HTTP-Referer': 'https://devpocket.app',
      'X-Title': 'DevPocket - AI-Powered Terminal',
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
      ),
    );
    
    // Logging interceptor (debug mode only)
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: false, // AI responses can be very large
          requestHeader: true,
          responseHeader: false,
          error: true,
          logPrint: (log) => debugPrint('[OpenRouter] $log'),
        ),
      );
    }
  }
  
  Future<void> _addAuthHeader(RequestOptions options) async {
    final apiKey = await getApiKey();
    if (apiKey != null) {
      options.headers['Authorization'] = 'Bearer $apiKey';
    }
  }
  
  /// Get the stored OpenRouter API key
  Future<String?> getApiKey() async {
    return await _secureStorage.read(key: AppConstants.openRouterApiKeyKey);
  }
  
  /// Set the OpenRouter API key
  Future<void> setApiKey(String apiKey) async {
    await _secureStorage.write(
      key: AppConstants.openRouterApiKeyKey,
      value: apiKey,
    );
  }
  
  /// Remove the OpenRouter API key
  Future<void> removeApiKey() async {
    await _secureStorage.delete(key: AppConstants.openRouterApiKeyKey);
  }
  
  /// Check if API key is configured
  Future<bool> hasApiKey() async {
    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
  
  /// Validate the API key by making a simple request
  Future<bool> validateApiKey([String? testApiKey]) async {
    try {
      // Temporarily use test key if provided
      if (testApiKey != null) {
        final currentKey = await getApiKey();
        await setApiKey(testApiKey);
        
        try {
          final models = await getModels();
          await setApiKey(currentKey ?? '');
          return models.isNotEmpty;
        } catch (e) {
          await setApiKey(currentKey ?? '');
          rethrow;
        }
      } else {
        final models = await getModels();
        return models.isNotEmpty;
      }
    } catch (e) {
      debugPrint('API key validation failed: $e');
      return false;
    }
  }
  
  /// Get available models
  Future<List<AiModel>> getModels() async {
    try {
      final response = await _dio.get(_modelsEndpoint);
      
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['data'] is List) {
          return (data['data'] as List)
              .map((modelData) => AiModel.fromJson(modelData))
              .toList();
        } else if (data is List) {
          return data.map((modelData) => AiModel.fromJson(modelData)).toList();
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting models: $e');
      return [];
    }
  }
  
  /// Get models filtered by capability
  Future<List<AiModel>> getModelsWithCapability({
    bool? supportsToolCalling,
    bool? supportsStreaming,
    int? minContextLength,
  }) async {
    final allModels = await getModels();
    
    return allModels.where((model) {
      if (supportsToolCalling != null && model.supportsToolCalling != supportsToolCalling) {
        return false;
      }
      if (supportsStreaming != null && model.supportsStreaming != supportsStreaming) {
        return false;
      }
      if (minContextLength != null && (model.contextLength ?? 0) < minContextLength) {
        return false;
      }
      return true;
    }).toList();
  }
  
  /// Create a chat completion
  Future<ApiResponse<AiChatCompletionResponse>> createChatCompletion(
    AiChatCompletionRequest request,
  ) async {
    try {
      final hasKey = await hasApiKey();
      if (!hasKey) {
        return const ApiResponse.error(
          message: 'OpenRouter API key not configured. Please add your API key in Settings.',
          statusCode: 401,
        );
      }
      
      final response = await _dio.post(
        _chatCompletionsEndpoint,
        data: request.toJson(),
      );
      
      if (response.statusCode == 200) {
        final completionResponse = AiChatCompletionResponse.fromJson(response.data);
        return ApiResponse.success(data: completionResponse);
      } else {
        return _handleErrorResponse(response);
      }
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      debugPrint('Error creating chat completion: $e');
      return ApiResponse.error(
        message: 'An unexpected error occurred: $e',
      );
    }
  }
  
  /// Create a streaming chat completion
  Stream<AiChatCompletionResponse> createStreamingChatCompletion(
    AiChatCompletionRequest request,
  ) async* {
    try {
      final hasKey = await hasApiKey();
      if (!hasKey) {
        throw Exception('OpenRouter API key not configured. Please add your API key in Settings.');
      }
      
      final streamRequest = AiChatCompletionRequest(
        model: request.model,
        messages: request.messages,
        maxTokens: request.maxTokens,
        temperature: request.temperature,
        topP: request.topP,
        stop: request.stop,
        stream: true,
        tools: request.tools,
        toolChoice: request.toolChoice,
        user: request.user,
        models: request.models,
      );
      
      final response = await _dio.post(
        _chatCompletionsEndpoint,
        data: streamRequest.toJson(),
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final stream = response.data as ResponseBody;
        
        await for (final chunk in _parseServerSentEvents(stream.stream)) {
          if (chunk.isNotEmpty && chunk != '[DONE]') {
            try {
              final data = json.decode(chunk);
              yield AiChatCompletionResponse.fromJson(data);
            } catch (e) {
              debugPrint('Error parsing streaming response: $e');
              // Continue to next chunk
            }
          }
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    } catch (e) {
      debugPrint('Error creating streaming chat completion: $e');
      throw Exception('Streaming error: $e');
    }
  }
  
  /// Parse Server-Sent Events stream
  Stream<String> _parseServerSentEvents(Stream<List<int>> stream) async* {
    String buffer = '';
    
    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      
      // Process complete lines
      while (buffer.contains('\n')) {
        final newlineIndex = buffer.indexOf('\n');
        final line = buffer.substring(0, newlineIndex).trim();
        buffer = buffer.substring(newlineIndex + 1);
        
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            yield '[DONE]';
            return;
          }
          yield data;
        }
      }
    }
  }
  
  /// Generate command suggestions using AI
  Future<List<String>> generateCommandSuggestions({
    required String input,
    required String context,
    String? currentDirectory,
    String? shellType,
    int maxSuggestions = 5,
  }) async {
    try {
      final systemPrompt = _buildCommandSuggestionPrompt(
        context: context,
        currentDirectory: currentDirectory,
        shellType: shellType ?? 'bash',
        maxSuggestions: maxSuggestions,
      );
      
      final request = AiChatCompletionRequest(
        model: 'openai/gpt-4o-mini', // Fast, cost-effective model for suggestions
        messages: [
          AiChatMessage.system(systemPrompt),
          AiChatMessage.user(input),
        ],
        maxTokens: 200,
        temperature: 0.1, // Low temperature for consistent suggestions
      );
      
      final response = await createChatCompletion(request);
      
      if (response.isSuccess && response.data != null) {
        final content = response.data!.choices.first.message.content;
        return _parseCommandSuggestions(content, maxSuggestions);
      }
      
      return [];
    } catch (e) {
      debugPrint('Error generating command suggestions: $e');
      return [];
    }
  }
  
  /// Explain a command using AI
  Future<String?> explainCommand(String command, {String? context}) async {
    try {
      const systemPrompt = '''
You are a command-line expert. Explain the given command in a clear, concise way.
Include:
1. What the command does
2. Key options and arguments
3. Potential risks or important notes
4. Example output if relevant

Keep the explanation under 200 words and use simple language.
''';
      
      final userPrompt = context != null 
          ? 'Context: $context\n\nExplain this command: $command'
          : 'Explain this command: $command';
      
      final request = AiChatCompletionRequest(
        model: 'openai/gpt-4o-mini',
        messages: [
          AiChatMessage.system(systemPrompt),
          AiChatMessage.user(userPrompt),
        ],
        maxTokens: 300,
        temperature: 0.3,
      );
      
      final response = await createChatCompletion(request);
      
      if (response.isSuccess && response.data != null) {
        return response.data!.choices.first.message.content;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error explaining command: $e');
      return null;
    }
  }
  
  /// Convert natural language to command
  Future<String?> naturalLanguageToCommand({
    required String naturalLanguage,
    String? context,
    String? currentDirectory,
    String? shellType,
  }) async {
    try {
      final systemPrompt = '''
You are a command-line expert. Convert natural language requests to precise shell commands.

## Rules:
1. Return ONLY the command, no explanation
2. Use ${shellType ?? 'bash'} syntax
3. Consider the current directory: ${currentDirectory ?? '/'}
4. Be safe - avoid destructive commands without explicit confirmation
5. If the request is unclear or dangerous, respond with "UNSAFE" or "UNCLEAR"

## Context: 
${context ?? 'General command line usage'}
''';
      
      final request = AiChatCompletionRequest(
        model: 'openai/gpt-4o-mini',
        messages: [
          AiChatMessage.system(systemPrompt),
          AiChatMessage.user(naturalLanguage),
        ],
        maxTokens: 100,
        temperature: 0.1,
      );
      
      final response = await createChatCompletion(request);
      
      if (response.isSuccess && response.data != null) {
        final command = response.data!.choices.first.message.content.trim();
        
        // Safety checks
        if (command.contains('UNSAFE') || command.contains('UNCLEAR')) {
          return null;
        }
        
        return command;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error converting natural language to command: $e');
      return null;
    }
  }
  
  String _buildCommandSuggestionPrompt({
    required String context,
    String? currentDirectory,
    required String shellType,
    required int maxSuggestions,
  }) {
    return '''
You are a command-line expert assistant. Generate $maxSuggestions relevant shell command suggestions based on the user's input.

Context: $context
Shell: $shellType
Current Directory: ${currentDirectory ?? 'unknown'}

Rules:
1. Return only the commands, one per line
2. No explanations, just the commands
3. Order by relevance and safety
4. Consider the current context and directory
5. Prefer commonly used, safe commands
6. Return exactly $maxSuggestions suggestions

Format:
command1
command2
command3
''';
  }
  
  List<String> _parseCommandSuggestions(String content, int maxSuggestions) {
    final suggestions = content
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && !s.startsWith('#'))
        .take(maxSuggestions)
        .toList();
    
    return suggestions;
  }
  
  ApiResponse<AiChatCompletionResponse> _handleErrorResponse(Response response) {
    final data = response.data;
    String message = 'Request failed';
    
    if (data is Map) {
      message = data['error']?['message'] ?? data['message'] ?? message;
    }
    
    return ApiResponse.error(
      message: message,
      statusCode: response.statusCode,
    );
  }
  
  ApiResponse<AiChatCompletionResponse> _handleDioError(DioException error) {
    String message;
    int? statusCode = error.response?.statusCode;
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        break;
      case DioExceptionType.receiveTimeout:
        message = 'AI response timeout. The model might be overloaded.';
        break;
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map) {
          message = data['error']?['message'] ?? data['message'] ?? 'Server error';
          
          // Handle specific OpenRouter errors
          if (statusCode == 401) {
            message = 'Invalid API key. Please check your OpenRouter API key.';
          } else if (statusCode == 402) {
            message = 'Insufficient credits. Please top up your OpenRouter account.';
          } else if (statusCode == 429) {
            message = 'Rate limited. Please wait before making more requests.';
          }
        } else {
          message = 'Server error occurred';
        }
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
    );
  }
  
  String _getDioErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.receiveTimeout:
        return 'AI response timeout. The model might be overloaded.';
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map) {
          return data['error']?['message'] ?? data['message'] ?? 'Server error';
        }
        return 'Server error occurred';
      case DioExceptionType.cancel:
        return 'Request was cancelled';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      default:
        return 'An unexpected error occurred';
    }
  }
}