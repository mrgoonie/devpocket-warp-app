import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import 'websocket_manager.dart';
import 'auth_service.dart';

/// Terminal WebSocket service for backend API integration
class TerminalWebSocketService {
  static TerminalWebSocketService? _instance;
  static TerminalWebSocketService get instance => _instance ??= TerminalWebSocketService._();

  TerminalWebSocketService._();

  final WebSocketManager _wsManager = WebSocketManager.instance;
  final AuthService _authService = AuthService.instance;
  final Map<String, String> _sessionToWebSocketMap = {};

  /// Create a new terminal session via WebSocket
  Future<String> createTerminalSession(SshProfile profile) async {
    try {
      debugPrint('Creating WebSocket terminal session for ${profile.name}');
      
      // Get authentication token
      final token = await _authService.getValidAccessToken();
      if (token == null) {
        throw Exception('No valid authentication token available');
      }

      // Connect to WebSocket if not already connected
      if (!_wsManager.isConnected) {
        await _wsManager.connect();
      }

      // Send session creation request
      final sessionRequest = {
        'action': 'create_session',
        'profile': profile.toApiJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _wsManager.sendMessage(TerminalMessage(
        type: TerminalMessageType.control,
        data: sessionRequest,
      ));

      // Wait for session creation response
      final completer = Completer<String>();
      StreamSubscription? subscription;
      
      subscription = _wsManager.messageStream.listen((message) {
        if (message.type == TerminalMessageType.control) {
          final data = message.data as Map<String, dynamic>;
          if (data['action'] == 'session_created') {
            final sessionId = data['session_id'] as String;
            _sessionToWebSocketMap[sessionId] = profile.id;
            subscription?.cancel();
            completer.complete(sessionId);
          } else if (data['action'] == 'session_error') {
            subscription?.cancel();
            completer.completeError(Exception(data['error'] ?? 'Session creation failed'));
          }
        }
      });

      // Add timeout for session creation
      Timer(const Duration(seconds: 30), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.completeError(Exception('Session creation timeout'));
        }
      });

      return await completer.future;

    } catch (e) {
      debugPrint('Failed to create WebSocket terminal session: $e');
      rethrow;
    }
  }

  /// Send terminal data via WebSocket
  Future<void> sendTerminalData(String data, {String? sessionId}) async {
    try {
      if (!_wsManager.isConnected) {
        throw Exception('WebSocket not connected');
      }

      final message = TerminalMessage.data(data, sessionId: sessionId);
      await _wsManager.sendMessage(message);

    } catch (e) {
      debugPrint('Failed to send terminal data: $e');
      rethrow;
    }
  }

  /// Send terminal control command via WebSocket
  Future<void> sendTerminalControl(String command, {String? sessionId}) async {
    try {
      if (!_wsManager.isConnected) {
        throw Exception('WebSocket not connected');
      }

      final message = TerminalMessage.control(command, sessionId: sessionId);
      await _wsManager.sendMessage(message);

    } catch (e) {
      debugPrint('Failed to send terminal control: $e');
      rethrow;
    }
  }

  /// Resize terminal via WebSocket
  Future<void> resizeTerminal(int cols, int rows, {String? sessionId}) async {
    try {
      if (!_wsManager.isConnected) {
        throw Exception('WebSocket not connected');
      }

      final message = TerminalMessage.resize(cols, rows, sessionId: sessionId);
      await _wsManager.sendMessage(message);

    } catch (e) {
      debugPrint('Failed to resize terminal: $e');
      rethrow;
    }
  }

  /// Close terminal session via WebSocket
  Future<void> closeTerminalSession(String sessionId) async {
    try {
      if (!_wsManager.isConnected) {
        debugPrint('WebSocket not connected, cannot close session');
        return;
      }

      final closeRequest = {
        'action': 'close_session',
        'session_id': sessionId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _wsManager.sendMessage(TerminalMessage(
        type: TerminalMessageType.control,
        data: closeRequest,
        sessionId: sessionId,
      ));

      // Remove from session mapping
      _sessionToWebSocketMap.remove(sessionId);

      debugPrint('Terminal session closed: $sessionId');

    } catch (e) {
      debugPrint('Failed to close terminal session: $e');
      rethrow;
    }
  }

  /// Get terminal output stream
  Stream<TerminalMessage> getTerminalOutput({String? sessionId}) {
    return _wsManager.messageStream.where((message) {
      // Filter messages for specific session if provided
      if (sessionId != null) {
        return message.sessionId == sessionId;
      }
      return true;
    });
  }

  /// Check if WebSocket is connected
  bool get isConnected => _wsManager.isConnected;

  /// Get WebSocket connection state
  WebSocketState get connectionState => _wsManager.state;

  /// Connect to WebSocket
  Future<void> connect() async {
    await _wsManager.connect();
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    // Close all active sessions
    for (final sessionId in _sessionToWebSocketMap.keys) {
      await closeTerminalSession(sessionId);
    }
    
    await _wsManager.disconnect();
    _sessionToWebSocketMap.clear();
  }

  /// Send heartbeat to keep connection alive
  Future<void> sendHeartbeat() async {
    try {
      if (!_wsManager.isConnected) {
        return;
      }

      await _wsManager.sendMessage(TerminalMessage(
        type: TerminalMessageType.heartbeat,
        data: {'ping': DateTime.now().toIso8601String()},
      ));

    } catch (e) {
      debugPrint('Failed to send heartbeat: $e');
    }
  }

  /// Start periodic heartbeat
  Timer? _heartbeatTimer;
  
  void startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      sendHeartbeat();
    });
  }

  void stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Get active session IDs
  List<String> getActiveSessions() {
    return _sessionToWebSocketMap.keys.toList();
  }

  /// Get session count
  int get activeSessionCount => _sessionToWebSocketMap.length;

  /// Dispose resources
  void dispose() {
    stopHeartbeat();
    disconnect();
  }
}