import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../models/ssh_profile_models.dart';
import '../../../services/terminal_session_handler.dart';
import '../../../services/ssh_connection_manager.dart';
import '../../../services/ssh_connection_models.dart';
import '../../../services/terminal_session_models.dart';

/// Manages SSH and local terminal connections for the SSH terminal widget
/// Extracted from ssh_terminal_widget.dart to handle connection lifecycle
class TerminalConnectionManager {
  // Service instances
  final TerminalSessionHandler _sessionHandler = TerminalSessionHandler.instance;
  final SshConnectionManager _sshManager = SshConnectionManager.instance;
  
  // Connection state
  String? _currentSessionId;
  bool _isConnected = false;
  String _status = 'Initializing...';
  String _welcomeMessage = '';
  
  // Stream subscriptions
  StreamSubscription<TerminalOutput>? _outputSubscription;
  StreamSubscription<SshConnectionEvent>? _sshEventSubscription;
  
  // Callbacks
  Function(String)? onStatusChanged;
  Function(String)? onWelcomeMessage;
  Function(TerminalOutput)? onTerminalOutput;
  Function(SshConnectionEvent)? onSshEvent;
  Function(String)? onError;
  
  // Getters for state
  String? get currentSessionId => _currentSessionId;
  bool get isConnected => _isConnected;
  String get status => _status;
  String get welcomeMessage => _welcomeMessage;
  
  /// Initialize connection manager with callbacks
  void initialize({
    Function(String)? onStatusChanged,
    Function(String)? onWelcomeMessage,
    Function(TerminalOutput)? onTerminalOutput,
    Function(SshConnectionEvent)? onSshEvent,
    Function(String)? onError,
  }) {
    this.onStatusChanged = onStatusChanged;
    this.onWelcomeMessage = onWelcomeMessage;
    this.onTerminalOutput = onTerminalOutput;
    this.onSshEvent = onSshEvent;
    this.onError = onError;
  }
  
  /// Setup session based on profile or session ID
  Future<void> setupSession({
    SshProfile? profile,
    String? sessionId,
  }) async {
    try {
      if (sessionId != null) {
        await _useExistingSession(sessionId);
      } else if (profile != null) {
        await _createSshSession(profile);
      } else {
        await _createLocalSession();
      }
      
      _updateStatus('Connected');
      
      // Handle welcome message for SSH sessions
      if (profile != null && _currentSessionId != null) {
        _handleWelcomeMessage();
      }
      
    } catch (e) {
      final errorMsg = 'Failed to setup session: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
      _updateStatus('Connection failed');
      rethrow;
    }
  }
  
  /// Use existing session
  Future<void> _useExistingSession(String sessionId) async {
    _currentSessionId = sessionId;
    _isConnected = _sshManager.isConnected(sessionId);
    debugPrint('Using existing session: $sessionId, connected: $_isConnected');
  }
  
  /// Create new SSH session
  Future<void> _createSshSession(SshProfile profile) async {
    _updateStatus('Connecting to ${profile.connectionString}...');
    
    _currentSessionId = await _sshManager.connect(profile);
    _isConnected = true;
    
    // Setup SSH event listening
    _sshEventSubscription = _sshManager.events.listen(_handleSshEvent);
    
    debugPrint('Created SSH session: $_currentSessionId for ${profile.connectionString}');
  }
  
  /// Create local terminal session
  Future<void> _createLocalSession() async {
    _updateStatus('Starting local terminal...');
    
    _currentSessionId = await _sessionHandler.createLocalSession();
    _isConnected = true;
    
    // Listen to session handler output for local sessions
    _outputSubscription = _sessionHandler.output.listen(
      _handleTerminalOutput,
      onError: (error) {
        final errorMsg = 'Terminal error: $error';
        debugPrint(errorMsg);
        onError?.call(errorMsg);
      },
    );
    
    debugPrint('Created local session: $_currentSessionId');
  }
  
  /// Handle welcome message display with delay
  void _handleWelcomeMessage() {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (_currentSessionId != null) {
        final welcomeMsg = _sshManager.getWelcomeMessage(_currentSessionId!);
        if (welcomeMsg.isNotEmpty) {
          _welcomeMessage = welcomeMsg;
          debugPrint('Welcome message received: ${welcomeMsg.length} chars');
          onWelcomeMessage?.call(welcomeMsg);
        }
      }
    });
  }
  
  /// Handle SSH connection events
  void _handleSshEvent(SshConnectionEvent event) {
    debugPrint('SSH event: ${event.type} - ${event.status}');
    
    if (event.type == SshConnectionEventType.statusChanged) {
      switch (event.status) {
        case SshConnectionStatus.connected:
          _isConnected = true;
          _updateStatus('Connected');
          break;
        case SshConnectionStatus.disconnected:
          _isConnected = false;
          _updateStatus('Disconnected');
          break;
        case SshConnectionStatus.failed:
          _isConnected = false;
          _updateStatus('Connection failed');
          break;
        case SshConnectionStatus.connecting:
          _updateStatus('Connecting...');
          break;
        default:
          break;
      }
    }
    
    if (event.error != null) {
      debugPrint('SSH error: ${event.error}');
      onError?.call(event.error!);
    }
    
    onSshEvent?.call(event);
  }
  
  /// Handle terminal output
  void _handleTerminalOutput(TerminalOutput output) {
    debugPrint('Terminal output received: ${output.data.length} bytes');
    onTerminalOutput?.call(output);
  }
  
  /// Update status and notify callback
  void _updateStatus(String newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      debugPrint('Status changed: $newStatus');
      onStatusChanged?.call(newStatus);
    }
  }
  
  /// Disconnect current session
  Future<void> disconnect() async {
    try {
      if (_currentSessionId != null) {
        if (_sshManager.isConnected(_currentSessionId!)) {
          await _sshManager.disconnect(_currentSessionId!);
        }
        debugPrint('Disconnected session: $_currentSessionId');
      }
      
      _isConnected = false;
      _currentSessionId = null;
      _updateStatus('Disconnected');
      
    } catch (e) {
      debugPrint('Error during disconnect: $e');
      onError?.call('Disconnect error: $e');
    }
  }
  
  /// Send data to current session
  Future<bool> sendData(String data) async {
    if (!_isConnected || _currentSessionId == null) {
      debugPrint('Cannot send data: not connected or no session');
      return false;
    }
    
    try {
      if (_sshManager.isConnected(_currentSessionId!)) {
        await _sshManager.sendInput(_currentSessionId!, data);
        return true;
      } else {
        await _sessionHandler.sendInput(data);
        return true;
      }
    } catch (e) {
      debugPrint('Error sending data: $e');
      onError?.call('Send error: $e');
      return false;
    }
  }
  
  /// Check if session supports given operation
  bool supportsOperation(String operation) {
    if (!_isConnected || _currentSessionId == null) return false;
    
    switch (operation) {
      case 'resize':
      case 'send_input':
      case 'get_output':
        return true;
      case 'file_transfer':
        return _sshManager.isConnected(_currentSessionId!);
      default:
        return false;
    }
  }
  
  /// Cleanup resources
  void dispose() {
    _outputSubscription?.cancel();
    _sshEventSubscription?.cancel();
    
    _outputSubscription = null;
    _sshEventSubscription = null;
    
    debugPrint('TerminalConnectionManager disposed');
  }
}