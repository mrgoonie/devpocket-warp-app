import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../services/terminal_session_models.dart';
import '../../services/ssh_connection_models.dart';
import '../../services/terminal_input_mode_service.dart';
import '../../services/active_block_models.dart';
import '../../services/pty_focus_manager.dart';
import '../../providers/theme_provider.dart';
import 'terminal_block.dart';

// Import the extracted components
import 'components/terminal_stream_handlers.dart';
import 'components/terminal_connection_manager.dart';
import 'components/terminal_session_manager.dart';
import 'components/terminal_event_handler.dart';
import 'components/terminal_input_controller.dart';
import 'components/terminal_output_processor.dart';
import 'components/terminal_focus_manager.dart';

/// Refactored SSH Terminal Widget using modular components
/// Extracted from 1,940-line monolithic file into focused components
class SshTerminalWidget extends ConsumerStatefulWidget {
  final SshProfile? profile;
  final String? sessionId;
  final bool enableInput;
  final VoidCallback? onSessionClosed;

  const SshTerminalWidget({
    super.key,
    this.profile,
    this.sessionId,
    this.enableInput = true,
    this.onSessionClosed,
  });

  @override
  ConsumerState<SshTerminalWidget> createState() => _SshTerminalWidgetState();
}

class _SshTerminalWidgetState extends ConsumerState<SshTerminalWidget> {
  // Component instances - each handles specific responsibilities
  late final TerminalStreamHandlers _streamHandlers;
  late final TerminalConnectionManager _connectionManager;
  late final TerminalSessionManager _sessionManager;
  late final TerminalEventHandler _eventHandler;
  late final TerminalInputController _inputController;
  late final TerminalOutputProcessor _outputProcessor;
  late final TerminalFocusManager _focusManager;
  
  // Additional service instances for advanced features (for future use)
  // final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  // final FullscreenCommandDetector _fullscreenDetector = FullscreenCommandDetector.instance;
  // final InteractiveCommandManager _interactiveManager = InteractiveCommandManager.instance;
  
  // Widget state
  bool _isConnected = false;
  String _status = 'Initializing...';
  TerminalInputMode _currentInputMode = TerminalInputMode.command;
  final bool _isAiProcessing = false;
  final bool _useBlockUI = true;

  @override
  void initState() {
    super.initState();
    _initializeComponents();
    _setupSession();
  }

  @override
  void dispose() {
    _disposeComponents();
    super.dispose();
  }

  /// Initialize all component instances and wire them together
  void _initializeComponents() {
    // Initialize components in dependency order
    _streamHandlers = TerminalStreamHandlers();
    _connectionManager = TerminalConnectionManager();
    _sessionManager = TerminalSessionManager();
    _eventHandler = TerminalEventHandler();
    _inputController = TerminalInputController();
    _outputProcessor = TerminalOutputProcessor();
    _focusManager = TerminalFocusManager();
    
    // Setup stream handlers with event callbacks
    _streamHandlers.setupStreams(
      onInputModeChanged: _handleInputModeChanged,
      onActiveBlockEvent: _handleActiveBlockEvent,
      onFocusEvent: _handleFocusEvent,
      onSshConnectionEvent: _handleSshConnectionEvent,
    );
    
    // Initialize connection manager
    _connectionManager.initialize(
      onStatusChanged: _handleStatusChanged,
      onWelcomeMessage: _handleWelcomeMessage,
      onTerminalOutput: _handleTerminalOutput,
      onSshEvent: _handleSshConnectionEvent,
      onError: _handleError,
    );
    
    // Initialize session manager
    _sessionManager.initialize(
      onNewBlock: _handleNewBlock,
      onBlockStatusUpdate: _handleBlockStatusUpdate,
      onBlocksChanged: _handleBlocksChanged,
      onError: _handleError,
      onSessionClosed: _handleSessionClosed,
      useBlockUI: _useBlockUI,
    );
    
    // Initialize event handler
    _eventHandler.initialize(
      onActiveBlockEvent: _handleActiveBlockEventProcessing,
      onFocusEvent: _handleFocusEventProcessing,
      onInputModeChanged: _handleInputModeChangedProcessing,
      onSshConnectionEvent: _handleSshConnectionEventProcessing,
      onError: _handleError,
      onStateChanged: _handleStateChanged,
    );
    
    // Initialize input controller
    _inputController.initialize(
      enableInput: widget.enableInput,
      useBlockUI: _useBlockUI,
      onDataSent: _handleDataSent,
      onInputModeChanged: _handleInputModeChangedFromInput,
      onTerminalResize: _handleTerminalResize,
      onError: _handleError,
      onStateChanged: _handleStateChanged,
    );
    
    // Initialize output processor
    _outputProcessor.initialize(
      useBlockUI: _useBlockUI,
      onProcessedOutput: _handleProcessedOutput,
      onTerminalWrite: _handleTerminalWrite,
      onBlockStatusUpdate: _handleBlockStatusFromOutput,
      onError: _handleError,
    );
    
    // Initialize focus manager
    _focusManager.initialize(
      onFocusedBlockChanged: _handleFocusedBlockChanged,
      onInteractiveModeChanged: _handleInteractiveModeChanged,
      onFocusChanged: _handleFocusChanged,
      onError: _handleError,
      onStateChanged: _handleStateChanged,
    );
    
    debugPrint('All SSH Terminal Widget components initialized');
  }

  /// Setup session based on widget parameters
  Future<void> _setupSession() async {
    try {
      // Update event handler context
      _eventHandler.setSessionContext(
        sessionId: widget.sessionId,
        isMounted: mounted,
      );
      
      // Setup connection through connection manager
      await _connectionManager.setupSession(
        profile: widget.profile,
        sessionId: widget.sessionId,
      );
      
      // Set session ID in session manager
      _sessionManager.setSessionId(_connectionManager.currentSessionId);
      
      // Update connection state
      setState(() {
        _isConnected = _connectionManager.isConnected;
        _status = _connectionManager.status;
      });
      
      debugPrint('Session setup completed');
      
    } catch (e) {
      _handleError('Failed to setup session: $e');
    }
  }

  // Event handling methods - coordinate between components

  void _handleInputModeChanged(TerminalInputModeEvent event) {
    if (mounted) {
      setState(() {
        _currentInputMode = event.mode;
      });
      _inputController.handleInputModeChanged(event);
      _eventHandler.handleInputModeChanged(event);
    }
  }

  void _handleActiveBlockEvent(ActiveBlockEvent event) {
    if (mounted) {
      _eventHandler.handleActiveBlockEvent(event);
      _focusManager.handleActiveBlockEvent(event);
    }
  }

  void _handleFocusEvent(FocusEvent event) {
    if (mounted) {
      _eventHandler.handleFocusEvent(event);
      _focusManager.handleFocusEvent(event);
    }
  }

  void _handleSshConnectionEvent(SshConnectionEvent event) {
    if (mounted) {
      _eventHandler.handleSshConnectionEvent(event);
      _handleConnectionStateFromEvent(event);
    }
  }

  void _handleStatusChanged(String status) {
    if (mounted) {
      setState(() {
        _status = status;
      });
    }
  }

  void _handleWelcomeMessage(String welcomeMsg) {
    _sessionManager.displayWelcomeMessage(welcomeMsg);
  }

  void _handleTerminalOutput(TerminalOutput output) {
    _outputProcessor.processTerminalOutput(output);
    _sessionManager.handleTerminalOutput(output, writeToTerminal: _inputController.writeToTerminal);
  }

  void _handleError(String error) {
    debugPrint('Terminal error: $error');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  void _handleSessionClosed() {
    widget.onSessionClosed?.call();
  }

  void _handleNewBlock(TerminalBlockData block) {
    if (mounted) {
      setState(() {
        // Update UI for new block
      });
    }
  }

  void _handleBlockStatusUpdate(String blockId, TerminalBlockStatus status) {
    debugPrint('Block $blockId status updated to $status');
  }

  void _handleBlocksChanged(List<TerminalBlockData> blocks) {
    if (mounted) {
      setState(() {
        // Update UI for blocks change
      });
    }
  }

  void _handleDataSent(String data) {
    _sessionManager.sendData(data, profile: widget.profile);
  }

  void _handleTerminalWrite(String data) {
    _inputController.writeToTerminal(data);
  }

  void _handleProcessedOutput(String data) {
    debugPrint('Processed output: ${data.length} characters');
  }

  void _handleTerminalResize(int width, int height, int pixelWidth, int pixelHeight) {
    debugPrint('Terminal resized: ${width}x$height');
  }

  void _handleStateChanged() {
    if (mounted) {
      setState(() {
        // General state update
      });
    }
  }

  // Additional event handlers for component coordination
  
  void _handleActiveBlockEventProcessing(ActiveBlockEvent event) {
    debugPrint('Processing active block event: ${event.type}');
  }
  
  void _handleFocusEventProcessing(FocusEvent event) {
    debugPrint('Processing focus event: ${event.type}');
  }
  
  void _handleInputModeChangedProcessing(TerminalInputModeEvent event) {
    debugPrint('Processing input mode change: ${event.mode}');
  }
  
  void _handleSshConnectionEventProcessing(SshConnectionEvent event) {
    debugPrint('Processing SSH connection event: ${event.type}');
  }
  
  void _handleInputModeChangedFromInput(TerminalInputMode mode) {
    if (mounted && _currentInputMode != mode) {
      setState(() {
        _currentInputMode = mode;
      });
    }
  }
  
  void _handleBlockStatusFromOutput(TerminalBlockStatus status) {
    debugPrint('Block status from output: $status');
  }
  
  void _handleFocusedBlockChanged(String? blockId) {
    debugPrint('Focused block changed: $blockId');
  }
  
  void _handleInteractiveModeChanged(bool interactive) {
    debugPrint('Interactive mode changed: $interactive');
  }
  
  void _handleFocusChanged(bool hasFocus) {
    debugPrint('Terminal focus changed: $hasFocus');
  }
  
  void _handleConnectionStateFromEvent(SshConnectionEvent event) {
    if (event.type == SshConnectionEventType.statusChanged && event.status != null) {
      setState(() {
        switch (event.status!) {
          case SshConnectionStatus.connected:
            _isConnected = true;
            break;
          case SshConnectionStatus.disconnected:
          case SshConnectionStatus.failed:
            _isConnected = false;
            break;
          default:
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final blocks = _sessionManager.terminalBlocks;
    final isDark = themeMode == ThemeMode.dark || 
                   (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
        border: Border.all(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _useBlockUI ? _buildBlockUI(isDark, blocks) : _buildTerminalUI(isDark),
          ),
          if (widget.enableInput) _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.circle : Icons.circle_outlined,
            color: _isConnected ? Colors.green : Colors.red,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _status,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 16, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            onPressed: _handleRefresh,
            tooltip: 'Refresh connection',
          ),
        ],
      ),
    );
  }

  Widget _buildBlockUI(bool isDark, List<TerminalBlockData> blocks) {
    return ListView.builder(
      controller: _focusManager.blocksScrollController,
      padding: const EdgeInsets.all(8),
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final block = blocks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TerminalBlock(
            key: ValueKey(block.id),
            command: block.command,
            status: block.status,
            timestamp: block.timestamp,
            blockIndex: index,
            output: block.output,
            onRerun: () => _handleBlockRerun(block.id),
            onCancel: () => _handleBlockCancel(block.id),
          ),
        );
      },
    );
  }

  Widget _buildTerminalUI(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TerminalView(_inputController.terminal),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController.inputController,
              enabled: widget.enableInput && !_isAiProcessing,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: _getInputHint(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: isDark ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onSubmitted: _handleInputSubmitted,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: AppTheme.primaryColor),
            onPressed: _isAiProcessing ? null : () => _handleInputSubmitted(_inputController.inputController.text),
            tooltip: 'Send command',
          ),
        ],
      ),
    );
  }

  String _getInputHint() {
    switch (_currentInputMode) {
      case TerminalInputMode.command:
        return 'Enter command...';
      case TerminalInputMode.ai:
        return 'Ask AI assistant...';
    }
  }

  void _handleInputSubmitted(String input) {
    if (input.trim().isEmpty || !widget.enableInput) return;
    _inputController.submitCommand(input);
  }

  void _handleRefresh() {
    _setupSession();
  }

  void _handleBlockRerun(String blockId) {
    final block = _sessionManager.getBlock(blockId);
    if (block != null) {
      _inputController.submitCommand(block.command);
    }
  }

  void _handleBlockCancel(String blockId) {
    _sessionManager.updateBlock(blockId, status: TerminalBlockStatus.cancelled);
  }


  /// Dispose all components
  void _disposeComponents() {
    _streamHandlers.dispose();
    _connectionManager.dispose();
    _sessionManager.dispose();
    _eventHandler.dispose();
    _inputController.dispose();
    _outputProcessor.dispose();
    _focusManager.dispose();
    
    debugPrint('All SSH Terminal Widget components disposed');
  }

  /// Get comprehensive widget statistics
  Map<String, dynamic> getStats() {
    return {
      'widget': {
        'isConnected': _isConnected,
        'status': _status,
        'currentInputMode': _currentInputMode.toString(),
        'isAiProcessing': _isAiProcessing,
        'useBlockUI': _useBlockUI,
        'enableInput': widget.enableInput,
        'hasProfile': widget.profile != null,
        'hasSessionId': widget.sessionId != null,
      },
      'components': {
        'streamHandlers': _streamHandlers.activeSubscriptionCount,
        'connectionManager': _connectionManager.currentSessionId,
        'sessionManager': _sessionManager.getSessionStats(),
        'eventHandler': _eventHandler.getStats(),
        'inputController': _inputController.getStats(),
        'outputProcessor': _outputProcessor.getStats(),
        'focusManager': _focusManager.getStats(),
      },
    };
  }
}