import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../models/enhanced_terminal_models.dart';
import '../../services/terminal_session_handler.dart';
import '../../services/ssh_connection_manager.dart';
import '../../services/terminal_input_mode_service.dart';
import '../../services/persistent_process_detector.dart';
import '../../services/active_block_manager.dart';
import '../../services/pty_focus_manager.dart';
import '../../services/fullscreen_command_detector.dart';
import '../../services/interactive_command_manager.dart';
import '../../providers/theme_provider.dart';
import '../../services/ansi_text_processor.dart';
import '../../services/terminal_text_encoding_service.dart';
import 'terminal_block.dart';
import 'enhanced_terminal_block.dart';

/// SSH Terminal Widget using xterm.dart
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
  late Terminal _terminal;
  late TerminalController _controller;
  String? _currentSessionId;
  StreamSubscription<TerminalOutput>? _outputSubscription;
  StreamSubscription<SshConnectionEvent>? _sshEventSubscription;
  StreamSubscription<TerminalInputModeEvent>? _inputModeSubscription;
  StreamSubscription<ActiveBlockEvent>? _activeBlockSubscription;
  StreamSubscription<FocusEvent>? _focusSubscription;

  final TerminalSessionHandler _sessionHandler =
      TerminalSessionHandler.instance;
  final SshConnectionManager _sshManager = SshConnectionManager.instance;
  final TerminalInputModeService _inputModeService =
      TerminalInputModeService.instance;
  final PersistentProcessDetector _processDetector =
      PersistentProcessDetector.instance;
  final FullscreenCommandDetector _fullscreenDetector =
      FullscreenCommandDetector.instance;
  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final PTYFocusManager _focusManager = PTYFocusManager.instance;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _blocksScrollController = ScrollController();

  bool _isConnected = false;
  String _status = 'Initializing...';
  String _welcomeMessage = '';
  final List<TerminalBlockData> _terminalBlocks = [];
  int _blockCounter = 0;
  bool _hasWelcomeBlock = false;
  TerminalInputMode _currentInputMode = TerminalInputMode.command;
  bool _isAiProcessing = false;

  // Block-based terminal state
  bool _useBlockUI = true;
  StreamController<String>? _currentOutputController;

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
    _setupInputModeService();
    _setupInteractiveProcessHandling();
    _setupSession();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _sshEventSubscription?.cancel();
    _inputModeSubscription?.cancel();
    _activeBlockSubscription?.cancel();
    _focusSubscription?.cancel();
    _currentOutputController?.close();
    _inputController.dispose();
    _blocksScrollController.dispose();
    _disconnectSession();
    super.dispose();
  }

  void _initializeTerminal() {
    _terminal = Terminal(
      maxLines: 10000,
    );

    _controller = TerminalController();

    // Handle terminal input (for fallback xterm mode)
    _terminal.onOutput = (data) {
      if (_isConnected && _currentSessionId != null && !_useBlockUI) {
        _sendData(data);
      }
    };

    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      // Handle terminal resize if needed
    };
  }

  void _setupInputModeService() {
    // Listen to input mode changes
    _inputModeSubscription = _inputModeService.modeStream.listen((event) {
      if (mounted) {
        setState(() {
          _currentInputMode = event.mode;
        });
      }
    });

    // Initialize with current mode
    _currentInputMode = _inputModeService.currentMode;
  }

  /// Setup interactive process handling services
  void _setupInteractiveProcessHandling() {
    // Initialize focus manager
    _focusManager.initialize();

    // Listen to active block events
    _activeBlockSubscription =
        _activeBlockManager.events.listen(_handleActiveBlockEvent);

    // Listen to focus events
    _focusSubscription = _focusManager.events.listen(_handleFocusEvent);
  }

  /// Handle active block manager events
  void _handleActiveBlockEvent(ActiveBlockEvent event) {
    if (mounted && event.sessionId == _currentSessionId) {
      setState(() {
        // Update UI based on active block events
        debugPrint(
            'Active block event: ${event.type} for block ${event.blockId}');
      });
    }
  }

  /// Handle focus manager events
  void _handleFocusEvent(FocusEvent event) {
    if (mounted) {
      setState(() {
        debugPrint('Focus event: ${event.type} for block ${event.blockId}');
      });
    }
  }

  Future<void> _setupSession() async {
    try {
      if (widget.sessionId != null) {
        // Use existing session
        _currentSessionId = widget.sessionId;
        _isConnected = _sshManager.isConnected(_currentSessionId!);
      } else if (widget.profile != null) {
        // Create new SSH session with enhanced connection manager
        setState(() {
          _status = 'Connecting to ${widget.profile!.connectionString}...';
        });

        _currentSessionId = await _sshManager.connect(widget.profile!);
        _isConnected = true;

        // Setup SSH event listening
        _sshEventSubscription = _sshManager.events.listen(_handleSshEvent);
      } else {
        // Create local session via session handler
        setState(() {
          _status = 'Starting local terminal...';
        });

        _currentSessionId = await _sessionHandler.createLocalSession();
        _isConnected = true;

        // Listen to session handler output for local sessions
        _outputSubscription = _sessionHandler.output.listen(
          _handleTerminalOutput,
          onError: (error) {
            _handleError('Terminal error: $error');
          },
        );
      }

      setState(() {
        _status = 'Connected';
      });

      // Get and display welcome message for SSH sessions
      if (widget.profile != null && _currentSessionId != null) {
        // Wait a moment for welcome message to be captured
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted && _currentSessionId != null) {
            final welcomeMsg =
                _sshManager.getWelcomeMessage(_currentSessionId!);
            if (welcomeMsg.isNotEmpty) {
              _displayWelcomeMessage(welcomeMsg);
            }
          }
        });
      }
    } catch (e) {
      _handleError('Connection failed: $e');
    }
  }

  void _handleTerminalOutput(TerminalOutput output) {
    // Always write to the current active display mode
    if (_useBlockUI) {
      // Handle output in block-based UI
      switch (output.type) {
        case TerminalOutputType.stdout:
        case TerminalOutputType.stderr:
          _currentOutputController?.add(output.data);
          break;

        case TerminalOutputType.info:
          _currentOutputController?.add('\x1b[36m${output.data}\x1b[0m');
          break;

        case TerminalOutputType.error:
          _currentOutputController?.add('\x1b[31m${output.data}\x1b[0m');
          _updateCurrentBlockStatus(TerminalBlockStatus.failed);
          break;

        case TerminalOutputType.command:
          // Commands are handled separately in block UI
          break;
      }
    } else {
      // Handle output in terminal view
      switch (output.type) {
        case TerminalOutputType.stdout:
        case TerminalOutputType.stderr:
          _terminal.write(output.data);
          break;

        case TerminalOutputType.info:
          _terminal.write('\x1b[36m${output.data}\x1b[0m'); // Cyan for info
          break;

        case TerminalOutputType.error:
          _terminal.write('\x1b[31m${output.data}\x1b[0m'); // Red for errors
          break;

        case TerminalOutputType.command:
          // Don't echo commands as they're already shown by the shell
          break;
      }
    }
  }

  Future<void> _sendData(String data) async {
    if (!_isConnected || _currentSessionId == null) return;

    try {
      if (widget.profile != null) {
        // Use SSH connection manager for SSH sessions
        await _sshManager.sendData(_currentSessionId!, data);
      } else {
        // Use session handler for local sessions
        await _sessionHandler.sendData(_currentSessionId!, data);
      }
    } catch (e) {
      _handleError('Error sending data: $e');
    }
  }

  Future<void> _disconnectSession() async {
    if (_currentSessionId != null) {
      try {
        if (widget.profile != null) {
          // SSH session - use SSH connection manager
          await _sshManager.disconnect(_currentSessionId!);
        } else {
          // Local session - use session handler
          await _sessionHandler.stopSession(_currentSessionId!);
        }

        _currentSessionId = null;
        _isConnected = false;
        _currentOutputController?.close();
        _currentOutputController = null;

        widget.onSessionClosed?.call();
      } catch (e) {
        debugPrint('Error disconnecting session: $e');
      }
    }
  }

  /// Handle SSH connection events for enhanced feedback
  void _handleSshEvent(SshConnectionEvent event) {
    if (!mounted) return;

    switch (event.type) {
      case SshConnectionEventType.dataReceived:
        if (event.data != null) {
          if (_useBlockUI) {
            // Send to block UI output stream
            _currentOutputController?.add(event.data!);
          } else {
            // Send to XTerm terminal in fallback mode
            _terminal.write(event.data!);
          }
        }
        break;

      case SshConnectionEventType.error:
        if (event.error != null) {
          _handleError('SSH Error: ${event.error!}');
        }
        break;

      case SshConnectionEventType.statusChanged:
        if (event.status != null) {
          setState(() {
            switch (event.status!) {
              case SshConnectionStatus.connecting:
                _status = 'Connecting...';
                break;
              case SshConnectionStatus.authenticating:
                _status = 'Authenticating...';
                break;
              case SshConnectionStatus.connected:
                _status = 'Connected';
                _isConnected = true;
                break;
              case SshConnectionStatus.disconnected:
                _status = 'Disconnected';
                _isConnected = false;
                break;
              case SshConnectionStatus.failed:
                _status = 'Connection Failed';
                _isConnected = false;
                break;
              case SshConnectionStatus.reconnecting:
                _status = 'Reconnecting...';
                break;
            }
          });
        }
        break;

      case SshConnectionEventType.closed:
        setState(() {
          _status = 'Connection Closed';
          _isConnected = false;
        });
        break;

      default:
        break;
    }
  }

  /// Handle errors with consistent error display
  void _handleError(String error) {
    debugPrint('SSH Terminal Error: $error');

    if (_useBlockUI) {
      _currentOutputController?.add('\x1b[31m$error\x1b[0m\n');
      _updateCurrentBlockStatus(TerminalBlockStatus.failed);
    } else {
      _terminal.write('\x1b[31m$error\x1b[0m\r\n');
    }

    setState(() {
      _status = 'Error';
    });
  }

  Future<void> _reconnectSession() async {
    if (widget.profile == null) return;

    setState(() {
      _status = 'Reconnecting...';
    });

    try {
      await _disconnectSession();
      await _setupSession();
    } catch (e) {
      setState(() {
        _status = 'Reconnection failed: $e';
        _isConnected = false;
      });
    }
  }

  /// Create a new terminal block for command execution
  /// Try to activate block for interactive processes
  Future<void> _tryActivateInteractiveBlock(
      String blockId, String command) async {
    try {
      // Create enhanced block data
      final enhancedBlockData = EnhancedTerminalBlockData(
        id: blockId,
        command: command,
        status: TerminalBlockStatus.running,
        timestamp: DateTime.now(),
        sessionId: _currentSessionId!,
        index: _terminalBlocks.length - 1,
      );

      await _activeBlockManager.activateBlock(
        blockId: blockId,
        sessionId: _currentSessionId!,
        command: command,
        blockData: enhancedBlockData,
      );
    } catch (e) {
      debugPrint('Failed to activate interactive block: $e');
    }
  }

  String? _createCommandBlock(String command) {
    if (!mounted) return null;

    // Close previous output controller if exists
    _currentOutputController?.close();

    // Create new output stream controller for this block
    _currentOutputController = StreamController<String>.broadcast();

    final blockId = 'block_${_blockCounter++}';
    final blockData = TerminalBlockData(
      id: blockId,
      command: command,
      status: TerminalBlockStatus.running,
      timestamp: DateTime.now(),
      isInteractive: _isInteractiveCommand(command),
      index: _terminalBlocks.length,
    );

    setState(() {
      _terminalBlocks.add(blockData);
    });

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_blocksScrollController.hasClients) {
        _blocksScrollController.animateTo(
          _blocksScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return blockId; // Return block ID for interactive handling
  }

  /// Create a welcome message block as the first terminal block
  void _createWelcomeBlock(String welcomeContent) {
    if (!mounted || _hasWelcomeBlock) return;

    // Store welcome message for potential re-creation after clear
    setState(() {
      _welcomeMessage = welcomeContent;
    });

    const blockId = 'welcome_block';
    final welcomeBlockData = TerminalBlockData(
      id: blockId,
      command: '# SSH Connection Welcome Message',
      status: TerminalBlockStatus.completed,
      timestamp: DateTime.now(),
      output: welcomeContent,
      isInteractive: false,
      index: 0, // Always index 0 as first block
    );

    setState(() {
      // Insert at the beginning of the blocks list
      _terminalBlocks.insert(0, welcomeBlockData);
      _hasWelcomeBlock = true;
      
      // Increment indices of existing blocks
      for (int i = 1; i < _terminalBlocks.length; i++) {
        _terminalBlocks[i] = _terminalBlocks[i].copyWith(index: i);
      }
    });

    // Auto-scroll to show the welcome block
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_blocksScrollController.hasClients) {
        _blocksScrollController.animateTo(
          0.0, // Scroll to top to show welcome block
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Resize terminal to fit current screen dimensions
  void _resizeTerminalForCurrentScreen() {
    if (!mounted) return;
    
    final screenSize = MediaQuery.of(context).size;
    
    // Terminal font metrics (JetBrains Mono)
    const double charWidth = 9.6;    // Character width in pixels
    const double charHeight = 18.0;   // Line height in pixels
    
    // Account for status bar, safe area, and UI elements
    const double statusBarHeight = 56.0;
    const double inputControlsHeight = 48.0;
    const double safeAreaBuffer = 88.0; // Combined safe area estimate
    
    final double availableWidth = screenSize.width - 16.0; // 8px padding on each side
    final double availableHeight = screenSize.height - 
        statusBarHeight - 
        inputControlsHeight - 
        safeAreaBuffer - 
        16.0; // 8px padding top/bottom
    
    final int cols = (availableWidth / charWidth).floor().clamp(20, 200);
    final int rows = (availableHeight / charHeight).floor().clamp(10, 100);
    
    _terminal.resize(cols, rows);
    
    debugPrint('Terminal resized to ${cols}x$rows for screen ${screenSize.width}x${screenSize.height}');
  }

  /// Sync blocks to terminal buffer for Terminal View mode
  /// DISABLED: Commenting out sync functionality due to issues
  /*
  Future<void> _syncBlocksToTerminal() async {
    if (_terminalBlocks.isEmpty) return;
    
    // Clear current terminal buffer
    _terminal.eraseDisplay();
    
    for (final block in _terminalBlocks) {
      // Skip welcome blocks when syncing to terminal as they have different formatting
      if (block.id == 'welcome_block') {
        // Write welcome message with terminal formatting
        if (block.output.isNotEmpty) {
          final formattedWelcome = '\x1b[32m# SSH Connection Welcome Message\x1b[0m\r\n'
              '\x1b[36m${block.output.replaceAll('\n', '\r\n')}\x1b[0m\r\n'
              '\x1b[33m${'─' * 50}\x1b[0m\r\n';
          _terminal.write(formattedWelcome);
        }
        continue;
      }
      
      // Write command with proper shell prompt formatting
      _terminal.write('\$ ${block.command}\r\n');
      
      // Write output if present
      if (block.output.isNotEmpty) {
        // Ensure proper line endings for terminal display
        final terminalOutput = block.output.replaceAll('\n', '\r\n');
        _terminal.write(terminalOutput);
        
        // Add line break if output doesn't end with one
        if (!block.output.endsWith('\n') && !block.output.endsWith('\r\n')) {
          _terminal.write('\r\n');
        }
      }
      
      // Add status indicator for failed commands
      if (block.status == TerminalBlockStatus.failed) {
        _terminal.write('\x1b[31m[Command failed]\x1b[0m\r\n');
      } else if (block.status == TerminalBlockStatus.cancelled) {
        _terminal.write('\x1b[33m[Command cancelled]\x1b[0m\r\n');
      }
    }
  }
  */
  
  /// Sync terminal buffer to blocks for Block UI mode
  /// DISABLED: Commenting out sync functionality due to issues
  /*
  Future<void> _syncTerminalToBlocks() async {
    // Get terminal buffer content
    final buffer = _terminal.buffer.toString();
    if (buffer.isEmpty) return;
    
    final lines = buffer.split('\n');
    final newBlocks = <TerminalBlockData>[];
    
    String? currentCommand;
    StringBuffer currentOutput = StringBuffer();
    bool inWelcomeMessage = false;
    String welcomeContent = '';
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Detect welcome message
      if (line.contains('SSH Connection Welcome Message')) {
        inWelcomeMessage = true;
        welcomeContent = '';
        continue;
      }
      
      // End of welcome message (dashed line)
      if (inWelcomeMessage && line.contains('─')) {
        inWelcomeMessage = false;
        if (welcomeContent.isNotEmpty) {
          // Create welcome block
          final welcomeBlock = TerminalBlockData(
            id: 'welcome_block',
            command: '# SSH Connection Welcome Message',
            status: TerminalBlockStatus.completed,
            timestamp: DateTime.now(),
            output: welcomeContent.trim(),
            isInteractive: false,
            index: 0,
          );
          newBlocks.add(welcomeBlock);
        }
        continue;
      }
      
      // Collect welcome content
      if (inWelcomeMessage) {
        // Remove ANSI escape sequences for cleaner welcome content
        final cleanLine = line.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
        if (cleanLine.isNotEmpty) {
          welcomeContent += cleanLine + '\n';
        }
        continue;
      }
      
      // Detect command lines (starting with $ prompt)
      if (_isCommandLine(line)) {
        // Save previous command block if exists
        if (currentCommand != null) {
          newBlocks.add(_createBlockFromData(
            currentCommand, 
            currentOutput.toString().trim(),
            newBlocks.length,
          ));
        }
        
        // Start new command
        currentCommand = _extractCommand(line);
        currentOutput = StringBuffer();
      } else if (currentCommand != null) {
        // Accumulate output for current command
        if (line.isNotEmpty) {
          currentOutput.writeln(line);
        }
      }
    }
    
    // Add final block if exists
    if (currentCommand != null) {
      newBlocks.add(_createBlockFromData(
        currentCommand, 
        currentOutput.toString().trim(),
        newBlocks.length,
      ));
    }
    
    // Update blocks list
    setState(() {
      _terminalBlocks.clear();
      _terminalBlocks.addAll(newBlocks);
      _hasWelcomeBlock = newBlocks.any((block) => block.id == 'welcome_block');
    });
  }
  */
  
  /// Check if a line represents a command (starts with $ prompt)
  /// DISABLED: Helper method for sync functionality
  /*
  bool _isCommandLine(String line) {
    return line.startsWith(r'$') || line.contains(r'$ ');
  }
  
  /// Extract command from a command line
  String _extractCommand(String line) {
    // Remove $ prompt and leading/trailing whitespace
    return line.replaceFirst(RegExp(r'^\s*\$\s*'), '').trim();
  }
  
  /// Create a TerminalBlockData from command and output
  TerminalBlockData _createBlockFromData(String command, String output, int index) {
    // Determine status based on output content
    TerminalBlockStatus status = TerminalBlockStatus.completed;
    if (output.contains('[Command failed]')) {
      status = TerminalBlockStatus.failed;
      // Remove status indicator from output
      output = output.replaceAll(RegExp(r'\[Command failed\]'), '').trim();
    } else if (output.contains('[Command cancelled]')) {
      status = TerminalBlockStatus.cancelled;
      // Remove status indicator from output
      output = output.replaceAll(RegExp(r'\[Command cancelled\]'), '').trim();
    }
    
    return TerminalBlockData(
      id: 'synced_block_${DateTime.now().millisecondsSinceEpoch}_$index',
      command: command,
      status: status,
      timestamp: DateTime.now(),
      output: output,
      isInteractive: _isInteractiveCommand(command),
      index: index,
    );
  }
  */

  /// Display welcome message in both Block UI and Terminal View modes
  void _displayWelcomeMessage(String welcomeContent) {
    if (!mounted) return;
    
    // Store welcome message for potential re-creation
    setState(() {
      _welcomeMessage = welcomeContent;
    });
    
    if (_useBlockUI) {
      // Use existing block creation for Block UI mode
      _createWelcomeBlock(welcomeContent);
    } else {
      // Write welcome message directly to terminal for Terminal View mode
      if (welcomeContent.isNotEmpty) {
        // Format welcome message with terminal colors and styling
        final formattedWelcome = '\x1b[32m# SSH Connection Welcome Message\x1b[0m\r\n'
            '\x1b[36m${welcomeContent.replaceAll('\n', '\r\n')}\x1b[0m\r\n'
            '\x1b[33m${'─' * 50}\x1b[0m\r\n';
        
        _terminal.write(formattedWelcome);
      }
    }
  }

  /// Check if command is interactive
  bool _isInteractiveCommand(String command) {
    // Use the enhanced command detection
    final handlingMode = _fullscreenDetector.detectHandlingMode(command);

    // Interactive commands are those that either:
    // 1. Use block-interactive mode (Phase 3.5)
    // 2. Use fullscreen modal mode (Phase 3) - but these won't create blocks anyway
    return handlingMode == CommandHandlingMode.blockInteractive ||
        handlingMode == CommandHandlingMode.fullscreenModal;
  }

  /// Update current block status
  void _updateCurrentBlockStatus(TerminalBlockStatus status) {
    if (_terminalBlocks.isEmpty) return;

    setState(() {
      final lastBlock = _terminalBlocks.last;
      _terminalBlocks[_terminalBlocks.length - 1] =
          lastBlock.copyWith(status: status);
    });

    // Close output controller if command is completed
    if (status == TerminalBlockStatus.completed ||
        status == TerminalBlockStatus.failed ||
        status == TerminalBlockStatus.cancelled) {
      _currentOutputController?.close();
      _currentOutputController = null;
    }
  }

  /// Send command through the terminal
  Future<void> _sendCommand(String command) async {
    if (!_isConnected || _currentSessionId == null || command.trim().isEmpty) {
      return;
    }

    try {
      // Set loading state if AI mode
      if (_currentInputMode == TerminalInputMode.ai) {
        setState(() {
          _isAiProcessing = true;
        });
      }

      // Process command through input mode service
      final processedCommand = await _inputModeService.processInput(command,
          sessionId: _currentSessionId);
      final finalCommand = processedCommand ?? command;

      // Check if command should trigger fullscreen modal
      if (_fullscreenDetector.shouldTriggerFullscreen(finalCommand)) {
        await _launchFullscreenModal(finalCommand);
        _inputController.clear();
        return;
      }

      // Create command block for regular and block-interactive commands
      if (_useBlockUI) {
        _createCommandBlock(finalCommand);
      }

      // Send command to session
      if (widget.profile != null) {
        await _sshManager.sendCommand(_currentSessionId!, finalCommand);
      } else {
        await _sessionHandler.sendCommand(_currentSessionId!, finalCommand);
      }

      // Clear input field
      _inputController.clear();
    } catch (e) {
      _handleError('Failed to send command: $e');
    } finally {
      // Clear loading state
      if (mounted) {
        setState(() {
          _isAiProcessing = false;
        });
      }
    }
  }

  /// Handle interactive input for running command blocks
  Future<void> _sendInteractiveInput(String input, String blockId) async {
    if (!_isConnected || _currentSessionId == null) return;

    try {
      if (widget.profile != null) {
        await _sshManager.sendData(_currentSessionId!, input);
      } else {
        await _sessionHandler.sendData(_currentSessionId!, input);
      }
    } catch (e) {
      _handleError('Failed to send interactive input: $e');
    }
  }

  /// Handle enhanced block input with focus management
  Future<void> _handleEnhancedBlockInput(String input, String blockId) async {
    // Try to route through focus manager first
    if (_focusManager.handleTextInput(input)) {
      // Input was handled by focus manager (sent to active block)
      return;
    }

    // Fallback to traditional interactive input handling
    await _sendInteractiveInput(input, blockId);
  }

  /// Handle block tap for focus management
  void _handleBlockTap(String blockId) {
    // Check if block is active and can accept input
    if (_activeBlockManager.canBlockAcceptInput(blockId)) {
      _focusManager.focusBlock(blockId);
    }
  }

  /// Handle main input submission with focus management
  Future<void> _handleMainInputSubmission(String input) async {
    // Check if input should be routed to focused block first
    if (_focusManager.handleTextInput(input)) {
      // Input was routed to focused block
      _inputController.clear();
      return;
    }

    // Otherwise, treat as new command
    await _sendCommand(input);
  }

  /// Toggle input mode between command and AI
  Future<void> _toggleInputMode() async {
    await _inputModeService.toggleMode(_currentSessionId);
  }

  /// Launch fullscreen modal for interactive commands
  Future<void> _launchFullscreenModal(String command) async {
    if (!mounted) return;

    try {
      // Get SSH client from connection manager if this is an SSH session
      final sshClient = widget.profile != null && _currentSessionId != null
          ? _sshManager.getSshClient(_currentSessionId!)
          : null;

      // Launch fullscreen modal
      await InteractiveCommandManager.launchFullscreenModal(
        context: context,
        command: command,
        sshClient: sshClient,
        environment: {
          'TERM': 'xterm-256color',
          'LC_ALL': 'en_US.UTF-8',
        },
        onOutput: (output) {
          // Handle output if needed for logging
          debugPrint('Fullscreen command output: $output');
        },
        onError: (error) {
          // Handle errors
          _handleError('Fullscreen command error: $error');
        },
        onExit: (exitCode) {
          // Handle command completion
          debugPrint('Fullscreen command exited with code: $exitCode');

          // Create a completion block in the main terminal
          if (mounted && _useBlockUI) {
            _createCompletionBlock(command, exitCode);
          }
        },
      );
    } catch (e) {
      _handleError('Failed to launch fullscreen modal: $e');
    }
  }

  /// Create a completion block after fullscreen command finishes
  void _createCompletionBlock(String command, int exitCode) {
    if (!mounted) return;

    final blockId = 'block_${_blockCounter++}';
    final wasSuccessful = exitCode == 0;

    final blockData = TerminalBlockData(
      id: blockId,
      command: command,
      status: wasSuccessful
          ? TerminalBlockStatus.completed
          : TerminalBlockStatus.failed,
      timestamp: DateTime.now(),
      isInteractive: false,
      index: _terminalBlocks.length + 1,
      output: wasSuccessful
          ? '[Fullscreen command completed successfully]'
          : '[Fullscreen command exited with code $exitCode]',
    );

    setState(() {
      _terminalBlocks.add(blockData);
    });

    // Auto-scroll to show new block
    _scrollToBottom();
  }

  /// Auto-scroll to bottom of blocks view
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_blocksScrollController.hasClients) {
        _blocksScrollController.animateTo(
          _blocksScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Rerun a command from a block
  void _rerunCommand(String command) {
    _inputController.text = command;
    _sendCommand(command);
  }

  /// Cancel current running command
  void _cancelCurrentCommand() {
    if (_terminalBlocks.isNotEmpty) {
      final lastBlock = _terminalBlocks.last;
      if (lastBlock.status == TerminalBlockStatus.running) {
        _updateCurrentBlockStatus(TerminalBlockStatus.cancelled);
        // Send Ctrl+C to interrupt
        _sendData('\x03');
      }
    }
  }

  /// Clear all terminal blocks (for Clear Screen functionality)
  void _clearScreenBlocks() {
    setState(() {
      _terminalBlocks.clear();
      _blockCounter = 0;
      _hasWelcomeBlock = false;
    });

    // Close current output controller if any
    _currentOutputController?.close();
    _currentOutputController = null;

    // Re-create welcome block if we have a welcome message
    if (_welcomeMessage.isNotEmpty) {
      _displayWelcomeMessage(_welcomeMessage);
    }

    // Show brief confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screen cleared'),
          duration: Duration(milliseconds: 1500),
          backgroundColor: AppTheme.terminalGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: _useBlockUI
              ? _buildBlockBasedTerminalContent()
              : _buildXtermFallbackContent(),
        ),
        if (widget.enableInput) _buildInputControls(),
      ],
    );
  }

  Widget _buildBlockBasedTerminalContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _terminalBlocks.isEmpty
          ? _buildEmptyBlocksState()
          : _buildBlocksList(),
    );
  }

  Widget _buildXtermFallbackContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TerminalView(
          _terminal,
          controller: _controller,
          autofocus: true,
          backgroundOpacity: 1.0,
          onSecondaryTapDown: widget.enableInput
              ? (details, offset) => _showContextMenu(details)
              : null,
        ),
      ),
    );
  }

  Widget _buildEmptyBlocksState() {
    // Check if we're in a connecting state
    final isConnecting = _status.contains('Connecting') || 
                        _status.contains('Authenticating') || 
                        _status.contains('Reconnecting') ||
                        _status.contains('Starting');
    
    if (isConnecting) {
      // Show loading indicator when connecting
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Show terminal ready state when not connecting
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal,
            size: 48,
            color: AppTheme.darkTextSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Terminal Ready',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Enter a command to get started',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlocksList() {
    return Scrollbar(
      controller: _blocksScrollController,
      child: ListView.builder(
        controller: _blocksScrollController,
        padding: const EdgeInsets.all(8),
        itemCount: _terminalBlocks.length,
        itemBuilder: (context, index) {
          final block = _terminalBlocks[index];

          // Check if this is the welcome block
          if (block.id == 'welcome_block') {
            return _buildWelcomeTerminalBlock(block);
          }

          // Create enhanced block data from regular block data
          final enhancedBlockData = EnhancedTerminalBlockData.fromBase(
            block,
            sessionId: _currentSessionId ?? 'unknown',
            isAgentCommand: _currentInputMode == TerminalInputMode.ai,
          );

          return EnhancedTerminalBlock(
            key: Key(block.id),
            blockData: enhancedBlockData,
            outputStream: (index == _terminalBlocks.length - 1)
                ? _currentOutputController?.stream
                : null,
            sessionId: _currentSessionId,
            onRerun: () => _rerunCommand(block.command),
            onCancel: (block.status == TerminalBlockStatus.running)
                ? _cancelCurrentCommand
                : null,
            onInputSubmit: (input) =>
                _handleEnhancedBlockInput(input, block.id),
            onTap: () => _handleBlockTap(block.id),
          );
        },
      ),
    );
  }

  /// Build a specialized welcome message terminal block
  Widget _buildWelcomeTerminalBlock(TerminalBlockData block) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.terminalBlue.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.terminalBlue.withValues(alpha: 0.05),
              AppTheme.darkSurface,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.terminalBlue.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.terminalBlue.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.terminalBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SSH Connection Welcome Message',
                    style: TextStyle(
                      color: AppTheme.terminalBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Timestamp
                  Text(
                    _formatWelcomeTimestamp(block.timestamp),
                    style: const TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Welcome content
            Container(
              padding: const EdgeInsets.all(12),
              child: AnsiTextProcessor.instance.createSelectableTerminalText(
                TerminalTextEncodingService.instance.processTerminalOutputWithAnsi(block.output),
                defaultStyle: TextStyle(
                  color: AppTheme.darkTextPrimary,
                  fontSize: ref.watch(fontSizeProvider) * 0.85,
                  fontFamily: ref.watch(fontFamilyProvider),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format timestamp for welcome block
  String _formatWelcomeTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildStatusBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color:
                  _isConnected ? AppTheme.terminalGreen : AppTheme.terminalRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.profile?.connectionString ?? 'Local Terminal',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          if (_useBlockUI) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _currentInputMode == TerminalInputMode.ai
                    ? AppTheme.primaryColor.withValues(alpha: 0.2)
                    : AppTheme.terminalGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _inputModeService.getModeLabel(_currentInputMode),
                style: TextStyle(
                  color: _currentInputMode == TerminalInputMode.ai
                      ? AppTheme.primaryColor
                      : AppTheme.terminalGreen,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Only show block count on larger screens to prevent overflow
            if (MediaQuery.of(context).size.width > 380) ...[
              Text(
                '${_terminalBlocks.length} blocks',
                style: const TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],
          Flexible(
            child: Text(
              _status,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(_useBlockUI ? Icons.terminal : Icons.view_list),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () async {
              // Perform synchronization before mode switch
              // DISABLED: Sync functionality commented out due to issues
              /*
              if (_useBlockUI) {
                // Switching to Terminal View - sync blocks to terminal
                await _syncBlocksToTerminal();
              } else {
                // Switching to Block UI - sync terminal to blocks
                await _syncTerminalToBlocks();
              }
              */
              
              setState(() {
                _useBlockUI = !_useBlockUI;
              });
              
              // Resize terminal when switching to Terminal View mode
              if (!_useBlockUI) {
                _resizeTerminalForCurrentScreen();
              }
            },
            tooltip: _useBlockUI
                ? 'Switch to Terminal View'
                : 'Switch to Block View',
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: _showOptionsMenu,
          ),
        ],
      ),
    );
  }

  Widget _buildInputControls() {
    if (_useBlockUI) {
      return _buildEnhancedInputControls();
    } else {
      return _buildLegacyInputControls();
    }
  }

  Widget _buildEnhancedInputControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(8),
        ),
      ),
      child: Column(
        children: [
          // Command input field (multiline)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  enabled: _isConnected && !_isAiProcessing,
                  maxLines: 5,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: ref.watch(fontSizeProvider) *
                        0.9, // Slightly smaller for input
                    fontFamily: ref.watch(fontFamilyProvider),
                  ),
                  decoration: InputDecoration(
                    hintText: _inputModeService
                        .getInputPlaceholder(_currentInputMode),
                    hintStyle: const TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.darkBorderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.darkBorderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.primaryColor),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: false,
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && !_isAiProcessing) {
                      _handleMainInputSubmission(value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Send button with loading indicator
              SizedBox(
                width: 40,
                height: 40,
                child: _isAiProcessing
                    ? Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                            ),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, size: 18),
                        onPressed: _isConnected
                            ? () {
                                final command = _inputController.text.trim();
                                if (command.isNotEmpty) {
                                  _handleMainInputSubmission(command);
                                }
                              }
                            : null,
                        tooltip: 'Send Command',
                        color: AppTheme.primaryColor,
                      ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Control keys and shortcuts with mode toggle
          Row(
            children: [
              // Input mode toggle button moved here
              InkWell(
                onTap: _isAiProcessing ? null : _toggleInputMode,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _currentInputMode == TerminalInputMode.ai
                        ? AppTheme.primaryColor
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _currentInputMode == TerminalInputMode.ai
                          ? AppTheme.primaryColor
                          : AppTheme.darkBorderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _inputModeService.getModeIcon(_currentInputMode),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _inputModeService.getModeLabel(_currentInputMode),
                        style: TextStyle(
                          color: _currentInputMode == TerminalInputMode.ai
                              ? Colors.white
                              : AppTheme.darkTextPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildControlKey('Ctrl'),
              _buildControlKey('Alt'),
              _buildControlKey('Esc'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                onPressed: () => _sendData('\x1b[A'), // Up arrow
                tooltip: 'Up Arrow',
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                onPressed: () => _sendData('\x1b[B'), // Down arrow
                tooltip: 'Down Arrow',
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_tab, size: 16),
                onPressed: () => _sendData('\t'), // Tab
                tooltip: 'Tab',
              ),
              IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: _isConnected
                    ? () {
                        _clearScreenBlocks();
                      }
                    : null,
                tooltip: 'Clear Screen',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyInputControls() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          _buildControlKey('Ctrl'),
          _buildControlKey('Alt'),
          _buildControlKey('Esc'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 16),
            onPressed: () => _sendData('\x1b[A'), // Up arrow
            tooltip: 'Up',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 16),
            onPressed: () => _sendData('\x1b[B'), // Down arrow
            tooltip: 'Down',
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_tab, size: 16),
            onPressed: () => _sendData('\t'), // Tab
            tooltip: 'Tab',
          ),
        ],
      ),
    );
  }

  Widget _buildControlKey(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: () {
          switch (label) {
            case 'Ctrl':
              // Ctrl key handling would be complex, showing as placeholder
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use physical Ctrl key')),
              );
              break;
            case 'Alt':
              // Alt key handling
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use physical Alt key')),
              );
              break;
            case 'Esc':
              _sendData('\x1b'); // ESC
              break;
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppTheme.darkBorderColor),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(TapDownDetails details) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      color: AppTheme.darkSurface,
      items: [
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.copy, color: AppTheme.primaryColor, size: 16),
              SizedBox(width: 8),
              Text('Copy', style: TextStyle(color: AppTheme.darkTextPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'paste',
          child: Row(
            children: [
              Icon(Icons.paste, color: AppTheme.primaryColor, size: 16),
              SizedBox(width: 8),
              Text('Paste', style: TextStyle(color: AppTheme.darkTextPrimary)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.clear, color: AppTheme.terminalYellow, size: 16),
              SizedBox(width: 8),
              Text('Clear', style: TextStyle(color: AppTheme.darkTextPrimary)),
            ],
          ),
        ),
      ],
    ).then((value) {
      switch (value) {
        case 'copy':
          // TODO: Implement copy selection functionality
          // _terminal.getSelection() if available
          break;
        case 'paste':
          // Get text from clipboard and paste
          // _terminal.paste(clipboardText);
          break;
        case 'clear':
          _terminal.eraseDisplay();
          break;
      }
    });
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_useBlockUI) ...[
              ListTile(
                leading: Icon(
                  _currentInputMode == TerminalInputMode.ai
                      ? Icons.computer
                      : Icons.psychology,
                  color: _currentInputMode == TerminalInputMode.ai
                      ? AppTheme.primaryColor
                      : AppTheme.terminalGreen,
                ),
                title: Text(
                  'Switch to ${_currentInputMode == TerminalInputMode.ai ? 'Command' : 'AI'} Mode',
                  style: const TextStyle(color: AppTheme.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _toggleInputMode();
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.clear_all, color: AppTheme.terminalYellow),
                title: const Text(
                  'Clear All Blocks',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _terminalBlocks.clear();
                    _blockCounter = 0;
                    _hasWelcomeBlock = false;
                  });
                  
                  // Re-create welcome block if we have a welcome message
                  if (_welcomeMessage.isNotEmpty) {
                    _displayWelcomeMessage(_welcomeMessage);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear_all, color: AppTheme.terminalRed),
                title: const Text(
                  'Clear All Blocks',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearAllBlocks();
                },
              ),
              ListTile(
                leading: Icon(
                  _useBlockUI ? Icons.terminal : Icons.view_list,
                  color: AppTheme.primaryColor,
                ),
                title: Text(
                  'Switch to ${_useBlockUI ? 'Terminal' : 'Block'} View',
                  style: const TextStyle(color: AppTheme.darkTextPrimary),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  
                  // Perform synchronization before mode switch
                  // DISABLED: Sync functionality commented out due to issues
                  /*
                  if (_useBlockUI) {
                    // Switching to Terminal View - sync blocks to terminal
                    await _syncBlocksToTerminal();
                  } else {
                    // Switching to Block UI - sync terminal to blocks
                    await _syncTerminalToBlocks();
                  }
                  */
                  
                  setState(() {
                    _useBlockUI = !_useBlockUI;
                  });
                  
                  // Resize terminal when switching to Terminal View mode
                  if (!_useBlockUI) {
                    _resizeTerminalForCurrentScreen();
                  }
                },
              ),
            ],
            if (!_useBlockUI) ...[
              ListTile(
                leading:
                    const Icon(Icons.clear, color: AppTheme.terminalYellow),
                title: const Text(
                  'Clear Terminal',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _terminal.eraseDisplay();
                },
              ),
            ],
            ListTile(
              leading: Icon(
                _isConnected ? Icons.wifi_off : Icons.wifi,
                color: _isConnected
                    ? AppTheme.terminalRed
                    : AppTheme.terminalGreen,
              ),
              title: Text(
                _isConnected ? 'Disconnect' : 'Reconnect',
                style: const TextStyle(color: AppTheme.darkTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                if (_isConnected) {
                  _disconnectSession();
                } else {
                  _reconnectSession();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.terminalRed),
              title: const Text(
                'Close Session',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _disconnectSession();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _clearAllBlocks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Clear All Blocks',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: const Text(
          'Are you sure you want to clear all terminal blocks? This action cannot be undone.',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _terminalBlocks.clear();
                _blockCounter = 0;
                _hasWelcomeBlock = false;
              });
              
              // Re-create welcome block if we have a welcome message
              if (_welcomeMessage.isNotEmpty) {
                _displayWelcomeMessage(_welcomeMessage);
              }
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All terminal blocks cleared'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppTheme.terminalGreen,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalRed,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
