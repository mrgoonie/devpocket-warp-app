import 'package:uuid/uuid.dart';

/// Basic connection log for SSH session tracking
class ConnectionLog {
  final String id;
  final String hostId;
  final String hostname;
  final String username;
  final DateTime timestamp;
  final Duration? duration;
  final bool success;
  final String? error;
  final String? message;
  final int commandCount;
  final String? lastCommand;

  const ConnectionLog({
    required this.id,
    required this.hostId,
    required this.hostname,
    required this.username,
    required this.timestamp,
    this.duration,
    required this.success,
    this.error,
    this.message,
    this.commandCount = 0,
    this.lastCommand,
  });

  ConnectionLog copyWith({
    String? id,
    String? hostId,
    String? hostname,
    String? username,
    DateTime? timestamp,
    Duration? duration,
    bool? success,
    String? error,
    String? message,
    int? commandCount,
    String? lastCommand,
  }) {
    return ConnectionLog(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostname: hostname ?? this.hostname,
      username: username ?? this.username,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      success: success ?? this.success,
      error: error ?? this.error,
      message: message ?? this.message,
      commandCount: commandCount ?? this.commandCount,
      lastCommand: lastCommand ?? this.lastCommand,
    );
  }

  factory ConnectionLog.fromJson(Map<String, dynamic> json) {
    return ConnectionLog(
      id: json['id'],
      hostId: json['host_id'],
      hostname: json['hostname'],
      username: json['username'],
      timestamp: DateTime.parse(json['timestamp']),
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'])
          : null,
      success: json['success'],
      error: json['error'],
      message: json['message'],
      commandCount: json['command_count'] ?? 0,
      lastCommand: json['last_command'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'hostname': hostname,
      'username': username,
      'timestamp': timestamp.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'success': success,
      'error': error,
      'message': message,
      'command_count': commandCount,
      'last_command': lastCommand,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ConnectionLog{id: $id, hostname: $hostname, success: $success}';
  }
}

/// Factory for creating ConnectionLog instances
class ConnectionLogFactory {
  static const Uuid _uuid = Uuid();

  static ConnectionLog create({
    required String hostId,
    required String hostname,
    required String username,
    required bool success,
    String? error,
    String? message,
    Duration? duration,
    int commandCount = 0,
    String? lastCommand,
  }) {
    return ConnectionLog(
      id: _uuid.v4(),
      hostId: hostId,
      hostname: hostname,
      username: username,
      timestamp: DateTime.now(),
      success: success,
      error: error,
      message: message,
      duration: duration,
      commandCount: commandCount,
      lastCommand: lastCommand,
    );
  }
}