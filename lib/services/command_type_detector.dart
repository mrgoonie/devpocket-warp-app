import 'package:flutter/foundation.dart';
import 'persistent_process_detector.dart';

/// UI-friendly command type classification for status icon display
enum CommandType {
  oneShot,    // Quick commands that complete immediately
  continuous, // Long-running monitoring commands  
  interactive // Commands requiring user interaction
}

/// UI-specific information about a command type
@immutable
class CommandTypeInfo {
  final CommandType type;
  final ProcessInfo processInfo;
  final String displayName;
  final String description;
  final bool showActivityIndicator;
  final bool requiresSpecialHandling;

  const CommandTypeInfo({
    required this.type,
    required this.processInfo,
    required this.displayName,
    required this.description,
    this.showActivityIndicator = false,
    this.requiresSpecialHandling = false,
  });

  @override
  String toString() {
    return 'CommandTypeInfo{type: $type, displayName: $displayName, showActivityIndicator: $showActivityIndicator}';
  }
}

/// Service for detecting command types and providing UI-specific information
/// Wraps PersistentProcessDetector with additional UI logic
class CommandTypeDetector {
  static CommandTypeDetector? _instance;
  static CommandTypeDetector get instance => _instance ??= CommandTypeDetector._();

  CommandTypeDetector._();

  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  final Map<String, CommandTypeInfo> _typeCache = {};

  /// Detect command type for UI display purposes
  CommandTypeInfo detectCommandType(String command) {
    final cleanCommand = command.trim().toLowerCase();
    
    // Check cache first
    if (_typeCache.containsKey(cleanCommand)) {
      return _typeCache[cleanCommand]!;
    }

    // Get process information
    final processInfo = _processDetector.detectProcessType(command);
    
    // Map to UI command type
    final commandType = _mapProcessTypeToCommandType(processInfo.type);
    
    // Create UI-specific information
    final typeInfo = CommandTypeInfo(
      type: commandType,
      processInfo: processInfo,
      displayName: _getDisplayName(commandType),
      description: _getDescription(commandType, processInfo),
      showActivityIndicator: _shouldShowActivityIndicator(commandType, processInfo),
      requiresSpecialHandling: processInfo.needsSpecialHandling,
    );
    
    // Cache result
    _typeCache[cleanCommand] = typeInfo;
    return typeInfo;
  }

  /// Map ProcessType to CommandType for UI purposes
  CommandType _mapProcessTypeToCommandType(ProcessType processType) {
    switch (processType) {
      case ProcessType.oneshot:
        return CommandType.oneShot;
      
      case ProcessType.persistent:
      case ProcessType.watcher:
      case ProcessType.devServer:
      case ProcessType.buildTool:
        return CommandType.continuous;
      
      case ProcessType.interactive:
      case ProcessType.repl:
        return CommandType.interactive;
    }
  }

  /// Get display name for command type
  String _getDisplayName(CommandType type) {
    switch (type) {
      case CommandType.oneShot:
        return 'One Shot';
      case CommandType.continuous:
        return 'Continuous';
      case CommandType.interactive:
        return 'Interactive';
    }
  }

  /// Get description for command type
  String _getDescription(CommandType type, ProcessInfo processInfo) {
    switch (type) {
      case CommandType.oneShot:
        return 'Quick command that completes immediately';
      case CommandType.continuous:
        return _getContinuousDescription(processInfo.type);
      case CommandType.interactive:
        return _getInteractiveDescription(processInfo.type);
    }
  }

  /// Get specific description for continuous commands
  String _getContinuousDescription(ProcessType processType) {
    switch (processType) {
      case ProcessType.watcher:
        return 'File watcher or monitoring command';
      case ProcessType.devServer:
        return 'Development server';
      case ProcessType.buildTool:
        return 'Build tool with watch mode';
      case ProcessType.persistent:
        return 'Long-running process';
      default:
        return 'Continuous monitoring command';
    }
  }

  /// Get specific description for interactive commands
  String _getInteractiveDescription(ProcessType processType) {
    switch (processType) {
      case ProcessType.repl:
        return 'Read-Eval-Print Loop';
      case ProcessType.interactive:
        return 'Interactive command requiring input';
      default:
        return 'Interactive command';
    }
  }

  /// Check if command should show activity indicator
  bool _shouldShowActivityIndicator(CommandType type, ProcessInfo processInfo) {
    switch (type) {
      case CommandType.oneShot:
        return false; // One-shot commands are too quick for activity indicators
      case CommandType.continuous:
        return true; // Always show activity for continuous commands
      case CommandType.interactive:
        return processInfo.isPersistent; // Show for persistent interactive commands
    }
  }

  /// Check if command is one-shot type
  bool isOneShot(String command) {
    return detectCommandType(command).type == CommandType.oneShot;
  }

  /// Check if command is continuous type
  bool isContinuous(String command) {
    return detectCommandType(command).type == CommandType.continuous;
  }

  /// Check if command is interactive type
  bool isInteractive(String command) {
    return detectCommandType(command).type == CommandType.interactive;
  }

  /// Get command type for simple enum check
  CommandType getCommandType(String command) {
    return detectCommandType(command).type;
  }

  /// Get all supported command types with examples
  Map<CommandType, List<String>> getCommandExamples() {
    return {
      CommandType.oneShot: [
        'ls', 'pwd', 'cat file.txt', 'grep pattern', 'whoami', 'date',
        'mkdir test', 'cp file1 file2', 'mv old new', 'rm file.txt'
      ],
      CommandType.continuous: [
        'top', 'htop', 'watch ps', 'tail -f log.txt', 'npm run dev',
        'ping google.com', 'docker logs -f container', 'journalctl -f'
      ],
      CommandType.interactive: [
        'vim file.txt', 'nano config.ini', 'ssh user@host', 'python',
        'node', 'mysql', 'psql', 'less large-file.txt', 'man command'
      ],
    };
  }

  /// Clear detection cache
  void clearCache() {
    _typeCache.clear();
    debugPrint('CommandTypeDetector: Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final typeDistribution = <CommandType, int>{};
    for (final info in _typeCache.values) {
      typeDistribution[info.type] = (typeDistribution[info.type] ?? 0) + 1;
    }

    return {
      'cacheSize': _typeCache.length,
      'typeDistribution': typeDistribution.map((k, v) => MapEntry(k.name, v)),
    };
  }

  /// Debug method to get detailed command information
  Map<String, dynamic> debugCommandInfo(String command) {
    final typeInfo = detectCommandType(command);
    return {
      'command': command,
      'type': typeInfo.type.name,
      'processType': typeInfo.processInfo.type.name,
      'displayName': typeInfo.displayName,
      'description': typeInfo.description,
      'showActivityIndicator': typeInfo.showActivityIndicator,
      'requiresSpecialHandling': typeInfo.requiresSpecialHandling,
      'isPersistent': typeInfo.processInfo.isPersistent,
      'requiresInput': typeInfo.processInfo.requiresInput,
      'needsPTY': typeInfo.processInfo.needsPTY,
    };
  }
}