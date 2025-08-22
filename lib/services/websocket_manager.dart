import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../main.dart';

/// WebSocket connection state
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

/// Terminal message types
enum TerminalMessageType {
  data,
  resize,
  control,
  heartbeat,
}

/// Terminal message wrapper
class TerminalMessage {
  final TerminalMessageType type;
  final dynamic data;
  final String? sessionId;
  final DateTime timestamp;
  
  TerminalMessage({
    required this.type,
    required this.data,
    this.sessionId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'data': data,
      if (sessionId != null) 'sessionId': sessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory TerminalMessage.fromJson(Map<String, dynamic> json) {
    return TerminalMessage(
      type: TerminalMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TerminalMessageType.data,
      ),
      data: json['data'],
      sessionId: json['sessionId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
  
  factory TerminalMessage.data(String data, {String? sessionId}) {
    return TerminalMessage(
      type: TerminalMessageType.data,
      data: data,
      sessionId: sessionId,
    );
  }
  
  factory TerminalMessage.resize(int cols, int rows, {String? sessionId}) {
    return TerminalMessage(
      type: TerminalMessageType.resize,
      data: {'cols': cols, 'rows': rows},
      sessionId: sessionId,
    );
  }
  
  factory TerminalMessage.control(String command, {String? sessionId}) {
    return TerminalMessage(
      type: TerminalMessageType.control,
      data: command,
      sessionId: sessionId,
    );
  }
}

/// WebSocket manager for terminal communication
class WebSocketManager {
  static WebSocketManager? _instance;
  static WebSocketManager get instance => _instance ??= WebSocketManager._();
  
  WebSocketChannel? _channel;
  WebSocketState _state = WebSocketState.disconnected;
  final FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  // Stream controllers
  final StreamController<TerminalMessage> _messageController = StreamController.broadcast();
  final StreamController<WebSocketState> _stateController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  
  // Connection management
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 2);
  
  WebSocketManager._();
  
  // Public streams
  Stream<TerminalMessage> get messageStream => _messageController.stream;
  Stream<WebSocketState> get stateStream => _stateController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  WebSocketState get state => _state;
  bool get isConnected => _state == WebSocketState.connected;
  bool get isConnecting => _state == WebSocketState.connecting;
  
  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_state == WebSocketState.connected || _state == WebSocketState.connecting) {
      debugPrint('WebSocket already connected or connecting');
      return _state == WebSocketState.connected;
    }
    
    try {
      _updateState(WebSocketState.connecting);
      
      // Get authentication token
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token == null) {
        _handleError('No authentication token available');
        return false;
      }
      
      // Build WebSocket URL with authentication
      final wsUrl = '${ApiConfig.wsUrl}/terminal?token=$token';
      
      debugPrint('Connecting to WebSocket: $wsUrl');
      
      // Create WebSocket connection
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleConnectionError,
        onDone: _handleConnectionClosed,
      );
      
      // Wait for connection confirmation or timeout
      await Future.delayed(const Duration(seconds: 3));
      
      if (_state == WebSocketState.connecting) {
        _updateState(WebSocketState.connected);
        _startHeartbeat();
        _reconnectAttempts = 0;
        debugPrint('WebSocket connected successfully');
        return true;
      }
      
      return false;
    } catch (e) {
      _handleError('Failed to connect: $e');
      return false;
    }
  }
  
  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    debugPrint('Disconnecting WebSocket');
    
    _stopHeartbeat();
    _stopReconnectTimer();
    
    await _channel?.sink.close();
    _channel = null;
    
    _updateState(WebSocketState.disconnected);
  }
  
  /// Send a terminal message
  Future<bool> sendMessage(TerminalMessage message) async {
    if (!isConnected) {
      debugPrint('Cannot send message: WebSocket not connected');
      return false;
    }
    
    try {
      final jsonData = json.encode(message.toJson());
      _channel!.sink.add(jsonData);
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _handleError('Failed to send message: $e');
      return false;
    }
  }
  
  /// Send terminal data (keyboard input)
  Future<bool> sendTerminalData(String data, {String? sessionId}) async {
    final message = TerminalMessage.data(data, sessionId: sessionId);
    return sendMessage(message);
  }
  
  /// Send terminal resize command
  Future<bool> resizeTerminal(int cols, int rows, {String? sessionId}) async {
    final message = TerminalMessage.resize(cols, rows, sessionId: sessionId);
    return sendMessage(message);
  }
  
  /// Send control command
  Future<bool> sendControlCommand(String command, {String? sessionId}) async {
    final message = TerminalMessage.control(command, sessionId: sessionId);
    return sendMessage(message);
  }
  
  void _handleMessage(dynamic data) {
    try {
      if (data is String) {
        // JSON message
        final jsonData = json.decode(data);
        final message = TerminalMessage.fromJson(jsonData);
        _messageController.add(message);
      } else if (data is Uint8List) {
        // Binary data (terminal output)
        final message = TerminalMessage.data(
          String.fromCharCodes(data),
        );
        _messageController.add(message);
      } else {
        debugPrint('Received unknown message type: ${data.runtimeType}');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
      _handleError('Failed to parse message: $e');
    }
  }
  
  void _handleConnectionError(error) {
    debugPrint('WebSocket error: $error');
    _handleError('Connection error: $error');
    _attemptReconnect();
  }
  
  void _handleConnectionClosed() {
    debugPrint('WebSocket connection closed');
    _updateState(WebSocketState.disconnected);
    _stopHeartbeat();
    _attemptReconnect();
  }
  
  void _handleError(String error) {
    debugPrint('WebSocket error: $error');
    _updateState(WebSocketState.error);
    _errorController.add(error);
  }
  
  void _updateState(WebSocketState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
      debugPrint('WebSocket state changed to: $newState');
    }
  }
  
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (isConnected) {
        final heartbeat = TerminalMessage(
          type: TerminalMessageType.heartbeat,
          data: 'ping',
        );
        sendMessage(heartbeat);
      } else {
        timer.cancel();
      }
    });
  }
  
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  void _attemptReconnect() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      _updateState(WebSocketState.error);
      return;
    }
    
    if (_state == WebSocketState.reconnecting) {
      return; // Already attempting to reconnect
    }
    
    _updateState(WebSocketState.reconnecting);
    _reconnectAttempts++;
    
    debugPrint('Attempting to reconnect (attempt $_reconnectAttempts/$maxReconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      reconnectDelay * _reconnectAttempts, // Exponential backoff
      () async {
        final success = await connect();
        if (!success && _reconnectAttempts < maxReconnectAttempts) {
          _attemptReconnect();
        }
      },
    );
  }
  
  void _stopReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  /// Dispose the WebSocket manager
  Future<void> dispose() async {
    await disconnect();
    await _messageController.close();
    await _stateController.close();
    await _errorController.close();
  }
}