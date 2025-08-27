import 'package:flutter/foundation.dart';
import 'persistent_process_detector.dart';

/// Types of command handling modes
enum CommandHandlingMode {
  oneshot,       // Regular commands handled in blocks
  blockInteractive,  // Interactive commands handled within blocks (Phase 3.5)
  fullscreenModal,   // Interactive commands requiring fullscreen modal (Phase 3)
}

/// Enhanced command detector that differentiates between block-interactive and fullscreen-modal commands
class FullscreenCommandDetector {
  static FullscreenCommandDetector? _instance;
  static FullscreenCommandDetector get instance => _instance ??= FullscreenCommandDetector._();
  
  FullscreenCommandDetector._();

  /// Commands that require fullscreen modal presentation
  static const Set<String> _fullscreenCommands = {
    // Text Editors
    'vi', 'vim', 'nvim', 'neovim', 'emacs', 'nano', 'pico', 'micro',
    
    // System Monitors  
    'top', 'htop', 'btop', 'atop', 'iotop', 'iftop', 'nethogs',
    
    // Pagers
    'less', 'more', 'most',
    
    // Terminal Multiplexers
    'tmux', 'screen', 'byobu',
    
    // File Managers
    'mc', 'ranger', 'nnn', 'lf', 'vifm',
    
    // Database Clients (fullscreen mode)
    'mycli', 'pgcli',
    
    // Mail clients
    'mutt', 'alpine',
    
    // IRC clients
    'irssi', 'weechat',
  };

  /// Commands that should stay in block-interactive mode (from Phase 3.5)
  static const Set<String> _blockInteractiveCommands = {
    // REPLs
    'python', 'python3', 'node', 'nodejs', 'irb', 'ruby',
    'julia', 'r', 'scala', 'clojure', 'clj', 'ghci', 'runghc',
    'erl', 'iex', 'psql', 'mysql', 'sqlite3', 'redis-cli',
    
    // AI assistants
    'claude', 'ai',
    
    // Development servers (handled in blocks with output streaming)
    'npm', 'pnpm', 'yarn', 'bun', 'next', 'vite', 'parcel',
    'webpack-dev-server', 'rails', 'bundle', 'django-admin',
    'flask', 'fastapi', 'uvicorn', 'gatsby', 'nuxt', 'hugo',
    'jekyll', 'flutter', 'expo', 'react-native',
    
    // Watchers and monitoring (continuous output in blocks)
    'watch', 'nodemon', 'tail', 'docker', 'kubectl', 'journalctl',
    
    // Build tools
    'make', 'gradle', 'gradlew', 'cargo', 'webpack', 'tsc',
    'typescript', 'sass', 'less', 'rollup', 'esbuild',
  };

  /// Pattern-based detection for complex commands
  static final List<RegExp> _fullscreenPatterns = [
    // Git commands that use pagers
    RegExp(r'^git\s+(log|diff|show|blame)(\s|$)'),
    
    // Man pages
    RegExp(r'^man\s+'),
    
    // SSH connections
    RegExp(r'^ssh\s+'),
    
    // FTP/SFTP
    RegExp(r'^(ftp|sftp)\s+'),
    
    // Editors with file arguments
    RegExp(r'^(vi|vim|nvim|nano|emacs)\s+'),
    
    // System monitors with arguments
    RegExp(r'^(top|htop|btop)\s+'),
    
    // Pagers with file arguments
    RegExp(r'^(less|more)\s+'),
  ];

  /// Block-interactive patterns (from Phase 3.5)
  static final List<RegExp> _blockInteractivePatterns = [
    // Development servers
    RegExp(r'^(npm|pnpm|yarn|bun)\s+run\s+(dev|start|serve)'),
    RegExp(r'^(npm|pnpm|yarn|bun)\s+(dev|start|serve)'),
    
    // Python/Node without arguments (REPL mode)
    RegExp(r'^(python|python3|node|nodejs)$'),
    
    // Watchers
    RegExp(r'^(watch)\s+'),
    RegExp(r'^(tail)\s+(-f|--follow)'),
    RegExp(r'--watch(\s|$)'),
    
    // Build tools with watch
    RegExp(r'^(make)\s+watch'),
    RegExp(r'^(webpack)\s+--watch'),
    RegExp(r'^(tsc|typescript)\s+--watch'),
  ];

  /// Determine the appropriate command handling mode
  CommandHandlingMode detectHandlingMode(String command) {
    final cleanCommand = command.trim().toLowerCase();
    final executable = cleanCommand.split(' ').first;
    
    // First check for direct fullscreen command matches
    if (_fullscreenCommands.contains(executable)) {
      return CommandHandlingMode.fullscreenModal;
    }
    
    // Check fullscreen patterns
    for (final pattern in _fullscreenPatterns) {
      if (pattern.hasMatch(cleanCommand)) {
        return CommandHandlingMode.fullscreenModal;
      }
    }
    
    // Check for block-interactive commands
    if (_blockInteractiveCommands.contains(executable)) {
      return CommandHandlingMode.blockInteractive;
    }
    
    // Check block-interactive patterns
    for (final pattern in _blockInteractivePatterns) {
      if (pattern.hasMatch(cleanCommand)) {
        return CommandHandlingMode.blockInteractive;
      }
    }
    
    // Use existing persistent process detector for additional classification
    final processInfo = PersistentProcessDetector.instance.detectProcessType(command);
    
    // Commands that need fullscreen based on process type
    if (processInfo.type == ProcessType.interactive && 
        processInfo.metadata['needsFullscreen'] == true) {
      return CommandHandlingMode.fullscreenModal;
    }
    
    // Commands that should stay in blocks (REPLs, dev servers, watchers)
    if (processInfo.type == ProcessType.repl ||
        processInfo.type == ProcessType.devServer ||
        processInfo.type == ProcessType.watcher ||
        processInfo.type == ProcessType.buildTool) {
      return CommandHandlingMode.blockInteractive;
    }
    
    // Default to oneshot for regular commands
    return CommandHandlingMode.oneshot;
  }

  /// Check if command should trigger fullscreen modal
  bool shouldTriggerFullscreen(String command) {
    return detectHandlingMode(command) == CommandHandlingMode.fullscreenModal;
  }

  /// Check if command should stay in block-interactive mode
  bool shouldUseBlockInteractive(String command) {
    return detectHandlingMode(command) == CommandHandlingMode.blockInteractive;
  }

  /// Check if command is a regular oneshot command
  bool isOneshotCommand(String command) {
    return detectHandlingMode(command) == CommandHandlingMode.oneshot;
  }

  /// Get command classification details for debugging
  Map<String, dynamic> getCommandDetails(String command) {
    final mode = detectHandlingMode(command);
    final processInfo = PersistentProcessDetector.instance.detectProcessType(command);
    
    return {
      'command': command,
      'handlingMode': mode.name,
      'processType': processInfo.type.name,
      'requiresInput': processInfo.requiresInput,
      'isPersistent': processInfo.isPersistent,
      'needsPTY': processInfo.needsPTY,
      'needsFullscreen': processInfo.metadata['needsFullscreen'] ?? false,
      'metadata': processInfo.metadata,
    };
  }

  /// Get all command patterns for debugging
  Map<String, dynamic> getPatternSummary() {
    return {
      'fullscreenCommands': _fullscreenCommands.toList(),
      'blockInteractiveCommands': _blockInteractiveCommands.toList(),
      'fullscreenPatterns': _fullscreenPatterns.map((p) => p.pattern).toList(),
      'blockInteractivePatterns': _blockInteractivePatterns.map((p) => p.pattern).toList(),
    };
  }

  /// Clear any internal caches
  void clearCache() {
    PersistentProcessDetector.instance.clearCache();
    debugPrint('FullscreenCommandDetector: Cache cleared');
  }
}