import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../services/terminal_session_handler.dart';

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
  final TerminalSessionHandler _sessionHandler = TerminalSessionHandler.instance;
  
  bool _isConnected = false;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeTerminal();
    _setupSession();
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _disconnectSession();
    super.dispose();
  }

  void _initializeTerminal() {
    _terminal = Terminal(
      maxLines: 10000,
    );
    
    _controller = TerminalController();
    
    // Handle terminal input
    _terminal.onOutput = (data) {
      if (_isConnected && _currentSessionId != null) {
        _sendData(data);
      }
    };
    
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      // Handle terminal resize if needed
    };
  }


  Future<void> _setupSession() async {
    try {
      if (widget.sessionId != null) {
        // Use existing session
        _currentSessionId = widget.sessionId;
        _isConnected = _sessionHandler.isSessionRunning(_currentSessionId!);
      } else if (widget.profile != null) {
        // Create new SSH session
        setState(() {
          _status = 'Connecting to ${widget.profile!.connectionString}...';
        });
        
        _currentSessionId = await _sessionHandler.createSshSession(widget.profile!);
        _isConnected = true;
      } else {
        // Create local session
        setState(() {
          _status = 'Starting local terminal...';
        });
        
        _currentSessionId = await _sessionHandler.createLocalSession();
        _isConnected = true;
      }
      
      // Listen to terminal output
      _outputSubscription = _sessionHandler.output.listen(
        _handleTerminalOutput,
        onError: (error) {
          _terminal.write('Terminal error: $error\r\n');
          setState(() {
            _status = 'Error: $error';
            _isConnected = false;
          });
        },
      );
      
      setState(() {
        _status = 'Connected';
      });
      
      // Show welcome message
      if (widget.profile != null) {
        _terminal.write('Connected to ${widget.profile!.connectionString}\r\n');
      } else {
        _terminal.write('Terminal session started\r\n');
      }
      
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
        _isConnected = false;
      });
      
      _terminal.write('Connection failed: $e\r\n');
      _terminal.write('Press Ctrl+R to retry or Ctrl+Q to close\r\n');
    }
  }

  void _handleTerminalOutput(TerminalOutput output) {
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

  Future<void> _sendData(String data) async {
    if (!_isConnected || _currentSessionId == null) return;
    
    try {
      await _sessionHandler.sendData(_currentSessionId!, data);
    } catch (e) {
      _terminal.write('\r\nError sending data: $e\r\n');
    }
  }


  Future<void> _disconnectSession() async {
    if (_currentSessionId != null) {
      try {
        await _sessionHandler.stopSession(_currentSessionId!);
        _currentSessionId = null;
        _isConnected = false;
        widget.onSessionClosed?.call();
      } catch (e) {
        debugPrint('Error disconnecting session: $e');
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusBar(),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              border: Border.all(
                color: AppTheme.darkBorderColor,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TerminalView(
                _terminal,
                controller: _controller,
                autofocus: true,
                backgroundOpacity: 1.0,
                onSecondaryTapDown: widget.enableInput ? (details, offset) => _showContextMenu(details) : null,
              ),
            ),
          ),
        ),
        if (widget.enableInput) _buildInputControls(),
      ],
    );
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
              color: _isConnected ? AppTheme.terminalGreen : AppTheme.terminalRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.profile?.connectionString ?? 'Local Terminal',
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            _status,
            style: const TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
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
            ListTile(
              leading: Icon(
                _isConnected ? Icons.wifi_off : Icons.wifi,
                color: _isConnected ? AppTheme.terminalRed : AppTheme.terminalGreen,
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
              leading: const Icon(Icons.clear, color: AppTheme.terminalYellow),
              title: const Text(
                'Clear Terminal',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _terminal.eraseDisplay();
              },
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen, color: AppTheme.primaryColor),
              title: const Text(
                'Fullscreen',
                style: TextStyle(color: AppTheme.darkTextPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement fullscreen mode
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fullscreen mode coming soon')),
                );
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
}