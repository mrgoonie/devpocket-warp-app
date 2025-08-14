import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  static const String _key = 'theme_mode';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_key) ?? ThemeMode.system.index;
      state = ThemeMode.values[themeIndex];
    } catch (e) {
      // If there's an error loading preferences, default to system theme
      state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    try {
      state = themeMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key, themeMode.index);
    } catch (e) {
      // Handle error but don't change state if save fails
      debugPrint('Failed to save theme preference: $e');
    }
  }

  bool get isDarkMode {
    if (state == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == 
          Brightness.dark;
    }
    return state == ThemeMode.dark;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

// Terminal theme provider
enum TerminalTheme {
  github('GitHub Dark', Color(0xFF0D1117)),
  dracula('Dracula', Color(0xFF282A36)),
  monokai('Monokai', Color(0xFF2D2A2E)),
  solarized('Solarized Dark', Color(0xFF002B36)),
  vscode('VS Code Dark', Color(0xFF1E1E1E));

  const TerminalTheme(this.name, this.backgroundColor);
  final String name;
  final Color backgroundColor;
}

class TerminalThemeNotifier extends StateNotifier<TerminalTheme> {
  TerminalThemeNotifier() : super(TerminalTheme.github) {
    _loadTerminalTheme();
  }

  static const String _key = 'terminal_theme';

  Future<void> _loadTerminalTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeName = prefs.getString(_key) ?? TerminalTheme.github.name;
      final theme = TerminalTheme.values.firstWhere(
        (t) => t.name == themeName,
        orElse: () => TerminalTheme.github,
      );
      state = theme;
    } catch (e) {
      state = TerminalTheme.github;
    }
  }

  Future<void> setTerminalTheme(TerminalTheme theme) async {
    try {
      state = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, theme.name);
    } catch (e) {
      debugPrint('Failed to save terminal theme preference: $e');
    }
  }
}

final terminalThemeProvider = StateNotifierProvider<TerminalThemeNotifier, TerminalTheme>((ref) {
  return TerminalThemeNotifier();
});

// Font preferences
class FontPreferencesNotifier extends StateNotifier<Map<String, dynamic>> {
  FontPreferencesNotifier() : super({
    'fontSize': 14.0,
    'fontFamily': 'JetBrainsMono',
  }) {
    _loadFontPreferences();
  }

  static const String _fontSizeKey = 'font_size';
  static const String _fontFamilyKey = 'font_family';

  Future<void> _loadFontPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontSize = prefs.getDouble(_fontSizeKey) ?? 14.0;
      final fontFamily = prefs.getString(_fontFamilyKey) ?? 'JetBrainsMono';
      
      state = {
        'fontSize': fontSize,
        'fontFamily': fontFamily,
      };
    } catch (e) {
      state = {
        'fontSize': 14.0,
        'fontFamily': 'JetBrainsMono',
      };
    }
  }

  Future<void> setFontSize(double fontSize) async {
    try {
      state = {...state, 'fontSize': fontSize};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, fontSize);
    } catch (e) {
      debugPrint('Failed to save font size preference: $e');
    }
  }

  Future<void> setFontFamily(String fontFamily) async {
    try {
      state = {...state, 'fontFamily': fontFamily};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fontFamilyKey, fontFamily);
    } catch (e) {
      debugPrint('Failed to save font family preference: $e');
    }
  }
}

final fontPreferencesProvider = StateNotifierProvider<FontPreferencesNotifier, Map<String, dynamic>>((ref) {
  return FontPreferencesNotifier();
});

// Individual font providers for easier access
final fontSizeProvider = Provider<double>((ref) {
  final fontPrefs = ref.watch(fontPreferencesProvider);
  return fontPrefs['fontSize'] as double;
});

final fontFamilyProvider = Provider<String>((ref) {
  final fontPrefs = ref.watch(fontPreferencesProvider);
  return fontPrefs['fontFamily'] as String;
});

// Biometric authentication preference
class BiometricPreferencesNotifier extends StateNotifier<bool> {
  BiometricPreferencesNotifier() : super(false) {
    _loadBiometricPreference();
  }

  static const String _key = 'biometric_enabled';

  Future<void> _loadBiometricPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (e) {
      state = false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    try {
      state = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled);
    } catch (e) {
      debugPrint('Failed to save biometric preference: $e');
    }
  }
}

final biometricEnabledProvider = StateNotifierProvider<BiometricPreferencesNotifier, bool>((ref) {
  return BiometricPreferencesNotifier();
});