import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'openrouter_ai_service.dart';
import 'command_validator.dart';
import '../models/enhanced_ssh_models.dart';

/// Terminal input modes for switching between direct command input and AI assistance
enum TerminalInputMode {
  command,
  ai,
}

/// Terminal input mode change event
class TerminalInputModeEvent {
  final TerminalInputMode mode;
  final DateTime timestamp;
  final String? context;

  const TerminalInputModeEvent({
    required this.mode,
    required this.timestamp,
    this.context,
  });
}

/// AI command generation request
class AiCommandRequest {
  final String naturalLanguageInput;
  final String? currentWorkingDirectory;
  final List<String>? previousCommands;
  final String? shellType;

  const AiCommandRequest({
    required this.naturalLanguageInput,
    this.currentWorkingDirectory,
    this.previousCommands,
    this.shellType,
  });
}

/// AI command generation response
class AiCommandResponse {
  final String command;
  final String explanation;
  final double confidence;
  final List<String>? warnings;
  final List<String>? alternatives;

  const AiCommandResponse({
    required this.command,
    required this.explanation,
    required this.confidence,
    this.warnings,
    this.alternatives,
  });
}

/// Service for managing terminal input modes and AI command generation
class TerminalInputModeService {
  static TerminalInputModeService? _instance;
  static TerminalInputModeService get instance => _instance ??= TerminalInputModeService._();

  TerminalInputModeService._();

  TerminalInputMode _currentMode = TerminalInputMode.command;
  final StreamController<TerminalInputModeEvent> _modeController = StreamController.broadcast();
  final Map<String, TerminalInputMode> _sessionModes = {};

  /// Stream of input mode changes
  Stream<TerminalInputModeEvent> get modeStream => _modeController.stream;

  /// Current input mode
  TerminalInputMode get currentMode => _currentMode;

  /// Toggle between command and AI input modes
  Future<void> toggleMode([String? sessionId]) async {
    final newMode = _currentMode == TerminalInputMode.command 
        ? TerminalInputMode.ai 
        : TerminalInputMode.command;
    
    await setMode(newMode, sessionId: sessionId);
  }

  /// Set specific input mode
  Future<void> setMode(TerminalInputMode mode, {String? sessionId, String? context}) async {
    final oldMode = _currentMode;
    
    if (sessionId != null) {
      _sessionModes[sessionId] = mode;
    }
    
    _currentMode = mode;

    debugPrint('Terminal input mode changed: ${oldMode.name} -> ${mode.name}');

    _modeController.add(TerminalInputModeEvent(
      mode: mode,
      timestamp: DateTime.now(),
      context: context,
    ));
  }

  /// Get input mode for specific session
  TerminalInputMode getModeForSession(String sessionId) {
    return _sessionModes[sessionId] ?? _currentMode;
  }

  /// Process input based on current mode
  Future<String?> processInput(
    String input, {
    String? sessionId,
    String? currentWorkingDirectory,
    List<String>? previousCommands,
    String? shellType,
  }) async {
    final mode = sessionId != null ? getModeForSession(sessionId) : _currentMode;
    
    switch (mode) {
      case TerminalInputMode.command:
        // Direct command input - return as-is
        return input;
        
      case TerminalInputMode.ai:
        // AI command generation with context
        try {
          final response = await _generateAiCommand(AiCommandRequest(
            naturalLanguageInput: input,
            currentWorkingDirectory: currentWorkingDirectory,
            previousCommands: previousCommands,
            shellType: shellType,
          ));
          return response.command;
        } catch (e) {
          debugPrint('AI command generation failed: $e');
          // Fallback to direct command input
          return input;
        }
    }
  }

  /// Process input and return full AI response with explanation and warnings
  Future<AiCommandResponse?> processInputWithDetails(
    String input, {
    String? sessionId,
    String? currentWorkingDirectory,
    List<String>? previousCommands,
    String? shellType,
  }) async {
    final mode = sessionId != null ? getModeForSession(sessionId) : _currentMode;
    
    switch (mode) {
      case TerminalInputMode.command:
        // Direct command input - create simple response
        return AiCommandResponse(
          command: input,
          explanation: 'Direct command input (no AI processing)',
          confidence: 1.0,
        );
        
      case TerminalInputMode.ai:
        // AI command generation with full details
        try {
          return await _generateAiCommand(AiCommandRequest(
            naturalLanguageInput: input,
            currentWorkingDirectory: currentWorkingDirectory,
            previousCommands: previousCommands,
            shellType: shellType,
          ));
        } catch (e) {
          debugPrint('AI command generation failed: $e');
          return AiCommandResponse(
            command: input,
            explanation: 'AI processing failed, using direct input',
            confidence: 0.1,
            warnings: ['Error: $e'],
          );
        }
    }
  }

  /// Generate AI command from natural language input using OpenRouter API
  Future<AiCommandResponse> _generateAiCommand(AiCommandRequest request) async {
    try {
      final openRouterService = OpenRouterAiService.instance;
      
      // Check if API key is configured
      final hasApiKey = await openRouterService.hasApiKey();
      if (!hasApiKey) {
        return AiCommandResponse(
          command: request.naturalLanguageInput,
          explanation: 'OpenRouter API key not configured. Please add your API key in Settings to enable AI command generation.',
          confidence: 0.1,
          warnings: ['AI assistance requires OpenRouter API key configuration'],
        );
      }

      // Determine shell type and platform
      final shellType = request.shellType ?? _detectShellType();
      final currentOS = Platform.operatingSystem;
      final contextInfo = _buildContextInfo(request, shellType, currentOS);

      // Generate command using OpenRouter API
      final generatedCommand = await openRouterService.naturalLanguageToCommand(
        naturalLanguage: request.naturalLanguageInput,
        context: contextInfo,
        currentDirectory: request.currentWorkingDirectory,
        shellType: shellType,
      );

      if (generatedCommand == null || generatedCommand.isEmpty) {
        return AiCommandResponse(
          command: request.naturalLanguageInput,
          explanation: 'AI could not generate a safe command for this request. Using direct input.',
          confidence: 0.2,
          warnings: ['Request may be unclear or potentially unsafe'],
        );
      }

      // Validate the generated command for safety
      final validationResult = await _validateCommand(generatedCommand, currentOS);
      
      // Get command explanation
      final explanation = await openRouterService.explainCommand(
        generatedCommand,
        context: contextInfo,
      );

      // Generate alternative commands if available
      final alternatives = await _generateAlternatives(
        request.naturalLanguageInput,
        generatedCommand,
        shellType,
        contextInfo,
      );

      // Convert validation result to AiCommandResponse format
      final confidence = _calculateConfidence(validationResult);
      final warnings = _extractWarnings(validationResult);

      return AiCommandResponse(
        command: generatedCommand,
        explanation: explanation ?? 'AI-generated command based on your request',
        confidence: confidence,
        warnings: warnings.isNotEmpty ? warnings : null,
        alternatives: alternatives,
      );
    } catch (e) {
      debugPrint('Error generating AI command: $e');
      
      // Fallback to basic pattern matching for common commands
      return _fallbackCommandGeneration(request);
    }
  }

  /// Detect shell type based on platform and environment
  String _detectShellType() {
    if (Platform.isWindows) {
      return 'cmd'; // or 'powershell' based on user preference
    } else if (Platform.isMacOS || Platform.isLinux) {
      // Try to detect from environment or default to bash
      return Platform.environment['SHELL']?.split('/').last ?? 'bash';
    }
    return 'bash'; // Default fallback
  }

  /// Build context information for AI command generation
  String _buildContextInfo(AiCommandRequest request, String shellType, String currentOS) {
    final context = StringBuffer();
    
    context.writeln('Operating System: $currentOS');
    context.writeln('Shell: $shellType');
    
    if (request.currentWorkingDirectory != null) {
      context.writeln('Current Directory: ${request.currentWorkingDirectory}');
    }
    
    if (request.previousCommands != null && request.previousCommands!.isNotEmpty) {
      context.writeln('Recent Commands:');
      for (final cmd in request.previousCommands!.take(3)) {
        context.writeln('  - $cmd');
      }
    }
    
    context.writeln('\nGenerate safe, commonly used commands. Avoid destructive operations without explicit confirmation.');
    
    return context.toString();
  }

  /// Validate generated command for safety and correctness
  Future<CommandValidationResult> _validateCommand(String command, String currentOS) async {
    try {
      return CommandValidator.validateCommand(
        command,
        level: ValidationLevel.moderate,
        allowFileOperations: true,
        allowNetworkOperations: true,
        allowSystemCommands: false,
      );
    } catch (e) {
      debugPrint('Command validation error: $e');
      return CommandValidationResult.warning(
        'Command validation failed: $e',
        securityLevel: SecurityLevel.low,
      );
    }
  }

  /// Generate alternative commands for the same request
  Future<List<String>?> _generateAlternatives(
    String originalRequest,
    String primaryCommand,
    String shellType,
    String contextInfo,
  ) async {
    try {
      final openRouterService = OpenRouterAiService.instance;
      final alternatives = await openRouterService.generateCommandSuggestions(
        input: originalRequest,
        context: contextInfo,
        maxSuggestions: 3,
      );
      
      // Filter out the primary command and return unique alternatives
      return alternatives
          .where((alt) => alt != primaryCommand && alt.isNotEmpty)
          .take(2)
          .toList();
    } catch (e) {
      debugPrint('Error generating alternatives: $e');
      return null;
    }
  }

  /// Fallback command generation using basic pattern matching
  AiCommandResponse _fallbackCommandGeneration(AiCommandRequest request) {
    final input = request.naturalLanguageInput.toLowerCase().trim();
    
    // Basic command mappings for common requests when API is unavailable
    final commandMappings = <String, AiCommandResponse>{
      'list files': const AiCommandResponse(
        command: 'ls -la',
        explanation: 'List all files and directories with detailed information',
        confidence: 0.8,
        warnings: ['Fallback mode - API unavailable'],
      ),
      'show current directory': const AiCommandResponse(
        command: 'pwd',
        explanation: 'Print the current working directory path',
        confidence: 0.9,
        warnings: ['Fallback mode - API unavailable'],
      ),
      'check disk space': const AiCommandResponse(
        command: 'df -h',
        explanation: 'Display filesystem disk space usage in human-readable format',
        confidence: 0.8,
        warnings: ['Fallback mode - API unavailable'],
      ),
      'show system info': const AiCommandResponse(
        command: 'uname -a',
        explanation: 'Display system information including kernel version',
        confidence: 0.7,
        warnings: ['Fallback mode - API unavailable'],
      ),
    };

    // Check for pattern matches
    for (final entry in commandMappings.entries) {
      if (input.contains(entry.key)) {
        return entry.value;
      }
    }

    // Pattern-based matching for more complex requests
    if (input.contains('create') && input.contains('directory')) {
      final dirName = _extractDirectoryName(input);
      return AiCommandResponse(
        command: 'mkdir ${dirName ?? 'new_directory'}',
        explanation: 'Create a new directory',
        confidence: 0.6,
        warnings: [
          'Fallback mode - API unavailable',
          if (dirName == null) 'Directory name not specified, using default',
        ],
      );
    }

    // Default response when no pattern matches
    return AiCommandResponse(
      command: request.naturalLanguageInput,
      explanation: 'Direct command execution (AI service unavailable)',
      confidence: 0.3,
      warnings: [
        'API service unavailable - using direct input',
        'Please configure OpenRouter API key for AI assistance',
      ],
    );
  }

  /// Calculate confidence based on validation result
  double _calculateConfidence(CommandValidationResult validationResult) {
    if (!validationResult.isAllowed) {
      return 0.1; // Very low confidence for blocked commands
    }

    switch (validationResult.securityLevel) {
      case SecurityLevel.critical:
        return validationResult.isWarning ? 0.8 : 0.95;
      case SecurityLevel.high:
        return validationResult.isWarning ? 0.7 : 0.9;
      case SecurityLevel.medium:
        return validationResult.isWarning ? 0.6 : 0.8;
      case SecurityLevel.low:
        return validationResult.isWarning ? 0.4 : 0.5;
    }
  }

  /// Extract warnings from validation result
  List<String> _extractWarnings(CommandValidationResult validationResult) {
    final warnings = <String>[];
    
    if (validationResult.isWarning) {
      warnings.add('Security warning: ${validationResult.message}');
    }
    
    if (!validationResult.isAllowed) {
      warnings.add('Command blocked: ${validationResult.message}');
    }

    // Add security level information
    if (validationResult.securityLevel == SecurityLevel.low) {
      warnings.add('Low security level - use with caution');
    }
    
    return warnings;
  }

  /// Extract directory name from natural language input
  String? _extractDirectoryName(String input) {
    final words = input.split(' ');
    for (int i = 0; i < words.length; i++) {
      if (words[i].toLowerCase() == 'called' && i + 1 < words.length) {
        return words[i + 1];
      }
      if (words[i].toLowerCase() == 'named' && i + 1 < words.length) {
        return words[i + 1];
      }
    }
    return null;
  }

  /// Get input mode label for UI display
  String getModeLabel(TerminalInputMode mode) {
    switch (mode) {
      case TerminalInputMode.command:
        return 'CMD';
      case TerminalInputMode.ai:
        return 'AI';
    }
  }

  /// Get input mode icon for UI display
  String getModeIcon(TerminalInputMode mode) {
    switch (mode) {
      case TerminalInputMode.command:
        return '💻';
      case TerminalInputMode.ai:
        return '🤖';
    }
  }

  /// Get input mode color for UI theming
  String getModeColor(TerminalInputMode mode) {
    switch (mode) {
      case TerminalInputMode.command:
        return '#4CAF50'; // Green
      case TerminalInputMode.ai:
        return '#2196F3'; // Blue
    }
  }

  /// Get placeholder text for input field based on mode
  String getInputPlaceholder(TerminalInputMode mode) {
    switch (mode) {
      case TerminalInputMode.command:
        return 'Enter command...';
      case TerminalInputMode.ai:
        return 'Describe what you want to do...';
    }
  }

  /// Clear session-specific mode settings
  void clearSessionMode(String sessionId) {
    _sessionModes.remove(sessionId);
  }


  /// Get all session modes for debugging
  Map<String, TerminalInputMode> getSessionModes() {
    return Map.from(_sessionModes);
  }

  /// Reset to default mode
  Future<void> resetToDefaultMode({String? sessionId}) async {
    await setMode(TerminalInputMode.command, sessionId: sessionId, context: 'Reset to default');
  }

  /// Dispose resources
  void dispose() {
    _modeController.close();
    _sessionModes.clear();
  }
}

/// Extensions for TerminalInputMode
extension TerminalInputModeExtension on TerminalInputMode {
  String get displayName {
    switch (this) {
      case TerminalInputMode.command:
        return 'Command Mode';
      case TerminalInputMode.ai:
        return 'AI Assistant Mode';
    }
  }

  String get description {
    switch (this) {
      case TerminalInputMode.command:
        return 'Direct command input for experienced users';
      case TerminalInputMode.ai:
        return 'Natural language input converted to commands';
    }
  }
}