import 'dart:async';

import '../models/ssh_profile_models.dart';
import 'terminal_session_models.dart';
import 'terminal_session_manager.dart';

/// Terminal session handler for managing terminal sessions with enhanced block support
/// This is now a lightweight facade over TerminalSessionManager
class TerminalSessionHandler {
  static TerminalSessionHandler? _instance;
  static TerminalSessionHandler get instance => _instance ??= TerminalSessionHandler._();

  TerminalSessionHandler._();

  final TerminalSessionManager _manager = TerminalSessionManager();

  /// Stream of terminal output
  Stream<TerminalOutput> get output => _manager.output;

  /// Create a new SSH terminal session
  Future<String> createSshSession(SshProfile profile) async {
    return await _manager.createSshSession(profile);
  }
  
  /// Create a new WebSocket terminal session
  Future<String> createWebSocketSession(String url) async {
    return await _manager.createWebSocketSession(url);
  }
  
  /// Create a local terminal session (future implementation)
  Future<String> createLocalSession() async {
    return await _manager.createLocalSession();
  }
  
  /// Send command to terminal session with enhanced metadata tracking
  Future<void> sendCommand(String sessionId, String command) async {
    return await _manager.sendCommand(sessionId, command);
  }
  
  /// Send raw data to terminal session
  Future<void> sendData(String sessionId, String data) async {
    return await _manager.sendData(sessionId, data);
  }
  
  /// Stop terminal session
  Future<void> stopSession(String sessionId) async {
    return await _manager.stopSession(sessionId);
  }
  
  /// Get session state
  TerminalSessionState getSessionState(String sessionId) {
    return _manager.getSessionState(sessionId);
  }
  
  /// Check if session is running
  bool isSessionRunning(String sessionId) {
    return _manager.isSessionRunning(sessionId);
  }
  
  /// Get all active sessions
  List<String> getActiveSessions() {
    return _manager.getActiveSessions();
  }
  
  /// Get session info with enhanced metadata
  Map<String, dynamic> getSessionInfo(String sessionId) {
    return _manager.getSessionInfo(sessionId);
  }
  
  /// Get command history for session
  List<Map<String, dynamic>> getSessionCommandHistory(String sessionId) {
    return _manager.getSessionCommandHistory(sessionId);
  }
  
  /// Get all command history across sessions
  Map<String, List<Map<String, dynamic>>> getAllCommandHistory() {
    return _manager.getAllCommandHistory();
  }
  
  /// Get session metadata
  Map<String, dynamic> getSessionMetadata(String sessionId) {
    return _manager.getSessionMetadata(sessionId);
  }
  
  /// Update session metadata
  void updateSessionMetadata(String sessionId, Map<String, dynamic> metadata) {
    _manager.updateSessionMetadata(sessionId, metadata);
  }
  
  /// Get session statistics
  Map<String, dynamic> getSessionStats(String sessionId) {
    return _manager.getSessionStats(sessionId);
  }
  
  
  /// Stop all sessions
  Future<void> stopAllSessions() async {
    return await _manager.stopAllSessions();
  }
  
  /// Clear session history
  void clearSessionHistory(String sessionId) {
    _manager.clearSessionHistory(sessionId);
  }
  
  /// Export session data for backup or analysis
  Map<String, dynamic> exportSessionData(String sessionId) {
    return _manager.exportSessionData(sessionId);
  }
  
  /// Dispose resources
  void dispose() {
    _manager.dispose();
  }
}
