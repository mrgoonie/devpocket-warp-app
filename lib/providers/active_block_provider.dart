import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../services/active_block_manager.dart';
import '../services/pty_focus_manager.dart';
import '../services/persistent_process_detector.dart';

/// Provider for the ActiveBlockManager singleton
final activeBlockManagerProvider = Provider<ActiveBlockManager>((ref) {
  return ActiveBlockManager.instance;
});

/// Provider for the PTYFocusManager singleton
final ptyFocusManagerProvider = Provider<PTYFocusManager>((ref) {
  return PTYFocusManager.instance;
});

/// Provider for the PersistentProcessDetector singleton
final persistentProcessDetectorProvider = Provider<PersistentProcessDetector>((ref) {
  return PersistentProcessDetector.instance;
});

/// State notifier for tracking active blocks across the app
class ActiveBlockState {
  final List<String> activeBlockIds;
  final String? focusedBlockId;
  final Map<String, String> sessionActiveBlocks; // sessionId -> blockId
  final DateTime lastUpdated;

  const ActiveBlockState({
    this.activeBlockIds = const [],
    this.focusedBlockId,
    this.sessionActiveBlocks = const {},
    required this.lastUpdated,
  });

  ActiveBlockState copyWith({
    List<String>? activeBlockIds,
    String? focusedBlockId,
    Map<String, String>? sessionActiveBlocks,
    DateTime? lastUpdated,
  }) {
    return ActiveBlockState(
      activeBlockIds: activeBlockIds ?? this.activeBlockIds,
      focusedBlockId: focusedBlockId ?? this.focusedBlockId,
      sessionActiveBlocks: sessionActiveBlocks ?? this.sessionActiveBlocks,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Check if any blocks are active
  bool get hasActiveBlocks => activeBlockIds.isNotEmpty;

  /// Check if a specific block is active
  bool isBlockActive(String blockId) => activeBlockIds.contains(blockId);

  /// Get active block for a session
  String? getActiveBlockForSession(String sessionId) => sessionActiveBlocks[sessionId];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveBlockState &&
          runtimeType == other.runtimeType &&
          listEquals(activeBlockIds, other.activeBlockIds) &&
          focusedBlockId == other.focusedBlockId &&
          mapEquals(sessionActiveBlocks, other.sessionActiveBlocks);

  @override
  int get hashCode =>
      activeBlockIds.hashCode ^
      focusedBlockId.hashCode ^
      sessionActiveBlocks.hashCode;

  @override
  String toString() {
    return 'ActiveBlockState{activeBlocks: ${activeBlockIds.length}, focused: $focusedBlockId, sessions: ${sessionActiveBlocks.length}}';
  }
}

/// State notifier for managing active block state
class ActiveBlockNotifier extends StateNotifier<ActiveBlockState> {
  ActiveBlockNotifier(this._activeBlockManager, this._focusManager)
      : super(ActiveBlockState(lastUpdated: DateTime.now())) {
    _initialize();
  }

  final ActiveBlockManager _activeBlockManager;
  final PTYFocusManager _focusManager;

  void _initialize() {
    // Listen to active block events
    _activeBlockManager.events.listen((event) {
      _handleActiveBlockEvent(event);
    });

    // Listen to focus events
    _focusManager.events.listen((event) {
      _handleFocusEvent(event);
    });

    // Initialize with current state
    _updateState();
  }

  void _handleActiveBlockEvent(ActiveBlockEvent event) {
    switch (event.type) {
      case ActiveBlockEventType.blockActivated:
      case ActiveBlockEventType.blockDeactivated:
      case ActiveBlockEventType.blockTerminated:
        _updateState();
        break;
      default:
        break;
    }
  }

  void _handleFocusEvent(FocusEvent event) {
    switch (event.type) {
      case FocusEventType.focusGained:
      case FocusEventType.focusLost:
        _updateState();
        break;
      default:
        break;
    }
  }

  void _updateState() {
    final stats = _activeBlockManager.getStats();
    final focusState = _focusManager.currentState;

    state = state.copyWith(
      activeBlockIds: _activeBlockManager.activeBlockIds,
      focusedBlockId: focusState.focusedBlockId,
      sessionActiveBlocks: Map<String, String>.from(stats['sessionMappings'] ?? {}),
      lastUpdated: DateTime.now(),
    );
  }

  /// Focus a specific block
  bool focusBlock(String blockId) {
    return _focusManager.focusBlock(blockId);
  }

  /// Clear focus and return to main input
  void focusMainInput() {
    _focusManager.focusMainInput();
  }

  /// Terminate an active block
  Future<bool> terminateBlock(String blockId) async {
    return await _activeBlockManager.terminateBlock(blockId);
  }

  /// Get active blocks for a session
  List<String> getActiveBlocksForSession(String sessionId) {
    return _activeBlockManager.getActiveBlocksForSession(sessionId);
  }

  /// Check if a block can accept input
  bool canBlockAcceptInput(String blockId) {
    return _activeBlockManager.canBlockAcceptInput(blockId);
  }

  /// Send input to a block
  bool sendInputToBlock(String blockId, String input) {
    return _activeBlockManager.sendInputToBlock(blockId, input);
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'state': state.toString(),
      'activeBlockManager': _activeBlockManager.getStats(),
      'focusManager': _focusManager.getFocusDebugInfo(),
    };
  }
}

/// Provider for the active block state notifier
final activeBlockNotifierProvider = StateNotifierProvider<ActiveBlockNotifier, ActiveBlockState>((ref) {
  final activeBlockManager = ref.watch(activeBlockManagerProvider);
  final focusManager = ref.watch(ptyFocusManagerProvider);
  return ActiveBlockNotifier(activeBlockManager, focusManager);
});

/// Provider for active block state
final activeBlockStateProvider = Provider<ActiveBlockState>((ref) {
  return ref.watch(activeBlockNotifierProvider);
});

/// Provider for checking if any blocks are active
final hasActiveBlocksProvider = Provider<bool>((ref) {
  return ref.watch(activeBlockStateProvider).hasActiveBlocks;
});

/// Provider for getting the focused block ID
final focusedBlockIdProvider = Provider<String?>((ref) {
  return ref.watch(activeBlockStateProvider).focusedBlockId;
});

/// Provider for getting active blocks for a specific session
final activeBlocksForSessionProvider = Provider.family<List<String>, String>((ref, sessionId) {
  final notifier = ref.watch(activeBlockNotifierProvider.notifier);
  return notifier.getActiveBlocksForSession(sessionId);
});

/// Provider for checking if a block is active
final isBlockActiveProvider = Provider.family<bool, String>((ref, blockId) {
  return ref.watch(activeBlockStateProvider).isBlockActive(blockId);
});

/// Provider for checking if a block can accept input
final canBlockAcceptInputProvider = Provider.family<bool, String>((ref, blockId) {
  final notifier = ref.watch(activeBlockNotifierProvider.notifier);
  return notifier.canBlockAcceptInput(blockId);
});

/// Provider for terminal focus state
final terminalFocusStateProvider = Provider<FocusState>((ref) {
  final focusManager = ref.watch(ptyFocusManagerProvider);
  return focusManager.currentState;
});

/// Provider for input routing suggestions
final inputRoutingSuggestionsProvider = Provider<List<String>>((ref) {
  final focusManager = ref.watch(ptyFocusManagerProvider);
  return focusManager.getInputRoutingSuggestions();
});