import 'package:flutter/foundation.dart';

import '../../../services/active_block_models.dart';
import '../../../services/pty_focus_manager.dart';
import '../../../services/terminal_input_mode_models.dart';
import '../../../services/ssh_connection_models.dart';

/// Handles various terminal events and coordinates responses
/// Extracted from ssh_terminal_widget.dart to manage event processing
class TerminalEventHandler {
  // Callbacks for different event types
  Function(ActiveBlockEvent)? onActiveBlockEvent;
  Function(FocusEvent)? onFocusEvent;
  Function(TerminalInputModeEvent)? onInputModeChanged;
  Function(SshConnectionEvent)? onSshConnectionEvent;
  Function(String)? onError;
  Function()? onStateChanged;
  
  // Current session context
  String? _currentSessionId;
  bool _isMounted = true;
  
  /// Initialize event handler with callbacks
  void initialize({
    Function(ActiveBlockEvent)? onActiveBlockEvent,
    Function(FocusEvent)? onFocusEvent,
    Function(TerminalInputModeEvent)? onInputModeChanged,
    Function(SshConnectionEvent)? onSshConnectionEvent,
    Function(String)? onError,
    Function()? onStateChanged,
  }) {
    this.onActiveBlockEvent = onActiveBlockEvent;
    this.onFocusEvent = onFocusEvent;
    this.onInputModeChanged = onInputModeChanged;
    this.onSshConnectionEvent = onSshConnectionEvent;
    this.onError = onError;
    this.onStateChanged = onStateChanged;
  }
  
  /// Set current session context
  void setSessionContext({
    required String? sessionId,
    required bool isMounted,
  }) {
    _currentSessionId = sessionId;
    _isMounted = isMounted;
  }
  
  /// Handle active block manager events
  void handleActiveBlockEvent(ActiveBlockEvent event) {
    if (!_isMounted || event.sessionId != _currentSessionId) {
      debugPrint('Ignoring active block event for different session or unmounted widget');
      return;
    }
    
    debugPrint('Processing active block event: ${event.type} for block ${event.blockId}');
    
    switch (event.type) {
      case ActiveBlockEventType.created:
        _handleBlockCreated(event);
        break;
      case ActiveBlockEventType.updated:
        _handleBlockUpdated(event);
        break;
      case ActiveBlockEventType.completed:
        _handleBlockCompleted(event);
        break;
      case ActiveBlockEventType.failed:
        _handleBlockFailed(event);
        break;
      case ActiveBlockEventType.focused:
        _handleBlockFocused(event);
        break;
      case ActiveBlockEventType.unfocused:
        _handleBlockUnfocused(event);
        break;
    }
    
    onActiveBlockEvent?.call(event);
    onStateChanged?.call();
  }
  
  /// Handle focus manager events
  void handleFocusEvent(FocusEvent event) {
    if (!_isMounted) {
      debugPrint('Ignoring focus event for unmounted widget');
      return;
    }
    
    debugPrint('Processing focus event: ${event.type} for block ${event.blockId}');
    
    switch (event.type) {
      case FocusEventType.focused:
        _handleFocusGained(event);
        break;
      case FocusEventType.unfocused:
        _handleFocusLost(event);
        break;
      case FocusEventType.requestFocus:
        _handleFocusRequested(event);
        break;
      case FocusEventType.releaseFocus:
        _handleFocusReleased(event);
        break;
    }
    
    onFocusEvent?.call(event);
    onStateChanged?.call();
  }
  
  /// Handle input mode changes
  void handleInputModeChanged(TerminalInputModeEvent event) {
    if (!_isMounted) {
      debugPrint('Ignoring input mode change for unmounted widget');
      return;
    }
    
    debugPrint('Processing input mode change: ${event.mode}');
    
    switch (event.mode) {
      case TerminalInputMode.command:
        _handleCommandModeActivated(event);
        break;
      case TerminalInputMode.agent:
        _handleAgentModeActivated(event);
        break;
      case TerminalInputMode.terminal:
        _handleTerminalModeActivated(event);
        break;
    }
    
    onInputModeChanged?.call(event);
    onStateChanged?.call();
  }
  
  /// Handle SSH connection events
  void handleSshConnectionEvent(SshConnectionEvent event) {
    if (!_isMounted) {
      debugPrint('Ignoring SSH event for unmounted widget');
      return;
    }
    
    debugPrint('Processing SSH connection event: ${event.type}');
    
    switch (event.type) {
      case SshConnectionEventType.statusChanged:
        _handleStatusChanged(event);
        break;
      case SshConnectionEventType.dataReceived:
        _handleDataReceived(event);
        break;
      case SshConnectionEventType.error:
        _handleConnectionError(event);
        break;
      case SshConnectionEventType.closed:
        _handleConnectionClosed(event);
        break;
    }
    
    onSshConnectionEvent?.call(event);
    onStateChanged?.call();
  }
  
  // Private event handling methods
  
  void _handleBlockCreated(ActiveBlockEvent event) {
    debugPrint('Block created: ${event.blockId}');
    // Additional block creation logic can be added here
  }
  
  void _handleBlockUpdated(ActiveBlockEvent event) {
    debugPrint('Block updated: ${event.blockId}');
    // Additional block update logic can be added here
  }
  
  void _handleBlockCompleted(ActiveBlockEvent event) {
    debugPrint('Block completed: ${event.blockId}');
    // Additional block completion logic can be added here
  }
  
  void _handleBlockFailed(ActiveBlockEvent event) {
    debugPrint('Block failed: ${event.blockId}');
    // Additional block failure logic can be added here
  }
  
  void _handleBlockFocused(ActiveBlockEvent event) {
    debugPrint('Block focused: ${event.blockId}');
    // Additional focus handling logic can be added here
  }
  
  void _handleBlockUnfocused(ActiveBlockEvent event) {
    debugPrint('Block unfocused: ${event.blockId}');
    // Additional unfocus handling logic can be added here
  }
  
  void _handleFocusGained(FocusEvent event) {
    debugPrint('Focus gained: ${event.blockId}');
    // Additional focus gain logic can be added here
  }
  
  void _handleFocusLost(FocusEvent event) {
    debugPrint('Focus lost: ${event.blockId}');
    // Additional focus loss logic can be added here
  }
  
  void _handleFocusRequested(FocusEvent event) {
    debugPrint('Focus requested: ${event.blockId}');
    // Additional focus request logic can be added here
  }
  
  void _handleFocusReleased(FocusEvent event) {
    debugPrint('Focus released: ${event.blockId}');
    // Additional focus release logic can be added here
  }
  
  void _handleCommandModeActivated(TerminalInputModeEvent event) {
    debugPrint('Command mode activated');
    // Additional command mode logic can be added here
  }
  
  void _handleAgentModeActivated(TerminalInputModeEvent event) {
    debugPrint('Agent mode activated');
    // Additional agent mode logic can be added here
  }
  
  void _handleTerminalModeActivated(TerminalInputModeEvent event) {
    debugPrint('Terminal mode activated');
    // Additional terminal mode logic can be added here
  }
  
  void _handleStatusChanged(SshConnectionEvent event) {
    if (event.status != null) {
      debugPrint('SSH status changed: ${event.status}');
      // Additional status change logic can be added here
    }
  }
  
  void _handleDataReceived(SshConnectionEvent event) {
    if (event.data != null) {
      debugPrint('SSH data received: ${event.data!.length} bytes');
      // Additional data handling logic can be added here
    }
  }
  
  void _handleConnectionError(SshConnectionEvent event) {
    if (event.error != null) {
      final errorMsg = 'SSH connection error: ${event.error}';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  void _handleConnectionClosed(SshConnectionEvent event) {
    debugPrint('SSH connection closed');
    // Additional connection close logic can be added here
  }
  
  /// Get event handler statistics
  Map<String, dynamic> getStats() {
    return {
      'currentSessionId': _currentSessionId,
      'isMounted': _isMounted,
      'hasActiveBlockCallback': onActiveBlockEvent != null,
      'hasFocusCallback': onFocusEvent != null,
      'hasInputModeCallback': onInputModeChanged != null,
      'hasSshConnectionCallback': onSshConnectionEvent != null,
      'hasErrorCallback': onError != null,
      'hasStateChangeCallback': onStateChanged != null,
    };
  }
  
  /// Reset event handler state
  void reset() {
    _currentSessionId = null;
    _isMounted = false;
    debugPrint('TerminalEventHandler reset');
  }
  
  /// Cleanup resources
  void dispose() {
    reset();
    debugPrint('TerminalEventHandler disposed');
  }
}