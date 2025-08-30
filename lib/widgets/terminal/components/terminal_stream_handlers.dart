import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../services/terminal_input_mode_service.dart';
import '../../../services/terminal_input_mode_models.dart';
import '../../../services/active_block_manager.dart';
import '../../../services/active_block_models.dart';
import '../../../services/pty_focus_manager.dart';
import '../../../services/ssh_connection_models.dart';

/// Manages all stream subscriptions for the SSH terminal widget
/// Extracted from ssh_terminal_widget.dart to handle stream lifecycle management
class TerminalStreamHandlers {
  // Stream subscriptions
  StreamSubscription<TerminalInputModeEvent>? _inputModeSubscription;
  StreamSubscription<ActiveBlockEvent>? _activeBlockSubscription;
  StreamSubscription<FocusEvent>? _focusSubscription;
  StreamSubscription<SshConnectionEvent>? _sshEventSubscription;
  
  // Service instances
  final TerminalInputModeService _inputModeService = TerminalInputModeService.instance;
  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final PTYFocusManager _focusManager = PTYFocusManager.instance;

  // Callbacks
  Function(TerminalInputModeEvent)? onInputModeChanged;
  Function(ActiveBlockEvent)? onActiveBlockEvent;
  Function(FocusEvent)? onFocusEvent;
  Function(SshConnectionEvent)? onSshConnectionEvent;
  
  /// Initialize all stream subscriptions
  void setupStreams({
    Function(TerminalInputModeEvent)? onInputModeChanged,
    Function(ActiveBlockEvent)? onActiveBlockEvent,
    Function(FocusEvent)? onFocusEvent,
    Function(SshConnectionEvent)? onSshConnectionEvent,
  }) {
    this.onInputModeChanged = onInputModeChanged;
    this.onActiveBlockEvent = onActiveBlockEvent;
    this.onFocusEvent = onFocusEvent;
    this.onSshConnectionEvent = onSshConnectionEvent;
    
    _setupInputModeStream();
    _setupActiveBlockStream();
    _setupFocusStream();
  }
  
  /// Setup input mode service stream
  void _setupInputModeStream() {
    _inputModeSubscription?.cancel();
    _inputModeSubscription = _inputModeService.modeStream.listen((event) {
      debugPrint('Input mode changed: ${event.mode}');
      onInputModeChanged?.call(event);
    }, onError: (error) {
      debugPrint('Input mode stream error: $error');
    });
  }
  
  /// Setup active block manager stream
  void _setupActiveBlockStream() {
    _activeBlockSubscription?.cancel();
    _activeBlockSubscription = _activeBlockManager.eventStream.listen((event) {
      debugPrint('Active block event: ${event.type} for block ${event.blockId}');
      onActiveBlockEvent?.call(event);
    }, onError: (error) {
      debugPrint('Active block stream error: $error');
    });
  }
  
  /// Setup PTY focus manager stream
  void _setupFocusStream() {
    _focusSubscription?.cancel();
    _focusSubscription = _focusManager.focusEventStream.listen((event) {
      debugPrint('Focus event: ${event.type} for block ${event.blockId}');
      onFocusEvent?.call(event);
    }, onError: (error) {
      debugPrint('Focus stream error: $error');
    });
  }
  
  /// Setup SSH connection event stream
  void setupSshEventStream(Stream<SshConnectionEvent> eventStream) {
    _sshEventSubscription?.cancel();
    _sshEventSubscription = eventStream.listen((event) {
      debugPrint('SSH connection event: ${event.type}');
      onSshConnectionEvent?.call(event);
    }, onError: (error) {
      debugPrint('SSH connection stream error: $error');
    });
  }
  
  /// Cancel all stream subscriptions
  void dispose() {
    _inputModeSubscription?.cancel();
    _activeBlockSubscription?.cancel();
    _focusSubscription?.cancel();
    _sshEventSubscription?.cancel();
    
    _inputModeSubscription = null;
    _activeBlockSubscription = null;
    _focusSubscription = null;
    _sshEventSubscription = null;
  }
  
  /// Check if all critical streams are properly set up
  bool get isInitialized => 
    _inputModeSubscription != null && 
    _activeBlockSubscription != null && 
    _focusSubscription != null;
    
  /// Get count of active subscriptions for debugging
  int get activeSubscriptionCount {
    int count = 0;
    if (_inputModeSubscription != null) count++;
    if (_activeBlockSubscription != null) count++;
    if (_focusSubscription != null) count++;
    if (_sshEventSubscription != null) count++;
    return count;
  }
}