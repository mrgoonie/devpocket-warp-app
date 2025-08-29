import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keyboard handler for fullscreen terminal modal
class ModalKeyboardHandler extends StatefulWidget {
  final Widget child;
  final FocusNode focusNode;
  final Function(String) onInput;
  final VoidCallback onEscape;
  final Function(String)? onControlSequence;
  final bool isTerminalApplicationRunning;
  
  const ModalKeyboardHandler({
    super.key,
    required this.child,
    required this.focusNode,
    required this.onInput,
    required this.onEscape,
    this.onControlSequence,
    this.isTerminalApplicationRunning = false,
  });

  @override
  State<ModalKeyboardHandler> createState() => _ModalKeyboardHandlerState();
}

class _ModalKeyboardHandlerState extends State<ModalKeyboardHandler> {
  final Map<LogicalKeyboardKey, String> _controlSequences = {
    LogicalKeyboardKey.keyA: '\x01', // Ctrl+A (Home)
    LogicalKeyboardKey.keyB: '\x02', // Ctrl+B (Left)
    LogicalKeyboardKey.keyC: '\x03', // Ctrl+C (SIGINT)
    LogicalKeyboardKey.keyD: '\x04', // Ctrl+D (EOF)
    LogicalKeyboardKey.keyE: '\x05', // Ctrl+E (End)
    LogicalKeyboardKey.keyF: '\x06', // Ctrl+F (Right)
    LogicalKeyboardKey.keyG: '\x07', // Ctrl+G (Bell)
    LogicalKeyboardKey.keyH: '\x08', // Ctrl+H (Backspace)
    LogicalKeyboardKey.keyI: '\x09', // Ctrl+I (Tab)
    LogicalKeyboardKey.keyJ: '\x0A', // Ctrl+J (Line Feed)
    LogicalKeyboardKey.keyK: '\x0B', // Ctrl+K (Kill line)
    LogicalKeyboardKey.keyL: '\x0C', // Ctrl+L (Clear screen)
    LogicalKeyboardKey.keyM: '\x0D', // Ctrl+M (Carriage return)
    LogicalKeyboardKey.keyN: '\x0E', // Ctrl+N (Next)
    LogicalKeyboardKey.keyO: '\x0F', // Ctrl+O
    LogicalKeyboardKey.keyP: '\x10', // Ctrl+P (Previous)
    LogicalKeyboardKey.keyQ: '\x11', // Ctrl+Q (XON)
    LogicalKeyboardKey.keyR: '\x12', // Ctrl+R (Reverse search)
    LogicalKeyboardKey.keyS: '\x13', // Ctrl+S (XOFF)
    LogicalKeyboardKey.keyT: '\x14', // Ctrl+T
    LogicalKeyboardKey.keyU: '\x15', // Ctrl+U (Kill line backwards)
    LogicalKeyboardKey.keyV: '\x16', // Ctrl+V
    LogicalKeyboardKey.keyW: '\x17', // Ctrl+W (Kill word backwards)
    LogicalKeyboardKey.keyX: '\x18', // Ctrl+X
    LogicalKeyboardKey.keyY: '\x19', // Ctrl+Y (Yank)
    LogicalKeyboardKey.keyZ: '\x1A', // Ctrl+Z (SIGTSTP)
  };

  final Map<LogicalKeyboardKey, String> _escapeSequences = {
    LogicalKeyboardKey.arrowUp: '\x1b[A',
    LogicalKeyboardKey.arrowDown: '\x1b[B',
    LogicalKeyboardKey.arrowRight: '\x1b[C',
    LogicalKeyboardKey.arrowLeft: '\x1b[D',
    LogicalKeyboardKey.home: '\x1b[H',
    LogicalKeyboardKey.end: '\x1b[F',
    LogicalKeyboardKey.pageUp: '\x1b[5~',
    LogicalKeyboardKey.pageDown: '\x1b[6~',
    LogicalKeyboardKey.insert: '\x1b[2~',
    LogicalKeyboardKey.delete: '\x1b[3~',
    LogicalKeyboardKey.f1: '\x1bOP',
    LogicalKeyboardKey.f2: '\x1bOQ',
    LogicalKeyboardKey.f3: '\x1bOR',
    LogicalKeyboardKey.f4: '\x1bOS',
    LogicalKeyboardKey.f5: '\x1b[15~',
    LogicalKeyboardKey.f6: '\x1b[17~',
    LogicalKeyboardKey.f7: '\x1b[18~',
    LogicalKeyboardKey.f8: '\x1b[19~',
    LogicalKeyboardKey.f9: '\x1b[20~',
    LogicalKeyboardKey.f10: '\x1b[21~',
    LogicalKeyboardKey.f11: '\x1b[23~',
    LogicalKeyboardKey.f12: '\x1b[24~',
  };

  @override
  void initState() {
    super.initState();
    
    // Auto-focus the terminal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.focusNode.requestFocus();
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    // Handle escape key - context-aware routing
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (widget.isTerminalApplicationRunning) {
        // Send ESC to terminal for vi/vim/nano editors
        widget.onInput('\x1b');
      } else {
        // Close modal for normal terminal
        widget.onEscape();
      }
      return;
    }

    // Handle control sequences
    if (HardwareKeyboard.instance.isControlPressed) {
      final sequence = _controlSequences[event.logicalKey];
      if (sequence != null) {
        widget.onInput(sequence);
        widget.onControlSequence?.call(sequence);
        return;
      }
    }

    // Handle alt sequences (meta key)
    if (HardwareKeyboard.instance.isAltPressed && event.character != null) {
      widget.onInput('\x1b${event.character}');
      return;
    }

    // Handle special keys (arrows, function keys, etc.)
    final escapeSequence = _escapeSequences[event.logicalKey];
    if (escapeSequence != null) {
      widget.onInput(escapeSequence);
      return;
    }

    // Handle regular character input
    if (event.character != null && !HardwareKeyboard.instance.isControlPressed && !HardwareKeyboard.instance.isMetaPressed) {
      widget.onInput(event.character!);
      return;
    }

    // Handle backspace
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      widget.onInput('\x7f'); // DEL character
      return;
    }

    // Handle enter/return
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onInput('\r');
      return;
    }

    // Handle tab
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        widget.onInput('\x1b[Z'); // Shift+Tab
      } else {
        widget.onInput('\t');
      }
      return;
    }

    // Handle space
    if (event.logicalKey == LogicalKeyboardKey.space) {
      widget.onInput(' ');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () {
          // Ensure focus when tapped
          widget.focusNode.requestFocus();
        },
        child: widget.child,
      ),
    );
  }
}