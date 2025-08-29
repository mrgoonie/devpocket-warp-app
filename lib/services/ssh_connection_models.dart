import 'package:dartssh2/dartssh2.dart';
import 'dart:async';
import 'dart:io';

import '../models/ssh_profile_models.dart';

/// SSH Connection status
enum SshConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  authenticating,
}

/// SSH connection event types
enum SshConnectionEventType {
  statusChanged,
  dataReceived,
  dataSent,
  error,
  closed,
}

/// SSH connection event
class SshConnectionEvent {
  final SshConnectionEventType type;
  final String? data;
  final String? error;
  final SshConnectionStatus? status;
  final DateTime timestamp;

  const SshConnectionEvent({
    required this.type,
    this.data,
    this.error,
    this.status,
    required this.timestamp,
  });
}

/// Internal connection session with enhanced buffer management
class ConnectionSession {
  final String id;
  final SshProfile profile;
  final SSHClient client;
  final SSHSession shell;
  SshConnectionStatus status;
  
  // Buffer management for terminal sessions
  final StringBuffer outputBuffer = StringBuffer();
  final StringBuffer commandBuffer = StringBuffer();
  final StringBuffer welcomeBuffer = StringBuffer();
  
  // Welcome message handling
  bool welcomeMessageShown = false;
  Timer? welcomeTimeout;
  
  // Current command tracking
  String? currentCommand;
  DateTime? commandStartTime;
  
  // Connection metrics
  final DateTime connectedAt;
  DateTime lastActivityAt;
  int bytesReceived = 0;
  int bytesSent = 0;
  int commandCount = 0;

  ConnectionSession({
    required this.id,
    required this.profile,
    required this.client,
    required this.shell,
    required this.status,
  }) : connectedAt = DateTime.now(),
       lastActivityAt = DateTime.now();
  
  void updateActivity() {
    lastActivityAt = DateTime.now();
  }
  
  void addBytesReceived(int bytes) {
    bytesReceived += bytes;
    updateActivity();
  }
  
  void addBytesSent(int bytes) {
    bytesSent += bytes;
    updateActivity();
  }
  
  void clearCommandOutput() {
    commandBuffer.clear();
    updateActivity();
  }
  
  void clearAllOutput() {
    outputBuffer.clear();
    commandBuffer.clear();
    welcomeBuffer.clear();
    updateActivity();
  }
  
  void markWelcomeShown() {
    welcomeMessageShown = true;
    welcomeTimeout?.cancel();
    welcomeTimeout = null;
    updateActivity();
  }
  
  void setCurrentCommand(String command) {
    currentCommand = command;
    commandStartTime = DateTime.now();
    commandCount++;
    clearCommandOutput();
    updateActivity();
  }
  
  /// Get connection statistics
  Map<String, dynamic> getStats() {
    final uptime = DateTime.now().difference(connectedAt);
    
    return {
      'sessionId': id,
      'profileName': profile.name,
      'connectionString': profile.connectionString,
      'uptime': uptime.inSeconds,
      'bytesReceived': bytesReceived,
      'bytesSent': bytesSent,
      'commandCount': commandCount,
      'lastActivity': lastActivityAt.toIso8601String(),
      'currentCommand': currentCommand,
      'status': status.name,
      'welcomeShown': welcomeMessageShown,
    };
  }
  
  /// Dispose connection resources
  void dispose() {
    welcomeTimeout?.cancel();
    try {
      shell.close();
      client.close();
    } catch (e) {
      // Ignore disposal errors
    }
  }
}