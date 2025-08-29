import 'package:uuid/uuid.dart';
import 'ssh_basic_enums.dart';

/// Basic SSH Key model for standard operations
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

/// SSH Key record with enhanced metadata
class SshKeyRecord {
  final String id;
  final String name;
  final SshKeyType keyType;
  final String publicKey;
  final String fingerprint;
  final DateTime createdAt;
  final DateTime? lastUsed;
  final bool hasPassphrase;
  final Map<String, dynamic> metadata;

  const SshKeyRecord({
    required this.id,
    required this.name,
    required this.keyType,
    required this.publicKey,
    required this.fingerprint,
    required this.createdAt,
    this.lastUsed,
    required this.hasPassphrase,
    this.metadata = const {},
  });

  SshKeyRecord copyWith({
    String? id,
    String? name,
    SshKeyType? keyType,
    String? publicKey,
    String? fingerprint,
    DateTime? createdAt,
    DateTime? lastUsed,
    bool? hasPassphrase,
    Map<String, dynamic>? metadata,
  }) {
    return SshKeyRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      keyType: keyType ?? this.keyType,
      publicKey: publicKey ?? this.publicKey,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
      hasPassphrase: hasPassphrase ?? this.hasPassphrase,
      metadata: metadata ?? this.metadata,
    );
  }

  factory SshKeyRecord.fromJson(Map<String, dynamic> json) {
    return SshKeyRecord(
      id: json['id'],
      name: json['name'],
      keyType: SshKeyType.values.firstWhere(
        (e) => e.name == json['keyType'],
        orElse: () => SshKeyType.rsa4096,
      ),
      publicKey: json['publicKey'],
      fingerprint: json['fingerprint'],
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
      hasPassphrase: json['hasPassphrase'] ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'keyType': keyType.name,
      'publicKey': publicKey,
      'fingerprint': fingerprint,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
      'hasPassphrase': hasPassphrase,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SshKeyRecord && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SshKeyRecord{id: $id, name: $name, keyType: ${keyType.displayName}}';
  }
}

/// SSH Key Pair (record + private key)
class SshKeyPair {
  final SshKeyRecord record;
  final String privateKey;

  const SshKeyPair({
    required this.record,
    required this.privateKey,
  });

  @override
  String toString() {
    return 'SshKeyPair{record: ${record.toString()}}';
  }
}

/// SSH Key event model
class SshKeyEvent {
  final SshKeyEventType type;
  final String? keyId;
  final String? name;
  final SshKeyType? keyType;
  final String? fingerprint;
  final String? message;
  final String? error;
  final DateTime timestamp;

  const SshKeyEvent({
    required this.type,
    this.keyId,
    this.name,
    this.keyType,
    this.fingerprint,
    this.message,
    this.error,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'SshKeyEvent{type: $type, keyId: $keyId, name: $name, message: $message}';
  }
}

/// Factory for creating SSHKey instances
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