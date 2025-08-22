import 'package:uuid/uuid.dart';

/// SSH profile authentication types as per API documentation
enum SshAuthType {
  password('password'),
  key('key'),
  keyWithPassphrase('keyWithPassphrase');
  
  const SshAuthType(this.value);
  final String value;
  
  static SshAuthType fromString(String value) {
    return SshAuthType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SshAuthType.password,
    );
  }
}

/// SSH profile status
enum SshProfileStatus {
  unknown,
  active,
  testing,
  failed,
  disabled,
}

/// SSH profile model matching API specification
class SshProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final SshAuthType authType;
  final String? password; // Encrypted
  final String? privateKey; // Encrypted
  final String? passphrase; // Encrypted
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final SshProfileStatus status;
  final String? description;
  final List<String> tags;
  final String? color;
  final bool isDefault;
  
  const SshProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    required this.authType,
    this.password,
    this.privateKey,
    this.passphrase,
    required this.createdAt,
    required this.updatedAt,
    this.lastConnectedAt,
    this.status = SshProfileStatus.unknown,
    this.description,
    this.tags = const [],
    this.color,
    this.isDefault = false,
  });
  
  SshProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    SshAuthType? authType,
    String? password,
    String? privateKey,
    String? passphrase,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    SshProfileStatus? status,
    String? description,
    List<String>? tags,
    String? color,
    bool? isDefault,
  }) {
    return SshProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authType: authType ?? this.authType,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      status: status ?? this.status,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
    );
  }
  
  factory SshProfile.fromJson(Map<String, dynamic> json) {
    return SshProfile(
      id: json['id'],
      name: json['name'],
      host: json['host'],
      port: json['port'] ?? 22,
      username: json['username'],
      authType: SshAuthType.fromString(json['authType'] ?? 'password'),
      password: json['password'],
      privateKey: json['privateKey'],
      passphrase: json['passphrase'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'])
          : null,
      status: SshProfileStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SshProfileStatus.unknown,
      ),
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      color: json['color'],
      isDefault: json['isDefault'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.value,
      if (password != null) 'password': password,
      if (privateKey != null) 'privateKey': privateKey,
      if (passphrase != null) 'passphrase': passphrase,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (lastConnectedAt != null) 'lastConnectedAt': lastConnectedAt!.toIso8601String(),
      'status': status.name,
      if (description != null) 'description': description,
      'tags': tags,
      if (color != null) 'color': color,
      'isDefault': isDefault,
    };
  }
  
  /// Create JSON for API requests (excludes client-only fields)
  Map<String, dynamic> toApiJson() {
    return {
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'authType': authType.value,
      if (password != null) 'password': password,
      if (privateKey != null) 'privateKey': privateKey,
      if (passphrase != null) 'passphrase': passphrase,
      if (description != null) 'description': description,
    };
  }
  
  String get connectionString => '$username@$host:$port';
  
  bool get requiresPassword => authType == SshAuthType.password;
  bool get requiresPrivateKey => authType == SshAuthType.key || authType == SshAuthType.keyWithPassphrase;
  bool get requiresPassphrase => authType == SshAuthType.keyWithPassphrase;
  
  bool get isActive => status == SshProfileStatus.active;
  bool get isTesting => status == SshProfileStatus.testing;
  bool get hasFailed => status == SshProfileStatus.failed;
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SshProfile && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'SshProfile{id: $id, name: $name, host: $host, username: $username, authType: ${authType.value}}';
  }
}

/// SSH connection test result
class SshConnectionTestResult {
  final bool success;
  final String? error;
  final Duration? responseTime;
  final DateTime timestamp;
  final String? message;
  
  const SshConnectionTestResult({
    required this.success,
    this.error,
    this.responseTime,
    required this.timestamp,
    this.message,
  });
  
  factory SshConnectionTestResult.fromJson(Map<String, dynamic> json) {
    return SshConnectionTestResult(
      success: json['success'] ?? false,
      error: json['error'],
      responseTime: json['responseTime'] != null 
          ? Duration(milliseconds: json['responseTime'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (error != null) 'error': error,
      if (responseTime != null) 'responseTime': responseTime!.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      if (message != null) 'message': message,
    };
  }
  
  @override
  String toString() {
    return 'SshConnectionTestResult{success: $success, error: $error, responseTime: $responseTime}';
  }
}

/// SSH key validation result
class SshKeyValidationResult {
  final bool isValid;
  final String? error;
  final String? keyType;
  final int? keySize;
  final String? fingerprint;
  
  const SshKeyValidationResult({
    required this.isValid,
    this.error,
    this.keyType,
    this.keySize,
    this.fingerprint,
  });
  
  factory SshKeyValidationResult.fromJson(Map<String, dynamic> json) {
    return SshKeyValidationResult(
      isValid: json['isValid'] ?? false,
      error: json['error'],
      keyType: json['keyType'],
      keySize: json['keySize'],
      fingerprint: json['fingerprint'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'isValid': isValid,
      if (error != null) 'error': error,
      if (keyType != null) 'keyType': keyType,
      if (keySize != null) 'keySize': keySize,
      if (fingerprint != null) 'fingerprint': fingerprint,
    };
  }
  
  @override
  String toString() {
    return 'SshKeyValidationResult{isValid: $isValid, keyType: $keyType, fingerprint: $fingerprint}';
  }
}

/// Terminal session model
class TerminalSession {
  final String id;
  final String type; // 'local' or 'ssh'
  final String? sshProfileId;
  final String? shell;
  final String status;
  final DateTime createdAt;
  final DateTime lastActivity;
  
  const TerminalSession({
    required this.id,
    required this.type,
    this.sshProfileId,
    this.shell,
    required this.status,
    required this.createdAt,
    required this.lastActivity,
  });
  
  factory TerminalSession.fromJson(Map<String, dynamic> json) {
    return TerminalSession(
      id: json['id'],
      type: json['type'],
      sshProfileId: json['sshProfileId'],
      shell: json['shell'],
      status: json['status'],
      createdAt: DateTime.parse(json['createdAt']),
      lastActivity: DateTime.parse(json['lastActivity']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      if (sshProfileId != null) 'sshProfileId': sshProfileId,
      if (shell != null) 'shell': shell,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'lastActivity': lastActivity.toIso8601String(),
    };
  }
  
  bool get isLocal => type == 'local';
  bool get isSsh => type == 'ssh';
  bool get isActive => status == 'active';
  
  @override
  String toString() {
    return 'TerminalSession{id: $id, type: $type, status: $status}';
  }
}

/// Terminal session creation request
class CreateTerminalSessionRequest {
  final String type;
  final String? sshProfileId;
  final String? shell;
  
  const CreateTerminalSessionRequest({
    required this.type,
    this.sshProfileId,
    this.shell,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (sshProfileId != null) 'sshProfileId': sshProfileId,
      if (shell != null) 'shell': shell,
    };
  }
  
  factory CreateTerminalSessionRequest.local({String shell = '/bin/bash'}) {
    return CreateTerminalSessionRequest(
      type: 'local',
      shell: shell,
    );
  }
  
  factory CreateTerminalSessionRequest.ssh({required String sshProfileId}) {
    return CreateTerminalSessionRequest(
      type: 'ssh',
      sshProfileId: sshProfileId,
    );
  }
}

/// Terminal usage statistics
class TerminalStats {
  final int totalSessions;
  final int activeSessions;
  final int totalCommands;
  final Duration totalUsageTime;
  final List<String> topCommands;
  final Map<String, int> sessionsByType;
  
  const TerminalStats({
    required this.totalSessions,
    required this.activeSessions,
    required this.totalCommands,
    required this.totalUsageTime,
    required this.topCommands,
    required this.sessionsByType,
  });
  
  factory TerminalStats.fromJson(Map<String, dynamic> json) {
    return TerminalStats(
      totalSessions: json['totalSessions'] ?? 0,
      activeSessions: json['activeSessions'] ?? 0,
      totalCommands: json['totalCommands'] ?? 0,
      totalUsageTime: Duration(milliseconds: json['totalUsageTime'] ?? 0),
      topCommands: List<String>.from(json['topCommands'] ?? []),
      sessionsByType: Map<String, int>.from(json['sessionsByType'] ?? {}),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'activeSessions': activeSessions,
      'totalCommands': totalCommands,
      'totalUsageTime': totalUsageTime.inMilliseconds,
      'topCommands': topCommands,
      'sessionsByType': sessionsByType,
    };
  }
  
  @override
  String toString() {
    return 'TerminalStats{totalSessions: $totalSessions, activeSessions: $activeSessions, totalCommands: $totalCommands}';
  }
}

/// Factory for creating SSH profiles
class SshProfileFactory {
  static const Uuid _uuid = Uuid();
  
  static SshProfile create({
    required String name,
    required String host,
    required String username,
    int port = 22,
    SshAuthType authType = SshAuthType.password,
    String? description,
    List<String> tags = const [],
    String? color,
  }) {
    final now = DateTime.now();
    return SshProfile(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      username: username,
      authType: authType,
      createdAt: now,
      updatedAt: now,
      description: description,
      tags: tags,
      color: color,
    );
  }
}