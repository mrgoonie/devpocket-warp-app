import 'package:flutter/material.dart';

/// ANSI text processor that converts ANSI escape sequences to Flutter TextSpan objects
class AnsiTextProcessor {
  static AnsiTextProcessor? _instance;
  static AnsiTextProcessor get instance => _instance ??= AnsiTextProcessor._();

  AnsiTextProcessor._();

  /// ANSI color codes mapping
  static const Map<int, Color> _ansiColors = {
    // Standard colors (30-37 foreground, 40-47 background)
    30: Color(0xFF000000), // Black
    31: Color(0xFFCD3131), // Red
    32: Color(0xFF0DBC79), // Green
    33: Color(0xFFE5E510), // Yellow
    34: Color(0xFF2472C8), // Blue
    35: Color(0xFFBC3FBC), // Magenta
    36: Color(0xFF11A8CD), // Cyan
    37: Color(0xFFE5E5E5), // White

    // Bright colors (90-97 foreground, 100-107 background)
    90: Color(0xFF666666), // Bright Black (Gray)
    91: Color(0xFFF14C4C), // Bright Red
    92: Color(0xFF23D18B), // Bright Green
    93: Color(0xFFF5F543), // Bright Yellow
    94: Color(0xFF3B8EEA), // Bright Blue
    95: Color(0xFFD670D6), // Bright Magenta
    96: Color(0xFF29B8DB), // Bright Cyan
    97: Color(0xFFFFFFFF), // Bright White
  };

  /// Convert ANSI escape sequence text to a TextSpan with proper styling
  TextSpan processAnsiText(String text, {TextStyle? defaultStyle}) {
    if (text.isEmpty) return TextSpan(text: text, style: defaultStyle);

    final List<TextSpan> spans = [];
    final RegExp ansiRegex = RegExp(r'\x1b\[([0-9;]*)m');
    int lastEnd = 0;
    
    TextStyle currentStyle = defaultStyle ?? const TextStyle();

    final matches = ansiRegex.allMatches(text);
    
    for (final match in matches) {
      // Add text before this ANSI code
      if (match.start > lastEnd) {
        final textBefore = text.substring(lastEnd, match.start);
        if (textBefore.isNotEmpty) {
          spans.add(TextSpan(text: textBefore, style: currentStyle));
        }
      }

      // Process the ANSI codes
      final codes = match.group(1);
      if (codes != null && codes.isNotEmpty) {
        currentStyle = _applyAnsiCodes(codes, currentStyle, defaultStyle);
      } else {
        // Reset to default style
        currentStyle = defaultStyle ?? const TextStyle();
      }

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      final remainingText = text.substring(lastEnd);
      if (remainingText.isNotEmpty) {
        spans.add(TextSpan(text: remainingText, style: currentStyle));
      }
    }

    // If no ANSI codes were found, return the original text
    if (spans.isEmpty) {
      return TextSpan(text: text, style: defaultStyle);
    }

    return TextSpan(children: spans);
  }

  /// Apply ANSI codes to the current text style
  TextStyle _applyAnsiCodes(String codes, TextStyle currentStyle, TextStyle? defaultStyle) {
    final List<int> codeList = codes.split(';')
        .where((s) => s.isNotEmpty)
        .map((s) => int.tryParse(s) ?? 0)
        .toList();

    if (codeList.isEmpty) codeList.add(0); // Default to reset if empty

    TextStyle newStyle = currentStyle;

    for (int code in codeList) {
      switch (code) {
        case 0: // Reset all attributes
          newStyle = defaultStyle ?? const TextStyle();
          break;
        case 1: // Bold
          newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
          break;
        case 2: // Dim
          newStyle = newStyle.copyWith(fontWeight: FontWeight.w300);
          break;
        case 3: // Italic
          newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
          break;
        case 4: // Underline
          newStyle = newStyle.copyWith(decoration: TextDecoration.underline);
          break;
        case 7: // Reverse (swap foreground and background)
          final fg = newStyle.color;
          final bg = newStyle.backgroundColor;
          newStyle = newStyle.copyWith(
            color: bg ?? Colors.black,
            backgroundColor: fg ?? Colors.white,
          );
          break;
        case 9: // Strikethrough
          newStyle = newStyle.copyWith(decoration: TextDecoration.lineThrough);
          break;
        case 22: // Normal intensity (not bold, not dim)
          newStyle = newStyle.copyWith(fontWeight: FontWeight.normal);
          break;
        case 23: // Not italic
          newStyle = newStyle.copyWith(fontStyle: FontStyle.normal);
          break;
        case 24: // Not underlined
          newStyle = newStyle.copyWith(decoration: TextDecoration.none);
          break;
        case 27: // Not reversed
          // This would require more complex state tracking
          break;
        case 29: // Not strikethrough
          newStyle = newStyle.copyWith(decoration: TextDecoration.none);
          break;
        default:
          if (code >= 30 && code <= 37) {
            // Foreground colors
            newStyle = newStyle.copyWith(color: _ansiColors[code]);
          } else if (code >= 40 && code <= 47) {
            // Background colors
            newStyle = newStyle.copyWith(backgroundColor: _ansiColors[code - 10]);
          } else if (code >= 90 && code <= 97) {
            // Bright foreground colors
            newStyle = newStyle.copyWith(color: _ansiColors[code]);
          } else if (code >= 100 && code <= 107) {
            // Bright background colors
            newStyle = newStyle.copyWith(backgroundColor: _ansiColors[code - 10]);
          } else if (code == 39) {
            // Default foreground color
            newStyle = newStyle.copyWith(color: defaultStyle?.color);
          } else if (code == 49) {
            // Default background color
            newStyle = newStyle.copyWith(backgroundColor: defaultStyle?.backgroundColor);
          }
          break;
      }
    }

    return newStyle;
  }

  /// Remove ANSI escape sequences from text (fallback method)
  String stripAnsiCodes(String text) {
    return text.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
  }

  /// Check if text contains ANSI escape sequences
  bool hasAnsiCodes(String text) {
    return text.contains(RegExp(r'\x1b\[[0-9;]*m'));
  }

  /// Process text for terminal output with proper color handling
  Widget createTerminalText(String text, {TextStyle? defaultStyle}) {
    if (!hasAnsiCodes(text)) {
      return Text(text, style: defaultStyle);
    }

    return RichText(
      text: processAnsiText(text, defaultStyle: defaultStyle),
      textScaler: TextScaler.noScaling,
    );
  }

  /// Create selectable terminal text with ANSI processing
  Widget createSelectableTerminalText(String text, {TextStyle? defaultStyle}) {
    if (!hasAnsiCodes(text)) {
      return SelectableText(text, style: defaultStyle);
    }

    return SelectableText.rich(
      processAnsiText(text, defaultStyle: defaultStyle),
    );
  }
}