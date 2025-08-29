import 'package:flutter/foundation.dart';

// OpenRouter API Models

@immutable
class AIMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  
  const AIMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
  
  factory AIMessage.fromJson(Map<String, dynamic> json) {
    return AIMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: DateTime.now(),
    );
  }
  
  // Factory constructors for common message types
  factory AIMessage.user(String content) {
    return AIMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
  }
  
  factory AIMessage.assistant(String content) {
    return AIMessage(
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
    );
  }
  
  factory AIMessage.system(String content) {
    return AIMessage(
      role: 'system',
      content: content,
      timestamp: DateTime.now(),
    );
  }
}

@immutable
class AIModel {
  final String id;
  final String name;
  final String description;
  final int contextLength;
  final double pricing;
  final bool isAvailable;
  final List<String> capabilities;
  
  const AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.contextLength,
    required this.pricing,
    required this.isAvailable,
    required this.capabilities,
  });
  
  factory AIModel.fromJson(Map<String, dynamic> json) {
    return AIModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      contextLength: json['context_length'] as int? ?? 0,
      pricing: (json['pricing']?['prompt'] as num?)?.toDouble() ?? 0.0,
      isAvailable: json['available'] as bool? ?? false,
      capabilities: List<String>.from(json['capabilities'] as List? ?? []),
    );
  }
}

@immutable
class CommandSuggestion {
  final String command;
  final String explanation;
  final double confidence;
  final String naturalLanguageQuery;
  final List<String> tags;
  final Map<String, dynamic> context;
  
  const CommandSuggestion({
    required this.command,
    required this.explanation,
    required this.confidence,
    required this.naturalLanguageQuery,
    this.tags = const [],
    this.context = const {},
  });
  
  factory CommandSuggestion.fromJson(Map<String, dynamic> json) {
    return CommandSuggestion(
      command: json['command'] as String,
      explanation: json['explanation'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      naturalLanguageQuery: json['query'] as String,
      tags: List<String>.from(json['tags'] as List? ?? []),
      context: Map<String, dynamic>.from(json['context'] as Map? ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'explanation': explanation,
      'confidence': confidence,
      'query': naturalLanguageQuery,
      'tags': tags,
      'context': context,
    };
  }
  
  // Confidence level helpers
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.6;
  
  String get confidenceLevel {
    if (isHighConfidence) return 'High';
    if (isMediumConfidence) return 'Medium';
    return 'Low';
  }
}

@immutable
class ErrorExplanation {
  final String originalCommand;
  final String errorOutput;
  final String explanation;
  final List<String> suggestions;
  final List<String> potentialCauses;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  
  const ErrorExplanation({
    required this.originalCommand,
    required this.errorOutput,
    required this.explanation,
    required this.suggestions,
    required this.potentialCauses,
    this.context = const {},
    required this.timestamp,
  });
  
  factory ErrorExplanation.fromJson(Map<String, dynamic> json) {
    return ErrorExplanation(
      originalCommand: json['command'] as String,
      errorOutput: json['error'] as String,
      explanation: json['explanation'] as String,
      suggestions: List<String>.from(json['suggestions'] as List? ?? []),
      potentialCauses: List<String>.from(json['causes'] as List? ?? []),
      context: Map<String, dynamic>.from(json['context'] as Map? ?? {}),
      timestamp: DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'command': originalCommand,
      'error': errorOutput,
      'explanation': explanation,
      'suggestions': suggestions,
      'causes': potentialCauses,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

@immutable
class CommandContext {
  final String currentDirectory;
  final String operatingSystem;
  final List<String> availableCommands;
  final Map<String, String> environmentVariables;
  final List<String> runningProcesses;
  final String shellType;
  final String hostname;
  final List<String>? recentCommands;
  final List<String>? availableTools;
  
  const CommandContext({
    required this.currentDirectory,
    required this.operatingSystem,
    this.availableCommands = const [],
    this.environmentVariables = const {},
    this.runningProcesses = const [],
    required this.shellType,
    required this.hostname,
    this.recentCommands,
    this.availableTools,
  });
  
  factory CommandContext.fromJson(Map<String, dynamic> json) {
    return CommandContext(
      currentDirectory: json['currentDirectory'] as String,
      operatingSystem: json['operatingSystem'] as String,
      availableCommands: List<String>.from(json['availableCommands'] as List? ?? []),
      environmentVariables: Map<String, String>.from(json['environmentVariables'] as Map? ?? {}),
      runningProcesses: List<String>.from(json['runningProcesses'] as List? ?? []),
      shellType: json['shellType'] as String,
      hostname: json['hostname'] as String,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'currentDirectory': currentDirectory,
      'operatingSystem': operatingSystem,
      'availableCommands': availableCommands,
      'environmentVariables': environmentVariables,
      'runningProcesses': runningProcesses,
      'shellType': shellType,
      'hostname': hostname,
    };
  }
}

@immutable
class AIUsageStats {
  final int requestCount;
  final int tokenCount;
  final double estimatedCost;
  final DateTime lastReset;
  final Map<String, int> modelUsage;
  
  const AIUsageStats({
    required this.requestCount,
    required this.tokenCount,
    required this.estimatedCost,
    required this.lastReset,
    this.modelUsage = const {},
  });
  
  factory AIUsageStats.empty() {
    return AIUsageStats(
      requestCount: 0,
      tokenCount: 0,
      estimatedCost: 0.0,
      lastReset: DateTime.now(),
      modelUsage: const {},
    );
  }
  
  factory AIUsageStats.fromJson(Map<String, dynamic> json) {
    return AIUsageStats(
      requestCount: json['requestCount'] as int,
      tokenCount: json['tokenCount'] as int,
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      lastReset: DateTime.parse(json['lastReset'] as String),
      modelUsage: Map<String, int>.from(json['modelUsage'] as Map? ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'requestCount': requestCount,
      'tokenCount': tokenCount,
      'estimatedCost': estimatedCost,
      'lastReset': lastReset.toIso8601String(),
      'modelUsage': modelUsage,
    };
  }
  
  AIUsageStats copyWith({
    int? requestCount,
    int? tokenCount,
    double? estimatedCost,
    DateTime? lastReset,
    Map<String, int>? modelUsage,
  }) {
    return AIUsageStats(
      requestCount: requestCount ?? this.requestCount,
      tokenCount: tokenCount ?? this.tokenCount,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      lastReset: lastReset ?? this.lastReset,
      modelUsage: modelUsage ?? this.modelUsage,
    );
  }
}

@immutable
class OpenRouterResponse {
  final String id;
  final String model;
  final List<AIMessage> choices;
  final Map<String, dynamic> usage;
  final DateTime created;
  
  const OpenRouterResponse({
    required this.id,
    required this.model,
    required this.choices,
    required this.usage,
    required this.created,
  });
  
  factory OpenRouterResponse.fromJson(Map<String, dynamic> json) {
    final choicesJson = json['choices'] as List;
    final choices = choicesJson.map((choice) {
      final message = choice['message'] as Map<String, dynamic>;
      return AIMessage.fromJson(message);
    }).toList();
    
    return OpenRouterResponse(
      id: json['id'] as String,
      model: json['model'] as String,
      choices: choices,
      usage: Map<String, dynamic>.from(json['usage'] as Map? ?? {}),
      created: DateTime.fromMillisecondsSinceEpoch((json['created'] as int) * 1000),
    );
  }
}

@immutable
class AIError {
  final String message;
  final String code;
  final int? httpStatusCode;
  final DateTime timestamp;
  
  const AIError({
    required this.message,
    required this.code,
    this.httpStatusCode,
    required this.timestamp,
  });
  
  factory AIError.fromJson(Map<String, dynamic> json) {
    return AIError(
      message: json['message'] as String,
      code: json['code'] as String,
      httpStatusCode: json['status_code'] as int?,
      timestamp: DateTime.now(),
    );
  }
  
  factory AIError.network(String message) {
    return AIError(
      message: message,
      code: 'network_error',
      timestamp: DateTime.now(),
    );
  }
  
  factory AIError.timeout(String message) {
    return AIError(
      message: message,
      code: 'timeout_error',
      timestamp: DateTime.now(),
    );
  }
  
  factory AIError.invalidApiKey() {
    return AIError(
      message: 'Invalid API key. Please check your OpenRouter API key.',
      code: 'invalid_api_key',
      httpStatusCode: 401,
      timestamp: DateTime.now(),
    );
  }
  
  factory AIError.rateLimited() {
    return AIError(
      message: 'Rate limit exceeded. Please try again later.',
      code: 'rate_limited',
      httpStatusCode: 429,
      timestamp: DateTime.now(),
    );
  }
  
  factory AIError.quotaExceeded() {
    return AIError(
      message: 'API quota exceeded. Please add more credits.',
      code: 'quota_exceeded',
      httpStatusCode: 402,
      timestamp: DateTime.now(),
    );
  }
  
  bool get isRetryable {
    return code == 'network_error' || 
           code == 'timeout_error' || 
           httpStatusCode == 429 ||
           httpStatusCode == 502 ||
           httpStatusCode == 503;
  }
}

// Cache models
@immutable
class CachedCommandSuggestion {
  final CommandSuggestion suggestion;
  final DateTime cachedAt;
  final Duration ttl;
  
  const CachedCommandSuggestion({
    required this.suggestion,
    required this.cachedAt,
    required this.ttl,
  });
  
  bool get isExpired {
    return DateTime.now().difference(cachedAt) > ttl;
  }
  
  factory CachedCommandSuggestion.fromJson(Map<String, dynamic> json) {
    return CachedCommandSuggestion(
      suggestion: CommandSuggestion.fromJson(json['suggestion']),
      cachedAt: DateTime.parse(json['cachedAt'] as String),
      ttl: Duration(milliseconds: json['ttl'] as int),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'suggestion': suggestion.toJson(),
      'cachedAt': cachedAt.toIso8601String(),
      'ttl': ttl.inMilliseconds,
    };
  }
}