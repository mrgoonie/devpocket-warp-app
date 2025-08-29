import 'persistent_process_detector.dart' show ProcessInfo;

/// Events emitted by the ActiveBlockManager
enum ActiveBlockEventType {
  blockActivated,
  blockDeactivated,
  blockTerminated,
  processOutput,
  processError,
  focusChanged,
}

/// Event model for active block changes
class ActiveBlockEvent {
  final ActiveBlockEventType type;
  final String? blockId;
  final String? sessionId;
  final String? message;
  final dynamic data;
  final DateTime timestamp;

  const ActiveBlockEvent({
    required this.type,
    this.blockId,
    this.sessionId,
    this.message,
    this.data,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ActiveBlockEvent{type: $type, blockId: $blockId, message: $message}';
  }
}

/// Block state information for tracking and management
class BlockState {
  final String blockId;
  final String sessionId;
  final String command;
  final ProcessInfo processInfo;
  final DateTime createdAt;
  final bool isActive;
  final bool isRunning;
  final bool isFocused;
  final int? exitCode;
  final DateTime? terminatedAt;

  const BlockState({
    required this.blockId,
    required this.sessionId,
    required this.command,
    required this.processInfo,
    required this.createdAt,
    required this.isActive,
    required this.isRunning,
    required this.isFocused,
    this.exitCode,
    this.terminatedAt,
  });

  /// Get process uptime
  Duration get uptime {
    final end = terminatedAt ?? DateTime.now();
    return end.difference(createdAt);
  }

  /// Create a copy with updated fields
  BlockState copyWith({
    String? blockId,
    String? sessionId,
    String? command,
    ProcessInfo? processInfo,
    DateTime? createdAt,
    bool? isActive,
    bool? isRunning,
    bool? isFocused,
    int? exitCode,
    DateTime? terminatedAt,
  }) {
    return BlockState(
      blockId: blockId ?? this.blockId,
      sessionId: sessionId ?? this.sessionId,
      command: command ?? this.command,
      processInfo: processInfo ?? this.processInfo,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      isRunning: isRunning ?? this.isRunning,
      isFocused: isFocused ?? this.isFocused,
      exitCode: exitCode ?? this.exitCode,
      terminatedAt: terminatedAt ?? this.terminatedAt,
    );
  }

  @override
  String toString() {
    return 'BlockState{blockId: $blockId, command: $command, type: ${processInfo.type}, active: $isActive, running: $isRunning}';
  }
}