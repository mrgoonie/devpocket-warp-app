import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';

import 'ssh_connection_models.dart';

/// Handles SSH shell setup and data stream management
class SshShellHandler {
  final Function(SshConnectionEvent) _eventEmitter;

  SshShellHandler({
    required Function(SshConnectionEvent) eventEmitter,
  }) : _eventEmitter = eventEmitter;

  /// Set up shell with enhanced data stream handlers
  void setupShellHandlers(ConnectionSession session) {
    // Set up stdout handler
    session.shell.stdout.cast<List<int>>().transform(utf8.decoder).listen(
      (data) {
        _handleShellOutput(session, data);
      },
      onError: (error) {
        debugPrint('SSH shell stdout error: $error');
        _eventEmitter(SshConnectionEvent(
          type: SshConnectionEventType.error,
          error: error.toString(),
          timestamp: DateTime.now(),
        ));
      },
    );
    
    // Set up stderr handler  
    session.shell.stderr.cast<List<int>>().transform(utf8.decoder).listen(
      (data) {
        _handleShellError(session, data);
      },
      onError: (error) {
        debugPrint('SSH shell stderr error: $error');
        _eventEmitter(SshConnectionEvent(
          type: SshConnectionEventType.error,
          error: error.toString(),
          timestamp: DateTime.now(),
        ));
      },
    );
  }

  /// Handle stdout data from SSH shell
  void _handleShellOutput(ConnectionSession session, String data) {
    // Update session metrics
    session.addBytesReceived(data.length);
    
    // Write to overall buffer for backward compatibility
    session.outputBuffer.write(data);
    
    // Enhanced welcome message detection with timeout mechanism
    if (!session.welcomeMessageShown) {
      session.welcomeBuffer.write(data);
      
      // Start welcome message timeout if not already started
      session.welcomeTimeout ??= Timer(const Duration(seconds: 3), () {
        session.markWelcomeShown();
      });
    } else {
      // This is command output after welcome period
      session.commandBuffer.write(data);
    }
    
    _eventEmitter(SshConnectionEvent(
      type: SshConnectionEventType.dataReceived,
      data: data,
      timestamp: DateTime.now(),
    ));
  }

  /// Handle stderr data from SSH shell
  void _handleShellError(ConnectionSession session, String data) {
    // Update session metrics
    session.addBytesReceived(data.length);
    
    // Write to overall buffer for backward compatibility
    session.outputBuffer.write(data);
    
    // Stderr always goes to command buffer
    session.commandBuffer.write(data);
    
    _eventEmitter(SshConnectionEvent(
      type: SshConnectionEventType.dataReceived,
      data: data,
      timestamp: DateTime.now(),
    ));
  }

  /// Send command to shell
  Future<void> sendCommand(ConnectionSession session, String command) async {
    if (session.status != SshConnectionStatus.connected) {
      throw Exception('SSH connection not established');
    }

    try {
      // Track command in session
      session.setCurrentCommand(command);
      
      // Clear command buffer before sending new command to avoid mixing outputs
      session.clearCommandOutput();
      
      final commandWithNewline = command.endsWith('\n') ? command : '$command\n';
      session.shell.stdin.add(utf8.encode(commandWithNewline));
      
      // Update metrics
      session.addBytesSent(commandWithNewline.length);
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.dataSent,
        data: commandWithNewline,
        timestamp: DateTime.now(),
      ));
      
      debugPrint('SSH command sent: ${command.trim()}');
      
    } catch (e) {
      debugPrint('Failed to send SSH command: $e');
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Failed to send command: $e',
        timestamp: DateTime.now(),
      ));
      throw Exception('Failed to send command: $e');
    }
  }

  /// Send raw data to shell
  Future<void> sendData(ConnectionSession session, String data) async {
    if (session.status != SshConnectionStatus.connected) {
      throw Exception('SSH connection not established');
    }

    try {
      session.shell.stdin.add(utf8.encode(data));
      
      // Update metrics
      session.addBytesSent(data.length);
      
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.dataSent,
        data: data,
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to send SSH data: $e');
      _eventEmitter(SshConnectionEvent(
        type: SshConnectionEventType.error,
        error: 'Failed to send data: $e',
        timestamp: DateTime.now(),
      ));
      throw Exception('Failed to send data: $e');
    }
  }

  /// Resize terminal (PTY) if supported
  Future<void> resizeTerminal(ConnectionSession session, int cols, int rows) async {
    try {
      // PTY resize functionality would go here
      debugPrint('Terminal resize requested: ${cols}x${rows}');
      // Note: dartssh2 may have limitations on PTY resize
    } catch (e) {
      debugPrint('Failed to resize terminal: $e');
    }
  }
}