import 'dart:async';
import 'dart:math';

import 'package:devpocket_warp_app/services/websocket_manager.dart';

/// WebSocket State Manager for comprehensive testing of connection lifecycle
/// Provides detailed simulation of connection states, transitions, and edge cases
class WebSocketStateManager {
  
  // Connection state tracking
  WebSocketState _currentState = WebSocketState.disconnected;
  final List<WebSocketStateTransition> _stateHistory = [];
  
  // Connection metrics
  int _connectionAttempts = 0;
  int _successfulConnections = 0;
  int _failedConnections = 0;
  int _disconnectionCount = 0;
  Duration _totalConnectedTime = Duration.zero;
  DateTime? _lastConnectionStart;
  
  // Configuration
  final Duration _reconnectDelay;
  final int _maxReconnectAttempts;
  final double _connectionFailureRate;
  final bool _shouldSimulateLatency;
  final Random _random = Random();
  
  // Stream controllers for state events
  final StreamController<WebSocketStateTransition> _stateController = StreamController.broadcast();
  final StreamController<WebSocketConnectionMetrics> _metricsController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  
  // Timers for connection lifecycle
  Timer? _connectionTimer;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  
  WebSocketStateManager({
    Duration reconnectDelay = const Duration(seconds: 2),
    int maxReconnectAttempts = 3,
    double connectionFailureRate = 0.0,
    bool shouldSimulateLatency = true,
  })  : _reconnectDelay = reconnectDelay,
        _maxReconnectAttempts = maxReconnectAttempts,
        _connectionFailureRate = connectionFailureRate,
        _shouldSimulateLatency = shouldSimulateLatency;
  
  // Public getters
  WebSocketState get currentState => _currentState;
  bool get isConnected => _currentState == WebSocketState.connected;
  bool get isConnecting => _currentState == WebSocketState.connecting;
  bool get isDisconnected => _currentState == WebSocketState.disconnected;
  bool get isError => _currentState == WebSocketState.error;
  
  List<WebSocketStateTransition> get stateHistory => List.unmodifiable(_stateHistory);
  Stream<WebSocketStateTransition> get stateStream => _stateController.stream;
  Stream<WebSocketConnectionMetrics> get metricsStream => _metricsController.stream;
  Stream<String> get errorStream => _errorController.stream;
  
  WebSocketConnectionMetrics get metrics => WebSocketConnectionMetrics(
    connectionAttempts: _connectionAttempts,
    successfulConnections: _successfulConnections,
    failedConnections: _failedConnections,
    disconnectionCount: _disconnectionCount,
    totalConnectedTime: _totalConnectedTime,
    currentConnectionDuration: _getCurrentConnectionDuration(),
    averageConnectionDuration: _getAverageConnectionDuration(),
    connectionSuccessRate: _getConnectionSuccessRate(),
  );
  
  /// Initiate connection with realistic state transitions
  Future<bool> connect({String? url}) async {
    if (_currentState == WebSocketState.connected) {
      return true; // Already connected
    }
    
    if (_currentState == WebSocketState.connecting) {
      throw StateError('Connection already in progress');
    }
    
    return await _performConnection(url);
  }
  
  /// Disconnect with proper cleanup
  Future<void> disconnect() async {
    if (_currentState == WebSocketState.disconnected) {
      return; // Already disconnected
    }
    
    await _performDisconnection(DisconnectionReason.clientRequest);
  }
  
  /// Reconnect with backoff strategy
  Future<bool> reconnect({String? url}) async {
    await disconnect();
    await Future.delayed(_reconnectDelay);
    return await connect(url: url);
  }
  
  /// Simulate network interruption
  Future<void> simulateNetworkInterruption({
    Duration duration = const Duration(seconds: 3),
    bool autoReconnect = true,
  }) async {
    if (!isConnected) return;
    
    await _transitionToState(
      WebSocketState.error,
      DisconnectionReason.networkError,
      'Simulated network interruption',
    );
    
    await Future.delayed(duration);
    
    if (autoReconnect) {
      await _attemptReconnection();
    }
  }
  
  /// Simulate connection timeout
  Future<void> simulateConnectionTimeout() async {
    if (_currentState != WebSocketState.connecting) {
      throw StateError('Can only simulate timeout during connection attempt');
    }
    
    await _transitionToState(
      WebSocketState.error,
      DisconnectionReason.timeout,
      'Connection timeout simulated',
    );
  }
  
  /// Force state change for testing edge cases
  Future<void> forceStateChange(WebSocketState newState, {String? reason}) async {
    await _transitionToState(newState, DisconnectionReason.unknown, reason ?? 'Forced state change');
  }
  
  /// Internal connection logic
  Future<bool> _performConnection(String? url) async {
    _connectionAttempts++;
    
    await _transitionToState(
      WebSocketState.connecting,
      DisconnectionReason.none,
      'Connection attempt started',
    );
    
    // Simulate connection process with potential failure
    if (_shouldConnectionFail()) {
      await Future.delayed(_getConnectionDelay());
      _failedConnections++;
      await _transitionToState(
        WebSocketState.error,
        DisconnectionReason.connectionFailed,
        'Connection failed - simulated network error',
      );
      return false;
    }
    
    // Simulate realistic connection time
    await Future.delayed(_getConnectionDelay());
    
    // Check for timeout during connection
    if (_connectionAttempts > _maxReconnectAttempts) {
      _failedConnections++;
      await _transitionToState(
        WebSocketState.error,
        DisconnectionReason.timeout,
        'Connection timeout after $_maxReconnectAttempts attempts',
      );
      return false;
    }
    
    // Successful connection
    _successfulConnections++;
    _lastConnectionStart = DateTime.now();
    
    await _transitionToState(
      WebSocketState.connected,
      DisconnectionReason.none,
      'Connection established successfully',
    );
    
    // Start keep-alive mechanism
    _startKeepAlive();
    
    return true;
  }
  
  /// Internal disconnection logic
  Future<void> _performDisconnection(DisconnectionReason reason) async {
    final previousState = _currentState;
    
    if (previousState == WebSocketState.connected) {
      // Transition directly to disconnected since disconnecting state doesn't exist
      await _transitionToState(
        WebSocketState.disconnected,
        reason,
        'Disconnection initiated',
      );
      
      // Update connection duration
      if (_lastConnectionStart != null) {
        _totalConnectedTime = _totalConnectedTime + DateTime.now().difference(_lastConnectionStart!);
      }
    }
    
    // Simulate disconnection delay
    if (_shouldSimulateLatency) {
      await Future.delayed(Duration(milliseconds: 100 + _random.nextInt(200)));
    }
    
    _disconnectionCount++;
    
    await _transitionToState(
      WebSocketState.disconnected,
      reason,
      'Disconnection completed',
    );
    
    // Cancel timers
    _cancelTimers();
  }
  
  /// State transition with history tracking
  Future<void> _transitionToState(
    WebSocketState newState,
    DisconnectionReason reason,
    String message,
  ) async {
    final previousState = _currentState;
    final transition = WebSocketStateTransition(
      from: previousState,
      to: newState,
      reason: reason,
      message: message,
      timestamp: DateTime.now(),
    );
    
    _currentState = newState;
    _stateHistory.add(transition);
    
    // Emit state change events
    _stateController.add(transition);
    _metricsController.add(metrics);
    
    // Log state changes for debugging
    print('WebSocket state: $previousState → $newState ($message)');
    
    // Handle error states
    if (newState == WebSocketState.error) {
      _errorController.add(message);
    }
  }
  
  /// Attempt automatic reconnection
  Future<void> _attemptReconnection() async {
    int attempts = 0;
    
    while (attempts < _maxReconnectAttempts && !isConnected) {
      attempts++;
      print('Reconnection attempt $attempts/$_maxReconnectAttempts');
      
      try {
        final success = await connect();
        if (success) {
          print('Reconnection successful');
          return;
        }
      } catch (e) {
        print('Reconnection attempt $attempts failed: $e');
      }
      
      // Exponential backoff
      final backoffDelay = Duration(
        milliseconds: _reconnectDelay.inMilliseconds * (attempts * attempts),
      );
      await Future.delayed(backoffDelay);
    }
    
    print('Reconnection failed after $attempts attempts');
    await _transitionToState(
      WebSocketState.error,
      DisconnectionReason.reconnectFailed,
      'Failed to reconnect after $attempts attempts',
    );
  }
  
  /// Start keep-alive mechanism
  void _startKeepAlive() {
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!isConnected) {
        timer.cancel();
        return;
      }
      
      // Simulate keep-alive ping
      print('Keep-alive ping sent');
    });
  }
  
  /// Cancel all active timers
  void _cancelTimers() {
    _connectionTimer?.cancel();
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
  }
  
  /// Determine if connection should fail based on configuration
  bool _shouldConnectionFail() {
    return _connectionFailureRate > 0.0 && _random.nextDouble() < _connectionFailureRate;
  }
  
  /// Get realistic connection delay
  Duration _getConnectionDelay() {
    if (!_shouldSimulateLatency) {
      return const Duration(milliseconds: 50);
    }
    
    // Simulate realistic connection times (100ms to 2 seconds)
    final baseDelay = 100 + _random.nextInt(1900);
    return Duration(milliseconds: baseDelay);
  }
  
  /// Calculate current connection duration
  Duration _getCurrentConnectionDuration() {
    if (_currentState != WebSocketState.connected || _lastConnectionStart == null) {
      return Duration.zero;
    }
    return DateTime.now().difference(_lastConnectionStart!);
  }
  
  /// Calculate average connection duration
  Duration _getAverageConnectionDuration() {
    if (_successfulConnections == 0) return Duration.zero;
    
    final totalMs = _totalConnectedTime.inMilliseconds + _getCurrentConnectionDuration().inMilliseconds;
    return Duration(milliseconds: totalMs ~/ _successfulConnections);
  }
  
  /// Calculate connection success rate
  double _getConnectionSuccessRate() {
    if (_connectionAttempts == 0) return 0.0;
    return _successfulConnections / _connectionAttempts;
  }
  
  /// Get state transition summary for debugging
  Map<String, dynamic> getStateTransitionSummary() {
    final transitions = <String, int>{};
    
    for (final transition in _stateHistory) {
      final key = '${transition.from} → ${transition.to}';
      transitions[key] = (transitions[key] ?? 0) + 1;
    }
    
    return {
      'total_transitions': _stateHistory.length,
      'transition_counts': transitions,
      'current_state': _currentState.toString(),
      'connection_metrics': {
        'attempts': _connectionAttempts,
        'successful': _successfulConnections,
        'failed': _failedConnections,
        'success_rate': '${(_getConnectionSuccessRate() * 100).toStringAsFixed(1)}%',
      },
    };
  }
  
  /// Reset all state and metrics
  void reset() {
    _cancelTimers();
    _currentState = WebSocketState.disconnected;
    _stateHistory.clear();
    _connectionAttempts = 0;
    _successfulConnections = 0;
    _failedConnections = 0;
    _disconnectionCount = 0;
    _totalConnectedTime = Duration.zero;
    _lastConnectionStart = null;
  }
  
  /// Dispose of resources
  void dispose() {
    _cancelTimers();
    _stateController.close();
    _metricsController.close();
    _errorController.close();
  }
}

/// Represents a state transition with metadata
class WebSocketStateTransition {
  final WebSocketState from;
  final WebSocketState to;
  final DisconnectionReason reason;
  final String message;
  final DateTime timestamp;
  
  WebSocketStateTransition({
    required this.from,
    required this.to,
    required this.reason,
    required this.message,
    required this.timestamp,
  });
  
  @override
  String toString() => '$from → $to: $message (${timestamp.toIso8601String()})';
  
  Map<String, dynamic> toJson() => {
    'from': from.toString(),
    'to': to.toString(),
    'reason': reason.toString(),
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Connection metrics for monitoring and testing
class WebSocketConnectionMetrics {
  final int connectionAttempts;
  final int successfulConnections;
  final int failedConnections;
  final int disconnectionCount;
  final Duration totalConnectedTime;
  final Duration currentConnectionDuration;
  final Duration averageConnectionDuration;
  final double connectionSuccessRate;
  
  WebSocketConnectionMetrics({
    required this.connectionAttempts,
    required this.successfulConnections,
    required this.failedConnections,
    required this.disconnectionCount,
    required this.totalConnectedTime,
    required this.currentConnectionDuration,
    required this.averageConnectionDuration,
    required this.connectionSuccessRate,
  });
  
  @override
  String toString() => 'WebSocketMetrics('
      'attempts: $connectionAttempts, '
      'successful: $successfulConnections, '
      'failed: $failedConnections, '
      'success_rate: ${(connectionSuccessRate * 100).toStringAsFixed(1)}%)';
  
  Map<String, dynamic> toJson() => {
    'connection_attempts': connectionAttempts,
    'successful_connections': successfulConnections,
    'failed_connections': failedConnections,
    'disconnection_count': disconnectionCount,
    'total_connected_time_ms': totalConnectedTime.inMilliseconds,
    'current_connection_duration_ms': currentConnectionDuration.inMilliseconds,
    'average_connection_duration_ms': averageConnectionDuration.inMilliseconds,
    'connection_success_rate': connectionSuccessRate,
  };
}

/// Reasons for disconnection
enum DisconnectionReason {
  none,
  clientRequest,
  serverRequest,
  networkError,
  timeout,
  connectionFailed,
  reconnectFailed,
  authenticationFailed,
  protocolError,
  unknown,
}

/// Factory for creating different state manager configurations
class WebSocketStateManagerFactory {
  
  /// Create reliable state manager for stable testing
  static WebSocketStateManager createReliable() {
    return WebSocketStateManager(
      reconnectDelay: const Duration(milliseconds: 500),
      maxReconnectAttempts: 2,
      connectionFailureRate: 0.0,
      shouldSimulateLatency: false,
    );
  }
  
  /// Create realistic state manager with network conditions
  static WebSocketStateManager createRealistic() {
    return WebSocketStateManager(
      reconnectDelay: const Duration(seconds: 2),
      maxReconnectAttempts: 3,
      connectionFailureRate: 0.1,
      shouldSimulateLatency: true,
    );
  }
  
  /// Create unreliable state manager for error testing
  static WebSocketStateManager createUnreliable() {
    return WebSocketStateManager(
      reconnectDelay: const Duration(seconds: 1),
      maxReconnectAttempts: 5,
      connectionFailureRate: 0.4,
      shouldSimulateLatency: true,
    );
  }
  
  /// Create fast state manager for performance testing
  static WebSocketStateManager createFast() {
    return WebSocketStateManager(
      reconnectDelay: const Duration(milliseconds: 100),
      maxReconnectAttempts: 1,
      connectionFailureRate: 0.0,
      shouldSimulateLatency: false,
    );
  }
}