import 'package:uuid/uuid.dart';

enum HostStatus {
  unknown,
  online,
  offline,
  connecting,
  error,
}

enum AuthMethod {
  password,
  publicKey,
  keyboardInteractive,
}

class Host {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  final String? password;
  final String? privateKeyPath;
  final String? privateKey;
  final String? passphrase;
  final AuthMethod authMethod;
  final bool useCompression;
  final int keepAliveInterval;
  final int connectionTimeout;
  final String? jumpHost;
  final Map<String, String> environmentVariables;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final HostStatus status;
  final String? description;
  final List<String> tags;
  final String? color;

  const Host({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKeyPath,
    this.privateKey,
    this.passphrase,
    this.authMethod = AuthMethod.password,
    this.useCompression = true,
    this.keepAliveInterval = 30,
    this.connectionTimeout = 10,
    this.jumpHost,
    this.environmentVariables = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastConnectedAt,
    this.status = HostStatus.unknown,
    this.description,
    this.tags = const [],
    this.color,
  });

  Host copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? username,
    String? password,
    String? privateKeyPath,
    String? privateKey,
    String? passphrase,
    AuthMethod? authMethod,
    bool? useCompression,
    int? keepAliveInterval,
    int? connectionTimeout,
    String? jumpHost,
    Map<String, String>? environmentVariables,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    HostStatus? status,
    String? description,
    List<String>? tags,
    String? color,
  }) {
    return Host(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      authMethod: authMethod ?? this.authMethod,
      useCompression: useCompression ?? this.useCompression,
      keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      jumpHost: jumpHost ?? this.jumpHost,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      status: status ?? this.status,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      color: color ?? this.color,
    );
  }

  factory Host.fromJson(Map<String, dynamic> json) {
    return Host(
      id: json['id'],
      name: json['name'],
      hostname: json['hostname'],
      port: json['port'] ?? 22,
      username: json['username'],
      password: json['password'],
      privateKeyPath: json['private_key_path'],
      privateKey: json['private_key'],
      passphrase: json['passphrase'],
      authMethod: AuthMethod.values.firstWhere(
        (e) => e.name == json['auth_method'],
        orElse: () => AuthMethod.password,
      ),
      useCompression: json['use_compression'] ?? true,
      keepAliveInterval: json['keep_alive_interval'] ?? 30,
      connectionTimeout: json['connection_timeout'] ?? 10,
      jumpHost: json['jump_host'],
      environmentVariables: Map<String, String>.from(json['environment_variables'] ?? {}),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      lastConnectedAt: json['last_connected_at'] != null
          ? DateTime.parse(json['last_connected_at'])
          : null,
      status: HostStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => HostStatus.unknown,
      ),
      description: json['description'],
      tags: List<String>.from(json['tags'] ?? []),
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
      'password': password,
      'private_key_path': privateKeyPath,
      'private_key': privateKey,
      'passphrase': passphrase,
      'auth_method': authMethod.name,
      'use_compression': useCompression,
      'keep_alive_interval': keepAliveInterval,
      'connection_timeout': connectionTimeout,
      'jump_host': jumpHost,
      'environment_variables': environmentVariables,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_connected_at': lastConnectedAt?.toIso8601String(),
      'status': status.name,
      'description': description,
      'tags': tags,
      'color': color,
    };
  }

  String get connectionString => '$username@$hostname:$port';

  bool get isOnline => status == HostStatus.online;
  bool get isConnecting => status == HostStatus.connecting;
  bool get hasError => status == HostStatus.error;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Host && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Host{id: $id, name: $name, hostname: $hostname, username: $username}';
  }
}

class SSHKey {
  final String id;
  final String name;
  final String type; // rsa, ed25519, ecdsa
  final String publicKey;
  final String? privateKey;
  final String? passphrase;
  final int? keySize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final List<String> hostIds; // Associated host IDs

  const SSHKey({
    required this.id,
    required this.name,
    required this.type,
    required this.publicKey,
    this.privateKey,
    this.passphrase,
    this.keySize,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.hostIds = const [],
  });

  SSHKey copyWith({
    String? id,
    String? name,
    String? type,
    String? publicKey,
    String? privateKey,
    String? passphrase,
    int? keySize,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    List<String>? hostIds,
  }) {
    return SSHKey(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      passphrase: passphrase ?? this.passphrase,
      keySize: keySize ?? this.keySize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      hostIds: hostIds ?? this.hostIds,
    );
  }

  factory SSHKey.fromJson(Map<String, dynamic> json) {
    return SSHKey(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      publicKey: json['public_key'],
      privateKey: json['private_key'],
      passphrase: json['passphrase'],
      keySize: json['key_size'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      description: json['description'],
      hostIds: List<String>.from(json['host_ids'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'public_key': publicKey,
      'private_key': privateKey,
      'passphrase': passphrase,
      'key_size': keySize,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'description': description,
      'host_ids': hostIds,
    };
  }

  String get displayType => type.toUpperCase();

  bool get hasPassphrase => passphrase != null && passphrase!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SSHKey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SSHKey{id: $id, name: $name, type: $type}';
  }
}

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

// Factory methods for creating new instances
class HostFactory {
  static const Uuid _uuid = Uuid();

  static Host create({
    required String name,
    required String hostname,
    required String username,
    int port = 22,
    String? password,
    AuthMethod authMethod = AuthMethod.password,
    String? description,
    List<String> tags = const [],
    String? color,
  }) {
    final now = DateTime.now();
    return Host(
      id: _uuid.v4(),
      name: name,
      hostname: hostname,
      port: port,
      username: username,
      password: password,
      authMethod: authMethod,
      createdAt: now,
      updatedAt: now,
      description: description,
      tags: tags,
      color: color,
    );
  }
}

class SSHKeyFactory {
  static const Uuid _uuid = Uuid();

  static SSHKey create({
    required String name,
    required String type,
    required String publicKey,
    String? privateKey,
    String? passphrase,
    int? keySize,
    String? description,
  }) {
    final now = DateTime.now();
    return SSHKey(
      id: _uuid.v4(),
      name: name,
      type: type,
      publicKey: publicKey,
      privateKey: privateKey,
      passphrase: passphrase,
      keySize: keySize,
      createdAt: now,
      updatedAt: now,
      description: description,
    );
  }
}

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