import 'package:flutter/foundation.dart';
import 'fullscreen_command_detector.dart';

/// Service to track running terminal applications and their context
/// Used to determine appropriate keyboard handling behavior
class TerminalApplicationTracker {
  static TerminalApplicationTracker? _instance;
  static TerminalApplicationTracker get instance => _instance ??= TerminalApplicationTracker._();
  
  TerminalApplicationTracker._();

  String? _currentCommand;
  bool _isApplicationRunning = false;
  
  /// Commands that specifically require ESC key to be sent to terminal
  static const Set<String> _escKeyApplications = {
    'vi', 'vim', 'nvim', 'neovim', 'emacs', 'nano', 'pico', 'micro',
    'less', 'more', 'most', 'man',
  };

  /// Update the current running command
  void updateCurrentCommand(String? command) {
    _currentCommand = command?.trim();
    _updateApplicationRunningState();
    
    if (kDebugMode) {
      debugPrint('TerminalApplicationTracker: Command updated to: $_currentCommand (isAppRunning: $_isApplicationRunning)');
    }
  }

  /// Clear the current command (when command exits)
  void clearCurrentCommand() {
    _currentCommand = null;
    _isApplicationRunning = false;
    
    if (kDebugMode) {
      debugPrint('TerminalApplicationTracker: Command cleared');
    }
  }

  /// Check if a terminal application is currently running that needs ESC key
  bool get isTerminalApplicationRunning => _isApplicationRunning;

  /// Get the current running command
  String? get currentCommand => _currentCommand;

  /// Update the application running state based on current command
  void _updateApplicationRunningState() {
    if (_currentCommand == null || _currentCommand!.isEmpty) {
      _isApplicationRunning = false;
      return;
    }

    final executable = _currentCommand!.split(' ').first.toLowerCase();
    
    // Check if it's an application that needs ESC key
    _isApplicationRunning = _escKeyApplications.contains(executable);
    
    // Also check if it's a fullscreen command that would need ESC
    if (!_isApplicationRunning) {
      final detector = FullscreenCommandDetector.instance;
      _isApplicationRunning = detector.shouldTriggerFullscreen(_currentCommand!);
    }
  }

  /// Check if a specific command would require ESC key handling
  bool wouldRequireEscKey(String command) {
    final executable = command.trim().split(' ').first.toLowerCase();
    return _escKeyApplications.contains(executable) || 
           FullscreenCommandDetector.instance.shouldTriggerFullscreen(command);
  }

  /// Get detailed information about the current state
  Map<String, dynamic> getState() {
    return {
      'currentCommand': _currentCommand,
      'isApplicationRunning': _isApplicationRunning,
      'executable': _currentCommand?.split(' ').first,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Force update the application running state (for testing or edge cases)
  void setApplicationRunning(bool isRunning) {
    _isApplicationRunning = isRunning;
    
    if (kDebugMode) {
      debugPrint('TerminalApplicationTracker: Application running state forced to: $isRunning');
    }
  }
}