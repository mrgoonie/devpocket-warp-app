import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user_models.dart';
import 'user_service.dart';

/// Preferences synchronization service
class PreferencesSyncService {
  static PreferencesSyncService? _instance;
  static PreferencesSyncService get instance => _instance ??= PreferencesSyncService._();
  
  final UserService _userService = UserService.instance;
  final Connectivity _connectivity = Connectivity();
  
  Timer? _syncTimer;
  bool _syncInProgress = false;
  
  static const String _lastSyncKey = 'preferences_last_sync';
  static const String _pendingChangesKey = 'preferences_pending_changes';
  static const String _syncEnabledKey = 'preferences_sync_enabled';
  
  PreferencesSyncService._();
  
  /// Initialize sync service
  Future<void> initialize() async {
    await _loadSyncSettings();
    _startPeriodicSync();
    
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }
  
  /// Start periodic sync
  void _startPeriodicSync() {
    _stopPeriodicSync();
    
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (!_syncInProgress) {
        syncPreferences();
      }
    });
  }
  
  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
  
  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet);
    
    if (hasConnection && !_syncInProgress) {
      // Sync when connectivity is restored
      Future.delayed(const Duration(seconds: 2), () {
        syncPreferences();
      });
    }
  }
  
  /// Check if sync is enabled
  Future<bool> isSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_syncEnabledKey) ?? true;
  }
  
  /// Enable/disable sync
  Future<void> setSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncEnabledKey, enabled);
    
    if (enabled) {
      _startPeriodicSync();
      await syncPreferences();
    } else {
      _stopPeriodicSync();
    }
  }
  
  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_lastSyncKey);
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }
  
  /// Set last sync time
  Future<void> _setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, time.toIso8601String());
  }
  
  /// Check if preferences need sync
  Future<bool> needsSync() async {
    final lastSync = await getLastSyncTime();
    if (lastSync == null) return true;
    
    final now = DateTime.now();
    const syncInterval = Duration(minutes: 30);
    
    return now.difference(lastSync) > syncInterval;
  }
  
  /// Sync preferences with server
  Future<SyncResult> syncPreferences({bool forceSync = false}) async {
    if (_syncInProgress) {
      return SyncResult(
        success: false,
        message: 'Sync already in progress',
      );
    }
    
    if (!forceSync && !await isSyncEnabled()) {
      return SyncResult(
        success: false,
        message: 'Sync is disabled',
      );
    }
    
    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResults.any((result) => 
      result == ConnectivityResult.mobile || 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.ethernet);
    
    if (!hasConnection) {
      return SyncResult(
        success: false,
        message: 'No internet connection',
      );
    }
    
    _syncInProgress = true;
    
    try {
      // Get current preferences
      final currentPrefs = await _getCurrentPreferences();
      
      // Get server preferences
      final serverResponse = await _userService.getUserPreferences();
      
      if (!serverResponse.isSuccess) {
        return SyncResult(
          success: false,
          message: 'Failed to fetch server preferences: ${serverResponse.message}',
        );
      }
      
      final serverPrefs = serverResponse.data!;
      final lastSync = await getLastSyncTime();
      
      // Determine sync action
      UserPreferences? mergedPrefs;
      
      if (lastSync == null) {
        // First sync - merge preferences
        mergedPrefs = _mergePreferences(currentPrefs, serverPrefs);
      } else {
        // Check for conflicts and merge
        mergedPrefs = _resolveConflicts(currentPrefs, serverPrefs, lastSync);
      }
      
      // Update local preferences
      await _saveLocalPreferences(mergedPrefs);
      
      // Update server preferences if needed
      final updateResponse = await _userService.updateUserPreferences(mergedPrefs);
      
      if (!updateResponse.isSuccess) {
        return SyncResult(
          success: false,
          message: 'Failed to update server preferences: ${updateResponse.message}',
        );
      }
      
      // Update sync timestamp
      await _setLastSyncTime(DateTime.now());
      
      // Clear pending changes
      await _clearPendingChanges();
      
      return SyncResult(
        success: true,
        message: 'Preferences synchronized successfully',
        data: mergedPrefs,
      );
    } catch (e) {
      debugPrint('Error syncing preferences: $e');
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    } finally {
      _syncInProgress = false;
    }
  }
  
  /// Load sync settings
  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final syncEnabled = prefs.getBool(_syncEnabledKey) ?? true;
    
    if (syncEnabled) {
      _startPeriodicSync();
    }
  }
  
  /// Get current local preferences
  Future<UserPreferences> _getCurrentPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = await getLastSyncTime();
    
    // Build preferences from various sources
    return UserPreferences(
      theme: prefs.getString('theme') ?? 'dark',
      language: prefs.getString('language') ?? 'en',
      timezone: prefs.getString('timezone') ?? 'UTC',
      notificationsEnabled: prefs.getBool('notifications_enabled') ?? true,
      emailNotifications: prefs.getBool('email_notifications') ?? true,
      pushNotifications: prefs.getBool('push_notifications') ?? true,
      terminal: _getTerminalPreferences(prefs),
      ai: _getAIPreferences(prefs),
      security: _getSecurityPreferences(prefs),
      sync: _getSyncPreferences(prefs).copyWith(lastSyncAt: lastSync),
    );
  }
  
  /// Get terminal preferences from SharedPreferences
  TerminalPreferences _getTerminalPreferences(SharedPreferences prefs) {
    return TerminalPreferences(
      fontSize: prefs.getString('terminal_font_size') ?? '14px',
      fontFamily: prefs.getString('terminal_font_family') ?? 'JetBrains Mono',
      colorScheme: prefs.getString('terminal_color_scheme') ?? 'dark',
      cursorBlink: prefs.getBool('terminal_cursor_blink') ?? true,
      cursorStyle: prefs.getString('terminal_cursor_style') ?? 'block',
      scrollbackLines: prefs.getInt('terminal_scrollback_lines') ?? 1000,
      showTimestamps: prefs.getBool('terminal_show_timestamps') ?? false,
      soundEnabled: prefs.getBool('terminal_sound_enabled') ?? true,
    );
  }
  
  /// Get AI preferences from SharedPreferences
  AIPreferences _getAIPreferences(SharedPreferences prefs) {
    return AIPreferences(
      enabled: prefs.getBool('ai_enabled') ?? true,
      defaultModel: prefs.getString('ai_default_model') ?? 'openai/gpt-4o-mini',
      autoSuggestions: prefs.getBool('ai_auto_suggestions') ?? true,
      errorExplanations: prefs.getBool('ai_error_explanations') ?? true,
      temperature: prefs.getDouble('ai_temperature') ?? 0.3,
      maxTokens: prefs.getInt('ai_max_tokens') ?? 500,
      cachingEnabled: prefs.getBool('ai_caching_enabled') ?? true,
      dailySpendLimit: prefs.getDouble('ai_daily_spend_limit') ?? 10.0,
    );
  }
  
  /// Get security preferences from SharedPreferences
  SecurityPreferences _getSecurityPreferences(SharedPreferences prefs) {
    return SecurityPreferences(
      biometricEnabled: prefs.getBool('security_biometric_enabled') ?? true,
      autoLockEnabled: prefs.getBool('security_auto_lock_enabled') ?? true,
      autoLockMinutes: prefs.getInt('security_auto_lock_minutes') ?? 15,
      requireAuthForSensitive: prefs.getBool('security_require_auth_sensitive') ?? true,
      sessionTimeoutEnabled: prefs.getBool('security_session_timeout_enabled') ?? true,
      sessionTimeoutMinutes: prefs.getInt('security_session_timeout_minutes') ?? 60,
      logSecurityEvents: prefs.getBool('security_log_events') ?? true,
    );
  }
  
  /// Get sync preferences from SharedPreferences
  SyncPreferences _getSyncPreferences(SharedPreferences prefs) {
    return SyncPreferences(
      enabled: prefs.getBool('sync_enabled') ?? true,
      autoSync: prefs.getBool('sync_auto') ?? true,
      conflictResolution: prefs.getString('sync_conflict_resolution') ?? 'merge',
      syncOnWifiOnly: prefs.getBool('sync_wifi_only') ?? false,
      syncIntervalMinutes: prefs.getInt('sync_interval_minutes') ?? 30,
      // Note: lastSyncAt will be set separately as it requires async call
    );
  }
  
  /// Save preferences locally
  Future<void> _saveLocalPreferences(UserPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    
    // General preferences
    await prefs.setString('theme', preferences.theme);
    await prefs.setString('language', preferences.language);
    await prefs.setString('timezone', preferences.timezone);
    await prefs.setBool('notifications_enabled', preferences.notificationsEnabled);
    await prefs.setBool('email_notifications', preferences.emailNotifications);
    await prefs.setBool('push_notifications', preferences.pushNotifications);
    
    // Terminal preferences
    await prefs.setString('terminal_font_size', preferences.terminal.fontSize);
    await prefs.setString('terminal_font_family', preferences.terminal.fontFamily);
    await prefs.setString('terminal_color_scheme', preferences.terminal.colorScheme);
    await prefs.setBool('terminal_cursor_blink', preferences.terminal.cursorBlink);
    await prefs.setString('terminal_cursor_style', preferences.terminal.cursorStyle);
    await prefs.setInt('terminal_scrollback_lines', preferences.terminal.scrollbackLines);
    await prefs.setBool('terminal_show_timestamps', preferences.terminal.showTimestamps);
    await prefs.setBool('terminal_sound_enabled', preferences.terminal.soundEnabled);
    
    // AI preferences
    await prefs.setBool('ai_enabled', preferences.ai.enabled);
    await prefs.setString('ai_default_model', preferences.ai.defaultModel);
    await prefs.setBool('ai_auto_suggestions', preferences.ai.autoSuggestions);
    await prefs.setBool('ai_error_explanations', preferences.ai.errorExplanations);
    await prefs.setDouble('ai_temperature', preferences.ai.temperature);
    await prefs.setInt('ai_max_tokens', preferences.ai.maxTokens);
    await prefs.setBool('ai_caching_enabled', preferences.ai.cachingEnabled);
    await prefs.setDouble('ai_daily_spend_limit', preferences.ai.dailySpendLimit);
    
    // Security preferences
    await prefs.setBool('security_biometric_enabled', preferences.security.biometricEnabled);
    await prefs.setBool('security_auto_lock_enabled', preferences.security.autoLockEnabled);
    await prefs.setInt('security_auto_lock_minutes', preferences.security.autoLockMinutes);
    await prefs.setBool('security_require_auth_sensitive', preferences.security.requireAuthForSensitive);
    await prefs.setBool('security_session_timeout_enabled', preferences.security.sessionTimeoutEnabled);
    await prefs.setInt('security_session_timeout_minutes', preferences.security.sessionTimeoutMinutes);
    await prefs.setBool('security_log_events', preferences.security.logSecurityEvents);
    
    // Sync preferences
    await prefs.setBool('sync_enabled', preferences.sync.enabled);
    await prefs.setBool('sync_auto', preferences.sync.autoSync);
    await prefs.setString('sync_conflict_resolution', preferences.sync.conflictResolution);
    await prefs.setBool('sync_wifi_only', preferences.sync.syncOnWifiOnly);
    await prefs.setInt('sync_interval_minutes', preferences.sync.syncIntervalMinutes);
  }
  
  /// Merge two preference objects
  UserPreferences _mergePreferences(UserPreferences local, UserPreferences server) {
    // Simple merge strategy - prefer server preferences for most settings
    // but keep local terminal and AI preferences unless explicitly changed
    
    return UserPreferences(
      theme: server.theme,
      language: server.language,
      timezone: server.timezone,
      dateFormat: server.dateFormat,
      timeFormat: server.timeFormat,
      notificationsEnabled: server.notificationsEnabled,
      emailNotifications: server.emailNotifications,
      pushNotifications: server.pushNotifications,
      featureFlags: server.featureFlags,
      terminal: local.terminal, // Keep local terminal preferences
      ai: _mergeAIPreferences(local.ai, server.ai),
      security: server.security,
      sync: server.sync,
      custom: {...local.custom, ...server.custom},
    );
  }
  
  /// Merge AI preferences with conflict resolution
  AIPreferences _mergeAIPreferences(AIPreferences local, AIPreferences server) {
    return AIPreferences(
      enabled: server.enabled,
      defaultModel: server.defaultModel,
      autoSuggestions: server.autoSuggestions,
      errorExplanations: server.errorExplanations,
      temperature: local.temperature, // Keep local temperature setting
      maxTokens: local.maxTokens, // Keep local max tokens
      cachingEnabled: server.cachingEnabled,
      dailySpendLimit: server.dailySpendLimit,
      modelSettings: {...local.modelSettings, ...server.modelSettings},
    );
  }
  
  /// Resolve conflicts between local and server preferences
  UserPreferences _resolveConflicts(
    UserPreferences local, 
    UserPreferences server, 
    DateTime lastSync,
  ) {
    // For now, use simple merge strategy
    // In future, could implement timestamp-based conflict resolution
    return _mergePreferences(local, server);
  }
  
  /// Clear pending changes
  Future<void> _clearPendingChanges() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingChangesKey);
  }
  
  /// Force sync now
  Future<SyncResult> forceSyncNow() async {
    return await syncPreferences(forceSync: true);
  }
  
  /// Get sync status
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      enabled: await isSyncEnabled(),
      inProgress: _syncInProgress,
      lastSync: await getLastSyncTime(),
      needsSync: await needsSync(),
    );
  }
  
  /// Dispose resources
  void dispose() {
    _stopPeriodicSync();
  }
}

/// Sync result model
@immutable
class SyncResult {
  final bool success;
  final String message;
  final UserPreferences? data;
  final DateTime timestamp;
  
  SyncResult({
    required this.success,
    required this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  @override
  String toString() {
    return 'SyncResult{success: $success, message: $message}';
  }
}

/// Sync status model
@immutable
class SyncStatus {
  final bool enabled;
  final bool inProgress;
  final DateTime? lastSync;
  final bool needsSync;
  
  const SyncStatus({
    required this.enabled,
    required this.inProgress,
    this.lastSync,
    required this.needsSync,
  });
  
  @override
  String toString() {
    return 'SyncStatus{enabled: $enabled, inProgress: $inProgress, needsSync: $needsSync}';
  }
}