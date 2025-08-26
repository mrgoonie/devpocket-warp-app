import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/enhanced_terminal_models.dart';
import '../widgets/terminal/terminal_block.dart';

/// Terminal block lifecycle service for managing block creation, updates, and cleanup
class TerminalBlockLifecycleService {
  static TerminalBlockLifecycleService? _instance;
  static TerminalBlockLifecycleService get instance => _instance ??= TerminalBlockLifecycleService._();

  TerminalBlockLifecycleService._();

  final Map<String, TerminalBlockLifecycle> _blockLifecycles = {};
  final StreamController<BlockLifecycleEvent> _eventController = StreamController.broadcast();
  Timer? _cleanupTimer;

  /// Stream of block lifecycle events
  Stream<BlockLifecycleEvent> get events => _eventController.stream;

  /// Initialize the service
  void initialize() {
    _startPeriodicCleanup();
  }

  /// Create new terminal block
  EnhancedTerminalBlockData createBlock({
    required String sessionId,
    required String command,
    bool isAgentCommand = false,
    bool isInteractive = false,
    String? encodingFormat,
    Map<String, dynamic> metadata = const {},
  }) {
    final now = DateTime.now();
    final blockId = _generateBlockId();
    
    final block = EnhancedTerminalBlockData(
      id: blockId,
      command: command,
      status: TerminalBlockStatus.pending,
      timestamp: now,
      sessionId: sessionId,
      index: _getNextBlockIndex(sessionId),
      isAgentCommand: isAgentCommand,
      isInteractive: isInteractive,
      requiresFullscreenModal: isInteractive && _requiresFullscreen(command),
      encodingFormat: encodingFormat ?? 'utf-8',
      metadata: metadata,
    );

    // Create lifecycle tracker
    final lifecycle = TerminalBlockLifecycle(
      blockId: blockId,
      sessionId: sessionId,
      createdAt: now,
    );
    
    _blockLifecycles[blockId] = lifecycle;

    // Emit creation event
    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.created,
      blockId: blockId,
      sessionId: sessionId,
      timestamp: now,
    ));

    debugPrint('Created terminal block: $blockId for session: $sessionId');
    return block;
  }

  /// Start block execution
  void startBlockExecution(String blockId) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.startExecution();

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.executionStarted,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
    ));

    debugPrint('Started execution for block: $blockId');
  }

  /// Update block output
  void updateBlockOutput(String blockId, String output, {bool append = true}) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.addOutput(output, append: append);

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.outputUpdated,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
      data: {'output': output, 'append': append},
    ));
  }

  /// Complete block execution
  void completeBlockExecution(
    String blockId, {
    bool success = true,
    int? exitCode,
    String? error,
  }) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.completeExecution(
      success: success,
      exitCode: exitCode,
      error: error,
    );

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.executionCompleted,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
      data: {
        'success': success,
        'exitCode': exitCode,
        'error': error,
        'duration': lifecycle.executionDuration?.inMilliseconds,
      },
    ));

    debugPrint('Completed execution for block: $blockId (success: $success)');
  }

  /// Cancel block execution
  void cancelBlockExecution(String blockId, {String? reason}) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.cancelExecution(reason: reason);

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.executionCancelled,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
      data: {'reason': reason},
    ));

    debugPrint('Cancelled execution for block: $blockId (reason: $reason)');
  }

  /// Add error to block
  void addBlockError(String blockId, EnhancedTerminalBlockError error) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.addError(error);

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.errorAdded,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
      data: {'error': error.toJson()},
    ));
  }

  /// Set block as interactive
  void setBlockInteractive(String blockId, bool interactive) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.setInteractive(interactive);

    _emitEvent(BlockLifecycleEvent(
      type: interactive 
          ? BlockLifecycleEventType.becameInteractive
          : BlockLifecycleEventType.leftInteractive,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
    ));
  }

  /// Archive block (soft delete)
  void archiveBlock(String blockId) {
    final lifecycle = _blockLifecycles[blockId];
    if (lifecycle == null) return;

    lifecycle.archive();

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.archived,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
    ));

    debugPrint('Archived block: $blockId');
  }

  /// Permanently delete block
  void deleteBlock(String blockId) {
    final lifecycle = _blockLifecycles.remove(blockId);
    if (lifecycle == null) return;

    _emitEvent(BlockLifecycleEvent(
      type: BlockLifecycleEventType.deleted,
      blockId: blockId,
      sessionId: lifecycle.sessionId,
      timestamp: DateTime.now(),
    ));

    debugPrint('Deleted block: $blockId');
  }

  /// Get block lifecycle info
  TerminalBlockLifecycle? getBlockLifecycle(String blockId) {
    return _blockLifecycles[blockId];
  }

  /// Get all blocks for session
  List<TerminalBlockLifecycle> getSessionBlocks(String sessionId) {
    return _blockLifecycles.values
        .where((lifecycle) => lifecycle.sessionId == sessionId)
        .toList();
  }

  /// Get blocks by status
  List<TerminalBlockLifecycle> getBlocksByStatus(TerminalBlockStatus status) {
    return _blockLifecycles.values
        .where((lifecycle) => lifecycle.status == status)
        .toList();
  }

  /// Get running blocks
  List<TerminalBlockLifecycle> getRunningBlocks() {
    return getBlocksByStatus(TerminalBlockStatus.running);
  }

  /// Get blocks that need cleanup
  List<TerminalBlockLifecycle> getBlocksForCleanup() {
    final now = DateTime.now();
    const maxAge = Duration(hours: 24); // Keep blocks for 24 hours
    
    return _blockLifecycles.values
        .where((lifecycle) => 
            lifecycle.isArchived && 
            now.difference(lifecycle.createdAt) > maxAge)
        .toList();
  }

  /// Cleanup old blocks
  Future<void> cleanupOldBlocks() async {
    final blocksToCleanup = getBlocksForCleanup();
    
    for (final lifecycle in blocksToCleanup) {
      deleteBlock(lifecycle.blockId);
    }
    
    if (blocksToCleanup.isNotEmpty) {
      debugPrint('Cleaned up ${blocksToCleanup.length} old blocks');
    }
  }

  /// Cleanup session blocks
  Future<void> cleanupSessionBlocks(String sessionId) async {
    final sessionBlocks = getSessionBlocks(sessionId);
    
    for (final lifecycle in sessionBlocks) {
      archiveBlock(lifecycle.blockId);
    }
    
    debugPrint('Archived ${sessionBlocks.length} blocks for session: $sessionId');
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    final allBlocks = _blockLifecycles.values.toList();
    final runningBlocks = getRunningBlocks();
    
    final statusCounts = <String, int>{};
    for (final status in TerminalBlockStatus.values) {
      statusCounts[status.name] = getBlocksByStatus(status).length;
    }
    
    final sessions = allBlocks.map((b) => b.sessionId).toSet();
    
    return {
      'totalBlocks': allBlocks.length,
      'runningBlocks': runningBlocks.length,
      'activeSessions': sessions.length,
      'statusCounts': statusCounts,
      'archivedBlocks': allBlocks.where((b) => b.isArchived).length,
      'oldestBlock': allBlocks.isNotEmpty 
          ? allBlocks.map((b) => b.createdAt).reduce((a, b) => a.isBefore(b) ? a : b).toIso8601String()
          : null,
    };
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(hours: 1), (_) {
      cleanupOldBlocks();
    });
  }

  /// Generate unique block ID
  String _generateBlockId() {
    return 'block_${DateTime.now().millisecondsSinceEpoch}_${_blockLifecycles.length}';
  }

  /// Get next block index for session
  int _getNextBlockIndex(String sessionId) {
    final sessionBlocks = getSessionBlocks(sessionId);
    return sessionBlocks.length;
  }

  /// Check if command requires fullscreen modal
  bool _requiresFullscreen(String command) {
    final fullscreenCommands = [
      'vi', 'vim', 'nvim', 'nano', 'emacs',
      'top', 'htop', 'btop', 'iotop',
      'watch', 'tail -f', 'less', 'more',
      'man', 'tmux', 'screen',
      'git log', 'git diff --no-pager',
    ];
    
    final cmd = command.toLowerCase().trim();
    return fullscreenCommands.any((fc) => cmd.startsWith(fc));
  }

  /// Emit lifecycle event
  void _emitEvent(BlockLifecycleEvent event) {
    _eventController.add(event);
  }

  /// Dispose service
  void dispose() {
    _cleanupTimer?.cancel();
    _eventController.close();
    _blockLifecycles.clear();
  }
}

/// Terminal block lifecycle tracker
class TerminalBlockLifecycle {
  final String blockId;
  final String sessionId;
  final DateTime createdAt;
  
  DateTime? executionStartedAt;
  DateTime? executionCompletedAt;
  String? executionError;
  int? exitCode;
  bool isInteractive = false;
  bool isArchived = false;
  final List<EnhancedTerminalBlockError> errors = [];
  final StringBuffer outputBuffer = StringBuffer();
  
  TerminalBlockLifecycle({
    required this.blockId,
    required this.sessionId,
    required this.createdAt,
  });

  /// Current block status
  TerminalBlockStatus get status {
    if (isArchived) {
      return executionError != null 
          ? TerminalBlockStatus.failed
          : TerminalBlockStatus.completed;
    }
    
    if (executionStartedAt == null) {
      return TerminalBlockStatus.pending;
    }
    
    if (executionCompletedAt == null) {
      return isInteractive 
          ? TerminalBlockStatus.interactive
          : TerminalBlockStatus.running;
    }
    
    if (executionError != null) {
      return TerminalBlockStatus.failed;
    }
    
    return TerminalBlockStatus.completed;
  }

  /// Execution duration
  Duration? get executionDuration {
    if (executionStartedAt == null) return null;
    final endTime = executionCompletedAt ?? DateTime.now();
    return endTime.difference(executionStartedAt!);
  }

  /// Total lifetime
  Duration get lifetime {
    return DateTime.now().difference(createdAt);
  }

  /// Start execution
  void startExecution() {
    executionStartedAt = DateTime.now();
  }

  /// Complete execution
  void completeExecution({
    bool success = true,
    int? exitCode,
    String? error,
  }) {
    executionCompletedAt = DateTime.now();
    this.exitCode = exitCode;
    if (!success || error != null) {
      executionError = error ?? 'Command failed';
    }
  }

  /// Cancel execution
  void cancelExecution({String? reason}) {
    executionCompletedAt = DateTime.now();
    executionError = reason ?? 'Cancelled by user';
  }

  /// Add output
  void addOutput(String output, {bool append = true}) {
    if (append) {
      outputBuffer.write(output);
    } else {
      outputBuffer.clear();
      outputBuffer.write(output);
    }
  }

  /// Add error
  void addError(EnhancedTerminalBlockError error) {
    errors.add(error);
  }

  /// Set interactive state
  void setInteractive(bool interactive) {
    isInteractive = interactive;
  }

  /// Archive block
  void archive() {
    isArchived = true;
    if (executionStartedAt != null && executionCompletedAt == null) {
      completeExecution(success: false, error: 'Block archived');
    }
  }

  /// Get output
  String get output => outputBuffer.toString();

  /// Has errors
  bool get hasErrors => errors.isNotEmpty;

  /// Was successful
  bool get wasSuccessful => status == TerminalBlockStatus.completed && !hasErrors;

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'blockId': blockId,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'executionStartedAt': executionStartedAt?.toIso8601String(),
      'executionCompletedAt': executionCompletedAt?.toIso8601String(),
      'executionError': executionError,
      'exitCode': exitCode,
      'isInteractive': isInteractive,
      'isArchived': isArchived,
      'status': status.name,
      'errors': errors.map((e) => e.toJson()).toList(),
      'outputLength': output.length,
      'executionDurationMs': executionDuration?.inMilliseconds,
      'lifetimeMs': lifetime.inMilliseconds,
      'hasErrors': hasErrors,
      'wasSuccessful': wasSuccessful,
    };
  }
}

/// Block lifecycle event types
enum BlockLifecycleEventType {
  created,
  executionStarted,
  outputUpdated,
  executionCompleted,
  executionCancelled,
  errorAdded,
  becameInteractive,
  leftInteractive,
  archived,
  deleted,
}

/// Block lifecycle event
class BlockLifecycleEvent {
  final BlockLifecycleEventType type;
  final String blockId;
  final String sessionId;
  final DateTime timestamp;
  final Map<String, dynamic>? data;

  const BlockLifecycleEvent({
    required this.type,
    required this.blockId,
    required this.sessionId,
    required this.timestamp,
    this.data,
  });

  @override
  String toString() {
    return 'BlockLifecycleEvent{type: $type, blockId: $blockId, sessionId: $sessionId}';
  }
}

/// Block lifecycle configuration
class BlockLifecycleConfig {
  final Duration maxBlockAge;
  final Duration cleanupInterval;
  final int maxBlocksPerSession;
  final bool autoArchiveCompletedBlocks;
  final bool enablePerformanceTracking;

  const BlockLifecycleConfig({
    this.maxBlockAge = const Duration(hours: 24),
    this.cleanupInterval = const Duration(hours: 1),
    this.maxBlocksPerSession = 1000,
    this.autoArchiveCompletedBlocks = true,
    this.enablePerformanceTracking = true,
  });
}