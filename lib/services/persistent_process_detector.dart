import 'package:flutter/foundation.dart';

/// Types of processes based on their interaction and persistence patterns
enum ProcessType {
  oneshot,       // Regular commands that run and complete (ls, echo, etc.)
  interactive,   // Commands that need user interaction in their block
  persistent,    // Long-running processes that need to stay active
  watcher,       // File watchers and monitoring commands
  repl,         // Read-Eval-Print loops
  devServer,    // Development servers
  buildTool,    // Build tools with watch mode
}

/// Information about a detected process
@immutable
class ProcessInfo {
  final ProcessType type;
  final String command;
  final bool requiresInput;
  final bool isPersistent;
  final bool needsPTY;
  final bool requiresFullscreen;
  final String? processName;
  final Map<String, dynamic> metadata;

  const ProcessInfo({
    required this.type,
    required this.command,
    this.requiresInput = false,
    this.isPersistent = false,
    this.needsPTY = false,
    this.requiresFullscreen = false,
    this.processName,
    this.metadata = const {},
  });

  /// Check if process should remain active in its block
  bool get shouldStayActive => isPersistent || requiresInput;

  /// Check if process needs special handling
  bool get needsSpecialHandling => type != ProcessType.oneshot;

  @override
  String toString() {
    return 'ProcessInfo{type: $type, command: $command, persistent: $isPersistent, requiresInput: $requiresInput, requiresFullscreen: $requiresFullscreen}';
  }
}

/// Service for detecting different types of terminal processes and their interaction requirements
class PersistentProcessDetector {
  static PersistentProcessDetector? _instance;
  static PersistentProcessDetector get instance => _instance ??= PersistentProcessDetector._();

  PersistentProcessDetector._();

  /// Pattern-based detection for different command types
  static final Map<ProcessType, List<RegExp>> _patterns = {
    // Interactive REPLs and AI assistants (less specific patterns)
    ProcessType.repl: [
      RegExp(r'^(python|python3)$'),  // Only exact match for python without args
      RegExp(r'^(node|nodejs)$'),     // Only exact match for node without args
      RegExp(r'^(irb|ruby)(\s|$)'),
      RegExp(r'^(julia)(\s|$)'),
      RegExp(r'^(R|r)(\s|$)'),
      RegExp(r'^(scala)(\s|$)'),
      RegExp(r'^(clojure|clj)(\s|$)'),
      RegExp(r'^(ghci|runghc)(\s|$)'),
      RegExp(r'^(erl|iex)(\s|$)'),
      RegExp(r'^(psql|mysql|sqlite3|redis-cli)(\s|$)'),
      RegExp(r'^(claude|ai)(\s|$)'),  // AI assistants
    ],

    // Development servers
    ProcessType.devServer: [
      RegExp(r'^(npm|pnpm|yarn|bun)\s+run\s+(dev|start|serve)'),
      RegExp(r'^(npm|pnpm|yarn|bun)\s+(dev|start|serve)'),
      RegExp(r'^(next|vite|parcel|webpack-dev-server)(\s|$)'),
      RegExp(r'^(rails|bundle\s+exec\s+rails)\s+(server|s)'),
      RegExp(r'^(django-admin|python\s+manage\.py)\s+runserver'),
      RegExp(r'^(flask|python\s+.*\.py)\s+run'),
      RegExp(r'^(fastapi|uvicorn)(\s|$)'),
      RegExp(r'^(gatsby|nuxt)\s+(dev|develop)'),
      RegExp(r'^(hugo|jekyll)\s+serve'),
      RegExp(r'^(flutter)\s+run'),
      RegExp(r'^(expo|react-native)\s+start'),
    ],

    // File watchers and monitoring
    ProcessType.watcher: [
      RegExp(r'^(watch)(\s|$)'),
      RegExp(r'^(nodemon)(\s|$)'),
      RegExp(r'^(tail)\s+(-f|--follow)'),
      RegExp(r'^(docker)\s+logs\s+(-f|--follow)'),
      RegExp(r'^(kubectl)\s+logs\s+(-f|--follow)'),
      RegExp(r'^(journalctl)\s+(-f|--follow)'),
      RegExp(r'--watch(\s|$)'),
      RegExp(r'--continuous(\s|$)'),
    ],

    // Build tools with watch capability
    ProcessType.buildTool: [
      RegExp(r'^(make)\s+watch'),
      RegExp(r'^(gradle|gradlew).*--continuous'),
      RegExp(r'^(cargo)\s+watch'),
      RegExp(r'^(webpack)\s+--watch'),
      RegExp(r'^(tsc|typescript)\s+--watch'),
      RegExp(r'^(sass|less)\s+--watch'),
      RegExp(r'^(rollup)\s+--watch'),
      RegExp(r'^(esbuild)\s+--watch'),
    ],

    // Interactive commands that need input
    ProcessType.interactive: [
      RegExp(r'^(vi|vim|nvim|emacs)(\s|$)'),
      RegExp(r'^(nano|micro|pico)(\s|$)'),
      RegExp(r'^(top|htop|btop|atop)(\s|$)'),
      RegExp(r'^(less|more)(\s|$)'),
      RegExp(r'^(man)(\s|$)'),
      RegExp(r'^(tmux|screen)(\s|$)'),
      RegExp(r'^(git)\s+(log|diff|show)'),
      RegExp(r'^(ssh)(\s|$)'),
      RegExp(r'^(ftp|sftp)(\s|$)'),
    ],
  };

  /// Special command signatures that override pattern matching
  static final Map<String, ProcessInfo> _specialCommands = {
    'claude': const ProcessInfo(
      type: ProcessType.repl,
      command: 'claude',
      requiresInput: true,
      isPersistent: true,
      needsPTY: true,
      processName: 'claude',
      metadata: {'isAI': true},
    ),
    // Removed python and node to allow pattern-based detection for complex commands
  };

  /// Advanced command analysis for complex scenarios
  final Map<String, ProcessInfo> _commandCache = {};

  /// Detect process type and interaction requirements
  ProcessInfo detectProcessType(String command) {
    final cleanCommand = command.trim().toLowerCase();
    
    // Check cache first
    if (_commandCache.containsKey(cleanCommand)) {
      return _commandCache[cleanCommand]!;
    }

    // Check special commands first
    final firstWord = cleanCommand.split(' ').first;
    if (_specialCommands.containsKey(firstWord)) {
      final info = _specialCommands[firstWord]!;
      _commandCache[cleanCommand] = info;
      return info;
    }

    // Pattern-based detection - check more specific patterns first
    final processTypesInOrder = [
      ProcessType.devServer,    // Most specific patterns
      ProcessType.watcher,
      ProcessType.buildTool,
      ProcessType.interactive,
      ProcessType.repl,         // Less specific patterns last
      ProcessType.persistent,
    ];
    
    for (final processType in processTypesInOrder) {
      final patterns = _patterns[processType];
      if (patterns != null) {
        for (final pattern in patterns) {
          if (pattern.hasMatch(cleanCommand)) {
            final info = _createProcessInfo(processType, command, cleanCommand);
            _commandCache[cleanCommand] = info;
            return info;
          }
        }
      }
    }

    // Default to oneshot if no pattern matches
    final info = ProcessInfo(
      type: ProcessType.oneshot,
      command: command,
      requiresInput: false,
      isPersistent: false,
      needsPTY: false,
    );
    
    _commandCache[cleanCommand] = info;
    return info;
  }

  /// Create ProcessInfo based on detected type
  ProcessInfo _createProcessInfo(ProcessType type, String originalCommand, String cleanCommand) {
    switch (type) {
      case ProcessType.repl:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: true,
          isPersistent: true,
          needsPTY: true,
          processName: _extractProcessName(cleanCommand),
          metadata: const {'supportsHistory': true, 'multiline': true},
        );

      case ProcessType.devServer:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: false,
          isPersistent: true,
          needsPTY: false,
          processName: _extractProcessName(cleanCommand),
          metadata: const {'isServer': true, 'hasLogs': true, 'canRestart': true},
        );

      case ProcessType.watcher:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: false,
          isPersistent: true,
          needsPTY: false,
          processName: _extractProcessName(cleanCommand),
          metadata: const {'streamingOutput': true, 'canInterrupt': true},
        );

      case ProcessType.buildTool:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: false,
          isPersistent: true,
          needsPTY: false,
          processName: _extractProcessName(cleanCommand),
          metadata: const {'buildsOnChange': true, 'hasProgress': true},
        );

      case ProcessType.interactive:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: true,
          isPersistent: true,
          needsPTY: true,
          processName: _extractProcessName(cleanCommand),
          metadata: {'needsFullscreen': _needsFullscreen(cleanCommand)},
        );

      case ProcessType.oneshot:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: false,
          isPersistent: false,
          needsPTY: false,
        );

      case ProcessType.persistent:
        return ProcessInfo(
          type: type,
          command: originalCommand,
          requiresInput: false,
          isPersistent: true,
          needsPTY: false,
          processName: _extractProcessName(cleanCommand),
        );
    }
  }

  /// Extract process name from command
  String _extractProcessName(String command) {
    final parts = command.split(' ');
    if (parts.isEmpty) return 'unknown';
    
    final firstPart = parts.first;
    
    // Handle complex commands like "npm run dev"
    if (firstPart == 'npm' && parts.length >= 3 && parts[1] == 'run') {
      return 'npm-${parts[2]}';
    }
    
    // Handle "python manage.py runserver"
    if (firstPart == 'python' && parts.length >= 2 && parts[1].endsWith('.py')) {
      return 'python-${parts[1].replaceAll('.py', '')}';
    }
    
    return firstPart;
  }

  /// Check if command needs fullscreen modal
  bool _needsFullscreen(String command) {
    final fullscreenCommands = [
      'vi', 'vim', 'nvim', 'emacs', 'nano',
      'top', 'htop', 'btop',
      'less', 'more', 'man',
      'tmux', 'screen'
    ];
    
    return fullscreenCommands.any((cmd) => command.startsWith(cmd));
  }

  /// Check if command is a long-running process
  bool isLongRunningProcess(String command) {
    final info = detectProcessType(command);
    return info.isPersistent;
  }

  /// Check if command requires user interaction
  bool requiresUserInteraction(String command) {
    final info = detectProcessType(command);
    return info.requiresInput;
  }

  /// Check if command should trigger fullscreen modal
  bool shouldTriggerFullscreen(String command) {
    final info = detectProcessType(command);
    return info.metadata['needsFullscreen'] == true;
  }

  /// Get all persistent process patterns for debugging
  Map<ProcessType, List<String>> getPatternSummary() {
    return _patterns.map((key, value) => 
        MapEntry(key, value.map((pattern) => pattern.pattern).toList()));
  }

  /// Clear detection cache
  void clearCache() {
    _commandCache.clear();
    debugPrint('PersistentProcessDetector: Cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final typeDistribution = <ProcessType, int>{};
    for (final info in _commandCache.values) {
      typeDistribution[info.type] = (typeDistribution[info.type] ?? 0) + 1;
    }

    return {
      'cacheSize': _commandCache.length,
      'typeDistribution': typeDistribution.map((k, v) => MapEntry(k.name, v)),
    };
  }
}