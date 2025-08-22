import 'package:flutter/foundation.dart';

/// Command execution result
enum CommandResultType {
  success('success'),
  error('error'),
  warning('warning'),
  info('info');
  
  const CommandResultType(this.value);
  final String value;
  
  static CommandResultType fromString(String value) {
    switch (value) {
      case 'success':
        return CommandResultType.success;
      case 'error':
        return CommandResultType.error;
      case 'warning':
        return CommandResultType.warning;
      case 'info':
        return CommandResultType.info;
      default:
        return CommandResultType.info;
    }
  }
}

/// Command history entry model
@immutable
class CommandHistoryEntry {
  final String id;
  final String command;
  final String? output;
  final CommandResultType resultType;
  final int? exitCode;
  final Duration? executionTime;
  final String sessionId;
  final String? workingDirectory;
  final String? shellType;
  final Map<String, String> environment;
  final DateTime executedAt;
  final String? sshProfileId;
  final bool isFavorite;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final String deviceId;
  final String userId;
  
  const CommandHistoryEntry({
    required this.id,
    required this.command,
    this.output,
    required this.resultType,
    this.exitCode,
    this.executionTime,
    required this.sessionId,
    this.workingDirectory,
    this.shellType,
    this.environment = const {},
    required this.executedAt,
    this.sshProfileId,
    this.isFavorite = false,
    this.tags = const [],
    this.metadata = const {},
    required this.deviceId,
    required this.userId,
  });
  
  factory CommandHistoryEntry.fromJson(Map<String, dynamic> json) {
    return CommandHistoryEntry(
      id: json['id'],
      command: json['command'],
      output: json['output'],
      resultType: CommandResultType.fromString(json['result_type'] ?? 'info'),
      exitCode: json['exit_code'],
      executionTime: json['execution_time_ms'] != null 
          ? Duration(milliseconds: json['execution_time_ms'])
          : null,
      sessionId: json['session_id'],
      workingDirectory: json['working_directory'],
      shellType: json['shell_type'],
      environment: Map<String, String>.from(json['environment'] ?? {}),
      executedAt: DateTime.parse(json['executed_at']),
      sshProfileId: json['ssh_profile_id'],
      isFavorite: json['is_favorite'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      deviceId: json['device_id'],
      userId: json['user_id'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': command,
      'output': output,
      'result_type': resultType.value,
      'exit_code': exitCode,
      'execution_time_ms': executionTime?.inMilliseconds,
      'session_id': sessionId,
      'working_directory': workingDirectory,
      'shell_type': shellType,
      'environment': environment,
      'executed_at': executedAt.toIso8601String(),
      'ssh_profile_id': sshProfileId,
      'is_favorite': isFavorite,
      'tags': tags,
      'metadata': metadata,
      'device_id': deviceId,
      'user_id': userId,
    };
  }
  
  CommandHistoryEntry copyWith({
    String? id,
    String? command,
    String? output,
    CommandResultType? resultType,
    int? exitCode,
    Duration? executionTime,
    String? sessionId,
    String? workingDirectory,
    String? shellType,
    Map<String, String>? environment,
    DateTime? executedAt,
    String? sshProfileId,
    bool? isFavorite,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    String? deviceId,
    String? userId,
  }) {
    return CommandHistoryEntry(
      id: id ?? this.id,
      command: command ?? this.command,
      output: output ?? this.output,
      resultType: resultType ?? this.resultType,
      exitCode: exitCode ?? this.exitCode,
      executionTime: executionTime ?? this.executionTime,
      sessionId: sessionId ?? this.sessionId,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      shellType: shellType ?? this.shellType,
      environment: environment ?? this.environment,
      executedAt: executedAt ?? this.executedAt,
      sshProfileId: sshProfileId ?? this.sshProfileId,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
    );
  }
  
  /// Get formatted execution time
  String get formattedExecutionTime {
    if (executionTime == null) return 'Unknown';
    
    final ms = executionTime!.inMilliseconds;
    if (ms < 1000) {
      return '${ms}ms';
    } else if (ms < 60000) {
      return '${(ms / 1000).toStringAsFixed(1)}s';
    } else {
      final minutes = (ms / 60000).floor();
      final seconds = ((ms % 60000) / 1000).toStringAsFixed(1);
      return '${minutes}m ${seconds}s';
    }
  }
  
  /// Check if command was successful
  bool get isSuccessful => resultType == CommandResultType.success && (exitCode == null || exitCode == 0);
  
  /// Get display name for the session
  String get sessionDisplayName {
    if (sshProfileId != null) {
      return 'SSH Session';
    } else {
      return 'Local Terminal';
    }
  }
  
  @override
  String toString() {
    return 'CommandHistoryEntry{id: $id, command: ${command.length > 50 ? '${command.substring(0, 50)}...' : command}, resultType: $resultType}';
  }
}

/// Command history search filters
@immutable
class CommandHistoryFilter {
  final String? query;
  final List<CommandResultType> resultTypes;
  final List<String> tags;
  final String? sessionId;
  final String? sshProfileId;
  final String? deviceId;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool favoritesOnly;
  final String sortBy;
  final bool sortDescending;
  final int limit;
  final int offset;
  
  const CommandHistoryFilter({
    this.query,
    this.resultTypes = const [],
    this.tags = const [],
    this.sessionId,
    this.sshProfileId,
    this.deviceId,
    this.startDate,
    this.endDate,
    this.favoritesOnly = false,
    this.sortBy = 'executed_at',
    this.sortDescending = true,
    this.limit = 50,
    this.offset = 0,
  });
  
  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    
    if (query != null && query!.isNotEmpty) {
      params['query'] = query;
    }
    
    if (resultTypes.isNotEmpty) {
      params['result_types'] = resultTypes.map((t) => t.value).join(',');
    }
    
    if (tags.isNotEmpty) {
      params['tags'] = tags.join(',');
    }
    
    if (sessionId != null) {
      params['session_id'] = sessionId;
    }
    
    if (sshProfileId != null) {
      params['ssh_profile_id'] = sshProfileId;
    }
    
    if (deviceId != null) {
      params['device_id'] = deviceId;
    }
    
    if (startDate != null) {
      params['start_date'] = startDate!.toIso8601String();
    }
    
    if (endDate != null) {
      params['end_date'] = endDate!.toIso8601String();
    }
    
    if (favoritesOnly) {
      params['favorites_only'] = 'true';
    }
    
    params['sort_by'] = sortBy;
    params['sort_desc'] = sortDescending ? 'true' : 'false';
    params['limit'] = limit.toString();
    params['offset'] = offset.toString();
    
    return params;
  }
  
  CommandHistoryFilter copyWith({
    String? query,
    List<CommandResultType>? resultTypes,
    List<String>? tags,
    String? sessionId,
    String? sshProfileId,
    String? deviceId,
    DateTime? startDate,
    DateTime? endDate,
    bool? favoritesOnly,
    String? sortBy,
    bool? sortDescending,
    int? limit,
    int? offset,
  }) {
    return CommandHistoryFilter(
      query: query ?? this.query,
      resultTypes: resultTypes ?? this.resultTypes,
      tags: tags ?? this.tags,
      sessionId: sessionId ?? this.sessionId,
      sshProfileId: sshProfileId ?? this.sshProfileId,
      deviceId: deviceId ?? this.deviceId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      sortBy: sortBy ?? this.sortBy,
      sortDescending: sortDescending ?? this.sortDescending,
      limit: limit ?? this.limit,
      offset: offset ?? this.offset,
    );
  }
}

/// Command history statistics
@immutable
class CommandHistoryStats {
  final int totalCommands;
  final int successfulCommands;
  final int failedCommands;
  final int favoriteCommands;
  final Map<String, int> commandsByType;
  final Map<String, int> commandsByDevice;
  final Map<String, int> commandsBySession;
  final DateTime? firstCommandAt;
  final DateTime? lastCommandAt;
  final Duration? averageExecutionTime;
  final List<String> topCommands;
  final List<String> recentWorkingDirectories;
  
  const CommandHistoryStats({
    required this.totalCommands,
    required this.successfulCommands,
    required this.failedCommands,
    required this.favoriteCommands,
    this.commandsByType = const {},
    this.commandsByDevice = const {},
    this.commandsBySession = const {},
    this.firstCommandAt,
    this.lastCommandAt,
    this.averageExecutionTime,
    this.topCommands = const [],
    this.recentWorkingDirectories = const [],
  });
  
  factory CommandHistoryStats.fromJson(Map<String, dynamic> json) {
    return CommandHistoryStats(
      totalCommands: json['total_commands'] ?? 0,
      successfulCommands: json['successful_commands'] ?? 0,
      failedCommands: json['failed_commands'] ?? 0,
      favoriteCommands: json['favorite_commands'] ?? 0,
      commandsByType: Map<String, int>.from(json['commands_by_type'] ?? {}),
      commandsByDevice: Map<String, int>.from(json['commands_by_device'] ?? {}),
      commandsBySession: Map<String, int>.from(json['commands_by_session'] ?? {}),
      firstCommandAt: json['first_command_at'] != null 
          ? DateTime.parse(json['first_command_at'])
          : null,
      lastCommandAt: json['last_command_at'] != null 
          ? DateTime.parse(json['last_command_at'])
          : null,
      averageExecutionTime: json['average_execution_time_ms'] != null
          ? Duration(milliseconds: json['average_execution_time_ms'])
          : null,
      topCommands: List<String>.from(json['top_commands'] ?? []),
      recentWorkingDirectories: List<String>.from(json['recent_working_directories'] ?? []),
    );
  }
  
  /// Calculate success rate
  double get successRate {
    if (totalCommands == 0) return 0.0;
    return successfulCommands / totalCommands;
  }
  
  /// Get formatted success rate
  String get formattedSuccessRate {
    return '${(successRate * 100).toStringAsFixed(1)}%';
  }
  
  @override
  String toString() {
    return 'CommandHistoryStats{totalCommands: $totalCommands, successRate: $formattedSuccessRate}';
  }
}

/// Command history sync status
@immutable
class CommandHistorySyncStatus {
  final bool enabled;
  final bool inProgress;
  final DateTime? lastSync;
  final int pendingUploads;
  final int pendingDownloads;
  final List<String> syncErrors;
  final int totalSynced;
  final DateTime? nextSyncAt;
  
  const CommandHistorySyncStatus({
    required this.enabled,
    required this.inProgress,
    this.lastSync,
    this.pendingUploads = 0,
    this.pendingDownloads = 0,
    this.syncErrors = const [],
    this.totalSynced = 0,
    this.nextSyncAt,
  });
  
  factory CommandHistorySyncStatus.fromJson(Map<String, dynamic> json) {
    return CommandHistorySyncStatus(
      enabled: json['enabled'] ?? false,
      inProgress: json['in_progress'] ?? false,
      lastSync: json['last_sync'] != null 
          ? DateTime.parse(json['last_sync'])
          : null,
      pendingUploads: json['pending_uploads'] ?? 0,
      pendingDownloads: json['pending_downloads'] ?? 0,
      syncErrors: List<String>.from(json['sync_errors'] ?? []),
      totalSynced: json['total_synced'] ?? 0,
      nextSyncAt: json['next_sync_at'] != null
          ? DateTime.parse(json['next_sync_at'])
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'in_progress': inProgress,
      'last_sync': lastSync?.toIso8601String(),
      'pending_uploads': pendingUploads,
      'pending_downloads': pendingDownloads,
      'sync_errors': syncErrors,
      'total_synced': totalSynced,
      'next_sync_at': nextSyncAt?.toIso8601String(),
    };
  }
  
  /// Check if sync is healthy
  bool get isHealthy => enabled && syncErrors.isEmpty;
  
  /// Check if sync is needed
  bool get needsSync => pendingUploads > 0 || pendingDownloads > 0;
  
  @override
  String toString() {
    return 'CommandHistorySyncStatus{enabled: $enabled, inProgress: $inProgress, needsSync: $needsSync}';
  }
}