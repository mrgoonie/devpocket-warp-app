import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import '../models/ssh_profile_models.dart';

/// SSH Connection status
enum SshConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
  authenticating,
}

/// SSH connection event types
enum SshConnectionEventType {
  statusChanged,
  dataReceived,
  dataSent,
  error,
  closed,
}

/// SSH connection event
class SshConnectionEvent {
  final SshConnectionEventType type;
  final String? data;
  final String? error;
  final SshConnectionStatus? status;
  final DateTime timestamp;

  const SshConnectionEvent({
    required this.type,
    this.data,
    this.error,
    this.status,
    required this.timestamp,
  });
}

/// SSH Connection Manager for handling SSH connections and terminal sessions
class SshConnectionManager {
  static SshConnectionManager? _instance;
  static SshConnectionManager get instance => _instance ??= SshConnectionManager._();

  SshConnectionManager._();

  final Map<String, _ConnectionSession> _connections = {};
  final StreamController<SshConnectionEvent> _eventController = StreamController.broadcast();

  /// Stream of connection events
  Stream<SshConnectionEvent> get events => _eventController.stream;

  /// Connect to SSH host
  Future<String> connect(SshProfile profile) async {
    final sessionId = profile.id;
    
    debugPrint('Connecting to SSH host: ${profile.connectionString}');
    
    try {
      // Close existing connection if any
      await disconnect(sessionId);
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.connecting,
        timestamp: DateTime.now(),
      ));
      
      // Create SSH socket connection
      final socket = await SSHSocket.connect(profile.host, profile.port);
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.authenticating,
        timestamp: DateTime.now(),
      ));
      
      // Create SSH client with authentication
      late SSHClient client;
      
      switch (profile.authType) {
        case SshAuthType.password:
          client = SSHClient(
            socket,
            username: profile.username,
            onPasswordRequest: () => profile.password ?? '',
          );
          break;
          
        case SshAuthType.key:
          final keyPair = await _parsePrivateKey(
            profile.privateKey!,
            profile.passphrase,
          );
          
          if (keyPair == null) {
            throw Exception('Invalid private key format');
          }
          
          client = SSHClient(
            socket,
            username: profile.username,
            identities: [keyPair],
          );
          break;
      }
      
      // Create terminal session with PTY support for interactive commands
      final shell = await client.shell();
      
      // Create connection session
      final session = _ConnectionSession(
        id: sessionId,
        profile: profile,
        client: client,
        shell: shell,
        status: SshConnectionStatus.connected,
      );
      
      // Set up shell data handlers with enhanced stream processing
      shell.stdout.cast<List<int>>().transform(utf8.decoder).listen(
        (data) {
          // Write to overall buffer for backward compatibility
          session.outputBuffer.write(data);
          
          // Enhanced welcome message detection with timeout mechanism
          if (!session.welcomeMessageShown) {
            session.welcomeBuffer.write(data);
            
            // Start welcome message timeout if not already started
            if (session.welcomeTimeout == null) {
              session.welcomeTimeout = Timer(const Duration(seconds: 3), () {
                session.markWelcomeShown();
              });
            }
          } else {
            // This is command output after welcome period
            session.commandBuffer.write(data);
          }
          
          _emitEvent(SshConnectionEvent(
            type: SshConnectionEventType.dataReceived,
            data: data,
            timestamp: DateTime.now(),
          ));
        },
        onError: (error) {
          debugPrint('SSH shell stdout error: $error');
          _emitEvent(SshConnectionEvent(
            type: SshConnectionEventType.error,
            error: error.toString(),
            timestamp: DateTime.now(),
          ));
        },
      );
      
      shell.stderr.cast<List<int>>().transform(utf8.decoder).listen(
        (data) {
          // Write to overall buffer for backward compatibility
          session.outputBuffer.write(data);
          
          // Stderr always goes to command buffer
          session.commandBuffer.write(data);
          
          _emitEvent(SshConnectionEvent(
            type: SshConnectionEventType.dataReceived,
            data: data,
            timestamp: DateTime.now(),
          ));
        },
        onError: (error) {
          debugPrint('SSH shell stderr error: $error');
          _emitEvent(SshConnectionEvent(
            type: SshConnectionEventType.error,
            error: error.toString(),
            timestamp: DateTime.now(),
          ));
        },
      );
      
      _connections[sessionId] = session;
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.connected,
        timestamp: DateTime.now(),
      ));
      
      debugPrint('SSH connection established: $sessionId');
      return sessionId;
      
    } on SocketException catch (e) {
      debugPrint('SSH socket error: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Network error: ${e.message}',
        timestamp: DateTime.now(),
      ));
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.failed,
        timestamp: DateTime.now(),
      ));
      throw Exception('Connection failed: ${e.message}');
      
    } on Exception catch (e) {
      // Check if it's an authentication-related error by message content
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('auth') || errorMessage.contains('password') || errorMessage.contains('key')) {
        debugPrint('SSH authentication error: $e');
        _emitEvent(SshConnectionEvent(
          type: SshConnectionEventType.error,
          error: 'Authentication failed: $e',
          timestamp: DateTime.now(),
        ));
        _emitEvent(SshConnectionEvent(
          type: SshConnectionEventType.statusChanged,
          status: SshConnectionStatus.failed,
          timestamp: DateTime.now(),
        ));
        throw Exception('Authentication failed: $e');
      } else {
        // Re-throw non-auth exceptions to be caught by the generic handler
        rethrow;
      }
      
    } catch (e) {
      debugPrint('SSH connection error: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Connection failed: $e',
        timestamp: DateTime.now(),
      ));
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.failed,
        timestamp: DateTime.now(),
      ));
      throw Exception('Connection failed: $e');
    }
  }
  
  /// Disconnect from SSH host with proper resource cleanup
  Future<void> disconnect(String sessionId) async {
    final session = _connections[sessionId];
    if (session == null) return;
    
    debugPrint('Disconnecting SSH session: $sessionId');
    
    try {
      session.dispose();
      _connections.remove(sessionId);
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.disconnected,
        timestamp: DateTime.now(),
      ));
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.closed,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error disconnecting SSH session: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Disconnect error: $e',
        timestamp: DateTime.now(),
      ));
    }
  }
  
  /// Send command to SSH session with enhanced command tracking
  Future<void> sendCommand(String sessionId, String command) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No active SSH session found: $sessionId');
    }
    
    if (session.status != SshConnectionStatus.connected) {
      throw Exception('SSH session not connected: $sessionId');
    }
    
    try {
      debugPrint('Sending command: $command');
      
      // Clear command buffer before sending new command to avoid mixing outputs
      session.clearCommandOutput();
      
      // Set the current command for tracking
      session.setCurrentCommand(command);
      
      // Mark welcome message as shown after first command and cancel timeout
      if (!session.welcomeMessageShown) {
        session.markWelcomeShown();
      }
      
      session.shell!.stdin.add(utf8.encode('$command\n'));
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.dataSent,
        data: command,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error sending command: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Send command error: $e',
        timestamp: DateTime.now(),
      ));
      throw Exception('Send command failed: $e');
    }
  }
  
  /// Send raw data to SSH session
  Future<void> sendData(String sessionId, String data) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No active SSH session found: $sessionId');
    }
    
    if (session.status != SshConnectionStatus.connected) {
      throw Exception('SSH session not connected: $sessionId');
    }
    
    try {
      session.shell!.stdin.add(utf8.encode(data));
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.dataSent,
        data: data,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error sending data: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Send data error: $e',
        timestamp: DateTime.now(),
      ));
      throw Exception('Send data failed: $e');
    }
  }
  
  /// Get connection status
  SshConnectionStatus getStatus(String sessionId) {
    final session = _connections[sessionId];
    return session?.status ?? SshConnectionStatus.disconnected;
  }
  
  /// Check if session is connected
  bool isConnected(String sessionId) {
    return getStatus(sessionId) == SshConnectionStatus.connected;
  }
  
  /// Get session output buffer
  String getOutput(String sessionId) {
    final session = _connections[sessionId];
    return session?.outputBuffer.toString() ?? '';
  }
  
  /// Clear output buffer
  void clearOutput(String sessionId) {
    final session = _connections[sessionId];
    session?.outputBuffer.clear();
  }
  
  /// Clear command-specific output buffer
  void clearCommandOutput(String sessionId) {
    final session = _connections[sessionId];
    session?.clearCommandOutput();
  }
  
  /// Get command output without welcome messages
  String getCommandOutput(String sessionId) {
    final session = _connections[sessionId];
    return session?.getCommandOutput() ?? '';
  }
  
  /// Get welcome message
  String getWelcomeMessage(String sessionId) {
    final session = _connections[sessionId];
    return session?.getWelcomeMessage() ?? '';
  }
  
  /// Mark welcome message as shown to prevent repetition
  void markWelcomeShown(String sessionId) {
    final session = _connections[sessionId];
    session?.markWelcomeShown();
  }
  
  /// Check if welcome message was already shown
  bool isWelcomeShown(String sessionId) {
    final session = _connections[sessionId];
    return session?.welcomeMessageShown ?? false;
  }
  
  /// Check if session is in interactive mode
  bool isInInteractiveMode(String sessionId) {
    final session = _connections[sessionId];
    return session?.isInInteractiveMode ?? false;
  }
  
  /// Get current executing command
  String? getCurrentCommand(String sessionId) {
    final session = _connections[sessionId];
    return session?.getCurrentCommand();
  }
  
  /// Get session statistics
  Map<String, dynamic> getSessionStats(String sessionId) {
    final session = _connections[sessionId];
    if (session == null) return {};
    
    return {
      'id': session.id,
      'status': session.status.name,
      'createdAt': session.createdAt.toIso8601String(),
      'welcomeShown': session.welcomeMessageShown,
      'interactiveMode': session.isInInteractiveMode,
      'currentCommand': session.getCurrentCommand(),
      'profile': {
        'host': session.profile.host,
        'port': session.profile.port,
        'username': session.profile.username,
        'name': session.profile.name,
      },
    };
  }
  
  /// Get all active sessions
  List<String> getActiveSessions() {
    return _connections.keys.toList();
  }
  
  /// Get session profile
  SshProfile? getSessionProfile(String sessionId) {
    return _connections[sessionId]?.profile;
  }
  
  /// Reconnect to SSH host
  Future<void> reconnect(String sessionId) async {
    final session = _connections[sessionId];
    if (session == null) {
      throw Exception('No SSH session found: $sessionId');
    }
    
    debugPrint('Reconnecting SSH session: $sessionId');
    
    _emitEvent(SshConnectionEvent(
      type: SshConnectionEventType.statusChanged,
      status: SshConnectionStatus.reconnecting,
      timestamp: DateTime.now(),
    ));
    
    try {
      // Close existing connection
      await disconnect(sessionId);
      
      // Reconnect with same profile
      await connect(session.profile);
      
    } catch (e) {
      debugPrint('Reconnection failed: $e');
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Reconnection failed: $e',
        timestamp: DateTime.now(),
      ));
      throw Exception('Reconnection failed: $e');
    }
  }
  
  /// Disconnect all sessions
  Future<void> disconnectAll() async {
    final sessionIds = _connections.keys.toList();
    for (final sessionId in sessionIds) {
      await disconnect(sessionId);
    }
  }
  
  /// Parse private key for SSH authentication
  Future<SSHKeyPair?> _parsePrivateKey(String privateKey, String? passphrase) async {
    try {
      final passphraseStr = passphrase ?? '';
      
      // dartssh2 uses a unified fromPem method for all key types
      final keyPairs = SSHKeyPair.fromPem(privateKey, passphraseStr);
      return keyPairs.isNotEmpty ? keyPairs.first : null;
      
    } catch (e) {
      debugPrint('Error parsing private key: $e');
      return null;
    }
  }
  
  /// Emit connection event
  void _emitEvent(SshConnectionEvent event) {
    _eventController.add(event);
  }
  
  /// Dispose resources with proper cleanup
  void dispose() {
    disconnectAll();
    _eventController.close();
  }
  
  /// Force disconnect session with cleanup
  Future<void> forceDisconnect(String sessionId) async {
    final session = _connections[sessionId];
    if (session == null) return;
    
    debugPrint('Force disconnecting SSH session: $sessionId');
    
    try {
      session.dispose();
      _connections.remove(sessionId);
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.disconnected,
        timestamp: DateTime.now(),
      ));
      
      _emitEvent(SshConnectionEvent(
        type: SshConnectionEventType.closed,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error force disconnecting SSH session: $e');
    }
  }
}

/// Internal connection session with enhanced PTY session management
class _ConnectionSession {
  final String id;
  final SshProfile profile;
  final SSHClient? client;
  final SSHSession? shell;
  SshConnectionStatus status;
  final StringBuffer outputBuffer; // Overall buffer (for backward compatibility)
  final StringBuffer welcomeBuffer; // Welcome message buffer
  final StringBuffer commandBuffer; // Current command output buffer
  final DateTime createdAt;
  bool welcomeMessageShown = false; // Track if welcome message was already shown
  Timer? welcomeTimeout; // Timeout for welcome message detection
  bool isInteractiveMode = false; // Track if currently in interactive command mode
  String? currentCommand; // Track the current executing command

  _ConnectionSession({
    required this.id,
    required this.profile,
    this.client,
    this.shell,
    required this.status,
  }) : outputBuffer = StringBuffer(),
       welcomeBuffer = StringBuffer(),
       commandBuffer = StringBuffer(),
       createdAt = DateTime.now();
  
  /// Clear command-specific output
  void clearCommandOutput() {
    commandBuffer.clear();
    currentCommand = null;
    isInteractiveMode = false;
  }
  
  /// Mark welcome message as shown and cancel timeout
  void markWelcomeShown() {
    welcomeMessageShown = true;
    welcomeTimeout?.cancel();
    welcomeTimeout = null;
  }
  
  /// Set current executing command
  void setCurrentCommand(String command) {
    currentCommand = command;
    // Detect interactive commands
    final interactiveCommands = ['vi', 'vim', 'nano', 'emacs', 'htop', 'top', 'less', 'more'];
    isInteractiveMode = interactiveCommands.any((cmd) => command.trim().startsWith(cmd));
  }
  
  /// Get command output without welcome message
  String getCommandOutput() {
    return commandBuffer.toString();
  }
  
  /// Get welcome message
  String getWelcomeMessage() {
    return welcomeBuffer.toString();
  }
  
  /// Check if currently in interactive mode
  bool get isInInteractiveMode => isInteractiveMode;
  
  /// Get current executing command
  String? getCurrentCommand() => currentCommand;
  
  /// Dispose session resources
  void dispose() {
    welcomeTimeout?.cancel();
    shell?.close();
    client?.close();
  }
}