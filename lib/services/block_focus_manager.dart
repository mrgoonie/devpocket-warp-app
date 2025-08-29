import 'package:flutter/foundation.dart';
import 'dart:async';

import 'active_block_models.dart';

/// Manages focus state and input routing for active blocks
class BlockFocusManager {
  final StreamController<ActiveBlockEvent> _eventController;
  
  String? _focusedBlockId;
  final Map<String, String> _sessionActiveBlocks = {}; // sessionId -> blockId
  
  BlockFocusManager({required StreamController<ActiveBlockEvent> eventController})
      : _eventController = eventController;

  /// Get currently focused block ID
  String? get focusedBlockId => _focusedBlockId;

  /// Get active block for a session
  String? getActiveBlockForSession(String sessionId) {
    return _sessionActiveBlocks[sessionId];
  }

  /// Set active block for a session
  void setActiveBlockForSession(String sessionId, String blockId) {
    _sessionActiveBlocks[sessionId] = blockId;
  }

  /// Remove session mapping
  void removeSessionMapping(String sessionId) {
    _sessionActiveBlocks.remove(sessionId);
  }

  /// Remove mappings by block ID
  void removeBlockMapping(String blockId) {
    _sessionActiveBlocks.removeWhere((_, activeBlockId) => activeBlockId == blockId);
  }

  /// Focus a specific block for input routing
  void focusBlock(String blockId, {String? sessionId}) {
    final previousFocus = _focusedBlockId;
    _focusedBlockId = blockId;

    _emitEvent(ActiveBlockEvent(
      type: ActiveBlockEventType.focusChanged,
      blockId: blockId,
      sessionId: sessionId,
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

    debugPrint('Focus cleared (was: $previousFocus)');
  }

  /// Check if a block is currently focused
  bool isBlockFocused(String blockId) {
    return _focusedBlockId == blockId;
  }

  /// Auto-focus strategy for new blocks
  void applyAutoFocus(String blockId, {
    required bool requiresInput,
    required bool isPersistent,
    String? sessionId,
  }) {
    // Auto-focus interactive processes
    if (requiresInput) {
      focusBlock(blockId, sessionId: sessionId);
      return;
    }

    // Auto-focus persistent processes if no current focus
    if (isPersistent && _focusedBlockId == null) {
      focusBlock(blockId, sessionId: sessionId);
      return;
    }

    debugPrint('No auto-focus applied for block $blockId');
  }

  /// Get focus routing information
  FocusRoutingInfo getFocusInfo() {
    return FocusRoutingInfo(
      focusedBlockId: _focusedBlockId,
      sessionMappings: Map.from(_sessionActiveBlocks),
      totalMappings: _sessionActiveBlocks.length,
    );
  }

  /// Handle session cleanup
  void cleanupSession(String sessionId) {
    final wasActive = _sessionActiveBlocks.containsKey(sessionId);
    final activeBlockId = _sessionActiveBlocks[sessionId];
    
    removeSessionMapping(sessionId);
    
    // Clear focus if the active block for this session was focused
    if (_focusedBlockId == activeBlockId) {
      clearFocus();
    }

    if (wasActive) {
      debugPrint('Cleaned up session mapping: $sessionId -> $activeBlockId');
    }
  }

  /// Handle block deactivation
  void handleBlockDeactivation(String blockId) {
    // Remove from session mappings
    removeBlockMapping(blockId);

    // Clear focus if this block was focused
    if (_focusedBlockId == blockId) {
      clearFocus();
    }

    _emitEvent(ActiveBlockEvent(
      type: ActiveBlockEventType.blockDeactivated,
      blockId: blockId,
      message: 'Block deactivated and focus cleared',
      timestamp: DateTime.now(),
    ));
  }

  /// Get statistics about focus management
  Map<String, dynamic> getFocusStats() {
    return {
      'focusedBlock': _focusedBlockId,
      'sessionMappings': Map.from(_sessionActiveBlocks),
      'totalSessionMappings': _sessionActiveBlocks.length,
      'hasFocus': _focusedBlockId != null,
    };
  }

  /// Reset all focus state
  void resetAll() {
    _focusedBlockId = null;
    _sessionActiveBlocks.clear();
    debugPrint('All focus state reset');
  }

  /// Emit an event through the provided controller
  void _emitEvent(ActiveBlockEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }
}

/// Focus routing information
class FocusRoutingInfo {
  final String? focusedBlockId;
  final Map<String, String> sessionMappings;
  final int totalMappings;

  const FocusRoutingInfo({
    required this.focusedBlockId,
    required this.sessionMappings,
    required this.totalMappings,
  });

  @override
  String toString() {
    return 'FocusRoutingInfo{focused: $focusedBlockId, mappings: $totalMappings}';
  }
}