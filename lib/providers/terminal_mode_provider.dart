import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';


/// Terminal mode settings
@immutable
class TerminalModeSettings {
  final bool isAiMode;
  final bool autoScrollEnabled;
  final bool showTimestamps;
  final bool enableKeyboardShortcuts;
  final TerminalDisplayMode displayMode;

  const TerminalModeSettings({
    this.isAiMode = false,
    this.autoScrollEnabled = true,
    this.showTimestamps = true,
    this.enableKeyboardShortcuts = true,
    this.displayMode = TerminalDisplayMode.blocks,
  });

  TerminalModeSettings copyWith({
    bool? isAiMode,
    bool? autoScrollEnabled,
    bool? showTimestamps,
    bool? enableKeyboardShortcuts,
    TerminalDisplayMode? displayMode,
  }) {
    return TerminalModeSettings(
      isAiMode: isAiMode ?? this.isAiMode,
      autoScrollEnabled: autoScrollEnabled ?? this.autoScrollEnabled,
      showTimestamps: showTimestamps ?? this.showTimestamps,
      enableKeyboardShortcuts: enableKeyboardShortcuts ?? this.enableKeyboardShortcuts,
      displayMode: displayMode ?? this.displayMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isAiMode': isAiMode,
      'autoScrollEnabled': autoScrollEnabled,
      'showTimestamps': showTimestamps,
      'enableKeyboardShortcuts': enableKeyboardShortcuts,
      'displayMode': displayMode.name,
    };
  }

  factory TerminalModeSettings.fromJson(Map<String, dynamic> json) {
    return TerminalModeSettings(
      isAiMode: json['isAiMode'] ?? false,
      autoScrollEnabled: json['autoScrollEnabled'] ?? true,
      showTimestamps: json['showTimestamps'] ?? true,
      enableKeyboardShortcuts: json['enableKeyboardShortcuts'] ?? true,
      displayMode: TerminalDisplayMode.values.firstWhere(
        (mode) => mode.name == json['displayMode'],
        orElse: () => TerminalDisplayMode.blocks,
      ),
    );
  }
}

/// Terminal display modes
enum TerminalDisplayMode {
  blocks,
  traditional,
  hybrid,
}

/// Terminal mode state notifier
class TerminalModeNotifier extends StateNotifier<TerminalModeSettings> {
  TerminalModeNotifier() : super(const TerminalModeSettings()) {
    _loadSettings();
  }

  static const String _prefsKeyPrefix = 'terminal_mode_';
  static const String _prefsKeyGlobal = '${_prefsKeyPrefix}global';

  /// Load settings from persistent storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKeyGlobal);
      
      if (jsonString != null) {
        // Load individual settings from preferences
        final isAiMode = prefs.getBool('${_prefsKeyPrefix}isAiMode') ?? false;
        final autoScrollEnabled = prefs.getBool('${_prefsKeyPrefix}autoScrollEnabled') ?? true;
        final showTimestamps = prefs.getBool('${_prefsKeyPrefix}showTimestamps') ?? true;
        final enableKeyboardShortcuts = prefs.getBool('${_prefsKeyPrefix}enableKeyboardShortcuts') ?? true;
        final displayModeIndex = prefs.getInt('${_prefsKeyPrefix}displayMode') ?? 0;

        state = TerminalModeSettings(
          isAiMode: isAiMode,
          autoScrollEnabled: autoScrollEnabled,
          showTimestamps: showTimestamps,
          enableKeyboardShortcuts: enableKeyboardShortcuts,
          displayMode: TerminalDisplayMode.values[displayModeIndex],
        );
      }
    } catch (e) {
      debugPrint('Failed to load terminal mode settings: $e');
    }
  }

  /// Save settings to persistent storage
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save individual settings for easy access
      await prefs.setBool('${_prefsKeyPrefix}isAiMode', state.isAiMode);
      await prefs.setBool('${_prefsKeyPrefix}autoScrollEnabled', state.autoScrollEnabled);
      await prefs.setBool('${_prefsKeyPrefix}showTimestamps', state.showTimestamps);
      await prefs.setBool('${_prefsKeyPrefix}enableKeyboardShortcuts', state.enableKeyboardShortcuts);
      await prefs.setInt('${_prefsKeyPrefix}displayMode', state.displayMode.index);
      
    } catch (e) {
      debugPrint('Failed to save terminal mode settings: $e');
    }
  }

  /// Toggle AI mode
  Future<void> toggleAiMode() async {
    state = state.copyWith(isAiMode: !state.isAiMode);
    await _saveSettings();
  }

  /// Set AI mode explicitly
  Future<void> setAiMode(bool enabled) async {
    if (state.isAiMode != enabled) {
      state = state.copyWith(isAiMode: enabled);
      await _saveSettings();
    }
  }

  /// Toggle auto-scroll
  Future<void> toggleAutoScroll() async {
    state = state.copyWith(autoScrollEnabled: !state.autoScrollEnabled);
    await _saveSettings();
  }

  /// Set auto-scroll explicitly
  Future<void> setAutoScroll(bool enabled) async {
    if (state.autoScrollEnabled != enabled) {
      state = state.copyWith(autoScrollEnabled: enabled);
      await _saveSettings();
    }
  }

  /// Toggle timestamps
  Future<void> toggleTimestamps() async {
    state = state.copyWith(showTimestamps: !state.showTimestamps);
    await _saveSettings();
  }

  /// Set display mode
  Future<void> setDisplayMode(TerminalDisplayMode mode) async {
    if (state.displayMode != mode) {
      state = state.copyWith(displayMode: mode);
      await _saveSettings();
    }
  }


  /// Reset to defaults
  Future<void> resetToDefaults() async {
    state = const TerminalModeSettings();
    await _saveSettings();
  }

  /// Update multiple settings at once
  Future<void> updateSettings(TerminalModeSettings newSettings) async {
    state = newSettings;
    await _saveSettings();
  }
}

/// Session-specific terminal mode settings
class SessionTerminalModeNotifier extends StateNotifier<Map<String, TerminalModeSettings>> {
  SessionTerminalModeNotifier() : super({});

  /// Get settings for a specific session
  TerminalModeSettings getSessionSettings(String sessionId) {
    return state[sessionId] ?? const TerminalModeSettings();
  }

  /// Update settings for a specific session
  void updateSessionSettings(String sessionId, TerminalModeSettings settings) {
    state = {
      ...state,
      sessionId: settings,
    };
  }

  /// Toggle AI mode for a specific session
  void toggleSessionAiMode(String sessionId) {
    final current = getSessionSettings(sessionId);
    updateSessionSettings(sessionId, current.copyWith(isAiMode: !current.isAiMode));
  }

  /// Remove session settings
  void removeSession(String sessionId) {
    final newState = Map<String, TerminalModeSettings>.from(state);
    newState.remove(sessionId);
    state = newState;
  }

  /// Clear all session settings
  void clearAllSessions() {
    state = {};
  }
}

/// Global terminal mode provider
final terminalModeProvider = StateNotifierProvider<TerminalModeNotifier, TerminalModeSettings>(
  (ref) => TerminalModeNotifier(),
);

/// Session-specific terminal mode provider
final sessionTerminalModeProvider = StateNotifierProvider<SessionTerminalModeNotifier, Map<String, TerminalModeSettings>>(
  (ref) => SessionTerminalModeNotifier(),
);

/// AI mode state provider for easy access
final aiModeProvider = Provider<bool>((ref) {
  return ref.watch(terminalModeProvider).isAiMode;
});

/// Auto-scroll state provider
final autoScrollProvider = Provider<bool>((ref) {
  return ref.watch(terminalModeProvider).autoScrollEnabled;
});

/// Display mode provider
final displayModeProvider = Provider<TerminalDisplayMode>((ref) {
  return ref.watch(terminalModeProvider).displayMode;
});

/// Session AI mode provider
final sessionAiModeProvider = Provider.family<bool, String>((ref, sessionId) {
  final sessionSettings = ref.watch(sessionTerminalModeProvider);
  return sessionSettings[sessionId]?.isAiMode ?? 
         ref.watch(terminalModeProvider).isAiMode;
});

/// Combined terminal mode settings provider
final combinedTerminalModeProvider = Provider.family<TerminalModeSettings, String?>((ref, sessionId) {
  final globalSettings = ref.watch(terminalModeProvider);
  
  if (sessionId == null) {
    return globalSettings;
  }
  
  final sessionSettings = ref.watch(sessionTerminalModeProvider)[sessionId];
  if (sessionSettings == null) {
    return globalSettings;
  }
  
  // Merge session settings with global settings (session takes precedence)
  return globalSettings.copyWith(
    isAiMode: sessionSettings.isAiMode,
    autoScrollEnabled: sessionSettings.autoScrollEnabled,
    showTimestamps: sessionSettings.showTimestamps,
    enableKeyboardShortcuts: sessionSettings.enableKeyboardShortcuts,
    displayMode: sessionSettings.displayMode,
  );
});

/// Terminal mode utils
class TerminalModeUtils {
  /// Check if AI mode is globally enabled
  static bool isAiModeEnabled(WidgetRef ref) {
    return ref.read(aiModeProvider);
  }

  /// Check if AI mode is enabled for a specific session
  static bool isSessionAiModeEnabled(WidgetRef ref, String sessionId) {
    return ref.read(sessionAiModeProvider(sessionId));
  }

  /// Toggle AI mode globally
  static Future<void> toggleGlobalAiMode(WidgetRef ref) async {
    await ref.read(terminalModeProvider.notifier).toggleAiMode();
  }

  /// Toggle AI mode for a specific session
  static void toggleSessionAiMode(WidgetRef ref, String sessionId) {
    ref.read(sessionTerminalModeProvider.notifier).toggleSessionAiMode(sessionId);
  }

  /// Get effective settings for a session (merged global + session)
  static TerminalModeSettings getEffectiveSettings(WidgetRef ref, String? sessionId) {
    return ref.read(combinedTerminalModeProvider(sessionId));
  }
}