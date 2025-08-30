import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../models/ssh_profile_models.dart';
import 'ssh_connection_models.dart';
import 'ssh_connection_auth.dart';

/// Factory for creating SSH connections
class SshConnectionFactory {
  final Function(SshConnectionEvent) _eventEmitter;

  SshConnectionFactory({
    required Function(SshConnectionEvent) eventEmitter,
  }) : _eventEmitter = eventEmitter;

  /// Create new SSH connection session
  Future<ConnectionSession> createConnection(SshProfile profile) async {
    final sessionId = profile.id;
    
    debugPrint('Creating SSH connection: ${profile.connectionString}');
    
    try {
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.connecting,
        timestamp: DateTime.now(),
      ));
      
      // Create SSH socket connection
      final socket = await SSHSocket.connect(profile.host, profile.port);
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.authenticating,
        timestamp: DateTime.now(),
      ));
      
      // Create SSH client with authentication
      final client = await SshConnectionAuth.createAuthenticatedClient(socket, profile);
      
      // Create terminal session with PTY support for interactive commands
      final shell = await client.shell();
      
      // Create connection session
      final session = ConnectionSession(
        id: sessionId,
        profile: profile,
        client: client,
        shell: shell,
        status: SshConnectionStatus.connected,
      );
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.connected,
        timestamp: DateTime.now(),
      ));
      
      debugPrint('SSH connection established: $sessionId');
      return session;
      
    } on SocketException catch (e) {
      debugPrint('SSH socket error: $e');
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Network error: ${e.message}',
        timestamp: DateTime.now(),
      ));
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.failed,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('Network connection failed: ${e.message}');
      
    } on Exception catch (e) {
      debugPrint('SSH protocol error: $e');
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'SSH authentication failed: $e',
        timestamp: DateTime.now(),
      ));
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.failed,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('SSH authentication failed: $e');
      
    } catch (e) {
      debugPrint('SSH connection error: $e');
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Connection failed: $e',
        timestamp: DateTime.now(),
      ));
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.statusChanged,
        status: SshConnectionStatus.failed,
        timestamp: DateTime.now(),
      ));
      
      throw Exception('SSH connection failed: $e');
    }
  }

  /// Reconnect existing connection session  
  Future<ConnectionSession> reconnectConnection(SshProfile profile) async {
    debugPrint('Reconnecting SSH connection: ${profile.connectionString}');
    
    _eventEmitter(SshConnectionEvent(
      type: SshConnectionEventType.statusChanged,
      status: SshConnectionStatus.reconnecting,
      timestamp: DateTime.now(),
    ));
    
    // Reconnection is essentially creating a new connection
    return await createConnection(profile);
  }

  /// Test connection without establishing full session
  Future<bool> testConnection(SshProfile profile) async {
    return await SshConnectionAuth.testConnection(profile);
  }
}