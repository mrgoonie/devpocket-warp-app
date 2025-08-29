import 'terminal_session_models.dart';
import 'ssh_connection_manager.dart';
import 'ssh_connection_models.dart';

/// Handles events for terminal sessions
class TerminalSessionEvents {
  final Function(TerminalOutput) _outputEmitter;

  TerminalSessionEvents({
    required Function(TerminalOutput) outputEmitter,
  }) : _outputEmitter = outputEmitter;

  /// Handle SSH connection events
  void handleSshEvent(String sessionId, SshConnectionEvent event, SessionInstance session) {
    switch (event.type) {
      case SshConnectionEventType.dataReceived:
        if (event.data != null) {
          _outputEmitter(TerminalOutput(
            data: event.data!,
            type: TerminalOutputType.stdout,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      case SshConnectionEventType.error:
        if (event.error != null) {
          _outputEmitter(TerminalOutput(
            data: 'SSH Error: ${event.error!}\n',
            type: TerminalOutputType.error,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      case SshConnectionEventType.closed:
        _outputEmitter(TerminalOutput(
          data: 'SSH connection closed\n',
          type: TerminalOutputType.info,
          timestamp: event.timestamp,
        ));
        
        session.state = TerminalSessionState.stopped;
        break;
        
      case SshConnectionEventType.statusChanged:
        if (event.status != null) {
          final statusMessage = _getStatusMessage(event.status!);
          
          _outputEmitter(TerminalOutput(
            data: '$statusMessage\n',
            type: TerminalOutputType.info,
            timestamp: event.timestamp,
          ));
        }
        break;
        
      default:
        break;
    }
  }

  /// Get human-readable status message
  String _getStatusMessage(SshConnectionStatus status) {
    switch (status) {
      case SshConnectionStatus.connecting:
        return 'Connecting...';
      case SshConnectionStatus.authenticating:
        return 'Authenticating...';
      case SshConnectionStatus.connected:
        return 'Connected';
      case SshConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case SshConnectionStatus.failed:
        return 'Connection failed';
      case SshConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }
}