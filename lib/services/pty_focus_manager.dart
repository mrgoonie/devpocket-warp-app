import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'active_block_manager.dart';
import 'persistent_process_detector.dart';

/// Keyboard input routing destination
enum InputDestination {
  mainInput,      // Route to main terminal input field
  activeBlock,    // Route to currently focused active block
  none,          // Don't route input
}

/// Control key sequences that can be intercepted
enum ControlKey {
  ctrlC,         // Ctrl+C - Interrupt
  ctrlD,         // Ctrl+D - EOF
  ctrlZ,         // Ctrl+Z - Suspend
  tab,           // Tab - Autocomplete
  enter,         // Enter - Execute/Submit
  escape,        // Escape - Cancel/Exit
  arrowUp,       // Arrow Up - History/Navigation
  arrowDown,     // Arrow Down - History/Navigation
  arrowLeft,     // Arrow Left - Navigation
  arrowRight,    // Arrow Right - Navigation
}

/// Focus state information
class FocusState {
  final String? focusedBlockId;
  final InputDestination destination;
  final bool canAcceptInput;
  final DateTime lastChanged;
  final Map<String, dynamic> metadata;

  const FocusState({
    this.focusedBlockId,
    required this.destination,
    this.canAcceptInput = false,
    required this.lastChanged,
    this.metadata = const {},
  });

  @override
  String toString() {
    return 'FocusState{blockId: $focusedBlockId, destination: $destination, canAcceptInput: $canAcceptInput}';
  }
}

/// Focus change events
enum FocusEventType {
  focusGained,
  focusLost,
  inputRouted,
  controlSignal,
  error,
}

class FocusEvent {
  final FocusEventType type;
  final String? blockId;
  final InputDestination? destination;
  final String? input;
  final ControlKey? controlKey;
  final String? message;
  final DateTime timestamp;

  const FocusEvent({
    required this.type,
    this.blockId,
    this.destination,
    this.input,
    this.controlKey,
    this.message,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'FocusEvent{type: $type, blockId: $blockId, destination: $destination, message: $message}';
  }
}

/// Service for managing PTY focus and routing keyboard input to appropriate destinations
class PTYFocusManager {
  static PTYFocusManager? _instance;
  static PTYFocusManager get instance => _instance ??= PTYFocusManager._();

  PTYFocusManager._();

  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final StreamController<FocusEvent> _eventController = StreamController.broadcast();
  
  FocusState _currentState = FocusState(
    destination: InputDestination.mainInput,
    lastChanged: DateTime.now(),
  );

  StreamSubscription<ActiveBlockEvent>? _activeBlockSubscription;

  /// Stream of focus events
  Stream<FocusEvent> get events => _eventController.stream;

  /// Current focus state
  FocusState get currentState => _currentState;

  /// Check if focus manager is initialized
  bool _isInitialized = false;

  /// Initialize the focus manager
  void initialize() {
    if (_isInitialized) return;

    // Listen to active block changes
    _activeBlockSubscription = _activeBlockManager.events.listen(_handleActiveBlockEvent);

    _isInitialized = true;
    debugPrint('PTYFocusManager initialized');
  }

  /// Handle active block events
  void _handleActiveBlockEvent(ActiveBlockEvent event) {
    switch (event.type) {
      case ActiveBlockEventType.blockActivated:
        if (event.blockId != null) {
          final connection = _activeBlockManager.getConnection(event.blockId!);
          if (connection?.processInfo.requiresInput == true) {
            _updateFocus(
              blockId: event.blockId,
              destination: InputDestination.activeBlock,
              canAcceptInput: true,
            );
          }
        }
        break;

      case ActiveBlockEventType.blockDeactivated:
      case ActiveBlockEventType.blockTerminated:
        if (_currentState.focusedBlockId == event.blockId) {
          _updateFocus(
            blockId: null,
            destination: InputDestination.mainInput,
            canAcceptInput: false,
          );
        }
        break;

      case ActiveBlockEventType.focusChanged:
        if (event.blockId != null) {
          final connection = _activeBlockManager.getConnection(event.blockId!);
          _updateFocus(
            blockId: event.blockId,
            destination: InputDestination.activeBlock,
            canAcceptInput: connection?.processInfo.requiresInput == true,
          );
        }
        break;

      default:
        // Handle other events if needed
        break;
    }
  }

  /// Update focus state
  void _updateFocus({
    String? blockId,
    required InputDestination destination,
    required bool canAcceptInput,
    Map<String, dynamic>? metadata,
  }) {
    final previousState = _currentState;
    
    _currentState = FocusState(
      focusedBlockId: blockId,
      destination: destination,
      canAcceptInput: canAcceptInput,
      lastChanged: DateTime.now(),
      metadata: metadata ?? {},
    );

    // Emit focus events
    if (previousState.focusedBlockId != blockId) {
      if (previousState.focusedBlockId != null) {
        _emitEvent(FocusEvent(
          type: FocusEventType.focusLost,
          blockId: previousState.focusedBlockId,
          destination: previousState.destination,
          timestamp: DateTime.now(),
        ));
      }

      if (blockId != null) {
        _emitEvent(FocusEvent(
          type: FocusEventType.focusGained,
          blockId: blockId,
          destination: destination,
          timestamp: DateTime.now(),
        ));
      }
    }

    debugPrint('Focus updated: $blockId -> $destination (canAcceptInput: $canAcceptInput)');
  }

  /// Focus on a specific block
  bool focusBlock(String blockId) {
    if (!_activeBlockManager.isBlockActive(blockId)) {
      debugPrint('Cannot focus inactive block: $blockId');
      return false;
    }

    _activeBlockManager.focusBlock(blockId);
    return true;
  }

  /// Clear focus and route input to main input field
  void focusMainInput() {
    _activeBlockManager.clearFocus();
    _updateFocus(
      blockId: null,
      destination: InputDestination.mainInput,
      canAcceptInput: false,
    );
  }

  /// Route text input to appropriate destination
  bool handleTextInput(String input) {
    if (!_isInitialized) {
      debugPrint('PTYFocusManager not initialized');
      return false;
    }

    switch (_currentState.destination) {
      case InputDestination.mainInput:
        // Input should go to main terminal input field
        // This is handled by the UI layer
        _emitEvent(FocusEvent(
          type: FocusEventType.inputRouted,
          destination: InputDestination.mainInput,
          input: input,
          timestamp: DateTime.now(),
        ));
        return false; // Let UI handle it

      case InputDestination.activeBlock:
        if (_currentState.focusedBlockId != null && _currentState.canAcceptInput) {
          final success = _activeBlockManager.sendInputToBlock(
            _currentState.focusedBlockId!,
            input,
          );
          
          _emitEvent(FocusEvent(
            type: FocusEventType.inputRouted,
            blockId: _currentState.focusedBlockId,
            destination: InputDestination.activeBlock,
            input: input,
            message: success ? 'Input sent successfully' : 'Failed to send input',
            timestamp: DateTime.now(),
          ));
          
          return success;
        }
        break;

      case InputDestination.none:
        // Input is ignored
        return false;
    }

    return false;
  }

  /// Handle control key sequences
  bool handleControlKey(ControlKey key) {
    if (!_isInitialized) {
      debugPrint('PTYFocusManager not initialized');
      return false;
    }

    final signal = _mapControlKeyToSignal(key);
    bool handled = false;

    switch (_currentState.destination) {
      case InputDestination.activeBlock:
        if (_currentState.focusedBlockId != null && signal != null) {
          handled = _activeBlockManager.sendControlSignal(
            _currentState.focusedBlockId!,
            signal,
          );
        }
        break;

      case InputDestination.mainInput:
        // Special handling for main input context
        switch (key) {
          case ControlKey.ctrlC:
            // Cancel current input or interrupt
            handled = true;
            break;
          case ControlKey.tab:
            // Autocomplete - let UI handle
            handled = false;
            break;
          default:
            handled = false;
        }
        break;

      case InputDestination.none:
        handled = false;
        break;
    }

    _emitEvent(FocusEvent(
      type: FocusEventType.controlSignal,
      blockId: _currentState.focusedBlockId,
      destination: _currentState.destination,
      controlKey: key,
      message: handled ? 'Control key handled' : 'Control key not handled',
      timestamp: DateTime.now(),
    ));

    return handled;
  }

  /// Map control keys to terminal signals
  String? _mapControlKeyToSignal(ControlKey key) {
    switch (key) {
      case ControlKey.ctrlC:
        return 'ctrl+c';
      case ControlKey.ctrlD:
        return 'ctrl+d';
      case ControlKey.ctrlZ:
        return 'ctrl+z';
      default:
        return null;
    }
  }

  /// Handle raw keyboard events from Flutter
  bool handleRawKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return false;

    final key = _parseRawKeyEvent(event);
    if (key != null) {
      return handleControlKey(key);
    }

    return false;
  }

  /// Parse Flutter RawKeyEvent to ControlKey  
  ControlKey? _parseRawKeyEvent(RawKeyEvent event) {
    // Simplified key parsing - focus on essential keys
    if (event.isControlPressed || event.isMetaPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyC) {
        return ControlKey.ctrlC;
      } else if (event.logicalKey == LogicalKeyboardKey.keyD) {
        return ControlKey.ctrlD;
      } else if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        return ControlKey.ctrlZ;
      }
    }
    
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      return ControlKey.tab;
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      return ControlKey.enter;
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      return ControlKey.escape;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return ControlKey.arrowUp;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return ControlKey.arrowDown;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return ControlKey.arrowLeft;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      return ControlKey.arrowRight;
    }

    return null;
  }

  /// Get input routing suggestions for UI
  List<String> getInputRoutingSuggestions() {
    final suggestions = <String>[];
    
    switch (_currentState.destination) {
      case InputDestination.mainInput:
        suggestions.add('Type commands here');
        if (_activeBlockManager.activeBlockIds.isNotEmpty) {
          suggestions.add('Tap active blocks to interact');
        }
        break;

      case InputDestination.activeBlock:
        if (_currentState.focusedBlockId != null) {
          final connection = _activeBlockManager.getConnection(_currentState.focusedBlockId!);
          if (connection != null) {
            switch (connection.processInfo.type) {
              case ProcessType.repl:
                suggestions.add('Enter ${connection.processInfo.processName ?? "REPL"} commands');
                suggestions.add('Press Ctrl+D to exit');
                break;
              case ProcessType.interactive:
                suggestions.add('Use arrow keys to navigate');
                suggestions.add('Press Ctrl+C to interrupt');
                break;
              case ProcessType.devServer:
              case ProcessType.watcher:
              case ProcessType.buildTool:
              case ProcessType.persistent:
                suggestions.add('Process is running...');
                suggestions.add('Press Ctrl+C to terminate');
                break;
              case ProcessType.oneshot:
                suggestions.add('Process is running...');
                break;
            }
          }
        }
        break;

      case InputDestination.none:
        suggestions.add('No input accepted');
        break;
    }

    return suggestions;
  }

  /// Get focus state for debugging
  Map<String, dynamic> getFocusDebugInfo() {
    return {
      'currentState': {
        'focusedBlockId': _currentState.focusedBlockId,
        'destination': _currentState.destination.name,
        'canAcceptInput': _currentState.canAcceptInput,
        'lastChanged': _currentState.lastChanged.toIso8601String(),
      },
      'activeBlocks': _activeBlockManager.activeBlockIds,
      'activeBlockManager': _activeBlockManager.getStats(),
      'initialized': _isInitialized,
    };
  }

  /// Emit a focus event
  void _emitEvent(FocusEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Dispose all resources
  void dispose() {
    _activeBlockSubscription?.cancel();
    _eventController.close();
    _isInitialized = false;
    debugPrint('PTYFocusManager disposed');
  }
}