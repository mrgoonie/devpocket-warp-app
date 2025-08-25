/// SSH Profile Synchronization Models
/// Handles data models for SSH profile sync operations, conflict resolution, and sync state management

import 'ssh_profile_models.dart';

/// Synchronization strategy options
enum SyncStrategy {
  uploadLocal('upload_local'),    // Upload local profiles to server
  downloadRemote('download_remote'), // Download server profiles
  merge('merge'),                 // Intelligent merge
  askUser('ask_user');            // Prompt user for decision

  const SyncStrategy(this.value);
  final String value;

  static SyncStrategy fromString(String value) {
    return SyncStrategy.values.firstWhere(
      (strategy) => strategy.value == value,
      orElse: () => SyncStrategy.askUser,
    );
  }
}

/// Synchronization status
enum SyncStatus { idle, syncing, success, error, conflict }

/// Result of sync operations
class SyncResult {
  final bool success;
  final int successful;
  final int failed;
  final int total;
  final Map<String, bool> details;
  final String? error;
  final Duration? duration;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    required this.successful,
    required this.failed,
    required this.total,
    required this.details,
    this.error,
    this.duration,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory SyncResult.success({
    required int successful,
    required int failed,
    required Map<String, bool> details,
    Duration? duration,
  }) {
    return SyncResult(
      success: failed == 0,
      successful: successful,
      failed: failed,
      total: successful + failed,
      details: details,
      duration: duration,
    );
  }

  factory SyncResult.error(String error) => SyncResult(
    success: false,
    successful: 0,
    failed: 0,
    total: 0,
    details: {},
    error: error,
  );

  factory SyncResult.empty() => SyncResult(
    success: true,
    successful: 0,
    failed: 0,
    total: 0,
    details: {},
  );

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'successful': successful,
      'failed': failed,
      'total': total,
      'details': details,
      if (error != null) 'error': error,
      if (duration != null) 'duration_ms': duration!.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'SyncResult{success: $success, successful: $successful, failed: $failed, total: $total}';
  }
}

/// Types of data inconsistencies
enum InconsistencyType {
  none,
  localOnly,      // Local has data, server doesn't
  serverOnly,     // Server has data, local doesn't
  conflicts,      // Both have data but different
  mixed,          // Complex conflicts with multiple types
}

/// Profile conflict between local and server versions
class ProfileConflict {
  final SshProfile localProfile;
  final SshProfile serverProfile;
  final List<String> conflictingFields;

  const ProfileConflict({
    required this.localProfile,
    required this.serverProfile,
    required this.conflictingFields,
  });

  /// Compare profiles and identify conflicting fields
  static ProfileConflict? detect(SshProfile local, SshProfile server) {
    if (local.id != server.id) return null;

    final conflicts = <String>[];
    
    if (local.name != server.name) conflicts.add('name');
    if (local.host != server.host) conflicts.add('host');
    if (local.port != server.port) conflicts.add('port');
    if (local.username != server.username) conflicts.add('username');
    if (local.authType != server.authType) conflicts.add('authType');
    if (local.description != server.description) conflicts.add('description');
    if (!_listsEqual(local.tags, server.tags)) conflicts.add('tags');
    if (local.updatedAt.isAfter(server.updatedAt)) conflicts.add('timestamp');

    return conflicts.isNotEmpty 
        ? ProfileConflict(
            localProfile: local,
            serverProfile: server,
            conflictingFields: conflicts,
          )
        : null;
  }

  static bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sortedA = [...a]..sort();
    final sortedB = [...b]..sort();
    for (int i = 0; i < sortedA.length; i++) {
      if (sortedA[i] != sortedB[i]) return false;
    }
    return true;
  }

  bool get hasConflicts => conflictingFields.isNotEmpty;
  bool get isNewerLocal => localProfile.updatedAt.isAfter(serverProfile.updatedAt);
  bool get isNewerServer => serverProfile.updatedAt.isAfter(localProfile.updatedAt);

  @override
  String toString() {
    return 'ProfileConflict{id: ${localProfile.id}, conflicts: $conflictingFields}';
  }
}

/// Data inconsistency detection result
class DataInconsistency {
  final InconsistencyType type;
  final List<SshProfile> localOnly;
  final List<SshProfile> serverOnly;
  final List<ProfileConflict> conflicts;
  final String? description;

  const DataInconsistency({
    required this.type,
    this.localOnly = const [],
    this.serverOnly = const [],
    this.conflicts = const [],
    this.description,
  });

  factory DataInconsistency.none() => const DataInconsistency(
    type: InconsistencyType.none,
    description: 'No inconsistencies detected',
  );

  factory DataInconsistency.localOnly(List<SshProfile> localProfiles) =>
      DataInconsistency(
        type: InconsistencyType.localOnly,
        localOnly: localProfiles,
        description: '${localProfiles.length} profile(s) exist locally but not on server',
      );

  factory DataInconsistency.serverOnly(List<SshProfile> serverProfiles) =>
      DataInconsistency(
        type: InconsistencyType.serverOnly,
        serverOnly: serverProfiles,
        description: '${serverProfiles.length} profile(s) exist on server but not locally',
      );

  factory DataInconsistency.conflicts(List<ProfileConflict> profileConflicts) =>
      DataInconsistency(
        type: InconsistencyType.conflicts,
        conflicts: profileConflicts,
        description: '${profileConflicts.length} profile(s) have conflicts between local and server versions',
      );

  factory DataInconsistency.mixed({
    List<SshProfile>? localOnly,
    List<SshProfile>? serverOnly,
    List<ProfileConflict>? conflicts,
  }) => DataInconsistency(
    type: InconsistencyType.mixed,
    localOnly: localOnly ?? [],
    serverOnly: serverOnly ?? [],
    conflicts: conflicts ?? [],
    description: 'Multiple types of inconsistencies detected',
  );

  bool get hasInconsistency => type != InconsistencyType.none;
  bool get hasLocalOnly => localOnly.isNotEmpty;
  bool get hasServerOnly => serverOnly.isNotEmpty;
  bool get hasConflicts => conflicts.isNotEmpty;
  bool get requiresUserDecision => hasConflicts || (hasLocalOnly && hasServerOnly);

  int get totalIssues => localOnly.length + serverOnly.length + conflicts.length;

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'local_only_count': localOnly.length,
      'server_only_count': serverOnly.length,
      'conflicts_count': conflicts.length,
      'total_issues': totalIssues,
      'description': description,
      'requires_user_decision': requiresUserDecision,
    };
  }

  @override
  String toString() {
    return 'DataInconsistency{type: ${type.name}, localOnly: ${localOnly.length}, serverOnly: ${serverOnly.length}, conflicts: ${conflicts.length}}';
  }
}

/// Synchronization state management
class SyncState {
  final SyncStatus status;
  final String? message;
  final SyncResult? lastResult;
  final DataInconsistency? pendingConflict;
  final double? progress;
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.message,
    this.lastResult,
    this.pendingConflict,
    this.progress,
    this.lastSyncTime,
  });

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    SyncResult? lastResult,
    DataInconsistency? pendingConflict,
    double? progress,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastResult: lastResult ?? this.lastResult,
      pendingConflict: pendingConflict ?? this.pendingConflict,
      progress: progress ?? this.progress,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  bool get isIdle => status == SyncStatus.idle;
  bool get isSyncing => status == SyncStatus.syncing;
  bool get hasError => status == SyncStatus.error;
  bool get hasConflict => status == SyncStatus.conflict;
  bool get isSuccess => status == SyncStatus.success;

  String get displayMessage {
    switch (status) {
      case SyncStatus.idle:
        return lastSyncTime != null 
            ? 'Last sync: ${_formatTime(lastSyncTime!)}'
            : 'Ready to sync';
      case SyncStatus.syncing:
        final progressText = progress != null 
            ? ' (${(progress! * 100).toInt()}%)'
            : '';
        return message ?? 'Syncing$progressText...';
      case SyncStatus.success:
        return message ?? 'Sync completed successfully';
      case SyncStatus.error:
        return message ?? 'Sync failed';
      case SyncStatus.conflict:
        return message ?? 'Sync conflicts detected';
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  @override
  String toString() {
    return 'SyncState{status: ${status.name}, message: $message}';
  }
}

/// Sync configuration options
class SyncConfig {
  final SyncStrategy defaultStrategy;
  final bool autoSyncEnabled;
  final Duration syncInterval;
  final bool conflictNotificationsEnabled;
  final bool backgroundSyncEnabled;

  const SyncConfig({
    this.defaultStrategy = SyncStrategy.askUser,
    this.autoSyncEnabled = false,
    this.syncInterval = const Duration(minutes: 30),
    this.conflictNotificationsEnabled = true,
    this.backgroundSyncEnabled = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'default_strategy': defaultStrategy.value,
      'auto_sync_enabled': autoSyncEnabled,
      'sync_interval_minutes': syncInterval.inMinutes,
      'conflict_notifications_enabled': conflictNotificationsEnabled,
      'background_sync_enabled': backgroundSyncEnabled,
    };
  }

  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      defaultStrategy: SyncStrategy.fromString(json['default_strategy'] ?? 'ask_user'),
      autoSyncEnabled: json['auto_sync_enabled'] ?? false,
      syncInterval: Duration(minutes: json['sync_interval_minutes'] ?? 30),
      conflictNotificationsEnabled: json['conflict_notifications_enabled'] ?? true,
      backgroundSyncEnabled: json['background_sync_enabled'] ?? false,
    );
  }
}