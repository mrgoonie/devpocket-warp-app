import 'package:flutter/foundation.dart';

/// User profile model
@immutable
class UserProfile {
  final String id;
  final String username;
  final String email;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final String? website;
  final String? githubUsername;
  final bool emailVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  final UserSubscriptionStatus? subscription;
  final Map<String, dynamic> metadata;
  
  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.bio,
    this.location,
    this.website,
    this.githubUsername,
    required this.emailVerified,
    required this.createdAt,
    required this.updatedAt,
    this.subscription,
    this.metadata = const {},
  });
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      displayName: json['display_name'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      location: json['location'],
      website: json['website'],
      githubUsername: json['github_username'],
      emailVerified: json['email_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      subscription: json['subscription'] != null
          ? UserSubscriptionStatus.fromJson(json['subscription'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'location': location,
      'website': website,
      'github_username': githubUsername,
      'email_verified': emailVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'subscription': subscription?.toJson(),
      'metadata': metadata,
    };
  }
  
  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? location,
    String? website,
    String? githubUsername,
    bool? emailVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserSubscriptionStatus? subscription,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      location: location ?? this.location,
      website: website ?? this.website,
      githubUsername: githubUsername ?? this.githubUsername,
      emailVerified: emailVerified ?? this.emailVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscription: subscription ?? this.subscription,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  String toString() {
    return 'UserProfile{id: $id, username: $username, email: $email}';
  }
}

/// User subscription status
@immutable
class UserSubscriptionStatus {
  final String plan;
  final bool isActive;
  final DateTime? expiresAt;
  final String? stripeCustomerId;
  final Map<String, int> usage;
  final Map<String, int> limits;
  
  const UserSubscriptionStatus({
    required this.plan,
    required this.isActive,
    this.expiresAt,
    this.stripeCustomerId,
    this.usage = const {},
    this.limits = const {},
  });
  
  factory UserSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return UserSubscriptionStatus(
      plan: json['plan'],
      isActive: json['is_active'] ?? false,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      stripeCustomerId: json['stripe_customer_id'],
      usage: Map<String, int>.from(json['usage'] ?? {}),
      limits: Map<String, int>.from(json['limits'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'plan': plan,
      'is_active': isActive,
      'expires_at': expiresAt?.toIso8601String(),
      'stripe_customer_id': stripeCustomerId,
      'usage': usage,
      'limits': limits,
    };
  }
  
  bool get isPro => plan == 'pro';
  bool get isTeam => plan == 'team';
  bool get isFree => plan == 'free';
}

/// User preferences model
@immutable
class UserPreferences {
  final String theme;
  final String language;
  final String timezone;
  final String dateFormat;
  final String timeFormat;
  final bool notificationsEnabled;
  final bool emailNotifications;
  final bool pushNotifications;
  final Map<String, bool> featureFlags;
  final TerminalPreferences terminal;
  final AIPreferences ai;
  final SecurityPreferences security;
  final SyncPreferences sync;
  final Map<String, dynamic> custom;
  
  const UserPreferences({
    this.theme = 'dark',
    this.language = 'en',
    this.timezone = 'UTC',
    this.dateFormat = 'yyyy-MM-dd',
    this.timeFormat = '24h',
    this.notificationsEnabled = true,
    this.emailNotifications = true,
    this.pushNotifications = true,
    this.featureFlags = const {},
    this.terminal = const TerminalPreferences(),
    this.ai = const AIPreferences(),
    this.security = const SecurityPreferences(),
    this.sync = const SyncPreferences(),
    this.custom = const {},
  });
  
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      theme: json['theme'] ?? 'dark',
      language: json['language'] ?? 'en',
      timezone: json['timezone'] ?? 'UTC',
      dateFormat: json['date_format'] ?? 'yyyy-MM-dd',
      timeFormat: json['time_format'] ?? '24h',
      notificationsEnabled: json['notifications_enabled'] ?? true,
      emailNotifications: json['email_notifications'] ?? true,
      pushNotifications: json['push_notifications'] ?? true,
      featureFlags: Map<String, bool>.from(json['feature_flags'] ?? {}),
      terminal: json['terminal'] != null
          ? TerminalPreferences.fromJson(json['terminal'])
          : const TerminalPreferences(),
      ai: json['ai'] != null
          ? AIPreferences.fromJson(json['ai'])
          : const AIPreferences(),
      security: json['security'] != null
          ? SecurityPreferences.fromJson(json['security'])
          : const SecurityPreferences(),
      sync: json['sync'] != null
          ? SyncPreferences.fromJson(json['sync'])
          : const SyncPreferences(),
      custom: Map<String, dynamic>.from(json['custom'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'language': language,
      'timezone': timezone,
      'date_format': dateFormat,
      'time_format': timeFormat,
      'notifications_enabled': notificationsEnabled,
      'email_notifications': emailNotifications,
      'push_notifications': pushNotifications,
      'feature_flags': featureFlags,
      'terminal': terminal.toJson(),
      'ai': ai.toJson(),
      'security': security.toJson(),
      'sync': sync.toJson(),
      'custom': custom,
    };
  }
  
  UserPreferences copyWith({
    String? theme,
    String? language,
    String? timezone,
    String? dateFormat,
    String? timeFormat,
    bool? notificationsEnabled,
    bool? emailNotifications,
    bool? pushNotifications,
    Map<String, bool>? featureFlags,
    TerminalPreferences? terminal,
    AIPreferences? ai,
    SecurityPreferences? security,
    SyncPreferences? sync,
    Map<String, dynamic>? custom,
  }) {
    return UserPreferences(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      timezone: timezone ?? this.timezone,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      emailNotifications: emailNotifications ?? this.emailNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      featureFlags: featureFlags ?? this.featureFlags,
      terminal: terminal ?? this.terminal,
      ai: ai ?? this.ai,
      security: security ?? this.security,
      sync: sync ?? this.sync,
      custom: custom ?? this.custom,
    );
  }
}

/// Terminal-specific preferences
@immutable
class TerminalPreferences {
  final String fontSize;
  final String fontFamily;
  final String colorScheme;
  final bool cursorBlink;
  final String cursorStyle;
  final int scrollbackLines;
  final bool showTimestamps;
  final bool soundEnabled;
  final Map<String, String> keyBindings;
  
  const TerminalPreferences({
    this.fontSize = '14px',
    this.fontFamily = 'JetBrains Mono',
    this.colorScheme = 'dark',
    this.cursorBlink = true,
    this.cursorStyle = 'block',
    this.scrollbackLines = 1000,
    this.showTimestamps = false,
    this.soundEnabled = true,
    this.keyBindings = const {},
  });
  
  factory TerminalPreferences.fromJson(Map<String, dynamic> json) {
    return TerminalPreferences(
      fontSize: json['font_size'] ?? '14px',
      fontFamily: json['font_family'] ?? 'JetBrains Mono',
      colorScheme: json['color_scheme'] ?? 'dark',
      cursorBlink: json['cursor_blink'] ?? true,
      cursorStyle: json['cursor_style'] ?? 'block',
      scrollbackLines: json['scrollback_lines'] ?? 1000,
      showTimestamps: json['show_timestamps'] ?? false,
      soundEnabled: json['sound_enabled'] ?? true,
      keyBindings: Map<String, String>.from(json['key_bindings'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'font_size': fontSize,
      'font_family': fontFamily,
      'color_scheme': colorScheme,
      'cursor_blink': cursorBlink,
      'cursor_style': cursorStyle,
      'scrollback_lines': scrollbackLines,
      'show_timestamps': showTimestamps,
      'sound_enabled': soundEnabled,
      'key_bindings': keyBindings,
    };
  }
}

/// AI-specific preferences
@immutable
class AIPreferences {
  final bool enabled;
  final String defaultModel;
  final bool autoSuggestions;
  final bool errorExplanations;
  final double temperature;
  final int maxTokens;
  final bool cachingEnabled;
  final double dailySpendLimit;
  final Map<String, dynamic> modelSettings;
  
  const AIPreferences({
    this.enabled = true,
    this.defaultModel = 'openai/gpt-4o-mini',
    this.autoSuggestions = true,
    this.errorExplanations = true,
    this.temperature = 0.3,
    this.maxTokens = 500,
    this.cachingEnabled = true,
    this.dailySpendLimit = 10.0,
    this.modelSettings = const {},
  });
  
  factory AIPreferences.fromJson(Map<String, dynamic> json) {
    return AIPreferences(
      enabled: json['enabled'] ?? true,
      defaultModel: json['default_model'] ?? 'openai/gpt-4o-mini',
      autoSuggestions: json['auto_suggestions'] ?? true,
      errorExplanations: json['error_explanations'] ?? true,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.3,
      maxTokens: json['max_tokens'] ?? 500,
      cachingEnabled: json['caching_enabled'] ?? true,
      dailySpendLimit: (json['daily_spend_limit'] as num?)?.toDouble() ?? 10.0,
      modelSettings: Map<String, dynamic>.from(json['model_settings'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'default_model': defaultModel,
      'auto_suggestions': autoSuggestions,
      'error_explanations': errorExplanations,
      'temperature': temperature,
      'max_tokens': maxTokens,
      'caching_enabled': cachingEnabled,
      'daily_spend_limit': dailySpendLimit,
      'model_settings': modelSettings,
    };
  }
}

/// Security-specific preferences
@immutable
class SecurityPreferences {
  final bool biometricEnabled;
  final bool autoLockEnabled;
  final int autoLockMinutes;
  final bool requireAuthForSensitive;
  final bool sessionTimeoutEnabled;
  final int sessionTimeoutMinutes;
  final bool logSecurityEvents;
  final Map<String, bool> permissions;
  
  const SecurityPreferences({
    this.biometricEnabled = true,
    this.autoLockEnabled = true,
    this.autoLockMinutes = 15,
    this.requireAuthForSensitive = true,
    this.sessionTimeoutEnabled = true,
    this.sessionTimeoutMinutes = 60,
    this.logSecurityEvents = true,
    this.permissions = const {},
  });
  
  factory SecurityPreferences.fromJson(Map<String, dynamic> json) {
    return SecurityPreferences(
      biometricEnabled: json['biometric_enabled'] ?? true,
      autoLockEnabled: json['auto_lock_enabled'] ?? true,
      autoLockMinutes: json['auto_lock_minutes'] ?? 15,
      requireAuthForSensitive: json['require_auth_for_sensitive'] ?? true,
      sessionTimeoutEnabled: json['session_timeout_enabled'] ?? true,
      sessionTimeoutMinutes: json['session_timeout_minutes'] ?? 60,
      logSecurityEvents: json['log_security_events'] ?? true,
      permissions: Map<String, bool>.from(json['permissions'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'biometric_enabled': biometricEnabled,
      'auto_lock_enabled': autoLockEnabled,
      'auto_lock_minutes': autoLockMinutes,
      'require_auth_for_sensitive': requireAuthForSensitive,
      'session_timeout_enabled': sessionTimeoutEnabled,
      'session_timeout_minutes': sessionTimeoutMinutes,
      'log_security_events': logSecurityEvents,
      'permissions': permissions,
    };
  }
}

/// Sync-specific preferences
@immutable
class SyncPreferences {
  final bool enabled;
  final bool autoSync;
  final List<String> syncItems;
  final String conflictResolution;
  final bool syncOnWifiOnly;
  final int syncIntervalMinutes;
  final DateTime? lastSyncAt;
  final Map<String, dynamic> syncStatus;
  
  const SyncPreferences({
    this.enabled = true,
    this.autoSync = true,
    this.syncItems = const ['preferences', 'ssh_profiles', 'history'],
    this.conflictResolution = 'merge',
    this.syncOnWifiOnly = false,
    this.syncIntervalMinutes = 30,
    this.lastSyncAt,
    this.syncStatus = const {},
  });
  
  factory SyncPreferences.fromJson(Map<String, dynamic> json) {
    return SyncPreferences(
      enabled: json['enabled'] ?? true,
      autoSync: json['auto_sync'] ?? true,
      syncItems: List<String>.from(json['sync_items'] ?? ['preferences', 'ssh_profiles', 'history']),
      conflictResolution: json['conflict_resolution'] ?? 'merge',
      syncOnWifiOnly: json['sync_on_wifi_only'] ?? false,
      syncIntervalMinutes: json['sync_interval_minutes'] ?? 30,
      lastSyncAt: json['last_sync_at'] != null
          ? DateTime.parse(json['last_sync_at'])
          : null,
      syncStatus: Map<String, dynamic>.from(json['sync_status'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'auto_sync': autoSync,
      'sync_items': syncItems,
      'conflict_resolution': conflictResolution,
      'sync_on_wifi_only': syncOnWifiOnly,
      'sync_interval_minutes': syncIntervalMinutes,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'sync_status': syncStatus,
    };
  }
  
  SyncPreferences copyWith({
    bool? enabled,
    bool? autoSync,
    List<String>? syncItems,
    String? conflictResolution,
    bool? syncOnWifiOnly,
    int? syncIntervalMinutes,
    DateTime? lastSyncAt,
    Map<String, dynamic>? syncStatus,
  }) {
    return SyncPreferences(
      enabled: enabled ?? this.enabled,
      autoSync: autoSync ?? this.autoSync,
      syncItems: syncItems ?? this.syncItems,
      conflictResolution: conflictResolution ?? this.conflictResolution,
      syncOnWifiOnly: syncOnWifiOnly ?? this.syncOnWifiOnly,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// User device model
@immutable
class UserDevice {
  final String id;
  final String name;
  final String type;
  final String os;
  final String version;
  final String? deviceId;
  final bool isCurrentDevice;
  final DateTime lastSeenAt;
  final DateTime registeredAt;
  final Map<String, dynamic> metadata;
  
  const UserDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.os,
    required this.version,
    this.deviceId,
    required this.isCurrentDevice,
    required this.lastSeenAt,
    required this.registeredAt,
    this.metadata = const {},
  });
  
  factory UserDevice.fromJson(Map<String, dynamic> json) {
    return UserDevice(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      os: json['os'],
      version: json['version'],
      deviceId: json['device_id'],
      isCurrentDevice: json['is_current_device'] ?? false,
      lastSeenAt: DateTime.parse(json['last_seen_at']),
      registeredAt: DateTime.parse(json['registered_at']),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'os': os,
      'version': version,
      'device_id': deviceId,
      'is_current_device': isCurrentDevice,
      'last_seen_at': lastSeenAt.toIso8601String(),
      'registered_at': registeredAt.toIso8601String(),
      'metadata': metadata,
    };
  }
  
  @override
  String toString() {
    return 'UserDevice{id: $id, name: $name, type: $type, os: $os}';
  }
}