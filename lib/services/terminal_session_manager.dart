import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'terminal_session_handler.dart';
import 'ssh_connection_manager.dart';

/// Terminal session manager for coordinating all terminal functionality
class TerminalSessionManager {
  static TerminalSessionManager? _instance;
  static TerminalSessionManager get instance => _instance ??= TerminalSessionManager._();

  TerminalSessionManager._();

  final TerminalSessionHandler _sessionHandler = TerminalSessionHandler.instance;
  final SshConnectionManager _connectionManager = SshConnectionManager.instance;
  
  final Map<String, String> _sessionToConnection = {}; // sessionId -> connectionId
  final StreamController<SessionEvent> _eventController = StreamController.broadcast();

  /// Stream of session events
  Stream<SessionEvent> get events => _eventController.stream;

  /// Create SSH terminal session
  Future<String> createSshSession(SshProfile profile) async {
    try {
      debugPrint('Creating SSH terminal session for: ${profile.name}');
      
      // Create terminal session
      final sessionId = await _sessionHandler.createSshSession(profile);
      
      // Map session to connection
      _sessionToConnection[sessionId] = profile.id;
      
      _emitEvent(SessionEvent(
        type: SessionEventType.created,
        sessionId: sessionId,
        profileId: profile.id,
        message: 'SSH terminal session created',
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create SSH terminal session: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        profileId: profile.id,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Create local terminal session
  Future<String> createLocalSession() async {
    try {
      debugPrint('Creating local terminal session');
      
      final sessionId = await _sessionHandler.createLocalSession();
      
      _emitEvent(SessionEvent(
        type: SessionEventType.created,
        sessionId: sessionId,
        message: 'Local terminal session created',
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create local terminal session: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Send command to session
  Future<void> sendCommand(String sessionId, String command) async {
    try {
      await _sessionHandler.sendCommand(sessionId, command);
      
      _emitEvent(SessionEvent(
        type: SessionEventType.commandSent,
        sessionId: sessionId,
        command: command,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to send command to session $sessionId: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        sessionId: sessionId,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Stop terminal session
  Future<void> stopSession(String sessionId) async {
    try {
      debugPrint('Stopping terminal session: $sessionId');
      
      await _sessionHandler.stopSession(sessionId);
      
      // Clean up mapping
      final connectionId = _sessionToConnection.remove(sessionId);
      
      _emitEvent(SessionEvent(
        type: SessionEventType.stopped,
        sessionId: sessionId,
        profileId: connectionId,
        message: 'Terminal session stopped',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to stop terminal session: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        sessionId: sessionId,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Get session state
  TerminalSessionState getSessionState(String sessionId) {
    return _sessionHandler.getSessionState(sessionId);
  }

  /// Check if session is running
  bool isSessionRunning(String sessionId) {
    return _sessionHandler.isSessionRunning(sessionId);
  }

  /// Get all active sessions
  List<String> getActiveSessions() {
    return _sessionHandler.getActiveSessions();
  }

  /// Get session information
  Map<String, dynamic> getSessionInfo(String sessionId) {
    final sessionInfo = _sessionHandler.getSessionInfo(sessionId);
    final connectionId = _sessionToConnection[sessionId];
    
    return {
      ...sessionInfo,
      'connectionId': connectionId,
      'connectionStatus': connectionId != null 
          ? _connectionManager.getStatus(connectionId).name
          : null,
    };
  }

  /// Reconnect session
  Future<void> reconnectSession(String sessionId) async {
    final connectionId = _sessionToConnection[sessionId];
    if (connectionId == null) {
      throw Exception('No connection found for session: $sessionId');
    }
    
    try {
      debugPrint('Reconnecting session: $sessionId');
      
      await _connectionManager.reconnect(connectionId);
      
      _emitEvent(SessionEvent(
        type: SessionEventType.reconnected,
        sessionId: sessionId,
        profileId: connectionId,
        message: 'Session reconnected',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to reconnect session: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        sessionId: sessionId,
        error: 'Reconnection failed: $e',
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    final activeSessions = getActiveSessions();
    final sshSessions = activeSessions.where((id) => 
        _sessionToConnection.containsKey(id)).length;
    final localSessions = activeSessions.length - sshSessions;
    
    return {
      'totalSessions': activeSessions.length,
      'sshSessions': sshSessions,
      'localSessions': localSessions,
      'activeConnections': _connectionManager.getActiveSessions().length,
      'lastActivity': DateTime.now().toIso8601String(),
    };
  }

  /// Cleanup all sessions
  Future<void> cleanup() async {
    debugPrint('Cleaning up all terminal sessions');
    
    try {
      await _sessionHandler.stopAllSessions();
      await _connectionManager.disconnectAll();
      
      _sessionToConnection.clear();
      
      _emitEvent(SessionEvent(
        type: SessionEventType.cleanup,
        message: 'All sessions cleaned up',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  /// Resume session from background
  Future<void> resumeSession(String sessionId) async {
    final connectionId = _sessionToConnection[sessionId];
    if (connectionId == null) return;
    
    try {
      // Check if connection is still alive
      final isConnected = _connectionManager.isConnected(connectionId);
      
      if (!isConnected) {
        // Attempt to reconnect
        await reconnectSession(sessionId);
      }
      
      _emitEvent(SessionEvent(
        type: SessionEventType.resumed,
        sessionId: sessionId,
        profileId: connectionId,
        message: 'Session resumed',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to resume session: $e');
      
      _emitEvent(SessionEvent(
        type: SessionEventType.error,
        sessionId: sessionId,
        error: 'Resume failed: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Emit session event
  void _emitEvent(SessionEvent event) {
    _eventController.add(event);
  }

  /// Dispose resources
  void dispose() {
    cleanup();
    _eventController.close();
  }
}

/// Session event types
enum SessionEventType {
  created,
  stopped,
  error,
  commandSent,
  reconnected,
  resumed,
  cleanup,
}

/// Session event model
class SessionEvent {
  final SessionEventType type;
  final String? sessionId;
  final String? profileId;
  final String? command;
  final String? message;
  final String? error;
  final DateTime timestamp;

  const SessionEvent({
    required this.type,
    this.sessionId,
    this.profileId,
    this.command,
    this.message,
    this.error,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'SessionEvent{type: $type, sessionId: $sessionId, message: $message}';
  }
}