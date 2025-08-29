import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import 'persistent_process_detector.dart' show ProcessInfo;

/// PTY connection wrapper for managing process lifecycle
class PtyConnection {
  final String blockId;
  final String command;
  final ProcessInfo processInfo;
  final Process? process;
  final StreamController<String> outputController;
  final StreamController<String> inputController;
  final DateTime createdAt;
  
  StreamSubscription<List<int>>? _stdoutSubscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  StreamSubscription<String>? _inputSubscription;
  
  bool _isTerminated = false;
  int? _exitCode;
  DateTime? _terminatedAt;

  PtyConnection({
    required this.blockId,
    required this.command,
    required this.processInfo,
    required this.process,
    required this.outputController,
    required this.inputController,
    required this.createdAt,
  });

  /// Check if process is still running
  bool get isRunning => !_isTerminated && process != null;

  /// Check if process has been terminated
  bool get isTerminated => _isTerminated;

  /// Get process exit code if available
  int? get exitCode => _exitCode;

  /// Get termination time
  DateTime? get terminatedAt => _terminatedAt;

  /// Get process uptime
  Duration get uptime {
    final end = _terminatedAt ?? DateTime.now();
    return end.difference(createdAt);
  }

  /// Initialize PTY streams
  void initialize() {
    if (process != null) {
      // Setup stdout stream
      _stdoutSubscription = process!.stdout.listen(
        (data) {
          if (!_isTerminated) {
            final output = String.fromCharCodes(data);
            outputController.add(output);
          }
        },
        onError: (error) {
          outputController.addError('Stdout error: $error');
        },
        onDone: () {
          if (!_isTerminated) {
            outputController.add('\n[Process stdout stream closed]\n');
          }
        },
      );

      // Setup stderr stream
      _stderrSubscription = process!.stderr.listen(
        (data) {
          if (!_isTerminated) {
            final output = String.fromCharCodes(data);
            outputController.add(output);
          }
        },
        onError: (error) {
          outputController.addError('Stderr error: $error');
        },
        onDone: () {
          if (!_isTerminated) {
            outputController.add('\n[Process stderr stream closed]\n');
          }
        },
      );

      // Setup input stream
      _inputSubscription = inputController.stream.listen(
        (input) {
          if (isRunning) {
            try {
              process!.stdin.write(input);
              if (!input.endsWith('\n')) {
                process!.stdin.write('\n');
              }
            } catch (e) {
              outputController.addError('Input error: $e');
            }
          }
        },
        onError: (error) {
          outputController.addError('Input stream error: $error');
        },
      );

      // Monitor process exit
      process!.exitCode.then((code) {
        _handleProcessExit(code);
      }).catchError((error) {
        outputController.addError('Process exit error: $error');
        _handleProcessExit(-1);
      });
    }
  }

  /// Handle process exit
  void _handleProcessExit(int code) {
    if (!_isTerminated) {
      _exitCode = code;
      _terminatedAt = DateTime.now();
      _isTerminated = true;
      
      outputController.add('\n[Process exited with code $code]\n');
      
      // Close streams after a short delay to ensure all output is captured
      Timer(const Duration(milliseconds: 100), () {
        dispose();
      });
    }
  }

  /// Send input to the process
  void sendInput(String input) {
    if (isRunning && processInfo.requiresInput) {
      inputController.add(input);
    } else {
      debugPrint('Cannot send input to non-interactive or terminated process');
    }
  }

  /// Dispose all resources
  void dispose() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _inputSubscription?.cancel();
    
    if (!outputController.isClosed) {
      outputController.close();
    }
    if (!inputController.isClosed) {
      inputController.close();
    }
  }

  @override
  String toString() {
    return 'PtyConnection{blockId: $blockId, command: $command, type: ${processInfo.type}, running: $isRunning}';
  }
}

/// Factory class for creating and managing PTY connections
class PtyConnectionManager {
  /// Create a PTY connection for a command
  static Future<PtyConnection?> createConnection({
    required String blockId,
    required String command,
    required ProcessInfo processInfo,
  }) async {
    try {
      final outputController = StreamController<String>.broadcast();
      final inputController = StreamController<String>();
      
      Process? process;
      if (processInfo.needsPTY || processInfo.isPersistent) {
        try {
          // Start the process
          final parts = command.split(' ');
          final executable = parts.first;
          final args = parts.length > 1 ? parts.sublist(1) : <String>[];
          
          process = await Process.start(
            executable,
            args,
            mode: ProcessStartMode.normal,
            runInShell: true,
          );
          
          debugPrint('Started process for block $blockId: $command (PID: ${process.pid})');
          
        } catch (e) {
          outputController.add('\n[Error starting process: $e]\n');
          debugPrint('Failed to start process for $command: $e');
        }
      }

      // Create PTY connection
      final ptyConnection = PtyConnection(
        blockId: blockId,
        command: command,
        processInfo: processInfo,
        process: process,
        outputController: outputController,
        inputController: inputController,
        createdAt: DateTime.now(),
      );

      // Initialize PTY streams
      ptyConnection.initialize();

      return ptyConnection;

    } catch (e) {
      debugPrint('Error creating PTY connection for $blockId: $e');
      return null;
    }
  }

  /// Validate if a connection is healthy
  static bool isConnectionHealthy(PtyConnection connection) {
    try {
      // Check if streams are not closed
      if (connection.outputController.isClosed || 
          connection.inputController.isClosed) {
        return false;
      }

      // Check if process is in valid state
      if (connection.processInfo.needsPTY && connection.process == null) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking connection health: $e');
      return false;
    }
  }
}