import '../models/enhanced_ssh_models.dart';
import 'audit_enums.dart';

/// Audit event model for comprehensive logging
class AuditEvent {
  final AuditEventType type;
  final DateTime timestamp;
  final String? hostId;
  final String? hostname;
  final String? username;
  final String? command;
  final bool success;
  final AuthMethod? authMethod;
  final SecurityLevel? securityLevel;
  final String? sourceIP;
  final Map<String, dynamic> data;

  const AuditEvent({
    required this.type,
    required this.timestamp,
    this.hostId,
    this.hostname,
    this.username,
    this.command,
    required this.success,
    this.authMethod,
    this.securityLevel,
    this.sourceIP,
    this.data = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'host_id': hostId,
      'hostname': hostname,
      'username': username,
      'command': command,
      'success': success,
      'auth_method': authMethod?.name,
      'security_level': securityLevel?.name,
      'source_ip': sourceIP,
      'data': data,
    };
  }

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      type: AuditEventType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => AuditEventType.systemEvent,
      ),
      timestamp: DateTime.parse(json['timestamp']),
      hostId: json['host_id'],
      hostname: json['hostname'],
      username: json['username'],
      command: json['command'],
      success: json['success'],
      authMethod: json['auth_method'] != null
          ? AuthMethod.values.firstWhere(
              (e) => e.name == json['auth_method'],
              orElse: () => AuthMethod.password,
            )
          : null,
      securityLevel: json['security_level'] != null
          ? SecurityLevel.values.firstWhere(
              (e) => e.name == json['security_level'],
              orElse: () => SecurityLevel.medium,
            )
          : null,
      sourceIP: json['source_ip'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

/// Audit statistics for compliance reporting
class AuditStatistics {
  final int totalEvents;
  final int connectionAttempts;
  final int successfulConnections;
  final int commandExecutions;
  final int securityWarnings;
  final int fileTransfers;
  final int keyOperations;
  final Map<String, int> eventsByType;
  final Map<String, int> eventsBySecurityLevel;
  final TimeRange? timeRange;

  const AuditStatistics({
    required this.totalEvents,
    required this.connectionAttempts,
    required this.successfulConnections,
    required this.commandExecutions,
    required this.securityWarnings,
    required this.fileTransfers,
    required this.keyOperations,
    required this.eventsByType,
    required this.eventsBySecurityLevel,
    this.timeRange,
  });

  double get successRate => connectionAttempts > 0
      ? successfulConnections / connectionAttempts
      : 0.0;

  double get securityWarningRate => totalEvents > 0
      ? securityWarnings / totalEvents
      : 0.0;
}

/// Time range for audit statistics
class TimeRange {
  final DateTime start;
  final DateTime end;

  const TimeRange({
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);
}