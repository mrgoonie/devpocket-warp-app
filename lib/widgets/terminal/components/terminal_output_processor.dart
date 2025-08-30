import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../services/ansi_text_processor.dart';
import '../../../services/terminal_text_encoding_service.dart';
import '../../../services/terminal_session_models.dart';
import '../../../models/enhanced_terminal_models.dart';

/// Processes terminal output and handles text formatting
/// Extracted from ssh_terminal_widget.dart to handle output processing
class TerminalOutputProcessor {
  // Service instances
  final AnsiTextProcessor _ansiProcessor = AnsiTextProcessor.instance;
  final TerminalTextEncodingService _encodingService = TerminalTextEncodingService.instance;
  
  // Processing state
  bool _useBlockUI = true;
  StreamController<String>? _currentOutputController;
  
  // Callbacks
  Function(String)? onProcessedOutput;
  Function(String)? onTerminalWrite;
  Function(TerminalBlockStatus)? onBlockStatusUpdate;
  Function(String)? onError;
  
  /// Initialize output processor
  void initialize({
    bool useBlockUI = true,
    Function(String)? onProcessedOutput,
    Function(String)? onTerminalWrite,
    Function(TerminalBlockStatus)? onBlockStatusUpdate,
    Function(String)? onError,
  }) {
    _useBlockUI = useBlockUI;
    this.onProcessedOutput = onProcessedOutput;
    this.onTerminalWrite = onTerminalWrite;
    this.onBlockStatusUpdate = onBlockStatusUpdate;
    this.onError = onError;
    
    debugPrint('TerminalOutputProcessor initialized (useBlockUI: $useBlockUI)');
  }
  
  /// Set current output controller for block UI
  void setOutputController(StreamController<String>? controller) {
    _currentOutputController = controller;
    debugPrint('Output controller set: ${controller != null}');
  }
  
  /// Process terminal output based on type and UI mode
  void processTerminalOutput(TerminalOutput output) {
    try {
      if (_useBlockUI) {
        _processBlockUIOutput(output);
      } else {
        _processTerminalViewOutput(output);
      }
    } catch (e) {
      final errorMsg = 'Error processing terminal output: $e';
      debugPrint(errorMsg);
      onError?.call(errorMsg);
    }
  }
  
  /// Process output for block UI mode
  void _processBlockUIOutput(TerminalOutput output) {
    String processedData;
    
    switch (output.type) {
      case TerminalOutputType.stdout:
      case TerminalOutputType.stderr:
        processedData = _processStandardOutput(output.data);
        _sendToBlockController(processedData);
        break;
        
      case TerminalOutputType.info:
        processedData = _processInfoOutput(output.data);
        _sendToBlockController(processedData);
        break;
        
      case TerminalOutputType.error:
        processedData = _processErrorOutput(output.data);
        _sendToBlockController(processedData);
        onBlockStatusUpdate?.call(TerminalBlockStatus.failed);
        break;
        
      case TerminalOutputType.command:
        // Commands are handled separately in block UI
        debugPrint('Command output ignored in block UI: ${output.data}');
        break;
    }
  }
  
  /// Process output for terminal view mode
  void _processTerminalViewOutput(TerminalOutput output) {
    String processedData;
    
    switch (output.type) {
      case TerminalOutputType.stdout:
      case TerminalOutputType.stderr:
        processedData = _processStandardOutput(output.data);
        _writeToTerminal(processedData);
        break;
        
      case TerminalOutputType.info:
        processedData = _processInfoOutput(output.data);
        _writeToTerminal(processedData);
        break;
        
      case TerminalOutputType.error:
        processedData = _processErrorOutput(output.data);
        _writeToTerminal(processedData);
        break;
        
      case TerminalOutputType.command:
        // Don't echo commands as they're already shown by the shell
        debugPrint('Command output ignored in terminal view: ${output.data}');
        break;
    }
  }
  
  /// Process standard output (stdout/stderr)
  String _processStandardOutput(String data) {
    try {
      // Apply encoding service processing
      final encodedData = _encodingService.processText(data);
      
      // Apply ANSI processing for color/formatting
      final processedData = _ansiProcessor.processAnsiText(encodedData);
      
      debugPrint('Processed standard output: ${data.length} -> ${processedData.length} chars');
      return processedData;
      
    } catch (e) {
      debugPrint('Error processing standard output: $e');
      return data; // Return original data on error
    }
  }
  
  /// Process info output with cyan color
  String _processInfoOutput(String data) {
    try {
      final encodedData = _encodingService.processText(data);
      final coloredData = '\x1b[36m$encodedData\x1b[0m'; // Cyan for info
      final processedData = _ansiProcessor.processAnsiText(coloredData);
      
      debugPrint('Processed info output: ${data.length} chars');
      return processedData;
      
    } catch (e) {
      debugPrint('Error processing info output: $e');
      return '\x1b[36m$data\x1b[0m'; // Fallback to simple coloring
    }
  }
  
  /// Process error output with red color
  String _processErrorOutput(String data) {
    try {
      final encodedData = _encodingService.processText(data);
      final coloredData = '\x1b[31m$encodedData\x1b[0m'; // Red for errors
      final processedData = _ansiProcessor.processAnsiText(coloredData);
      
      debugPrint('Processed error output: ${data.length} chars');
      return processedData;
      
    } catch (e) {
      debugPrint('Error processing error output: $e');
      return '\x1b[31m$data\x1b[0m'; // Fallback to simple coloring
    }
  }
  
  /// Send processed data to block controller
  void _sendToBlockController(String data) {
    if (_currentOutputController != null && !_currentOutputController!.isClosed) {
      _currentOutputController!.add(data);
      onProcessedOutput?.call(data);
    } else {
      debugPrint('Cannot send to block controller: controller unavailable');
    }
  }
  
  /// Write processed data to terminal
  void _writeToTerminal(String data) {
    onTerminalWrite?.call(data);
    onProcessedOutput?.call(data);
  }
  
  /// Process raw string data with ANSI codes
  String processRawOutput(String data) {
    try {
      final encodedData = _encodingService.processText(data);
      final processedData = _ansiProcessor.processAnsiText(encodedData);
      
      debugPrint('Processed raw output: ${data.length} -> ${processedData.length} chars');
      return processedData;
      
    } catch (e) {
      debugPrint('Error processing raw output: $e');
      return data; // Return original data on error
    }
  }
  
  /// Process welcome message with special formatting
  String processWelcomeMessage(String welcomeMsg) {
    try {
      // Welcome messages might contain ANSI codes for formatting
      final processedData = _ansiProcessor.processAnsiText(welcomeMsg);
      
      debugPrint('Processed welcome message: ${welcomeMsg.length} -> ${processedData.length} chars');
      return processedData;
      
    } catch (e) {
      debugPrint('Error processing welcome message: $e');
      return welcomeMsg; // Return original message on error
    }
  }
  
  /// Strip ANSI codes from data
  String stripAnsiCodes(String data) {
    try {
      return _ansiProcessor.stripAnsiCodes(data);
    } catch (e) {
      debugPrint('Error stripping ANSI codes: $e');
      return data;
    }
  }
  
  /// Check if data contains ANSI codes
  bool containsAnsiCodes(String data) {
    try {
      return _ansiProcessor.containsAnsiCodes(data);
    } catch (e) {
      debugPrint('Error checking ANSI codes: $e');
      return false;
    }
  }
  
  /// Set block UI mode
  void setUseBlockUI(bool useBlockUI) {
    if (_useBlockUI != useBlockUI) {
      _useBlockUI = useBlockUI;
      debugPrint('Block UI mode changed: $useBlockUI');
    }
  }
  
  /// Get processor statistics
  Map<String, dynamic> getStats() {
    return {
      'useBlockUI': _useBlockUI,
      'hasOutputController': _currentOutputController != null,
      'outputControllerClosed': _currentOutputController?.isClosed ?? true,
      'hasCallbacks': {
        'onProcessedOutput': onProcessedOutput != null,
        'onTerminalWrite': onTerminalWrite != null,
        'onBlockStatusUpdate': onBlockStatusUpdate != null,
        'onError': onError != null,
      },
    };
  }
  
  /// Reset processor state
  void reset() {
    _currentOutputController = null;
    debugPrint('TerminalOutputProcessor reset');
  }
  
  /// Cleanup resources
  void dispose() {
    reset();
    debugPrint('TerminalOutputProcessor disposed');
  }
}