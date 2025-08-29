import 'ssh_security_enums.dart';

/// Enhanced SSH Host model with comprehensive security features
class SecureHost {
  final String id;
  final String name;
  final String hostname;
  final int port;
  final String username;
  final String? passwordHash; // Hashed password for verification
  final String? privateKeyId; // Reference to encrypted key in secure storage
  final String? keyPassphraseHash; // Hashed passphrase for verification
  final AuthMethod authMethod;
  final bool useCompression;
  final int keepAliveInterval;
  final Duration connectionTimeout;
  final String? jumpHostId; // Reference to jump host
  final String? jumpHostKeyFingerprint;
  final Map<String, String> environmentVariables;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final HostStatus status;
  final String? description;
  final List<String> tags;
  final String? color;
  
  // Enhanced security features
  final SecurityLevel securityLevel;
  final HostKeyVerification hostKeyVerification;
  final String? knownHostKeyFingerprint;
  final String? hostKeyType;
  final bool strictHostKeyChecking;
  final int maxAuthAttempts;
  final Duration keepAliveTimeout;
  final bool compressionEnabled;
  final String? certificatePath;
  final List<String> allowedCiphers;
  final List<String> allowedMACs;
  final List<String> allowedKex;
  final EncryptionLevel encryptionLevel;
  final bool requiresBiometric;
  final DateTime? lastSecurityAudit;
  final Map<String, dynamic> complianceFlags;

  const SecureHost({
    required this.id,
    required this.name,
    required this.hostname,
    this.port = 22,
    required this.username,
    this.passwordHash,
    this.privateKeyId,
    this.keyPassphraseHash,
    this.authMethod = AuthMethod.password,
    this.useCompression = false, // Disabled for security
    this.keepAliveInterval = 30,
    this.connectionTimeout = const Duration(seconds: 30),
    this.jumpHostId,
    this.jumpHostKeyFingerprint,
    this.environmentVariables = const {},
    required this.createdAt,
    required this.updatedAt,
    this.lastConnectedAt,
    this.status = HostStatus.unknown,
    this.description,
    this.tags = const [],
    this.color,
    
    // Security parameters with secure defaults
    this.securityLevel = SecurityLevel.medium,
    this.hostKeyVerification = HostKeyVerification.strict,
    this.knownHostKeyFingerprint,
    this.hostKeyType,
    this.strictHostKeyChecking = true,
    this.maxAuthAttempts = 3,
    this.keepAliveTimeout = const Duration(seconds: 60),
    this.compressionEnabled = false, // Disabled for security
    this.certificatePath,
    this.allowedCiphers = const ['aes256-gcm@openssh.com', 'aes256-ctr'],
    this.allowedMACs = const ['hmac-sha2-256-etm@openssh.com', 'hmac-sha2-512-etm@openssh.com'],
    this.allowedKex = const ['curve25519-sha256', 'diffie-hellman-group16-sha512'],
    this.encryptionLevel = EncryptionLevel.standard,
    this.requiresBiometric = false,
    this.lastSecurityAudit,
    this.complianceFlags = const {},
  });

  SecureHost copyWith({
    String? id,
    String? name,
    String? hostname,
    int? port,
    String? username,
    String? passwordHash,
    String? privateKeyId,
    String? keyPassphraseHash,
    AuthMethod? authMethod,
    bool? useCompression,
    int? keepAliveInterval,
    Duration? connectionTimeout,
    String? jumpHostId,
    String? jumpHostKeyFingerprint,
    Map<String, String>? environmentVariables,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastConnectedAt,
    HostStatus? status,
    String? description,
    List<String>? tags,
    String? color,
    SecurityLevel? securityLevel,
    HostKeyVerification? hostKeyVerification,
    String? knownHostKeyFingerprint,
    String? hostKeyType,
    bool? strictHostKeyChecking,
    int? maxAuthAttempts,
    Duration? keepAliveTimeout,
    bool? compressionEnabled,
    String? certificatePath,
    List<String>? allowedCiphers,
    List<String>? allowedMACs,
    List<String>? allowedKex,
    EncryptionLevel? encryptionLevel,
    bool? requiresBiometric,
    DateTime? lastSecurityAudit,
    Map<String, dynamic>? complianceFlags,
  }) {
    return SecureHost(
      id: id ?? this.id,
      name: name ?? this.name,
      hostname: hostname ?? this.hostname,
      port: port ?? this.port,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      privateKeyId: privateKeyId ?? this.privateKeyId,
      keyPassphraseHash: keyPassphraseHash ?? this.keyPassphraseHash,
      authMethod: authMethod ?? this.authMethod,
      useCompression: useCompression ?? this.useCompression,
      keepAliveInterval: keepAliveInterval ?? this.keepAliveInterval,
      connectionTimeout: connectionTimeout ?? this.connectionTimeout,
      jumpHostId: jumpHostId ?? this.jumpHostId,
      jumpHostKeyFingerprint: jumpHostKeyFingerprint ?? this.jumpHostKeyFingerprint,
      environmentVariables: environmentVariables ?? this.environmentVariables,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      status: status ?? this.status,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      securityLevel: securityLevel ?? this.securityLevel,
      hostKeyVerification: hostKeyVerification ?? this.hostKeyVerification,
      knownHostKeyFingerprint: knownHostKeyFingerprint ?? this.knownHostKeyFingerprint,
      hostKeyType: hostKeyType ?? this.hostKeyType,
      strictHostKeyChecking: strictHostKeyChecking ?? this.strictHostKeyChecking,
      maxAuthAttempts: maxAuthAttempts ?? this.maxAuthAttempts,
      keepAliveTimeout: keepAliveTimeout ?? this.keepAliveTimeout,
      compressionEnabled: compressionEnabled ?? this.compressionEnabled,
      certificatePath: certificatePath ?? this.certificatePath,
      allowedCiphers: allowedCiphers ?? this.allowedCiphers,
      allowedMACs: allowedMACs ?? this.allowedMACs,
      allowedKex: allowedKex ?? this.allowedKex,
      encryptionLevel: encryptionLevel ?? this.encryptionLevel,
      requiresBiometric: requiresBiometric ?? this.requiresBiometric,
      lastSecurityAudit: lastSecurityAudit ?? this.lastSecurityAudit,
      complianceFlags: complianceFlags ?? this.complianceFlags,
    );
  }

  factory SecureHost.fromJson(Map<String, dynamic> json) {
    return SecureHost(
      id: json['id'],
      name: json['name'],
      hostname: json['hostname'],
      port: json['port'] ?? 22,
      username: json['username'],
      passwordHash: json['password_hash'],
      privateKeyId: json['private_key_id'],
      keyPassphraseHash: json['key_passphrase_hash'],
      authMethod: AuthMethod.values.firstWhere(
        (e) => e.name == json['auth_method'],
        orElse: () => AuthMethod.password,
      ),
      useCompression: json['use_compression'] ?? false,
      keepAliveInterval: json['keep_alive_interval'] ?? 30,
      connectionTimeout: Duration(seconds: json['connection_timeout'] ?? 30),
      jumpHostId: json['jump_host_id'],
      jumpHostKeyFingerprint: json['jump_host_key_fingerprint'],
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
      securityLevel: SecurityLevel.values.firstWhere(
        (e) => e.name == json['security_level'],
        orElse: () => SecurityLevel.medium,
      ),
      hostKeyVerification: HostKeyVerification.values.firstWhere(
        (e) => e.name == json['host_key_verification'],
        orElse: () => HostKeyVerification.strict,
      ),
      knownHostKeyFingerprint: json['known_host_key_fingerprint'],
      hostKeyType: json['host_key_type'],
      strictHostKeyChecking: json['strict_host_key_checking'] ?? true,
      maxAuthAttempts: json['max_auth_attempts'] ?? 3,
      keepAliveTimeout: Duration(seconds: json['keep_alive_timeout'] ?? 60),
      compressionEnabled: json['compression_enabled'] ?? false,
      certificatePath: json['certificate_path'],
      allowedCiphers: List<String>.from(json['allowed_ciphers'] ?? ['aes256-gcm@openssh.com', 'aes256-ctr']),
      allowedMACs: List<String>.from(json['allowed_macs'] ?? ['hmac-sha2-256-etm@openssh.com']),
      allowedKex: List<String>.from(json['allowed_kex'] ?? ['curve25519-sha256']),
      encryptionLevel: EncryptionLevel.values.firstWhere(
        (e) => e.name == json['encryption_level'],
        orElse: () => EncryptionLevel.standard,
      ),
      requiresBiometric: json['requires_biometric'] ?? false,
      lastSecurityAudit: json['last_security_audit'] != null
          ? DateTime.parse(json['last_security_audit'])
          : null,
      complianceFlags: Map<String, dynamic>.from(json['compliance_flags'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hostname': hostname,
      'port': port,
      'username': username,
      'password_hash': passwordHash,
      'private_key_id': privateKeyId,
      'key_passphrase_hash': keyPassphraseHash,
      'auth_method': authMethod.name,
      'use_compression': useCompression,
      'keep_alive_interval': keepAliveInterval,
      'connection_timeout': connectionTimeout.inSeconds,
      'jump_host_id': jumpHostId,
      'jump_host_key_fingerprint': jumpHostKeyFingerprint,
      'environment_variables': environmentVariables,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_connected_at': lastConnectedAt?.toIso8601String(),
      'status': status.name,
      'description': description,
      'tags': tags,
      'color': color,
      'security_level': securityLevel.name,
      'host_key_verification': hostKeyVerification.name,
      'known_host_key_fingerprint': knownHostKeyFingerprint,
      'host_key_type': hostKeyType,
      'strict_host_key_checking': strictHostKeyChecking,
      'max_auth_attempts': maxAuthAttempts,
      'keep_alive_timeout': keepAliveTimeout.inSeconds,
      'compression_enabled': compressionEnabled,
      'certificate_path': certificatePath,
      'allowed_ciphers': allowedCiphers,
      'allowed_macs': allowedMACs,
      'allowed_kex': allowedKex,
      'encryption_level': encryptionLevel.name,
      'requires_biometric': requiresBiometric,
      'last_security_audit': lastSecurityAudit?.toIso8601String(),
      'compliance_flags': complianceFlags,
    };
  }

  String get connectionString => '$username@$hostname:$port';
  String get displayName => name.isEmpty ? connectionString : name;

  bool get isOnline => status == HostStatus.online || status == HostStatus.connected;
  bool get isConnecting => status == HostStatus.connecting || status == HostStatus.authenticating;
  bool get hasError => status == HostStatus.error || status == HostStatus.timeout;
  bool get isSecure => securityLevel == SecurityLevel.high || securityLevel == SecurityLevel.critical;
  bool get requiresStrictSecurity => securityLevel == SecurityLevel.critical;

  /// Get security risk assessment
  SecurityRisk get securityRisk {
    int riskScore = 0;

    // Host key verification
    if (hostKeyVerification == HostKeyVerification.disabled) {
      riskScore += 30;
    } else if (hostKeyVerification == HostKeyVerification.warn) {
      riskScore += 20;
    }

    // Authentication method
    if (authMethod == AuthMethod.password) {
      riskScore += 10;
    } else if (authMethod == AuthMethod.multiFactor) {
      riskScore -= 10;
    }

    // Encryption level
    if (encryptionLevel == EncryptionLevel.legacy) {
      riskScore += 25;
    } else if (encryptionLevel == EncryptionLevel.high) {
      riskScore -= 10;
    }

    // Compression (security risk)
    if (compressionEnabled) riskScore += 5;

    // Known host key
    if (knownHostKeyFingerprint == null) riskScore += 15;

    // Biometric requirement
    if (!requiresBiometric && securityLevel == SecurityLevel.critical) riskScore += 10;

    if (riskScore >= 50) return SecurityRisk.high;
    if (riskScore >= 25) return SecurityRisk.medium;
    return SecurityRisk.low;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecureHost && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SecureHost{id: $id, name: $name, hostname: $hostname, username: $username, security: ${securityLevel.name}}';
  }
}