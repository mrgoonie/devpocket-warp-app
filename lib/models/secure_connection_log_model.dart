import 'ssh_security_enums.dart';

/// Enhanced connection log with security auditing
class SecureConnectionLog {
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
  final String sourceIP;
  final String? userAgent;
  final AuthMethod authMethod;
  final SecurityLevel securityLevel;
  final List<String> securityWarnings;
  final Map<String, dynamic> securityMetadata;

  const SecureConnectionLog({
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
    required this.sourceIP,
    this.userAgent,
    required this.authMethod,
    required this.securityLevel,
    this.securityWarnings = const [],
    this.securityMetadata = const {},
  });

  factory SecureConnectionLog.fromJson(Map<String, dynamic> json) {
    return SecureConnectionLog(
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
      sourceIP: json['source_ip'],
      userAgent: json['user_agent'],
      authMethod: AuthMethod.values.firstWhere(
        (e) => e.name == json['auth_method'],
        orElse: () => AuthMethod.password,
      ),
      securityLevel: SecurityLevel.values.firstWhere(
        (e) => e.name == json['security_level'],
        orElse: () => SecurityLevel.medium,
      ),
      securityWarnings: List<String>.from(json['security_warnings'] ?? []),
      securityMetadata: Map<String, dynamic>.from(json['security_metadata'] ?? {}),
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
      'source_ip': sourceIP,
      'user_agent': userAgent,
      'auth_method': authMethod.name,
      'security_level': securityLevel.name,
      'security_warnings': securityWarnings,
      'security_metadata': securityMetadata,
    };
  }

  bool get hasSecurityWarnings => securityWarnings.isNotEmpty;
  bool get isHighRisk => securityLevel == SecurityLevel.low && !success;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecureConnectionLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SecureConnectionLog{id: $id, hostname: $hostname, success: $success, security: ${securityLevel.name}}';
  }
}