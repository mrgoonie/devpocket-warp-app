import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ai_models.dart';

class AIService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  static const String _defaultModel = 'anthropic/claude-3.5-sonnet';
  static const Duration _defaultTimeout = Duration(seconds: 30);
  // TODO: Implement retry logic for failed API calls
  // static const int _maxRetries = 3;
  
  final http.Client _client;
  String? _apiKey;
  String? _appName;
  String? _appUrl;
  
  // Rate limiting
  final List<DateTime> _requestTimes = [];
  static const int _maxRequestsPerMinute = 20;
  
  AIService({http.Client? client}) : _client = client ?? http.Client();
  
  // Initialize service with user's API key
  Future<void> initialize({
    required String apiKey,
    String? appName,
    String? appUrl,
  }) async {
    _apiKey = apiKey;
    _appName = appName ?? 'DevPocket';
    _appUrl = appUrl ?? 'https://devpocket.app';
  }
  
  // Validate API key by making a test request
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final response = await _makeRequest(
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
  
  // Get available models
  Future<List<AIModel>> getAvailableModels() async {
    try {
      final response = await _makeRequest(
        endpoint: '/models',
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final modelsJson = data['data'] as List;
        
        return modelsJson
            .map((model) => AIModel.fromJson(model))
            .where((model) => model.isAvailable)
            .toList();
      }
      
      // Return default models if API call fails
      return _getDefaultModels();
    } catch (e) {
      return _getDefaultModels();
    }
  }
  
  // Generate command from natural language
  Future<CommandSuggestion> generateCommand(
    String naturalLanguage, {
    CommandContext? context,
    String? model,
  }) async {
    if (_apiKey == null) {
      throw AIError(
        message: 'API key not initialized',
        code: 'no_api_key',
        timestamp: DateTime.now(),
      );
    }
    
    // Check rate limiting
    await _checkRateLimit();
    
    // Build system prompt with context
    final systemPrompt = _buildCommandGenerationPrompt(context);
    
    final messages = [
      AIMessage.system(systemPrompt),
      AIMessage.user('Convert this to a shell command: $naturalLanguage'),
    ];
    
    try {
      final response = await _makeChatCompletion(
        messages: messages,
        model: model ?? _defaultModel,
        maxTokens: 500,
      );
      
      return _parseCommandResponse(response.choices.first.content, naturalLanguage);
    } catch (e) {
      if (e is AIError) rethrow;
      
      throw AIError(
        message: 'Failed to generate command: $e',
        code: 'generation_error',
        timestamp: DateTime.now(),
      );
    }
  }
  
  // Explain command error
  Future<ErrorExplanation> explainError(
    String command,
    String errorOutput, {
    CommandContext? context,
    String? model,
  }) async {
    if (_apiKey == null) {
      throw AIError(
        message: 'API key not initialized',
        code: 'no_api_key',
        timestamp: DateTime.now(),
      );
    }
    
    await _checkRateLimit();
    
    final systemPrompt = _buildErrorExplanationPrompt(context);
    
    final userPrompt = '''
Command executed: $command
Error output: $errorOutput

Please explain this error and provide suggestions to fix it.
''';
    
    final messages = [
      AIMessage.system(systemPrompt),
      AIMessage.user(userPrompt),
    ];
    
    try {
      final response = await _makeChatCompletion(
        messages: messages,
        model: model ?? _defaultModel,
        maxTokens: 800,
      );
      
      return _parseErrorResponse(response.choices.first.content, command, errorOutput);
    } catch (e) {
      if (e is AIError) rethrow;
      
      throw AIError(
        message: 'Failed to explain error: $e',
        code: 'explanation_error',
        timestamp: DateTime.now(),
      );
    }
  }
  
  // Get smart command suggestions based on context
  Future<List<CommandSuggestion>> getSmartSuggestions({
    CommandContext? context,
    List<String>? recentCommands,
    String? currentTask,
    int limit = 5,
  }) async {
    if (_apiKey == null) return [];
    
    try {
      await _checkRateLimit();
      
      final systemPrompt = _buildSuggestionsPrompt(context);
      
      String userPrompt = 'Suggest useful commands for the current context.';
      if (recentCommands?.isNotEmpty == true) {
        userPrompt += '\nRecent commands: ${recentCommands!.take(5).join(', ')}';
      }
      if (currentTask?.isNotEmpty == true) {
        userPrompt += '\nCurrent task: $currentTask';
      }
      
      final messages = [
        AIMessage.system(systemPrompt),
        AIMessage.user(userPrompt),
      ];
      
      final response = await _makeChatCompletion(
        messages: messages,
        model: _defaultModel,
        maxTokens: 600,
      );
      
      return _parseSuggestionsResponse(response.choices.first.content)
          .take(limit)
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  // Check user's remaining credits
  Future<Map<String, dynamic>?> getCredits() async {
    if (_apiKey == null) return null;
    
    try {
      final response = await _makeRequest(
        endpoint: '/credits',
        method: 'GET',
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['data'] as Map<String, dynamic>?;
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Private helper methods
  
  Future<http.Response> _makeRequest({
    required String endpoint,
    required String method,
    Map<String, dynamic>? body,
    String? apiKey,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${apiKey ?? _apiKey}',
    };
    
    if (_appUrl != null) {
      headers['HTTP-Referer'] = _appUrl!;
    }
    if (_appName != null) {
      headers['X-Title'] = _appName!;
    }
    
    http.Response response;
    
    switch (method.toUpperCase()) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(
          timeout ?? _defaultTimeout,
        );
        break;
      case 'POST':
        response = await _client.post(
          uri,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        ).timeout(timeout ?? _defaultTimeout);
        break;
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
    
    if (response.statusCode >= 400) {
      throw _handleHttpError(response);
    }
    
    return response;
  }
  
  Future<OpenRouterResponse> _makeChatCompletion({
    required List<AIMessage> messages,
    required String model,
    int? maxTokens,
    double? temperature,
  }) async {
    final body = {
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'max_tokens': maxTokens ?? 1000,
      'temperature': temperature ?? 0.3,
      'user': 'devpocket_user', // For tracking and abuse prevention
    };
    
    final response = await _makeRequest(
      endpoint: '/chat/completions',
      method: 'POST',
      body: body,
    );
    
    final data = json.decode(response.body);
    return OpenRouterResponse.fromJson(data);
  }
  
  Future<void> _checkRateLimit() async {
    final now = DateTime.now();
    
    // Remove requests older than 1 minute
    _requestTimes.removeWhere(
      (time) => now.difference(time).inMinutes >= 1,
    );
    
    if (_requestTimes.length >= _maxRequestsPerMinute) {
      final oldestRequest = _requestTimes.first;
      final waitTime = const Duration(minutes: 1) - now.difference(oldestRequest);
      
      if (waitTime.inSeconds > 0) {
        await Future.delayed(waitTime);
      }
    }
    
    _requestTimes.add(now);
  }
  
  AIError _handleHttpError(http.Response response) {
    final statusCode = response.statusCode;
    
    try {
      final data = json.decode(response.body);
      final message = data['error']?['message'] as String? ?? 'Unknown error';
      final code = data['error']?['code'] as String? ?? 'unknown';
      
      return AIError(
        message: message,
        code: code,
        httpStatusCode: statusCode,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // If we can't parse the error response
      switch (statusCode) {
        case 401:
          return AIError.invalidApiKey();
        case 402:
          return AIError.quotaExceeded();
        case 429:
          return AIError.rateLimited();
        default:
          return AIError(
            message: 'HTTP $statusCode: ${response.reasonPhrase}',
            code: 'http_error',
            httpStatusCode: statusCode,
            timestamp: DateTime.now(),
          );
      }
    }
  }
  
  String _buildCommandGenerationPrompt(CommandContext? context) {
    final buffer = StringBuffer();
    buffer.writeln('''
You are a terminal command expert. Convert natural language requests to precise shell commands.

Rules:
1. Always provide the exact command that should be executed
2. Use standard UNIX/Linux commands unless specifically asked for other platforms
3. Prioritize safety - avoid destructive operations without explicit confirmation
4. Include necessary flags for human-readable output when appropriate
5. If multiple commands are needed, provide the most important one first

Response format:
COMMAND: [the exact command]
EXPLANATION: [brief explanation of what it does]
CONFIDENCE: [0.0-1.0 confidence score]
TAGS: [comma-separated relevant tags]''');
    
    if (context != null) {
      buffer.writeln('\nContext:');
      buffer.writeln('- OS: ${context.operatingSystem}');
      buffer.writeln('- Shell: ${context.shellType}');
      buffer.writeln('- Current directory: ${context.currentDirectory}');
      buffer.writeln('- Hostname: ${context.hostname}');
      
      if (context.availableCommands.isNotEmpty) {
        buffer.writeln('- Available commands: ${context.availableCommands.take(10).join(', ')}');
      }
    }
    
    return buffer.toString();
  }
  
  String _buildErrorExplanationPrompt(CommandContext? context) {
    return '''
You are a terminal troubleshooting expert. Analyze command errors and provide helpful explanations.

Rules:
1. Explain the error in simple terms
2. Provide specific suggestions to fix the issue
3. List potential root causes
4. Consider the user's current context

Response format:
EXPLANATION: [clear explanation of what went wrong]
SUGGESTIONS: [numbered list of specific fix suggestions]
CAUSES: [bullet points of potential root causes]

${context != null ? 'Context: OS=${context.operatingSystem}, Shell=${context.shellType}, Directory=${context.currentDirectory}' : ''}
''';
  }
  
  String _buildSuggestionsPrompt(CommandContext? context) {
    return '''
You are a productivity assistant for terminal users. Suggest useful commands based on context.

Rules:
1. Suggest practical, commonly-used commands
2. Focus on commands relevant to the current directory and context
3. Include brief explanations
4. Prioritize commands that improve workflow

Response format for each suggestion:
COMMAND: [command]
EXPLANATION: [what it does and why it's useful]
CONFIDENCE: [0.8+ for suggestions]
TAGS: [workflow tags like monitoring, files, network, etc.]

Suggest 3-5 commands separated by "---"

${context != null ? 'Context: OS=${context.operatingSystem}, Directory=${context.currentDirectory}' : ''}
''';
  }
  
  CommandSuggestion _parseCommandResponse(String response, String query) {
    final lines = response.split('\n');
    String command = '';
    String explanation = '';
    double confidence = 0.5;
    List<String> tags = [];
    
    for (final line in lines) {
      if (line.startsWith('COMMAND:')) {
        command = line.substring(8).trim();
      } else if (line.startsWith('EXPLANATION:')) {
        explanation = line.substring(12).trim();
      } else if (line.startsWith('CONFIDENCE:')) {
        final confStr = line.substring(11).trim();
        confidence = double.tryParse(confStr) ?? 0.5;
      } else if (line.startsWith('TAGS:')) {
        final tagStr = line.substring(5).trim();
        tags = tagStr.split(',').map((t) => t.trim()).toList();
      }
    }
    
    // Fallback parsing if structured format isn't followed
    if (command.isEmpty) {
      // Try to extract command from code blocks or first line
      final codeBlockMatch = RegExp(r'```(?:bash|shell)?\s*\n(.+?)\n```', dotAll: true).firstMatch(response);
      if (codeBlockMatch != null) {
        command = codeBlockMatch.group(1)?.trim() ?? '';
      } else {
        // Use first non-empty line that looks like a command
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#') && trimmed.length > 2) {
            command = trimmed;
            break;
          }
        }
      }
    }
    
    if (explanation.isEmpty) {
      explanation = response.length > 200 
          ? '${response.substring(0, 197)}...' 
          : response;
    }
    
    return CommandSuggestion(
      command: command,
      explanation: explanation,
      confidence: confidence.clamp(0.0, 1.0),
      naturalLanguageQuery: query,
      tags: tags,
    );
  }
  
  ErrorExplanation _parseErrorResponse(String response, String command, String error) {
    final lines = response.split('\n');
    String explanation = '';
    List<String> suggestions = [];
    List<String> causes = [];
    
    String currentSection = '';
    
    for (final line in lines) {
      if (line.startsWith('EXPLANATION:')) {
        currentSection = 'explanation';
        explanation = line.substring(12).trim();
      } else if (line.startsWith('SUGGESTIONS:')) {
        currentSection = 'suggestions';
      } else if (line.startsWith('CAUSES:')) {
        currentSection = 'causes';
      } else if (line.trim().isNotEmpty) {
        switch (currentSection) {
          case 'explanation':
            if (explanation.isNotEmpty) explanation += ' ';
            explanation += line.trim();
            break;
          case 'suggestions':
            if (line.trim().startsWith(RegExp(r'\d+\.'))) {
              suggestions.add(line.trim());
            }
            break;
          case 'causes':
            if (line.trim().startsWith('•') || line.trim().startsWith('-')) {
              causes.add(line.trim().substring(1).trim());
            }
            break;
        }
      }
    }
    
    // Fallback if structured parsing fails
    if (explanation.isEmpty) {
      explanation = response.length > 300 ? '${response.substring(0, 297)}...' : response;
    }
    
    return ErrorExplanation(
      originalCommand: command,
      errorOutput: error,
      explanation: explanation,
      suggestions: suggestions,
      potentialCauses: causes,
      timestamp: DateTime.now(),
    );
  }
  
  List<CommandSuggestion> _parseSuggestionsResponse(String response) {
    final suggestions = <CommandSuggestion>[];
    final sections = response.split('---');
    
    for (final section in sections) {
      if (section.trim().isEmpty) continue;
      
      final lines = section.split('\n');
      String command = '';
      String explanation = '';
      double confidence = 0.8;
      List<String> tags = [];
      
      for (final line in lines) {
        if (line.startsWith('COMMAND:')) {
          command = line.substring(8).trim();
        } else if (line.startsWith('EXPLANATION:')) {
          explanation = line.substring(12).trim();
        } else if (line.startsWith('CONFIDENCE:')) {
          final confStr = line.substring(11).trim();
          confidence = double.tryParse(confStr) ?? 0.8;
        } else if (line.startsWith('TAGS:')) {
          final tagStr = line.substring(5).trim();
          tags = tagStr.split(',').map((t) => t.trim()).toList();
        }
      }
      
      if (command.isNotEmpty) {
        suggestions.add(CommandSuggestion(
          command: command,
          explanation: explanation.isNotEmpty ? explanation : 'Useful command for current context',
          confidence: confidence,
          naturalLanguageQuery: 'Context-based suggestion',
          tags: tags,
        ));
      }
    }
    
    return suggestions;
  }
  
  List<AIModel> _getDefaultModels() {
    return [
      const AIModel(
        id: 'anthropic/claude-3.5-sonnet',
        name: 'Claude 3.5 Sonnet',
        description: 'Most intelligent model with excellent command knowledge',
        contextLength: 200000,
        pricing: 0.003,
        isAvailable: true,
        capabilities: ['chat', 'commands', 'analysis'],
      ),
      const AIModel(
        id: 'openai/gpt-4o',
        name: 'GPT-4o',
        description: 'Fast and reliable for command generation',
        contextLength: 128000,
        pricing: 0.0025,
        isAvailable: true,
        capabilities: ['chat', 'commands'],
      ),
      const AIModel(
        id: 'openai/gpt-4o-mini',
        name: 'GPT-4o Mini',
        description: 'Cost-effective option for basic commands',
        contextLength: 128000,
        pricing: 0.00015,
        isAvailable: true,
        capabilities: ['chat', 'commands'],
      ),
    ];
  }
  
  void dispose() {
    _client.close();
  }
}