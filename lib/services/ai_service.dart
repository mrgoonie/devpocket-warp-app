import 'dart:async';
import 'package:http/http.dart' as http;

import '../models/ai_models.dart';
import 'ai_service_models.dart';
import 'ai_http_client.dart';
import 'ai_response_parser.dart';
import 'ai_prompt_builder.dart';
import 'ai_rate_limiter.dart';

/// AI service for command generation, error explanation, and smart suggestions
class AIService {
  // Components
  final AIHttpClient _httpClient;
  final AIRateLimiter _rateLimiter;
  
  // State
  AIServiceState _state;

  AIService({
    http.Client? httpClient,
    AIServiceConfig? config,
    int? maxRequestsPerMinute,
  }) : _httpClient = AIHttpClient(
         client: httpClient,
         config: config,
       ),
       _rateLimiter = AIRateLimiter(
         maxRequestsPerMinute: maxRequestsPerMinute ?? 20,
       ),
       _state = const AIServiceState();

  /// Initialize service with user's API key
  Future<void> initialize({
    required String apiKey,
    String? appName,
    String? appUrl,
  }) async {
    _state = _state.copyWith(
      apiKey: apiKey,
      appName: appName,
      appUrl: appUrl,
      isInitialized: true,
    );
  }

  /// Check if service is properly initialized
  bool get isInitialized => _state.isInitialized && _state.apiKey != null;

  /// Validate API key by making a test request
  Future<bool> validateApiKey(String apiKey) async {
    return await _httpClient.validateApiKey(apiKey);
  }

  /// Get available models (returns default models for now)
  Future<List<AIModel>> getAvailableModels() async {
    try {
      // In future, this could fetch from API
      return _getDefaultModels();
    } catch (e) {
      // Return default models if API call fails
      return _getDefaultModels();
    }
  }

  /// Generate command from natural language
  Future<CommandSuggestion> generateCommand(
    String naturalLanguage, {
    CommandContext? context,
    String? model,
  }) async {
    _ensureInitialized();
    
    // Check rate limiting
    await _rateLimiter.checkRateLimit();

    // Build system prompt with context
    final systemPrompt = AIPromptBuilder.buildCommandGenerationPrompt(context);
    final userPrompt = AIPromptBuilder.buildUserPrompt(naturalLanguage, context: context);
    final fullPrompt = '$systemPrompt\n$userPrompt';

    try {
      final response = await _httpClient.makeChatCompletion(
        prompt: fullPrompt,
        apiKey: _state.apiKey!,
        model: model,
      );

      if (response.choices.isNotEmpty) {
        final content = response.choices.first.message.content;
        return AIResponseParser.parseCommandResponse(content);
      } else {
        throw Exception('No response from AI service');
      }
    } catch (e) {
      throw Exception('Failed to generate command: $e');
    }
  }

  /// Explain command error
  Future<ErrorExplanation> explainError(
    String command,
    String errorOutput, {
    CommandContext? context,
    String? model,
  }) async {
    _ensureInitialized();
    
    // Check rate limiting
    await _rateLimiter.checkRateLimit();

    // Build system prompt with context
    final systemPrompt = AIPromptBuilder.buildErrorExplanationPrompt(context);
    final userPrompt = AIPromptBuilder.buildErrorUserPrompt(command, errorOutput, context: context);
    final fullPrompt = '$systemPrompt\n$userPrompt';

    try {
      final response = await _httpClient.makeChatCompletion(
        prompt: fullPrompt,
        apiKey: _state.apiKey!,
        model: model,
      );

      if (response.choices.isNotEmpty) {
        final content = response.choices.first.message.content;
        return AIResponseParser.parseErrorResponse(content);
      } else {
        throw Exception('No response from AI service');
      }
    } catch (e) {
      throw Exception('Failed to explain error: $e');
    }
  }

  /// Get smart command suggestions based on context
  Future<List<CommandSuggestion>> getSmartSuggestions({
    CommandContext? context,
    List<String>? recentCommands,
    String? currentTask,
    String? model,
  }) async {
    _ensureInitialized();
    
    // Check rate limiting
    await _rateLimiter.checkRateLimit();

    // Build prompts
    final systemPrompt = AIPromptBuilder.buildSuggestionsPrompt(context);
    final userPrompt = AIPromptBuilder.buildSuggestionsUserPrompt(
      currentTask: currentTask,
      recentCommands: recentCommands,
      context: context,
    );
    final fullPrompt = '$systemPrompt\n$userPrompt';

    try {
      final response = await _httpClient.makeChatCompletion(
        prompt: fullPrompt,
        apiKey: _state.apiKey!,
        model: model,
      );

      if (response.choices.isNotEmpty) {
        final content = response.choices.first.message.content;
        return AIResponseParser.parseSuggestionsResponse(content);
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Failed to get suggestions: $e');
    }
  }

  /// Check user's remaining credits
  Future<Map<String, dynamic>?> getCredits() async {
    _ensureInitialized();
    return await _httpClient.getCredits(_state.apiKey!);
  }

  /// Get rate limiting statistics
  Map<String, dynamic> getRateLimitStats() {
    return _rateLimiter.getStats();
  }

  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'initialized': _state.isInitialized,
      'hasApiKey': _state.apiKey != null,
      'appName': _state.appName,
      'appUrl': _state.appUrl,
      'rateLimitStats': getRateLimitStats(),
    };
  }

  /// Reset rate limiting
  void resetRateLimit() {
    _rateLimiter.reset();
  }

  /// Dispose resources
  void dispose() {
    _httpClient.dispose();
  }

  /// Ensure service is initialized
  void _ensureInitialized() {
    if (!isInitialized) {
      throw Exception('AI service not initialized. Call initialize() first.');
    }
  }

  /// Get default AI models
  List<AIModel> _getDefaultModels() {
    return [
      const AIModel(
        id: 'anthropic/claude-3.5-sonnet',
        name: 'Claude 3.5 Sonnet',
        description: 'Best overall model for code and reasoning',
        contextLength: 200000,
        pricing: 0.000003,
        isAvailable: true,
        capabilities: ['text', 'code', 'reasoning'],
      ),
      const AIModel(
        id: 'anthropic/claude-3-haiku',
        name: 'Claude 3 Haiku',
        description: 'Fast and efficient for simple tasks',
        contextLength: 200000,
        pricing: 0.00000025,
        isAvailable: true,
        capabilities: ['text', 'code'],
      ),
      const AIModel(
        id: 'openai/gpt-4o',
        name: 'GPT-4o',
        description: 'OpenAI\'s latest model',
        contextLength: 128000,
        pricing: 0.000005,
        isAvailable: true,
        capabilities: ['text', 'code', 'vision'],
      ),
      const AIModel(
        id: 'openai/gpt-4o-mini',
        name: 'GPT-4o Mini',
        description: 'Cost-effective OpenAI model',
        contextLength: 128000,
        pricing: 0.00000015,
        isAvailable: true,
        capabilities: ['text', 'code'],
      ),
    ];
  }
}