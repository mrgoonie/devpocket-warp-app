import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/ssh_connection_error.dart';

/// Service for monitoring SSH connection health and quality
class SshHealthMonitor {
  static SshHealthMonitor? _instance;
  static SshHealthMonitor get instance => _instance ??= SshHealthMonitor._();

  SshHealthMonitor._();

  // Configuration constants
  static const Duration _defaultHealthCheckInterval = Duration(minutes: 2);
  static const Duration _timeoutThreshold = Duration(seconds: 30);
  static const int _maxConsecutiveFailures = 3;

  // Active monitoring sessions
  final Map<String, _HealthSession> _activeSessions = {};
  final StreamController<SshHealthUpdate> _healthController = StreamController.broadcast();

  /// Stream of health updates for all monitored connections
  Stream<SshHealthUpdate> get healthUpdates => _healthController.stream;

  /// Start monitoring health for a specific SSH session
  void startMonitoring(String sessionId, {
    Duration? healthCheckInterval,
    Duration? timeoutThreshold,
  }) {
    debugPrint('[HealthMonitor] Starting health monitoring for session: $sessionId');
    
    // Stop existing monitoring if any
    stopMonitoring(sessionId);

    final session = _HealthSession(
      sessionId: sessionId,
      healthCheckInterval: healthCheckInterval ?? _defaultHealthCheckInterval,
      timeoutThreshold: timeoutThreshold ?? _timeoutThreshold,
    );

    _activeSessions[sessionId] = session;
    _startHealthChecks(session);
  }

  /// Stop monitoring health for a specific SSH session
  void stopMonitoring(String sessionId) {
    final session = _activeSessions.remove(sessionId);
    if (session != null) {
      debugPrint('[HealthMonitor] Stopping health monitoring for session: $sessionId');
      session.dispose();
    }
  }

  /// Get current health metrics for a session
  SshHealthMetrics? getHealthMetrics(String sessionId) {
    final session = _activeSessions[sessionId];
    return session?.currentMetrics;
  }

  /// Update health metrics manually (e.g., from successful command execution)
  void updateHealthMetrics(String sessionId, {
    double? latencyMs,
    bool? isHealthy,
  }) {
    final session = _activeSessions[sessionId];
    if (session != null) {
      final currentMetrics = session.currentMetrics;
      final updatedMetrics = currentMetrics.copyWith(
        latencyMs: latencyMs ?? currentMetrics.latencyMs,
        isHealthy: isHealthy ?? currentMetrics.isHealthy,
        lastHealthCheck: DateTime.now(),
        quality: _calculateQuality(
          latencyMs ?? currentMetrics.latencyMs,
          isHealthy ?? currentMetrics.isHealthy,
        ),
      );

      session.updateMetrics(updatedMetrics);
      _emitHealthUpdate(sessionId, updatedMetrics);
    }
  }

  /// Record a connection error for health tracking
  void recordConnectionError(String sessionId, SshConnectionError error) {
    final session = _activeSessions[sessionId];
    if (session != null) {
      session.recordError(error);
      
      final currentMetrics = session.currentMetrics;
      final updatedMetrics = currentMetrics.copyWith(
        consecutiveFailures: currentMetrics.consecutiveFailures + 1,
        isHealthy: false,
        lastHealthCheck: DateTime.now(),
        quality: SshConnectionQuality.critical,
      );

      session.updateMetrics(updatedMetrics);
      _emitHealthUpdate(sessionId, updatedMetrics);
    }
  }

  /// Record a successful connection event
  void recordConnectionSuccess(String sessionId, {double? latencyMs}) {
    final session = _activeSessions[sessionId];
    if (session != null) {
      session.recordSuccess();
      
      final currentMetrics = session.currentMetrics;
      final updatedMetrics = currentMetrics.copyWith(
        consecutiveFailures: 0,
        isHealthy: true,
        lastHealthCheck: DateTime.now(),
        latencyMs: latencyMs ?? currentMetrics.latencyMs,
        quality: _calculateQuality(
          latencyMs ?? currentMetrics.latencyMs,
          true,
        ),
      );

      session.updateMetrics(updatedMetrics);
      _emitHealthUpdate(sessionId, updatedMetrics);
    }
  }

  /// Check if a session should trigger auto-reconnect based on health
  bool shouldAutoReconnect(String sessionId) {
    final session = _activeSessions[sessionId];
    if (session == null) return false;

    final metrics = session.currentMetrics;
    
    // Auto-reconnect conditions:
    // 1. Not currently healthy
    // 2. Consecutive failures below threshold
    // 3. Recent network connectivity
    return !metrics.isHealthy && 
           metrics.consecutiveFailures < _maxConsecutiveFailures &&
           session.hasRecentNetworkConnectivity;
  }

  /// Get health summary for all monitored sessions
  Map<String, SshHealthMetrics> getAllHealthMetrics() {
    final result = <String, SshHealthMetrics>{};
    for (final entry in _activeSessions.entries) {
      result[entry.key] = entry.value.currentMetrics;
    }
    return result;
  }

  /// Dispose all resources
  void dispose() {
    debugPrint('[HealthMonitor] Disposing health monitor');
    
    // Stop all active monitoring sessions
    final sessionIds = _activeSessions.keys.toList();
    for (final sessionId in sessionIds) {
      stopMonitoring(sessionId);
    }
    
    _healthController.close();
  }

  // Private methods

  void _startHealthChecks(_HealthSession session) {
    // Start periodic health checks
    session.healthTimer = Timer.periodic(session.healthCheckInterval, (_) {
      _performHealthCheck(session);
    });

    // Perform initial health check
    Timer(const Duration(seconds: 5), () {
      _performHealthCheck(session);
    });
  }

  Future<void> _performHealthCheck(_HealthSession session) async {
    if (session.isDisposed) return;

    debugPrint('[HealthMonitor] Performing health check for session: ${session.sessionId}');
    
    try {
      // Simple health check: try to establish a quick connection test
      // In a real implementation, this could be a lightweight command like 'echo test'
      final startTime = DateTime.now();
      
      // Simulate health check (in real implementation, this would be actual network test)
      await _simulateHealthCheck(session);
      
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds.toDouble();
      
      // Update metrics with successful health check
      final currentMetrics = session.currentMetrics;
      final updatedMetrics = currentMetrics.copyWith(
        latencyMs: latency,
        isHealthy: true,
        lastHealthCheck: endTime,
        consecutiveFailures: 0,
        quality: _calculateQuality(latency, true),
      );

      session.updateMetrics(updatedMetrics);
      session.recordSuccess();
      _emitHealthUpdate(session.sessionId, updatedMetrics);

    } catch (e) {
      debugPrint('[HealthMonitor] Health check failed for session ${session.sessionId}: $e');
      
      // Update metrics with failed health check
      final currentMetrics = session.currentMetrics;
      final updatedMetrics = currentMetrics.copyWith(
        isHealthy: false,
        lastHealthCheck: DateTime.now(),
        consecutiveFailures: currentMetrics.consecutiveFailures + 1,
        quality: SshConnectionQuality.critical,
      );

      session.updateMetrics(updatedMetrics);
      session.recordError(SshConnectionError.fromException(
        Exception('Health check failed: $e'),
        debugInfo: {'sessionId': session.sessionId},
      ));
      _emitHealthUpdate(session.sessionId, updatedMetrics);
    }
  }

  Future<void> _simulateHealthCheck(_HealthSession session) async {
    // Simulate a lightweight network operation
    // In real implementation, this could be:
    // - Sending a simple SSH command like 'echo test'
    // - TCP ping to the SSH port
    // - Checking if the SSH session is still responsive
    
    await Future.delayed(Duration(milliseconds: 50 + (session.currentMetrics.latencyMs * 0.1).round()));
    
    // Simulate occasional health check failures
    if (session.consecutiveHealthFailures > 2) {
      throw Exception('Connection appears to be unresponsive');
    }
  }

  SshConnectionQuality _calculateQuality(double latencyMs, bool isHealthy) {
    if (!isHealthy) return SshConnectionQuality.critical;
    
    if (latencyMs < 100) return SshConnectionQuality.excellent;
    if (latencyMs < 300) return SshConnectionQuality.good;
    if (latencyMs < 800) return SshConnectionQuality.fair;
    return SshConnectionQuality.poor;
  }

  void _emitHealthUpdate(String sessionId, SshHealthMetrics metrics) {
    if (!_healthController.isClosed) {
      _healthController.add(SshHealthUpdate(
        sessionId: sessionId,
        metrics: metrics,
        timestamp: DateTime.now(),
      ));
    }
  }
}

/// Health monitoring session for a specific SSH connection
class _HealthSession {
  final String sessionId;
  final Duration healthCheckInterval;
  final Duration timeoutThreshold;
  
  SshHealthMetrics currentMetrics;
  Timer? healthTimer;
  bool isDisposed = false;
  
  final List<SshConnectionError> _recentErrors = [];
  final List<DateTime> _recentSuccesses = [];
  int consecutiveHealthFailures = 0;

  _HealthSession({
    required this.sessionId,
    required this.healthCheckInterval,
    required this.timeoutThreshold,
  }) : currentMetrics = SshHealthMetrics.initial();

  void updateMetrics(SshHealthMetrics newMetrics) {
    if (isDisposed) return;
    currentMetrics = newMetrics;
  }

  void recordError(SshConnectionError error) {
    if (isDisposed) return;
    
    _recentErrors.add(error);
    consecutiveHealthFailures++;
    
    // Keep only recent errors (last 10)
    if (_recentErrors.length > 10) {
      _recentErrors.removeAt(0);
    }
  }

  void recordSuccess() {
    if (isDisposed) return;
    
    _recentSuccesses.add(DateTime.now());
    consecutiveHealthFailures = 0;
    
    // Keep only recent successes (last 10)
    if (_recentSuccesses.length > 10) {
      _recentSuccesses.removeAt(0);
    }
  }

  /// Check if there's been recent network connectivity
  bool get hasRecentNetworkConnectivity {
    if (_recentSuccesses.isEmpty) return false;
    
    final recentThreshold = DateTime.now().subtract(const Duration(minutes: 5));
    return _recentSuccesses.any((success) => success.isAfter(recentThreshold));
  }

  /// Get error rate in the last period
  double getErrorRate({Duration period = const Duration(minutes: 10)}) {
    final threshold = DateTime.now().subtract(period);
    final recentErrors = _recentErrors.where((error) => 
        error.timestamp.isAfter(threshold)).length;
    final recentSuccesses = _recentSuccesses.where((success) => 
        success.isAfter(threshold)).length;
    
    final total = recentErrors + recentSuccesses;
    return total > 0 ? recentErrors / total : 0.0;
  }

  void dispose() {
    isDisposed = true;
    healthTimer?.cancel();
    healthTimer = null;
  }
}

/// Health update event
@immutable
class SshHealthUpdate {
  final String sessionId;
  final SshHealthMetrics metrics;
  final DateTime timestamp;

  const SshHealthUpdate({
    required this.sessionId,
    required this.metrics,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'SshHealthUpdate(sessionId: $sessionId, quality: ${metrics.quality}, healthy: ${metrics.isHealthy})';
  }
}