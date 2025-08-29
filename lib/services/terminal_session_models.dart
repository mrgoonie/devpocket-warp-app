import 'dart:async';
import '../models/ssh_profile_models.dart';
import 'ssh_connection_manager.dart';

/// Terminal session types
enum TerminalSessionType {
  local,
  ssh,
  websocket,
}

/// Terminal session state
enum TerminalSessionState {
  idle,
  starting,
  running,
  stopping,
  stopped,
  error,
}

/// Terminal output event
class TerminalOutput {
  final String data;
  final TerminalOutputType type;
  final DateTime timestamp;

  const TerminalOutput({
    required this.data,
    required this.type,
    required this.timestamp,
  });
}

/// Terminal output types
enum TerminalOutputType {
  stdout,
  stderr,
  info,
  error,
  command,
}

/// Internal terminal session with enhanced metadata tracking
class SessionInstance {
  final String id;
  final TerminalSessionType type;
  TerminalSessionState state;
  final SshProfile? profile;
  final String? websocketUrl;
  final DateTime createdAt;
  
  StreamSubscription<SshConnectionEvent>? sshSubscription;
  StreamSubscription? wsSubscription;
  
  // Enhanced session metadata
  int commandCount = 0;
  DateTime lastActivityAt;
  Map<String, dynamic> sessionStats = {};
  List<String> recentCommands = [];
  String? currentWorkingDirectory;

  SessionInstance({
    required this.id,
    required this.type,
    required this.state,
    this.profile,
    this.websocketUrl,
  }) : createdAt = DateTime.now(),
       lastActivityAt = DateTime.now();
       
  void updateActivity() {
    lastActivityAt = DateTime.now();
  }
  
  void addCommand(String command) {
    commandCount++;
    recentCommands.add(command);
    if (recentCommands.length > 50) {
      recentCommands.removeAt(0);
    }
    updateActivity();
  }
  
  /// Convert session to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'state': state.name,
      'createdAt': createdAt.toIso8601String(),
      'lastActivityAt': lastActivityAt.toIso8601String(),
      'commandCount': commandCount,
      'recentCommands': recentCommands,
      'currentWorkingDirectory': currentWorkingDirectory,
      'sessionStats': sessionStats,
      'profile': profile?.toJson(),
      'websocketUrl': websocketUrl,
    };
  }
}