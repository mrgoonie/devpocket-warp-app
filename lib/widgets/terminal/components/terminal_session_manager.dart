import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../models/ssh_profile_models.dart';
import '../../../models/enhanced_terminal_models.dart';
import '../../../services/terminal_session_handler.dart';
import '../../../services/ssh_connection_manager.dart';
import '../../../services/ssh_connection_models.dart';
import '../../../services/terminal_session_models.dart';

/// Manages terminal sessions, blocks, and output handling
/// Extracted from ssh_terminal_widget.dart to handle session lifecycle
class TerminalSessionManager {
  // Service instances
  final TerminalSessionHandler _sessionHandler = TerminalSessionHandler.instance;
  final SshConnectionManager _sshManager = SshConnectionManager.instance;
  
  // Session state
  String? _currentSessionId;
  bool _useBlockUI = true;
  StreamController<String>? _currentOutputController;
  final List<TerminalBlockData> _terminalBlocks = [];
  int _blockCounter = 0;
  bool _hasWelcomeBlock = false;
  
  // Callbacks
  Function(TerminalBlockData)? onNewBlock;
  Function(String, TerminalBlockStatus)? onBlockStatusUpdate;
  Function(List<TerminalBlockData>)? onBlocksChanged;
  Function(String)? onError;
  Function()? onSessionClosed;
  
  // Getters
  String? get currentSessionId => _currentSessionId;
  bool get useBlockUI => _useBlockUI;
  List<TerminalBlockData> get terminalBlocks => List.unmodifiable(_terminalBlocks);
  int get blockCount => _terminalBlocks.length;
  bool get hasWelcomeBlock => _hasWelcomeBlock;
  StreamController<String>? get currentOutputController => _currentOutputController;
  
  /// Initialize session manager with callbacks
  void initialize({
    Function(TerminalBlockData)? onNewBlock,
    Function(String, TerminalBlockStatus)? onBlockStatusUpdate,
    Function(List<TerminalBlockData>)? onBlocksChanged,
    Function(String)? onError,
    Function()? onSessionClosed,
    bool useBlockUI = true,
  }) {
    this.onNewBlock = onNewBlock;
    this.onBlockStatusUpdate = onBlockStatusUpdate;
    this.onBlocksChanged = onBlocksChanged;
    this.onError = onError;
    this.onSessionClosed = onSessionClosed;
    _useBlockUI = useBlockUI;
  }
  
  /// Set current session ID
  void setSessionId(String? sessionId) {
    _currentSessionId = sessionId;
    debugPrint('Session ID set to: $sessionId');
  }
  
  /// Handle terminal output based on UI mode
  void handleTerminalOutput(TerminalOutput output, {
    required Function(String) writeToTerminal,
  }) {
    if (_useBlockUI) {
      _handleBlockOutput(output);
    } else {
      _handleTerminalViewOutput(output, writeToTerminal);
    }
  }
  
  /// Handle output in block UI mode
  void _handleBlockOutput(TerminalOutput output) {
    switch (output.type) {
      case TerminalOutputType.stdout:
      case TerminalOutputType.stderr:
        _currentOutputController?.add(output.data);
        break;
        
      case TerminalOutputType.info:
        _currentOutputController?.add('\x1b[36m${output.data}\x1b[0m'); // Cyan
        break;
        
      case TerminalOutputType.error:
        _currentOutputController?.add('\x1b[31m${output.data}\x1b[0m'); // Red
        _updateCurrentBlockStatus(TerminalBlockStatus.failed);
        break;
        
      case TerminalOutputType.command:
        // Commands are handled separately in block UI
        break;
    }
  }
  
  /// Handle output in terminal view mode
  void _handleTerminalViewOutput(TerminalOutput output, Function(String) writeToTerminal) {
    switch (output.type) {
      case TerminalOutputType.stdout:
      case TerminalOutputType.stderr:
        writeToTerminal(output.data);
        break;
        
      case TerminalOutputType.info:
        writeToTerminal('\x1b[36m${output.data}\x1b[0m'); // Cyan for info
        break;
        
      case TerminalOutputType.error:
        writeToTerminal('\x1b[31m${output.data}\x1b[0m'); // Red for errors
        break;
        
      case TerminalOutputType.command:
        // Don't echo commands as they're already shown by the shell
        break;
    }
  }
  
  /// Send data to current session
  Future<void> sendData(String data, {SshProfile? profile}) async {
    if (_currentSessionId == null) {
      debugPrint('Cannot send data: no session ID');
      return;
    }
    
    try {
      if (profile != null) {
        // Use SSH connection manager for SSH sessions
        await _sshManager.sendData(_currentSessionId!, data);
      } else {
        // Use session handler for local sessions
        await _sessionHandler.sendData(_currentSessionId!, data);
      }
      debugPrint('Sent data: ${data.length} characters');
    } catch (e) {
      final errorMsg = 'Error sending data: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Disconnect current session
  Future<void> disconnectSession({SshProfile? profile}) async {
    if (_currentSessionId == null) return;
    
    try {
      if (profile != null) {
        // SSH session - use SSH connection manager
        await _sshManager.disconnect(_currentSessionId!);
      } else {
        // Local session - use session handler
        await _sessionHandler.stopSession(_currentSessionId!);
      }
      
      _currentSessionId = null;
      _currentOutputController?.close();
      _currentOutputController = null;
      
      debugPrint('Session disconnected and cleaned up');
      onSessionClosed?.call();
      
    } catch (e) {
      debugPrint('Error disconnecting session: $e');
      onError?.call('Disconnect error: $e');
    }
  }
  
  /// Display welcome message as first block
  void displayWelcomeMessage(String welcomeMsg) {
    if (_hasWelcomeBlock || welcomeMsg.isEmpty) return;
    
    final welcomeBlock = TerminalBlockData(
      id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
      command: '',
      output: welcomeMsg,
      status: TerminalBlockStatus.completed,
      createdAt: DateTime.now(),
      isWelcomeMessage: true,
    );
    
    _terminalBlocks.insert(0, welcomeBlock);
    _hasWelcomeBlock = true;
    
    debugPrint('Welcome message displayed: ${welcomeMsg.length} characters');
    onNewBlock?.call(welcomeBlock);
    onBlocksChanged?.call(_terminalBlocks);
  }
  
  /// Create new terminal block
  TerminalBlockData createNewBlock({
    required String command,
    String? blockId,
    bool isInteractive = false,
  }) {
    final effectiveBlockId = blockId ?? 'block_${_blockCounter++}_${DateTime.now().millisecondsSinceEpoch}';
    
    final block = TerminalBlockData(
      id: effectiveBlockId,
      command: command,
      output: '',
      status: isInteractive ? TerminalBlockStatus.interactive : TerminalBlockStatus.running,
      createdAt: DateTime.now(),
      isInteractive: isInteractive,
    );
    
    _terminalBlocks.add(block);
    
    // Create output stream for this block
    if (_useBlockUI) {
      _currentOutputController?.close();
      _currentOutputController = StreamController<String>.broadcast();
    }
    
    debugPrint('Created new block: ${block.id} (interactive: $isInteractive)');
    onNewBlock?.call(block);
    onBlocksChanged?.call(_terminalBlocks);
    
    return block;
  }
  
  /// Update current block status
  void _updateCurrentBlockStatus(TerminalBlockStatus status) {
    if (_terminalBlocks.isEmpty) return;
    
    final currentBlock = _terminalBlocks.last;
    if (currentBlock.status != status) {
      final updatedBlock = currentBlock.copyWith(status: status);
      _terminalBlocks[_terminalBlocks.length - 1] = updatedBlock;
      
      debugPrint('Updated block ${currentBlock.id} status to $status');
      onBlockStatusUpdate?.call(currentBlock.id, status);
      onBlocksChanged?.call(_terminalBlocks);
    }
  }
  
  /// Update block by ID
  void updateBlock(String blockId, {
    String? output,
    TerminalBlockStatus? status,
    String? currentCommand,
  }) {
    final index = _terminalBlocks.indexWhere((block) => block.id == blockId);
    if (index == -1) return;
    
    final currentBlock = _terminalBlocks[index];
    final updatedBlock = currentBlock.copyWith(
      output: output ?? currentBlock.output,
      status: status ?? currentBlock.status,
      currentCommand: currentCommand ?? currentBlock.currentCommand,
    );
    
    _terminalBlocks[index] = updatedBlock;
    
    debugPrint('Updated block $blockId');
    if (status != null && status != currentBlock.status) {
      onBlockStatusUpdate?.call(blockId, status);
    }
    onBlocksChanged?.call(_terminalBlocks);
  }
  
  /// Get block by ID
  TerminalBlockData? getBlock(String blockId) {
    try {
      return _terminalBlocks.firstWhere((block) => block.id == blockId);
    } catch (e) {
      return null;
    }
  }
  
  /// Remove block by ID
  bool removeBlock(String blockId) {
    final index = _terminalBlocks.indexWhere((block) => block.id == blockId);
    if (index == -1) return false;
    
    _terminalBlocks.removeAt(index);
    debugPrint('Removed block: $blockId');
    onBlocksChanged?.call(_terminalBlocks);
    return true;
  }
  
  /// Clear all blocks
  void clearBlocks() {
    _terminalBlocks.clear();
    _blockCounter = 0;
    _hasWelcomeBlock = false;
    _currentOutputController?.close();
    _currentOutputController = null;
    
    debugPrint('Cleared all terminal blocks');
    onBlocksChanged?.call(_terminalBlocks);
  }
  
  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'sessionId': _currentSessionId,
      'blockCount': _terminalBlocks.length,
      'hasWelcomeBlock': _hasWelcomeBlock,
      'useBlockUI': _useBlockUI,
      'activeOutputController': _currentOutputController != null,
      'runningBlocks': _terminalBlocks.where((b) => b.status == TerminalBlockStatus.running).length,
      'completedBlocks': _terminalBlocks.where((b) => b.status == TerminalBlockStatus.completed).length,
      'failedBlocks': _terminalBlocks.where((b) => b.status == TerminalBlockStatus.failed).length,
    };
  }
  
  /// Cleanup resources
  void dispose() {
    _currentOutputController?.close();
    _currentOutputController = null;
    _terminalBlocks.clear();
    debugPrint('TerminalSessionManager disposed');
  }
}