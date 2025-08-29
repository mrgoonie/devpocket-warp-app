import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import '../services/ssh_connection_manager.dart';
import '../services/ssh_connection_models.dart';

/// SSH Connection status for terminal
enum SshTerminalConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

/// SSH Connection state for terminal
@immutable
class SshTerminalConnectionState {
  final SshTerminalConnectionStatus status;
  final SshProfile? profile;
  final String? sessionId;
  final String? error;
  final DateTime? lastConnectedAt;

  const SshTerminalConnectionState({
    this.status = SshTerminalConnectionStatus.disconnected,
    this.profile,
    this.sessionId,
    this.error,
    this.lastConnectedAt,
  });

  SshTerminalConnectionState copyWith({
    SshTerminalConnectionStatus? status,
    SshProfile? profile,
    String? sessionId,
    String? error,
    DateTime? lastConnectedAt,
  }) {
    return SshTerminalConnectionState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      sessionId: sessionId ?? this.sessionId,
      error: error ?? this.error,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  bool get isConnected => status == SshTerminalConnectionStatus.connected;
  bool get isConnecting => status == SshTerminalConnectionStatus.connecting || 
                          status == SshTerminalConnectionStatus.reconnecting;
  bool get hasError => status == SshTerminalConnectionStatus.error && error != null;
  bool get canConnect => status == SshTerminalConnectionStatus.disconnected || 
                        status == SshTerminalConnectionStatus.error;
}

/// SSH Connection state notifier for terminal
class SshTerminalConnectionNotifier extends StateNotifier<SshTerminalConnectionState> {
  SshTerminalConnectionNotifier() : super(const SshTerminalConnectionState()) {
    // Listen to SSH connection manager events
    _setupEventListeners();
  }

  final SshConnectionManager _connectionManager = SshConnectionManager.instance;

  void _setupEventListeners() {
    _connectionManager.events.listen(_handleConnectionEvent);
  }

  void _handleConnectionEvent(SshConnectionEvent event) {
    switch (event.type) {
      case SshConnectionEventType.statusChanged:
        if (event.status != null) {
          _updateStatus(_mapConnectionStatus(event.status!));
        }
        break;
      case SshConnectionEventType.error:
        state = state.copyWith(
          status: SshTerminalConnectionStatus.error,
          error: event.error,
        );
        break;
      case SshConnectionEventType.closed:
        state = state.copyWith(
          status: SshTerminalConnectionStatus.disconnected,
          sessionId: null,
          error: null,
        );
        break;
      default:
        break;
    }
  }

  SshTerminalConnectionStatus _mapConnectionStatus(SshConnectionStatus status) {
    switch (status) {
      case SshConnectionStatus.disconnected:
        return SshTerminalConnectionStatus.disconnected;
      case SshConnectionStatus.connecting:
        return SshTerminalConnectionStatus.connecting;
      case SshConnectionStatus.connected:
        return SshTerminalConnectionStatus.connected;
      case SshConnectionStatus.reconnecting:
        return SshTerminalConnectionStatus.reconnecting;
      case SshConnectionStatus.failed:
        return SshTerminalConnectionStatus.error;
      case SshConnectionStatus.authenticating:
        return SshTerminalConnectionStatus.connecting;
    }
  }

  void _updateStatus(SshTerminalConnectionStatus status) {
    state = state.copyWith(
      status: status,
      lastConnectedAt: status == SshTerminalConnectionStatus.connected 
          ? DateTime.now() 
          : state.lastConnectedAt,
      error: status == SshTerminalConnectionStatus.connected ? null : state.error,
    );
  }

  /// Connect to SSH host
  Future<void> connect(SshProfile profile) async {
    if (state.isConnecting) {
      debugPrint('SSH connection already in progress');
      return;
    }

    state = state.copyWith(
      status: SshTerminalConnectionStatus.connecting,
      profile: profile,
      error: null,
    );

    try {
      final sessionId = await _connectionManager.connect(profile);
      state = state.copyWith(
        status: SshTerminalConnectionStatus.connected,
        sessionId: sessionId,
        lastConnectedAt: DateTime.now(),
      );
      debugPrint('SSH connection established: $sessionId');
    } catch (e) {
      debugPrint('SSH connection failed: $e');
      state = state.copyWith(
        status: SshTerminalConnectionStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Disconnect from SSH host
  Future<void> disconnect() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    try {
      await _connectionManager.disconnect(sessionId);
      state = state.copyWith(
        status: SshTerminalConnectionStatus.disconnected,
        sessionId: null,
        error: null,
      );
    } catch (e) {
      debugPrint('SSH disconnect error: $e');
      // Still mark as disconnected even if disconnect failed
      state = state.copyWith(
        status: SshTerminalConnectionStatus.disconnected,
        sessionId: null,
        error: 'Disconnect error: $e',
      );
    }
  }

  /// Reconnect to SSH host
  Future<void> reconnect() async {
    final profile = state.profile;
    if (profile == null) return;

    await disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    await connect(profile);
  }

  /// Send command to SSH session
  Future<void> sendCommand(String command) async {
    final sessionId = state.sessionId;
    if (sessionId == null || !state.isConnected) {
      throw Exception('No active SSH connection');
    }

    try {
      await _connectionManager.sendCommand(sessionId, command);
    } catch (e) {
      debugPrint('Send command error: $e');
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
      state = state.copyWith(
        status: SshTerminalConnectionStatus.disconnected,
        error: null,
      );
    }
  }

  @override
  void dispose() {
    // Cleanup SSH connections
    if (state.sessionId != null) {
      _connectionManager.disconnect(state.sessionId!);
    }
    super.dispose();
  }
}

/// SSH Terminal output buffer notifier
class SshTerminalOutputNotifier extends StateNotifier<String> {
  SshTerminalOutputNotifier() : super('') {
    _setupEventListeners();
  }

  final SshConnectionManager _connectionManager = SshConnectionManager.instance;

  void _setupEventListeners() {
    _connectionManager.events.listen(_handleConnectionEvent);
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
}

// Providers
final sshTerminalConnectionProvider = StateNotifierProvider<SshTerminalConnectionNotifier, SshTerminalConnectionState>((ref) {
  return SshTerminalConnectionNotifier();
});

final sshTerminalOutputProvider = StateNotifierProvider<SshTerminalOutputNotifier, String>((ref) {
  return SshTerminalOutputNotifier();
});

/// Convenience providers
final sshConnectionStatusProvider = Provider<SshTerminalConnectionStatus>((ref) {
  return ref.watch(sshTerminalConnectionProvider).status;
});

final sshConnectionErrorProvider = Provider<String?>((ref) {
  return ref.watch(sshTerminalConnectionProvider).error;
});

final sshConnectedProfileProvider = Provider<SshProfile?>((ref) {
  return ref.watch(sshTerminalConnectionProvider).profile;
});

final isConnectedToSshProvider = Provider<bool>((ref) {
  return ref.watch(sshTerminalConnectionProvider).isConnected;
});

final canConnectSshProvider = Provider<bool>((ref) {
  return ref.watch(sshTerminalConnectionProvider).canConnect;
});

final hasActiveSshSessionProvider = Provider<bool>((ref) {
  final connectionState = ref.watch(sshTerminalConnectionProvider);
  return connectionState.sessionId != null && connectionState.isConnected;
});