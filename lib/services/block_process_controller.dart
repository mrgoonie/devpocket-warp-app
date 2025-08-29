import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import 'pty_connection_manager.dart';

/// Controller for managing process control signals and termination
class BlockProcessController {
  /// Send control signal (Ctrl+C, Ctrl+D, etc.) to a PTY connection
  static bool sendControlSignal(PtyConnection connection, String signal) {
    if (!connection.isRunning) {
      debugPrint('Cannot send signal to non-running process');
      return false;
    }

    switch (signal.toLowerCase()) {
      case 'ctrl+c':
      case '^c':
        connection.inputController.add('\x03'); // ETX (End of Text)
        break;
      case 'ctrl+d':
      case '^d':
        connection.inputController.add('\x04'); // EOT (End of Transmission)
        break;
      case 'ctrl+z':
      case '^z':
        connection.inputController.add('\x1A'); // SUB (Substitute)
        break;
      default:
        debugPrint('Unknown control signal: $signal');
        return false;
    }
    
    return true;
  }

  /// Terminate a PTY connection process
  static Future<bool> terminateProcess(PtyConnection connection, {Duration? timeout}) async {
    if (connection.isTerminated || connection.process == null) {
      return true; // Already terminated
    }

    try {
      // Try graceful termination first
      sendControlSignal(connection, 'ctrl+c');
      
      // Wait for graceful exit with timeout
      final timeoutDuration = timeout ?? const Duration(seconds: 5);
      final exitResult = await connection.process!.exitCode.timeout(timeoutDuration);
      
      debugPrint('Process terminated gracefully with exit code: $exitResult');
      return true;
      
    } on TimeoutException {
      // Force kill if graceful termination failed
      try {
        connection.process!.kill(ProcessSignal.sigkill);
        debugPrint('Process force killed with SIGKILL');
        return true;
      } catch (e) {
        debugPrint('Failed to force kill process: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error terminating process: $e');
      return false;
    }
  }

  /// Send input to a PTY connection
  static bool sendInput(PtyConnection connection, String input) {
    if (!connection.isRunning || !connection.processInfo.requiresInput) {
      debugPrint('Cannot send input to non-interactive or terminated process');
      return false;
    }

    connection.sendInput(input);
    return true;
  }

  /// Check if a connection can accept input
  static bool canAcceptInput(PtyConnection connection) {
    return connection.processInfo.requiresInput && connection.isRunning;
  }

  /// Get process status information
  static Map<String, dynamic> getProcessStatus(PtyConnection connection) {
    return {
      'blockId': connection.blockId,
      'command': connection.command,
      'processType': connection.processInfo.type.name,
      'isRunning': connection.isRunning,
      'isTerminated': connection.isTerminated,
      'requiresInput': connection.processInfo.requiresInput,
      'isPersistent': connection.processInfo.isPersistent,
      'needsPTY': connection.processInfo.needsPTY,
      'uptime': connection.uptime.inSeconds,
      'exitCode': connection.exitCode,
      'terminatedAt': connection.terminatedAt?.toIso8601String(),
      'createdAt': connection.createdAt.toIso8601String(),
    };
  }

  /// Validate process health and detect issues
  static ProcessHealthStatus validateProcessHealth(PtyConnection connection) {
    final issues = <String>[];
    
    // Check if process should be running but isn't
    if (connection.processInfo.needsPTY && connection.process == null) {
      issues.add('Process required but not started');
    }

    // Check if streams are closed unexpectedly
    if (connection.outputController.isClosed && connection.isRunning) {
      issues.add('Output stream closed while process running');
    }

    // Check for long-running processes without output
    final timeSinceCreated = DateTime.now().difference(connection.createdAt);
    if (connection.isRunning && timeSinceCreated > const Duration(minutes: 30)) {
      issues.add('Process running for extended period without termination');
    }

    // Check if terminated process has resources not cleaned up
    if (connection.isTerminated && !connection.outputController.isClosed) {
      issues.add('Process terminated but streams not closed');
    }

    return ProcessHealthStatus(
      isHealthy: issues.isEmpty,
      issues: issues,
      connection: connection,
      lastChecked: DateTime.now(),
    );
  }

  /// Force cleanup of a connection's resources
  static Future<void> forceCleanup(PtyConnection connection) async {
    try {
      // Force kill process if still running
      if (connection.process != null && connection.isRunning) {
        try {
          connection.process!.kill(ProcessSignal.sigkill);
        } catch (e) {
          debugPrint('Error force killing process: $e');
        }
      }

      // Dispose all resources
      connection.dispose();
      
      debugPrint('Forced cleanup completed for block: ${connection.blockId}');
    } catch (e) {
      debugPrint('Error during force cleanup: $e');
    }
  }
}

/// Process health status information
class ProcessHealthStatus {
  final bool isHealthy;
  final List<String> issues;
  final PtyConnection connection;
  final DateTime lastChecked;

  const ProcessHealthStatus({
    required this.isHealthy,
    required this.issues,
    required this.connection,
    required this.lastChecked,
  });

  @override
  String toString() {
    return 'ProcessHealthStatus{blockId: ${connection.blockId}, healthy: $isHealthy, issues: $issues}';
  }
}