import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'terminal_block_state_manager.dart';

/// Handles user interactions for terminal block widgets
/// Manages input submission, gestures, keyboard shortcuts, and action callbacks
class TerminalBlockInteractionHandler {
  final TerminalBlockStateManager stateManager;
  final TextEditingController inputController = TextEditingController();
  
  // Callback functions
  final VoidCallback? onRerun;
  final VoidCallback? onCancel;
  final VoidCallback? onEnterFullscreen;
  final ValueChanged<String>? onInputSubmit;
  final VoidCallback? onTap;

  TerminalBlockInteractionHandler({
    required this.stateManager,
    this.onRerun,
    this.onCancel,
    this.onEnterFullscreen,
    this.onInputSubmit,
    this.onTap,
  });

  /// Handle tap gesture on the terminal block
  void handleBlockTap() {
    // Focus the block if it's interactive
    if (stateManager.canAcceptInput()) {
      stateManager.focusBlock();
    }
    
    // Call custom tap callback
    onTap?.call();
  }

  /// Handle long press gesture
  void handleLongPress(BuildContext context) {
    // Show context menu for copy/paste operations
    _showContextMenu(context);
  }

  /// Handle input submission
  void handleInputSubmit() {
    final input = inputController.text.trim();
    if (input.isEmpty) return;

    // Send input to active block if possible
    if (stateManager.canAcceptInput()) {
      final success = stateManager.sendInput(input);
      if (success) {
        inputController.clear();
        return;
      }
    }

    // Fallback to callback
    onInputSubmit?.call(input);
    inputController.clear();
  }

  /// Handle keyboard shortcuts
  bool handleKeyEvent(KeyEvent event) {
    // Only handle key down events
    if (event is! KeyDownEvent) return false;

    final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl+C - Copy output or cancel process
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (stateManager.isActiveBlock && stateManager.canAcceptInput()) {
        // Send Ctrl+C to active process
        stateManager.sendInput('\x03'); // ETX (End of Text)
        return true;
      } else {
        // Copy output to clipboard
        _copyOutputToClipboard();
        return true;
      }
    }

    // Ctrl+D - Send EOF to process
    if (isCtrlPressed && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (stateManager.canAcceptInput()) {
        stateManager.sendInput('\x04'); // EOT (End of Transmission)
        return true;
      }
    }

    // Enter - Submit input or expand command
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (inputController.text.isNotEmpty) {
        handleInputSubmit();
        return true;
      } else if (isShiftPressed) {
        // Shift+Enter - toggle command display
        _toggleCommandDisplay();
        return true;
      }
    }

    // Escape - Clear input or cancel
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (inputController.text.isNotEmpty) {
        inputController.clear();
        return true;
      } else {
        onCancel?.call();
        return true;
      }
    }

    // F11 - Toggle fullscreen
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      onEnterFullscreen?.call();
      return true;
    }

    return false;
  }

  /// Show context menu for additional actions
  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Output'),
                onTap: () {
                  Navigator.pop(context);
                  _copyOutputToClipboard();
                },
              ),
              if (onRerun != null)
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Rerun Command'),
                  onTap: () {
                    Navigator.pop(context);
                    onRerun?.call();
                  },
                ),
              if (onCancel != null && stateManager.isActiveBlock)
                ListTile(
                  leading: const Icon(Icons.stop),
                  title: const Text('Cancel Process'),
                  onTap: () {
                    Navigator.pop(context);
                    onCancel?.call();
                  },
                ),
              if (onEnterFullscreen != null)
                ListTile(
                  leading: const Icon(Icons.fullscreen),
                  title: const Text('Enter Fullscreen'),
                  onTap: () {
                    Navigator.pop(context);
                    onEnterFullscreen?.call();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Block Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockInfo(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Copy output to clipboard
  void _copyOutputToClipboard() {
    final output = stateManager.processedOutput;
    if (output.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: output));
      // Could show a snackbar here if context is available
    }
  }

  /// Toggle command display (full/truncated)
  void _toggleCommandDisplay() {
    stateManager.setShowFullCommand(!stateManager.showFullCommand);
  }

  /// Show block information dialog
  void _showBlockInfo(BuildContext context) {
    final stateInfo = stateManager.getStateInfo();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Block Information'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Block ID', stateInfo.blockId),
                if (stateInfo.sessionId != null)
                  _buildInfoRow('Session ID', stateInfo.sessionId!),
                _buildInfoRow('Active Block', stateInfo.isActiveBlock ? 'Yes' : 'No'),
                _buildInfoRow('Focused', stateInfo.isFocused ? 'Yes' : 'No'),
                _buildInfoRow('Command Type', stateInfo.commandType.name),
                _buildInfoRow('Can Accept Input', stateInfo.canAcceptInput ? 'Yes' : 'No'),
                _buildInfoRow('Output Length', '${stateInfo.outputLength} characters'),
                if (stateInfo.processInfo != null) ...[
                  const Divider(),
                  const Text('Process Information:', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildInfoRow('Process Type', stateInfo.processInfo!.type.name),
                  _buildInfoRow('Requires Input', stateInfo.processInfo!.requiresInput ? 'Yes' : 'No'),
                  _buildInfoRow('Is Persistent', stateInfo.processInfo!.isPersistent ? 'Yes' : 'No'),
                  _buildInfoRow('Needs PTY', stateInfo.processInfo!.needsPTY ? 'Yes' : 'No'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Build information row widget
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  /// Create input field widget
  Widget buildInputField({
    required BuildContext context,
    bool enabled = true,
    String? hintText,
    TextStyle? style,
  }) {
    return TextField(
      controller: inputController,
      enabled: enabled && stateManager.canAcceptInput(),
      style: style,
      decoration: InputDecoration(
        hintText: hintText ?? (stateManager.canAcceptInput() 
            ? 'Enter command...' 
            : 'Block not interactive'),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      ),
      onSubmitted: (_) => handleInputSubmit(),
      textInputAction: TextInputAction.send,
    );
  }

  /// Get interaction capabilities info
  TerminalBlockInteractionInfo getInteractionInfo() {
    return TerminalBlockInteractionInfo(
      canAcceptInput: stateManager.canAcceptInput(),
      isActive: stateManager.isActiveBlock,
      isFocused: stateManager.isFocused,
      hasRerunCallback: onRerun != null,
      hasCancelCallback: onCancel != null,
      hasFullscreenCallback: onEnterFullscreen != null,
      hasInputCallback: onInputSubmit != null,
      hasTapCallback: onTap != null,
    );
  }

  /// Dispose resources
  void dispose() {
    inputController.dispose();
  }
}

/// Information about terminal block interaction capabilities
class TerminalBlockInteractionInfo {
  final bool canAcceptInput;
  final bool isActive;
  final bool isFocused;
  final bool hasRerunCallback;
  final bool hasCancelCallback;
  final bool hasFullscreenCallback;
  final bool hasInputCallback;
  final bool hasTapCallback;

  const TerminalBlockInteractionInfo({
    required this.canAcceptInput,
    required this.isActive,
    required this.isFocused,
    required this.hasRerunCallback,
    required this.hasCancelCallback,
    required this.hasFullscreenCallback,
    required this.hasInputCallback,
    required this.hasTapCallback,
  });

  @override
  String toString() {
    return 'TerminalBlockInteractionInfo{input: $canAcceptInput, active: $isActive, focused: $isFocused}';
  }
}