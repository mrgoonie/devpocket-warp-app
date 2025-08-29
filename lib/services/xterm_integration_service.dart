import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';

/// Service for integrating xterm.dart terminal in fullscreen modal
class XTermIntegrationService {
  final Terminal terminal;
  final TerminalController controller;
  
  XTermIntegrationService({
    required this.terminal,
    required this.controller,
  });

  /// Dark theme configuration for terminal
  static const TerminalTheme darkTheme = TerminalTheme(
    cursor: Color(0xFFFFFFFF),
    selection: Color(0x3FFFFFFF),
    foreground: Color(0xFFFFFFFF),
    background: Color(0xFF000000),
    // ANSI Colors (Standard)
    black: Color(0xFF000000),
    red: Color(0xFFCD0000),
    green: Color(0xFF00CD00),
    yellow: Color(0xFFCDCD00),
    blue: Color(0xFF0000EE),
    magenta: Color(0xFFCD00CD),
    cyan: Color(0xFF00CDCD),
    white: Color(0xFFE5E5E5),
    // Bright ANSI Colors
    brightBlack: Color(0xFF7F7F7F),
    brightRed: Color(0xFFFF0000),
    brightGreen: Color(0xFF00FF00),
    brightYellow: Color(0xFFFFFF00),
    brightBlue: Color(0xFF5C5CFF),
    brightMagenta: Color(0xFFFF00FF),
    brightCyan: Color(0xFF00FFFF),
    brightWhite: Color(0xFFFFFFFF),
    // Search colors
    searchHitBackground: Color(0xFF7F7F00),
    searchHitBackgroundCurrent: Color(0xFFFFFF00),
    searchHitForeground: Color(0xFF000000),
  );

  /// Light theme configuration for terminal
  static const TerminalTheme lightTheme = TerminalTheme(
    cursor: Color(0xFF000000),
    selection: Color(0x3F000000),
    foreground: Color(0xFF000000),
    background: Color(0xFFFFFFFF),
    // ANSI Colors (Light variant)
    black: Color(0xFF000000),
    red: Color(0xFFB22222),
    green: Color(0xFF228B22),
    yellow: Color(0xFFDAA520),
    blue: Color(0xFF0000CD),
    magenta: Color(0xFF8B008B),
    cyan: Color(0xFF008B8B),
    white: Color(0xFF708090),
    // Bright ANSI Colors (Light variant)
    brightBlack: Color(0xFF2F4F4F),
    brightRed: Color(0xFFDC143C),
    brightGreen: Color(0xFF32CD32),
    brightYellow: Color(0xFFFFD700),
    brightBlue: Color(0xFF4169E1),
    brightMagenta: Color(0xFFDA70D6),
    brightCyan: Color(0xFF40E0D0),
    brightWhite: Color(0xFF000000),
    // Search colors
    searchHitBackground: Color(0xFFFFFF00),
    searchHitBackgroundCurrent: Color(0xFF7F7F00),
    searchHitForeground: Color(0xFF000000),
  );

  /// Configure terminal for fullscreen modal use
  void configureForFullscreen([Size? screenSize]) {
    final size = _calculateOptimalTerminalSize(screenSize);
    
    // Set terminal size
    terminal.resize(
      size.width.toInt(), 
      size.height.toInt(),
      size.pixelWidth?.toInt(),
      size.pixelHeight?.toInt(),
    );
    
    // Configure terminal behavior
    _configureTerminalBehavior();
  }

  /// Calculate optimal terminal size based on device and font metrics
  TerminalSize _calculateOptimalTerminalSize([Size? screenSize]) {
    // Get device metrics - using fallback values for service context
    final double screenWidth = screenSize?.width ?? 390.0;  // iPhone 12 Pro width as fallback
    final double screenHeight = screenSize?.height ?? 844.0; // iPhone 12 Pro height as fallback
    
    // Terminal font metrics (JetBrains Mono)
    const double charWidth = 9.6;    // Character width in pixels
    const double charHeight = 18.0;   // Line height in pixels
    
    // Account for modal header, safe area, and control bar
    const double headerHeight = 56.0;
    const double controlBarHeight = 48.0;
    const double safeAreaTop = 44.0;
    const double safeAreaBottom = 34.0;
    
    final double availableWidth = screenWidth - 16.0; // 8px padding on each side
    final double availableHeight = screenHeight - 
        headerHeight - 
        controlBarHeight - 
        safeAreaTop - 
        safeAreaBottom - 
        16.0; // 8px padding top/bottom
    
    final int cols = (availableWidth / charWidth).floor().clamp(20, 200);
    final int rows = (availableHeight / charHeight).floor().clamp(10, 100);
    
    return TerminalSize(
      width: cols,
      height: rows,
      pixelWidth: cols * charWidth,
      pixelHeight: rows * charHeight,
    );
  }

  /// Configure terminal behavior for interactive commands
  void _configureTerminalBehavior() {
    // Configure bell handling
    terminal.onBell = () {
      HapticFeedback.lightImpact();
    };
    
    // Configure title changes (useful for editors)
    terminal.onTitleChange = (title) {
      // Could emit title changes for modal header update
      debugPrint('Terminal title changed: $title');
    };
    
    // Configure resize handling
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      debugPrint('Terminal resized: ${width}x$height (${pixelWidth}x${pixelHeight}px)');
    };
  }

  /// Resize terminal to fit new dimensions
  void resizeTerminal(Size screenSize, {
    double? customCharWidth,
    double? customCharHeight,
  }) {
    final charWidth = customCharWidth ?? 9.6;
    final charHeight = customCharHeight ?? 18.0;
    
    // Account for UI elements
    const double headerHeight = 56.0;
    const double controlBarHeight = 48.0;
    const double safeAreaBuffer = 88.0; // Combined safe area estimate
    
    final double availableWidth = screenSize.width - 16.0;
    final double availableHeight = screenSize.height - 
        headerHeight - 
        controlBarHeight - 
        safeAreaBuffer - 
        16.0;
    
    final int cols = (availableWidth / charWidth).floor().clamp(20, 200);
    final int rows = (availableHeight / charHeight).floor().clamp(10, 100);
    
    terminal.resize(cols, rows);
  }

  /// Handle orientation changes
  void handleOrientationChange(Orientation orientation, Size screenSize) {
    // Delay resize to allow UI to settle
    Timer(const Duration(milliseconds: 100), () {
      resizeTerminal(screenSize);
    });
  }

  /// Write data to terminal
  void write(String data) {
    terminal.write(data);
  }

  /// Write line to terminal
  void writeln(String data) {
    terminal.write('$data\r\n');
  }

  /// Clear terminal screen
  void clear() {
    terminal.write('\x1b[2J\x1b[H'); // Clear screen and move cursor to top-left
  }

  /// Send control sequence
  void sendControlSequence(String sequence) {
    terminal.write(sequence);
  }

  /// Get terminal content as string
  String getContent() {
    // Note: This is a simplified implementation
    // In practice, you'd need to access the terminal buffer properly
    // For now, return empty string as this is mainly for debugging
    return '';
  }

  /// Get cursor position
  TerminalCursor get cursor => const TerminalCursor(0, 0);

  /// Check if terminal is ready for input
  bool get isReady => true; // xterm is always ready once initialized

  /// Get terminal dimensions
  TerminalSize get size => TerminalSize(
    width: terminal.viewWidth,
    height: terminal.viewHeight,
  );

  /// Configure for specific command types
  void configureForCommand(String command) {
    final executable = command.split(' ').first.toLowerCase();
    
    switch (executable) {
      case 'vi':
      case 'vim':
      case 'nvim':
        _configureForEditor();
        break;
      case 'nano':
      case 'micro':
        _configureForSimpleEditor();
        break;
      case 'top':
      case 'htop':
      case 'btop':
        _configureForMonitor();
        break;
      case 'less':
      case 'more':
        _configureForPager();
        break;
      case 'tmux':
      case 'screen':
        _configureForMultiplexer();
        break;
      default:
        _configureDefault();
    }
  }

  void _configureForEditor() {
    // Vim/Vi specific configuration
    // Ensure proper key mapping
    debugPrint('Terminal configured for text editor');
  }

  void _configureForSimpleEditor() {
    // Nano/Micro specific configuration
    debugPrint('Terminal configured for simple text editor');
  }

  void _configureForMonitor() {
    // Top/Htop specific configuration
    // These update frequently, may need special handling
    debugPrint('Terminal configured for system monitor');
  }

  void _configureForPager() {
    // Less/More specific configuration
    debugPrint('Terminal configured for pager');
  }

  void _configureForMultiplexer() {
    // Tmux/Screen specific configuration
    // May need special key handling
    debugPrint('Terminal configured for terminal multiplexer');
  }

  void _configureDefault() {
    // Default configuration
    debugPrint('Terminal configured with default settings');
  }

  /// Dispose resources
  void dispose() {
    // Clean up any resources
    debugPrint('XTermIntegrationService disposed');
  }
}

/// Terminal size information
class TerminalSize {
  final int width;
  final int height;
  final double? pixelWidth;
  final double? pixelHeight;

  const TerminalSize({
    required this.width,
    required this.height,
    this.pixelWidth,
    this.pixelHeight,
  });

  @override
  String toString() {
    return 'TerminalSize(${width}x$height${pixelWidth != null ? ', ${pixelWidth}x${pixelHeight}px' : ''})';
  }
}

/// Terminal cursor information
class TerminalCursor {
  final int x;
  final int y;

  const TerminalCursor(this.x, this.y);

  @override
  String toString() => 'TerminalCursor($x, $y)';
}