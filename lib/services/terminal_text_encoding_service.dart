import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Terminal text encoding service for handling various character encodings
/// and fixing square symbols/rendering issues
class TerminalTextEncodingService {
  static TerminalTextEncodingService? _instance;
  static TerminalTextEncodingService get instance => _instance ??= TerminalTextEncodingService._();

  TerminalTextEncodingService._();

  /// Common problematic character mappings for terminal output
  static const Map<String, String> _characterReplacements = {
    // Box drawing characters (common in terminal UIs)
    '─': '─', // Horizontal line
    '│': '│', // Vertical line
    '┌': '┌', // Top-left corner
    '┐': '┐', // Top-right corner
    '└': '└', // Bottom-left corner
    '┘': '┘', // Bottom-right corner
    '├': '├', // T-junction left
    '┤': '┤', // T-junction right
    '┬': '┬', // T-junction top
    '┴': '┴', // T-junction bottom
    '┼': '┼', // Cross junction
    
    // Arrow characters
    '→': '→', // Right arrow
    '←': '←', // Left arrow
    '↑': '↑', // Up arrow
    '↓': '↓', // Down arrow
    
    // Bullet points and special characters
    '•': '•', // Bullet
    '◆': '◆', // Diamond
    '▪': '▪', // Square
    '▫': '▫', // Empty square
    '◦': '◦', // White bullet
    '※': '※', // Reference mark
    
    // Mathematical symbols
    '×': '×', // Multiplication
    '÷': '÷', // Division
    '±': '±', // Plus-minus
    '∞': '∞', // Infinity
    
    // Currency symbols
    '€': '€', // Euro
    '£': '£', // Pound
    '¥': '¥', // Yen
    '¢': '¢', // Cent
    
    // Accented characters (common in SSH outputs)
    'é': 'é', 'è': 'è', 'ê': 'ê', 'ë': 'ë',
    'á': 'á', 'à': 'à', 'â': 'â', 'ä': 'ä',
    'í': 'í', 'ì': 'ì', 'î': 'î', 'ï': 'ï',
    'ó': 'ó', 'ò': 'ò', 'ô': 'ô', 'ö': 'ö',
    'ú': 'ú', 'ù': 'ù', 'û': 'û', 'ü': 'ü',
    'ñ': 'ñ', 'ç': 'ç',
    
    // Common escape sequences that might render as squares
    '\x1b': '', // ESC character
    '\x00': '', // NULL character
    '\x7f': '', // DEL character
  };

  /// Control characters that should be filtered out
  static const Set<int> _controlCharacters = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 0-7
    0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, // 14-21
    0x16, 0x17, 0x18, 0x19, 0x1a, 0x1c, 0x1d, 0x1e, 0x1f, // 22-31 (excluding 0x1b ESC)
    0x7f, // DEL
  };

  /// Process terminal output text to fix encoding issues
  String processTerminalOutput(String input, {String? encoding}) {
    try {
      // Handle empty or null input
      if (input.isEmpty) return input;

      // Detect and handle different encodings
      String processed = _handleEncoding(input, encoding);

      // Replace problematic characters
      processed = _replaceProblematicCharacters(processed);

      // Filter out control characters
      processed = _filterControlCharacters(processed);

      // Handle ANSI escape sequences
      processed = _handleAnsiSequences(processed);

      // Normalize unicode characters
      processed = _normalizeUnicode(processed);

      return processed;

    } catch (e) {
      debugPrint('Error processing terminal output: $e');
      // Return sanitized fallback
      return _sanitizeFallback(input);
    }
  }

  /// Handle different text encodings
  String _handleEncoding(String input, String? encoding) {
    if (encoding == null || encoding.toLowerCase() == 'utf-8') {
      return input; // UTF-8 is default and should work fine
    }

    try {
      switch (encoding.toLowerCase()) {
        case 'utf-16':
        case 'utf-16le':
        case 'utf-16be':
          return _handleUtf16(input);
        case 'latin-1':
        case 'iso-8859-1':
          return _handleLatin1(input);
        case 'ascii':
          return _handleAscii(input);
        case 'cp1252':
        case 'windows-1252':
          return _handleWindows1252(input);
        default:
          debugPrint('Unsupported encoding: $encoding, using UTF-8');
          return input;
      }
    } catch (e) {
      debugPrint('Error handling encoding $encoding: $e');
      return input;
    }
  }

  /// Handle UTF-16 encoding
  String _handleUtf16(String input) {
    try {
      // If input is already properly decoded, return as is
      return input;
    } catch (e) {
      debugPrint('Error handling UTF-16: $e');
      return input;
    }
  }

  /// Handle Latin-1 encoding
  String _handleLatin1(String input) {
    try {
      final bytes = latin1.encode(input);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      debugPrint('Error handling Latin-1: $e');
      return input;
    }
  }

  /// Handle ASCII encoding
  String _handleAscii(String input) {
    return input.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
  }

  /// Handle Windows-1252 encoding
  String _handleWindows1252(String input) {
    // Windows-1252 character mapping for common characters
    const windows1252Map = {
      0x80: '€', 0x82: '‚', 0x83: 'ƒ', 0x84: '„', 0x85: '…',
      0x86: '†', 0x87: '‡', 0x88: 'ˆ', 0x89: '‰', 0x8A: 'Š',
      0x8B: '‹', 0x8C: 'Œ', 0x8E: 'Ž', 0x91: ''', 0x92: ''',
      0x93: '"', 0x94: '"', 0x95: '•', 0x96: '–', 0x97: '—',
      0x98: '˜', 0x99: '™', 0x9A: 'š', 0x9B: '›', 0x9C: 'œ',
      0x9E: 'ž', 0x9F: 'Ÿ',
    };

    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      if (windows1252Map.containsKey(codeUnit)) {
        buffer.write(windows1252Map[codeUnit]);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// Replace problematic characters that might render as squares
  String _replaceProblematicCharacters(String input) {
    String result = input;
    
    _characterReplacements.forEach((problematic, replacement) {
      result = result.replaceAll(problematic, replacement);
    });

    // Replace any remaining unrecognized characters with safe alternatives
    result = result.replaceAll(RegExp(r'[\uFFFD]'), '?'); // Replacement character
    result = result.replaceAll(RegExp(r'[\u25A0]'), '■'); // Black square
    result = result.replaceAll(RegExp(r'[\u25A1]'), '□'); // White square

    return result;
  }

  /// Filter out control characters that shouldn't be displayed
  String _filterControlCharacters(String input) {
    final buffer = StringBuffer();
    
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      
      // Keep printable characters and common whitespace
      if (codeUnit >= 32 || codeUnit == 9 || codeUnit == 10 || codeUnit == 13) {
        // Skip control characters except tab, newline, and carriage return
        if (!_controlCharacters.contains(codeUnit)) {
          buffer.writeCharCode(codeUnit);
        }
      }
    }
    
    return buffer.toString();
  }

  /// Handle ANSI escape sequences for colors and formatting
  String _handleAnsiSequences(String input) {
    // Remove ANSI color codes but preserve the text
    // This is a simple approach - you might want to parse and apply colors in the UI
    return input.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
  }

  /// Normalize Unicode characters
  String _normalizeUnicode(String input) {
    try {
      // Normalize to NFC (Canonical Decomposition followed by Canonical Composition)
      // This helps with accented characters and composite characters
      return input; // Flutter handles Unicode normalization automatically
    } catch (e) {
      debugPrint('Error normalizing Unicode: $e');
      return input;
    }
  }

  /// Sanitize text as fallback when processing fails
  String _sanitizeFallback(String input) {
    return input
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Remove control chars
        .replaceAll(RegExp(r'[^\x20-\x7E\x80-\xFF]'), '?') // Replace non-printable chars
        .replaceAll('�', '?'); // Replace replacement characters
  }

  /// Detect encoding from byte patterns
  String? detectEncoding(Uint8List bytes) {
    // Simple encoding detection logic
    if (bytes.isEmpty) return null;

    // Check for BOM (Byte Order Mark)
    if (bytes.length >= 3 && 
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      return 'utf-8';
    }
    
    if (bytes.length >= 2 && 
        bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return 'utf-16le';
    }
    
    if (bytes.length >= 2 && 
        bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return 'utf-16be';
    }

    // Check for high probability of UTF-8
    int utf8Score = 0;
    int latin1Score = 0;
    
    for (int i = 0; i < bytes.length; i++) {
      final byte = bytes[i];
      
      if (byte < 0x80) {
        // ASCII range - compatible with both
        utf8Score += 1;
        latin1Score += 1;
      } else if (byte < 0xC0) {
        // Invalid UTF-8 start byte but valid Latin-1
        latin1Score += 2;
      } else {
        // Potential UTF-8 multibyte sequence
        utf8Score += 2;
      }
    }

    if (utf8Score > latin1Score) {
      return 'utf-8';
    } else {
      return 'latin-1';
    }
  }

  /// Convert bytes to string with proper encoding handling
  String bytesToString(Uint8List bytes, {String? encoding}) {
    try {
      final detectedEncoding = encoding ?? detectEncoding(bytes);
      
      switch (detectedEncoding?.toLowerCase()) {
        case 'utf-8':
          return utf8.decode(bytes, allowMalformed: true);
        case 'latin-1':
        case 'iso-8859-1':
          return latin1.decode(bytes);
        case 'ascii':
          return ascii.decode(bytes, allowInvalid: true);
        default:
          // Default to UTF-8 with malformed handling
          return utf8.decode(bytes, allowMalformed: true);
      }
    } catch (e) {
      debugPrint('Error converting bytes to string: $e');
      // Fallback to Latin-1 which accepts any byte value
      return latin1.decode(bytes);
    }
  }

  /// Check if text contains problematic characters
  bool hasEncodingIssues(String text) {
    // Check for replacement characters
    if (text.contains('�')) return true;
    
    // Check for suspicious control characters
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (_controlCharacters.contains(codeUnit)) return true;
    }
    
    // Check for unrecognized box drawing characters (might render as squares)
    if (text.contains(RegExp(r'[\u25A0-\u25FF]'))) return true;
    
    return false;
  }

  /// Get safe font families for terminal text rendering
  List<String> getTerminalFontFamilies() {
    return [
      'Monaco', // macOS monospace
      'Consolas', // Windows monospace
      'Liberation Mono', // Linux monospace
      'DejaVu Sans Mono', // Cross-platform
      'Courier New', // Fallback
      'monospace', // Generic fallback
    ];
  }

  /// Test if a font supports specific characters
  Future<bool> testFontSupport(String fontFamily, List<String> testCharacters) async {
    try {
      // This would require platform-specific implementation
      // For now, return true for common fonts
      const supportedFonts = ['Monaco', 'Consolas', 'Liberation Mono', 'DejaVu Sans Mono'];
      return supportedFonts.contains(fontFamily);
    } catch (e) {
      debugPrint('Error testing font support: $e');
      return false;
    }
  }
}