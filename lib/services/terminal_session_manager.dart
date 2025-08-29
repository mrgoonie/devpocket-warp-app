import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'terminal_session_models.dart';
import 'terminal_session_factory.dart';
import 'terminal_session_commands.dart';
import 'terminal_session_events.dart';
import 'ssh_connection_manager.dart';
import 'websocket_manager.dart';
import 'terminal_websocket_service.dart';

/// Core terminal session manager with enhanced tracking capabilities
class TerminalSessionManager {
  final Map<String, SessionInstance> _sessions = {};
  final StreamController<TerminalOutput> _outputController = StreamController.broadcast();
  
  // Service dependencies
  final SshConnectionManager _sshManager = SshConnectionManager.instance;
  final WebSocketManager _wsManager = WebSocketManager.instance;
  final TerminalWebSocketService _terminalWsService = TerminalWebSocketService.instance;
  
  // Components
  late final TerminalSessionFactory _sessionFactory;
  late final TerminalSessionCommands _sessionCommands;
  late final TerminalSessionEvents _sessionEvents;
  
  // Enhanced session tracking for block-based UI
  final Map<String, List<Map<String, dynamic>>> _sessionCommandHistory = {};
  final Map<String, Map<String, dynamic>> _sessionMetadata = {};

  TerminalSessionManager() {
    _sessionFactory = TerminalSessionFactory(
      sshManager: _sshManager,
      wsManager: _wsManager,
      terminalWsService: _terminalWsService,
      outputEmitter: _emitOutput,
    );
    
    _sessionCommands = TerminalSessionCommands(
      sshManager: _sshManager,
      terminalWsService: _terminalWsService,
      outputEmitter: _emitOutput,
    );
    
    _sessionEvents = TerminalSessionEvents(
      outputEmitter: _emitOutput,
    );
  }

  /// Stream of terminal output
  Stream<TerminalOutput> get output => _outputController.stream;

  /// Create a new SSH terminal session
  Future<String> createSshSession(SshProfile profile) async {
    final session = await _sessionFactory.createSshSession(profile);
    _sessions[session.id] = session;
    
    // Set up SSH event handling if using direct SSH
    if (session.sshSubscription != null) {
      session.sshSubscription = _sshManager.events.listen((event) {
        _sessionEvents.handleSshEvent(session.id, event, session);
      });
    }
    
    return session.id;
  }

  /// Create a new WebSocket terminal session
  Future<String> createWebSocketSession(String url) async {
    final session = await _sessionFactory.createWebSocketSession(url);
    _sessions[session.id] = session;
    return session.id;
  }
  
  /// Create a local terminal session (future implementation)
  Future<String> createLocalSession() async {
    final session = await _sessionFactory.createLocalSession();
    _sessions[session.id] = session;
    return session.id;
  }

  /// Send command to terminal session with enhanced metadata tracking
  Future<void> sendCommand(String sessionId, String command) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Terminal session not found: $sessionId');
    }
    
    if (session.state != TerminalSessionState.running) {
      throw Exception('Terminal session not running: $sessionId');
    }
    
    // Track command in session history
    session.addCommand(command);
    
    // Add to session command history
    final commandRecord = {
      'command': command,
      'timestamp': DateTime.now().toIso8601String(),
      'sessionId': sessionId,
      'type': session.type.name,
    };
    
    _sessionCommandHistory.putIfAbsent(sessionId, () => []).add(commandRecord);
    
    _emitOutput(TerminalOutput(
      data: command,
      type: TerminalOutputType.command,
      timestamp: DateTime.now(),
    ));
    
    await _sessionCommands.sendCommand(session, command);
  }
  
  /// Send raw data to terminal session
  Future<void> sendData(String sessionId, String data) async {
    final session = _sessions[sessionId];
    if (session == null) {
      throw Exception('Terminal session not found: $sessionId');
    }
    
    if (session.state != TerminalSessionState.running) {
      throw Exception('Terminal session not running: $sessionId');
    }
    
    await _sessionCommands.sendData(session, data);
  }

  /// Stop terminal session
  Future<void> stopSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) return;
    
    debugPrint('Stopping terminal session: $sessionId');
    
    try {
      session.state = TerminalSessionState.stopping;
      
      // Cancel subscriptions
      await session.sshSubscription?.cancel();
      await session.wsSubscription?.cancel();
      
      // Disconnect based on session type
      switch (session.type) {
        case TerminalSessionType.ssh:
          await _sshManager.disconnect(sessionId);
          break;
          
        case TerminalSessionType.websocket:
          await _wsManager.disconnect();
          break;
          
        case TerminalSessionType.local:
          // Local session cleanup would go here
          break;
      }
      
      session.state = TerminalSessionState.stopped;
      _sessions.remove(sessionId);
      
      _emitOutput(TerminalOutput(
        data: 'Terminal session stopped\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error stopping terminal session: $e');
      session.state = TerminalSessionState.error;
    }
  }

  /// Get session state
  TerminalSessionState getSessionState(String sessionId) {
    return _sessions[sessionId]?.state ?? TerminalSessionState.stopped;
  }
  
  /// Check if session is running
  bool isSessionRunning(String sessionId) {
    return getSessionState(sessionId) == TerminalSessionState.running;
  }
  
  /// Get all active sessions
  List<String> getActiveSessions() {
    return _sessions.keys.toList();
  }

  /// Get session info with enhanced metadata
  Map<String, dynamic> getSessionInfo(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return {};
    
    return session.toJson();
  }
  
  /// Get command history for session
  List<Map<String, dynamic>> getSessionCommandHistory(String sessionId) {
    return _sessionCommandHistory[sessionId] ?? [];
  }
  
  /// Get all command history across sessions
  Map<String, List<Map<String, dynamic>>> getAllCommandHistory() {
    return Map.from(_sessionCommandHistory);
  }
  
  /// Get session metadata
  Map<String, dynamic> getSessionMetadata(String sessionId) {
    return _sessionMetadata[sessionId] ?? {};
  }
  
  /// Update session metadata
  void updateSessionMetadata(String sessionId, Map<String, dynamic> metadata) {
    _sessionMetadata[sessionId] = {..._sessionMetadata[sessionId] ?? {}, ...metadata};
    final session = _sessions[sessionId];
    if (session != null) {
      session.updateActivity();
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return {};
    
    final history = getSessionCommandHistory(sessionId);
    final uptime = DateTime.now().difference(session.createdAt);
    
    return {
      'sessionId': sessionId,
      'uptime': uptime.inSeconds,
      'commandCount': session.commandCount,
      'averageCommandsPerMinute': session.commandCount / (uptime.inMinutes > 0 ? uptime.inMinutes : 1),
      'lastActivity': session.lastActivityAt.toIso8601String(),
      'totalCommands': history.length,
      'sessionType': session.type.name,
      'isActive': session.state == TerminalSessionState.running,
    };
  }

  /// Stop all sessions
  Future<void> stopAllSessions() async {
    final sessionIds = _sessions.keys.toList();
    for (final sessionId in sessionIds) {
      await stopSession(sessionId);
    }
  }
  
  /// Clear session history
  void clearSessionHistory(String sessionId) {
    _sessionCommandHistory.remove(sessionId);
    _sessionMetadata.remove(sessionId);
    final session = _sessions[sessionId];
    if (session != null) {
      session.recentCommands.clear();
      session.commandCount = 0;
      session.sessionStats.clear();
    }
  }
  
  /// Export session data for backup or analysis
  Map<String, dynamic> exportSessionData(String sessionId) {
    return {
      'sessionInfo': getSessionInfo(sessionId),
      'commandHistory': getSessionCommandHistory(sessionId),
      'metadata': getSessionMetadata(sessionId),
      'stats': getSessionStats(sessionId),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Emit terminal output
  void _emitOutput(TerminalOutput output) {
    _outputController.add(output);
  }

  /// Dispose resources
  void dispose() {
    stopAllSessions();
    _sessionCommandHistory.clear();
    _sessionMetadata.clear();
    _outputController.close();
  }
}