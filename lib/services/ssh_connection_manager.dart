import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'ssh_connection_models.dart';
import 'ssh_connection_factory.dart';
import 'ssh_shell_handler.dart';

/// SSH Connection Manager for handling SSH connections and terminal sessions
class SshConnectionManager {
  static SshConnectionManager? _instance;
  static SshConnectionManager get instance => _instance ??= SshConnectionManager._();

  SshConnectionManager._() {
    _connectionFactory = SshConnectionFactory(eventEmitter: _emitEvent);
    _shellHandler = SshShellHandler(eventEmitter: _emitEvent);
  }

  final Map<String, ConnectionSession> _connections = {};
  final StreamController<SshConnectionEvent> _eventController = StreamController.broadcast();
  
  // Components
  late final SshConnectionFactory _connectionFactory;
  late final SshShellHandler _shellHandler;

  /// Stream of connection events
  Stream<SshConnectionEvent> get events => _eventController.stream;

  /// Connect to SSH host
  Future<String> connect(SshProfile profile) async {
    try {
      // Close existing connection if any
      await disconnect(profile.id);
      
      // Create new connection session
      final session = await _connectionFactory.createConnection(profile);
      
      // Set up shell handlers
      _shellHandler.setupShellHandlers(session);
      
      // Store session
      _connections[session.id] = session;
      
      return session.id;
      
    } catch (e) {
      debugPrint('SSH connection failed: $e');
      rethrow;
    }
  }
  
  /// Disconnect from SSH host with proper resource cleanup
  Future<void> disconnect(String sessionId) async {
    final session = _connections[sessionId];
    if (session == null) return;
    
    debugPrint('Disconnecting SSH session: $sessionId');
    
    try {
      session.dispose();
      _connections.remove(sessionId);
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.disconnected,
        timestamp: DateTime.now(),
      ));
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.closed,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error disconnecting SSH session: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Disconnect error: $e',
        timestamp: DateTime.now(),
      ));
    }
  }
  
  /// Send command to SSH session with enhanced command tracking
  Future<void> sendCommand(String sessionId, String command) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No active SSH session found: $sessionId');
    }
    
    // Mark welcome message as shown after first command and cancel timeout
    if (!session.welcomeMessageShown) {
      session.markWelcomeShown();
    }
    
    await _shellHandler.sendCommand(session, command);
  }
  
  /// Send raw data to SSH session
  Future<void> sendData(String sessionId, String data) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No active SSH session found: $sessionId');
    }
    
    await _shellHandler.sendData(session, data);
  }
  
  /// Get connection status
  SshConnectionStatus getStatus(String sessionId) {
    return _connections[sessionId]?.status ?? SshConnectionStatus.disconnected;
  }
  
  /// Check if session is connected
  bool isConnected(String sessionId) {
    return getStatus(sessionId) == SshConnectionStatus.connected;
  }
  
  /// Get session output buffer
  String getOutput(String sessionId) {
    return _connections[sessionId]?.outputBuffer.toString() ?? '';
  }
  
  /// Clear output buffer
  void clearOutput(String sessionId) {
    _connections[sessionId]?.clearAllOutput();
  }
  
  /// Clear command-specific output buffer
  void clearCommandOutput(String sessionId) {
    _connections[sessionId]?.clearCommandOutput();
  }
  
  /// Get command output without welcome messages
  String getCommandOutput(String sessionId) {
    return _connections[sessionId]?.commandBuffer.toString() ?? '';
  }
  
  /// Get welcome message
  String getWelcomeMessage(String sessionId) {
    return _connections[sessionId]?.welcomeBuffer.toString() ?? '';
  }
  
  /// Mark welcome message as shown to prevent repetition
  void markWelcomeShown(String sessionId) {
    _connections[sessionId]?.markWelcomeShown();
  }
  
  /// Check if welcome message was already shown
  bool isWelcomeShown(String sessionId) {
    return _connections[sessionId]?.welcomeMessageShown ?? false;
  }
  
  /// Check if currently executing an interactive command
  bool isInInteractiveMode(String sessionId) {
    final session = _connections[sessionId];
    return session != null && session.currentCommand != null;
  }
  
  /// Get current executing command
  String? getCurrentCommand(String sessionId) {
    return _connections[sessionId]?.currentCommand;
  }
  
  /// Get comprehensive session statistics
  Map<String, dynamic> getSessionStats(String sessionId) {
    final session = _connections[sessionId];
    if (session == null) return {};
    
    return session.getStats();
  }
  
  /// Get list of all active session IDs
  List<String> getActiveSessions() {
    return _connections.keys.toList();
  }
  
  /// Get detailed connection status for all sessions
  Map<String, Map<String, dynamic>> getAllSessionStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final sessionId in _connections.keys) {
      stats[sessionId] = getSessionStats(sessionId);
    }
    return stats;
  }
  
  /// Reconnect to SSH host
  Future<void> reconnect(String sessionId) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No session found to reconnect: $sessionId');
    }
    
    try {
      debugPrint('Reconnecting SSH session: $sessionId');
      
      // Store profile for reconnection
      final profile = session.profile;
      
      // Disconnect current session
      await disconnect(sessionId);
      
      // Create new connection
      await connect(profile);
      
    } catch (e) {
      debugPrint('SSH reconnection failed: $e');
      rethrow;
    }
  }
  
  /// Disconnect all active sessions
  Future<void> disconnectAll() async {
    final sessionIds = _connections.keys.toList();
    for (final sessionId in sessionIds) {
      await disconnect(sessionId);
    }
  }
  
  /// Force disconnect with minimal cleanup for emergency cases
  Future<void> forceDisconnect(String sessionId) async {
    final session = _connections.remove(sessionId);
    if (session != null) {
      try {
        session.dispose();
      } catch (e) {
        debugPrint('Error during force disconnect: $e');
      }
    }
  }
  
  /// Test connection without establishing full session
  Future<bool> testConnection(SshProfile profile) async {
    return await _connectionFactory.testConnection(profile);
  }
  
  /// Get SSH client for session (for backward compatibility)
  SSHClient? getSshClient(String sessionId) {
    return _connections[sessionId]?.client;
  }
  
  /// Get SSH profile for session
  SshProfile? getSessionProfile(String sessionId) {
    return _connections[sessionId]?.profile;
  }
  
  /// Emit connection event
  void _emitEvent(SshConnectionEvent event) {
    _eventController.add(event);
  }
  
  /// Dispose all resources
  void dispose() {
    disconnectAll();
    _eventController.close();
  }
}