import 'package:flutter/foundation.dart';

import 'terminal_session_models.dart';
import 'ssh_connection_manager.dart';
import 'terminal_websocket_service.dart';

/// Handles command execution for terminal sessions
class TerminalSessionCommands {
  final SshConnectionManager _sshManager;
  final TerminalWebSocketService _terminalWsService;
  final Function(TerminalOutput) _outputEmitter;

  TerminalSessionCommands({
    required SshConnectionManager sshManager,
    required TerminalWebSocketService terminalWsService,
    required Function(TerminalOutput) outputEmitter,
  }) : _sshManager = sshManager,
       _terminalWsService = terminalWsService,
       _outputEmitter = outputEmitter;

  /// Send command to terminal session
  Future<void> sendCommand(SessionInstance session, String command) async {
    try {
      switch (session.type) {
        case TerminalSessionType.ssh:
          // Try WebSocket first, fallback to direct SSH
          if (_terminalWsService.isConnected && 
              _terminalWsService.getActiveSessions().contains(session.id)) {
            await _terminalWsService.sendTerminalControl(command, sessionId: session.id);
          } else {
            await _sshManager.sendCommand(session.id, command);
          }
          break;
          
        case TerminalSessionType.websocket:
          if (session.websocketUrl != null) {
            await _terminalWsService.sendTerminalData(command, sessionId: session.id);
          }
          break;
          
        case TerminalSessionType.local:
          // Local command execution would go here
          _outputEmitter(TerminalOutput(
            data: 'Local command execution not implemented yet\n',
            type: TerminalOutputType.info,
            timestamp: DateTime.now(),
          ));
          break;
      }
      
    } catch (e) {
      debugPrint('Failed to send command: $e');
      _outputEmitter(TerminalOutput(
        data: 'Failed to send command: $e\n',
        type: TerminalOutputType.error,
        timestamp: DateTime.now(),
      ));
      throw Exception('Failed to send command: $e');
    }
  }

  /// Send raw data to terminal session
  Future<void> sendData(SessionInstance session, String data) async {
    try {
      switch (session.type) {
        case TerminalSessionType.ssh:
          // Try WebSocket first, fallback to direct SSH
          if (_terminalWsService.isConnected && 
              _terminalWsService.getActiveSessions().contains(session.id)) {
            await _terminalWsService.sendTerminalData(data, sessionId: session.id);
          } else {
            await _sshManager.sendData(session.id, data);
          }
          break;
          
        case TerminalSessionType.websocket:
          if (session.websocketUrl != null) {
            await _terminalWsService.sendTerminalData(data, sessionId: session.id);
          }
          break;
          
        case TerminalSessionType.local:
          // Local data send would go here
          break;
      }
      
    } catch (e) {
      debugPrint('Failed to send data: $e');
      throw Exception('Failed to send data: $e');
    }
  }
}