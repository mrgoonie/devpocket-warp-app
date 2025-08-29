import 'package:uuid/uuid.dart';
import 'ssh_basic_enums.dart';

/// Basic SSH Host model for standard SSH operations
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

/// Factory for creating Host instances
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