import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'package:flutter/foundation.dart';

import '../../../services/terminal_input_mode_service.dart';
import '../../../services/terminal_input_mode_models.dart';

/// Controls terminal input handling and mode management
/// Extracted from ssh_terminal_widget.dart to handle input processing
class TerminalInputController {
  // Controllers and input state
  final TextEditingController _inputController = TextEditingController();
  late Terminal _terminal;
  late TerminalController _terminalController;
  
  // Input mode state
  TerminalInputMode _currentInputMode = TerminalInputMode.command;
  bool _isAiProcessing = false;
  bool _enableInput = true;
  bool _useBlockUI = true;
  
  // Service instances
  final TerminalInputModeService _inputModeService = TerminalInputModeService.instance;
  
  // Callbacks
  Function(String)? onDataSent;
  Function(TerminalInputMode)? onInputModeChanged;
  Function(int, int, int, int)? onTerminalResize;
  Function(String)? onError;
  Function()? onStateChanged;
  
  // Getters
  TextEditingController get inputController => _inputController;
  Terminal get terminal => _terminal;
  TerminalController get terminalController => _terminalController;
  TerminalInputMode get currentInputMode => _currentInputMode;
  bool get isAiProcessing => _isAiProcessing;
  bool get enableInput => _enableInput;
  bool get useBlockUI => _useBlockUI;
  
  /// Initialize input controller
  void initialize({
    bool enableInput = true,
    bool useBlockUI = true,
    Function(String)? onDataSent,
    Function(TerminalInputMode)? onInputModeChanged,
    Function(int, int, int, int)? onTerminalResize,
    Function(String)? onError,
    Function()? onStateChanged,
  }) {
    _enableInput = enableInput;
    _useBlockUI = useBlockUI;
    this.onDataSent = onDataSent;
    this.onInputModeChanged = onInputModeChanged;
    this.onTerminalResize = onTerminalResize;
    this.onError = onError;
    this.onStateChanged = onStateChanged;
    
    _initializeTerminal();
    _setupInputModeService();
    
    debugPrint('TerminalInputController initialized (enableInput: $enableInput, useBlockUI: $useBlockUI)');
  }
  
  /// Initialize terminal and controller
  void _initializeTerminal() {
    _terminal = Terminal(maxLines: 5000);
    _terminalController = TerminalController();
    
    // Handle terminal input (for fallback xterm mode)
    _terminal.onOutput = (data) {
      if (_enableInput && !_useBlockUI) {
        debugPrint('Terminal output: ${data.length} characters');
        onDataSent?.call(data);
      }
    };
    
    // Handle terminal resize
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      debugPrint('Terminal resize: ${width}x${height} (${pixelWidth}x${pixelHeight}px)');
      onTerminalResize?.call(width, height, pixelWidth, pixelHeight);
    };
  }
  
  /// Setup input mode service subscription
  void _setupInputModeService() {
    // Initialize with current mode
    _currentInputMode = _inputModeService.currentMode;
    
    debugPrint('Initial input mode: $_currentInputMode');
  }
  
  /// Handle input mode change event
  void handleInputModeChanged(TerminalInputModeEvent event) {
    if (_currentInputMode != event.mode) {
      _currentInputMode = event.mode;
      debugPrint('Input mode changed to: ${event.mode}');
      onInputModeChanged?.call(event.mode);
      onStateChanged?.call();
    }
  }
  
  /// Send data through terminal
  void sendTerminalData(String data) {
    if (!_enableInput) {
      debugPrint('Input disabled, ignoring data: $data');
      return;
    }
    
    try {
      if (_useBlockUI) {
        // In block UI mode, send through callback
        debugPrint('Sending data via block UI: ${data.length} characters');
        onDataSent?.call(data);
      } else {
        // In terminal mode, write directly to terminal
        debugPrint('Writing data to terminal: ${data.length} characters');
        _terminal.write(data);
      }
    } catch (e) {
      final errorMsg = 'Error sending terminal data: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Write data to terminal display
  void writeToTerminal(String data) {
    try {
      _terminal.write(data);
      debugPrint('Wrote to terminal display: ${data.length} characters');
    } catch (e) {
      final errorMsg = 'Error writing to terminal display: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Clear terminal display
  void clearTerminal() {
    try {
      _terminal.buffer.clear();
      debugPrint('Terminal display cleared');
    } catch (e) {
      final errorMsg = 'Error clearing terminal: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Set AI processing state
  void setAiProcessing(bool processing) {
    if (_isAiProcessing != processing) {
      _isAiProcessing = processing;
      debugPrint('AI processing state changed: $processing');
      onStateChanged?.call();
    }
  }
  
  /// Set input enabled state
  void setInputEnabled(bool enabled) {
    if (_enableInput != enabled) {
      _enableInput = enabled;
      debugPrint('Input enabled state changed: $enabled');
      onStateChanged?.call();
    }
  }
  
  /// Set block UI mode
  void setUseBlockUI(bool useBlockUI) {
    if (_useBlockUI != useBlockUI) {
      _useBlockUI = useBlockUI;
      debugPrint('Block UI mode changed: $useBlockUI');
      onStateChanged?.call();
    }
  }
  
  /// Handle command input submission
  void submitCommand(String command) {
    if (!_enableInput || command.trim().isEmpty) {
      debugPrint('Cannot submit command: input disabled or empty command');
      return;
    }
    
    try {
      debugPrint('Submitting command: $command');
      
      // Clear input controller
      _inputController.clear();
      
      // Send command based on current mode
      switch (_currentInputMode) {
        case TerminalInputMode.command:
          _handleCommandModeInput(command);
          break;
        case TerminalInputMode.agent:
          _handleAgentModeInput(command);
          break;
        case TerminalInputMode.terminal:
          _handleTerminalModeInput(command);
          break;
      }
      
    } catch (e) {
      final errorMsg = 'Error submitting command: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Handle command mode input
  void _handleCommandModeInput(String command) {
    debugPrint('Processing command mode input: $command');
    // Add newline for command execution
    onDataSent?.call('$command\n');
  }
  
  /// Handle agent mode input
  void _handleAgentModeInput(String input) {
    debugPrint('Processing agent mode input: $input');
    // Agent mode processing would be handled by parent widget
    setAiProcessing(true);
    // The actual AI processing would be handled by the parent
  }
  
  /// Handle terminal mode input
  void _handleTerminalModeInput(String input) {
    debugPrint('Processing terminal mode input: $input');
    // Send input directly to terminal
    onDataSent?.call(input);
  }
  
  /// Resize terminal
  void resizeTerminal(int cols, int rows) {
    try {
      _terminal.resize(cols, rows);
      debugPrint('Terminal resized to: ${cols}x${rows}');
    } catch (e) {
      final errorMsg = 'Error resizing terminal: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Get input controller statistics
  Map<String, dynamic> getStats() {
    return {
      'currentInputMode': _currentInputMode.toString(),
      'isAiProcessing': _isAiProcessing,
      'enableInput': _enableInput,
      'useBlockUI': _useBlockUI,
      'terminalSize': '${_terminal.viewWidth}x${_terminal.viewHeight}',
      'terminalLines': _terminal.buffer.height,
      'inputControllerText': _inputController.text,
      'hasCallbacks': {
        'onDataSent': onDataSent != null,
        'onInputModeChanged': onInputModeChanged != null,
        'onTerminalResize': onTerminalResize != null,
        'onError': onError != null,
        'onStateChanged': onStateChanged != null,
      },
    };
  }
  
  /// Reset input controller state
  void reset() {
    _inputController.clear();
    _isAiProcessing = false;
    clearTerminal();
    debugPrint('TerminalInputController reset');
  }
  
  /// Cleanup resources
  void dispose() {
    _inputController.dispose();
    debugPrint('TerminalInputController disposed');
  }
}