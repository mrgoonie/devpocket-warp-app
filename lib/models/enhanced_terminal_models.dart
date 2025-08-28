import 'package:flutter/foundation.dart';

import '../widgets/terminal/terminal_block.dart';

/// Enhanced terminal block data model with additional features
@immutable
class EnhancedTerminalBlockData extends TerminalBlockData {
  final String sessionId;
  final bool isAgentCommand;
  final bool requiresFullscreenModal;
  final String? encodingFormat; // utf-8, utf-16, etc.
  final List<String> environmentVariables;
  final String? workingDirectory;
  final Map<String, dynamic> metadata;
  final List<EnhancedTerminalBlockError> errors;
  final double? executionTime; // in seconds
  @override
  final int? exitCode;
  final String? interruptSignal;

  EnhancedTerminalBlockData({
    required super.id,
    required super.command,
    required super.status,
    required super.timestamp,
    super.output,
    super.isInteractive,
    required super.index,
    this.exitCode,
    super.duration,
    super.errorMessage,
    required this.sessionId,
    this.isAgentCommand = false,
    this.requiresFullscreenModal = false,
    this.encodingFormat,
    this.environmentVariables = const [],
    this.workingDirectory,
    this.metadata = const {},
    this.errors = const [],
    this.executionTime,
    this.interruptSignal,
  }) : super(
         exitCode: exitCode,
       );

  /// Create from base TerminalBlockData
  EnhancedTerminalBlockData.fromBase(
    TerminalBlockData base, {
    required this.sessionId,
    this.isAgentCommand = false,
    this.requiresFullscreenModal = false,
    this.encodingFormat,
    this.environmentVariables = const [],
    this.workingDirectory,
    this.metadata = const {},
    this.errors = const [],
    this.executionTime,
    this.exitCode,
    this.interruptSignal,
  }) : super(
         id: base.id,
         command: base.command,
         status: base.status,
         timestamp: base.timestamp,
         output: base.output,
         isInteractive: base.isInteractive,
         index: base.index,
         exitCode: base.exitCode,
         duration: base.duration,
         errorMessage: base.errorMessage,
       );

  @override
  EnhancedTerminalBlockData copyWith({
    String? id,
    String? command,
    TerminalBlockStatus? status,
    DateTime? timestamp,
    String? output,
    bool? isInteractive,
    int? index,
    int? exitCode,
    Duration? duration,
    String? errorMessage,
    String? sessionId,
    bool? isAgentCommand,
    bool? requiresFullscreenModal,
    String? encodingFormat,
    List<String>? environmentVariables,
    String? workingDirectory,
    Map<String, dynamic>? metadata,
    List<EnhancedTerminalBlockError>? errors,
    double? executionTime,
    String? interruptSignal,
  }) {
    return EnhancedTerminalBlockData(
      id: id ?? this.id,
      command: command ?? this.command,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      output: output ?? this.output,
      isInteractive: isInteractive ?? this.isInteractive,
      index: index ?? this.index,
      exitCode: exitCode ?? this.exitCode,
      duration: duration ?? super.duration,
      errorMessage: errorMessage ?? super.errorMessage,
      sessionId: sessionId ?? this.sessionId,
      isAgentCommand: isAgentCommand ?? this.isAgentCommand,
      requiresFullscreenModal: requiresFullscreenModal ?? this.requiresFullscreenModal,
      encodingFormat: encodingFormat ?? this.encodingFormat,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      workingDirectory: workingDirectory ?? this.workingDirectory,
      metadata: metadata ?? this.metadata,
      errors: errors ?? this.errors,
      executionTime: executionTime ?? this.executionTime,
      interruptSignal: interruptSignal ?? this.interruptSignal,
    );
  }

  /// Check if block has errors
  bool get hasErrors => errors.isNotEmpty;

  /// Check if block execution was successful
  bool get wasSuccessful => status == TerminalBlockStatus.completed && (exitCode == null || exitCode == 0);

  /// Get formatted execution time
  String? get formattedExecutionTime {
    if (executionTime == null) return null;
    if (executionTime! < 1) return '${(executionTime! * 1000).toStringAsFixed(0)}ms';
    return '${executionTime!.toStringAsFixed(2)}s';
  }

  /// Check if block requires special text encoding handling
  bool get requiresEncodingConversion => encodingFormat != null && encodingFormat != 'utf-8';

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': command,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'output': output,
      'isInteractive': isInteractive,
      'index': index,
      'sessionId': sessionId,
      'isAgentCommand': isAgentCommand,
      'requiresFullscreenModal': requiresFullscreenModal,
      'encodingFormat': encodingFormat,
      'environmentVariables': environmentVariables,
      'workingDirectory': workingDirectory,
      'metadata': metadata,
      'errors': errors.map((e) => e.toJson()).toList(),
      'executionTime': executionTime,
      'exitCode': exitCode,
      'interruptSignal': interruptSignal,
    };
  }

  /// Create from JSON
  factory EnhancedTerminalBlockData.fromJson(Map<String, dynamic> json) {
    return EnhancedTerminalBlockData(
      id: json['id'],
      command: json['command'],
      status: TerminalBlockStatus.values.firstWhere((e) => e.name == json['status']),
      timestamp: DateTime.parse(json['timestamp']),
      output: json['output'] ?? '',
      isInteractive: json['isInteractive'] ?? false,
      index: json['index'],
      sessionId: json['sessionId'],
      isAgentCommand: json['isAgentCommand'] ?? false,
      requiresFullscreenModal: json['requiresFullscreenModal'] ?? false,
      encodingFormat: json['encodingFormat'],
      environmentVariables: List<String>.from(json['environmentVariables'] ?? []),
      workingDirectory: json['workingDirectory'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      errors: (json['errors'] as List?)
          ?.map((e) => EnhancedTerminalBlockError.fromJson(e))
          .toList() ?? [],
      executionTime: json['executionTime']?.toDouble(),
      exitCode: json['exitCode'],
      interruptSignal: json['interruptSignal'],
    );
  }
}

/// Error model for terminal blocks
@immutable
class EnhancedTerminalBlockError {
  final String type;
  final String message;
  final String? code;
  final DateTime timestamp;
  final Map<String, dynamic> context;

  const EnhancedTerminalBlockError({
    required this.type,
    required this.message,
    this.code,
    required this.timestamp,
    this.context = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'code': code,
      'timestamp': timestamp.toIso8601String(),
      'context': context,
    };
  }

  factory EnhancedTerminalBlockError.fromJson(Map<String, dynamic> json) {
    return EnhancedTerminalBlockError(
      type: json['type'],
      message: json['message'],
      code: json['code'],
      timestamp: DateTime.parse(json['timestamp']),
      context: Map<String, dynamic>.from(json['context'] ?? {}),
    );
  }
}

/// Interactive command session model for fullscreen modal
class InteractiveCommandSession {
  final String id;
  final String sessionId;
  final String blockId;
  final String command;
  final DateTime startTime;
  final InteractiveSessionType type;
  final Map<String, dynamic> configuration;
  final List<String> keyBindings;
  
  DateTime? endTime;
  InteractiveSessionStatus status;
  String? exitReason;
  Map<String, dynamic> state;

  InteractiveCommandSession({
    required this.id,
    required this.sessionId,
    required this.blockId,
    required this.command,
    required this.startTime,
    required this.type,
    this.configuration = const {},
    this.keyBindings = const [],
    this.endTime,
    this.status = InteractiveSessionStatus.starting,
    this.exitReason,
    this.state = const {},
  });

  /// Check if session is active
  bool get isActive => status == InteractiveSessionStatus.active;

  /// Check if session is finished
  bool get isFinished => status == InteractiveSessionStatus.completed || 
                         status == InteractiveSessionStatus.cancelled ||
                         status == InteractiveSessionStatus.error;

  /// Get session duration
  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Update session state
  InteractiveCommandSession copyWith({
    DateTime? endTime,
    InteractiveSessionStatus? status,
    String? exitReason,
    Map<String, dynamic>? state,
  }) {
    return InteractiveCommandSession(
      id: id,
      sessionId: sessionId,
      blockId: blockId,
      command: command,
      startTime: startTime,
      type: type,
      configuration: configuration,
      keyBindings: keyBindings,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      exitReason: exitReason ?? this.exitReason,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'blockId': blockId,
      'command': command,
      'startTime': startTime.toIso8601String(),
      'type': type.name,
      'configuration': configuration,
      'keyBindings': keyBindings,
      'endTime': endTime?.toIso8601String(),
      'status': status.name,
      'exitReason': exitReason,
      'state': state,
    };
  }
}

/// Interactive session types
enum InteractiveSessionType {
  editor, // vi, vim, nano, emacs
  monitor, // top, htop, btop
  pager, // less, more, man
  watcher, // watch, tail -f
  multiplexer, // tmux, screen
  other,
}

/// Interactive session status
enum InteractiveSessionStatus {
  starting,
  active,
  paused,
  completed,
  cancelled,
  error,
}

/// Terminal session state model with enhanced features
@immutable
class EnhancedTerminalSessionState {
  final String sessionId;
  final bool isAiMode;
  final ScrollPosition? scrollPosition;
  final List<String> commandHistory;
  final int? historyIndex;
  final Map<String, dynamic> preferences;
  final DateTime lastActivity;
  final List<String> activeSessions;
  final String? currentInteractiveSession;
  final Map<String, String> environmentVariables;
  final String workingDirectory;

  const EnhancedTerminalSessionState({
    required this.sessionId,
    this.isAiMode = false,
    this.scrollPosition,
    this.commandHistory = const [],
    this.historyIndex,
    this.preferences = const {},
    required this.lastActivity,
    this.activeSessions = const [],
    this.currentInteractiveSession,
    this.environmentVariables = const {},
    this.workingDirectory = '/',
  });

  EnhancedTerminalSessionState copyWith({
    String? sessionId,
    bool? isAiMode,
    ScrollPosition? scrollPosition,
    List<String>? commandHistory,
    int? historyIndex,
    Map<String, dynamic>? preferences,
    DateTime? lastActivity,
    List<String>? activeSessions,
    String? currentInteractiveSession,
    Map<String, String>? environmentVariables,
    String? workingDirectory,
  }) {
    return EnhancedTerminalSessionState(
      sessionId: sessionId ?? this.sessionId,
      isAiMode: isAiMode ?? this.isAiMode,
      scrollPosition: scrollPosition ?? this.scrollPosition,
      commandHistory: commandHistory ?? this.commandHistory,
      historyIndex: historyIndex ?? this.historyIndex,
      preferences: preferences ?? this.preferences,
      lastActivity: lastActivity ?? this.lastActivity,
      activeSessions: activeSessions ?? this.activeSessions,
      currentInteractiveSession: currentInteractiveSession ?? this.currentInteractiveSession,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      workingDirectory: workingDirectory ?? this.workingDirectory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'isAiMode': isAiMode,
      'commandHistory': commandHistory,
      'historyIndex': historyIndex,
      'preferences': preferences,
      'lastActivity': lastActivity.toIso8601String(),
      'activeSessions': activeSessions,
      'currentInteractiveSession': currentInteractiveSession,
      'environmentVariables': environmentVariables,
      'workingDirectory': workingDirectory,
    };
  }

  factory EnhancedTerminalSessionState.fromJson(Map<String, dynamic> json) {
    return EnhancedTerminalSessionState(
      sessionId: json['sessionId'],
      isAiMode: json['isAiMode'] ?? false,
      commandHistory: List<String>.from(json['commandHistory'] ?? []),
      historyIndex: json['historyIndex'],
      preferences: Map<String, dynamic>.from(json['preferences'] ?? {}),
      lastActivity: DateTime.parse(json['lastActivity']),
      activeSessions: List<String>.from(json['activeSessions'] ?? []),
      currentInteractiveSession: json['currentInteractiveSession'],
      environmentVariables: Map<String, String>.from(json['environmentVariables'] ?? {}),
      workingDirectory: json['workingDirectory'] ?? '/',
    );
  }
}

/// Scroll position data
class ScrollPosition {
  final double pixels;
  final double maxScrollExtent;
  final double minScrollExtent;

  const ScrollPosition({
    required this.pixels,
    required this.maxScrollExtent,
    required this.minScrollExtent,
  });

  bool get isAtBottom => pixels >= maxScrollExtent - 10; // 10px tolerance
  bool get isAtTop => pixels <= minScrollExtent + 10; // 10px tolerance

  Map<String, dynamic> toJson() {
    return {
      'pixels': pixels,
      'maxScrollExtent': maxScrollExtent,
      'minScrollExtent': minScrollExtent,
    };
  }

  factory ScrollPosition.fromJson(Map<String, dynamic> json) {
    return ScrollPosition(
      pixels: json['pixels']?.toDouble() ?? 0.0,
      maxScrollExtent: json['maxScrollExtent']?.toDouble() ?? 0.0,
      minScrollExtent: json['minScrollExtent']?.toDouble() ?? 0.0,
    );
  }
}