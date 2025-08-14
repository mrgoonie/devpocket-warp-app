import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_models.dart';
import '../services/ai_service.dart';

// Storage keys
const _apiKeyStorageKey = 'openrouter_api_key';
const _selectedModelKey = 'selected_ai_model';
const _usageStatsKey = 'ai_usage_stats';
const _commandCacheKey = 'command_suggestions_cache';
// const _errorCacheKey = 'error_explanations_cache'; // Unused for now

// Providers

final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

final apiKeyProvider = StateNotifierProvider<ApiKeyNotifier, AsyncValue<String?>>((ref) {
  return ApiKeyNotifier(ref.read(aiServiceProvider));
});

final availableModelsProvider = FutureProvider<List<AIModel>>((ref) async {
  final aiService = ref.read(aiServiceProvider);
  return await aiService.getAvailableModels();
});

final selectedModelProvider = StateNotifierProvider<SelectedModelNotifier, String>((ref) {
  return SelectedModelNotifier();
});

final aiUsageProvider = StateNotifierProvider<AIUsageNotifier, AIUsageStats>((ref) {
  return AIUsageNotifier();
});

final commandCacheProvider = StateNotifierProvider<CommandCacheNotifier, Map<String, CachedCommandSuggestion>>((ref) {
  return CommandCacheNotifier();
});

final aiFeatureSettingsProvider = StateNotifierProvider<AIFeatureSettingsNotifier, AIFeatureSettings>((ref) {
  return AIFeatureSettingsNotifier();
});

// State Notifiers

class ApiKeyNotifier extends StateNotifier<AsyncValue<String?>> {
  static const _storage = FlutterSecureStorage();

  final AIService _aiService;

  ApiKeyNotifier(this._aiService) : super(const AsyncValue.loading()) {
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    try {
      state = const AsyncValue.loading();
      final apiKey = await _storage.read(key: _apiKeyStorageKey);
      
      if (apiKey != null) {
        await _aiService.initialize(
          apiKey: apiKey,
          appName: 'DevPocket',
          appUrl: 'https://devpocket.app',
        );
      }
      
      state = AsyncValue.data(apiKey);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<bool> setApiKey(String apiKey) async {
    try {
      state = const AsyncValue.loading();
      
      // Validate the key first
      final isValid = await _aiService.validateApiKey(apiKey);
      
      if (isValid) {
        await _storage.write(key: _apiKeyStorageKey, value: apiKey);
        await _aiService.initialize(
          apiKey: apiKey,
          appName: 'DevPocket',
          appUrl: 'https://devpocket.app',
        );
        state = AsyncValue.data(apiKey);
        return true;
      } else {
        state = AsyncValue.error(
          'Invalid API key. Please check your OpenRouter API key.',
          StackTrace.current,
        );
        return false;
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  Future<void> removeApiKey() async {
    try {
      await _storage.delete(key: _apiKeyStorageKey);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  bool get hasValidKey {
    return state.maybeWhen(
      data: (key) => key != null && key.isNotEmpty,
      orElse: () => false,
    );
  }
}

class SelectedModelNotifier extends StateNotifier<String> {
  static const _defaultModel = 'anthropic/claude-3.5-sonnet';

  SelectedModelNotifier() : super(_defaultModel) {
    _loadSelectedModel();
  }

  Future<void> _loadSelectedModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString(_selectedModelKey) ?? _defaultModel;
      state = savedModel;
    } catch (e) {
      state = _defaultModel;
    }
  }

  Future<void> setModel(String modelId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedModelKey, modelId);
      state = modelId;
    } catch (e) {
      // Silently fail - not critical
    }
  }
}

class AIUsageNotifier extends StateNotifier<AIUsageStats> {
  AIUsageNotifier() : super(AIUsageStats.empty()) {
    _loadUsageStats();
  }

  Future<void> _loadUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString(_usageStatsKey);
      
      if (statsJson != null) {
        final statsMap = json.decode(statsJson) as Map<String, dynamic>;
        state = AIUsageStats.fromJson(statsMap);
      }
    } catch (e) {
      state = AIUsageStats.empty();
    }
  }

  Future<void> recordUsage({
    required String model,
    required int tokenCount,
    required double estimatedCost,
  }) async {
    final newUsage = state.copyWith(
      requestCount: state.requestCount + 1,
      tokenCount: state.tokenCount + tokenCount,
      estimatedCost: state.estimatedCost + estimatedCost,
      modelUsage: {
        ...state.modelUsage,
        model: (state.modelUsage[model] ?? 0) + 1,
      },
    );

    state = newUsage;
    await _saveUsageStats();
  }

  Future<void> resetStats() async {
    state = AIUsageStats.empty();
    await _saveUsageStats();
  }

  Future<void> _saveUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usageStatsKey, json.encode(state.toJson()));
    } catch (e) {
      // Silently fail - not critical
    }
  }

  // Convenience getters
  double get dailySpend {
    final today = DateTime.now();
    final lastReset = state.lastReset;
    
    if (today.difference(lastReset).inDays > 0) {
      // Reset if it's been more than a day
      WidgetsBinding.instance.addPostFrameCallback((_) => resetStats());
      return 0.0;
    }
    
    return state.estimatedCost;
  }

  bool get isNearDailyLimit {
    return dailySpend > 5.0; // $5 daily warning threshold
  }
}

class CommandCacheNotifier extends StateNotifier<Map<String, CachedCommandSuggestion>> {
  static const Duration _defaultTTL = Duration(hours: 24);
  static const int _maxCacheSize = 100;

  CommandCacheNotifier() : super({}) {
    _loadCache();
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_commandCacheKey);
      
      if (cacheJson != null) {
        final cacheMap = json.decode(cacheJson) as Map<String, dynamic>;
        final cache = <String, CachedCommandSuggestion>{};
        
        for (final entry in cacheMap.entries) {
          try {
            final cached = CachedCommandSuggestion.fromJson(entry.value);
            if (!cached.isExpired) {
              cache[entry.key] = cached;
            }
          } catch (e) {
            // Skip invalid cache entries
            continue;
          }
        }
        
        state = cache;
      }
    } catch (e) {
      state = {};
    }
  }

  String _generateCacheKey(String query, CommandContext? context) {
    final buffer = StringBuffer(query.toLowerCase().trim());
    
    if (context != null) {
      buffer.write('|${context.operatingSystem}');
      buffer.write('|${context.currentDirectory}');
    }
    
    return buffer.toString();
  }

  CommandSuggestion? getCached(String query, CommandContext? context) {
    final key = _generateCacheKey(query, context);
    final cached = state[key];
    
    if (cached != null && !cached.isExpired) {
      return cached.suggestion;
    }
    
    return null;
  }

  Future<void> cache(
    String query,
    CommandSuggestion suggestion, {
    CommandContext? context,
    Duration? ttl,
  }) async {
    final key = _generateCacheKey(query, context);
    final cached = CachedCommandSuggestion(
      suggestion: suggestion,
      cachedAt: DateTime.now(),
      ttl: ttl ?? _defaultTTL,
    );

    final newCache = Map<String, CachedCommandSuggestion>.from(state);
    newCache[key] = cached;

    // Cleanup if cache is too large
    if (newCache.length > _maxCacheSize) {
      final entries = newCache.entries.toList()
        ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
      
      // Remove oldest entries
      final toRemove = entries.take(newCache.length - _maxCacheSize);
      for (final entry in toRemove) {
        newCache.remove(entry.key);
      }
    }

    state = newCache;
    await _saveCache();
  }

  Future<void> clearCache() async {
    state = {};
    await _saveCache();
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMap = <String, dynamic>{};
      
      for (final entry in state.entries) {
        cacheMap[entry.key] = entry.value.toJson();
      }
      
      await prefs.setString(_commandCacheKey, json.encode(cacheMap));
    } catch (e) {
      // Silently fail - not critical
    }
  }

  int get cacheSize => state.length;
  
  double get hitRate {
    // This would need more sophisticated tracking in a real implementation
    return 0.0;
  }
}

@immutable
class AIFeatureSettings {
  final bool agentModeEnabled;
  final bool autoErrorExplanation;
  final bool smartSuggestionsEnabled;
  final bool cachingEnabled;
  final bool costWarningsEnabled;
  final double dailySpendLimit;
  final int maxRequestsPerMinute;

  const AIFeatureSettings({
    this.agentModeEnabled = true,
    this.autoErrorExplanation = true,
    this.smartSuggestionsEnabled = true,
    this.cachingEnabled = true,
    this.costWarningsEnabled = true,
    this.dailySpendLimit = 10.0,
    this.maxRequestsPerMinute = 20,
  });

  AIFeatureSettings copyWith({
    bool? agentModeEnabled,
    bool? autoErrorExplanation,
    bool? smartSuggestionsEnabled,
    bool? cachingEnabled,
    bool? costWarningsEnabled,
    double? dailySpendLimit,
    int? maxRequestsPerMinute,
  }) {
    return AIFeatureSettings(
      agentModeEnabled: agentModeEnabled ?? this.agentModeEnabled,
      autoErrorExplanation: autoErrorExplanation ?? this.autoErrorExplanation,
      smartSuggestionsEnabled: smartSuggestionsEnabled ?? this.smartSuggestionsEnabled,
      cachingEnabled: cachingEnabled ?? this.cachingEnabled,
      costWarningsEnabled: costWarningsEnabled ?? this.costWarningsEnabled,
      dailySpendLimit: dailySpendLimit ?? this.dailySpendLimit,
      maxRequestsPerMinute: maxRequestsPerMinute ?? this.maxRequestsPerMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agentModeEnabled': agentModeEnabled,
      'autoErrorExplanation': autoErrorExplanation,
      'smartSuggestionsEnabled': smartSuggestionsEnabled,
      'cachingEnabled': cachingEnabled,
      'costWarningsEnabled': costWarningsEnabled,
      'dailySpendLimit': dailySpendLimit,
      'maxRequestsPerMinute': maxRequestsPerMinute,
    };
  }

  factory AIFeatureSettings.fromJson(Map<String, dynamic> json) {
    return AIFeatureSettings(
      agentModeEnabled: json['agentModeEnabled'] as bool? ?? true,
      autoErrorExplanation: json['autoErrorExplanation'] as bool? ?? true,
      smartSuggestionsEnabled: json['smartSuggestionsEnabled'] as bool? ?? true,
      cachingEnabled: json['cachingEnabled'] as bool? ?? true,
      costWarningsEnabled: json['costWarningsEnabled'] as bool? ?? true,
      dailySpendLimit: (json['dailySpendLimit'] as num?)?.toDouble() ?? 10.0,
      maxRequestsPerMinute: json['maxRequestsPerMinute'] as int? ?? 20,
    );
  }
}

class AIFeatureSettingsNotifier extends StateNotifier<AIFeatureSettings> {
  static const _settingsKey = 'ai_feature_settings';

  AIFeatureSettingsNotifier() : super(const AIFeatureSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);
      
      if (settingsJson != null) {
        final settingsMap = json.decode(settingsJson) as Map<String, dynamic>;
        state = AIFeatureSettings.fromJson(settingsMap);
      }
    } catch (e) {
      state = const AIFeatureSettings();
    }
  }

  Future<void> updateSettings(AIFeatureSettings settings) async {
    state = settings;
    await _saveSettings();
  }

  Future<void> toggleAgentMode() async {
    state = state.copyWith(agentModeEnabled: !state.agentModeEnabled);
    await _saveSettings();
  }

  Future<void> toggleAutoErrorExplanation() async {
    state = state.copyWith(autoErrorExplanation: !state.autoErrorExplanation);
    await _saveSettings();
  }

  Future<void> toggleSmartSuggestions() async {
    state = state.copyWith(smartSuggestionsEnabled: !state.smartSuggestionsEnabled);
    await _saveSettings();
  }

  Future<void> toggleCaching() async {
    state = state.copyWith(cachingEnabled: !state.cachingEnabled);
    await _saveSettings();
  }

  Future<void> setDailySpendLimit(double limit) async {
    state = state.copyWith(dailySpendLimit: limit);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, json.encode(state.toJson()));
    } catch (e) {
      // Silently fail - not critical
    }
  }
}

// Helper providers for computed values
final hasValidApiKeyProvider = Provider<bool>((ref) {
  return ref.watch(apiKeyProvider.notifier).hasValidKey;
});

final aiEnabledProvider = Provider<bool>((ref) {
  final hasKey = ref.watch(hasValidApiKeyProvider);
  final settings = ref.watch(aiFeatureSettingsProvider);
  return hasKey && settings.agentModeEnabled;
});

final currentCostProvider = Provider<double>((ref) {
  final usage = ref.watch(aiUsageProvider);
  return usage.estimatedCost;
});

final isNearCostLimitProvider = Provider<bool>((ref) {
  final cost = ref.watch(currentCostProvider);
  final settings = ref.watch(aiFeatureSettingsProvider);
  return cost >= (settings.dailySpendLimit * 0.8); // 80% threshold
});

final cacheStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final cache = ref.watch(commandCacheProvider);
  final cacheNotifier = ref.read(commandCacheProvider.notifier);
  
  return {
    'size': cacheNotifier.cacheSize,
    'hitRate': cacheNotifier.hitRate,
    'entries': cache.length,
  };
});