import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'ssh_connection_manager.dart';
import 'websocket_manager.dart';
import 'terminal_websocket_service.dart';

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

/// Terminal session handler for managing terminal sessions with enhanced block support
class TerminalSessionHandler {
  static TerminalSessionHandler? _instance;
  static TerminalSessionHandler get instance => _instance ??= TerminalSessionHandler._();

  TerminalSessionHandler._();

  final Map<String, _TerminalSession> _sessions = {};
  final StreamController<TerminalOutput> _outputController = StreamController.broadcast();
  final SshConnectionManager _sshManager = SshConnectionManager.instance;
  final WebSocketManager _wsManager = WebSocketManager.instance;
  final TerminalWebSocketService _terminalWsService = TerminalWebSocketService.instance;
  
  // Enhanced session tracking for block-based UI
  final Map<String, List<Map<String, dynamic>>> _sessionCommandHistory = {};
  final Map<String, Map<String, dynamic>> _sessionMetadata = {};

  /// Stream of terminal output
  Stream<TerminalOutput> get output => _outputController.stream;

  /// Create a new SSH terminal session
  Future<String> createSshSession(SshProfile profile) async {
    final sessionId = profile.id;
    
    debugPrint('Creating SSH terminal session: ${profile.name}');
    
    try {
      // Create terminal session
      final session = _TerminalSession(
        id: sessionId,
        type: TerminalSessionType.ssh,
        state: TerminalSessionState.starting,
        profile: profile,
      );
      
      _sessions[sessionId] = session;
      
      _emitOutput(TerminalOutput(
        data: 'Connecting to ${profile.connectionString}...\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      // Try WebSocket connection first (if backend supports it)
      try {
        await _terminalWsService.connect();
        final wsSessionId = await _terminalWsService.createTerminalSession(profile);
        
        // Listen to WebSocket terminal output
        session.wsSubscription = _terminalWsService.getTerminalOutput(sessionId: wsSessionId).listen((message) {
          _emitOutput(TerminalOutput(
            data: message.data.toString(),
            type: TerminalOutputType.stdout,
            timestamp: message.timestamp,
          ));
        });
        
        session.state = TerminalSessionState.running;
        
        _emitOutput(TerminalOutput(
          data: 'Connected to ${profile.connectionString} via WebSocket\n',
          type: TerminalOutputType.info,
          timestamp: DateTime.now(),
        ));
        
        return sessionId;
        
      } catch (wsError) {
        debugPrint('WebSocket connection failed, falling back to direct SSH: $wsError');
        
        // Fallback to direct SSH connection
        await _sshManager.connect(profile);
        
        session.state = TerminalSessionState.running;
        
        // Listen to SSH events
        session.sshSubscription = _sshManager.events.listen((event) {
          _handleSshEvent(sessionId, event);
        });
        
        _emitOutput(TerminalOutput(
          data: 'Connected to ${profile.connectionString} via direct SSH\n',
          type: TerminalOutputType.info,
          timestamp: DateTime.now(),
        ));
        
        return sessionId;
      }
      
    } catch (e) {
      debugPrint('Failed to create SSH terminal session: $e');
      
      final session = _sessions[sessionId];
      if (session != null) {
        session.state = TerminalSessionState.error;
      }
      
      _emitOutput(TerminalOutput(
        data: 'Connection failed: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('Failed to create SSH session: $e');
    }
  }
  
  /// Create a new WebSocket terminal session
  Future<String> createWebSocketSession(String url) async {
    final sessionId = 'ws_${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Creating WebSocket terminal session: $url');
    
    try {
      final session = _TerminalSession(
        id: sessionId,
        type: TerminalSessionType.websocket,
        state: TerminalSessionState.starting,
        websocketUrl: url,
      );
      
      _sessions[sessionId] = session;
      
      _emitOutput(TerminalOutput(
        data: 'Connecting to WebSocket terminal...\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      // Connect to WebSocket
      await _wsManager.connect();
      
      session.state = TerminalSessionState.running;
      
      // Listen to WebSocket events
      session.wsSubscription = _wsManager.messageStream.listen((message) {
        _emitOutput(TerminalOutput(
          data: message.data.toString(),
          type: TerminalOutputType.stdout,
          timestamp: DateTime.now(),
        ));
      });
      
      _emitOutput(TerminalOutput(
        data: 'WebSocket terminal connected\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create WebSocket terminal session: $e');
      
      final session = _sessions[sessionId];
      if (session != null) {
        session.state = TerminalSessionState.error;
      }
      
      _emitOutput(TerminalOutput(
        data: 'WebSocket connection failed: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('Failed to create WebSocket session: $e');
    }
  }
  
  /// Create a local terminal session (future implementation)
  Future<String> createLocalSession() async {
    final sessionId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Creating local terminal session');
    
    try {
      final session = _TerminalSession(
        id: sessionId,
        type: TerminalSessionType.local,
        state: TerminalSessionState.running,
      );
      
      _sessions[sessionId] = session;
      
      _emitOutput(TerminalOutput(
        data: 'Local terminal session started\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      _emitOutput(TerminalOutput(
        data: 'Welcome to DevPocket Terminal\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create local terminal session: $e');
      throw Exception('Failed to create local session: $e');
    }
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
    
    try {
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
      
      switch (session.type) {
        case TerminalSessionType.ssh:
          // Try WebSocket first, fallback to direct SSH
          if (_terminalWsService.isConnected && _terminalWsService.getActiveSessions().contains(sessionId)) {
            await _terminalWsService.sendTerminalControl(command, sessionId: sessionId);
          } else {
            await _sshManager.sendCommand(sessionId, command);
          }
          break;
          
        case TerminalSessionType.websocket:
          if (session.websocketUrl != null) {
            await _terminalWsService.sendTerminalData(command, sessionId: sessionId);
          }
          break;
          
        case TerminalSessionType.local:
          // Local command execution would go here
          _emitOutput(TerminalOutput(
            data: 'Local command execution not implemented yet\n',
            type: TerminalOutputType.info,
            timestamp: DateTime.now(),
          ));
          break;
      }
      
    } catch (e) {
      debugPrint('Failed to send command: $e');
      _emitOutput(TerminalOutput(
        data: 'Failed to send command: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      throw Exception('Failed to send command: $e');
    }
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
    
    try {
      switch (session.type) {
        case TerminalSessionType.ssh:
          // Try WebSocket first, fallback to direct SSH
          if (_terminalWsService.isConnected && _terminalWsService.getActiveSessions().contains(sessionId)) {
            await _terminalWsService.sendTerminalData(data, sessionId: sessionId);
          } else {
            await _sshManager.sendData(sessionId, data);
          }
          break;
          
        case TerminalSessionType.websocket:
          if (session.websocketUrl != null) {
            await _terminalWsService.sendTerminalData(data, sessionId: sessionId);
          }
          break;
          
        case TerminalSessionType.local:
          // Local data send would go here
          break;
      }
      
    } catch (e) {
      debugPrint('Failed to send data: $e');
      throw Exception('Failed to send data: $e');
    }
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
    
    return {
      'id': session.id,
      'type': session.type.name,
      'state': session.state.name,
      'createdAt': session.createdAt.toIso8601String(),
      'lastActivityAt': session.lastActivityAt.toIso8601String(),
      'commandCount': session.commandCount,
      'recentCommands': session.recentCommands,
      'currentWorkingDirectory': session.currentWorkingDirectory,
      'sessionStats': session.sessionStats,
      'profile': session.profile?.toJson(),
      'websocketUrl': session.websocketUrl,
    };
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
  
  /// Handle SSH connection events
  void _handleSshEvent(String sessionId, SshConnectionEvent event) {
    switch (event.type) {
      case SshConnectionEventType.dataReceived:
        if (event.data != null) {
          _emitOutput(TerminalOutput(
            data: event.data!,
            type: TerminalOutputType.stdout,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      case SshConnectionEventType.error:
        if (event.error != null) {
          _emitOutput(TerminalOutput(
            data: 'SSH Error: ${event.error!}\n',
            type: TerminalOutputType.error,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      case SshConnectionEventType.closed:
        _emitOutput(TerminalOutput(
          data: 'SSH connection closed\n',
          type: TerminalOutputType.info,
          timestamp: event.timestamp,
        ));
        
        final session = _sessions[sessionId];
        if (session != null) {
          session.state = TerminalSessionState.stopped;
        }
        break;
        
      case SshConnectionEventType.statusChanged:
        if (event.status != null) {
          String statusMessage;
          switch (event.status!) {
            case SshConnectionStatus.connecting:
              statusMessage = 'Connecting...';
              break;
            case SshConnectionStatus.authenticating:
              statusMessage = 'Authenticating...';
              break;
            case SshConnectionStatus.connected:
              statusMessage = 'Connected';
              break;
            case SshConnectionStatus.reconnecting:
              statusMessage = 'Reconnecting...';
              break;
            case SshConnectionStatus.failed:
              statusMessage = 'Connection failed';
              break;
            case SshConnectionStatus.disconnected:
              statusMessage = 'Disconnected';
              break;
          }
          
          _emitOutput(TerminalOutput(
            data: '$statusMessage\n',
            type: TerminalOutputType.info,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      default:
        break;
    }
  }
  
  /// Emit terminal output
  void _emitOutput(TerminalOutput output) {
    _outputController.add(output);
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
  
  /// Dispose resources
  void dispose() {
    stopAllSessions();
    _sessionCommandHistory.clear();
    _sessionMetadata.clear();
    _outputController.close();
  }
}

/// Internal terminal session with enhanced metadata tracking
class _TerminalSession {
  final String id;
  final TerminalSessionType type;
  TerminalSessionState state;
  final SshProfile? profile;
  final String? websocketUrl;
  final DateTime createdAt;
  
  StreamSubscription<SshConnectionEvent>? sshSubscription;
  StreamSubscription<TerminalMessage>? wsSubscription;
  
  // Enhanced session metadata
  int commandCount = 0;
  DateTime lastActivityAt;
  Map<String, dynamic> sessionStats = {};
  List<String> recentCommands = [];
  String? currentWorkingDirectory;

  _TerminalSession({
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
}