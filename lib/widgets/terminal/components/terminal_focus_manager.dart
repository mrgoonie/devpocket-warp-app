import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../../services/pty_focus_manager.dart';
import '../../../services/active_block_manager.dart';
import '../../../services/interactive_command_manager.dart';

/// Manages focus state and coordination for terminal components
/// Extracted from ssh_terminal_widget.dart to handle focus management
class TerminalFocusManager {
  // Service instances
  final PTYFocusManager _ptyFocusManager = PTYFocusManager.instance;
  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final InteractiveCommandManager _interactiveManager = InteractiveCommandManager.instance;
  
  // Focus state
  String? _focusedBlockId;
  bool _isInteractiveMode = false;
  bool _hasFocus = false;
  
  // Controllers
  final ScrollController _blocksScrollController = ScrollController();
  
  // Callbacks
  Function(String?)? onFocusedBlockChanged;
  Function(bool)? onInteractiveModeChanged;
  Function(bool)? onFocusChanged;
  Function(String)? onError;
  Function()? onStateChanged;
  
  // Getters
  String? get focusedBlockId => _focusedBlockId;
  bool get isInteractiveMode => _isInteractiveMode;
  bool get hasFocus => _hasFocus;
  ScrollController get blocksScrollController => _blocksScrollController;
  
  /// Initialize focus manager
  void initialize({
    Function(String?)? onFocusedBlockChanged,
    Function(bool)? onInteractiveModeChanged,
    Function(bool)? onFocusChanged,
    Function(String)? onError,
    Function()? onStateChanged,
  }) {
    this.onFocusedBlockChanged = onFocusedBlockChanged;
    this.onInteractiveModeChanged = onInteractiveModeChanged;
    this.onFocusChanged = onFocusChanged;
    this.onError = onError;
    this.onStateChanged = onStateChanged;
    
    // Initialize PTY focus manager
    _ptyFocusManager.initialize();
    
    debugPrint('TerminalFocusManager initialized');
  }
  
  /// Handle focus event from PTY focus manager
  void handleFocusEvent(FocusEvent event) {
    try {
      switch (event.type) {
        case FocusEventType.focused:
          _handleFocusGained(event.blockId);
          break;
        case FocusEventType.unfocused:
          _handleFocusLost(event.blockId);
          break;
        case FocusEventType.requestFocus:
          _handleFocusRequested(event.blockId);
          break;
        case FocusEventType.releaseFocus:
          _handleFocusReleased(event.blockId);
          break;
      }
    } catch (e) {
      final errorMsg = 'Error handling focus event: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Handle active block event for focus coordination
  void handleActiveBlockEvent(ActiveBlockEvent event) {
    try {
      switch (event.type) {
        case ActiveBlockEventType.focused:
          _setFocusedBlock(event.blockId);
          break;
        case ActiveBlockEventType.unfocused:
          if (_focusedBlockId == event.blockId) {
            _setFocusedBlock(null);
          }
          break;
        case ActiveBlockEventType.created:
          // Auto-focus new blocks if appropriate
          _handleNewBlockCreated(event.blockId);
          break;
        case ActiveBlockEventType.completed:
        case ActiveBlockEventType.failed:
          // Release focus when blocks complete/fail
          _handleBlockCompleted(event.blockId);
          break;
        case ActiveBlockEventType.updated:
          // Handle block updates that might affect focus
          _handleBlockUpdated(event.blockId);
          break;
      }
    } catch (e) {
      final errorMsg = 'Error handling active block event for focus: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Request focus for a specific block
  void requestFocus(String blockId) {
    try {
      debugPrint('Requesting focus for block: $blockId');
      _ptyFocusManager.requestFocus(blockId);
      _setFocusedBlock(blockId);
      _scrollToBlock(blockId);
    } catch (e) {
      final errorMsg = 'Error requesting focus: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Release focus from current block
  void releaseFocus() {
    try {
      if (_focusedBlockId != null) {
        debugPrint('Releasing focus from block: $_focusedBlockId');
        _ptyFocusManager.releaseFocus(_focusedBlockId!);
        _setFocusedBlock(null);
      }
    } catch (e) {
      final errorMsg = 'Error releasing focus: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Set interactive mode state
  void setInteractiveMode(bool interactive, {String? blockId}) {
    if (_isInteractiveMode != interactive) {
      _isInteractiveMode = interactive;
      debugPrint('Interactive mode changed: $interactive for block: $blockId');
      
      if (interactive && blockId != null) {
        _setFocusedBlock(blockId);
        _scrollToBlock(blockId);
      }
      
      onInteractiveModeChanged?.call(interactive);
      onStateChanged?.call();
    }
  }
  
  /// Set overall focus state
  void setHasFocus(bool hasFocus) {
    if (_hasFocus != hasFocus) {
      _hasFocus = hasFocus;
      debugPrint('Terminal focus changed: $hasFocus');
      onFocusChanged?.call(hasFocus);
      onStateChanged?.call();
    }
  }
  
  /// Scroll to a specific block
  void _scrollToBlock(String blockId) {
    try {
      // This would typically scroll the blocks scroll controller
      // to bring the specified block into view
      if (_blocksScrollController.hasClients) {
        // Scroll to bottom if it's a new block (simplified approach)
        _blocksScrollController.animateTo(
          _blocksScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        debugPrint('Scrolled to block: $blockId');
      }
    } catch (e) {
      debugPrint('Error scrolling to block: $e');
    }
  }
  
  // Private focus handling methods
  
  void _handleFocusGained(String? blockId) {
    debugPrint('Focus gained: $blockId');
    _setFocusedBlock(blockId);
    setHasFocus(true);
  }
  
  void _handleFocusLost(String? blockId) {
    debugPrint('Focus lost: $blockId');
    if (_focusedBlockId == blockId) {
      _setFocusedBlock(null);
    }
    setHasFocus(false);
  }
  
  void _handleFocusRequested(String? blockId) {
    debugPrint('Focus requested: $blockId');
    if (blockId != null) {
      _setFocusedBlock(blockId);
      _scrollToBlock(blockId);
    }
  }
  
  void _handleFocusReleased(String? blockId) {
    debugPrint('Focus released: $blockId');
    if (_focusedBlockId == blockId) {
      _setFocusedBlock(null);
    }
  }
  
  void _handleNewBlockCreated(String blockId) {
    debugPrint('New block created: $blockId');
    // Auto-focus new blocks if no other block has focus
    if (_focusedBlockId == null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        requestFocus(blockId);
      });
    }
  }
  
  void _handleBlockCompleted(String blockId) {
    debugPrint('Block completed: $blockId');
    // Release focus if this was the focused block
    if (_focusedBlockId == blockId) {
      releaseFocus();
    }
  }
  
  void _handleBlockUpdated(String blockId) {
    debugPrint('Block updated: $blockId');
    // Handle any focus-related updates
    if (_focusedBlockId == blockId && _isInteractiveMode) {
      // Ensure focus is maintained for interactive blocks
      _scrollToBlock(blockId);
    }
  }
  
  void _setFocusedBlock(String? blockId) {
    if (_focusedBlockId != blockId) {
      final previousBlock = _focusedBlockId;
      _focusedBlockId = blockId;
      
      debugPrint('Focused block changed: $previousBlock -> $blockId');
      onFocusedBlockChanged?.call(blockId);
      onStateChanged?.call();
    }
  }
  
  /// Check if a block is currently focused
  bool isBlockFocused(String blockId) {
    return _focusedBlockId == blockId;
  }
  
  /// Get focus manager statistics
  Map<String, dynamic> getStats() {
    return {
      'focusedBlockId': _focusedBlockId,
      'isInteractiveMode': _isInteractiveMode,
      'hasFocus': _hasFocus,
      'scrollControllerAttached': _blocksScrollController.hasClients,
      'scrollPosition': _blocksScrollController.hasClients ? _blocksScrollController.offset : null,
      'hasCallbacks': {
        'onFocusedBlockChanged': onFocusedBlockChanged != null,
        'onInteractiveModeChanged': onInteractiveModeChanged != null,
        'onFocusChanged': onFocusChanged != null,
        'onError': onError != null,
        'onStateChanged': onStateChanged != null,
      },
    };
  }
  
  /// Reset focus manager state
  void reset() {
    _focusedBlockId = null;
    _isInteractiveMode = false;
    _hasFocus = false;
    
    // Reset scroll position
    if (_blocksScrollController.hasClients) {
      _blocksScrollController.jumpTo(0);
    }
    
    debugPrint('TerminalFocusManager reset');
  }
  
  /// Cleanup resources
  void dispose() {
    _blocksScrollController.dispose();
    reset();
    debugPrint('TerminalFocusManager disposed');
  }
}