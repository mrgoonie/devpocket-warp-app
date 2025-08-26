import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import '../models/ssh_connection_error.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_health_monitor.dart';
import '../services/network_monitor.dart';

/// Enhanced SSH Connection status for terminal with comprehensive states
enum EnhancedSshConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
  retrying,
}

/// Enhanced SSH Connection state with comprehensive error handling and health monitoring
@immutable
class EnhancedSshConnectionState {
  final EnhancedSshConnectionStatus status;
  final SshProfile? profile;
  final String? sessionId;
  final SshConnectionError? connectionError;
  final SshHealthMetrics? healthMetrics;
  final SshConnectionStep? currentStep;
  final double? connectionProgress;
  final int retryCount;
  final DateTime? nextRetryAt;
  final bool isAutoRetrying;
  final DateTime? lastConnectedAt;
  final DateTime? lastHealthCheck;

  const EnhancedSshConnectionState({
    this.status = EnhancedSshConnectionStatus.disconnected,
    this.profile,
    this.sessionId,
    this.connectionError,
    this.healthMetrics,
    this.currentStep,
    this.connectionProgress,
    this.retryCount = 0,
    this.nextRetryAt,
    this.isAutoRetrying = false,
    this.lastConnectedAt,
    this.lastHealthCheck,
  });

  EnhancedSshConnectionState copyWith({
    EnhancedSshConnectionStatus? status,
    SshProfile? profile,
    String? sessionId,
    SshConnectionError? connectionError,
    SshHealthMetrics? healthMetrics,
    SshConnectionStep? currentStep,
    double? connectionProgress,
    int? retryCount,
    DateTime? nextRetryAt,
    bool? isAutoRetrying,
    DateTime? lastConnectedAt,
    DateTime? lastHealthCheck,
  }) {
    return EnhancedSshConnectionState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      sessionId: sessionId ?? this.sessionId,
      connectionError: connectionError ?? this.connectionError,
      healthMetrics: healthMetrics ?? this.healthMetrics,
      currentStep: currentStep ?? this.currentStep,
      connectionProgress: connectionProgress ?? this.connectionProgress,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      isAutoRetrying: isAutoRetrying ?? this.isAutoRetrying,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
    );
  }

  // Computed properties
  bool get isConnected => status == EnhancedSshConnectionStatus.connected;
  bool get isConnecting => status == EnhancedSshConnectionStatus.connecting || 
                          status == EnhancedSshConnectionStatus.reconnecting ||
                          status == EnhancedSshConnectionStatus.retrying;
  bool get hasError => status == EnhancedSshConnectionStatus.error && connectionError != null;
  bool get canConnect => status == EnhancedSshConnectionStatus.disconnected || 
                        (status == EnhancedSshConnectionStatus.error && !isAutoRetrying);
  bool get isHealthy => healthMetrics?.isHealthy ?? false;
  bool get shouldShowRetry => hasError && connectionError?.isRetryable == true;
  bool get canRetry => shouldShowRetry && !isAutoRetrying;
  
  /// Get user-friendly status description
  String get statusDescription {
    switch (status) {
      case EnhancedSshConnectionStatus.disconnected:
        return 'Disconnected';
      case EnhancedSshConnectionStatus.connecting:
        return currentStep?.description ?? 'Connecting...';
      case EnhancedSshConnectionStatus.connected:
        return 'Connected';
      case EnhancedSshConnectionStatus.error:
        return 'Connection failed';
      case EnhancedSshConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case EnhancedSshConnectionStatus.retrying:
        return isAutoRetrying ? 'Retrying automatically...' : 'Retrying...';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedSshConnectionState &&
        other.status == status &&
        other.sessionId == sessionId &&
        other.retryCount == retryCount &&
        other.isAutoRetrying == isAutoRetrying;
  }

  @override
  int get hashCode {
    return Object.hash(status, sessionId, retryCount, isAutoRetrying);
  }
}

/// Enhanced SSH Connection notifier with comprehensive error handling and retry logic
class EnhancedSshConnectionNotifier extends StateNotifier<EnhancedSshConnectionState> {
  EnhancedSshConnectionNotifier() : super(const EnhancedSshConnectionState()) {
    _initialize();
  }

  final SshConnectionManager _connectionManager = SshConnectionManager.instance;
  final SshHealthMonitor _healthMonitor = SshHealthMonitor.instance;
  final NetworkMonitor _networkMonitor = NetworkMonitor.instance;
  
  Timer? _retryTimer;
  StreamSubscription<SshConnectionEvent>? _connectionSubscription;
  StreamSubscription<SshHealthUpdate>? _healthSubscription;
  StreamSubscription<NetworkState>? _networkSubscription;
  
  static const int _maxRetryAttempts = 3;
  static const Duration _baseRetryDelay = Duration(seconds: 5);

  void _initialize() {
    _setupEventListeners();
    _setupHealthMonitoring();
    _setupNetworkMonitoring();
  }

  void _setupEventListeners() {
    _connectionSubscription = _connectionManager.events.listen(_handleConnectionEvent);
  }
  
  void _setupHealthMonitoring() {
    _healthSubscription = _healthMonitor.healthUpdates.listen(_handleHealthUpdate);
  }
  
  void _setupNetworkMonitoring() {
    _networkSubscription = _networkMonitor.networkStateStream.listen(_handleNetworkStateChange);
  }

  void _handleConnectionEvent(SshConnectionEvent event) {
    switch (event.type) {
      case SshConnectionEventType.statusChanged:
        if (event.status != null) {
          _updateConnectionStatus(event.status!);
        }
        break;
      case SshConnectionEventType.error:
        final error = SshConnectionError.fromException(
          Exception(event.error ?? 'Unknown connection error'),
          debugInfo: {
            'sessionId': state.sessionId,
            'eventType': event.type.toString(),
          },
        );
        _handleConnectionError(error);
        break;
      case SshConnectionEventType.closed:
        _handleConnectionClosed();
        break;
      default:
        break;
    }
  }
  
  void _handleHealthUpdate(SshHealthUpdate update) {
    if (update.sessionId == state.sessionId) {
      state = state.copyWith(
        healthMetrics: update.metrics,
        lastHealthCheck: update.timestamp,
      );
      
      // Check if we should trigger auto-reconnect based on health
      if (_shouldAutoReconnect()) {
        _scheduleAutoReconnect();
      }
    }
  }
  
  void _handleNetworkStateChange(NetworkState networkState) {
    // Handle network restoration for auto-reconnect
    if (networkState.isConnected && state.hasError && state.connectionError?.shouldAutoRetry == true) {
      _scheduleAutoReconnect();
    }
  }

  void _updateConnectionStatus(SshConnectionStatus status) {
    final enhancedStatus = _mapConnectionStatus(status);
    final step = _mapConnectionStep(status);
    final progress = _calculateProgress(status);
    
    state = state.copyWith(
      status: enhancedStatus,
      currentStep: step,
      connectionProgress: progress,
      lastConnectedAt: enhancedStatus == EnhancedSshConnectionStatus.connected 
          ? DateTime.now() 
          : state.lastConnectedAt,
      connectionError: enhancedStatus == EnhancedSshConnectionStatus.connected ? null : state.connectionError,
      retryCount: enhancedStatus == EnhancedSshConnectionStatus.connected ? 0 : state.retryCount,
      isAutoRetrying: false,
    );
    
    // Start health monitoring when connected
    if (enhancedStatus == EnhancedSshConnectionStatus.connected && state.sessionId != null) {
      _healthMonitor.startMonitoring(state.sessionId!);
      _healthMonitor.recordConnectionSuccess(state.sessionId!);
    }
  }
  
  EnhancedSshConnectionStatus _mapConnectionStatus(SshConnectionStatus status) {
    switch (status) {
      case SshConnectionStatus.disconnected:
        return EnhancedSshConnectionStatus.disconnected;
      case SshConnectionStatus.connecting:
        return EnhancedSshConnectionStatus.connecting;
      case SshConnectionStatus.connected:
        return EnhancedSshConnectionStatus.connected;
      case SshConnectionStatus.reconnecting:
        return EnhancedSshConnectionStatus.reconnecting;
      case SshConnectionStatus.failed:
        return EnhancedSshConnectionStatus.error;
      case SshConnectionStatus.authenticating:
        return EnhancedSshConnectionStatus.connecting;
    }
  }
  
  SshConnectionStep? _mapConnectionStep(SshConnectionStatus status) {
    switch (status) {
      case SshConnectionStatus.connecting:
        return SshConnectionStep.connecting;
      case SshConnectionStatus.authenticating:
        return SshConnectionStep.authenticating;
      case SshConnectionStatus.connected:
        return SshConnectionStep.connected;
      default:
        return null;
    }
  }
  
  double? _calculateProgress(SshConnectionStatus status) {
    switch (status) {
      case SshConnectionStatus.connecting:
        return 0.25;
      case SshConnectionStatus.authenticating:
        return 0.75;
      case SshConnectionStatus.connected:
        return 1.0;
      default:
        return null;
    }
  }

  void _handleConnectionError(SshConnectionError error) {
    // Record error in health monitor
    if (state.sessionId != null) {
      _healthMonitor.recordConnectionError(state.sessionId!, error);
    }
    
    state = state.copyWith(
      status: EnhancedSshConnectionStatus.error,
      connectionError: error,
      currentStep: null,
      connectionProgress: null,
      isAutoRetrying: false,
    );
    
    // Schedule retry if appropriate
    if (error.shouldAutoRetry && state.retryCount < _maxRetryAttempts) {
      _scheduleAutoReconnect();
    }
  }
  
  void _handleConnectionClosed() {
    // Stop health monitoring
    if (state.sessionId != null) {
      _healthMonitor.stopMonitoring(state.sessionId!);
    }
    
    state = state.copyWith(
      status: EnhancedSshConnectionStatus.disconnected,
      sessionId: null,
      connectionError: null,
      currentStep: null,
      connectionProgress: null,
      healthMetrics: null,
      isAutoRetrying: false,
    );
  }

  // Public methods

  /// Connect to SSH host with enhanced error handling
  Future<void> connect(SshProfile profile, {bool isRetry = false}) async {
    if (state.isConnecting) {
      debugPrint('SSH connection already in progress');
      return;
    }

    // Cancel any pending retry
    _cancelRetry();
    
    // Check network connectivity first
    if (!_networkMonitor.hasConnectivity) {
      final networkError = SshConnectionError.create(
        SshErrorType.networkUnreachable,
        debugInfo: {'profile': profile.name},
      );
      _handleConnectionError(networkError);
      return;
    }

    final currentRetryCount = isRetry ? state.retryCount + 1 : 0;
    
    state = state.copyWith(
      status: isRetry ? EnhancedSshConnectionStatus.retrying : EnhancedSshConnectionStatus.connecting,
      profile: profile,
      connectionError: null,
      currentStep: SshConnectionStep.initializing,
      connectionProgress: 0.0,
      retryCount: currentRetryCount,
      isAutoRetrying: isRetry,
    );

    try {
      final sessionId = await _connectionManager.connect(profile);
      state = state.copyWith(
        status: EnhancedSshConnectionStatus.connected,
        sessionId: sessionId,
        lastConnectedAt: DateTime.now(),
        currentStep: SshConnectionStep.connected,
        connectionProgress: 1.0,
        retryCount: 0,
        isAutoRetrying: false,
      );
      debugPrint('SSH connection established: $sessionId');
      
      // Start health monitoring
      _healthMonitor.startMonitoring(sessionId);
      
    } catch (e) {
      debugPrint('SSH connection failed: $e');
      final error = SshConnectionError.fromException(
        e is Exception ? e : Exception(e.toString()),
        debugInfo: {
          'profile': profile.name,
          'retryCount': currentRetryCount,
          'isRetry': isRetry,
        },
      );
      _handleConnectionError(error);
    }
  }

  /// Disconnect from SSH host
  Future<void> disconnect() async {
    final sessionId = state.sessionId;
    
    // Cancel any pending retry
    _cancelRetry();
    
    // Stop health monitoring
    if (sessionId != null) {
      _healthMonitor.stopMonitoring(sessionId);
    }

    if (sessionId == null) {
      state = state.copyWith(
        status: EnhancedSshConnectionStatus.disconnected,
        connectionError: null,
        currentStep: null,
        connectionProgress: null,
        healthMetrics: null,
        retryCount: 0,
        isAutoRetrying: false,
      );
      return;
    }

    try {
      await _connectionManager.disconnect(sessionId);
      _handleConnectionClosed();
    } catch (e) {
      debugPrint('SSH disconnect error: $e');
      // Still mark as disconnected even if disconnect failed
      _handleConnectionClosed();
    }
  }

  /// Reconnect to SSH host
  Future<void> reconnect() async {
    final profile = state.profile;
    if (profile == null) return;

    state = state.copyWith(status: EnhancedSshConnectionStatus.reconnecting);
    
    await disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect(profile, isRetry: true);
  }
  
  /// Manual retry connection
  Future<void> retry() async {
    final profile = state.profile;
    if (profile == null || !state.canRetry) return;
    
    await connect(profile, isRetry: true);
  }

  /// Send command to SSH session
  Future<void> sendCommand(String command) async {
    final sessionId = state.sessionId;
    if (sessionId == null || !state.isConnected) {
      throw Exception('No active SSH connection');
    }

    try {
      final startTime = DateTime.now();
      await _connectionManager.sendCommand(sessionId, command);
      
      // Record successful command execution for health metrics
      final endTime = DateTime.now();
      final latency = endTime.difference(startTime).inMilliseconds.toDouble();
      _healthMonitor.updateHealthMetrics(sessionId, latencyMs: latency, isHealthy: true);
      
    } catch (e) {
      debugPrint('Send command error: $e');
      
      // Record command failure for health metrics
      _healthMonitor.updateHealthMetrics(sessionId, isHealthy: false);
      rethrow;
    }
  }

  /// Send raw data to SSH session
  Future<void> sendData(String data) async {
    final sessionId = state.sessionId;
    if (sessionId == null || !state.isConnected) {
      throw Exception('No active SSH connection');
    }

    try {
      await _connectionManager.sendData(sessionId, data);
    } catch (e) {
      debugPrint('Send data error: $e');
      rethrow;
    }
  }

  /// Get SSH session output
  String getOutput() {
    final sessionId = state.sessionId;
    if (sessionId == null) return '';
    return _connectionManager.getOutput(sessionId);
  }

  /// Clear SSH session output
  void clearOutput() {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      _connectionManager.clearOutput(sessionId);
    }
  }

  /// Clear error state
  void clearError() {
    if (state.hasError) {
      _cancelRetry();
      state = state.copyWith(
        status: EnhancedSshConnectionStatus.disconnected,
        connectionError: null,
        retryCount: 0,
        isAutoRetrying: false,
        nextRetryAt: null,
      );
    }
  }

  /// Cancel any pending automatic retry
  void cancelRetry() {
    _cancelRetry();
  }

  // Private helper methods
  
  bool _shouldAutoReconnect() {
    return state.hasError && 
           state.connectionError?.shouldAutoRetry == true &&
           state.retryCount < _maxRetryAttempts &&
           _networkMonitor.hasConnectivity &&
           !state.isAutoRetrying;
  }
  
  void _scheduleAutoReconnect() {
    if (state.isAutoRetrying || _retryTimer?.isActive == true) return;
    
    final error = state.connectionError;
    if (error == null || !error.shouldAutoRetry) return;
    
    final retryDelay = _calculateRetryDelay(error, state.retryCount);
    final nextRetryAt = DateTime.now().add(retryDelay);
    
    state = state.copyWith(
      status: EnhancedSshConnectionStatus.retrying,
      isAutoRetrying: true,
      nextRetryAt: nextRetryAt,
    );
    
    debugPrint('Scheduling auto-reconnect in ${retryDelay.inSeconds} seconds (attempt ${state.retryCount + 1}/$_maxRetryAttempts)');
    
    _retryTimer = Timer(retryDelay, () {
      if (mounted && state.isAutoRetrying) {
        reconnect();
      }
    });
  }
  
  Duration _calculateRetryDelay(SshConnectionError error, int retryCount) {
    final baseDelay = error.retryAfterSeconds != null 
        ? Duration(seconds: error.retryAfterSeconds!) 
        : _baseRetryDelay;
    
    switch (error.retryStrategy) {
      case SshRetryStrategy.exponentialBackoff:
        // Exponential backoff: 5s, 10s, 20s
        final multiplier = (1 << retryCount).clamp(1, 4);
        return Duration(seconds: baseDelay.inSeconds * multiplier);
      case SshRetryStrategy.fixedDelay:
        return baseDelay;
      case SshRetryStrategy.waitForNetwork:
        // Wait for network, then short delay
        return _networkMonitor.hasConnectivity ? const Duration(seconds: 2) : baseDelay;
      case SshRetryStrategy.noRetry:
        return baseDelay;
    }
  }
  
  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (state.isAutoRetrying) {
      state = state.copyWith(
        status: state.hasError ? EnhancedSshConnectionStatus.error : state.status,
        isAutoRetrying: false,
        nextRetryAt: null,
      );
    }
  }

  @override
  void dispose() {
    // Cancel retry timer
    _cancelRetry();
    
    // Cleanup SSH connections and health monitoring
    if (state.sessionId != null) {
      _healthMonitor.stopMonitoring(state.sessionId!);
      _connectionManager.disconnect(state.sessionId!);
    }
    
    // Cancel subscriptions
    _connectionSubscription?.cancel();
    _healthSubscription?.cancel();
    _networkSubscription?.cancel();
    
    super.dispose();
  }
}

/// Enhanced SSH Terminal output buffer notifier
class EnhancedSshTerminalOutputNotifier extends StateNotifier<String> {
  EnhancedSshTerminalOutputNotifier() : super('') {
    _setupEventListeners();
  }

  final SshConnectionManager _connectionManager = SshConnectionManager.instance;
  StreamSubscription<SshConnectionEvent>? _outputSubscription;

  void _setupEventListeners() {
    _outputSubscription = _connectionManager.events.listen(_handleConnectionEvent);
  }

  void _handleConnectionEvent(SshConnectionEvent event) {
    if (event.type == SshConnectionEventType.dataReceived && event.data != null) {
      state += event.data!;
    }
  }

  /// Clear output buffer
  void clear() {
    state = '';
  }

  /// Append data to output
  void append(String data) {
    state += data;
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    super.dispose();
  }
}

// Enhanced Providers
final enhancedSshConnectionProvider = StateNotifierProvider<EnhancedSshConnectionNotifier, EnhancedSshConnectionState>((ref) {
  return EnhancedSshConnectionNotifier();
});

final enhancedSshOutputProvider = StateNotifierProvider<EnhancedSshTerminalOutputNotifier, String>((ref) {
  return EnhancedSshTerminalOutputNotifier();
});

// Convenience providers
final sshConnectionStatusEnhancedProvider = Provider<EnhancedSshConnectionStatus>((ref) {
  return ref.watch(enhancedSshConnectionProvider).status;
});

final sshConnectionErrorEnhancedProvider = Provider<SshConnectionError?>((ref) {
  return ref.watch(enhancedSshConnectionProvider).connectionError;
});

final sshHealthMetricsProvider = Provider<SshHealthMetrics?>((ref) {
  return ref.watch(enhancedSshConnectionProvider).healthMetrics;
});

final sshConnectionStepProvider = Provider<SshConnectionStep?>((ref) {
  return ref.watch(enhancedSshConnectionProvider).currentStep;
});

final sshConnectionProgressProvider = Provider<double?>((ref) {
  return ref.watch(enhancedSshConnectionProvider).connectionProgress;
});

final canRetrySshProvider = Provider<bool>((ref) {
  return ref.watch(enhancedSshConnectionProvider).canRetry;
});

final sshRetryInfoProvider = Provider<({int count, DateTime? nextAt, bool isActive})>((ref) {
  final state = ref.watch(enhancedSshConnectionProvider);
  return (
    count: state.retryCount,
    nextAt: state.nextRetryAt,
    isActive: state.isAutoRetrying,
  );
});

final isConnectedToSshEnhancedProvider = Provider<bool>((ref) {
  return ref.watch(enhancedSshConnectionProvider).isConnected;
});

final canConnectSshEnhancedProvider = Provider<bool>((ref) {
  return ref.watch(enhancedSshConnectionProvider).canConnect;
});

final sshConnectedProfileEnhancedProvider = Provider<SshProfile?>((ref) {
  return ref.watch(enhancedSshConnectionProvider).profile;
});

final hasActiveSshSessionEnhancedProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(enhancedSshConnectionProvider);
  return connectionState.sessionId != null && connectionState.isConnected;
});

// Network monitoring provider
final networkStateProvider = StreamProvider<NetworkState>((ref) {
  return NetworkMonitor.instance.networkStateStream;
});

final currentNetworkStateProvider = Provider<NetworkState>((ref) {
  return NetworkMonitor.instance.currentState;
});

final hasNetworkConnectivityProvider = Provider<bool>((ref) {
  return NetworkMonitor.instance.hasConnectivity;
});

final isNetworkGoodForSshProvider = Provider<bool>((ref) {
  return NetworkMonitor.instance.isGoodForSsh;
});