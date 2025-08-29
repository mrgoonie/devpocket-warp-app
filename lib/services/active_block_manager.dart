import 'package:flutter/foundation.dart';
import 'dart:async';

import 'persistent_process_detector.dart';
import 'active_block_models.dart';
import 'pty_connection_manager.dart';
import 'block_process_controller.dart';
import 'block_focus_manager.dart';
import 'block_statistics_service.dart';
import '../models/enhanced_terminal_models.dart';

/// Service for managing active terminal blocks and their PTY connections
class ActiveBlockManager {
  static ActiveBlockManager? _instance;
  static ActiveBlockManager get instance => _instance ??= ActiveBlockManager._();

  ActiveBlockManager._();

  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  final StreamController<ActiveBlockEvent> _eventController = StreamController.broadcast();
  
  final Map<String, PtyConnection> _activeBlocks = {};
  late final BlockFocusManager _focusManager;
  bool _isInitialized = false;
  
  /// Initialize the focus manager
  void _initializeFocusManager() {
    if (!_isInitialized) {
      _focusManager = BlockFocusManager(eventController: _eventController);
      _isInitialized = true;
    }
  }
  
  /// Stream of active block events
  Stream<ActiveBlockEvent> get events => _eventController.stream;

  /// Get currently focused block ID
  String? get focusedBlockId => _focusManager.focusedBlockId;

  /// Get all active block IDs
  List<String> get activeBlockIds => _activeBlocks.keys.toList();

  /// Get active blocks for a session
  List<String> getActiveBlocksForSession(String sessionId) {
    final activeBlockId = _focusManager.getActiveBlockForSession(sessionId);
    return activeBlockId != null ? [activeBlockId] : [];
  }

  /// Create and activate a new block for persistent/interactive commands
  Future<String?> activateBlock({
    required String blockId,
    required String sessionId,
    required String command,
    required EnhancedTerminalBlockData blockData,
  }) async {
    _ensureFocusManagerInitialized();
    
    try {
      final processInfo = _processDetector.detectProcessType(command);
      
      // Only activate blocks that need special handling
      if (!processInfo.needsSpecialHandling) {
        debugPrint('Command does not require special handling: $command');
        return null;
      }

      // Terminate previous active block for this session if exists
      final previousActiveBlockId = _focusManager.getActiveBlockForSession(sessionId);
      if (previousActiveBlockId != null) {
        await terminateBlock(previousActiveBlockId);
      }

      // Create PTY connection
      final ptyConnection = await PtyConnectionManager.createConnection(
        blockId: blockId,
        command: command,
        processInfo: processInfo,
      );
      
      if (ptyConnection == null) {
        debugPrint('Failed to create PTY connection for $blockId');
        return null;
      }

      // Register active block
      _activeBlocks[blockId] = ptyConnection;
      _focusManager.setActiveBlockForSession(sessionId, blockId);

      // Emit activation event
      _emitEvent(ActiveBlockEvent(
        type: ActiveBlockEventType.blockActivated,
        blockId: blockId,
        sessionId: sessionId,
        message: 'Block activated for ${processInfo.type.name} process',
        data: processInfo,
        timestamp: DateTime.now(),
      ));

      // Apply auto-focus strategy
      _focusManager.applyAutoFocus(
        blockId,
        requiresInput: processInfo.requiresInput,
        isPersistent: processInfo.isPersistent,
        sessionId: sessionId,
      );

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
    _ensureFocusManagerInitialized();
    
    if (!_activeBlocks.containsKey(blockId)) {
      debugPrint('Cannot focus non-existent block: $blockId');
      return;
    }

    _focusManager.focusBlock(blockId);
  }

  /// Remove focus from current block
  void clearFocus() {
    _ensureFocusManagerInitialized();
    _focusManager.clearFocus();
  }

  /// Send input to a specific active block
  bool sendInputToBlock(String blockId, String input) {
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      debugPrint('Cannot send input to non-existent block: $blockId');
      return false;
    }

    return BlockProcessController.sendInput(connection, input);
  }

  /// Send control signal to active block
  bool sendControlSignal(String blockId, String signal) {
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      debugPrint('Cannot send signal to non-existent block: $blockId');
      return false;
    }

    return BlockProcessController.sendControlSignal(connection, signal);
  }

  /// Terminate a specific active block
  Future<bool> terminateBlock(String blockId) async {
    _ensureFocusManagerInitialized();
    
    final connection = _activeBlocks[blockId];
    if (connection == null) {
      return true; // Already terminated or doesn't exist
    }

    debugPrint('Terminating block: $blockId');

    try {
      // Terminate the process
      await BlockProcessController.terminateProcess(connection);

      // Remove from active blocks
      _activeBlocks.remove(blockId);

      // Handle focus management cleanup
      _focusManager.handleBlockDeactivation(blockId);

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
    return connection != null && BlockProcessController.canAcceptInput(connection);
  }

  /// Auto-terminate previous active process when new command starts
  Future<void> onNewCommandStarted(String sessionId, String newCommand) async {
    _ensureFocusManagerInitialized();
    
    final activeBlockId = _focusManager.getActiveBlockForSession(sessionId);
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
    _ensureFocusManagerInitialized();
    return BlockStatisticsService.getBlockStatistics(_activeBlocks, _focusManager);
  }
  
  /// Get comprehensive statistics report
  BlockStatisticsReport getStatisticsReport() {
    _ensureFocusManagerInitialized();
    return BlockStatisticsService.generateReport(_activeBlocks, _focusManager);
  }

  /// Cleanup all active blocks
  Future<void> cleanupAll() async {
    debugPrint('Cleaning up all active blocks...');
    
    final blockIds = _activeBlocks.keys.toList();
    for (final blockId in blockIds) {
      await terminateBlock(blockId);
    }
    
    _activeBlocks.clear();
    if (_isInitialized) {
      _focusManager.resetAll();
    }
    
    debugPrint('All active blocks cleaned up');
  }

  /// Ensure focus manager is initialized
  void _ensureFocusManagerInitialized() {
    if (!_isInitialized) {
      _initializeFocusManager();
    }
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