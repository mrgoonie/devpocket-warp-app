/// AI chat models for OpenRouter integration
class AiChatMessage {
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String content;
  final String? name;
  final String? toolCallId; // For tool messages
  final List<AiToolCall>? toolCalls; // For assistant messages with tool calls
  final DateTime timestamp;
  
  AiChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCallId,
    this.toolCalls,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
  
  factory AiChatMessage.system(String content) {
    return AiChatMessage(
      role: 'system',
      content: content,
      timestamp: DateTime.now(),
    );
  }
  
  factory AiChatMessage.user(String content) {
    return AiChatMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
    );
  }
  
  factory AiChatMessage.assistant(String content, {List<AiToolCall>? toolCalls}) {
    return AiChatMessage(
      role: 'assistant',
      content: content,
      toolCalls: toolCalls,
      timestamp: DateTime.now(),
    );
  }
  
  factory AiChatMessage.tool(String content, String toolCallId, {String? name}) {
    return AiChatMessage(
      role: 'tool',
      content: content,
      toolCallId: toolCallId,
      name: name,
      timestamp: DateTime.now(),
    );
  }
  
  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      role: json['role'],
      content: json['content'],
      name: json['name'],
      toolCallId: json['tool_call_id'],
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List)
              .map((tc) => AiToolCall.fromJson(tc))
              .toList()
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role,
      'content': content,
    };
    
    if (name != null) json['name'] = name;
    if (toolCallId != null) json['tool_call_id'] = toolCallId;
    if (toolCalls != null) {
      json['tool_calls'] = toolCalls!.map((tc) => tc.toJson()).toList();
    }
    
    return json;
  }
  
  Map<String, dynamic> toJsonWithTimestamp() {
    final json = toJson();
    json['timestamp'] = timestamp.toIso8601String();
    return json;
  }
  
  AiChatMessage copyWith({
    String? role,
    String? content,
    String? name,
    String? toolCallId,
    List<AiToolCall>? toolCalls,
    DateTime? timestamp,
  }) {
    return AiChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      name: name ?? this.name,
      toolCallId: toolCallId ?? this.toolCallId,
      toolCalls: toolCalls ?? this.toolCalls,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  @override
  String toString() {
    return 'AiChatMessage{role: $role, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}}';
  }
}

/// AI tool call model
class AiToolCall {
  final String id;
  final String type; // 'function'
  final AiFunction function;
  
  const AiToolCall({
    required this.id,
    required this.type,
    required this.function,
  });
  
  factory AiToolCall.fromJson(Map<String, dynamic> json) {
    return AiToolCall(
      id: json['id'],
      type: json['type'],
      function: AiFunction.fromJson(json['function']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'function': function.toJson(),
    };
  }
  
  @override
  String toString() {
    return 'AiToolCall{id: $id, function: ${function.name}}';
  }
}

/// AI function model
class AiFunction {
  final String name;
  final String? arguments;
  
  const AiFunction({
    required this.name,
    this.arguments,
  });
  
  factory AiFunction.fromJson(Map<String, dynamic> json) {
    return AiFunction(
      name: json['name'],
      arguments: json['arguments'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (arguments != null) 'arguments': arguments,
    };
  }
  
  @override
  String toString() {
    return 'AiFunction{name: $name}';
  }
}

/// AI tool definition for function calling
class AiTool {
  final String type; // 'function'
  final AiToolFunction function;
  
  const AiTool({
    required this.type,
    required this.function,
  });
  
  factory AiTool.function(AiToolFunction function) {
    return AiTool(
      type: 'function',
      function: function,
    );
  }
  
  factory AiTool.fromJson(Map<String, dynamic> json) {
    return AiTool(
      type: json['type'],
      function: AiToolFunction.fromJson(json['function']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'function': function.toJson(),
    };
  }
  
  @override
  String toString() {
    return 'AiTool{type: $type, function: ${function.name}}';
  }
}

/// AI tool function definition
class AiToolFunction {
  final String name;
  final String? description;
  final Map<String, dynamic> parameters;
  
  const AiToolFunction({
    required this.name,
    this.description,
    required this.parameters,
  });
  
  factory AiToolFunction.fromJson(Map<String, dynamic> json) {
    return AiToolFunction(
      name: json['name'],
      description: json['description'],
      parameters: json['parameters'] ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
      'parameters': parameters,
    };
  }
  
  @override
  String toString() {
    return 'AiToolFunction{name: $name, description: $description}';
  }
}

/// AI chat completion request
class AiChatCompletionRequest {
  final String model;
  final List<AiChatMessage> messages;
  final int? maxTokens;
  final double? temperature;
  final double? topP;
  final List<String>? stop;
  final bool stream;
  final List<AiTool>? tools;
  final dynamic toolChoice; // 'auto', 'none', or specific tool
  final String? user;
  final List<String>? models; // Fallback models for OpenRouter
  
  const AiChatCompletionRequest({
    required this.model,
    required this.messages,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.stop,
    this.stream = false,
    this.tools,
    this.toolChoice,
    this.user,
    this.models,
  });
  
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
    
    if (maxTokens != null) json['max_tokens'] = maxTokens;
    if (temperature != null) json['temperature'] = temperature;
    if (topP != null) json['top_p'] = topP;
    if (stop != null) json['stop'] = stop;
    if (stream) json['stream'] = stream;
    if (tools != null) json['tools'] = tools!.map((t) => t.toJson()).toList();
    if (toolChoice != null) json['tool_choice'] = toolChoice;
    if (user != null) json['user'] = user;
    if (models != null) json['models'] = models;
    
    return json;
  }
  
  @override
  String toString() {
    return 'AiChatCompletionRequest{model: $model, messages: ${messages.length}, stream: $stream}';
  }
}

/// AI chat completion response
class AiChatCompletionResponse {
  final String id;
  final String object;
  final int created;
  final String? model;
  final String? provider;
  final List<AiChatChoice> choices;
  final AiUsage? usage;
  
  const AiChatCompletionResponse({
    required this.id,
    required this.object,
    required this.created,
    this.model,
    this.provider,
    required this.choices,
    this.usage,
  });
  
  factory AiChatCompletionResponse.fromJson(Map<String, dynamic> json) {
    return AiChatCompletionResponse(
      id: json['id'],
      object: json['object'],
      created: json['created'],
      model: json['model'],
      provider: json['provider'],
      choices: (json['choices'] as List)
          .map((c) => AiChatChoice.fromJson(c))
          .toList(),
      usage: json['usage'] != null ? AiUsage.fromJson(json['usage']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'object': object,
      'created': created,
      if (model != null) 'model': model,
      if (provider != null) 'provider': provider,
      'choices': choices.map((c) => c.toJson()).toList(),
      if (usage != null) 'usage': usage!.toJson(),
    };
  }
  
  @override
  String toString() {
    return 'AiChatCompletionResponse{id: $id, model: $model, choices: ${choices.length}}';
  }
}

/// AI chat choice
class AiChatChoice {
  final int index;
  final AiChatMessage message;
  final AiChatMessage? delta; // For streaming responses
  final String? finishReason;
  
  const AiChatChoice({
    required this.index,
    required this.message,
    this.delta,
    this.finishReason,
  });
  
  factory AiChatChoice.fromJson(Map<String, dynamic> json) {
    return AiChatChoice(
      index: json['index'],
      message: AiChatMessage.fromJson(json['message']),
      delta: json['delta'] != null ? AiChatMessage.fromJson(json['delta']) : null,
      finishReason: json['finish_reason'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'index': index,
      'message': message.toJson(),
      if (delta != null) 'delta': delta!.toJson(),
      if (finishReason != null) 'finish_reason': finishReason,
    };
  }
  
  @override
  String toString() {
    return 'AiChatChoice{index: $index, finishReason: $finishReason}';
  }
}

/// AI usage statistics
class AiUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double? cost; // OpenRouter specific
  
  const AiUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    this.cost,
  });
  
  factory AiUsage.fromJson(Map<String, dynamic> json) {
    return AiUsage(
      promptTokens: json['prompt_tokens'],
      completionTokens: json['completion_tokens'],
      totalTokens: json['total_tokens'],
      cost: json['cost']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      if (cost != null) 'cost': cost,
    };
  }
  
  @override
  String toString() {
    return 'AiUsage{total: $totalTokens, prompt: $promptTokens, completion: $completionTokens, cost: $cost}';
  }
}

/// AI model information
class AiModel {
  final String id;
  final String name;
  final String? description;
  final int? contextLength;
  final AiModelPricing? pricing;
  final bool supportsToolCalling;
  final bool supportsStreaming;
  final bool supportsSystemMessage;
  final List<String>? supportedParameters;
  
  const AiModel({
    required this.id,
    required this.name,
    this.description,
    this.contextLength,
    this.pricing,
    this.supportsToolCalling = false,
    this.supportsStreaming = false,
    this.supportsSystemMessage = true,
    this.supportedParameters,
  });
  
  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['id'],
      name: json['name'] ?? json['id'],
      description: json['description'],
      contextLength: json['context_length'],
      pricing: json['pricing'] != null ? AiModelPricing.fromJson(json['pricing']) : null,
      supportsToolCalling: json['supports_tool_calling'] ?? false,
      supportsStreaming: json['supports_streaming'] ?? false,
      supportsSystemMessage: json['supports_system_message'] ?? true,
      supportedParameters: json['supported_parameters'] != null
          ? List<String>.from(json['supported_parameters'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      if (contextLength != null) 'context_length': contextLength,
      if (pricing != null) 'pricing': pricing!.toJson(),
      'supports_tool_calling': supportsToolCalling,
      'supports_streaming': supportsStreaming,
      'supports_system_message': supportsSystemMessage,
      if (supportedParameters != null) 'supported_parameters': supportedParameters,
    };
  }
  
  @override
  String toString() {
    return 'AiModel{id: $id, name: $name, contextLength: $contextLength}';
  }
}

/// AI model pricing information
class AiModelPricing {
  final double? prompt;
  final double? completion;
  final String? currency;
  
  const AiModelPricing({
    this.prompt,
    this.completion,
    this.currency,
  });
  
  factory AiModelPricing.fromJson(Map<String, dynamic> json) {
    return AiModelPricing(
      prompt: json['prompt']?.toDouble(),
      completion: json['completion']?.toDouble(),
      currency: json['currency'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      if (prompt != null) 'prompt': prompt,
      if (completion != null) 'completion': completion,
      if (currency != null) 'currency': currency,
    };
  }
  
  @override
  String toString() {
    return 'AiModelPricing{prompt: $prompt, completion: $completion}';
  }
}