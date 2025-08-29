/// Models and data classes for AI service

/// OpenRouter API response model
class OpenRouterResponse {
  final String id;
  final String model;
  final List<OpenRouterChoice> choices;
  final OpenRouterUsage? usage;
  final DateTime created;

  const OpenRouterResponse({
    required this.id,
    required this.model,
    required this.choices,
    this.usage,
    required this.created,
  });

  factory OpenRouterResponse.fromJson(Map<String, dynamic> json) {
    return OpenRouterResponse(
      id: json['id'] ?? '',
      model: json['model'] ?? '',
      choices: (json['choices'] as List? ?? [])
          .map((choice) => OpenRouterChoice.fromJson(choice))
          .toList(),
      usage: json['usage'] != null ? OpenRouterUsage.fromJson(json['usage']) : null,
      created: DateTime.fromMillisecondsSinceEpoch((json['created'] ?? 0) * 1000),
    );
  }
}

/// OpenRouter choice model
class OpenRouterChoice {
  final int index;
  final OpenRouterMessage message;
  final String? finishReason;

  const OpenRouterChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });

  factory OpenRouterChoice.fromJson(Map<String, dynamic> json) {
    return OpenRouterChoice(
      index: json['index'] ?? 0,
      message: OpenRouterMessage.fromJson(json['message'] ?? {}),
      finishReason: json['finish_reason'],
    );
  }
}

/// OpenRouter message model
class OpenRouterMessage {
  final String role;
  final String content;

  const OpenRouterMessage({
    required this.role,
    required this.content,
  });

  factory OpenRouterMessage.fromJson(Map<String, dynamic> json) {
    return OpenRouterMessage(
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
    );
  }
}

/// OpenRouter usage model
class OpenRouterUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const OpenRouterUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory OpenRouterUsage.fromJson(Map<String, dynamic> json) {
    return OpenRouterUsage(
      promptTokens: json['prompt_tokens'] ?? 0,
      completionTokens: json['completion_tokens'] ?? 0,
      totalTokens: json['total_tokens'] ?? 0,
    );
  }
}

/// AI service configuration
class AIServiceConfig {
  final String baseUrl;
  final String defaultModel;
  final Duration defaultTimeout;
  final int maxRequestsPerMinute;
  final int maxRetries;

  const AIServiceConfig({
    this.baseUrl = 'https://openrouter.ai/api/v1',
    this.defaultModel = 'anthropic/claude-3.5-sonnet',
    this.defaultTimeout = const Duration(seconds: 30),
    this.maxRequestsPerMinute = 20,
    this.maxRetries = 3,
  });
}

/// Rate limiting state
class RateLimitState {
  final List<DateTime> requestTimes;
  final int maxRequestsPerMinute;

  RateLimitState({
    required this.requestTimes,
    required this.maxRequestsPerMinute,
  });

  bool canMakeRequest() {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    // Remove old requests
    requestTimes.removeWhere((time) => time.isBefore(oneMinuteAgo));
    
    return requestTimes.length < maxRequestsPerMinute;
  }

  void recordRequest() {
    requestTimes.add(DateTime.now());
  }

  Duration getWaitTime() {
    if (canMakeRequest()) return Duration.zero;
    
    final oldestRequest = requestTimes.first;
    final waitUntil = oldestRequest.add(const Duration(minutes: 1));
    return waitUntil.difference(DateTime.now());
  }
}

/// AI service initialization state
class AIServiceState {
  final String? apiKey;
  final String appName;
  final String appUrl;
  final bool isInitialized;

  const AIServiceState({
    this.apiKey,
    this.appName = 'DevPocket',
    this.appUrl = 'https://devpocket.app',
    this.isInitialized = false,
  });

  AIServiceState copyWith({
    String? apiKey,
    String? appName,
    String? appUrl,
    bool? isInitialized,
  }) {
    return AIServiceState(
      apiKey: apiKey ?? this.apiKey,
      appName: appName ?? this.appName,
      appUrl: appUrl ?? this.appUrl,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}