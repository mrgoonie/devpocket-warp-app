import 'package:dartssh2/dartssh2.dart';

/// Represents a fullscreen modal command session
class ModalSession {
  final String id;
  final String command;
  final DateTime startTime;
  final SSHClient? sshClient;
  final Map<String, String> environment;
  
  DateTime? endTime;
  int? exitCode;
  String? error;
  
  ModalSession({
    required this.id,
    required this.command,
    required this.startTime,
    this.sshClient,
    this.environment = const {},
  });

  /// Calculate session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Check if session is active
  bool get isActive => endTime == null;

  /// Check if session was successful
  bool get wasSuccessful => exitCode == 0 && error == null;

  /// Check if session uses SSH
  bool get isSSH => sshClient != null;

  /// Get formatted duration string
  String get formattedDuration {
    final dur = duration;
    if (dur.inHours > 0) {
      return '${dur.inHours}h ${dur.inMinutes % 60}m ${dur.inSeconds % 60}s';
    } else if (dur.inMinutes > 0) {
      return '${dur.inMinutes}m ${dur.inSeconds % 60}s';
    } else {
      return '${dur.inSeconds}s';
    }
  }

  /// Complete the session
  void complete({int? exitCode, String? error}) {
    endTime = DateTime.now();
    this.exitCode = exitCode;
    this.error = error;
  }

  /// Convert to JSON for logging/debugging
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': command,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration.inSeconds,
      'exitCode': exitCode,
      'error': error,
      'isSSH': isSSH,
      'environment': environment,
    };
  }

  @override
  String toString() {
    return 'ModalSession{id: $id, command: $command, duration: $formattedDuration, exitCode: $exitCode}';
  }
}

/// Modal session state management
class ModalSessionState {
  final ModalSession? currentSession;
  final List<ModalSession> recentSessions;
  final bool isLoading;
  final String? error;

  const ModalSessionState({
    this.currentSession,
    this.recentSessions = const [],
    this.isLoading = false,
    this.error,
  });

  bool get hasActiveSession => currentSession?.isActive == true;

  ModalSessionState copyWith({
    ModalSession? currentSession,
    List<ModalSession>? recentSessions,
    bool? isLoading,
    String? error,
  }) {
    return ModalSessionState(
      currentSession: currentSession ?? this.currentSession,
      recentSessions: recentSessions ?? this.recentSessions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'ModalSessionState{hasActiveSession: $hasActiveSession, recentSessions: ${recentSessions.length}, isLoading: $isLoading, error: $error}';
  }
}

/// Session events for state management
abstract class ModalSessionEvent {}

class SessionStartEvent extends ModalSessionEvent {
  final String command;
  final SSHClient? sshClient;
  final Map<String, String>? environment;

  SessionStartEvent({
    required this.command,
    this.sshClient,
    this.environment,
  });
}

class SessionOutputEvent extends ModalSessionEvent {
  final String output;
  final DateTime timestamp;

  SessionOutputEvent({
    required this.output,
    required this.timestamp,
  });
}

class SessionErrorEvent extends ModalSessionEvent {
  final String error;
  final DateTime timestamp;

  SessionErrorEvent({
    required this.error,
    required this.timestamp,
  });
}

class SessionCompleteEvent extends ModalSessionEvent {
  final int exitCode;
  final DateTime timestamp;

  SessionCompleteEvent({
    required this.exitCode,
    required this.timestamp,
  });
}

class SessionTerminateEvent extends ModalSessionEvent {
  final String reason;
  final DateTime timestamp;

  SessionTerminateEvent({
    required this.reason,
    required this.timestamp,
  });
}

/// Statistics for modal sessions
class ModalSessionStats {
  final int totalSessions;
  final int successfulSessions;
  final int failedSessions;
  final int sshSessions;
  final int localSessions;
  final Duration averageDuration;
  final String mostUsedCommand;
  final DateTime? lastSessionTime;

  const ModalSessionStats({
    required this.totalSessions,
    required this.successfulSessions,
    required this.failedSessions,
    required this.sshSessions,
    required this.localSessions,
    required this.averageDuration,
    required this.mostUsedCommand,
    this.lastSessionTime,
  });

  double get successRate => 
      totalSessions > 0 ? successfulSessions / totalSessions : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'successfulSessions': successfulSessions,
      'failedSessions': failedSessions,
      'sshSessions': sshSessions,
      'localSessions': localSessions,
      'averageDuration': averageDuration.inSeconds,
      'successRate': successRate,
      'mostUsedCommand': mostUsedCommand,
      'lastSessionTime': lastSessionTime?.toIso8601String(),
    };
  }
}

/// Utility functions for modal sessions
class ModalSessionUtils {
  /// Generate session ID
  static String generateSessionId() {
    return 'modal_${DateTime.now().millisecondsSinceEpoch}_${_randomString(4)}';
  }

  /// Calculate statistics from session list
  static ModalSessionStats calculateStats(List<ModalSession> sessions) {
    if (sessions.isEmpty) {
      return const ModalSessionStats(
        totalSessions: 0,
        successfulSessions: 0,
        failedSessions: 0,
        sshSessions: 0,
        localSessions: 0,
        averageDuration: Duration.zero,
        mostUsedCommand: '',
      );
    }

    final successful = sessions.where((s) => s.wasSuccessful).length;
    final failed = sessions.length - successful;
    final ssh = sessions.where((s) => s.isSSH).length;
    final local = sessions.length - ssh;

    final totalDuration = sessions.fold<Duration>(
      Duration.zero,
      (sum, session) => sum + session.duration,
    );
    final averageDuration = totalDuration ~/ sessions.length;

    // Find most used command
    final commandCounts = <String, int>{};
    for (final session in sessions) {
      final command = session.command.split(' ').first;
      commandCounts[command] = (commandCounts[command] ?? 0) + 1;
    }
    
    final mostUsedCommand = commandCounts.isEmpty
        ? ''
        : commandCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    final lastSessionTime = sessions.isNotEmpty
        ? sessions.map((s) => s.startTime).reduce((a, b) => a.isAfter(b) ? a : b)
        : null;

    return ModalSessionStats(
      totalSessions: sessions.length,
      successfulSessions: successful,
      failedSessions: failed,
      sshSessions: ssh,
      localSessions: local,
      averageDuration: averageDuration,
      mostUsedCommand: mostUsedCommand,
      lastSessionTime: lastSessionTime,
    );
  }

  /// Generate random string for ID
  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (i) => chars[(random + i) % chars.length]).join();
  }

  /// Format command for display
  static String formatCommandForDisplay(String command, {int maxLength = 50}) {
    if (command.length <= maxLength) return command;
    return '${command.substring(0, maxLength - 3)}...';
  }

  /// Extract command name from full command
  static String extractCommandName(String command) {
    return command.split(' ').first;
  }

  /// Check if command is likely to be long-running
  static bool isLongRunningCommand(String command) {
    final longRunningCommands = {
      'vi', 'vim', 'nvim', 'emacs', 'nano',
      'top', 'htop', 'btop', 'atop',
      'less', 'more', 'man',
      'tmux', 'screen',
    };
    
    final commandName = extractCommandName(command);
    return longRunningCommands.contains(commandName);
  }
}