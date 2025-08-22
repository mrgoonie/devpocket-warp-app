import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_chat_models.dart';
import 'openrouter_ai_service.dart';

/// Command types for AI assistance
enum AiCommandType {
  suggestion,
  explanation,
  naturalLanguageConversion,
  errorDiagnosis,
  optimizationTip,
}

/// AI command service result
class AiCommandResult {
  final AiCommandType type;
  final String input;
  final String output;
  final bool success;
  final String? error;
  final DateTime timestamp;
  final AiUsage? usage;
  
  AiCommandResult({
    required this.type,
    required this.input,
    required this.output,
    required this.success,
    this.error,
    DateTime? timestamp,
    this.usage,
  }) : timestamp = timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
  
  factory AiCommandResult.success({
    required AiCommandType type,
    required String input,
    required String output,
    AiUsage? usage,
  }) {
    return AiCommandResult(
      type: type,
      input: input,
      output: output,
      success: true,
      timestamp: DateTime.now(),
      usage: usage,
    );
  }
  
  factory AiCommandResult.failure({
    required AiCommandType type,
    required String input,
    required String error,
  }) {
    return AiCommandResult(
      type: type,
      input: input,
      output: '',
      success: false,
      error: error,
      timestamp: DateTime.now(),
    );
  }
  
  @override
  String toString() {
    return 'AiCommandResult{type: $type, success: $success, input: ${input.length > 30 ? '${input.substring(0, 30)}...' : input}}';
  }
}

/// Terminal context for AI assistance
class TerminalContext {
  final String? currentDirectory;
  final String? shellType;
  final String? operatingSystem;
  final List<String> recentCommands;
  final String? lastCommandOutput;
  final int? lastExitCode;
  final Map<String, String> environmentVariables;
  
  const TerminalContext({
    this.currentDirectory,
    this.shellType,
    this.operatingSystem,
    this.recentCommands = const [],
    this.lastCommandOutput,
    this.lastExitCode,
    this.environmentVariables = const {},
  });
  
  TerminalContext copyWith({
    String? currentDirectory,
    String? shellType,
    String? operatingSystem,
    List<String>? recentCommands,
    String? lastCommandOutput,
    int? lastExitCode,
    Map<String, String>? environmentVariables,
  }) {
    return TerminalContext(
      currentDirectory: currentDirectory ?? this.currentDirectory,
      shellType: shellType ?? this.shellType,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      recentCommands: recentCommands ?? this.recentCommands,
      lastCommandOutput: lastCommandOutput ?? this.lastCommandOutput,
      lastExitCode: lastExitCode ?? this.lastExitCode,
      environmentVariables: environmentVariables ?? this.environmentVariables,
    );
  }
  
  String toContextString() {
    final parts = <String>[];
    
    if (currentDirectory != null) {
      parts.add('Directory: $currentDirectory');
    }
    if (shellType != null) {
      parts.add('Shell: $shellType');
    }
    if (operatingSystem != null) {
      parts.add('OS: $operatingSystem');
    }
    if (recentCommands.isNotEmpty) {
      parts.add('Recent: ${recentCommands.take(3).join(', ')}');
    }
    if (lastExitCode != null && lastExitCode != 0) {
      parts.add('Last exit code: $lastExitCode');
    }
    
    return parts.join(' | ');
  }
}

/// AI command service for terminal assistance
class AiCommandService {
  static AiCommandService? _instance;
  static AiCommandService get instance => _instance ??= AiCommandService._();
  
  final OpenRouterAiService _aiService = OpenRouterAiService.instance;
  final StreamController<AiCommandResult> _resultsController = StreamController.broadcast();
  
  AiCommandService._();
  
  /// Stream of AI command results
  Stream<AiCommandResult> get resultsStream => _resultsController.stream;
  
  /// Check if AI service is configured and ready
  Future<bool> isReady() async {
    return await _aiService.hasApiKey();
  }
  
  /// Get command suggestions based on partial input
  Future<AiCommandResult> getCommandSuggestions({
    required String partialInput,
    TerminalContext? context,
    int maxSuggestions = 5,
  }) async {
    try {
      if (!await isReady()) {
        return AiCommandResult.failure(
          type: AiCommandType.suggestion,
          input: partialInput,
          error: 'AI service not configured. Please add your OpenRouter API key.',
        );
      }
      
      final suggestions = await _aiService.generateCommandSuggestions(
        input: partialInput,
        context: context?.toContextString() ?? 'Terminal command suggestions',
        currentDirectory: context?.currentDirectory,
        shellType: context?.shellType,
        maxSuggestions: maxSuggestions,
      );
      
      final result = AiCommandResult.success(
        type: AiCommandType.suggestion,
        input: partialInput,
        output: suggestions.join('\n'),
      );
      
      _resultsController.add(result);
      return result;
    } catch (e) {
      debugPrint('Error getting command suggestions: $e');
      final result = AiCommandResult.failure(
        type: AiCommandType.suggestion,
        input: partialInput,
        error: e.toString(),
      );
      _resultsController.add(result);
      return result;
    }
  }
  
  /// Explain a command
  Future<AiCommandResult> explainCommand({
    required String command,
    TerminalContext? context,
  }) async {
    try {
      if (!await isReady()) {
        return AiCommandResult.failure(
          type: AiCommandType.explanation,
          input: command,
          error: 'AI service not configured. Please add your OpenRouter API key.',
        );
      }
      
      final explanation = await _aiService.explainCommand(
        command,
        context: context?.toContextString(),
      );
      
      if (explanation != null) {
        final result = AiCommandResult.success(
          type: AiCommandType.explanation,
          input: command,
          output: explanation,
        );
        _resultsController.add(result);
        return result;
      } else {
        final result = AiCommandResult.failure(
          type: AiCommandType.explanation,
          input: command,
          error: 'Could not generate explanation',
        );
        _resultsController.add(result);
        return result;
      }
    } catch (e) {
      debugPrint('Error explaining command: $e');
      final result = AiCommandResult.failure(
        type: AiCommandType.explanation,
        input: command,
        error: e.toString(),
      );
      _resultsController.add(result);
      return result;
    }
  }
  
  /// Convert natural language to command
  Future<AiCommandResult> convertNaturalLanguageToCommand({
    required String naturalLanguage,
    TerminalContext? context,
  }) async {
    try {
      if (!await isReady()) {
        return AiCommandResult.failure(
          type: AiCommandType.naturalLanguageConversion,
          input: naturalLanguage,
          error: 'AI service not configured. Please add your OpenRouter API key.',
        );
      }
      
      final command = await _aiService.naturalLanguageToCommand(
        naturalLanguage: naturalLanguage,
        context: context?.toContextString(),
        currentDirectory: context?.currentDirectory,
        shellType: context?.shellType,
      );
      
      if (command != null) {
        final result = AiCommandResult.success(
          type: AiCommandType.naturalLanguageConversion,
          input: naturalLanguage,
          output: command,
        );
        _resultsController.add(result);
        return result;
      } else {
        final result = AiCommandResult.failure(
          type: AiCommandType.naturalLanguageConversion,
          input: naturalLanguage,
          error: 'Could not convert to command. Request may be unclear or unsafe.',
        );
        _resultsController.add(result);
        return result;
      }
    } catch (e) {
      debugPrint('Error converting natural language: $e');
      final result = AiCommandResult.failure(
        type: AiCommandType.naturalLanguageConversion,
        input: naturalLanguage,
        error: e.toString(),
      );
      _resultsController.add(result);
      return result;
    }
  }
  
  /// Diagnose command errors
  Future<AiCommandResult> diagnoseError({
    required String command,
    required String errorOutput,
    required int exitCode,
    TerminalContext? context,
  }) async {
    try {
      if (!await isReady()) {
        return AiCommandResult.failure(
          type: AiCommandType.errorDiagnosis,
          input: '$command (exit $exitCode)',
          error: 'AI service not configured. Please add your OpenRouter API key.',
        );
      }
      
      final diagnosis = await _diagnoseCommandError(
        command: command,
        errorOutput: errorOutput,
        exitCode: exitCode,
        context: context,
      );
      
      if (diagnosis != null) {
        final result = AiCommandResult.success(
          type: AiCommandType.errorDiagnosis,
          input: '$command (exit $exitCode)',
          output: diagnosis,
        );
        _resultsController.add(result);
        return result;
      } else {
        final result = AiCommandResult.failure(
          type: AiCommandType.errorDiagnosis,
          input: '$command (exit $exitCode)',
          error: 'Could not diagnose error',
        );
        _resultsController.add(result);
        return result;
      }
    } catch (e) {
      debugPrint('Error diagnosing command error: $e');
      final result = AiCommandResult.failure(
        type: AiCommandType.errorDiagnosis,
        input: '$command (exit $exitCode)',
        error: e.toString(),
      );
      _resultsController.add(result);
      return result;
    }
  }
  
  /// Get optimization tips for workflow
  Future<AiCommandResult> getOptimizationTip({
    required List<String> recentCommands,
    TerminalContext? context,
  }) async {
    try {
      if (!await isReady()) {
        return AiCommandResult.failure(
          type: AiCommandType.optimizationTip,
          input: 'workflow optimization',
          error: 'AI service not configured. Please add your OpenRouter API key.',
        );
      }
      
      final tip = await _generateOptimizationTip(
        recentCommands: recentCommands,
        context: context,
      );
      
      if (tip != null) {
        final result = AiCommandResult.success(
          type: AiCommandType.optimizationTip,
          input: 'workflow optimization',
          output: tip,
        );
        _resultsController.add(result);
        return result;
      } else {
        final result = AiCommandResult.failure(
          type: AiCommandType.optimizationTip,
          input: 'workflow optimization',
          error: 'Could not generate optimization tip',
        );
        _resultsController.add(result);
        return result;
      }
    } catch (e) {
      debugPrint('Error generating optimization tip: $e');
      final result = AiCommandResult.failure(
        type: AiCommandType.optimizationTip,
        input: 'workflow optimization',
        error: e.toString(),
      );
      _resultsController.add(result);
      return result;
    }
  }
  
  Future<String?> _diagnoseCommandError({
    required String command,
    required String errorOutput,
    required int exitCode,
    TerminalContext? context,
  }) async {
    final systemPrompt = '''
You are a command-line expert. Analyze the failed command and provide helpful diagnosis.

Include:
1. What likely went wrong
2. Common causes of this error
3. Suggested fixes or alternatives
4. Prevention tips

Keep the response under 200 words and be practical.
''';
    
    final userPrompt = '''
Command: $command
Exit Code: $exitCode
Error Output: $errorOutput
${context != null ? 'Context: ${context.toContextString()}' : ''}

Please diagnose this error and suggest solutions.
''';
    
    final request = AiChatCompletionRequest(
      model: 'openai/gpt-4o-mini',
      messages: [
        AiChatMessage.system(systemPrompt),
        AiChatMessage.user(userPrompt),
      ],
      maxTokens: 300,
      temperature: 0.3,
    );
    
    final response = await _aiService.createChatCompletion(request);
    
    if (response.isSuccess && response.data != null) {
      return response.data!.choices.first.message.content;
    }
    
    return null;
  }
  
  Future<String?> _generateOptimizationTip({
    required List<String> recentCommands,
    TerminalContext? context,
  }) async {
    if (recentCommands.isEmpty) return null;
    
    final systemPrompt = '''
You are a command-line productivity expert. Analyze recent commands and suggest optimizations.

Focus on:
1. Repetitive patterns that could be automated
2. More efficient alternatives
3. Useful aliases or shortcuts
4. Better tool combinations

Provide ONE specific, actionable tip. Keep it under 150 words.
''';
    
    final userPrompt = '''
Recent Commands:
${recentCommands.take(10).join('\n')}

${context != null ? 'Context: ${context.toContextString()}' : ''}

Suggest one optimization tip for this workflow.
''';
    
    final request = AiChatCompletionRequest(
      model: 'openai/gpt-4o-mini',
      messages: [
        AiChatMessage.system(systemPrompt),
        AiChatMessage.user(userPrompt),
      ],
      maxTokens: 200,
      temperature: 0.4,
    );
    
    final response = await _aiService.createChatCompletion(request);
    
    if (response.isSuccess && response.data != null) {
      return response.data!.choices.first.message.content;
    }
    
    return null;
  }
  
  /// Dispose resources
  void dispose() {
    _resultsController.close();
  }
}