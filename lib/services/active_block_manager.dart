import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import 'persistent_process_detector.dart';
import '../models/enhanced_terminal_models.dart';

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

  /// Send control signal (Ctrl+C, Ctrl+D, etc.)
  void sendControlSignal(String signal) {
    if (isRunning) {
      switch (signal.toLowerCase()) {
        case 'ctrl+c':
        case '^c':
          inputController.add('\x03'); // ETX (End of Text)
          break;
        case 'ctrl+d':
        case '^d':
          inputController.add('\x04'); // EOT (End of Transmission)
          break;
        case 'ctrl+z':
        case '^z':
          inputController.add('\x1A'); // SUB (Substitute)
          break;
        default:
          debugPrint('Unknown control signal: $signal');
      }
    }
  }

  /// Terminate the process
  Future<bool> terminate({Duration? timeout}) async {
    if (_isTerminated || process == null) {
      return true;
    }

    try {
      // Try graceful termination first
      sendControlSignal('ctrl+c');
      
      // Wait for graceful exit with timeout
      final timeoutDuration = timeout ?? const Duration(seconds: 5);
      final exitResult = await process!.exitCode.timeout(timeoutDuration);
      
      _handleProcessExit(exitResult);
      return true;
      
    } on TimeoutException {
      // Force kill if graceful termination failed
      try {
        process!.kill(ProcessSignal.sigkill);
        _handleProcessExit(-9); // SIGKILL
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

/// Events emitted by the ActiveBlockManager
enum ActiveBlockEventType {
  blockActivated,
  blockDeactivated,
  blockTerminated,
  processOutput,
  processError,
  focusChanged,
}

/// Event model for active block changes
class ActiveBlockEvent {
  final ActiveBlockEventType type;
  final String? blockId;
  final String? sessionId;
  final String? message;
  final dynamic data;
  final DateTime timestamp;

  const ActiveBlockEvent({
    required this.type,
    this.blockId,
    this.sessionId,
    this.message,
    this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ActiveBlockEvent{type: $type, blockId: $blockId, message: $message}';
  }
}

/// Service for managing active terminal blocks and their PTY connections
class ActiveBlockManager {
  static ActiveBlockManager? _instance;
  static ActiveBlockManager get instance => _instance ??= ActiveBlockManager._();

  ActiveBlockManager._();

  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  final StreamController<ActiveBlockEvent> _eventController = StreamController.broadcast();
  
  final Map<String, PtyConnection> _activeBlocks = {};
  final Map<String, String> _sessionActiveBlocks = {}; // sessionId -> blockId
  String? _focusedBlockId;
  
  /// Stream of active block events
  Stream<ActiveBlockEvent> get events => _eventController.stream;

  /// Get currently focused block ID
  String? get focusedBlockId => _focusedBlockId;

  /// Get all active block IDs
  List<String> get activeBlockIds => _activeBlocks.keys.toList();

  /// Get active blocks for a session
  List<String> getActiveBlocksForSession(String sessionId) {
    return _activeBlocks.entries
        .where((entry) => _sessionActiveBlocks[sessionId] == entry.key)
        .map((entry) => entry.key)
        .toList();
  }

  /// Create and activate a new block for persistent/interactive commands
  Future<String?> activateBlock({
    required String blockId,
    required String sessionId,
    required String command,
    required EnhancedTerminalBlockData blockData,
  }) async {
    try {
      final processInfo = _processDetector.detectProcessType(command);
      
      // Only activate blocks that need special handling
      if (!processInfo.needsSpecialHandling) {
        debugPrint('Command does not require special handling: $command');
        return null;
      }

      // Terminate previous active block for this session if exists
      final previousActiveBlockId = _sessionActiveBlocks[sessionId];
      if (previousActiveBlockId != null) {
        await terminateBlock(previousActiveBlockId);
      }

      // Create PTY connection
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

      // Register active block
      _activeBlocks[blockId] = ptyConnection;
      _sessionActiveBlocks[sessionId] = blockId;

      // Emit activation event
      _emitEvent(ActiveBlockEvent(
        type: ActiveBlockEventType.blockActivated,
        blockId: blockId,
        sessionId: sessionId,
        message: 'Block activated for ${processInfo.type.name} process',
        data: processInfo,
        timestamp: DateTime.now(),
      ));

      // Auto-focus if it's interactive
      if (processInfo.requiresInput) {
        focusBlock(blockId);
      }

      return blockId;

    } catch (e) {
      debugPrint('Error activating block $blockId: $e');
      
      _emitEvent(ActiveBlockEvent(
        type: ActiveBlockEventType.processError,
        blockId: blockId,
        sessionId: sessionId,
        message: 'Failed to activate block: $e',
        timestamp: DateTime.now(),
      ));

      return null;
    }
  }

  /// Focus a specific block for input routing
  void focusBlock(String blockId) {
    if (!_activeBlocks.containsKey(blockId)) {
      debugPrint('Cannot focus non-existent block: $blockId');
      return;
    }

    final previousFocus = _focusedBlockId;
    _focusedBlockId = blockId;

    _emitEvent(ActiveBlockEvent(
      type: ActiveBlockEventType.focusChanged,
      blockId: blockId,
      message: 'Block focused (previous: $previousFocus)',
      timestamp: DateTime.now(),
    ));

    debugPrint('Focused block: $blockId');
  }

  /// Remove focus from current block
  void clearFocus() {
    final previousFocus = _focusedBlockId;
    _focusedBlockId = null;

    if (previousFocus != null) {
      _emitEvent(ActiveBlockEvent(
        type: ActiveBlockEventType.focusChanged,
        blockId: previousFocus,
        message: 'Focus cleared',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Send input to a specific active block
  bool sendInputToBlock(String blockId, String input) {
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      debugPrint('Cannot send input to non-existent block: $blockId');
      return false;
    }

    if (!connection.processInfo.requiresInput) {
      debugPrint('Block $blockId does not accept input');
      return false;
    }

    connection.sendInput(input);
    return true;
  }

  /// Send control signal to active block
  bool sendControlSignal(String blockId, String signal) {
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      debugPrint('Cannot send signal to non-existent block: $blockId');
      return false;
    }

    connection.sendControlSignal(signal);
    return true;
  }

  /// Terminate a specific active block
  Future<bool> terminateBlock(String blockId) async {
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      return true; // Already terminated or doesn't exist
    }

    debugPrint('Terminating block: $blockId');

    try {
      // Terminate the process
      await connection.terminate();

      // Remove from active blocks
      _activeBlocks.remove(blockId);

      // Clear session mapping
      _sessionActiveBlocks.removeWhere((_, activeBlockId) => activeBlockId == blockId);

      // Clear focus if this block was focused
      if (_focusedBlockId == blockId) {
        _focusedBlockId = null;
      }

      // Dispose connection resources
      connection.dispose();

      _emitEvent(ActiveBlockEvent(
        type: ActiveBlockEventType.blockTerminated,
        blockId: blockId,
        message: 'Block terminated successfully',
        timestamp: DateTime.now(),
      ));

      return true;

    } catch (e) {
      debugPrint('Error terminating block $blockId: $e');
      return false;
    }
  }

  /// Get PTY connection for a block
  PtyConnection? getConnection(String blockId) {
    return _activeBlocks[blockId];
  }

  /// Get output stream for a block
  Stream<String>? getOutputStream(String blockId) {
    return _activeBlocks[blockId]?.outputController.stream;
  }

  /// Check if a block is active
  bool isBlockActive(String blockId) {
    return _activeBlocks.containsKey(blockId);
  }

  /// Check if a block accepts input
  bool canBlockAcceptInput(String blockId) {
    final connection = _activeBlocks[blockId];
    return connection?.processInfo.requiresInput == true && connection?.isRunning == true;
  }

  /// Auto-terminate previous active process when new command starts
  Future<void> onNewCommandStarted(String sessionId, String newCommand) async {
    final activeBlockId = _sessionActiveBlocks[sessionId];
    if (activeBlockId != null) {
      final connection = _activeBlocks[activeBlockId];
      if (connection != null && connection.isRunning) {
        debugPrint('Auto-terminating previous active process for new command: $newCommand');
        await terminateBlock(activeBlockId);
      }
    }
  }

  /// Get statistics about active blocks
  Map<String, dynamic> getStats() {
    final stats = <String, dynamic>{};
    
    stats['totalActiveBlocks'] = _activeBlocks.length;
    stats['focusedBlock'] = _focusedBlockId;
    
    final typeDistribution = <String, int>{};
    final runningCount = _activeBlocks.values.where((c) => c.isRunning).length;
    
    for (final connection in _activeBlocks.values) {
      final typeName = connection.processInfo.type.name;
      typeDistribution[typeName] = (typeDistribution[typeName] ?? 0) + 1;
    }
    
    stats['runningBlocks'] = runningCount;
    stats['typeDistribution'] = typeDistribution;
    stats['sessionMappings'] = Map.from(_sessionActiveBlocks);
    
    return stats;
  }

  /// Cleanup all active blocks
  Future<void> cleanupAll() async {
    debugPrint('Cleaning up all active blocks...');
    
    final blockIds = _activeBlocks.keys.toList();
    for (final blockId in blockIds) {
      await terminateBlock(blockId);
    }
    
    _activeBlocks.clear();
    _sessionActiveBlocks.clear();
    _focusedBlockId = null;
    
    debugPrint('All active blocks cleaned up');
  }

  /// Emit an event
  void _emitEvent(ActiveBlockEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await cleanupAll();
    await _eventController.close();
  }
}