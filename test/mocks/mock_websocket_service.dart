import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:mockito/mockito.dart';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import 'package:devpocket_warp_app/services/terminal_websocket_service.dart';
import 'package:devpocket_warp_app/services/websocket_manager.dart';

/// WebSocket connection events for testing
enum WebSocketConnectionEvent {
  connecting,
  connected,
  disconnecting,
  disconnected,
  error,
}

/// Comprehensive WebSocket mock service for testing SSH terminal functionality
/// Provides realistic simulation of WebSocket connections, state management, and message flow
class MockWebSocketService extends Mock implements TerminalWebSocketService {
  
  // Connection state management
  bool _isConnected = false;
  WebSocketState _connectionState = WebSocketState.disconnected;
  final List<String> _activeSessions = [];
  final Map<String, SshProfile> _sessionProfiles = {};
  final Map<String, List<String>> _sessionMessages = {};
  
  // Stream controllers for real-time communication simulation
  final StreamController<String> _messageController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  final StreamController<WebSocketConnectionEvent> _connectionController = StreamController.broadcast();
  
  // Test configuration
  final Duration _connectionDelay;
  final double _errorRate;
  final bool _shouldSimulateNetworkDelay;
  final Random _random = Random();
  
  MockWebSocketService({
    Duration connectionDelay = const Duration(milliseconds: 100),
    double errorRate = 0.0, // 0.0 = no errors, 1.0 = always error
    bool shouldSimulateNetworkDelay = true,
  })  : _connectionDelay = connectionDelay,
        _errorRate = errorRate,
        _shouldSimulateNetworkDelay = shouldSimulateNetworkDelay;
  
  @override
  bool get isConnected => _isConnected;
  
  @override
  int get activeSessionCount => _activeSessions.length;
  
  @override
  WebSocketState get connectionState => _connectionState;
  
  /// Stream of WebSocket messages for testing
  Stream<String> get messages => _messageController.stream;
  
  /// Stream of connection events for testing WebSocket state changes
  Stream<WebSocketConnectionEvent> get connectionEvents => _connectionController.stream;
  
  /// Stream of WebSocket errors for testing
  Stream<String> get errors => _errorController.stream;
  
  /// Simulate WebSocket connection with configurable delay and error scenarios
  @override
  Future<void> connect([String? url]) async {
    if (_shouldThrowError('connect')) {
      throw Exception('Mock WebSocket connection failed: Network error');
    }
    
    _connectionState = WebSocketState.connecting;
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(_connectionDelay);
    }
    
    _isConnected = true;
    _connectionState = WebSocketState.connected;
    _connectionController.add(WebSocketConnectionEvent.connected);
    
    // Simulate initial connection message
    _messageController.add(jsonEncode({
      'type': 'connection_established',
      'timestamp': DateTime.now().toIso8601String(),
      'server_version': '1.0.0-mock'
    }));
  }
  
  /// Simulate WebSocket disconnection with cleanup
  @override
  Future<void> disconnect() async {
    if (!_isConnected) return;
    
    _connectionState = WebSocketState.disconnected;
    
    // Clean up all active sessions
    final sessionsToClose = List<String>.from(_activeSessions);
    for (final sessionId in sessionsToClose) {
      await _closeSessionInternal(sessionId);
    }
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: _connectionDelay.inMilliseconds ~/ 2));
    }
    
    _isConnected = false;
    _connectionState = WebSocketState.disconnected;
    _connectionController.add(WebSocketConnectionEvent.disconnected);
    
    // Simulate disconnection message
    _messageController.add(jsonEncode({
      'type': 'connection_closed',
      'timestamp': DateTime.now().toIso8601String(),
      'reason': 'client_disconnect'
    }));
  }
  
  /// Create a new terminal session via WebSocket
  @override
  Future<String> createTerminalSession(SshProfile profile) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    if (_shouldThrowError('createSession')) {
      throw Exception('Failed to create terminal session: Authentication failed');
    }
    
    final sessionId = 'mock_session_${profile.id}_${DateTime.now().millisecondsSinceEpoch}';
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));
    }
    
    _activeSessions.add(sessionId);
    _sessionProfiles[sessionId] = profile;
    _sessionMessages[sessionId] = [];
    
    // Simulate session creation response
    final sessionData = {
      'type': 'session_created',
      'session_id': sessionId,
      'profile': {
        'id': profile.id,
        'name': profile.name,
        'host': profile.host,
        'port': profile.port,
        'username': profile.username,
      },
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _messageController.add(jsonEncode(sessionData));
    
    // Simulate initial terminal output
    await Future.delayed(const Duration(milliseconds: 50));
    await _simulateTerminalOutput(sessionId, 'Welcome to ${profile.host}\n');
    await _simulateTerminalOutput(sessionId, '${profile.username}@${profile.host}:~\$ ');
    
    return sessionId;
  }
  
  /// Close a terminal session
  @override
  Future<void> closeTerminalSession(String sessionId) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    await _closeSessionInternal(sessionId);
  }
  
  /// Internal session cleanup logic
  Future<void> _closeSessionInternal(String sessionId) async {
    if (!_activeSessions.contains(sessionId)) return;
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
    }
    
    _activeSessions.remove(sessionId);
    _sessionProfiles.remove(sessionId);
    _sessionMessages.remove(sessionId);
    
    // Simulate session close message
    _messageController.add(jsonEncode({
      'type': 'session_closed',
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }
  
  /// Send terminal data to a specific session
  @override
  Future<void> sendTerminalData(String data, {String? sessionId}) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    if (sessionId != null && !_activeSessions.contains(sessionId)) {
      throw Exception('Session not found: $sessionId');
    }
    
    if (_shouldThrowError('sendData')) {
      throw Exception('Failed to send terminal data: Connection interrupted');
    }
    
    final targetSessionId = sessionId ?? _activeSessions.first;
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: 10 + _random.nextInt(50)));
    }
    
    // Store message in session history
    _sessionMessages[targetSessionId]?.add(data);
    
    // Simulate sending data to server
    _messageController.add(jsonEncode({
      'type': 'terminal_input',
      'session_id': targetSessionId,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    
    // Simulate command execution and response
    await _simulateCommandResponse(targetSessionId, data);
  }
  
  /// Send terminal control commands (clear, resize, etc.)
  @override
  Future<void> sendTerminalControl(String command, {String? sessionId}) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final targetSessionId = sessionId ?? _activeSessions.first;
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: 50 + _random.nextInt(100)));
    }
    
    _messageController.add(jsonEncode({
      'type': 'terminal_control',
      'session_id': targetSessionId,
      'command': command,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    
    // Handle specific control commands
    switch (command.toLowerCase()) {
      case 'clear':
        await _simulateTerminalOutput(targetSessionId, '\x1b[2J\x1b[H');
        break;
      case 'reset':
        await _simulateTerminalOutput(targetSessionId, '\x1bc');
        break;
    }
  }
  
  /// Resize terminal dimensions
  @override
  Future<void> resizeTerminal(int cols, int rows, {String? sessionId}) async {
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final targetSessionId = sessionId ?? _activeSessions.first;
    
    if (_shouldSimulateNetworkDelay) {
      await Future.delayed(Duration(milliseconds: 20 + _random.nextInt(80)));
    }
    
    _messageController.add(jsonEncode({
      'type': 'terminal_resize',
      'session_id': targetSessionId,
      'cols': cols,
      'rows': rows,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }
  
  /// Get list of active session IDs
  @override
  List<String> getActiveSessions() => List.from(_activeSessions);
  
  /// Get session information
  Map<String, dynamic> getSessionInfo(String sessionId) {
    final profile = _sessionProfiles[sessionId];
    final messages = _sessionMessages[sessionId];
    
    return {
      'session_id': sessionId,
      'profile': profile?.toJson(),
      'message_count': messages?.length ?? 0,
      'is_active': _activeSessions.contains(sessionId),
      'created_at': DateTime.now().toIso8601String(), // Mock timestamp
    };
  }
  
  /// Get message history for a session
  List<String> getSessionMessages(String sessionId) {
    return List.from(_sessionMessages[sessionId] ?? []);
  }
  
  /// Simulate terminal output from server
  Future<void> _simulateTerminalOutput(String sessionId, String output) async {
    if (!_activeSessions.contains(sessionId)) return;
    
    _messageController.add(jsonEncode({
      'type': 'terminal_output',
      'session_id': sessionId,
      'data': output,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }
  
  /// Simulate command execution and response
  Future<void> _simulateCommandResponse(String sessionId, String input) async {
    if (!_activeSessions.contains(sessionId)) return;
    
    final command = input.trim();
    if (command.isEmpty) return;
    
    // Simulate processing delay with timeout protection
    final maxDelay = Duration(milliseconds: 100 + _random.nextInt(300));
    final actualDelay = maxDelay.inMilliseconds > 1000 
        ? const Duration(milliseconds: 500) // Cap delay at 500ms for tests
        : maxDelay;
    
    await Future.delayed(actualDelay);
    
    final profile = _sessionProfiles[sessionId];
    String response = '';
    
    // Simulate common command responses with timeout protection
    switch (command.toLowerCase()) {
      case 'ls':
      case 'ls -la':
        response = 'total 48\n'
            'drwxr-xr-x  7 ${profile?.username ?? 'user'} ${profile?.username ?? 'user'}  224 Jan 24 10:30 .\n'
            'drwxr-xr-x  3 ${profile?.username ?? 'user'} ${profile?.username ?? 'user'}   96 Jan 24 10:29 ..\n'
            '-rw-r--r--  1 ${profile?.username ?? 'user'} ${profile?.username ?? 'user'}   57 Jan 24 10:30 README.md\n'
            'drwxr-xr-x  5 ${profile?.username ?? 'user'} ${profile?.username ?? 'user'}  160 Jan 24 10:30 src\n';
        break;
      case 'pwd':
        response = '/home/${profile?.username ?? 'user'}\n';
        break;
      case 'whoami':
        response = '${profile?.username ?? 'user'}\n';
        break;
      case 'date':
        response = '${DateTime.now().toString()}\n';
        break;
      case 'echo "test"':
      case 'echo test':
        response = 'test\n';
        break;
      case 'clear':
        response = '\x1b[2J\x1b[H'; // ANSI clear screen
        break;
      default:
        if (command.startsWith('echo ')) {
          final text = command.substring(5).replaceAll('"', '');
          response = '$text\n';
        } else {
          response = 'bash: $command: command not found\n';
        }
    }
    
    // Use timeout-protected output simulation
    try {
      await _simulateTerminalOutput(sessionId, response)
          .timeout(const Duration(milliseconds: 500));
      await _simulateTerminalOutput(sessionId, '${profile?.username ?? 'user'}@${profile?.host ?? 'localhost'}:~\$ ')
          .timeout(const Duration(milliseconds: 500));
    } catch (e) {
      // Prevent infinite loops - just log and continue
      print('WebSocket mock response timeout: $e');
    }
  }
  
  /// Determine if an operation should throw an error based on configured error rate
  bool _shouldThrowError(String operation) {
    if (_errorRate <= 0.0) return false;
    return _random.nextDouble() < _errorRate;
  }
  
  /// Simulate network interruption
  Future<void> simulateNetworkInterruption({Duration duration = const Duration(seconds: 2)}) async {
    if (!_isConnected) return;
    
    final wasConnected = _isConnected;
    _isConnected = false;
    _connectionState = WebSocketState.disconnected;
    _connectionController.add(WebSocketConnectionEvent.error);
    
    _errorController.add('Network interruption simulated');
    
    await Future.delayed(duration);
    
    if (wasConnected) {
      await connect();
    }
  }
  
  /// Force connection error for testing error scenarios
  void forceConnectionError() {
    if (_isConnected) {
      _isConnected = false;
      _connectionState = WebSocketState.error;
      _connectionController.add(WebSocketConnectionEvent.error);
      _errorController.add('Forced connection error for testing');
    }
  }
  
  /// Reset mock service to initial state
  void reset() {
    _isConnected = false;
    _connectionState = WebSocketState.disconnected;
    _activeSessions.clear();
    _sessionProfiles.clear();
    _sessionMessages.clear();
  }
  
  /// Dispose of resources and close streams
  @override
  void dispose() {
    reset();
    _messageController.close();
    _connectionController.close();
    _errorController.close();
  }
}

/// Mock WebSocket Manager for testing connection state management
class MockWebSocketManager extends Mock implements WebSocketManager {
  WebSocketState _state = WebSocketState.disconnected;
  final Duration _connectionDelay;
  final double _errorRate;
  final Random _random = Random();
  
  MockWebSocketManager({
    Duration connectionDelay = const Duration(milliseconds: 150),
    double errorRate = 0.0,
  })  : _connectionDelay = connectionDelay,
        _errorRate = errorRate;
  
  @override
  WebSocketState get state => _state;
  
  @override
  bool get isConnected => _state == WebSocketState.connected;
  
  @override
  Future<bool> connect() async {
    if (_shouldThrowError('connect')) {
      _state = WebSocketState.error;
      throw Exception('Mock connection failed');
    }
    
    _state = WebSocketState.connecting;
    await Future.delayed(_connectionDelay);
    _state = WebSocketState.connected;
    return true;
  }
  
  @override
  Future<void> disconnect() async {
    if (_state == WebSocketState.disconnected) return;
    
    await Future.delayed(Duration(milliseconds: _connectionDelay.inMilliseconds ~/ 2));
    _state = WebSocketState.disconnected;
  }
  
  Future<bool> reconnect() async {
    await disconnect();
    await Future.delayed(const Duration(milliseconds: 100));
    return await connect();
  }
  
  /// Force state change for testing
  void setState(WebSocketState newState) {
    _state = newState;
  }
  
  /// Check if should throw error based on error rate
  bool _shouldThrowError(String operation) {
    return _errorRate > 0.0 && _random.nextDouble() < _errorRate;
  }
}

/// Factory for creating mock WebSocket services with different configurations
class MockWebSocketServiceFactory {
  
  /// Create a reliable mock service (no errors, minimal delays)
  static MockWebSocketService createReliable() {
    return MockWebSocketService(
      connectionDelay: const Duration(milliseconds: 50),
      errorRate: 0.0,
      shouldSimulateNetworkDelay: false,
    );
  }
  
  /// Create a mock service that simulates realistic network conditions
  static MockWebSocketService createRealistic() {
    return MockWebSocketService(
      connectionDelay: const Duration(milliseconds: 200),
      errorRate: 0.1, // 10% error rate
      shouldSimulateNetworkDelay: true,
    );
  }
  
  /// Create a mock service for testing error scenarios
  static MockWebSocketService createUnreliable() {
    return MockWebSocketService(
      connectionDelay: const Duration(seconds: 1),
      errorRate: 0.3, // 30% error rate
      shouldSimulateNetworkDelay: true,
    );
  }
  
  /// Create a fast mock service for performance testing
  static MockWebSocketService createFast() {
    return MockWebSocketService(
      connectionDelay: const Duration(milliseconds: 10),
      errorRate: 0.0,
      shouldSimulateNetworkDelay: false,
    );
  }
}