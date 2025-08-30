import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../../services/active_block_manager.dart';
import '../../../services/active_block_models.dart';
import '../../../services/persistent_process_detector.dart';
import '../../../services/command_type_detector.dart';
import '../../../services/terminal_text_encoding_service.dart';
import '../../../models/enhanced_terminal_models.dart';

/// Manages state and service integration for terminal block widgets
/// Handles active block management, process detection, and output processing
class TerminalBlockStateManager {
  final String blockId;
  final String? sessionId;
  final EnhancedTerminalBlockData initialBlockData;
  
  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  final CommandTypeDetector _commandTypeDetector = CommandTypeDetector.instance;
  final TerminalTextEncodingService _encodingService = TerminalTextEncodingService.instance;
  
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<ActiveBlockEvent>? _activeBlockSubscription;
  
  final StringBuffer _outputBuffer = StringBuffer();
  String _processedOutput = '';
  
  // State tracking
  bool _isActiveBlock = false;
  bool _isFocused = false;
  ProcessInfo? _processInfo;
  CommandTypeInfo? _commandTypeInfo;
  CommandType _commandType = CommandType.oneShot;
  bool _showFullCommand = false;

  // Event notifiers
  final ValueNotifier<String> _outputNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _activeBlockNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _focusNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<ProcessInfo?> _processInfoNotifier = ValueNotifier<ProcessInfo?>(null);

  TerminalBlockStateManager({
    required this.blockId,
    required this.initialBlockData,
    this.sessionId,
  });

  // Getters for current state
  bool get isActiveBlock => _isActiveBlock;
  bool get isFocused => _isFocused;
  ProcessInfo? get processInfo => _processInfo;
  CommandTypeInfo? get commandTypeInfo => _commandTypeInfo;
  CommandType get commandType => _commandType;
  String get processedOutput => _processedOutput;
  bool get showFullCommand => _showFullCommand;

  // Value notifiers for reactive updates
  ValueListenable<String> get outputNotifier => _outputNotifier;
  ValueListenable<bool> get activeBlockNotifier => _activeBlockNotifier;
  ValueListenable<bool> get focusNotifier => _focusNotifier;
  ValueListenable<ProcessInfo?> get processInfoNotifier => _processInfoNotifier;

  /// Initialize state manager
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Initializing TerminalBlockStateManager for $blockId');
      
      // Initialize output
      _initializeOutput();
      
      // Setup service integrations
      await _setupInteractiveProcessHandling();
      _setupCommandTypeDetection();
      
      debugPrint('✅ TerminalBlockStateManager initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize TerminalBlockStateManager: $e');
      rethrow;
    }
  }

  /// Initialize output buffer and processing
  void _initializeOutput() {
    _outputBuffer.clear();
    if (initialBlockData.output.isNotEmpty) {
      _outputBuffer.write(initialBlockData.output);
      _processOutput();
    }
  }

  /// Setup interactive process handling
  Future<void> _setupInteractiveProcessHandling() async {
    try {
      // Check if this command is a persistent/interactive process
      _processInfo = _processDetector.detectProcessType(initialBlockData.command);
      _processInfoNotifier.value = _processInfo;
      
      if (_processInfo?.needsSpecialHandling == true && sessionId != null) {
        // Activate this block for interactive handling
        final blockId = await _activeBlockManager.activateBlock(
          blockId: this.blockId,
          sessionId: sessionId!,
          command: initialBlockData.command,
          blockData: initialBlockData,
        );
        
        if (blockId != null) {
          _isActiveBlock = true;
          _activeBlockNotifier.value = true;
          debugPrint('✅ Block $blockId activated for interactive process');
        }
      }
      
      // Listen for active block events
      _activeBlockSubscription = _activeBlockManager.events.listen(_handleActiveBlockEvent);
      
    } catch (e) {
      debugPrint('❌ Error setting up interactive process handling: $e');
    }
  }

  /// Setup command type detection
  void _setupCommandTypeDetection() {
    try {
      _commandTypeInfo = _commandTypeDetector.detectCommandType(initialBlockData.command);
      _commandType = _commandTypeInfo?.type ?? CommandType.oneShot;
      
      debugPrint('📋 Command type detected: ${_commandType.name} for ${initialBlockData.command}');
    } catch (e) {
      debugPrint('❌ Error detecting command type: $e');
      _commandType = CommandType.oneShot;
    }
  }

  /// Setup output stream subscription
  void setupOutputStream(Stream<String>? outputStream) {
    _outputSubscription?.cancel();
    
    if (outputStream != null) {
      _outputSubscription = outputStream.listen(
        (data) {
          _outputBuffer.write(data);
          _processOutput();
        },
        onError: (error) {
          debugPrint('❌ Output stream error: $error');
        },
      );
    }
  }

  /// Process output buffer and update processed output
  void _processOutput() {
    try {
      final rawOutput = _outputBuffer.toString();
      _processedOutput = _encodingService.processTerminalOutput(rawOutput);
      _outputNotifier.value = _processedOutput;
    } catch (e) {
      debugPrint('❌ Error processing output: $e');
      _processedOutput = _outputBuffer.toString(); // Fallback to raw output
      _outputNotifier.value = _processedOutput;
    }
  }

  /// Handle active block events
  void _handleActiveBlockEvent(ActiveBlockEvent event) {
    if (event.blockId != blockId) return;
    
    switch (event.type) {
      case ActiveBlockEventType.blockActivated:
        _isActiveBlock = true;
        _activeBlockNotifier.value = true;
        debugPrint('🟢 Block $blockId activated');
        break;
        
      case ActiveBlockEventType.blockDeactivated:
      case ActiveBlockEventType.blockTerminated:
        _isActiveBlock = false;
        _activeBlockNotifier.value = false;
        debugPrint('🔴 Block $blockId deactivated/terminated');
        break;
        
      case ActiveBlockEventType.focusChanged:
        final newFocusState = _activeBlockManager.focusedBlockId == blockId;
        if (_isFocused != newFocusState) {
          _isFocused = newFocusState;
          _focusNotifier.value = _isFocused;
          debugPrint('🎯 Block $blockId focus changed: $_isFocused');
        }
        break;
        
      default:
        break;
    }
  }

  /// Update show full command state
  void setShowFullCommand(bool show) {
    if (_showFullCommand != show) {
      _showFullCommand = show;
      // Could add a notifier for this if needed
    }
  }

  /// Check if the block can accept input
  bool canAcceptInput() {
    return _isActiveBlock && (_processInfo?.requiresInput == true);
  }

  /// Send input to the active block
  bool sendInput(String input) {
    if (!canAcceptInput()) {
      debugPrint('⚠️ Cannot send input to block $blockId: not active or not interactive');
      return false;
    }
    
    return _activeBlockManager.sendInputToBlock(blockId, input);
  }

  /// Focus this block
  void focusBlock() {
    if (_isActiveBlock) {
      _activeBlockManager.focusBlock(blockId);
    }
  }

  /// Get current state summary
  TerminalBlockStateInfo getStateInfo() {
    return TerminalBlockStateInfo(
      blockId: blockId,
      sessionId: sessionId,
      isActiveBlock: _isActiveBlock,
      isFocused: _isFocused,
      processInfo: _processInfo,
      commandType: _commandType,
      canAcceptInput: canAcceptInput(),
      outputLength: _processedOutput.length,
      showFullCommand: _showFullCommand,
    );
  }

  /// Dispose all resources
  void dispose() {
    debugPrint('🔄 Disposing TerminalBlockStateManager for $blockId');
    
    _outputSubscription?.cancel();
    _activeBlockSubscription?.cancel();
    
    _outputNotifier.dispose();
    _activeBlockNotifier.dispose();
    _focusNotifier.dispose();
    _processInfoNotifier.dispose();
  }
}

/// State information for terminal blocks
class TerminalBlockStateInfo {
  final String blockId;
  final String? sessionId;
  final bool isActiveBlock;
  final bool isFocused;
  final ProcessInfo? processInfo;
  final CommandType commandType;
  final bool canAcceptInput;
  final int outputLength;
  final bool showFullCommand;

  const TerminalBlockStateInfo({
    required this.blockId,
    required this.sessionId,
    required this.isActiveBlock,
    required this.isFocused,
    required this.processInfo,
    required this.commandType,
    required this.canAcceptInput,
    required this.outputLength,
    required this.showFullCommand,
  });

  @override
  String toString() {
    return 'TerminalBlockStateInfo{blockId: $blockId, active: $isActiveBlock, focused: $isFocused, type: $commandType}';
  }
}