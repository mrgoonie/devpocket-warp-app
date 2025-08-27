import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ssh_profile_models.dart';
import '../models/enhanced_terminal_models.dart';
import '../widgets/terminal/terminal_block.dart';
import '../services/enhanced_terminal_session_manager.dart';
import '../services/persistent_process_detector.dart';
import 'enhanced_ssh_connection_providers.dart';
import 'terminal_session_provider.dart';

/// Enhanced SSH Terminal state combining SSH connection and terminal session
@immutable
class EnhancedSshTerminalState {
  final String? sessionId;
  final SshProfile? profile;
  final EnhancedSshConnectionState connectionState;
  final EnhancedTerminalSessionState terminalState;
  final List<TerminalBlockData> terminalBlocks;
  final String? activeInteractiveBlockId;
  final bool isFullscreenModalOpen;
  final String? currentCommand;
  final DateTime? lastActivity;

  const EnhancedSshTerminalState({
    this.sessionId,
    this.profile,
    required this.connectionState,
    required this.terminalState,
    this.terminalBlocks = const [],
    this.activeInteractiveBlockId,
    this.isFullscreenModalOpen = false,
    this.currentCommand,
    this.lastActivity,
  });

  EnhancedSshTerminalState copyWith({
    String? sessionId,
    SshProfile? profile,
    EnhancedSshConnectionState? connectionState,
    EnhancedTerminalSessionState? terminalState,
    List<TerminalBlockData>? terminalBlocks,
    String? activeInteractiveBlockId,
    bool? isFullscreenModalOpen,
    String? currentCommand,
    DateTime? lastActivity,
  }) {
    return EnhancedSshTerminalState(
      sessionId: sessionId ?? this.sessionId,
      profile: profile ?? this.profile,
      connectionState: connectionState ?? this.connectionState,
      terminalState: terminalState ?? this.terminalState,
      terminalBlocks: terminalBlocks ?? this.terminalBlocks,
      activeInteractiveBlockId: activeInteractiveBlockId ?? this.activeInteractiveBlockId,
      isFullscreenModalOpen: isFullscreenModalOpen ?? this.isFullscreenModalOpen,
      currentCommand: currentCommand ?? this.currentCommand,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  // Computed properties
  bool get isConnected => connectionState.isConnected && sessionId != null;
  bool get isConnecting => connectionState.isConnecting;
  bool get hasError => connectionState.hasError;
  bool get canConnect => connectionState.canConnect;
  bool get hasActiveInteraction => activeInteractiveBlockId != null;
  bool get hasRunningBlocks => terminalBlocks.any((block) => 
      block.status == TerminalBlockStatus.running);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedSshTerminalState &&
        other.sessionId == sessionId &&
        other.connectionState == connectionState &&
        other.terminalBlocks.length == terminalBlocks.length &&
        other.activeInteractiveBlockId == activeInteractiveBlockId &&
        other.isFullscreenModalOpen == isFullscreenModalOpen;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      connectionState,
      terminalBlocks.length,
      activeInteractiveBlockId,
      isFullscreenModalOpen,
    );
  }
}

/// Enhanced SSH Terminal Provider that bridges SSH connections with enhanced terminal
class EnhancedSshTerminalNotifier extends StateNotifier<EnhancedSshTerminalState> {
  EnhancedSshTerminalNotifier(this._sshConnectionNotifier, this._terminalSessionNotifier) 
      : super(EnhancedSshTerminalState(
          connectionState: _sshConnectionNotifier.state,
          terminalState: EnhancedTerminalSessionState(
            sessionId: '',
            lastActivity: DateTime.now(),
          ),
        )) {
    _initialize();
  }

  final EnhancedSshConnectionNotifier _sshConnectionNotifier;
  final TerminalSessionStateNotifier _terminalSessionNotifier;
  final EnhancedTerminalSessionManager _sessionManager = EnhancedTerminalSessionManager.instance;
  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  // final InteractiveCommandManager _interactiveManager = InteractiveCommandManager.instance; // Not used yet

  StreamSubscription<EnhancedSessionEvent>? _sessionEventSubscription;
  StreamSubscription<void>? _sshConnectionSubscription;
  StreamSubscription<void>? _terminalSessionSubscription;

  void _initialize() {
    _setupEventListeners();
    _syncInitialState();
  }

  void _setupEventListeners() {
    // Listen to SSH connection changes
    _sshConnectionSubscription = Stream.periodic(const Duration(milliseconds: 100))
        .listen((_) => _syncConnectionState());
    
    // Listen to terminal session changes
    _terminalSessionSubscription = Stream.periodic(const Duration(milliseconds: 100))
        .listen((_) => _syncTerminalState());

    // Listen to enhanced session events
    _sessionEventSubscription = _sessionManager.events.listen(_handleSessionEvent);
  }

  void _syncInitialState() {
    state = state.copyWith(
      connectionState: _sshConnectionNotifier.state,
      terminalState: _terminalSessionNotifier.state,
    );
  }

  void _syncConnectionState() {
    if (mounted) {
      final newConnectionState = _sshConnectionNotifier.state;
      if (newConnectionState != state.connectionState) {
        state = state.copyWith(
          connectionState: newConnectionState,
          profile: newConnectionState.profile,
        );
        
        // Handle SSH connection state changes
        _handleSshConnectionStateChange(newConnectionState);
      }
    }
  }

  void _syncTerminalState() {
    if (mounted) {
      final newTerminalState = _terminalSessionNotifier.state;
      if (newTerminalState != state.terminalState) {
        state = state.copyWith(terminalState: newTerminalState);
      }
    }
  }

  void _handleSshConnectionStateChange(EnhancedSshConnectionState connectionState) {
    switch (connectionState.status) {
      case EnhancedSshConnectionStatus.connected:
        _onSshConnected(connectionState.sessionId!, connectionState.profile!);
        break;
      case EnhancedSshConnectionStatus.disconnected:
        _onSshDisconnected();
        break;
      case EnhancedSshConnectionStatus.error:
        _onSshError(connectionState.connectionError);
        break;
      default:
        break;
    }
  }

  Future<void> _onSshConnected(String sshSessionId, SshProfile profile) async {
    try {
      debugPrint('SSH connected, creating enhanced terminal session');
      
      // Create enhanced terminal session for SSH connection
      final terminalSessionId = await _sessionManager.createEnhancedSshSession(profile);
      
      state = state.copyWith(
        sessionId: terminalSessionId,
        profile: profile,
        lastActivity: DateTime.now(),
      );
      
      debugPrint('Enhanced SSH terminal session created: $terminalSessionId');
      
    } catch (e) {
      debugPrint('Failed to create enhanced terminal session for SSH: $e');
    }
  }

  void _onSshDisconnected() {
    final sessionId = state.sessionId;
    if (sessionId != null) {
      _sessionManager.stopEnhancedSession(sessionId);
    }
    
    state = state.copyWith(
      sessionId: null,
      profile: null,
      terminalBlocks: [],
      activeInteractiveBlockId: null,
      isFullscreenModalOpen: false,
      currentCommand: null,
    );
  }

  void _onSshError(dynamic error) {
    debugPrint('SSH connection error in enhanced terminal: $error');
    // Error handling is managed by the SSH connection provider
  }

  void _handleSessionEvent(EnhancedSessionEvent event) {
    if (event.sessionId != state.sessionId) return;

    switch (event.type) {
      case EnhancedSessionEventType.commandExecuted:
        _updateTerminalBlocks();
        state = state.copyWith(
          currentCommand: event.command,
          lastActivity: event.timestamp,
        );
        break;
        
      case EnhancedSessionEventType.blockOutputUpdated:
        _updateTerminalBlocks();
        state = state.copyWith(lastActivity: event.timestamp);
        break;
        
      case EnhancedSessionEventType.blockCompleted:
        _updateTerminalBlocks();
        _handleBlockCompletion(event.blockId!);
        break;
        
      case EnhancedSessionEventType.interactiveCommandDetected:
        _handleInteractiveCommand(event.blockId!, event.command!);
        break;
        
      default:
        break;
    }
  }

  void _updateTerminalBlocks() {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    final session = _sessionManager.getEnhancedSession(sessionId);
    if (session != null) {
      state = state.copyWith(
        terminalBlocks: List.from(session.blocks),
        lastActivity: DateTime.now(),
      );
    }
  }

  void _handleBlockCompletion(String blockId) {
    // Check if this was an interactive block
    if (state.activeInteractiveBlockId == blockId) {
      state = state.copyWith(
        activeInteractiveBlockId: null,
        isFullscreenModalOpen: false,
      );
    }
  }

  void _handleInteractiveCommand(String blockId, String command) {
    final processInfo = _processDetector.detectProcessType(command);
    
    if (processInfo.requiresFullscreen) {
      state = state.copyWith(
        activeInteractiveBlockId: blockId,
        isFullscreenModalOpen: true,
      );
      
      // Interactive command detected - can be handled later
      debugPrint('Interactive command detected: $command in block $blockId');
    } else if (processInfo.isPersistent) {
      state = state.copyWith(
        activeInteractiveBlockId: blockId,
      );
    }
  }

  // Public methods for terminal operations

  /// Connect to SSH host with enhanced terminal integration
  Future<void> connectToSsh(SshProfile profile) async {
    try {
      await _sshConnectionNotifier.connect(profile);
    } catch (e) {
      debugPrint('Enhanced SSH terminal connection failed: $e');
      rethrow;
    }
  }

  /// Disconnect from SSH host
  Future<void> disconnectFromSsh() async {
    try {
      await _sshConnectionNotifier.disconnect();
    } catch (e) {
      debugPrint('Enhanced SSH terminal disconnect failed: $e');
      rethrow;
    }
  }

  /// Execute command in enhanced SSH terminal
  Future<String?> executeCommand(String command, {bool isAgentMode = false}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || !state.isConnected) {
      throw Exception('No active enhanced SSH terminal session');
    }

    try {
      // Send command to SSH connection
      _sshConnectionNotifier.sendCommand(command);
      
      // Execute command in enhanced terminal session
      final blockId = await _sessionManager.executeCommand(
        sessionId, 
        command, 
        isAgentMode: isAgentMode,
      );
      
      state = state.copyWith(
        currentCommand: command,
        lastActivity: DateTime.now(),
      );
      
      return blockId;
      
    } catch (e) {
      debugPrint('Enhanced terminal command execution failed: $e');
      rethrow;
    }
  }

  /// Send raw data to SSH session
  Future<void> sendData(String data) async {
    if (!state.isConnected) {
      throw Exception('No active SSH connection');
    }

    try {
      await _sshConnectionNotifier.sendData(data);
    } catch (e) {
      debugPrint('Enhanced terminal send data failed: $e');
      rethrow;
    }
  }

  /// Handle interactive block input
  Future<void> sendInteractiveInput(String blockId, String input) async {
    if (state.activeInteractiveBlockId != blockId) {
      throw Exception('Block is not currently interactive: $blockId');
    }

    try {
      // Send input to SSH connection directly for now
      await _sshConnectionNotifier.sendData(input);
    } catch (e) {
      debugPrint('Interactive input failed: $e');
      rethrow;
    }
  }

  /// Exit interactive mode
  void exitInteractiveMode() {
    final blockId = state.activeInteractiveBlockId;
    if (blockId != null) {
      // _interactiveManager.exitInteractiveSession(blockId); // Method not available yet
      
      state = state.copyWith(
        activeInteractiveBlockId: null,
        isFullscreenModalOpen: false,
      );
    }
  }

  /// Toggle fullscreen modal for interactive commands
  void toggleFullscreenModal() {
    if (state.activeInteractiveBlockId != null) {
      state = state.copyWith(
        isFullscreenModalOpen: !state.isFullscreenModalOpen,
      );
    }
  }

  /// Cancel running command
  Future<void> cancelCommand(String blockId) async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    try {
      // Send interrupt signal to SSH connection
      await _sshConnectionNotifier.sendData('\x03'); // Ctrl+C
      
      // Cancel block in session manager
      _sessionManager.cancelBlock(sessionId, blockId);
      
    } catch (e) {
      debugPrint('Cancel command failed: $e');
    }
  }

  /// Get current terminal output
  String getTerminalOutput() {
    return _sshConnectionNotifier.getOutput();
  }

  /// Clear terminal output
  void clearTerminalOutput() {
    _sshConnectionNotifier.clearOutput();
    
    final sessionId = state.sessionId;
    if (sessionId != null) {
      final session = _sessionManager.getEnhancedSession(sessionId);
      session?.blocks.clear();
      _updateTerminalBlocks();
    }
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'sessionId': state.sessionId,
      'isConnected': state.isConnected,
      'blocksCount': state.terminalBlocks.length,
      'runningBlocks': state.terminalBlocks.where((b) => 
          b.status == TerminalBlockStatus.running).length,
      'hasActiveInteraction': state.hasActiveInteraction,
      'isFullscreenModalOpen': state.isFullscreenModalOpen,
      'lastActivity': state.lastActivity?.toIso8601String(),
    };
  }

  @override
  void dispose() {
    // Cancel subscriptions
    _sessionEventSubscription?.cancel();
    _sshConnectionSubscription?.cancel();
    _terminalSessionSubscription?.cancel();
    
    // Cleanup session if active
    final sessionId = state.sessionId;
    if (sessionId != null) {
      _sessionManager.stopEnhancedSession(sessionId);
    }
    
    super.dispose();
  }
}

// Provider definitions
final enhancedSshTerminalProvider = StateNotifierProvider<EnhancedSshTerminalNotifier, EnhancedSshTerminalState>((ref) {
  final sshConnectionNotifier = ref.read(enhancedSshConnectionProvider.notifier);
  final terminalSessionNotifier = ref.read(terminalSessionStateProvider('default').notifier);
  
  return EnhancedSshTerminalNotifier(sshConnectionNotifier, terminalSessionNotifier);
});

// Convenience providers
final enhancedSshTerminalSessionIdProvider = Provider<String?>((ref) {
  return ref.watch(enhancedSshTerminalProvider).sessionId;
});

final enhancedSshTerminalBlocksProvider = Provider<List<TerminalBlockData>>((ref) {
  return ref.watch(enhancedSshTerminalProvider).terminalBlocks;
});

final enhancedSshTerminalConnectionStatusProvider = Provider<EnhancedSshConnectionStatus>((ref) {
  return ref.watch(enhancedSshTerminalProvider).connectionState.status;
});

final hasActiveEnhancedSshInteractionProvider = Provider<bool>((ref) {
  return ref.watch(enhancedSshTerminalProvider).hasActiveInteraction;
});

final isEnhancedSshFullscreenModalOpenProvider = Provider<bool>((ref) {
  return ref.watch(enhancedSshTerminalProvider).isFullscreenModalOpen;
});

final enhancedSshCurrentCommandProvider = Provider<String?>((ref) {
  return ref.watch(enhancedSshTerminalProvider).currentCommand;
});

final enhancedSshCanExecuteCommandProvider = Provider<bool>((ref) {
  final state = ref.watch(enhancedSshTerminalProvider);
  return state.isConnected && !state.hasActiveInteraction;
});

final enhancedSshTerminalStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.read(enhancedSshTerminalProvider.notifier).getSessionStats();
});