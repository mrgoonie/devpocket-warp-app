import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';

import '../../themes/app_theme.dart';
import '../../services/xterm_integration_service.dart';
import '../../services/interactive_command_manager.dart';
import '../../models/enhanced_ssh_models.dart';
import 'modal_keyboard_handler.dart';

/// Fullscreen modal for interactive terminal commands like vi, nano, top, htop, etc.
class FullscreenTerminalModal extends ConsumerStatefulWidget {
  final String command;
  final SSHClient? sshClient;
  final VoidCallback onClose;
  final String? sessionId;
  final Map<String, String>? environment;
  
  const FullscreenTerminalModal({
    super.key,
    required this.command,
    required this.onClose,
    this.sshClient,
    this.sessionId,
    this.environment,
  });

  @override
  ConsumerState<FullscreenTerminalModal> createState() => _FullscreenTerminalModalState();
}

class _FullscreenTerminalModalState extends ConsumerState<FullscreenTerminalModal>
    with TickerProviderStateMixin {
  
  late Terminal _terminal;
  late TerminalController _controller;
  late XTermIntegrationService _xtermService;
  late InteractiveCommandManager _commandManager;
  
  final FocusNode _terminalFocusNode = FocusNode();
  StreamSubscription? _outputSubscription;
  StreamSubscription? _keySubscription;
  
  bool _isInitialized = false;
  bool _isCommandRunning = false;
  bool _showKeyboard = false;
  String? _error;
  
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    _initializeAnimations();
    _initializeTerminal();
    
    // Execute command after a delay to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _executeCommand();
        }
      });
    });
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    // Start animations
    _slideController.forward();
    _fadeController.forward();
  }

  void _initializeTerminal() {
    try {
      _terminal = Terminal(
        maxLines: 10000,
        onOutput: _handleTerminalInput,
        onBell: () {
          if (mounted) {
            HapticFeedback.lightImpact();
          }
        },
        onTitleChange: (title) {
          // Could update modal title if needed
        },
        onResize: (width, height, pixelWidth, pixelHeight) {
          // Handle terminal resize
        },
      );

      _controller = TerminalController();
      
      // Initialize services
      try {
        _xtermService = XTermIntegrationService(
          terminal: _terminal,
          controller: _controller,
        );
        
        _commandManager = InteractiveCommandManager.instance;
        
        // Configure terminal for fullscreen
        _xtermService.configureForFullscreen();
        
        setState(() {
          _isInitialized = true;
        });
        
        // Request focus after initialization
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _terminalFocusNode.requestFocus();
          }
        });
        
      } catch (serviceError) {
        setState(() {
          _error = 'Failed to initialize terminal services: $serviceError';
          _isInitialized = false;
        });
      }
      
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize terminal: $e';
        _isInitialized = false;
      });
    }
  }

  Future<void> _executeCommand() async {
    if (!_isInitialized) {
      // Wait a bit and retry if not initialized
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isInitialized) {
        _handleCommandError('Terminal not properly initialized');
        return;
      }
    }
    
    try {
      setState(() {
        _isCommandRunning = true;
        _error = null;
      });
      
      // Add a small delay to ensure terminal is ready
      await Future.delayed(const Duration(milliseconds: 50));
      
      await _commandManager.executeFullscreenCommand(
        command: widget.command,
        terminal: _terminal,
        sshClient: widget.sshClient,
        environment: widget.environment,
        onOutput: _handleCommandOutput,
        onError: _handleCommandError,
        onExit: _handleCommandExit,
      );
      
    } catch (e) {
      _handleCommandError('Failed to execute command: $e');
    }
  }

  void _handleTerminalInput(String data) {
    if (_commandManager.isActive && _isCommandRunning) {
      _commandManager.sendInput(data);
    }
  }
  
  void _handleCommandOutput(String output) {
    if (mounted) {
      _terminal.write(output);
    }
  }
  
  void _handleCommandError(String error) {
    if (mounted) {
      setState(() {
        _error = error;
      });
      _terminal.write('\r\n[ERROR] $error\r\n');
    }
  }
  
  void _handleCommandExit(int exitCode) {
    if (mounted) {
      setState(() {
        _isCommandRunning = false;
      });
      
      if (exitCode == 0) {
        // Command completed successfully, close modal
        _handleClose();
      } else {
        // Show exit code
        _terminal.write('\r\n[Process exited with code $exitCode]\r\n');
      }
    }
  }

  Future<bool> _handleWillPop() async {
    if (_isCommandRunning) {
      // Show confirmation dialog for running commands
      final shouldExit = await _showExitConfirmation();
      if (shouldExit) {
        await _terminateCommand();
        return true;
      }
      return false;
    }
    return true;
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: Text(
          'Exit Command',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Text(
          'The command "${widget.command}" is still running. Are you sure you want to exit?',
          style: TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.terminalBlue)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Exit', style: TextStyle(color: AppTheme.terminalRed)),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _terminateCommand() async {
    if (_commandManager.isActive) {
      await _commandManager.terminate();
    }
  }

  void _handleClose() {
    _slideController.reverse().then((_) {
      widget.onClose();
    });
  }

  void _handleKeyboardToggle() {
    setState(() {
      _showKeyboard = !_showKeyboard;
    });
  }

  void _sendControlSequence(String sequence) {
    if (_commandManager.isActive && _isCommandRunning) {
      _commandManager.sendInput(sequence);
    }
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _keySubscription?.cancel();
    _terminalFocusNode.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    _commandManager.cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildTerminalView(),
                  ),
                  if (_showKeyboard || MediaQuery.of(context).viewInsets.bottom == 0)
                    _buildControlBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      color: AppTheme.darkSurface,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close, color: AppTheme.darkTextPrimary),
            onPressed: _handleClose,
            tooltip: 'Close (ESC)',
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.command,
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'JetBrainsMono',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.sshClient != null)
                  Text(
                    'SSH Connection',
                    style: TextStyle(
                      color: AppTheme.darkTextSecondary,
                      fontSize: 12,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
              ],
            ),
          ),
          if (_isCommandRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.terminalGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppTheme.terminalGreen,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Running',
                    style: TextStyle(
                      color: AppTheme.terminalGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(
              _showKeyboard ? Icons.keyboard_hide : Icons.keyboard,
              color: AppTheme.darkTextSecondary,
            ),
            onPressed: _handleKeyboardToggle,
            tooltip: 'Toggle virtual keyboard',
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalView() {
    if (_error != null) {
      return _buildErrorView();
    }

    if (!_isInitialized) {
      return _buildLoadingView();
    }

    return Container(
      color: Colors.black,
      child: ModalKeyboardHandler(
        focusNode: _terminalFocusNode,
        onInput: _handleTerminalInput,
        onEscape: _handleClose,
        onControlSequence: _sendControlSequence,
        child: TerminalView(
          _terminal,
          controller: _controller,
          autofocus: true,
          backgroundOpacity: 1.0,
          padding: const EdgeInsets.all(8),
          theme: XTermIntegrationService.darkTheme,
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.terminalRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Terminal Error',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleClose,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.terminalRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppTheme.terminalBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Initializing terminal...',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      height: 48,
      color: AppTheme.darkBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _buildControlButton('ESC', () => _sendControlSequence('\x1b')),
            _buildControlButton('Tab', () => _sendControlSequence('\t')),
            _buildControlButton('^C', () => _sendControlSequence('\x03')),
            _buildControlButton('^D', () => _sendControlSequence('\x04')),
            _buildControlButton('^Z', () => _sendControlSequence('\x1a')),
            _buildControlButton('^L', () => _sendControlSequence('\x0c')),
            _buildControlButton('↑', () => _sendControlSequence('\x1b[A')),
            _buildControlButton('↓', () => _sendControlSequence('\x1b[B')),
            _buildControlButton('←', () => _sendControlSequence('\x1b[D')),
            _buildControlButton('→', () => _sendControlSequence('\x1b[C')),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
        ),
      ),
    );
  }
}