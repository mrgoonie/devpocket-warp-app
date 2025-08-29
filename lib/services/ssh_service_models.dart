import '../models/enhanced_ssh_models.dart';

/// SSH command execution result
class SSHCommandResult {
  final String command;
  final String stdout;
  final String stderr;
  final int? exitCode;
  final Duration duration;
  final DateTime timestamp;

  const SSHCommandResult({
    required this.command,
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.duration,
    required this.timestamp,
  });

  bool get success => exitCode == 0;
  String get output => stdout + stderr;
}

/// SSH security events
class SecurityEvent {
  final String type;
  final String hostId;
  final String hostname;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const SecurityEvent({
    required this.type,
    required this.hostId,
    required this.hostname,
    required this.timestamp,
    this.data = const {},
  });

  factory SecurityEvent.connectionEstablished({
    required String hostId,
    required String hostname,
    required SecurityLevel securityLevel,
  }) {
    return SecurityEvent(
      type: 'connection_established',
      hostId: hostId,
      hostname: hostname,
      timestamp: DateTime.now(),
      data: {'security_level': securityLevel.name},
    );
  }

  factory SecurityEvent.connectionFailed({
    required String hostId,
    required String hostname,
    required String error,
  }) {
    return SecurityEvent(
      type: 'connection_failed',
      hostId: hostId,
      hostname: hostname,
      timestamp: DateTime.now(),
      data: {'error': error},
    );
  }

  factory SecurityEvent.connectionClosed({
    required String hostId,
    required String hostname,
  }) {
    return SecurityEvent(
      type: 'connection_closed',
      hostId: hostId,
      hostname: hostname,
      timestamp: DateTime.now(),
    );
  }

  factory SecurityEvent.hostKeyChanged({
    required String hostId,
    required String hostname,
    required String expectedFingerprint,
    required String actualFingerprint,
  }) {
    return SecurityEvent(
      type: 'host_key_changed',
      hostId: hostId,
      hostname: hostname,
      timestamp: DateTime.now(),
      data: {
        'expected_fingerprint': expectedFingerprint,
        'actual_fingerprint': actualFingerprint,
      },
    );
  }
}

/// SSH-related exceptions
class SSHException implements Exception {
  final String message;
  final Object? cause;

  const SSHException(this.message, [this.cause]);

  @override
  String toString() => 'SSHException: $message';
}

class SSHSecurityException extends SSHException {
  const SSHSecurityException(super.message, [super.cause]);

  @override
  String toString() => 'SSHSecurityException: $message';
}