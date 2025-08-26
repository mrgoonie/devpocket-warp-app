import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/enhanced_terminal_models.dart';
import '../services/enhanced_terminal_session_manager.dart';
import '../widgets/terminal/terminal_block.dart';

/// Terminal session state notifier
class TerminalSessionStateNotifier extends StateNotifier<EnhancedTerminalSessionState> {
  TerminalSessionStateNotifier(String sessionId) 
      : super(EnhancedTerminalSessionState(
          sessionId: sessionId,
          lastActivity: DateTime.now(),
        ));

  /// Update AI mode for this session
  void setAiMode(bool enabled) {
    state = state.copyWith(
      isAiMode: enabled,
      lastActivity: DateTime.now(),
    );
  }

  /// Update scroll position
  void updateScrollPosition(ScrollPosition? position) {
    state = state.copyWith(
      scrollPosition: position,
      lastActivity: DateTime.now(),
    );
  }

  /// Add command to history
  void addCommandToHistory(String command) {
    final newHistory = List<String>.from(state.commandHistory);
    
    // Avoid duplicate consecutive commands
    if (newHistory.isEmpty || newHistory.last != command) {
      newHistory.add(command);
      
      // Limit history size
      if (newHistory.length > 1000) {
        newHistory.removeRange(0, newHistory.length - 1000);
      }
    }
    
    state = state.copyWith(
      commandHistory: newHistory,
      historyIndex: null, // Reset history navigation
      lastActivity: DateTime.now(),
    );
  }

  /// Navigate command history
  String? navigateHistory(bool up) {
    if (state.commandHistory.isEmpty) return null;
    
    int? newIndex;
    if (state.historyIndex == null) {
      newIndex = up ? state.commandHistory.length - 1 : 0;
    } else {
      if (up && state.historyIndex! > 0) {
        newIndex = state.historyIndex! - 1;
      } else if (!up && state.historyIndex! < state.commandHistory.length - 1) {
        newIndex = state.historyIndex! + 1;
      }
    }
    
    if (newIndex != null) {
      state = state.copyWith(
        historyIndex: newIndex,
        lastActivity: DateTime.now(),
      );
      return state.commandHistory[newIndex];
    }
    
    return null;
  }

  /// Reset history navigation
  void resetHistoryNavigation() {
    if (state.historyIndex != null) {
      state = state.copyWith(
        historyIndex: null,
        lastActivity: DateTime.now(),
      );
    }
  }

  /// Update preferences
  void updatePreferences(Map<String, dynamic> preferences) {
    final newPreferences = Map<String, dynamic>.from(state.preferences);
    newPreferences.addAll(preferences);
    
    state = state.copyWith(
      preferences: newPreferences,
      lastActivity: DateTime.now(),
    );
  }

  /// Set interactive session
  void setCurrentInteractiveSession(String? sessionId) {
    state = state.copyWith(
      currentInteractiveSession: sessionId,
      lastActivity: DateTime.now(),
    );
  }

  /// Update environment variables
  void updateEnvironmentVariables(Map<String, String> variables) {
    final newEnv = Map<String, String>.from(state.environmentVariables);
    newEnv.addAll(variables);
    
    state = state.copyWith(
      environmentVariables: newEnv,
      lastActivity: DateTime.now(),
    );
  }

  /// Update working directory
  void updateWorkingDirectory(String directory) {
    state = state.copyWith(
      workingDirectory: directory,
      lastActivity: DateTime.now(),
    );
  }

  /// Update active sessions list
  void updateActiveSessions(List<String> sessions) {
    state = state.copyWith(
      activeSessions: sessions,
      lastActivity: DateTime.now(),
    );
  }

  /// Get preference value
  T? getPreference<T>(String key, [T? defaultValue]) {
    return state.preferences[key] as T? ?? defaultValue;
  }

  /// Set preference value
  void setPreference<T>(String key, T value) {
    updatePreferences({key: value});
  }
}

/// Terminal session blocks notifier
class TerminalSessionBlocksNotifier extends StateNotifier<List<EnhancedTerminalBlockData>> {
  TerminalSessionBlocksNotifier() : super([]);

  /// Add new block
  void addBlock(EnhancedTerminalBlockData block) {
    state = [...state, block];
  }

  /// Update existing block
  void updateBlock(String blockId, EnhancedTerminalBlockData updatedBlock) {
    state = state.map((block) {
      return block.id == blockId ? updatedBlock : block;
    }).toList();
  }

  /// Remove block
  void removeBlock(String blockId) {
    state = state.where((block) => block.id != blockId).toList();
  }

  /// Update block status
  void updateBlockStatus(String blockId, TerminalBlockStatus status) {
    final blockIndex = state.indexWhere((block) => block.id == blockId);
    if (blockIndex >= 0) {
      final updatedBlock = state[blockIndex].copyWith(status: status);
      final newState = List<EnhancedTerminalBlockData>.from(state);
      newState[blockIndex] = updatedBlock;
      state = newState;
    }
  }

  /// Update block output
  void updateBlockOutput(String blockId, String output, {bool append = true}) {
    final blockIndex = state.indexWhere((block) => block.id == blockId);
    if (blockIndex >= 0) {
      final currentOutput = state[blockIndex].output;
      final newOutput = append ? currentOutput + output : output;
      final updatedBlock = state[blockIndex].copyWith(output: newOutput);
      final newState = List<EnhancedTerminalBlockData>.from(state);
      newState[blockIndex] = updatedBlock;
      state = newState;
    }
  }

  /// Clear all blocks
  void clearBlocks() {
    state = [];
  }

  /// Get running blocks
  List<EnhancedTerminalBlockData> getRunningBlocks() {
    return state.where((block) => block.status == TerminalBlockStatus.running).toList();
  }

  /// Get block by ID
  EnhancedTerminalBlockData? getBlock(String blockId) {
    try {
      return state.firstWhere((block) => block.id == blockId);
    } catch (e) {
      return null;
    }
  }
}

/// Interactive session state notifier
class InteractiveSessionStateNotifier extends StateNotifier<InteractiveCommandSession?> {
  InteractiveSessionStateNotifier() : super(null);

  /// Start interactive session
  void startSession(InteractiveCommandSession session) {
    state = session;
  }

  /// Update session
  void updateSession(InteractiveCommandSession session) {
    state = session;
  }

  /// Update session status
  void updateStatus(InteractiveSessionStatus status, {String? exitReason}) {
    if (state != null) {
      state = state!.copyWith(
        status: status,
        exitReason: exitReason,
        endTime: status.isFinished ? DateTime.now() : null,
      );
    }
  }

  /// Update session state
  void updateSessionState(Map<String, dynamic> stateData) {
    if (state != null) {
      state = state!.copyWith(state: stateData);
    }
  }

  /// End session
  void endSession() {
    if (state != null) {
      state = state!.copyWith(
        status: InteractiveSessionStatus.completed,
        endTime: DateTime.now(),
      );
    }
    // Clear state after a brief delay to allow UI to react
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        state = null;
      }
    });
  }

  /// Cancel session
  void cancelSession() {
    if (state != null) {
      state = state!.copyWith(
        status: InteractiveSessionStatus.cancelled,
        endTime: DateTime.now(),
        exitReason: 'User cancelled',
      );
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        state = null;
      }
    });
  }
}

/// Session statistics notifier
class SessionStatisticsNotifier extends StateNotifier<Map<String, dynamic>> {
  SessionStatisticsNotifier() : super({});

  /// Update statistics
  void updateStatistics(Map<String, dynamic> stats) {
    state = {
      ...state,
      ...stats,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Increment counter
  void incrementCounter(String key) {
    final currentValue = state[key] as int? ?? 0;
    state = {
      ...state,
      key: currentValue + 1,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Set value
  void setValue(String key, dynamic value) {
    state = {
      ...state,
      key: value,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
}

/// Terminal session state provider
final terminalSessionStateProvider = StateNotifierProvider.family<
    TerminalSessionStateNotifier, EnhancedTerminalSessionState, String>(
  (ref, sessionId) => TerminalSessionStateNotifier(sessionId),
);

/// Terminal session blocks provider
final terminalSessionBlocksProvider = StateNotifierProvider.family<
    TerminalSessionBlocksNotifier, List<EnhancedTerminalBlockData>, String>(
  (ref, sessionId) => TerminalSessionBlocksNotifier(),
);

/// Interactive session provider
final interactiveSessionProvider = StateNotifierProvider.family<
    InteractiveSessionStateNotifier, InteractiveCommandSession?, String>(
  (ref, sessionId) => InteractiveSessionStateNotifier(),
);

/// Session statistics provider
final sessionStatisticsProvider = StateNotifierProvider.family<
    SessionStatisticsNotifier, Map<String, dynamic>, String>(
  (ref, sessionId) => SessionStatisticsNotifier(),
);

/// Active sessions provider
final activeSessionsProvider = StateProvider<List<String>>((ref) => []);

/// Current session provider
final currentSessionProvider = StateProvider<String?>((ref) => null);

/// Session AI mode provider
final sessionAiModeProvider = Provider.family<bool, String>((ref, sessionId) {
  final sessionState = ref.watch(terminalSessionStateProvider(sessionId));
  return sessionState.isAiMode;
});

/// Session blocks count provider
final sessionBlocksCountProvider = Provider.family<int, String>((ref, sessionId) {
  final blocks = ref.watch(terminalSessionBlocksProvider(sessionId));
  return blocks.length;
});

/// Session running blocks count provider
final sessionRunningBlocksCountProvider = Provider.family<int, String>((ref, sessionId) {
  final blocks = ref.watch(terminalSessionBlocksProvider(sessionId));
  return blocks.where((block) => block.status == TerminalBlockStatus.running).length;
});

/// Session has interactive command provider
final sessionHasInteractiveProvider = Provider.family<bool, String>((ref, sessionId) {
  final interactiveSession = ref.watch(interactiveSessionProvider(sessionId));
  return interactiveSession != null && interactiveSession.isActive;
});

/// Session command history provider
final sessionCommandHistoryProvider = Provider.family<List<String>, String>((ref, sessionId) {
  final sessionState = ref.watch(terminalSessionStateProvider(sessionId));
  return sessionState.commandHistory;
});

/// Session working directory provider
final sessionWorkingDirectoryProvider = Provider.family<String, String>((ref, sessionId) {
  final sessionState = ref.watch(terminalSessionStateProvider(sessionId));
  return sessionState.workingDirectory;
});

/// Combined session info provider
final sessionInfoProvider = Provider.family<Map<String, dynamic>, String>((ref, sessionId) {
  final sessionState = ref.watch(terminalSessionStateProvider(sessionId));
  final blocks = ref.watch(terminalSessionBlocksProvider(sessionId));
  final interactiveSession = ref.watch(interactiveSessionProvider(sessionId));
  final statistics = ref.watch(sessionStatisticsProvider(sessionId));

  return {
    'sessionId': sessionId,
    'isAiMode': sessionState.isAiMode,
    'blocksCount': blocks.length,
    'runningBlocksCount': blocks.where((b) => b.status == TerminalBlockStatus.running).length,
    'completedBlocksCount': blocks.where((b) => b.status == TerminalBlockStatus.completed).length,
    'failedBlocksCount': blocks.where((b) => b.status == TerminalBlockStatus.failed).length,
    'hasInteractiveSession': interactiveSession != null,
    'interactiveSessionActive': interactiveSession?.isActive ?? false,
    'commandHistorySize': sessionState.commandHistory.length,
    'workingDirectory': sessionState.workingDirectory,
    'lastActivity': sessionState.lastActivity.toIso8601String(),
    'statistics': statistics,
  };
});

/// Terminal session management utilities
class TerminalSessionUtils {
  /// Create new session
  static String createSession(WidgetRef ref) {
    final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    final activeSessions = ref.read(activeSessionsProvider);
    ref.read(activeSessionsProvider.notifier).state = [...activeSessions, sessionId];
    ref.read(currentSessionProvider.notifier).state = sessionId;
    return sessionId;
  }

  /// Switch to session
  static void switchToSession(WidgetRef ref, String sessionId) {
    ref.read(currentSessionProvider.notifier).state = sessionId;
  }

  /// Close session
  static void closeSession(WidgetRef ref, String sessionId) {
    final activeSessions = ref.read(activeSessionsProvider);
    final newActiveSessions = activeSessions.where((id) => id != sessionId).toList();
    ref.read(activeSessionsProvider.notifier).state = newActiveSessions;
    
    final currentSession = ref.read(currentSessionProvider);
    if (currentSession == sessionId) {
      ref.read(currentSessionProvider.notifier).state = 
          newActiveSessions.isNotEmpty ? newActiveSessions.last : null;
    }
  }

  /// Get session info
  static Map<String, dynamic> getSessionInfo(WidgetRef ref, String sessionId) {
    return ref.read(sessionInfoProvider(sessionId));
  }

  /// Execute command in session
  static Future<String> executeCommand(
    WidgetRef ref, 
    String sessionId, 
    String command,
  ) async {
    final sessionManager = EnhancedTerminalSessionManager.instance;
    final sessionStateNotifier = ref.read(terminalSessionStateProvider(sessionId).notifier);
    final currentState = ref.read(terminalSessionStateProvider(sessionId));
    
    // Add to command history
    sessionStateNotifier.addCommandToHistory(command);
    
    try {
      // Execute command through session manager
      final blockId = await sessionManager.executeCommand(
        sessionId, 
        command, 
        isAgentMode: currentState.isAiMode,
      );
      
      return blockId;
    } catch (e) {
      debugPrint('Error executing command: $e');
      rethrow;
    }
  }
}

extension InteractiveSessionStatusExtension on InteractiveSessionStatus {
  bool get isFinished => this == InteractiveSessionStatus.completed || 
                        this == InteractiveSessionStatus.cancelled ||
                        this == InteractiveSessionStatus.error;
}