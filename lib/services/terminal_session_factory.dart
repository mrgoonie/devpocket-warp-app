import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'terminal_session_models.dart';
import 'ssh_connection_manager.dart';
import 'websocket_manager.dart';
import 'terminal_websocket_service.dart';

/// Factory for creating different types of terminal sessions
class TerminalSessionFactory {
  final SshConnectionManager _sshManager;
  final WebSocketManager _wsManager;
  final TerminalWebSocketService _terminalWsService;
  final Function(TerminalOutput) _outputEmitter;

  TerminalSessionFactory({
    required SshConnectionManager sshManager,
    required WebSocketManager wsManager,
    required TerminalWebSocketService terminalWsService,
    required Function(TerminalOutput) outputEmitter,
  }) : _sshManager = sshManager,
       _wsManager = wsManager,
       _terminalWsService = terminalWsService,
       _outputEmitter = outputEmitter;

  /// Create a new SSH terminal session
  Future<SessionInstance> createSshSession(SshProfile profile) async {
    final sessionId = profile.id;
    
    debugPrint('Creating SSH terminal session: ${profile.name}');
    
    try {
      // Create terminal session
      final session = SessionInstance(
        id: sessionId,
        type: TerminalSessionType.ssh,
        state: TerminalSessionState.starting,
        profile: profile,
      );
      
      _outputEmitter(TerminalOutput(
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
          _outputEmitter(TerminalOutput(
            data: message.data.toString(),
            type: TerminalOutputType.stdout,
            timestamp: message.timestamp,
          ));
        });
        
        session.state = TerminalSessionState.running;
        
        _outputEmitter(TerminalOutput(
          data: 'Connected to ${profile.connectionString} via WebSocket\n',
          type: TerminalOutputType.info,
          timestamp: DateTime.now(),
        ));
        
        return session;
        
      } catch (wsError) {
        debugPrint('WebSocket connection failed, falling back to direct SSH: $wsError');
        
        // Fallback to direct SSH connection
        await _sshManager.connect(profile);
        
        session.state = TerminalSessionState.running;
        
        // Listen to SSH events - will be handled by event handler
        session.sshSubscription = _sshManager.events.listen((event) {
          // Event handling is delegated to the main handler
        });
        
        _outputEmitter(TerminalOutput(
          data: 'Connected to ${profile.connectionString} via direct SSH\n',
          type: TerminalOutputType.info,
          timestamp: DateTime.now(),
        ));
        
        return session;
      }
      
    } catch (e) {
      debugPrint('Failed to create SSH terminal session: $e');
      
      _outputEmitter(TerminalOutput(
        data: 'Connection failed: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('Failed to create SSH session: $e');
    }
  }
  
  /// Create a new WebSocket terminal session
  Future<SessionInstance> createWebSocketSession(String url) async {
    final sessionId = 'ws_${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Creating WebSocket terminal session: $url');
    
    try {
      final session = SessionInstance(
        id: sessionId,
        type: TerminalSessionType.websocket,
        state: TerminalSessionState.starting,
        websocketUrl: url,
      );
      
      _outputEmitter(TerminalOutput(
        data: 'Connecting to WebSocket terminal...\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      // Connect to WebSocket
      await _wsManager.connect();
      
      session.state = TerminalSessionState.running;
      
      // Listen to WebSocket events
      session.wsSubscription = _wsManager.messageStream.listen((message) {
        _outputEmitter(TerminalOutput(
          data: message.data.toString(),
          type: TerminalOutputType.stdout,
          timestamp: DateTime.now(),
        ));
      });
      
      _outputEmitter(TerminalOutput(
        data: 'WebSocket terminal connected\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      return session;
      
    } catch (e) {
      debugPrint('Failed to create WebSocket terminal session: $e');
      
      _outputEmitter(TerminalOutput(
        data: 'WebSocket connection failed: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('Failed to create WebSocket session: $e');
    }
  }
  
  /// Create a local terminal session (future implementation)
  Future<SessionInstance> createLocalSession() async {
    final sessionId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    
    debugPrint('Creating local terminal session');
    
    try {
      final session = SessionInstance(
        id: sessionId,
        type: TerminalSessionType.local,
        state: TerminalSessionState.running,
      );
      
      _outputEmitter(TerminalOutput(
        data: 'Local terminal session started\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      _outputEmitter(TerminalOutput(
        data: 'Welcome to DevPocket Terminal\n',
        type: TerminalOutputType.info,
        timestamp: DateTime.now(),
      ));
      
      return session;
      
    } catch (e) {
      debugPrint('Failed to create local terminal session: $e');
      throw Exception('Failed to create local session: $e');
    }
  }
}